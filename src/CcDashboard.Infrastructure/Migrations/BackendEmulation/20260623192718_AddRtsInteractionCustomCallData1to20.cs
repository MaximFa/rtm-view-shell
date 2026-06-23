using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class AddRtsInteractionCustomCallData1to20 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Idempotent ADD COLUMN IF NOT EXISTS for dev/re-run safety
            migrationBuilder.Sql(@"
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData1"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData2"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData3"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData4"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData5"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData6"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData7"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData8"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData9"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData10"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData11"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData12"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData13"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData14"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData15"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData16"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData17"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData18"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData19"" text;
ALTER TABLE ""RTSData_Interaction"" ADD COLUMN IF NOT EXISTS ""CustomCallData20"" text;
");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData1"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData2"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData3"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData4"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData5"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData6"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData7"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData8"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData9"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData10"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData11"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData12"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData13"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData14"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData15"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData16"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData17"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData18"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData19"";
ALTER TABLE ""RTSData_Interaction"" DROP COLUMN IF EXISTS ""CustomCallData20"";
");
        }
    }
}
