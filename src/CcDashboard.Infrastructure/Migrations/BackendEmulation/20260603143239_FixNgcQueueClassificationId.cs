using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class FixNgcQueueClassificationId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                "UPDATE \"NGC_BusinessUnitQueueClassification\"" +
                " SET \"ClassificationId\" = 'ALL'" +
                " WHERE \"ClassificationId\" IS NULL OR \"ClassificationId\" = ''");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {

        }
    }
}
