using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ARSmartMenu.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(AppDbContext))]
    [Migration("20261113110000_AddBusinessGeofenceAndPartyPin")]
    public partial class AddBusinessGeofenceAndPartyPin : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Businesses]') AND name = 'GeofenceRadiusMeters')
                    ALTER TABLE [Businesses] ADD [GeofenceRadiusMeters] int NOT NULL DEFAULT 200;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Businesses]') AND name = 'Latitude')
                    ALTER TABLE [Businesses] ADD [Latitude] float NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Businesses]') AND name = 'Longitude')
                    ALTER TABLE [Businesses] ADD [Longitude] float NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Businesses]') AND name = 'RequireGeofence')
                    ALTER TABLE [Businesses] ADD [RequireGeofence] bit NOT NULL DEFAULT 0;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[TableOrders]') AND name = 'PartyPin')
                    ALTER TABLE [TableOrders] ADD [PartyPin] nvarchar(max) NULL;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "GeofenceRadiusMeters",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "Latitude",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "Longitude",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "RequireGeofence",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "PartyPin",
                table: "TableOrders");
        }
    }
}
