using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class AddCatalogueFieldsToRtsGridMetric : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CatalogCategory",
                table: "RTSGrid_Metric",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CatalogNotes",
                table: "RTSGrid_Metric",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CatalogStatus",
                table: "RTSGrid_Metric",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Channel",
                table: "RTSGrid_Metric",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Comparison",
                table: "RTSGrid_Metric",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DisplayName",
                table: "RTSGrid_Metric",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Family",
                table: "RTSGrid_Metric",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LongDescription",
                table: "RTSGrid_Metric",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ShortDescription",
                table: "RTSGrid_Metric",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "StandardKpi",
                table: "RTSGrid_Metric",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "StandardRef",
                table: "RTSGrid_Metric",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ThresholdSec",
                table: "RTSGrid_Metric",
                type: "integer",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CatalogCategory",
                table: "RTSGrid_Metric");

            migrationBuilder.DropColumn(
                name: "CatalogNotes",
                table: "RTSGrid_Metric");

            migrationBuilder.DropColumn(
                name: "CatalogStatus",
                table: "RTSGrid_Metric");

            migrationBuilder.DropColumn(
                name: "Channel",
                table: "RTSGrid_Metric");

            migrationBuilder.DropColumn(
                name: "Comparison",
                table: "RTSGrid_Metric");

            migrationBuilder.DropColumn(
                name: "DisplayName",
                table: "RTSGrid_Metric");

            migrationBuilder.DropColumn(
                name: "Family",
                table: "RTSGrid_Metric");

            migrationBuilder.DropColumn(
                name: "LongDescription",
                table: "RTSGrid_Metric");

            migrationBuilder.DropColumn(
                name: "ShortDescription",
                table: "RTSGrid_Metric");

            migrationBuilder.DropColumn(
                name: "StandardKpi",
                table: "RTSGrid_Metric");

            migrationBuilder.DropColumn(
                name: "StandardRef",
                table: "RTSGrid_Metric");

            migrationBuilder.DropColumn(
                name: "ThresholdSec",
                table: "RTSGrid_Metric");
        }
    }
}
