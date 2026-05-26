using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class AddRtsDataEntitiesAndStatusGroup : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                -- RTSData_Interaction (dev/test only; production table owned by CC backend)
                CREATE TABLE IF NOT EXISTS "RTSData_Interaction" (
                    "TenantId"           uuid,
                    "InteractionId"      varchar(50)  NOT NULL,
                    "Segment"            integer      NOT NULL,
                    "OnDate"             varchar(50)  NOT NULL,
                    "ServerId"           varchar(50)  NOT NULL,
                    "Workgroup"          varchar(100) NOT NULL,
                    "UserId"             varchar(50)  NOT NULL DEFAULT '',
                    "ClassificationCode" text,
                    "InteractionType"    varchar(50),
                    "CallType"           varchar(50),
                    "Direction"          varchar(50),
                    "CustomCallData"     text,
                    "IsTransferred"      boolean,
                    "IsAnswered"         boolean,
                    "IsInQueue"          boolean,
                    "IsTalk"             boolean,
                    "IsAbandoned"        boolean,
                    "TimeInQueue"        integer,
                    "TalkTime"           integer,
                    "InQueueDateTime"    timestamptz,
                    "AnsweredDateTime"   timestamptz,
                    "UpdateTime"         timestamptz,
                    "LastUserId"         varchar(50),
                    "LastWorkgroup"      varchar(100),
                    "IsMessaging"        boolean,
                    "RemoteAddress"      varchar(50),
                    "IsCallbackRequest"  boolean,
                    "TimeZone"           varchar(10),
                    CONSTRAINT "PK_RTSData_Interaction"
                        PRIMARY KEY ("InteractionId","Segment","OnDate","ServerId","Workgroup")
                );

                -- RTSData_UserStatus
                CREATE TABLE IF NOT EXISTS "RTSData_UserStatus" (
                    "TenantId"      uuid,
                    "UserId"        varchar(100) NOT NULL,
                    "StatusId"      varchar(100) NOT NULL,
                    "ServerId"      varchar(50)  NOT NULL,
                    "OnDate"        varchar(50)  NOT NULL,
                    "StatusName"    varchar(100),
                    "StatusGroup"   varchar(100),
                    "TotalDuration" integer,
                    "MaxDuration"   integer,
                    "TotalCount"    integer,
                    "UpdateTime"    timestamptz,
                    "DisplayName"   varchar(100),
                    "TimeZone"      varchar(10),
                    CONSTRAINT "PK_RTSData_UserStatus"
                        PRIMARY KEY ("UserId","StatusId","ServerId","OnDate")
                );

                -- RTSData_UserStatusLog
                CREATE TABLE IF NOT EXISTS "RTSData_UserStatusLog" (
                    "Id"          integer GENERATED ALWAYS AS IDENTITY,
                    "TenantId"    uuid,
                    "UserId"      varchar(100),
                    "StatusId"    varchar(100),
                    "ServerId"    varchar(50),
                    "OnDate"      varchar(50),
                    "StartTime"   timestamptz,
                    "EndTime"     timestamptz,
                    "Duration"    bigint,
                    "UpdateTime"  timestamptz,
                    "TimeZone"    varchar(10),
                    CONSTRAINT "PK_RTSData_UserStatusLog" PRIMARY KEY ("Id")
                );

                -- Add StatusGroup to UserStatusLog (idempotent — safe on production)
                ALTER TABLE "RTSData_UserStatusLog"
                    ADD COLUMN IF NOT EXISTS "StatusGroup" varchar(50) NULL;

                -- Index for interval StatusGroup queries
                CREATE INDEX IF NOT EXISTS "IX_RTSData_UserStatusLog_StatusGroup_Time"
                    ON "RTSData_UserStatusLog" ("TenantId","StatusGroup","StartTime","EndTime");
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Do NOT drop RTSData_* tables — backend-owned.
            // Only remove what this migration added.
            migrationBuilder.Sql("""
                ALTER TABLE "RTSData_UserStatusLog"
                    DROP COLUMN IF EXISTS "StatusGroup";
                DROP INDEX IF EXISTS "IX_RTSData_UserStatusLog_StatusGroup_Time";
                """);
        }
    }
}
