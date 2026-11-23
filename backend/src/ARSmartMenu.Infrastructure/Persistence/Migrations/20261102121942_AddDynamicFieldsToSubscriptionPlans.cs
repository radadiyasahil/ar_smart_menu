using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ARSmartMenu.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDynamicFieldsToSubscriptionPlans : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[SubscriptionPlans]') AND name = 'Badge')
                    ALTER TABLE [SubscriptionPlans] ADD [Badge] nvarchar(max) NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[SubscriptionPlans]') AND name = 'BasePricePaise')
                    ALTER TABLE [SubscriptionPlans] ADD [BasePricePaise] int NOT NULL DEFAULT 0;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[SubscriptionPlans]') AND name = 'Description')
                    ALTER TABLE [SubscriptionPlans] ADD [Description] nvarchar(max) NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[SubscriptionPlans]') AND name = 'DiscountPercent')
                    ALTER TABLE [SubscriptionPlans] ADD [DiscountPercent] int NOT NULL DEFAULT 0;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[SubscriptionPlans]') AND name = 'DurationDays')
                    ALTER TABLE [SubscriptionPlans] ADD [DurationDays] int NOT NULL DEFAULT 0;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[SubscriptionPlans]') AND name = 'FacilitiesJson')
                    ALTER TABLE [SubscriptionPlans] ADD [FacilitiesJson] nvarchar(max) NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[SubscriptionPlans]') AND name = 'GstPaise')
                    ALTER TABLE [SubscriptionPlans] ADD [GstPaise] int NOT NULL DEFAULT 0;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[SubscriptionPlans]') AND name = 'IsDeleted')
                    ALTER TABLE [SubscriptionPlans] ADD [IsDeleted] bit NOT NULL DEFAULT CAST(0 AS bit);

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[SubscriptionPlans]') AND name = 'OriginalPricePaise')
                    ALTER TABLE [SubscriptionPlans] ADD [OriginalPricePaise] int NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[SubscriptionPlans]') AND name = 'TotalPricePaise')
                    ALTER TABLE [SubscriptionPlans] ADD [TotalPricePaise] int NOT NULL DEFAULT 0;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Badge",
                table: "SubscriptionPlans");

            migrationBuilder.DropColumn(
                name: "BasePricePaise",
                table: "SubscriptionPlans");

            migrationBuilder.DropColumn(
                name: "Description",
                table: "SubscriptionPlans");

            migrationBuilder.DropColumn(
                name: "DiscountPercent",
                table: "SubscriptionPlans");

            migrationBuilder.DropColumn(
                name: "DurationDays",
                table: "SubscriptionPlans");

            migrationBuilder.DropColumn(
                name: "FacilitiesJson",
                table: "SubscriptionPlans");

            migrationBuilder.DropColumn(
                name: "GstPaise",
                table: "SubscriptionPlans");

            migrationBuilder.DropColumn(
                name: "IsDeleted",
                table: "SubscriptionPlans");

            migrationBuilder.DropColumn(
                name: "OriginalPricePaise",
                table: "SubscriptionPlans");

            migrationBuilder.DropColumn(
                name: "TotalPricePaise",
                table: "SubscriptionPlans");
        }
    }
}
