using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ARSmartMenu.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddBillRequestedToTableOrders : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_QrCodes_Products_ProductId",
                table: "QrCodes");

            migrationBuilder.AddColumn<bool>(
                name: "BillRequested",
                table: "TableOrders",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTime>(
                name: "BillRequestedAt",
                table: "TableOrders",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_QrCodes_Products_ProductId",
                table: "QrCodes",
                column: "ProductId",
                principalTable: "Products",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_QrCodes_Products_ProductId",
                table: "QrCodes");

            migrationBuilder.DropColumn(
                name: "BillRequested",
                table: "TableOrders");

            migrationBuilder.DropColumn(
                name: "BillRequestedAt",
                table: "TableOrders");

            migrationBuilder.AddForeignKey(
                name: "FK_QrCodes_Products_ProductId",
                table: "QrCodes",
                column: "ProductId",
                principalTable: "Products",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
