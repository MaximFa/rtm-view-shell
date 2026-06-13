# CC Task — DBA: PD-008 P3 systematic column drift-gate for db/functions/01+02, then fix ALL in correct direction (45 release-blocker)

> Authored by dba-0610. The 3db705d regen fixed SIGNATURES/kind/DROP-guards (KEEP that) but a BODY references columns the
> 45 table lacks -> 45 re-apply failed at 02:335 (RTSData_getInteractions selects CustomCallData1..20). PD-008: schema.sql is
> authoritative for SIGNATURES, NOT BODIES. Body authority = the ACTUAL canonical table columns + what RTM reads/writes.
> STOP whack-a-mole: scan ALL function bodies vs ALL real table columns ONCE, then fix every mismatch in the CORRECT DIRECTION.

## Git push
Do NOT run `git push`. Commit only (fix/db:). Push requested separately (§37).

## Mandatory — read before starting
Read: .claude/skills/widget-planner/widget-planner.md
Read: .claude/skills/widget-creator/widget-creator.md
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/rtm-service-expert/rtm-service-expert.md  (§5 routine catalogue, §6 data flows, §10)
Read: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md  (RTSData column semantics) — if metric-adjacent.

## STEP 0 — integrity + sync + binding
0a. §0.6a integrity. ⚠ db/functions/01 + 02 are KNOWN PD-007-TRUNCATED in the working tree (01 ~667L vs HEAD 835L; 02 ~470L vs
    HEAD 496L). RESTORE BOTH from HEAD FIRST: `for f in db/functions/01_ngc_functions.sql db/functions/02_rtsdata_functions.sql; do git show HEAD:"$f" > "$f"; done` ; verify wc -l == 835/496 before any edit.
0b. Barrier check (.coord/push/request.md -> STOP). Slug dba-0610. CLAIM: db/functions/01_ngc_functions.sql + db/functions/02_rtsdata_functions.sql. commit.lock around commit.
0c. NORM-CUR-07 binding: append OPEN block to .coord/cc/dba.md; write RESULT there on commit. (RTM DB ops = PowerShell + psql.exe on Windows host.)

## STEP 1 — PD-008 P3 SYSTEMATIC DRIFT SCAN (ground truth; do this BEFORE any edit)
On the KNOWN-GOOD dev DB (rtmviewdb):
1. For EVERY routine in db/functions/01 + 02, extract every quoted column identifier referenced in its body (RETURNS TABLE list,
   SELECT list, INSERT col-list, UPSERT SET, WHERE). For each, identify the table(s) the routine reads/writes.
2. Diff each referenced column vs the ACTUAL table columns: 
   `SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='<T>';`
   Tables in scope: RTSData_Interaction, RTSData_UserStatus, RTSData_UserStatusLog, RTSData_ChatMessage, NGC_BusinessUnit,
   NGC_Supergroup, NGC_Queues, NGC_AgentGroups, NGC_* mapping tables, NGC_Site (+ any others a routine touches).
3. Cheap runtime cross-check: invoke each FUNCTION (`SELECT * FROM fn(<dummy args>) LIMIT 0`) / `CALL` each PROCEDURE in a
   ROLLBACK txn on dev -> surfaces 42703 (missing col) / 42883 (arity) immediately. Collect ALL failures, not just the first.
4. PRODUCE THE FULL MISMATCH LIST: `(routine, referenced_col, table, present_in_table? Y/N, RTM-reads/writes_it? Y/N)`.
   Write it into the .coord/cc/dba.md RESULT (and a /tmp scan output) BEFORE editing. This list is the gate artifact.

## STEP 2 — CLASSIFY each mismatch, fix in the CORRECT DIRECTION (do NOT default to "strip from body")
Authority = canonical table columns + RTM read/write contract. For each mismatch:
- **(K) KEEP body, table is DRIFTED:** the col is in the CANONICAL table source (db/schema.sql table DDL) AND RTM reads/writes it
  -> the body is RIGHT, the 45 table is behind. This is a TABLE-MIGRATION fix (add the column), NOT a body edit. Do NOT strip it
  from the function. RECORD it as a required table migration and HAND to coordinator/devops/backend (out of THIS file's scope).
- **(S) STRIP from body, col is true legacy cruft:** the col is absent from the canonical table DDL AND RTM does not use it
  -> remove it from the body (this is a genuine broken-legacy body the dump carried).
- If ambiguous (canonical DDL has it but dev table doesn't and RTM usage unclear) -> STOP, report to coordinator with the scan row; do not guess.

### ⚠ CustomCallData1..20 (the line-335 trigger) — direction is NOT obvious; resolve via the scan, do NOT auto-strip:
Evidence that they are CANONICAL (class K, table-migration — NOT strip): schema.sql RTSData_Interaction DDL has CustomCallData + CustomCallData1..20;
RTM Call.cs assigns CustomCallData1..20; the committed RTSData_SetInteraction WRITES all 21 (INSERT+UPSERT). If the dev table HAS
the 20 cols -> 45 is drifted -> fix = migrate 45's RTSData_Interaction to add CustomCallData1..20 (devops/backend), functions UNCHANGED.
ONLY if the dev table truly lacks them AND backend confirms RTM does not persist them -> strip 1..20 from BOTH getInteractions
overloads AND RTSData_SetInteraction (keep them consistent — never read cols SetInteraction doesn't write, vice-versa).
Backend MUST confirm the RTSData_Interaction column contract before any strip.

## STEP 3 — APPLY (only the (S)-class body edits live in THIS file; (K)-class -> handoff, not edited here)
- Edit ONLY db/functions/01 + 02. Keep ALL 3db705d signature/kind/DROP-guard work intact (verify the 14 pg_proc DROP guards + the
  overload set survive). Preserve read/write column-set CONSISTENCY within each table (getX must match setX).
- SQL via QUOTED HEREDOC + byte-gate (anti-rake: the written SQL block has no stray chars; grep for accidental markers ==0).
- No table DDL in functions; no schema.sql edit; no out-of-claim file.

## STEP 4 — VERIFY (before commit)
- Re-run STEP 1.3 runtime cross-check on dev: ALL routines in 01+02 invoke clean (no 42703/42883).
- Idempotent double-apply of BOTH files (no 42809).
- `bash tools/pre-commit-check.sh db/functions/01_ngc_functions.sql db/functions/02_rtsdata_functions.sql` -> exit 0.

## STEP 5 — COMMIT (commit.lock; §0.6 post-commit; PD-007 re-sync BOTH; NO push)
- pre-commit-check both -> git add both (explicit paths) -> commit `fix/db: PD-008 P3 drift-gate — align 01+02 bodies to canonical table columns (45 column-mismatch fix); signatures from 3db705d kept`
- §0.6 post-commit clean; PD-007 re-sync BOTH (`git show HEAD:<f> > <f>`); RESULT (incl the STEP-1 mismatch list + per-row K/S disposition) to .coord/cc/dba.md; cc_post_commit.sh.

## Acceptance criteria
- [ ] FULL scan mismatch list produced (every routine x referenced col vs real table) BEFORE edits, in the RESULT.
- [ ] Each mismatch classified K (table-drift -> handoff) or S (legacy -> stripped); NO blind stripping; CustomCallData1..20 resolved via dev-table ground truth + backend contract (default = KEEP/table-migrate unless proven legacy).
- [ ] read/write column-set consistency per table (getInteractions <-> SetInteraction).
- [ ] 3db705d signatures/kind/DROP-guards intact; runtime cross-check clean; idempotent double-apply; pre-commit-check exit 0; no push.

## NOTES for coordinator (read before §4)
- ⚠ **DIRECTION CONFLICT flag (dba review-gate):** your 11:27 framing was "strip CustomCallData1..20 (broken legacy body)". But schema.sql RTSData_Interaction DDL HAS all 21 cols, RTM Call.cs reads/writes 1..20, and the committed RTSData_SetInteraction WRITES all 21 — internally CONSISTENT on 21. By your own PD-008 authority rule (table cols + RTM read), CustomCallData1..20 are most likely CANONICAL -> 45's table is DRIFTED -> the real fix is a 45 TABLE MIGRATION (add the 20 cols), and the FUNCTIONS STAY. Stripping would regress SetInteraction's write path + RTM + dev/234. The STEP-1 dev-DB scan + `\d "RTSData_Interaction"` is the arbiter; the prompt branches accordingly and will NOT auto-strip.
- Needs backend: the RTSData_Interaction column contract (does RTM persist CustomCallData1..20? — Call.cs says yes) + whether dev/canonical table carries the 20 cols. If table-migration is the fix, that's devops/backend (a migration), out of this file's scope.
- This is the first LIVE use of PD-008 P3. P4 (generate functions from dev-DB dump) + P1 (freshness audit) remain post-45-green.
