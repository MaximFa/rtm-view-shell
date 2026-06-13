# CC Task — DBA+backend: 45 table-drift migration (ADD missing canonical columns) — RTSData_Interaction CustomCallData1..20 + scan-found set

> Authored by dba-0610, CO-AUTHOR backend (owns RTM column/positional contract). Coordinator §4 PASS + DIRECTION CONFIRMED (11:37):
> the 45 re-apply failure (02:335) is a DRIFTED TABLE, NOT a broken function body. 3db705d function bodies are CORRECT vs canonical.
> FIX = bring 45's tables up to the canonical schema via idempotent ADD COLUMN. Functions UNCHANGED. NEVER strip CustomCallData1..20
> (RTM reads POSITIONALLY -> stripping shifts the index by 20 = corrupts RemoteAddress/UserId/flags/timestamps — catastrophic).
> SUPERSEDES the function-edit framing of cc_prompt_dba_drift_gate_45.md for the K-class fix (its STEP-1 scan methodology is reused here).

## Git push
Do NOT run `git push`. Commit only (fix/db:). Push requested separately (§37).

## Mandatory — read before starting
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/rtm-service-expert/rtm-service-expert.md  (§5 routines, §6 data flows / positional contract)

## STEP 0 — integrity + sync + binding
0a. §0.6a integrity. NOTE: db/functions/01+02 may be PD-007-truncated in the working tree (HEAD is correct @3db705d) — if so, restore
    from HEAD; but this task does NOT edit them. Confirm they are NOT in your claim/commit.
0b. Barrier check (.coord/push/request.md -> STOP). Slug dba-0610. CLAIM: `db/migrations/20260613_011_45_table_drift_addcolumns.sql` (NEW file). commit.lock around commit.
0c. NORM-CUR-07 binding: OPEN block in .coord/cc/dba.md; RESULT on commit. RTM DB ops = PowerShell + psql.exe on Windows host.

## STEP 1 — drift scan (ground truth: canonical vs the deployed table)  [PD-008 P3]
On the dev DB (canonical) AND, where reachable, mirror against 45's reported state:
1. For every table referenced by db/functions/01 + 02 bodies, diff the CANONICAL column set (db/schema.sql table DDL) vs the actual
   table columns (`SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='<T>'`).
2. **GAP SOURCE (coord §4 affirm #1):** the gap set = CANONICAL schema.sql DDL columns that the 01+02 bodies REFERENCE but the deployed (45) table LACKS -> ADD them ALL `IF NOT EXISTS`. NB: the dev-DB runtime invoke (`SELECT * FROM fn(...) LIMIT 0` in ROLLBACK) finds ZERO 42703 because dev is COMPLETE — that is a CLEAN-CONFIRM of the 3db705d bodies, NOT the gap-finder. Derive the gap from canonical-DDL ∩ body-referenced columns (+ the known CustomCallData1..20); confirm against 45 where reachable. ADD-IF-NOT-EXISTS => no-op on dev/234, fixes 45.
3. Known/expected from analysis (CONFIRM via scan, do not assume): `RTSData_Interaction` missing `CustomCallData1..CustomCallData20`
   (canonical = 21 incl single `CustomCallData`; schema.sql DDL + RTM Call.cs + RTSData_SetInteraction all use all 21). Also re-check
   `RTSData_UserStatus`, `RTSData_UserStatusLog` (StatusGroup already added _004), and the NGC_Queues/AgentGroups `CreatedDatetime`
   case (note: 3db705d GetOrCreate no longer INSERTs CreatedDatetime, so it's not a function blocker — only add to the migration if a
   STILL-REFERENCING body needs it; otherwise leave to baseline alignment, NOT this hotfix).
4. Write the FULL missing-column set (table, column, canonical type/null/default) into the RESULT and a /tmp scan file.

## STEP 2 — author the migration (idempotent ADD COLUMN; types from canonical schema.sql; ADD AT END)
Create `db/migrations/20260613_011_45_table_drift_addcolumns.sql`:
- For every missing column from STEP 1, `ALTER TABLE "<T>" ADD COLUMN IF NOT EXISTS "<Col>" <canonical type>;`
  RTSData_Interaction: `CustomCallData1`..`CustomCallData20` = `text` (nullable, no default — match schema.sql DDL EXACTLY).
- **ADD AT TABLE END** (do not reorder existing columns). The getter's EXPLICIT `SELECT "Col1","Col2",...` order is the positional
  contract RTM relies on — appending physical columns does not change an explicit SELECT, so it is safe. (backend confirms.)
- IDEMPOTENT: `ADD COLUMN IF NOT EXISTS` -> safe on already-correct servers (dev/234) and fixes 45. No data rewrite (nullable text, no default).
- Tenant-agnostic schema DDL (no TenantId scoping needed for ALTER TABLE).
- **§38a self-record (MANDATORY, this is a db/migrations/ file):** end the file with
  `INSERT INTO public.db_patch_history (migration_name) VALUES ('20260613_011_45_table_drift_addcolumns') ON CONFLICT (migration_name) DO NOTHING;`
- BOM-less UTF-8 (psql rejects BOM); written via quoted-heredoc + byte-gate.

## STEP 3 — VERIFY (dev DB, before commit)
- Apply the migration on dev -> all target columns present (`\d "RTSData_Interaction"` shows CustomCallData1..20).
- Re-run STEP 1.2 runtime cross-check: EVERY routine in 01+02 invokes clean (no 42703/42883) AGAINST a table that now has the columns.
- Apply TWICE -> second run clean (ADD COLUMN IF NOT EXISTS idempotent; self-record ON CONFLICT no-op).
- `bash tools/pre-commit-check.sh db/migrations/20260613_011_45_table_drift_addcolumns.sql` -> exit 0.

## STEP 4 — COMMIT (commit.lock; §0.6; PD-007 re-sync; NO push)
- pre-commit-check -> git add the migration file (explicit) -> commit `fix/db: 45 table-drift migration — ADD canonical columns RTSData_Interaction CustomCallData1..20 (+scan set), idempotent (functions unchanged, 3db705d correct)`
- §0.6 post-commit clean; PD-007 re-sync the migration file; RESULT (incl full missing-col set + the migration) -> .coord/cc/dba.md; cc_post_commit.sh.

## Acceptance criteria
- [ ] STEP-1 full missing-column set produced (scan, not assumption) in the RESULT; ALL 42703s across 01+02 collected (not just :335).
- [ ] Migration adds every missing canonical column, IF NOT EXISTS, correct types, AT TABLE END; idempotent (double-apply clean).
- [ ] §38a self-record present; BOM-less; pre-commit-check exit 0.
- [ ] db/functions/01+02 NOT modified (3db705d stays); CustomCallData1..20 NOT stripped anywhere.
- [ ] backend signed the column set/types/positional-safety.

## NOTES for coordinator (§4) + routing
- CO-AUTHOR backend: backend owns the RTM column/positional contract — must confirm (a) the exact missing-column set + canonical types,
  (b) that ADD-at-end is positionally safe for RTM's explicit-SELECT readers. If backend prefers to author the DDL, I review (DBA gate); either way one of us claims the single migration file (no L-SC-09).
- devops: applies 20260613_011 on 45 -> re-apply -> functions resolve against the now-complete tables. 🔴 **The 45 re-apply `-MigrationList` MUST include 011: `001,004,005,008,011`** (Phase-4 ADDs columns BEFORE Phase-5 functions re-apply). The repackage (from HEAD) must carry _011 in migrations/ AND functions from the COMMITTED tree (HEAD), not the PD-007-truncated working copy.
- schema/migration-class -> TW doc-sync gate at the push barrier (§42.7/L-SC-23).
- PD-008 P4 (generate functions from dev-DB dump) + P1 (freshness audit) still post-45-green.
