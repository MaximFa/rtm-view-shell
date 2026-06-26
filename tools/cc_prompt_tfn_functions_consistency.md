# CC task — T-FN: db/functions self-consistency (dead overload cleanup + fresh-build completeness + regen determinism)
> §4-DRAFTED by coordinator-0612 2026-06-15T05:50Z. Owner: dba-0610. Executor: native CC, Windows, PG18 + dotnet ef.
> Claims: db/functions/01_ngc_functions.sql + db/tools/Regen-Schema.ps1 + db/schema.sql (only if a re-regen legitimately changes it).
> Commit prefix `db:`. **NO push** (rides next barrier). Post-push triage #12; nothing on prod is broken — this is source consistency.
> INVESTIGATION-FIRST: diagnose before removing anything.

## Why
E2 enumeration surfaced that db/functions/*.sql is not self-consistent with migrations / a clean build:
- _012_drop_legacy_mapping_functions DROPs dead 3-param FUNCTION overloads of NGC_Create*Mapping that db/functions/01 STILL declares
  -> every clean build creates-then-drops them (Compare shows them as false "missing routines").
- Compare also showed "missing routine: RTSData_SetUserStatus" on the regen scratch (count varied between runs) -> must confirm
  this is the dead-overload/parse artifact and NOT a real gap (a function a fresh prod install would lack -> RTM 42883 at runtime).

## Mandatory read (§40) + integrity + binding PREAMBLE
- Read: widget-planner / widget-creator / session-coord skills.
- §0.2: git status; branch v2-backend; HEAD==7ae098a (pushed); hash-verify claimed files vs HEAD.
- Binding PREAMBLE -> .coord/cc/dba.md:
```
## 2026-06-15T05:50Z | binding: dba <-> CC | directive: tools/cc_prompt_tfn_functions_consistency.md | status: open
### DIRECTIVE: T-FN — diagnose functions vs clean build; remove confirmed-dead FUNCTION overloads from db/functions/01; Regen determinism. Claims: 01_ngc_functions.sql + Regen-Schema.ps1 (+schema.sql if re-regen changes). db:. NO push.
```
## S1 barrier + S2 claim
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then echo BARRIER; exit 1; fi
python3 tools/coord_check_claims.py dba-0610 db/functions/01_ngc_functions.sql db/tools/Regen-Schema.ps1 db/schema.sql
```

## STEP 1 — DIAGNOSE (read-only; build clean scratch, diff pg_proc vs source declarations)
1. Build a fresh scratch DB from HEAD sources (reuse Regen-Schema.ps1 logic, or run it with a temp scratch). Functions applied (db/functions/*) THEN all db/migrations/* (matching the canonical apply order).
2. Snapshot server routines: `SELECT n.nspname, p.proname, p.prokind, pg_get_function_identity_arguments(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('public','identity','audit') ORDER BY 2,3;`
3. Parse the DECLARED routines from db/functions/*.sql (name + kind + arg signature).
4. Produce a DIFF table classifying every discrepancy:
   - **DEAD-OVERLOAD**: declared as FUNCTION in db/functions/01 AND dropped by _012 (the NGC_Create*Mapping 3-param FUNCTIONs) -> source cleanup candidate.
   - **REAL GAP**: declared (and NOT dropped by any migration) but ABSENT on the clean build -> a genuine problem (report loudly; this would break RTM on a fresh install). For RTSData_SetUserStatus specifically: confirm whether it ends up present (it's declared PROCEDURE @02:174 + referenced by _002/_004) or genuinely missing, and WHY.
   - **MIGRATION-SUPERSEDED**: declared one way, a migration legitimately replaced it -> expected, no action.
PASTE this diff table in the report. Do NOT change code yet if a REAL GAP is found — report it and STOP for coordinator decision.

## STEP 2 — CLEANUP (only the CONFIRMED-DEAD overloads)
If STEP 1 confirms the only source-vs-build noise is the dead FUNCTION overloads:
- In db/functions/01_ngc_functions.sql, REMOVE the dead 3-param `CREATE ... FUNCTION` overloads of:
  NGC_CreateBusinessUnitQueueClassificationMapping, NGC_CreateBusinessUnitSupergroupMapping, NGC_CreateSupergroupAgentgroupMapping
  (exactly the signatures _012 drops: see db/migrations/20260613_012_drop_legacy_mapping_functions.sql).
- KEEP the canonical PROCEDURE versions intact. Do NOT touch any other routine.
- _012 STAYS (historical; DROP FUNCTION IF EXISTS = harmless no-op on fresh builds + still fixes already-deployed servers).

## STEP 3 — Regen-Schema.ps1 determinism (hygiene)
Ensure Regen-Schema.ps1 ALWAYS drops+recreates the scratch DB at start (never reuses a kept scratch) so runs are deterministic.
If a -KeepScratch switch exists it may keep the DB at the END for inspection, but the START must always drop+recreate.

## STEP 4 — Verify
1. Re-run Regen-Schema.ps1 -> produces db/schema.sql. DIFF vs the committed schema.sql (7ae098a): it MUST be UNCHANGED (the dead
   overloads were already absent from the end-state because _012 dropped them). If schema.sql changes unexpectedly -> investigate before commit. If identical -> do NOT restage schema.sql.
2. Compare-ToBaseline.ps1 -Database <fresh scratch> -> Dimension B "missing routines" for the 3 NGC_Create*Mapping FUNCTIONs is GONE (and RTSData_SetUserStatus resolved per STEP 1 finding).
3. PowerShell parse clean (Regen-Schema.ps1); SQL file still valid (psql -f on scratch, no error).

## Commit (db:, NO push) under commit.lock
Acquire .coord/locks/commit.lock (dba-0610). Stage ONLY the files that actually changed (db/functions/01_ngc_functions.sql, db/tools/Regen-Schema.ps1; schema.sql ONLY if STEP 4.1 legitimately changed it):
```
bash tools/pre-commit-check.sh
git add db/functions/01_ngc_functions.sql db/tools/Regen-Schema.ps1
git commit -m "db: T-FN — remove dead NGC_Create*Mapping FUNCTION overloads from db/functions/01 (dropped by _012); Regen scratch always drop+rebuild; functions-source == clean-build end-state"
git rev-parse HEAD
```
§0.6 post-commit -> `bash tools/cc_post_commit.sh dba-0610 $(git log -1 --format=%h)` -> sync -> §0.7 re-sync changed files from HEAD.

## Binding RESULT -> .coord/cc/dba.md (status: done)
```
### RESULT (by CC): commit <hash>; STEP1 diff = <dead-overload count> dead + <real-gap: none|LIST> + <superseded>; removed 3 NGC_Create*Mapping FUNCTION overloads from 01; Regen drop+rebuild enforced; schema.sql unchanged (verified); Compare Dim B no longer false-missing those. NO push. verified: object-store + reruns.
```

## Report (chat) — NO push
PASTE the STEP-1 diff table; what was removed; whether any REAL GAP found (esp. RTSData_SetUserStatus verdict); schema.sql unchanged confirm; commit hash. NO push. If a REAL GAP found -> reported + STOPPED for coordinator decision (no blind fix).
