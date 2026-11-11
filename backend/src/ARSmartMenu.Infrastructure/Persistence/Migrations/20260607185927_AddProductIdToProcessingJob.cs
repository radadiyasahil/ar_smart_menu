using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ARSmartMenu.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddProductIdToProcessingJob : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "ProductId",
                table: "ProcessingJobs",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_ProcessingJobs_ProductId",
                table: "ProcessingJobs",
                column: "ProductId");

            migrationBuilder.AddForeignKey(
                name: "FK_ProcessingJobs_Products_ProductId",
                table: "ProcessingJobs",
                column: "ProductId",
                principalTable: "Products",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ProcessingJobs_Products_ProductId",
                table: "ProcessingJobs");

            migrationBuilder.DropIndex(
                name: "IX_ProcessingJobs_ProductId",
                table: "ProcessingJobs");

            migrationBuilder.DropColumn(
                name: "ProductId",
                table: "ProcessingJobs");
        }
    }
}
