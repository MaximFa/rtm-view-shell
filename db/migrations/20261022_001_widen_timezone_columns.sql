-- 20261022_001_widen_timezone_columns.sql
-- PR234-SITE-TZ-FIXED-OFFSET-01: backend TimeZone columns varchar(10) -> varchar(64), so a time zone id
-- ("Israel Standard Time", "Asia/Jerusalem") fits. Backend tables are owned by db/schema.sql (ADR-007, Design B);
-- fresh installs get varchar(64) from schema.sql, existing databases from THIS file. The archive tables (App-owned)
-- widen through EF App migration 20261022090000_WidenTimeZoneColumns.
-- Must be applied BEFORE any zone id is written to NGC_Site (the engine copies the site zone into every row).
-- Idempotent: only widens a varchar shorter than 64; an unlimited varchar or text is left alone. Metadata-only in PG.
\set ON_ERROR_STOP on

DO $widen$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['NGC_Site','RTSData_Interaction','RTSData_UserStatus','RTSData_UserStatusLog'] LOOP
        IF EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = t AND column_name = 'TimeZone'
                     AND data_type = 'character varying' AND character_maximum_length < 64) THEN
            EXECUTE format('ALTER TABLE public.%I ALTER COLUMN "TimeZone" TYPE character varying(64)', t);
        END IF;
    END LOOP;
END $widen$;

-- self-record (db_patch_history ledger convention from _002)
INSERT INTO public.db_patch_history (migration_name)
VALUES ('20261022_001_widen_timezone_columns')
ON CONFLICT (migration_name) DO NOTHING;

-- Verify: expect 4 rows, all 64
SELECT table_name, character_maximum_length FROM information_schema.columns
WHERE table_schema = 'public' AND column_name = 'TimeZone'
  AND table_name IN ('NGC_Site','RTSData_Interaction','RTSData_UserStatus','RTSData_UserStatusLog') ORDER BY 1;
