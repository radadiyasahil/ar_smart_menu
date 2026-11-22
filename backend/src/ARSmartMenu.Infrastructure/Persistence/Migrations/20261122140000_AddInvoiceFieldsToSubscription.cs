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
            migrationBuilder.AddColumn<string>(
                name: "InvoiceNumber",
                table: "Subscriptions",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "BaseAmountPaise",
                table: "Subscriptions",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "GstPaise",
                table: "Subscriptions",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "TotalAmountPaise",
                table: "Subscriptions",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "PaymentMethod",
                table: "Subscriptions",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PaymentRef",
                table: "Subscriptions",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CustomerGstNumber",
                table: "Subscriptions",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CustomerBusinessName",
                table: "Subscriptions",
                type: "nvarchar(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CustomerAddress",
                table: "Subscriptions",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CustomerState",
                table: "Subscriptions",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SacCode",
                table: "Subscriptions",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true,
                defaultValue: "998313");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(name: "InvoiceNumber", table: "Subscriptions");
            migrationBuilder.DropColumn(name: "BaseAmountPaise", table: "Subscriptions");
            migrationBuilder.DropColumn(name: "GstPaise", table: "Subscriptions");
            migrationBuilder.DropColumn(name: "TotalAmountPaise", table: "Subscriptions");
            migrationBuilder.DropColumn(name: "PaymentMethod", table: "Subscriptions");
            migrationBuilder.DropColumn(name: "PaymentRef", table: "Subscriptions");
            migrationBuilder.DropColumn(name: "CustomerGstNumber", table: "Subscriptions");
            migrationBuilder.DropColumn(name: "CustomerBusinessName", table: "Subscriptions");
            migrationBuilder.DropColumn(name: "CustomerAddress", table: "Subscriptions");
            migrationBuilder.DropColumn(name: "CustomerState", table: "Subscriptions");
            migrationBuilder.DropColumn(name: "SacCode", table: "Subscriptions");
        }
    }
}
