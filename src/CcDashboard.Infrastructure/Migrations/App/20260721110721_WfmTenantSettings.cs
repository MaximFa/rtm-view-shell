using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <inheritdoc />
    public partial class WfmTenantSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "WfmDefaultShrinkage",
                table: "tenant_settings",
                type: "double precision",
                nullable: false,
                defaultValue: 0.28);

            migrationBuilder.AddColumn<bool>(
                name: "WfmEnableRealtime",
                table: "tenant_settings",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<string[]>(
                name: "WfmServingStateGroups",
                table: "tenant_settings",
                type: "text[]",
                nullable: false,
                defaultValue: new[] { "Available", "On Phone", "Paperwork" });

            migrationBuilder.AddColumn<double>(
                name: "WfmSlTargetPct",
                table: "tenant_settings",
                type: "double precision",
                nullable: false,
                defaultValue: 80.0);

            migrationBuilder.AddColumn<int>(
                name: "WfmSlThresholdSec",
                table: "tenant_settings",
                type: "integer",
                nullable: false,
                defaultValue: 20);

            migrationBuilder.AddColumn<string>(
                name: "WfmThresholds",
                table: "tenant_settings",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "WfmTrunkCapacity",
                table: "tenant_settings",
                type: "integer",
                nullable: false,
                defaultValue: 100);

            migrationBuilder.AddColumn<int>(
                name: "WfmWindowMinutes",
                table: "tenant_settings",
                type: "integer",
                nullable: false,
                defaultValue: 30);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "WfmDefaultShrinkage",
                table: "tenant_settings");

            migrationBuilder.DropColumn(
                name: "WfmEnableRealtime",
                table: "tenant_settings");

            migrationBuilder.DropColumn(
                name: "WfmServingStateGroups",
                table: "tenant_settings");

            migrationBuilder.DropColumn(
                name: "WfmSlTargetPct",
                table: "tenant_settings");

            migrationBuilder.DropColumn(
                name: "WfmSlThresholdSec",
                table: "tenant_settings");

            migrationBuilder.DropColumn(
                name: "WfmThresholds",
                table: "tenant_settings");

            migrationBuilder.DropColumn(
                name: "WfmTrunkCapacity",
                table: "tenant_settings");

            migrationBuilder.DropColumn(
                name: "WfmWindowMinutes",
                table: "tenant_settings");
        }
    }
}
