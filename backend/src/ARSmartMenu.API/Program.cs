using ARSmartMenu.API.Middleware;
using ARSmartMenu.Application.Interfaces;
using ARSmartMenu.Infrastructure;
using ARSmartMenu.Infrastructure.Seed;
using Hangfire;
using Hangfire.SqlServer;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using System.Text;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);

// Dynamically auto-detect SQL Server instance across different developer machines (LocalDB vs localhost vs SQLEXPRESS)
var connectionString = ResolveDatabaseConnectionString(builder.Configuration);
builder.Configuration["ConnectionStrings:DefaultConnection"] = connectionString;

// Bind to 0.0.0.0 so mobile devices on LAN/USB tethering can reach the API
var configuredUrls = Environment.GetEnvironmentVariable("ASPNETCORE_URLS") 
    ?? builder.Configuration["Urls"] 
    ?? "http://0.0.0.0:5232";
builder.WebHost.UseUrls(configuredUrls);
builder.Services.AddHttpContextAccessor();

builder.Services.AddControllers();
builder.Services.AddInfrastructure(builder.Configuration);

var jwtSecret = builder.Configuration["Jwt:Secret"]
    ?? throw new InvalidOperationException("Jwt:Secret must be configured.");
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "ARSmartMenu";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "ARSmartMenuClients";

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtIssuer,
            ValidateAudience = true,
            ValidAudience = jwtAudience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),
        };

        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = async context =>
            {
                var jti = context.Principal?.FindFirstValue(JwtRegisteredClaimNames.Jti);
                if (string.IsNullOrEmpty(jti)) return;

                var auth = context.HttpContext.RequestServices.GetRequiredService<IAuthService>();
                if (await auth.IsTokenRevokedAsync(jti))
                    context.Fail("Token has been revoked.");
            },
        };
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("Admin", policy =>
        policy.RequireClaim("is_admin", "true"));
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "AR Smart Menu API",
        Version = "v1",
        Description = "REST API for AR Smart Menu SaaS platform",
    });

    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "JWT access token from /api/auth/verify-otp",
    });

    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" },
            },
            Array.Empty<string>()
        },
    });
});
// CORS for Flutter app, admin panel, and WebAR frontend
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
    ?? ["http://localhost:5173"];

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowClients", policy =>
    {
        if (builder.Environment.IsDevelopment())
        {
            // Flutter web uses random localhost ports â€” allow all local dev origins.
            policy.SetIsOriginAllowed(static origin =>
            {
                if (string.IsNullOrEmpty(origin)) return false;
                if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri)) return false;
                return true; // Allow local dev origins including mobile devices on LAN/tethering
            });
        }
        else
        {
            policy.WithOrigins(allowedOrigins);
        }

        policy.AllowAnyHeader().AllowAnyMethod();
    });
});

// Hangfire background jobs (uses same SQL Server database)
builder.Services.AddHangfire(config =>
    config.UseSqlServerStorage(connectionString, new SqlServerStorageOptions
    {
        SchemaName = "Hangfire",
    }));
builder.Services.AddHangfireServer();

var app = builder.Build();

app.UseMiddleware<ExceptionHandlingMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/swagger/v1/swagger.json", "AR Smart Menu API v1");
        options.RoutePrefix = "swagger";
    });
}

app.UseCors("AllowClients");
app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
app.UseHangfireDashboard("/hangfire");

app.MapControllers();

RecurringJob.AddOrUpdate<ARSmartMenu.Infrastructure.Jobs.PipelineJobRunner>(
    "cleanup-temp-files",
    runner => runner.CleanupTemporaryFilesAsync(),
    Cron.Daily);

try
{
    // Apply migrations + seed data
    await DatabaseSeeder.SeedAsync(app.Services);
    await SaaSDatabaseSeeder.SeedAsync(app.Services);

    app.Run();
}
catch (Microsoft.Data.SqlClient.SqlException ex)
{
    Console.ForegroundColor = ConsoleColor.Red;
    Console.WriteLine("\n=======================================================");
    Console.WriteLine(" [DATABASE CONNECTION ERROR] Cannot connect to SQL Server");
    Console.WriteLine("=======================================================");
    Console.WriteLine($"Connection String: {connectionString}");
    Console.WriteLine($"Error Details: {ex.Message}");
    Console.WriteLine("\nPlease ensure SQL Server or LocalDB is running: 'sqllocaldb start mssqllocaldb'\n");
    Console.ResetColor();
    Environment.Exit(1);
}
catch (System.IO.IOException ex) when (ex.InnerException is Microsoft.AspNetCore.Connections.AddressInUseException || ex.Message.Contains("address already in use"))
{
    Console.ForegroundColor = ConsoleColor.Red;
    Console.WriteLine("\n[PORT CONFLICT] Port 5232 is already in use by another instance or process.");
    Console.WriteLine("Automatic fix: The dev script will terminate stale processes on launch, or run 'start-backend.bat'.\n");
    Console.ResetColor();
    Environment.Exit(1);
}

// Auto-detect working SQL Server connection string across different developer machines
static string ResolveDatabaseConnectionString(IConfiguration configuration)
{
    var configured = configuration.GetConnectionString("DefaultConnection");
    var candidates = new List<string>();

    if (!string.IsNullOrWhiteSpace(configured))
    {
        candidates.Add(configured);
    }

    // Common developer database targets for seamless portability across machines
    candidates.Add("Server=(localdb)\\mssqllocaldb;Database=ARSmartMenu;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true");
    candidates.Add("Server=localhost;Database=ARSmartMenu;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true");
    candidates.Add("Server=.\\SQLEXPRESS;Database=ARSmartMenu;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true");
    candidates.Add("Server=localhost\\SQLEXPRESS;Database=ARSmartMenu;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true");

    foreach (var rawConn in candidates.Distinct())
    {
        try
        {
            var testBuilder = new SqlConnectionStringBuilder(rawConn)
            {
                InitialCatalog = "master", // Test connection to master catalog first
                ConnectTimeout = 2,
            };
            using var conn = new SqlConnection(testBuilder.ConnectionString);
            conn.Open();
            Console.WriteLine($"[Database] Successfully detected SQL Server instance: {testBuilder.DataSource}");
            return rawConn;
        }
        catch
        {
            // Try next candidate
        }
    }

    return configured ?? candidates[0];
}
