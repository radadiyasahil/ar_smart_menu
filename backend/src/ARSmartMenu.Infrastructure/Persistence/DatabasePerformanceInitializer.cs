using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace ARSmartMenu.Infrastructure.Persistence;

/// <summary>
/// Idempotently applies SQL Server storage optimizations (bounded columns, duplicate column cleanup),
/// composite covering indexes, scalar functions, SQL views, triggers, and stored procedures.
/// </summary>
public static class DatabasePerformanceInitializer
{
    public static async Task InitializeAsync(IServiceProvider services)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var logger = scope.ServiceProvider.GetRequiredService<ILoggerFactory>()
            .CreateLogger("DatabasePerformanceInitializer");

        try
        {
            await ApplyColumnRefinementsAsync(db, logger);
            await ApplyCompositeIndexesAsync(db, logger);
            await CreateFunctionsAsync(db, logger);
            await CreateViewsAsync(db, logger);
            await CreateTriggersAsync(db, logger);
            await CreateStoredProceduresAsync(db, logger);
            logger.LogInformation("[DB Performance] SQL schema refinements, indexes, views, functions, triggers, and stored procedures initialized.");
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "[DB Performance] Initialization notice: {Message}", ex.Message);
        }
    }

    private static async Task ApplyColumnRefinementsAsync(AppDbContext db, ILogger logger)
    {
        // 1. Migrate & drop unused duplicate [NotMapped] columns from Subscriptions
        const string dropDuplicateColumnsSql = @"
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Subscriptions]') AND name = N'BaseAmountPaise')
   AND EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Subscriptions]') AND name = N'TotalAmountPaise')
   AND EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Subscriptions]') AND name = N'PaymentRef')
BEGIN
    EXEC(N'
        UPDATE [dbo].[Subscriptions]
        SET [BasePricePaise] = CASE WHEN [BasePricePaise] = 0 AND [BaseAmountPaise] > 0 THEN [BaseAmountPaise] ELSE [BasePricePaise] END,
            [TotalPricePaise] = CASE WHEN [TotalPricePaise] = 0 AND [TotalAmountPaise] > 0 THEN [TotalAmountPaise] ELSE [TotalPricePaise] END,
            [TransactionRef] = COALESCE([TransactionRef], [PaymentRef])
        WHERE [BaseAmountPaise] > 0 OR [TotalAmountPaise] > 0 OR [PaymentRef] IS NOT NULL;
    ');
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Subscriptions]') AND name = N'BaseAmountPaise')
BEGIN
    DECLARE @c1 sysname;
    SELECT @c1 = dc.name FROM sys.default_constraints dc
    INNER JOIN sys.columns c ON dc.parent_object_id = c.object_id AND dc.parent_column_id = c.column_id
    WHERE dc.parent_object_id = OBJECT_ID(N'[dbo].[Subscriptions]') AND c.name = N'BaseAmountPaise';
    IF @c1 IS NOT NULL EXEC(N'ALTER TABLE [dbo].[Subscriptions] DROP CONSTRAINT [' + @c1 + N']');
    EXEC(N'ALTER TABLE [dbo].[Subscriptions] DROP COLUMN [BaseAmountPaise];');
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Subscriptions]') AND name = N'TotalAmountPaise')
BEGIN
    DECLARE @c2 sysname;
    SELECT @c2 = dc.name FROM sys.default_constraints dc
    INNER JOIN sys.columns c ON dc.parent_object_id = c.object_id AND dc.parent_column_id = c.column_id
    WHERE dc.parent_object_id = OBJECT_ID(N'[dbo].[Subscriptions]') AND c.name = N'TotalAmountPaise';
    IF @c2 IS NOT NULL EXEC(N'ALTER TABLE [dbo].[Subscriptions] DROP CONSTRAINT [' + @c2 + N']');
    EXEC(N'ALTER TABLE [dbo].[Subscriptions] DROP COLUMN [TotalAmountPaise];');
END

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Subscriptions]') AND name = N'PaymentRef')
BEGIN
    DECLARE @c3 sysname;
    SELECT @c3 = dc.name FROM sys.default_constraints dc
    INNER JOIN sys.columns c ON dc.parent_object_id = c.object_id AND dc.parent_column_id = c.column_id
    WHERE dc.parent_object_id = OBJECT_ID(N'[dbo].[Subscriptions]') AND c.name = N'PaymentRef';
    IF @c3 IS NOT NULL EXEC(N'ALTER TABLE [dbo].[Subscriptions] DROP CONSTRAINT [' + @c3 + N']');
    EXEC(N'ALTER TABLE [dbo].[Subscriptions] DROP COLUMN [PaymentRef];');
END
";
        await ExecuteSafeAsync(db, dropDuplicateColumnsSql, logger, "Drop duplicate Subscription columns");

        // 2. Truncate oversized telemetry strings before tightening nvarchar(max) -> bounded nvarchar(N)
        const string trimTelemetrySql = @"
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[ArScanEvents]') AND name = N'UserAgent' AND max_length = -1)
    UPDATE [dbo].[ArScanEvents] SET [UserAgent] = LEFT([UserAgent], 160) WHERE LEN([UserAgent]) > 160;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[ArViewEvents]') AND name = N'UserAgent' AND max_length = -1)
    UPDATE [dbo].[ArViewEvents] SET [UserAgent] = LEFT([UserAgent], 160) WHERE LEN([UserAgent]) > 160;
";
        await ExecuteSafeAsync(db, trimTelemetrySql, logger, "Trim UserAgent telemetry");

        // 3. Narrow unbounded nvarchar(max) columns to exact bounded lengths (unlocks composite indexing + shrinks storage)
        var columnSpecs = new (string Table, string Column, string TargetType)[]
        {
            ("TableOrders", "TableNumber", "nvarchar(50) NOT NULL"),
            ("TableOrders", "Status", "nvarchar(24) NOT NULL"),
            ("TableOrders", "CustomerPhone", "nvarchar(20) NOT NULL"),
            ("TableOrders", "PartyPin", "nvarchar(10) NULL"),

            ("ArScanEvents", "SessionId", "nvarchar(100) NULL"),
            ("ArScanEvents", "UserAgent", "nvarchar(160) NULL"),
            ("ArScanEvents", "IpAddress", "nvarchar(45) NULL"),
            ("ArScanEvents", "Referrer", "nvarchar(300) NULL"),

            ("ArViewEvents", "SessionId", "nvarchar(100) NULL"),
            ("ArViewEvents", "UserAgent", "nvarchar(160) NULL"),

            ("Businesses", "BusinessName", "nvarchar(200) NOT NULL"),
            ("Businesses", "City", "nvarchar(100) NOT NULL"),
            ("Businesses", "FssaiNumber", "nvarchar(32) NULL"),
            ("Businesses", "GstNumber", "nvarchar(32) NULL"),
            ("Businesses", "BankAccountNumber", "nvarchar(32) NULL"),
            ("Businesses", "BankIfsc", "nvarchar(16) NULL"),
            ("Businesses", "UpiId", "nvarchar(100) NULL"),
            ("Businesses", "WifiName", "nvarchar(80) NULL"),
            ("Businesses", "WifiPassword", "nvarchar(80) NULL"),
            ("Businesses", "RazorpayContactId", "nvarchar(64) NULL"),
            ("Businesses", "RazorpayFundAccountId", "nvarchar(64) NULL"),

            ("Users", "WhatsAppNumber", "nvarchar(20) NULL"),
            ("Users", "FullName", "nvarchar(150) NULL"),
            ("Users", "AadhaarLast4", "nvarchar(8) NULL"),
            ("Users", "PanNumber", "nvarchar(16) NULL"),
            ("Users", "LanguagePreference", "nvarchar(10) NOT NULL"),
            ("Users", "PasswordHash", "nvarchar(256) NULL"),

            ("Products", "Name", "nvarchar(200) NOT NULL"),
            ("Products", "RejectionReason", "nvarchar(500) NULL"),

            ("Subscriptions", "PaymentMethod", "nvarchar(50) NULL"),
            ("Subscriptions", "TransactionRef", "nvarchar(120) NULL"),
            ("Subscriptions", "CustomerGstNumber", "nvarchar(32) NULL"),
            ("Subscriptions", "CustomerBusinessName", "nvarchar(200) NULL"),
            ("Subscriptions", "CustomerAddress", "nvarchar(500) NULL"),
            ("Subscriptions", "CustomerCity", "nvarchar(100) NULL"),
        };

        foreach (var (table, col, targetType) in columnSpecs)
        {
            var sql = $@"
IF EXISTS (
    SELECT 1 FROM sys.columns c
    WHERE c.object_id = OBJECT_ID(N'[dbo].[{table}]')
      AND c.name = N'{col}'
      AND c.max_length = -1
)
BEGIN
    BEGIN TRY
        ALTER TABLE [dbo].[{table}] ALTER COLUMN [{col}] {targetType};
    END TRY
    BEGIN CATCH
        -- Skip cleanly if existing row data exceeds target length
    END CATCH
END";
            await ExecuteSafeAsync(db, sql, logger, $"Narrow {table}.{col}");
        }
    }

    private static async Task ApplyCompositeIndexesAsync(AppDbContext db, ILogger logger)
    {
        const string indexSql = @"
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_TableOrders_Business_Created_Status' AND object_id = OBJECT_ID(N'[dbo].[TableOrders]'))
BEGIN
    BEGIN TRY
        CREATE NONCLUSTERED INDEX [IX_TableOrders_Business_Created_Status]
        ON [dbo].[TableOrders] ([BusinessId], [CreatedAt] DESC, [Status])
        INCLUDE ([TableNumber], [Round], [TotalAmount], [BillRequested], [CompletedAt], [UpdatedAt]);
    END TRY BEGIN CATCH END CATCH
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Subscriptions_Business_Status_Ends' AND object_id = OBJECT_ID(N'[dbo].[Subscriptions]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_Subscriptions_Business_Status_Ends]
    ON [dbo].[Subscriptions] ([BusinessId], [Status], [EndsAt] DESC)
    INCLUDE ([PlanId]);
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Products_Business_Status_Order' AND object_id = OBJECT_ID(N'[dbo].[Products]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_Products_Business_Status_Order]
    ON [dbo].[Products] ([BusinessId], [Status], [DisplayOrder])
    INCLUDE ([Name], [Category], [PricePaise], [SoldOutToday]);
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_QrCodes_Business_Type_Active' AND object_id = OBJECT_ID(N'[dbo].[QrCodes]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_QrCodes_Business_Type_Active]
    ON [dbo].[QrCodes] ([BusinessId], [QrType], [IsActive])
    INCLUDE ([ProductId], [Slug], [WebUrl]);
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ArScanEvents_Business_Created' AND object_id = OBJECT_ID(N'[dbo].[ArScanEvents]'))
BEGIN
    BEGIN TRY
        CREATE NONCLUSTERED INDEX [IX_ArScanEvents_Business_Created]
        ON [dbo].[ArScanEvents] ([BusinessId], [CreatedAt])
        INCLUDE ([ProductId], [SessionId], [IpAddress]);
    END TRY BEGIN CATCH END CATCH
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ArViewEvents_Business_Created' AND object_id = OBJECT_ID(N'[dbo].[ArViewEvents]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_ArViewEvents_Business_Created]
    ON [dbo].[ArViewEvents] ([BusinessId], [CreatedAt])
    INCLUDE ([ProductId]);
END

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Notifications_Business_Read_Created' AND object_id = OBJECT_ID(N'[dbo].[Notifications]'))
BEGIN
    CREATE NONCLUSTERED INDEX [IX_Notifications_Business_Read_Created]
    ON [dbo].[Notifications] ([BusinessId], [IsRead], [CreatedAt] DESC);
END
";
        await ExecuteSafeAsync(db, indexSql, logger, "Composite Indexes");
    }

    private static async Task CreateFunctionsAsync(AppDbContext db, ILogger logger)
    {
        const string fnNormalizeTable = @"
CREATE OR ALTER FUNCTION [dbo].[fn_NormalizeTableKey](@TableNumber nvarchar(50))
RETURNS nvarchar(50)
AS
BEGIN
    DECLARE @s nvarchar(50) = LOWER(LTRIM(RTRIM(ISNULL(@TableNumber, N''))));
    WHILE LEFT(@s, 5) = N'table'
    BEGIN
        SET @s = LTRIM(SUBSTRING(@s, 6, 50));
    END
    RETURN @s;
END";
        await ExecuteSafeAsync(db, fnNormalizeTable, logger, "fn_NormalizeTableKey");

        const string fnDishLimit = @"
CREATE OR ALTER FUNCTION [dbo].[fn_GetBusinessEffectiveDishLimit](@BusinessId uniqueidentifier)
RETURNS int
AS
BEGIN
    DECLARE @Limit int;
    SELECT TOP 1 @Limit =
        CASE
            WHEN b.[CustomDishLimit] IS NOT NULL AND b.[CustomDishLimit] > 0 THEN b.[CustomDishLimit]
            ELSE ISNULL(sp.[MaxProducts], 50)
        END
    FROM [dbo].[Businesses] b
    OUTER APPLY (
        SELECT TOP 1 p.[MaxProducts]
        FROM [dbo].[Subscriptions] s
        INNER JOIN [dbo].[SubscriptionPlans] p ON p.[Id] = s.[PlanId]
        WHERE s.[BusinessId] = b.[Id] AND s.[Status] = 0 AND s.[EndsAt] > GETUTCDATE()
        ORDER BY s.[EndsAt] DESC
    ) sp
    WHERE b.[Id] = @BusinessId;

    RETURN ISNULL(@Limit, 50);
END";
        await ExecuteSafeAsync(db, fnDishLimit, logger, "fn_GetBusinessEffectiveDishLimit");
    }

    private static async Task CreateViewsAsync(AppDbContext db, ILogger logger)
    {
        const string vwAdminBiz = @"
CREATE OR ALTER VIEW [dbo].[vw_AdminBusinessSummary]
AS
SELECT
    b.[Id],
    b.[OwnerId],
    b.[BusinessName],
    b.[BusinessType],
    b.[City],
    b.[FullAddress],
    b.[Status],
    b.[FssaiNumber],
    b.[GstNumber],
    b.[UpiId],
    b.[BankAccountNumber],
    b.[BankIfsc],
    b.[BankPennyVerified],
    b.[RejectionReason],
    b.[AdminNotes],
    b.[CustomDishLimit],
    b.[ArViewEnabled],
    b.[ArPerViewChargePaise],
    b.[ArViewCredits],
    b.[ArViewsUsed],
    b.[CreatedAt],
    u.[MobileNumber] AS [OwnerMobile],
    u.[FullName] AS [OwnerName],
    u.[KycStatus] AS [OwnerKycStatus],
    u.[WhatsAppNumber] AS [OwnerWhatsApp],
    u.[AadhaarLast4] AS [OwnerAadhaarLast4],
    u.[PanNumber] AS [OwnerPanNumber],
    ls.[PlanName] AS [SubscriptionPlanName],
    ls.[PlanSlug] AS [SubscriptionPlanSlug],
    ls.[StartsAt] AS [SubscriptionStartsAt],
    ls.[EndsAt] AS [SubscriptionEndsAt],
    ls.[SubStatusInt],
    ls.[PlanMaxProducts],
    CASE
        WHEN ls.[Id] IS NULL THEN N'None'
        WHEN ls.[SubStatusInt] = 0 AND ls.[EndsAt] > GETUTCDATE() THEN
            CASE WHEN ls.[PlanSlug] = N'trial-7-days' THEN N'Trial' ELSE N'Active' END
        ELSE N'Expired'
    END AS [SubscriptionStatus],
    CASE
        WHEN ls.[SubStatusInt] = 0 AND ls.[EndsAt] > GETUTCDATE()
            THEN CAST(CEILING(DATEDIFF(SECOND, GETUTCDATE(), ls.[EndsAt]) / 86400.0) AS int)
        ELSE 0
    END AS [SubscriptionDaysRemaining],
    CAST(CASE WHEN EXISTS (
        SELECT 1 FROM [dbo].[Subscriptions] st
        INNER JOIN [dbo].[SubscriptionPlans] sp ON sp.[Id] = st.[PlanId]
        WHERE st.[BusinessId] = b.[Id] AND sp.[Slug] = N'trial-7-days'
    ) THEN 1 ELSE 0 END AS bit) AS [HasUsedTrial],
    CASE
        WHEN b.[CustomDishLimit] IS NOT NULL AND b.[CustomDishLimit] > 0 THEN b.[CustomDishLimit]
        ELSE ISNULL(ls.[PlanMaxProducts], 50)
    END AS [EffectiveDishLimit],
    ISNULL(ps.[ProductCount], 0) AS [ProductCount],
    ISNULL(ps.[LiveProductCount], 0) AS [LiveProductCount],
    ISNULL(ps.[ArProductCount], 0) AS [ArProductCount],
    ISNULL(os.[TotalOrdersCount], 0) AS [TotalOrdersCount],
    ISNULL(os.[CompletedOrdersCount], 0) AS [CompletedOrdersCount],
    ISNULL(sc.[TotalScans], 0) AS [TotalScans],
    ISNULL(vw.[TotalViews], 0) AS [TotalViews],
    fb.[AverageRating],
    ISNULL(fb.[TotalReviews], 0) AS [TotalReviews]
FROM [dbo].[Businesses] b
INNER JOIN [dbo].[Users] u ON u.[Id] = b.[OwnerId]
OUTER APPLY (
    SELECT TOP 1
        s.[Id], s.[Status] AS [SubStatusInt], s.[StartsAt], s.[EndsAt],
        p.[Name] AS [PlanName], p.[Slug] AS [PlanSlug], p.[MaxProducts] AS [PlanMaxProducts]
    FROM [dbo].[Subscriptions] s
    LEFT JOIN [dbo].[SubscriptionPlans] p ON p.[Id] = s.[PlanId]
    WHERE s.[BusinessId] = b.[Id]
    ORDER BY CASE WHEN s.[Status] = 0 AND s.[EndsAt] > GETUTCDATE() THEN 0 ELSE 1 END, s.[EndsAt] DESC
) ls
OUTER APPLY (
    SELECT
        COUNT(DISTINCT p.[Id]) AS [ProductCount],
        COUNT(DISTINCT CASE WHEN p.[Status] = 4 THEN p.[Id] END) AS [LiveProductCount],
        COUNT(DISTINCT CASE WHEN m.[Id] IS NOT NULL THEN p.[Id] END) AS [ArProductCount]
    FROM [dbo].[Products] p
    LEFT JOIN [dbo].[Models3d] m ON m.[ProductId] = p.[Id]
    WHERE p.[BusinessId] = b.[Id]
) ps
OUTER APPLY (
    SELECT
        COUNT(*) AS [TotalOrdersCount],
        SUM(CASE WHEN o.[Status] IN (N'COMPLETED', N'PAID', N'SETTLED') THEN 1 ELSE 0 END) AS [CompletedOrdersCount]
    FROM [dbo].[TableOrders] o
    WHERE o.[BusinessId] = b.[Id] AND o.[Round] <= 1
) os
OUTER APPLY (
    SELECT COUNT(*) AS [TotalScans]
    FROM [dbo].[ArScanEvents] e
    WHERE e.[BusinessId] = b.[Id]
) sc
OUTER APPLY (
    SELECT COUNT(*) AS [TotalViews]
    FROM [dbo].[ArViewEvents] v
    WHERE v.[BusinessId] = b.[Id]
) vw
OUTER APPLY (
    SELECT
        ROUND(AVG(CAST(o.[Rating] AS float)), 1) AS [AverageRating],
        COUNT(*) AS [TotalReviews]
    FROM [dbo].[TableOrders] o
    WHERE o.[BusinessId] = b.[Id] AND o.[Rating] IS NOT NULL AND o.[Rating] > 0
) fb";
        await ExecuteSafeAsync(db, vwAdminBiz, logger, "vw_AdminBusinessSummary");

        const string vwSubHistory = @"
CREATE OR ALTER VIEW [dbo].[vw_SubscriptionHistoryDetails]
AS
SELECT
    s.[Id],
    s.[BusinessId],
    s.[PlanId],
    s.[InvoiceNumber],
    ISNULL(s.[InvoiceDate], COALESCE(s.[CreatedAt], s.[StartsAt])) AS [InvoiceDate],
    s.[BillingCycle],
    s.[Status],
    s.[StartsAt],
    s.[EndsAt],
    s.[CancelledAt],
    s.[BasePricePaise],
    s.[GstPaise],
    s.[TotalPricePaise],
    s.[PaymentMethod],
    s.[TransactionRef],
    s.[RazorpaySubscriptionId],
    s.[PaymentStatus],
    s.[SacCode],
    s.[GstRatePercent],
    ISNULL(s.[CustomerBusinessName], b.[BusinessName]) AS [BusinessName],
    ISNULL(s.[CustomerGstNumber], b.[GstNumber]) AS [CustomerGstNumber],
    ISNULL(s.[CustomerAddress], b.[FullAddress]) AS [CustomerAddress],
    ISNULL(s.[CustomerCity], b.[City]) AS [CustomerCity],
    p.[Name] AS [PlanName],
    p.[Slug] AS [PlanSlug],
    p.[DurationDays] AS [PlanDurationDays],
    p.[BasePricePaise] AS [PlanBasePricePaise],
    p.[GstPaise] AS [PlanGstPaise],
    p.[TotalPricePaise] AS [PlanTotalPricePaise],
    u.[FullName] AS [OwnerName],
    u.[MobileNumber] AS [OwnerMobile]
FROM [dbo].[Subscriptions] s
LEFT JOIN [dbo].[SubscriptionPlans] p ON p.[Id] = s.[PlanId]
INNER JOIN [dbo].[Businesses] b ON b.[Id] = s.[BusinessId]
INNER JOIN [dbo].[Users] u ON u.[Id] = b.[OwnerId]";
        await ExecuteSafeAsync(db, vwSubHistory, logger, "vw_SubscriptionHistoryDetails");
    }

    private static async Task CreateTriggersAsync(AppDbContext db, ILogger logger)
    {
        const string trViewTrack = @"
CREATE OR ALTER TRIGGER [dbo].[tr_ArViewEvents_TrackUsage]
ON [dbo].[ArViewEvents]
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted WHERE [ArLaunched] = 1) RETURN;

    UPDATE b
    SET b.[ArViewsUsed] = b.[ArViewsUsed] + v.[LaunchCount],
        b.[ArViewCredits] = CASE WHEN b.[ArViewCredits] >= v.[LaunchCount] THEN b.[ArViewCredits] - v.[LaunchCount] ELSE 0 END,
        b.[UpdatedAt] = GETUTCDATE()
    FROM [dbo].[Businesses] b
    INNER JOIN (
        SELECT [BusinessId], COUNT(*) AS [LaunchCount]
        FROM inserted
        WHERE [ArLaunched] = 1
        GROUP BY [BusinessId]
    ) v ON v.[BusinessId] = b.[Id];
END";
        await ExecuteSafeAsync(db, trViewTrack, logger, "tr_ArViewEvents_TrackUsage");

        const string trSyncGst = @"
CREATE OR ALTER TRIGGER [dbo].[tr_SystemSettings_SyncBusinessGstRate]
ON [dbo].[SystemSettings]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted WHERE [Key] = N'Billing.GstRatePercent') RETURN;

    DECLARE @NewRate float;
    SELECT TOP 1 @NewRate = TRY_CAST([Value] AS float)
    FROM inserted
    WHERE [Key] = N'Billing.GstRatePercent';

    IF @NewRate IS NOT NULL AND @NewRate >= 0 AND @NewRate <= 100
    BEGIN
        UPDATE [dbo].[Businesses]
        SET [GstRate] = @NewRate,
            [UpdatedAt] = GETUTCDATE()
        WHERE [GstRate] <= 0 OR [GstRate] = 5.0;
    END
END";
        await ExecuteSafeAsync(db, trSyncGst, logger, "tr_SystemSettings_SyncBusinessGstRate");
    }

    private static async Task CreateStoredProceduresAsync(AppDbContext db, ILogger logger)
    {
        const string uspAdminStats = @"
CREATE OR ALTER PROCEDURE [dbo].[usp_GetAdminDashboardStats]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM [dbo].[Businesses]) AS [TotalBusinesses],
        (SELECT COUNT(*) FROM [dbo].[Businesses] WHERE [Status] = 1) AS [ActiveBusinesses],
        (SELECT COUNT(*) FROM [dbo].[Businesses] WHERE [Status] = 0) AS [PendingApprovals],
        (SELECT COUNT(*) FROM [dbo].[Products] WHERE [Status] IN (1, 2, 3)) AS [PendingProductReviews],
        (SELECT COUNT(*) FROM [dbo].[ArScanEvents]) AS [TotalScans],
        (SELECT COUNT(*) FROM [dbo].[ArViewEvents]) AS [TotalArViews],
        (SELECT COUNT(*) FROM [dbo].[Products]) AS [TotalProducts],
        (SELECT COUNT(*) FROM [dbo].[Products] WHERE [Status] = 4) AS [TotalLiveDishes],
        (SELECT COUNT(*) FROM [dbo].[Models3d]) AS [TotalArDishes],
        (SELECT COUNT(*) FROM [dbo].[TableOrders] WHERE [Round] <= 1) AS [TotalOrdersPlaced],
        (SELECT COUNT(*) FROM [dbo].[TableOrders] WHERE [Round] <= 1 AND [Status] IN (N'COMPLETED', N'PAID', N'SETTLED')) AS [TotalOrdersCompleted],
        (SELECT ROUND(AVG(CAST([Rating] AS float)), 1) FROM [dbo].[TableOrders] WHERE [Rating] IS NOT NULL AND [Rating] > 0) AS [AverageRating],
        (SELECT COUNT(*) FROM [dbo].[TableOrders] WHERE [Rating] IS NOT NULL AND [Rating] > 0) AS [TotalReviews];
END";
        await ExecuteSafeAsync(db, uspAdminStats, logger, "usp_GetAdminDashboardStats");

        const string uspAnalyticsOverview = @"
CREATE OR ALTER PROCEDURE [dbo].[usp_GetBusinessAnalyticsOverview]
    @BusinessId uniqueidentifier,
    @FromDate datetime2
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Businesses] WHERE [Id] = @BusinessId AND [Status] = 1)
    BEGIN
        SELECT 0 AS [TotalScans], 0 AS [TotalViews], 0 AS [UniqueVisitors], 0 AS [TotalOrders], 0 AS [TotalRevenue];
        RETURN;
    END

    SELECT
        (SELECT COUNT(*) FROM [dbo].[ArScanEvents] WHERE [BusinessId] = @BusinessId AND [CreatedAt] >= @FromDate) AS [TotalScans],
        (SELECT COUNT(*) FROM [dbo].[ArViewEvents] WHERE [BusinessId] = @BusinessId AND [CreatedAt] >= @FromDate) AS [TotalViews],
        (SELECT COUNT(DISTINCT COALESCE([SessionId], [IpAddress], CAST([Id] AS nvarchar(36))))
         FROM [dbo].[ArScanEvents]
         WHERE [BusinessId] = @BusinessId AND [CreatedAt] >= @FromDate) AS [UniqueVisitors],
        ISNULL(ord.[TotalOrders], 0) AS [TotalOrders],
        ISNULL(ord.[TotalRevenue], 0) AS [TotalRevenue]
    FROM (SELECT 1 AS [One]) d
    OUTER APPLY (
        SELECT
            COUNT(*) AS [TotalOrders],
            ISNULL(SUM(CAST([TotalAmount] AS int)), 0) AS [TotalRevenue]
        FROM [dbo].[TableOrders]
        WHERE [BusinessId] = @BusinessId AND [CreatedAt] >= @FromDate AND [Status] <> N'CANCELLED'
    ) ord;
END";
        await ExecuteSafeAsync(db, uspAnalyticsOverview, logger, "usp_GetBusinessAnalyticsOverview");

        const string uspAnalyticsChart = @"
CREATE OR ALTER PROCEDURE [dbo].[usp_GetBusinessAnalyticsChart]
    @BusinessId uniqueidentifier,
    @FromDate datetime2
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Businesses] WHERE [Id] = @BusinessId AND [Status] = 1)
    BEGIN
        SELECT TOP 0 CAST(GETUTCDATE() AS date) AS [BucketDate], 0 AS [Scans], 0 AS [Views], 0 AS [Orders], 0 AS [Revenue];
        RETURN;
    END

    SELECT
        [BucketDate],
        SUM([Scans]) AS [Scans],
        SUM([Views]) AS [Views],
        SUM([Orders]) AS [Orders],
        SUM([Revenue]) AS [Revenue]
    FROM (
        SELECT CAST([CreatedAt] AS date) AS [BucketDate], COUNT(*) AS [Scans], 0 AS [Views], 0 AS [Orders], 0 AS [Revenue]
        FROM [dbo].[ArScanEvents]
        WHERE [BusinessId] = @BusinessId AND [CreatedAt] >= @FromDate
        GROUP BY CAST([CreatedAt] AS date)

        UNION ALL

        SELECT CAST([CreatedAt] AS date) AS [BucketDate], 0 AS [Scans], COUNT(*) AS [Views], 0 AS [Orders], 0 AS [Revenue]
        FROM [dbo].[ArViewEvents]
        WHERE [BusinessId] = @BusinessId AND [CreatedAt] >= @FromDate
        GROUP BY CAST([CreatedAt] AS date)

        UNION ALL

        SELECT CAST([CreatedAt] AS date) AS [BucketDate], 0 AS [Scans], 0 AS [Views], COUNT(*) AS [Orders], ISNULL(SUM(CAST([TotalAmount] AS int)), 0) AS [Revenue]
        FROM [dbo].[TableOrders]
        WHERE [BusinessId] = @BusinessId AND [CreatedAt] >= @FromDate AND [Status] <> N'CANCELLED'
        GROUP BY CAST([CreatedAt] AS date)
    ) combined
    GROUP BY [BucketDate]
    ORDER BY [BucketDate];
END";
        await ExecuteSafeAsync(db, uspAnalyticsChart, logger, "usp_GetBusinessAnalyticsChart");

        const string uspTopProducts = @"
CREATE OR ALTER PROCEDURE [dbo].[usp_GetTopProductsAnalytics]
    @BusinessId uniqueidentifier,
    @FromDate datetime2,
    @Limit int = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[Businesses] WHERE [Id] = @BusinessId AND [Status] = 1)
    BEGIN
        SELECT TOP 0 NEWID() AS [ProductId], N'' AS [ProductName], 0 AS [Scans], 0 AS [Views], 0 AS [OrderCount], 0 AS [TotalRevenue];
        RETURN;
    END

    SET @Limit = CASE WHEN @Limit < 1 THEN 1 WHEN @Limit > 50 THEN 50 ELSE @Limit END;

    ;WITH ParsedItems AS (
        SELECT
            TRY_CAST(COALESCE(j.[IdUpper], j.[IdLower]) AS uniqueidentifier) AS [RawProductId],
            LTRIM(RTRIM(COALESCE(j.[NameUpper], j.[NameLower], N''))) AS [ItemName],
            ISNULL(j.[QtyUpper], ISNULL(j.[QtyLower], 1)) AS [Quantity],
            ISNULL(j.[PriceUpper], ISNULL(j.[PriceLower], 0)) AS [UnitPrice]
        FROM [dbo].[TableOrders] o
        CROSS APPLY OPENJSON(CASE WHEN ISJSON(o.[ItemsJson]) = 1 THEN o.[ItemsJson] ELSE N'[]' END)
        WITH (
            [IdUpper] nvarchar(50) '$.Id',
            [IdLower] nvarchar(50) '$.id',
            [NameUpper] nvarchar(200) '$.Name',
            [NameLower] nvarchar(200) '$.name',
            [QtyUpper] int '$.Quantity',
            [QtyLower] int '$.quantity',
            [PriceUpper] int '$.UnitPrice',
            [PriceLower] int '$.unitPrice'
        ) j
        WHERE o.[BusinessId] = @BusinessId
          AND o.[CreatedAt] >= @FromDate
          AND o.[Status] <> N'CANCELLED'
          AND LTRIM(RTRIM(COALESCE(j.[NameUpper], j.[NameLower], N''))) <> N''
    ),
    ResolvedOrders AS (
        SELECT
            COALESCE(pById.[Id], pByName.[Id]) AS [ProductId],
            MAX(COALESCE(pById.[Name], pByName.[Name], pi.[ItemName])) AS [ProductName],
            LOWER(MAX(pi.[ItemName])) AS [ItemKey],
            SUM(pi.[Quantity]) AS [OrderCount],
            SUM(pi.[Quantity] * pi.[UnitPrice]) AS [TotalRevenue]
        FROM ParsedItems pi
        LEFT JOIN [dbo].[Products] pById ON pById.[Id] = pi.[RawProductId] AND pById.[BusinessId] = @BusinessId
        LEFT JOIN [dbo].[Products] pByName ON pById.[Id] IS NULL AND pByName.[Name] = pi.[ItemName] AND pByName.[BusinessId] = @BusinessId
        GROUP BY COALESCE(pById.[Id], pByName.[Id]), CASE WHEN COALESCE(pById.[Id], pByName.[Id]) IS NULL THEN LOWER(pi.[ItemName]) ELSE N'' END
    ),
    ScanAgg AS (
        SELECT [ProductId], COUNT(*) AS [Scans]
        FROM [dbo].[ArScanEvents]
        WHERE [BusinessId] = @BusinessId AND [CreatedAt] >= @FromDate AND [ProductId] IS NOT NULL
        GROUP BY [ProductId]
    ),
    ViewAgg AS (
        SELECT [ProductId], COUNT(*) AS [Views]
        FROM [dbo].[ArViewEvents]
        WHERE [BusinessId] = @BusinessId AND [CreatedAt] >= @FromDate AND [ProductId] IS NOT NULL
        GROUP BY [ProductId]
    )
    SELECT TOP (@Limit)
        ISNULL(ro.[ProductId], ISNULL(sa.[ProductId], '00000000-0000-0000-0000-000000000000')) AS [ProductId],
        COALESCE(ro.[ProductName], p.[Name], N'Unknown') AS [ProductName],
        ISNULL(sa.[Scans], 0) AS [Scans],
        ISNULL(va.[Views], 0) AS [Views],
        ISNULL(ro.[OrderCount], 0) AS [OrderCount],
        ISNULL(ro.[TotalRevenue], 0) AS [TotalRevenue]
    FROM ResolvedOrders ro
    FULL OUTER JOIN ScanAgg sa ON ro.[ProductId] = sa.[ProductId]
    LEFT JOIN ViewAgg va ON ISNULL(ro.[ProductId], sa.[ProductId]) = va.[ProductId]
    LEFT JOIN [dbo].[Products] p ON sa.[ProductId] = p.[Id]
    ORDER BY ISNULL(ro.[OrderCount], 0) DESC, ISNULL(ro.[TotalRevenue], 0) DESC, ISNULL(sa.[Scans], 0) DESC;
END";
        await ExecuteSafeAsync(db, uspTopProducts, logger, "usp_GetTopProductsAnalytics");

        const string uspReorder = @"
CREATE OR ALTER PROCEDURE [dbo].[usp_ReorderProducts]
    @BusinessId uniqueidentifier,
    @OrderJson nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    IF ISJSON(@OrderJson) <> 1 RETURN;

    UPDATE p
    SET p.[DisplayOrder] = j.[DisplayOrder],
        p.[UpdatedAt] = GETUTCDATE()
    FROM [dbo].[Products] p
    INNER JOIN OPENJSON(@OrderJson)
    WITH (
        [Id] uniqueidentifier '$.id',
        [DisplayOrder] int '$.displayOrder'
    ) j ON p.[Id] = j.[Id]
    WHERE p.[BusinessId] = @BusinessId;
END";
        await ExecuteSafeAsync(db, uspReorder, logger, "usp_ReorderProducts");

        const string uspBulkSoldOut = @"
CREATE OR ALTER PROCEDURE [dbo].[usp_BulkSetSoldOut]
    @BusinessId uniqueidentifier,
    @ProductIdsJson nvarchar(max),
    @SoldOut bit,
    @SoldOutDate date = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF ISJSON(@ProductIdsJson) <> 1 RETURN;

    UPDATE p
    SET p.[SoldOutToday] = @SoldOut,
        p.[SoldOutDate] = CASE WHEN @SoldOut = 1 THEN @SoldOutDate ELSE NULL END,
        p.[UpdatedAt] = GETUTCDATE()
    FROM [dbo].[Products] p
    INNER JOIN OPENJSON(@ProductIdsJson) j ON p.[Id] = TRY_CAST(j.[value] AS uniqueidentifier)
    WHERE p.[BusinessId] = @BusinessId;
END";
        await ExecuteSafeAsync(db, uspBulkSoldOut, logger, "usp_BulkSetSoldOut");

        const string uspCleanup = @"
CREATE OR ALTER PROCEDURE [dbo].[usp_CleanupExpiredData]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now datetime2 = GETUTCDATE();

    DELETE FROM [dbo].[OtpRecords]
    WHERE [ExpiresAt] < DATEADD(HOUR, -1, @Now) OR ([IsUsed] = 1 AND [CreatedAt] < DATEADD(HOUR, -1, @Now));

    DELETE FROM [dbo].[RevokedTokens]
    WHERE [ExpiresAt] < @Now;

    DELETE FROM [dbo].[Notifications]
    WHERE [IsRead] = 1 AND [CreatedAt] < DATEADD(DAY, -90, @Now);

    DELETE FROM [dbo].[ProcessingLogs]
    WHERE [CreatedAt] < DATEADD(DAY, -90, @Now);
END";
        await ExecuteSafeAsync(db, uspCleanup, logger, "usp_CleanupExpiredData");
    }

    private static async Task ExecuteSafeAsync(AppDbContext db, string sql, ILogger logger, string label)
    {
        try
        {
            await db.Database.ExecuteSqlRawAsync(sql);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "[DB Performance] Step '{Label}' warning: {Message}", label, ex.Message);
        }
    }
}
