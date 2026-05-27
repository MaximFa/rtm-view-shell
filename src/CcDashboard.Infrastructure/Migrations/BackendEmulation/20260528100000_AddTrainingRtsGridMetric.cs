using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    public partial class AddTrainingRtsGridMetric : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                INSERT INTO "RTSGrid_Metric"
                    ("MetricId", "Description", "MetricParameter",
                     "MetricFunction", "MetricFormat", "DefaultValue",
                     "DataType", "MetricType", "ValueType")
                VALUES
                    ('QueueLoginDataNumTrainingUsers',
                     'Agent Group - Number of Agents in Training State Group',
                     'TRAINING',
                     'UsersInStatusGroupCount',
                     '', '', 'String', 'Data', 'number')
                ON CONFLICT ("MetricId") DO NOTHING;
                """);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                DELETE FROM "RTSGrid_Metric"
                WHERE "MetricId" = 'QueueLoginDataNumTrainingUsers';
                """);
        }
    }
}
