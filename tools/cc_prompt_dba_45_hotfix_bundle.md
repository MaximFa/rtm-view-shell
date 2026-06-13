# CC Task — DBA(+backend): 45 hotfix bundle (42883 missing PROCEDUREs + 23505 IDENTITY resync) + durable package fix + [D]/[A] verify

> Authored by dba-0610. TWO active 45-green blockers (coordinator 14:36 + 14:40). §26.8: this prompt is §4-BOUND —
> submit to coordinator §4 for BLESS BEFORE the operator applies anything. HOTFIX = priority-1 (live RTM 42883 loop).
> CO-AUTHOR backend (MANDATORY for the durable FUNCTION-removal — sign the no-caller finding below).

## Git push
Do NOT run `git push`. Commit only (fix/db:). Push requested separately (§37).

## Mandatory — read before starting
Read: .claude/skills/widget-planner/widget-planner.md ; widget-creator.md ; session-coord.md ; rtm-service-expert.md (§4 PROCEDURE/CALL, §10)

## STEP 0 — integrity + sync + binding
0a. §0.6a integrity (db/functions/01 may be PD-007-truncated; RESTORE from HEAD before editing: `git show HEAD:db/functions/01_ngc_functions.sql > db/functions/01_ngc_functions.sql`; verify == HEAD lines).
0b. Barrier check (.coord/push/request.md -> STOP). Slug dba-0610. CLAIM: db/functions/01_ngc_functions.sql + db/migrations/20260613_012_drop_legacy_mapping_functions.sql + staging/45_hotfix_20260613.sql. commit.lock around commit.
0c. NORM-CUR-07 binding: OPEN block in .coord/cc/dba.md; RESULT on commit. RTM DB ops = PowerShell + psql.exe on the Windows host.

## CALLER FINDING (dba-verified; backend MUST sign)
- Shell (src/): grep = ZERO callers of the 3 NGC_Create*Mapping routines. The "Shell caller (SELECT fn())" comment on the 3-param FUNCTION in 01 is STALE.
- RTM (BusinessUnitData.cs:459/510/559): calls all 3 via `DBAdapter.ExecuteNonQuery` = CALL => the canonical N-param PROCEDURE.
=> the legacy 3-param FUNCTION overloads are DEAD (no caller). Removing them is SAFE. **Backend: confirm/sign before durable removal.**

## PART A — HOTFIX SQL for 45 (staging/45_hotfix_20260613.sql; operator applies via psql as superuser; NO repackage)
Idempotent, BOM-less, runnable on any server. Two sections:

### A1 — 42883: drop the dead 3-param FUNCTION + (re)create the canonical PROCEDURE, per routine
For each, kind-agnostic clean then CREATE PROCEDURE (bodies VERBATIM from db/functions/01 HEAD):
- `DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitQueueClassificationMapping"(integer, text, uuid);`
  then `CREATE OR REPLACE PROCEDURE "NGC_CreateBusinessUnitQueueClassificationMapping"(integer,text,text,text,uuid)` (5-param body from 01).
- `DROP FUNCTION IF EXISTS "NGC_CreateBusinessUnitSupergroupMapping"(integer, integer, uuid);`
  then `CREATE OR REPLACE PROCEDURE "NGC_CreateBusinessUnitSupergroupMapping"(integer,integer,text,uuid)` (4-param body from 01).
- `DROP FUNCTION IF EXISTS "NGC_CreateSupergroupAgentgroupMapping"(integer, text, uuid);`
  then `CREATE OR REPLACE PROCEDURE "NGC_CreateSupergroupAgentgroupMapping"(integer,text,text,uuid)` (4-param body from 01).
(Belt-and-braces: precede each with the kind-agnostic pg_proc DROP loop so any stray overload of that name is cleared first.)
VERIFY: `SELECT proname, pg_get_function_identity_arguments(oid), prokind FROM pg_proc WHERE proname LIKE 'NGC_Create%Mapping' ORDER BY 1,2;`
-> each name shows ONLY prokind='p' (the canonical PROCEDURE), NO 'f'. A test `CALL "NGC_CreateBusinessUnitQueueClassificationMapping"(1,'q','c','sys',gen_random_uuid())` resolves (rollback). RTM.log 42883 stops.

### A2 — 23505: resync seed IDENTITY sequences (idempotent, safe anywhere)
For each seed IDENTITY table.id-col:
`SELECT setval(pg_get_serial_sequence('"<T>"','<IdCol>'), GREATEST((SELECT COALESCE(MAX("<IdCol>"),0) FROM "<T>"),1));`
Tables: RTSGrid_Grid.GridId, RTSGrid_Row.RowId, RTSGrid_Column.ColumnId, RTSGrid_Cell.CellId, RTSGrid_Statistic.StatisticId,
RTSUserGrid_Grid.GridId, RTSUserGrid_Column.ColumnId, RTSUserGrid_ColumnsSet.ColumnsSetId (+ NGC_* IDENTITY tables defensively — harmless).
VERIFY: a QueueGrid save (Grid/Row/Column/Cell INSERTs) succeeds with no 23505.
=> A1 + A2 are ONE psql file the operator applies on 45 today; clears both live blockers.

## PART B — DURABLE (package) so a clean rebuild never reproduces these
### B1 — db/functions/01_ngc_functions.sql: REMOVE the 3 dead `CREATE OR REPLACE FUNCTION` (3-param) blocks
Keep the canonical N-param PROCEDURE + the existing kind-agnostic DROP guard for each of the 3 routines. After removal a clean
rebuild creates PROCEDURE-only (no dual-kind ambiguity -> the PROCEDURE lands deterministically; root cause of the 42883). Touch ONLY those 3 FUNCTION blocks; leave Delete*Mapping + all else intact.
### B2 — db/migrations/20260613_012_drop_legacy_mapping_functions.sql (NEW)
For already-deployed servers: per routine, `DROP FUNCTION IF EXISTS "<name>"(<3-param sig>);` + ensure the canonical PROCEDURE exists
(CREATE OR REPLACE PROCEDURE, body from 01). §38a self-record: `INSERT INTO public.db_patch_history (migration_name) VALUES ('20260613_012_drop_legacy_mapping_functions') ON CONFLICT (migration_name) DO NOTHING;`. BOM-less.
### B3 — canonical IDENTITY-resync block for the rebuild runbook (PD-008 P6; devops wires it)
Provide a reusable SQL block (the A2 setval set, parameterised over the seed IDENTITY tables) for devops to append to the SEED phase
of db/tools/Create-FreshDb.ps1 + Restore-All.ps1. You author the SQL; devops wires it (their claim).

## PART C — fold in the 14:29 [D]/[A] verification (report-only; operator runs reads on 45)
- [D] applied-state on 45 (by OBJECT presence, not just ledger): 20260606_008_daytrend_fn_bu_scope (HIGH — DayTrend BU-scope; check fn signature/body present), 20260605_004_metrics_dedup, 20260607_003_fix_curlogintimestamp, 20260604_001_add_agent_state_pct_metrics, 20260606_005_history_unavailable_metrics. Report applied/not + redundant-vs-needed (note [C]=0 metrics).
- [A] 448 schema drift: triage the 328 "missing on server" for RUNTIME-CRITICAL objects (a table/column a function or RTM reads). Report ONLY runtime-critical as blocking; the rest = schema.sql staleness (PD-008 P1/P4 advisory).

## VERIFY (dev) + COMMIT
- B1/B2 on dev: re-apply 01 + apply _012 twice -> only PROCEDURE for the 3 names (pg_proc prokind='p'), idempotent, no 42809/42883; RTM-style CALL resolves.
- A1/A2 staging SQL: dry-run on dev (rollback) -> 42883 names resolve, seq resync no-op-safe.
- pre-commit-check on all touched files -> exit 0. §0.6 post-commit; PD-007 re-sync; RESULT (commit hash + pg_proc verify + [D]/[A] findings) -> .coord/cc/dba.md. NO push.

## Acceptance criteria
- [ ] PART A staging/45_hotfix SQL: A1 (3 routines -> PROCEDURE-only, FUNCTION dropped) + A2 (8 seq resyncs) — idempotent, BOM-less.
- [ ] PART B1: 3 dead FUNCTION blocks removed from 01 (PROCEDURE + guard kept); B2 migration _012 with §38a self-record; B3 resync block delivered for devops.
- [ ] backend SIGNED the no-3-param-FUNCTION-caller finding before B1 removal.
- [ ] PART C [D]/[A] findings reported (008 applied-state HIGH; runtime-critical [A] only).
- [ ] dev verify: prokind='p'-only for the 3; idempotent; pre-commit-check exit 0; NO push.

## NOTES for coordinator (§4 BLESS before apply — §26.8)
- dba caller-check CONFIRMS your remove-FUNCTION direction (Shell=0 callers, RTM=CALL/PROCEDURE) — backend co-signs. (Contrast: the CustomCallData case was the opposite; verified each direction independently.)
- Priority-1 = PART A (live RTM 42883 + QueueGrid 23505). PART B durable + C verify can follow but ship together if time allows.
- Sequence: §4 bless -> operator applies PART A on 45 (clears live) -> CC commits PART B -> backend sign -> §4-final -> devops repackage (incl _012, B3 runbook) -> Compare [B]=0.
