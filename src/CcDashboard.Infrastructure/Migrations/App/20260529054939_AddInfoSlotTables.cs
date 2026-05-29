using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <inheritdoc />
    public partial class AddInfoSlotTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "info_slots",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    DisplayMode = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    SecondsPerMessage = table.Column<int>(type: "integer", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedByUserId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_info_slots", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "info_slot_messages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    InfoSlotId = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    Content = table.Column<string>(type: "text", nullable: false),
                    Priority = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    DeactivatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    DeactivatedByUserId = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_info_slot_messages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_info_slot_messages_info_slots_InfoSlotId",
                        column: x => x.InfoSlotId,
                        principalTable: "info_slots",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "info_slot_permissions",
                columns: table => new
                {
                    InfoSlotId = table.Column<Guid>(type: "uuid", nullable: false),
                    PermissionGroupId = table.Column<Guid>(type: "uuid", nullable: false),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_info_slot_permissions", x => new { x.InfoSlotId, x.PermissionGroupId });
                    table.ForeignKey(
                        name: "FK_info_slot_permissions_info_slots_InfoSlotId",
                        column: x => x.InfoSlotId,
                        principalTable: "info_slots",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_info_slot_permissions_permission_groups_PermissionGroupId",
                        column: x => x.PermissionGroupId,
                        principalTable: "permission_groups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_info_slot_messages_InfoSlotId_IsActive_ExpiresAt",
                table: "info_slot_messages",
                columns: new[] { "InfoSlotId", "IsActive", "ExpiresAt" });

            migrationBuilder.CreateIndex(
                name: "IX_info_slot_messages_TenantId_CreatedAt",
                table: "info_slot_messages",
                columns: new[] { "TenantId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_info_slot_permissions_PermissionGroupId",
                table: "info_slot_permissions",
                column: "PermissionGroupId");

            migrationBuilder.CreateIndex(
                name: "IX_info_slots_TenantId_Name",
                table: "info_slots",
                columns: new[] { "TenantId", "Name" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "info_slot_messages");

            migrationBuilder.DropTable(
                name: "info_slot_permissions");

            migrationBuilder.DropTable(
                name: "info_slots");
        }
    }
}
