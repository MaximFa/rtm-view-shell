using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App;

/// <summary>
/// CC-HIST-B0: UserReport soft-delete fields (matches Dashboard pattern, §6/§7).
/// EF-APP migration — do NOT insert into db_patch_history (§38a is for db/migrations/*.sql only).
/// </summary>
public partial class UserReportSoftDelete : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<bool>(
            name: "IsDeleted",
            table: "user_reports",
            type: "boolean",
            nullable: false,
            defaultValue: false);

        migrationBuilder.AddColumn<DateTime>(
            name: "DeletedAt",
            table: "user_reports",
            type: "timestamp with time zone",
            nullable: true);

        migrationBuilder.AddColumn<Guid>(
            name: "DeletedByUserId",
            table: "user_reports",
            type: "uuid",
            nullable: true);

        // Recreate unique index with soft-delete filter
        migrationBuilder.DropIndex(
            name: "ix_user_reports_tenant_name",
            table: "user_reports");

        migrationBuilder.CreateIndex(
            name: "ix_user_reports_tenant_name",
            table: "user_reports",
            columns: new[] { "TenantId", "Name" },
            unique: true,
            filter: "\"IsDeleted\" = false");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropIndex(
            name: "ix_user_reports_tenant_name",
            table: "user_reports");

        migrationBuilder.DropColumn(
            name: "DeletedByUserId",
            table: "user_reports");

        migrationBuilder.DropColumn(
            name: "DeletedAt",
            table: "user_reports");

        migrationBuilder.DropColumn(
            name: "IsDeleted",
            table: "user_reports");

        migrationBuilder.CreateIndex(
            name: "ix_user_reports_tenant_name",
            table: "user_reports",
            columns: new[] { "TenantId", "Name" },
            unique: true);
    }
}
