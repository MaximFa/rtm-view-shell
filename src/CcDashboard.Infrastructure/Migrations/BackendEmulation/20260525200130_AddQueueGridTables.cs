using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class AddQueueGridTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RTSGrid_Cell",
                columns: table => new
                {
                    CellId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    RowId = table.Column<int>(type: "integer", nullable: false),
                    ColumnId = table.Column<int>(type: "integer", nullable: false),
                    ColNumber = table.Column<int>(type: "integer", nullable: true),
                    UnionId = table.Column<int>(type: "integer", nullable: true),
                    StyleId = table.Column<int>(type: "integer", nullable: true),
                    CellType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    Value = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    Tooltip = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    OnClick = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ThresholdSetId = table.Column<int>(type: "integer", nullable: true),
                    NewRowId = table.Column<int>(type: "integer", nullable: true),
                    OldRowId = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSGrid_Cell", x => x.CellId);
                });

            migrationBuilder.CreateTable(
                name: "RTSGrid_Column",
                columns: table => new
                {
                    ColumnId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    GridId = table.Column<int>(type: "integer", nullable: false),
                    ColumnNumber = table.Column<int>(type: "integer", nullable: false),
                    CellTemplateId = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSGrid_Column", x => x.ColumnId);
                });

            migrationBuilder.CreateTable(
                name: "RTSGrid_Grid",
                columns: table => new
                {
                    GridId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    UnionId = table.Column<int>(type: "integer", nullable: true),
                    StyleId = table.Column<int>(type: "integer", nullable: true),
                    Title = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    ThresholdScript = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSGrid_Grid", x => x.GridId);
                });

            migrationBuilder.CreateTable(
                name: "RTSGrid_Row",
                columns: table => new
                {
                    RowId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    GridId = table.Column<int>(type: "integer", nullable: false),
                    RowNumber = table.Column<int>(type: "integer", nullable: false),
                    UnionId = table.Column<int>(type: "integer", nullable: true),
                    StyleId = table.Column<int>(type: "integer", nullable: true),
                    ThresholdScript = table.Column<string>(type: "text", nullable: true),
                    OldRowId = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSGrid_Row", x => x.RowId);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RTSGrid_Cell");

            migrationBuilder.DropTable(
                name: "RTSGrid_Column");

            migrationBuilder.DropTable(
                name: "RTSGrid_Grid");

            migrationBuilder.DropTable(
                name: "RTSGrid_Row");
        }
    }
}
