using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ARSmartMenu.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(AppDbContext))]
    [Migration("20261118120000_AddDishLimitAndArPricingToBusinesses")]
    public partial class AddDishLimitAndArPricingToBusinesses : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Businesses]') AND name = 'CustomDishLimit')
                    ALTER TABLE [Businesses] ADD [CustomDishLimit] int NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Businesses]') AND name = 'ArViewEnabled')
                    ALTER TABLE [Businesses] ADD [ArViewEnabled] bit NOT NULL DEFAULT 1;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Businesses]') AND name = 'ArPerViewChargePaise')
                    ALTER TABLE [Businesses] ADD [ArPerViewChargePaise] int NOT NULL DEFAULT 50;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Businesses]') AND name = 'ArViewCredits')
                    ALTER TABLE [Businesses] ADD [ArViewCredits] int NOT NULL DEFAULT 500;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Businesses]') AND name = 'ArViewsUsed')
                    ALTER TABLE [Businesses] ADD [ArViewsUsed] int NOT NULL DEFAULT 0;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CustomDishLimit",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "ArViewEnabled",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "ArPerViewChargePaise",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "ArViewCredits",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "ArViewsUsed",
                table: "Businesses");
        }
    }
}
