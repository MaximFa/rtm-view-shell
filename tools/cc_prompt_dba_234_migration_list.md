# CC task — DBA: finalize 234 -MigrationList from the pre-deploy Compare delta (PG18, NOT 45)
> §4-PASS by coordinator-0612 2026-06-18T13:00:18Z. Owner: dba-0610. Executor: native CC. ANALYSIS + apply-plan; NO blind apply, NO push.
> INPUT (operator provides): the 234 Compare output from the bundle run — Installations\<234_compare>\out\baseline_delta_*.txt + align_*.sql (Dim-A enumerated detail + Dim-D probes). Read those, NOT a fresh run (dba has no 234 access, §43).

## Why
234 pre-deploy Compare (read-only gate) = NO runtime-critical drift. But Dim-D: 234 lacks _001(backfill)+_005 for sure + 8 UNKNOWN (no probe): _004, _008, 0613_001, 0613_011..015. We must NOT blindly apply the whole 0613 saga (that was the 45 firefight; 234 = PG18 != 45). Finalize EXACTLY which migrations 234 needs, in order, PG18-safe.

## TASK
1. From the 234 baseline_delta Dim-A ENUMERATED detail (which tables/columns/indexes/constraints 234 LACKS vs b58e2c2 baseline) + Dim-D probes, MAP each candidate migration to whether 234 already has its effect:
   - _001 backfill_metric_deploy_log (sorts BEFORE _011..015 -> MUST be explicit) — needed (Compare: 234 lacks).
   - _005, _004, _008 — determine applied/needed from the Dim-A objects + metric data (C dim).
   - 0613_011 (table-drift ADD COLUMN), _012 (drop legacy mapping FUNCTIONs), _013 (sgag UNIQUE), _014 (schema reconcile, to_regclass-guarded), _015 (NGC_CreateSupergroup overloads) — for EACH: does 234 already have the columns/constraints/indexes/routines? If present -> SKIP (idempotent guards make re-apply safe but list only what's needed); if absent -> include.
2. Account for PG18 specifics on 234 (vs 45). Flag anything PG18-version-sensitive.
3. Produce the FINALIZED ordered -MigrationList for 234 (explicit, incl _001) + a one-line rationale per migration (needed/skip + why, cite the Dim-A object or probe).
4. NGC_DeleteBUQueueClassificationMapping (B=1, missing FUNCTION overload): note it self-heals on db/functions re-apply; coordinate with backend's caller=CALL confirm (RTM-SEC-002: if caller uses CALL it must be PROCEDURE; the FUNCTION overload absence is benign if CALL).
5. The 0613_011/_014 align: the Compare align.sql is ADVISORY (§38.5) — verify DIRECTION per object against 234, do NOT auto-apply; prefer the migration files over align.sql.

## VERIFY / output
- A table: migration | 234 needs? (yes/skip) | evidence (Dim-A object / probe) | order.
- The final `-MigrationList <comma-list>` string for the deploy.
- PG18 flags + any object that needs a 234-specific check before apply.
- NO push, NO blind apply. Report -> .coord/inbox/coordinator.md + chat. (If a staging apply script is produced, it goes to staging/ as advisory, NOT auto-run.)
