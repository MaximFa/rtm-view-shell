using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.App
{
    /// <summary>
    /// PR234-SITE-TZ-FIXED-OFFSET-01: archive TimeZone columns varchar(10) -> varchar(64), so a time zone id (e.g. "Israel
    /// Standard Time", "Asia/Jerusalem") fits. The archiver copies RTSData_* rows as they are, so the archive must be at
    /// least as wide as the backend columns (widened by db/schema.sql and db/migrations, not here - ADR-007).
    /// Existence guards keep the migration safe on any database.
    /// Widening a varchar is metadata-only in PostgreSQL (no table rewrite). Down is intentionally a no-op: narrowing could
    /// truncate or fail on stored zone ids.
    /// </summary>
    public partial class WidenTimeZoneColumns : Migration
    {
        // ONLY the archive tables: they are App-owned (created by App migration 20260622090000_AddArchiveTables).
        // NGC_Site and RTSData_* are backend tables owned by db/schema.sql (ADR-007, Design B - see
        // 20260712223405_DropAppOwnedBackendTables); they widen through db/schema.sql (fresh install) and
        // db/migrations/20261022_001_widen_timezone_columns.sql (existing databases), never from this context.
        private static readonly string[] Tables =
        {
            "arch_rtsdata_interaction", "arch_rtsdata_userstatus", "arch_rtsdata_userstatuslog",
        };

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            foreach (var t in Tables)
            {
                migrationBuilder.Sql($@"
DO $widen$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = '{t}' AND column_name = 'TimeZone'
                 AND character_maximum_length < 64   -- unlimited varchar (NULL length) is left alone, never narrowed
                 AND data_type = 'character varying') THEN
        EXECUTE 'ALTER TABLE public.""{t}"" ALTER COLUMN ""TimeZone"" TYPE character varying(64)';
    END IF;
END $widen$;");
            }
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // no-op (see summary)
        }
    }
}
