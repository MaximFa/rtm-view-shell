# CC Task L1-B: seed ru-RU + he-IL catalogue translations

> Stage-2 localization, DATA layer. Backfills RTSGrid_MetricTranslation (created in L1-A, cc7f995) with
> ru-RU + he-IL translations for all 197 live metrics' 4 fields. Source of truth = the two committed
> docs/metrics-catalog.<locale>.json files (produced + verified by metrics-0605). DATA ONLY — no EF
> migration, so NO BackendEmulation snapshot contention with epic P1.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md   (phantom-aware S3, S4b flush, S1 hard-stop)
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md
Only after reading: proceed.

## Git push: NONE (§37). Commit only.
## BARRIER CHECK (S1): if .coord/push/request.md has CONTENT -> STOP. (Known phantom may linger on the mount;
## Windows/CC side reflects real state — trust the real FS.)

## Claims (file-mode, metrics-0605)
- docs: docs/metrics-catalog.ru-RU.json, docs/metrics-catalog.he-IL.json  (already written, untracked)
- tools: tools/gen_translation_backfill.py  (already written, untracked)
- db: db/data/05_metric_translations.sql  (NEW — you generate it)
       db/tools/Restore-All.ps1 / Create-FreshDb.ps1 — ONLY IF they list db/data files explicitly (see step 4); if they glob db/data/*.sql, no change.

## Step 0 — §0.6a integrity + sync (§42.7.6) + coord sync block (slug + claims above; phantom-aware S3).

## Step 1 — Generate the seed SQL
`python3 tools/gen_translation_backfill.py --out db/data/05_metric_translations.sql`
Expected: "wrote db/data/05_metric_translations.sql: 394 rows (2 locales x 197)". The script reads
docs/metrics-catalog.ru-RU.json + .he-IL.json, escapes single quotes, NULLs empty fields, idempotent
(DELETE the two locales then INSERT). Verify the file: `wc -l`, `head`, `tail` ends with `;`.

## Step 2 — Apply to dev DB
`psql -U ccdashboard_user -d rtmviewdb -f db\data\05_metric_translations.sql`
(The RTSGrid_MetricTranslation table already exists from L1-A migration cc7f995.)

## Step 3 — Verify
- `SELECT count(*) FROM "RTSGrid_MetricTranslation";` -> 394
- `SELECT "Locale", count(*) FROM "RTSGrid_MetricTranslation" GROUP BY "Locale";` -> ru-RU 197, he-IL 197
- Spot: `SELECT "DisplayName" FROM "RTSGrid_MetricTranslation" WHERE "MetricId"='QueuePctAnsweredCalls60secInc' AND "Locale"='ru-RU';`
  -> should be the Russian "% отвеченных звонков за 60 сек (от входящих)".

## Step 4 — Fresh-install wiring (check, don't assume)
Confirm db/data/05_metric_translations.sql is picked up on fresh install: inspect db/tools/Restore-All.ps1
(and Create-FreshDb.ps1). If they apply `db/data/*.sql` by glob -> nothing to do. If they list data files
explicitly -> add 05_metric_translations.sql in the correct order (AFTER 02_metrics.sql, since the
translation rows FK/relate to metrics). Report which case it was.

## Step 5 — Do NOT run Export-All
Export-All currently dumps a fixed set of tables and does NOT know RTSGrid_MetricTranslation; running it
would NOT capture this data and could clobber db/data. The canonical seed is db/data/05_metric_translations.sql
(generated from the docs JSON). Extending Export-All to dump the translation table is deferred to L1-C
(when in-app editing lands). Leave a one-line note in the completion report.

## Commit (lock §42.4; §39.3) — split by module
- `docs: ru-RU + he-IL catalogue translations (metrics-catalog.<locale>.json) + backfill generator`
  (docs/metrics-catalog.ru-RU.json, docs/metrics-catalog.he-IL.json, tools/gen_translation_backfill.py)
- `db: seed RTSGrid_MetricTranslation ru-RU + he-IL (197x2)` (db/data/05_metric_translations.sql [+ Restore-All if changed])
Each: pre-commit-check -> §0.6 verify -> journal -> S4b post-commit flush to coordinator -> release lock -> PD-007 re-sync. No push.

## Acceptance criteria
1. db/data/05_metric_translations.sql generated (394 rows) and applied; RTSGrid_MetricTranslation has 197 ru-RU + 197 he-IL.
2. Spot-check returns Russian/Hebrew DisplayName for a known metric.
3. Fresh-install path confirmed (glob or explicit-list-with-05-added).
4. Export-All NOT run; note left for L1-C.
5. Two commits (docs:, db:); tree clean (ignore known false-M); journal + S4b per commit; lock released; no push.

## After this task (manual, operator): set browser/profile UI culture to ru-RU or he-IL, open the
## metric wizard -> localized DisplayName/descriptions should appear (en-US still shows English). I (metrics-0605)
## will live-verify via Chrome.
