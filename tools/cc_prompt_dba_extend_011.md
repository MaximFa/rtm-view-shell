# CC Task — DBA: EXTEND _011 with the 45 cross-check's additional missing columns (re-apply GATE close)

> Authored by dba-0610. The 45 completeness cross-check (operator-run) found 45 missing MORE than CustomCallData1..20.
> EXTEND the EXISTING migration db/migrations/20260613_011_45_table_drift_addcolumns.sql in ONE pass (do NOT add a 2nd migration).
> Functions 01/02 UNCHANGED (3db705d correct). This closes the re-apply GATE.

## Git push
Do NOT run `git push`. Commit only (fix/db:). Push requested separately (§37).

## Mandatory — read before starting
Read: .claude/skills/widget-planner/widget-planner.md ; widget-creator.md ; session-coord.md ; rtm-service-expert.md (§5/§6)

## STEP 0 — integrity + sync + binding
0a. §0.6a integrity (db/functions/01+02 may be PD-007-truncated; this task does NOT touch them — leave out of claim/commit).
0b. Barrier check (.coord/push/request.md -> STOP). Slug dba-0610. CLAIM: db/migrations/20260613_011_45_table_drift_addcolumns.sql. commit.lock around commit.
0c. NORM-CUR-07 binding: OPEN block to .coord/cc/dba.md; RESULT on commit. RTM DB ops = PowerShell + psql.exe on Windows host.

## STEP 1 — EXTEND db/migrations/20260613_011 (append these 3 ALTERs BEFORE the §38a self-record INSERT)
The existing 20x RTSData_Interaction CustomCallData1..20 ADDs STAY. Add (types EXACT from canonical schema.sql DDL):

```sql
-- [45 cross-check 2026-06-13] additional canonical columns missing on 45:
-- RTSData_UserStatus.MaxDuraction  — BODY-REFERENCED by RTSData_getUsersStatuses (RETURNS+SELECT) => 42703 on re-apply if absent (CRITICAL)
ALTER TABLE "RTSData_UserStatus" ADD COLUMN IF NOT EXISTS "MaxDuraction" integer;
-- NGC_Queues/NGC_AgentGroups.CreatedDatetime — canonical PARITY (no function references it after 3db705d GetOrCreate fix; not a re-apply blocker, added for canonical end-state + to stop future drift). Match canonical type+default.
ALTER TABLE "NGC_Queues"      ADD COLUMN IF NOT EXISTS "CreatedDatetime" timestamptz DEFAULT now();
ALTER TABLE "NGC_AgentGroups" ADD COLUMN IF NOT EXISTS "CreatedDatetime" timestamptz DEFAULT now();
```
- PRESERVE the existing §38a self-record at the END — the line `INSERT INTO public.db_patch_history (migration_name) VALUES ('20260613_011_45_table_drift_addcolumns') ON CONFLICT (migration_name) DO NOTHING;` MUST remain. Insert the 3 ALTERs BEFORE it, in the migration body.
- BOM-less; quoted-heredoc + byte-gate.
- NB type discipline: MaxDuraction=integer (NOT text); CreatedDatetime=timestamptz DEFAULT now() (matches schema.sql; one-time small-table rewrite acceptable on the config tables).

## STEP 2 — VERIFY (dev DB)
- Apply _011 on dev -> all targets present (`\d "RTSData_UserStatus"` shows MaxDuraction; NGC_Queues/AgentGroups show CreatedDatetime).
- Runtime cross-check: invoke RTSData_getUsersStatuses (arity-1 AND arity-2) -> resolves MaxDuraction (no 42703). Re-run the full STEP-1 cross-check VALUES query (tools/cc_prompt_dba_45_completeness_crosscheck.md) on dev -> ZERO rows.
- Idempotent double-apply (ADD IF NOT EXISTS + self-record ON CONFLICT) -> clean.
- Confirm §38a self-record survived: `grep -c db_patch_history db/migrations/20260613_011_45_table_drift_addcolumns.sql` == 1 (INSERT still present).
- `bash tools/pre-commit-check.sh db/migrations/20260613_011_45_table_drift_addcolumns.sql` -> exit 0.

## STEP 3 — COMMIT (commit.lock; §0.6; PD-007 re-sync; NO push)
- git add the migration (explicit) -> commit `fix/db: extend _011 — add RTSData_UserStatus.MaxDuraction (42703) + NGC_Queues/AgentGroups.CreatedDatetime (parity); 45 cross-check close`
- §0.6 post-commit clean; PD-007 re-sync the file; RESULT (final ALTER set + dev cross-check ZERO-rows proof) -> .coord/cc/dba.md; cc_post_commit.sh.

## Acceptance criteria
- [ ] _011 now adds: RTSData_Interaction CustomCallData1..20 (text) + RTSData_UserStatus.MaxDuraction (integer) + NGC_Queues/AgentGroups.CreatedDatetime (timestamptz DEFAULT now()). All ADD COLUMN IF NOT EXISTS, AT TABLE END.
- [ ] §38a self-record (db_patch_history INSERT) intact (grep -c == 1); BOM-less; idempotent double-apply; pre-commit-check exit 0.
- [ ] dev re-run of the cross-check VALUES query = ZERO rows (GATE proof); functions 01/02 untouched.

## NOTES for coordinator (light §4)
- Re-apply GATE: MaxDuraction is the re-apply-CRITICAL add (body-referenced/42703). The 2 CreatedDatetime are PARITY (not body-referenced; re-apply would not fail without them) — included to reach canonical parity + stop drift (recommended; drop them if you prefer minimal-touch, but then 45 stays non-canonical on those 2). 
- After commit -> backend sign authored final set -> §4-final -> devops repackage-from-HEAD (incl final _011 + -MigrationList 001,004,005,008,011) -> operator re-apply ONCE. The dev cross-check ZERO-rows is the gate proof.
