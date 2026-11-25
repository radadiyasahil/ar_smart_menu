using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ARSmartMenu.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(AppDbContext))]
    [Migration("20261122140000_AddInvoiceFieldsToSubscription")]
    public partial class AddInvoiceFieldsToSubscription : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'InvoiceNumber')
                    ALTER TABLE [Subscriptions] ADD [InvoiceNumber] nvarchar(50) NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'BasePricePaise')
                    ALTER TABLE [Subscriptions] ADD [BasePricePaise] int NOT NULL DEFAULT 0;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'GstPaise')
                    ALTER TABLE [Subscriptions] ADD [GstPaise] int NOT NULL DEFAULT 0;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'TotalPricePaise')
                    ALTER TABLE [Subscriptions] ADD [TotalPricePaise] int NOT NULL DEFAULT 0;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'PaymentMethod')
                    ALTER TABLE [Subscriptions] ADD [PaymentMethod] nvarchar(50) NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'TransactionRef')
                    ALTER TABLE [Subscriptions] ADD [TransactionRef] nvarchar(100) NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'PaymentStatus')
                    ALTER TABLE [Subscriptions] ADD [PaymentStatus] nvarchar(50) NOT NULL DEFAULT 'Completed';

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'InvoiceDate')
                    ALTER TABLE [Subscriptions] ADD [InvoiceDate] datetime2 NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'CustomerGstNumber')
                    ALTER TABLE [Subscriptions] ADD [CustomerGstNumber] nvarchar(50) NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'CustomerBusinessName')
                    ALTER TABLE [Subscriptions] ADD [CustomerBusinessName] nvarchar(200) NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'CustomerAddress')
                    ALTER TABLE [Subscriptions] ADD [CustomerAddress] nvarchar(500) NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'CustomerCity')
                    ALTER TABLE [Subscriptions] ADD [CustomerCity] nvarchar(100) NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'CustomerState')
                    ALTER TABLE [Subscriptions] ADD [CustomerState] nvarchar(100) NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'SacCode')
                    ALTER TABLE [Subscriptions] ADD [SacCode] nvarchar(20) NULL DEFAULT '998313';

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Subscriptions]') AND name = 'GstRatePercent')
                    ALTER TABLE [Subscriptions] ADD [GstRatePercent] decimal(5, 2) NOT NULL DEFAULT 18.0;

                IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Subscriptions_InvoiceNumber' AND object_id = OBJECT_ID(N'[Subscriptions]'))
                    CREATE INDEX [IX_Subscriptions_InvoiceNumber] ON [Subscriptions] ([InvoiceNumber]);
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Defensive no-op down to preserve invoice audit integrity across historical records
        }
    }
}
