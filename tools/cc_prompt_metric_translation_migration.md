# CC Task: durable migration — create RTSGrid_MetricTranslation on EXISTING DBs

> Operator-found (test server, 2026-06-07): GetRtsGridMetricsQuery throws 42P01
> `relation "RTSGrid_MetricTranslation" does not exist` -> MetricWizard opens empty / breaks.
> ROOT: L1-A added the table ONLY in db/schema.sql (fresh-install / Restore-All path) + the
> BackendEmulation EF migration. There is NO db/migrations/*.sql to create it on an EXISTING DB,
> so every republish onto a standing server breaks the wizard (same durability gap as the typo-metric
> lesson). FIX: a standalone idempotent migration that creates the table on existing DBs.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md  (phantom-aware S3, S4b wrapper, S1 hard-stop)
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md  (metric/translation data contract)
Only after reading all: proceed.

## Git push: NONE (§37). Commit only.
## BARRIER CHECK (S1): if .coord/push/request.md has CONTENT -> STOP.

## Claims (file-mode, metrics-2-0607)
- db: db/migrations/20260607_001_add_metric_translation_table.sql  (NEW file — free)
> Run coord_check_claims on it FIRST. Touch NOTHING else. Do NOT regenerate db/schema.sql
> (it ALREADY contains the table from L1-A Export-All) and do NOT run Export-All.

## Step 0 — §0.6a integrity + git fetch (§42.7.6) + coord sync block (slug metrics-2-0607 + the claim above).

## Deliverable — db/migrations/20260607_001_add_metric_translation_table.sql
Create the file with EXACTLY this DDL (matches db/schema.sql lines ~2186 + PK ~3130 verbatim),
fully idempotent so it is safe on a DB that lacks OR already has the table:

```sql
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
```

NOTE on data: this migration creates the EMPTY table only. The ru/he rows live in
db/data/05_metric_translations.sql (already in git, idempotent DELETE+INSERT). Deploy procedure
(documented for the operator, NOT part of this commit): after applying this migration, run
`psql ... -f db/data/05_metric_translations.sql` with PGCLIENTENCODING=UTF8 to load translations
(missing rows just mean EN-fallback in the query — not an error).

## Verify (report, do NOT touch a live server from CC)
- The file parses: `psql --version` present; optionally dry-check syntax with a throwaway local DB
  ONLY if available — otherwise visual DDL check vs db/schema.sql is sufficient.
- Confirm db/schema.sql ALREADY has the table (no change needed there):
  `grep -c 'CREATE TABLE public."RTSGrid_MetricTranslation"' db/schema.sql`  (expect 1).

## Commit
`db: add metric translation table migration for existing DBs (20260607_001)`
(only db/migrations/20260607_001_add_metric_translation_table.sql)
S3 lock -> pre-commit-check -> git add (the one file) -> commit -> §0.6 verify ->
`bash tools/cc_post_commit.sh metrics-2-0607 $(git log -1 --format=%h)` -> sync. No push.

## Acceptance criteria
1. New file db/migrations/20260607_001_add_metric_translation_table.sql with the idempotent DDL above.
2. CREATE TABLE IF NOT EXISTS + PK + guarded GRANT; no other DDL.
3. db/schema.sql NOT modified; Export-All NOT run.
4. One db: commit; tree clean (ignore known false-M on db/*.sql); journal + S4b via wrapper; lock released; no push.
