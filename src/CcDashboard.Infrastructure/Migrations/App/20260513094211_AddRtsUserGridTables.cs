using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <inheritdoc />
    public partial class AddRtsUserGridTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RTSUserGrid_Column",
                columns: table => new
                {
                    ColumnId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    ColumnsSetId = table.Column<int>(type: "integer", nullable: false),
                    Title = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    MetricId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    StyleId = table.Column<int>(type: "integer", nullable: true),
                    ColumnsOrder = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSUserGrid_Column", x => x.ColumnId);
                });

            migrationBuilder.CreateTable(
                name: "RTSUserGrid_ColumnsSet",
                columns: table => new
                {
                    ColumnsSetId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    Title = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "text", nullable: true),
                    Direction = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSUserGrid_ColumnsSet", x => x.ColumnsSetId);
                });

            migrationBuilder.CreateTable(
                name: "RTSUserGrid_Grid",
                columns: table => new
                {
                    GridId = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    UnionId = table.Column<int>(type: "integer", nullable: true),
                    StyleId = table.Column<int>(type: "integer", nullable: true),
                    Title = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    RowsFilter = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    PageSize = table.Column<int>(type: "integer", nullable: true),
                    ColumnsSetId = table.Column<int>(type: "integer", nullable: true),
                    ThresholdScript = table.Column<string>(type: "text", nullable: true),
                    RowsFilterNew = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    NoRecordsText = table.Column<string>(type: "text", nullable: true),
                    AllowPaging = table.Column<bool>(type: "boolean", nullable: true),
                    AllowScroll = table.Column<bool>(type: "boolean", nullable: true),
                    TextDirection = table.Column<string>(type: "character varying(5)", maxLength: 5, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RTSUserGrid_Grid", x => x.GridId);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RTSUserGrid_Column");

            migrationBuilder.DropTable(
                name: "RTSUserGrid_ColumnsSet");

            migrationBuilder.DropTable(
                name: "RTSUserGrid_Grid");
        }
    }
}
