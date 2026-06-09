-- 20260607_001_add_metric_translation_table.sql
-- Durable creation of RTSGrid_MetricTranslation for EXISTING databases.
-- L1-A shipped the table only in db/schema.sql (fresh install) + the EF migration;
-- standing DBs (deployed servers) lacked it -> GetRtsGridMetricsQuery 42P01 / empty MetricWizard.
-- Idempotent: IF NOT EXISTS guards everywhere.

CREATE TABLE IF NOT EXISTS public."RTSGrid_MetricTranslation" (
    "MetricId"         character varying(100) NOT NULL,
    "Locale"           character varying(10)  NOT NULL,
    "DisplayName"      character varying(200),
    "ShortDescription" character varying(500),
    "LongDescription"  text,
    "Comparison"       text,
    CONSTRAINT "PK_RTSGrid_MetricTranslation" PRIMARY KEY ("MetricId", "Locale")
);

-- App role grant (mirror other tables' grants in this DB; role name per deploy = ccdashboard_user).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ccdashboard_user') THEN
        EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON public."RTSGrid_MetricTranslation" TO ccdashboard_user';
    END IF;
END $$;
