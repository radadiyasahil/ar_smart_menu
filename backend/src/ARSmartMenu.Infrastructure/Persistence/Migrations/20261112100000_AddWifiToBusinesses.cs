using ARSmartMenu.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ARSmartMenu.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(AppDbContext))]
    [Migration("20261112100000_AddWifiToBusinesses")]
    public partial class AddWifiToBusinesses : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Businesses]') AND name = 'WifiName')
                    ALTER TABLE [Businesses] ADD [WifiName] nvarchar(max) NULL;

                IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[Businesses]') AND name = 'WifiPassword')
                    ALTER TABLE [Businesses] ADD [WifiPassword] nvarchar(max) NULL;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "WifiName",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "WifiPassword",
                table: "Businesses");
        }
    }
}
