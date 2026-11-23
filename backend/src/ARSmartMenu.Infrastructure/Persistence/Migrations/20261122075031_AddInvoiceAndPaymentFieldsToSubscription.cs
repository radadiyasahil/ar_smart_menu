using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ARSmartMenu.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddInvoiceAndPaymentFieldsToSubscription : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "BasePricePaise",
                table: "Subscriptions",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "CustomerAddress",
                table: "Subscriptions",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CustomerBusinessName",
                table: "Subscriptions",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CustomerCity",
                table: "Subscriptions",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CustomerGstNumber",
                table: "Subscriptions",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "GstPaise",
                table: "Subscriptions",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "InvoiceDate",
                table: "Subscriptions",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "InvoiceNumber",
                table: "Subscriptions",
                type: "nvarchar(450)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PaymentMethod",
                table: "Subscriptions",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PaymentStatus",
                table: "Subscriptions",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "Completed");

            migrationBuilder.AddColumn<int>(
                name: "TotalPricePaise",
                table: "Subscriptions",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "TransactionRef",
                table: "Subscriptions",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Subscriptions_InvoiceNumber",
                table: "Subscriptions",
                column: "InvoiceNumber");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Subscriptions_InvoiceNumber",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "BasePricePaise",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "CustomerAddress",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "CustomerBusinessName",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "CustomerCity",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "CustomerGstNumber",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "GstPaise",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "InvoiceDate",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "InvoiceNumber",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "PaymentMethod",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "PaymentStatus",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "TotalPricePaise",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "TransactionRef",
                table: "Subscriptions");
        }
    }
}
