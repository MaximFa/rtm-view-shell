using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <inheritdoc />
    public partial class AddReportEntities : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "report_categories",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_report_categories", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "report_screens",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CategoryId = table.Column<Guid>(type: "uuid", nullable: true),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    IsPublic = table.Column<bool>(type: "boolean", nullable: false),
                    IsDarkMode = table.Column<bool>(type: "boolean", nullable: false),
                    LayoutJson = table.Column<string>(type: "jsonb", nullable: true),
                    CreatedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    IsDeleted = table.Column<bool>(type: "boolean", nullable: false),
                    DeletedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    DeletedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    xmin = table.Column<uint>(type: "xid", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_report_screens", x => x.Id);
                    table.ForeignKey(
                        name: "FK_report_screens_report_categories_CategoryId",
                        column: x => x.CategoryId,
                        principalTable: "report_categories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "report_permissions",
                columns: table => new
                {
                    PermissionGroupId = table.Column<Guid>(type: "uuid", nullable: false),
                    ReportScreenId = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    AccessLevel = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_report_permissions", x => new { x.PermissionGroupId, x.ReportScreenId });
                    table.ForeignKey(
                        name: "FK_report_permissions_permission_groups_PermissionGroupId",
                        column: x => x.PermissionGroupId,
                        principalTable: "permission_groups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_report_permissions_report_screens_ReportScreenId",
                        column: x => x.ReportScreenId,
                        principalTable: "report_screens",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "report_schedules",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ReportScreenId = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Cadence = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Recipients = table.Column<string>(type: "jsonb", nullable: true),
                    Format = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    DateWindow = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    RollingDays = table.Column<int>(type: "integer", nullable: true),
                    FixedFrom = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    FixedTo = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    LastRunAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    NextRunAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_report_schedules", x => x.Id);
                    table.ForeignKey(
                        name: "FK_report_schedules_report_screens_ReportScreenId",
                        column: x => x.ReportScreenId,
                        principalTable: "report_screens",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "report_widgets",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ReportScreenId = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    WidgetType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    PositionJson = table.Column<string>(type: "jsonb", nullable: true),
                    ConfigJson = table.Column<string>(type: "jsonb", nullable: true),
                    IsDeleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_report_widgets", x => x.Id);
                    table.ForeignKey(
                        name: "FK_report_widgets_report_screens_ReportScreenId",
                        column: x => x.ReportScreenId,
                        principalTable: "report_screens",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_report_categories_TenantId_Name",
                table: "report_categories",
                columns: new[] { "TenantId", "Name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_report_permissions_ReportScreenId",
                table: "report_permissions",
                column: "ReportScreenId");

            migrationBuilder.CreateIndex(
                name: "IX_report_schedules_ReportScreenId",
                table: "report_schedules",
                column: "ReportScreenId");

            migrationBuilder.CreateIndex(
                name: "IX_report_schedules_TenantId_IsActive_NextRunAt",
                table: "report_schedules",
                columns: new[] { "TenantId", "IsActive", "NextRunAt" });

            migrationBuilder.CreateIndex(
                name: "IX_report_screens_CategoryId",
                table: "report_screens",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_report_screens_TenantId_Name",
                table: "report_screens",
                columns: new[] { "TenantId", "Name" });

            migrationBuilder.CreateIndex(
                name: "IX_report_widgets_ReportScreenId",
                table: "report_widgets",
                column: "ReportScreenId");

            migrationBuilder.CreateIndex(
                name: "IX_report_widgets_TenantId",
                table: "report_widgets",
                column: "TenantId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "report_permissions");

            migrationBuilder.DropTable(
                name: "report_schedules");

            migrationBuilder.DropTable(
                name: "report_widgets");

            migrationBuilder.DropTable(
                name: "report_screens");

            migrationBuilder.DropTable(
                name: "report_categories");
        }
    }
}
