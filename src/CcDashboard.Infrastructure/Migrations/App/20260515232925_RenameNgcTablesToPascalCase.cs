using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <inheritdoc />
    public partial class RenameNgcTablesToPascalCase : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameTable(name: "ngc_AgentGroups", newName: "NGC_AgentGroups");
            migrationBuilder.RenameTable(name: "ngc_queues", newName: "NGC_Queues");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameTable(name: "NGC_AgentGroups", newName: "ngc_AgentGroups");
            migrationBuilder.RenameTable(name: "NGC_Queues", newName: "ngc_queues");
        }
    }
}
