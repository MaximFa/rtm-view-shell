using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <inheritdoc />
    public partial class AddDashboardCategory : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "CategoryId",
                table: "dashboards",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "dashboard_categories",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedByUserId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_dashboard_categories", x => x.Id);
                    table.ForeignKey(
                        name: "FK_dashboard_categories_tenants_TenantId",
                        column: x => x.TenantId,
                        principalTable: "tenants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_dashboards_CategoryId",
                table: "dashboards",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_dashboard_categories_TenantId_Name",
                table: "dashboard_categories",
                columns: new[] { "TenantId", "Name" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_dashboards_dashboard_categories_CategoryId",
                table: "dashboards",
                column: "CategoryId",
                principalTable: "dashboard_categories",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_dashboards_dashboard_categories_CategoryId",
                table: "dashboards");

            migrationBuilder.DropTable(
                name: "dashboard_categories");

            migrationBuilder.DropIndex(
                name: "IX_dashboards_CategoryId",
                table: "dashboards");

            migrationBuilder.DropColumn(
                name: "CategoryId",
                table: "dashboards");
        }
    }
}
