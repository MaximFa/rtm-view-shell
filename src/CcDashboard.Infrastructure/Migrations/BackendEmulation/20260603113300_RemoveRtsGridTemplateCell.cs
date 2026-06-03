using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class RemoveRtsGridTemplateCell : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RTSGrid_TemplateCell");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RTSGrid_TemplateCell",
                columns: table => new
                {
                    CellTemplateId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    CellType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    OnClick = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    StyleId = table.Column<int>(type: "integer", nullable: true),
                    Tooltip = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    Value = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSGrid_TemplateCell", x => x.CellTemplateId);
                });
        }
    }
}
