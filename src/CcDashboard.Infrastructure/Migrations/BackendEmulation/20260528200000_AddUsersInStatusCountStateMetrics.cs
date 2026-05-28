using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class AddUsersInStatusCountStateMetrics : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // CC-009: Add UsersInStatusCount metrics for the 5 standard agent states.
            // These are required for the ASD widget "By State" distribution mode.
            // MetricParameter must match AgentStateName from tenant_agent_states (case-sensitive).
            migrationBuilder.Sql("""
                INSERT INTO "RTSGrid_Metric"
                    ("MetricId", "Description", "MetricParameter",
                     "MetricFunction", "MetricFormat", "DefaultValue",
                     "DataType", "MetricType", "ValueType")
                VALUES
                    ('StateCountAvailable',
                     'Agent Group - Number of Agents in Available State',
                     'Available', 'UsersInStatusCount', '', '0', 'UsersSummary', 'Data', 'number'),
                    ('StateCountOnPhone',
                     'Agent Group - Number of Agents in On Phone State',
                     'On Phone', 'UsersInStatusCount', '', '0', 'UsersSummary', 'Data', 'number'),
                    ('StateCountBreak',
                     'Agent Group - Number of Agents in Break State',
                     'Break', 'UsersInStatusCount', '', '0', 'UsersSummary', 'Data', 'number'),
                    ('StateCountPaperwork',
                     'Agent Group - Number of Agents in Paperwork State',
                     'Paperwork', 'UsersInStatusCount', '', '0', 'UsersSummary', 'Data', 'number'),
                    ('StateCountTraining',
                     'Agent Group - Number of Agents in Training State',
                     'Training', 'UsersInStatusCount', '', '0', 'UsersSummary', 'Data', 'number')
                ON CONFLICT ("MetricId") DO NOTHING;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                DELETE FROM "RTSGrid_Metric"
                WHERE "MetricId" IN (
                    'StateCountAvailable', 'StateCountOnPhone', 'StateCountBreak',
                    'StateCountPaperwork', 'StateCountTraining'
                );
                """);
        }
    }
}
