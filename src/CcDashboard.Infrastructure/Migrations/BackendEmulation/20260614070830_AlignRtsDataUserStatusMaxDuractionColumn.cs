using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class AlignRtsDataUserStatusMaxDuractionColumn : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "MaxDuration",
                table: "RTSData_UserStatus",
                newName: "MaxDuraction");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "MaxDuraction",
                table: "RTSData_UserStatus",
                newName: "MaxDuration");
        }
    }
}
