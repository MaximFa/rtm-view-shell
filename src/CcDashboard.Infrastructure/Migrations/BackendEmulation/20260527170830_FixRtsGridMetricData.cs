using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class FixRtsGridMetricData : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // 1. Delete dot-notation metrics (belong to history_metrics, not RTSGrid_Metrics)
            migrationBuilder.Sql("""
                DELETE FROM "RTSGrid_Metric"
                WHERE "MetricId" LIKE '%.%';
                """);

            // 2. Fix MetricType based on Description prefix
            migrationBuilder.Sql("""
                UPDATE "RTSGrid_Metric"
                SET "MetricType" = 'Data'
                WHERE "Description" LIKE 'QM - %'
                   OR "Description" LIKE 'Agent Group - %';

                UPDATE "RTSGrid_Metric"
                SET "MetricType" = 'Agent'
                WHERE "Description" LIKE 'Agent - %'
                   OR ("MetricType" != 'Data');
                """);

            // 3. Fix ValueType — default to 'number', then override time and text
            migrationBuilder.Sql("""
                UPDATE "RTSGrid_Metric" SET "ValueType" = 'number';

                UPDATE "RTSGrid_Metric" SET "ValueType" = 'time'
                WHERE "MetricFunction" IN (
                    'CurLoginDuration', 'CurStatusDuration', 'CurStatusGroupDuration',
                    'LongestInteractionStateDuration',
                    'MessagesAvgFirstResponseTime', 'MessagesAvgResponseTime', 'MessagesMaxFirstResponseTime',
                    'TalkDurationAvg', 'TalkDurationCurMax', 'TalkDurationMax',
                    'TotalLoginDuration', 'TotalStatusDuration', 'TotalStatusDurationAvg',
                    'TotalStatusGroupDuration', 'TotalStatusGroupDurationAvg',
                    'WaitDurationAvg', 'WaitDurationCurMax'
                );

                UPDATE "RTSGrid_Metric" SET "ValueType" = 'text'
                WHERE "MetricFunction" IN (
                    'CurLoginTimeStamp', 'CurStatusGroup', 'CurStatusTitle', 'DisplayName',
                    'FirstLoginTimestamp', 'IsTodayLogin',
                    'LongestInteractionId', 'LongestInteractionRemoteAddress',
                    'LongestInteractionState', 'LongestInteractionType', 'LongestInteractionWorkgroup',
                    'Station', 'UserExtension', 'UserID'
                );
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Restore ValueType and MetricType to legacy incorrect values
            migrationBuilder.Sql("""
                UPDATE "RTSGrid_Metric" SET "ValueType" = 'String', "MetricType" = 'Agent';
                """);
        }
    }
}
