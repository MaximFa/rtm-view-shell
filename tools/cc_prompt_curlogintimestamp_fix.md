# CC Task: CurLoginTimeStamp data-fix (dead metric MonAgentCurrentLoginTimeStamp)

> Engine inventory (2026-06-05): metric MonAgentCurrentLoginTimeStamp seeds MetricFunction='CurLoginTimeStamp'
> (capital S), but the RTM engine switch in UserManager.cs:1117 is `case "CurLoginTimestamp":` (lowercase s) and
> is CASE-SENSITIVE -> the metric never produces a value (dead). FIX: change MetricFunction to 'CurLoginTimestamp'
> everywhere it is seeded (durability — typo-metric lesson: a migration alone misses fresh-install/restart paths).
> Data-only. NO resx, NO ScreenEditorPage.

## Mandatory — read before starting
Read file: .claude/skills/session-coord/session-coord.md  (phantom-aware S3, S4b wrapper, S1 hard-stop)
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md  (metric seed paths, durability, Export-All scope)
Only after reading all: proceed.

## Git push: NONE (§37). Commit only.
## BARRIER CHECK (S1): if .coord/push/request.md has CONTENT -> STOP.

## Claims (file-mode, metrics-2-0607)
- db:   db/migrations/20260607_003_fix_curlogintimestamp.sql  (NEW)
- db:   db/data/02_metrics.sql
- db:   db/baseline.sql
- web:  src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs
- docs: docs/metrics-catalog.json
> coord_check_claims on ALL first (S2). Touch nothing else. Confirm the canonical engine label is
> `CurLoginTimestamp` (UserManager.cs:1117) before editing — do NOT change the engine, only the metric seed.

## Step 0 — §0.6a integrity + git fetch (§42.7.6) + coord sync block (slug + claims).

## The fix — change MetricFunction 'CurLoginTimeStamp' -> 'CurLoginTimestamp' for MonAgentCurrentLoginTimeStamp in ALL seed paths:

1. NEW db/migrations/20260607_003_fix_curlogintimestamp.sql — idempotent UPDATE for EXISTING DBs:
   ```sql
   -- Fix dead metric: engine switch (UserManager.cs) is case-sensitive 'CurLoginTimestamp';
   -- the metric was seeded 'CurLoginTimeStamp' (capital S) -> never produced a value.
   UPDATE "RTSGrid_Metric"
      SET "MetricFunction" = 'CurLoginTimestamp'
    WHERE "MetricId" = 'MonAgentCurrentLoginTimeStamp'
      AND "MetricFunction" = 'CurLoginTimeStamp';
   ```
   OPTIONAL (per coordinator §4 / devops _002 ledger convention): if db/migrations now self-record into a
   db_patch_history ledger, append the standard self-record INSERT at the END of this migration following
   the exact form devops used in _002 (read it before issue). If no such convention is present, skip.
2. db/data/02_metrics.sql (line ~52): change the MetricFunction column value CurLoginTimeStamp -> CurLoginTimestamp
   for MonAgentCurrentLoginTimeStamp. Update the CatalogNotes: the "CONFIRMED dead ... Fix: UPDATE MetricFunction
   to 'CurLoginTimestamp'." note is now RESOLVED — reword to "RESOLVED 2026-06-07: MetricFunction corrected to
   CurLoginTimestamp (matches engine UserManager.cs)." and change CatalogType from 'defect-candidate' to its
   normal value if appropriate (keep consistent with other live Agent metrics; if unsure leave CatalogType, just
   fix the note + function).
3. db/baseline.sql (line ~249): same MetricFunction value fix CurLoginTimeStamp -> CurLoginTimestamp.
4. src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs (line ~599): MetricFunction = "CurLoginTimeStamp"
   -> "CurLoginTimestamp".
5. docs/metrics-catalog.json (line ~1318 metricFunction + ~1335 notes): metricFunction "CurLoginTimeStamp"
   -> "CurLoginTimestamp"; reword notes to the RESOLVED text. (Check ru-RU/he-IL catalog json: they hold
   translations only — if they do NOT carry metricFunction/notes, leave them untouched; if they mirror the note,
   update consistently. Report which you touched.)
> Do NOT run Export-All (this is a targeted edit; Export-All would also pull devops/test-5 working-tree state into
> schema.sql — out of scope). 02_metrics.sql + baseline are edited DIRECTLY here.
> Run `python3 tools/lint_metrics.py` after: catalogue coverage MUST stay green (metricFunction change is within an
> existing catalogued metric — no coverage delta expected). Fix any lint regression before commit.

## Build & verify
- `dotnet build CcDashboard.sln` clean (DatabaseInitializer change compiles).
- grep confirms ZERO remaining 'CurLoginTimeStamp' (capital S) in the 5 files (only 'CurLoginTimestamp' remains),
  EXCEPT historical/publish snapshots (publish/, Metrics.sql, staging/) which are NOT in scope — do not touch them.

## Commit (module-split under ONE lock acquisition)
Acquire commit.lock once, then:
 - `db: fix MonAgentCurrentLoginTimeStamp MetricFunction CurLoginTimestamp (20260607_002 + 02_metrics + baseline)`
 - `web: fix CurLoginTimestamp in DatabaseInitializer seed`
 - `docs: mark CurLoginTimeStamp metric resolved in metrics-catalog.json`
(or a single combined commit if cleaner — your call, but each file staged explicitly within claims)
pre-commit-check -> §0.6 verify -> `bash tools/cc_post_commit.sh metrics-2-0607 $(git log -1 --format=%h)` per commit
-> release lock -> sync. No push.

## Acceptance criteria
1. New migration 20260607_002 with idempotent guarded UPDATE.
2. 02_metrics.sql + baseline.sql + DatabaseInitializer.cs + metrics-catalog.json all use 'CurLoginTimestamp'; notes resolved.
3. dotnet build clean; lint_metrics.py green; no 'CurLoginTimeStamp' (capital S) left in the 5 in-scope files.
4. No Export-All; no resx/ScreenEditorPage touched; commits journaled + S4b; lock released; no push.
