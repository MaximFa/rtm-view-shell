using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <inheritdoc />
    public partial class PerTenantUserNameIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UserNameIndex",
                schema: "identity",
                table: "users");

            migrationBuilder.CreateIndex(
                name: "IX_users_NormalizedUserName_TenantId",
                schema: "identity",
                table: "users",
                columns: new[] { "NormalizedUserName", "TenantId" },
                unique: true,
                filter: "\"IsActive\" = true");

            migrationBuilder.CreateIndex(
                name: "UserNameIndex",
                schema: "identity",
                table: "users",
                column: "NormalizedUserName");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_users_NormalizedUserName_TenantId",
                schema: "identity",
                table: "users");

            migrationBuilder.DropIndex(
                name: "UserNameIndex",
                schema: "identity",
                table: "users");

            migrationBuilder.CreateIndex(
                name: "UserNameIndex",
                schema: "identity",
                table: "users",
                column: "NormalizedUserName",
                unique: true);
        }
    }
}
