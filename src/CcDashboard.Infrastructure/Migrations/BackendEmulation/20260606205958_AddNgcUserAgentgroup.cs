using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class AddNgcUserAgentgroup : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "NGC_UserAgentgroup",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    UserId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    AgentgroupId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    TenantId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedDatetime = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedBy = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NGC_UserAgentgroup", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_NGC_UserAgentgroup_TenantId_UserId_AgentgroupId",
                table: "NGC_UserAgentgroup",
                columns: new[] { "TenantId", "UserId", "AgentgroupId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "NGC_UserAgentgroup");
        }
    }
}
