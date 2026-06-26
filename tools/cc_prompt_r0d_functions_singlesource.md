# CC task — R0d: functions single-source (db/functions/* only); schema.sql = table DDL → Compare A:0

> Owner: dba (slug dba-0620). §4-APPROVED scope: coordinator-0612 2026-06-21T14:56:17Z (OPT-1). db: commit. NO push (§37).
> §4-PASS by coordinator-0612 (2026-06-21T15:05:50Z) — logic+scope verified object-store (agentstatus:898 dup of 02:422 -> strip; interactions:1011 schema-only -> move to 02; (iv) carve-aware [A] mandatory). EXECUTE authorized AFTER STEP 0.5 below + backend part-(i) canon-confirm. native CC, db: commit, commit.lock, NO push.
> Finishes the R0 hardening: R0b+R0c are FUNCTIONALLY PROVEN (rebuild zero-error; Compare B=0 C=0 F=0). The only residual
> is Compare A=12 = db/schema.sql DUPLICATES db/functions/* (38 fn defs in schema.sql, drifted). Per CLAUDE.md §39.1
> functions live ONLY in db/functions/*; schema.sql = tables/indexes/constraints/sequences. Barrier #3 HELD until A:0.

## Mandatory — read before starting
Read: .claude/skills/session-coord/session-coord.md
Read: .claude/skills/role-dba/role-dba.md (§A core + §C VERIFY)
Read: db/REBUILD_RUNBOOK.md
Read: db/tools/Compare-ToBaseline.ps1 (Dimension A section ~190-240)

## INIT / discipline
- §0.2 integrity; branch v2-backend; §0.5 object-store verify (git cat-file/show), NOT mount git status.
- §0.3 writes: Python + os.fsync ONLY (Edit BANNED); after write: sync + tail -3 + wc -l.
- §42.6 sync block: slug dba-0620; claims = ["db/schema.sql","db/functions/02_rtsdata_functions.sql","db/tools/Export-All.ps1","db/tools/Compare-ToBaseline.ps1"].
  Check .coord/push/request.md absent. commit.lock around commit. §0.6b binding -> .coord/cc/dba.md. NO push.

## §4 STEP 0.5 (MANDATORY, coordinator-added) — RESTORE db/schema.sql FROM HEAD FIRST
⚠ The WORKING-TREE db/schema.sql is NUL-CORRUPTED (PD-007 mount write-back): on-disk 115656 bytes incl 36325 NUL;
HEAD is clean 77072 bytes / 0 NUL. ⚠ The §0.2 line-count integrity check MISSES this — WT lines == HEAD lines (2259==2259);
NUL-padding does not change line count, so `[ H-W -gt 0 ]` will NOT restore it. If you read the working tree, the moved
fn_daytrendinteractions body = garbage. MANDATORY before any read/edit of schema.sql:
```bash
git show HEAD:db/schema.sql > db/schema.sql && sync
# verify clean: 0 NUL, 77072 bytes
tr -cd '\000' < db/schema.sql | wc -c   # must be 0
wc -c < db/schema.sql                    # must be 77072
```
Read ALL function bodies to move/strip from this RESTORED file (or via `git show HEAD:db/schema.sql`). After your edits,
re-verify 0 NUL before commit. Same NUL-check applies to any file you write on this mount.

## CORRECTION to the 11:40 scope (object-store verified — do NOT blindly "move both")
- **fn_daytrendagentstatus**: EXISTS IN BOTH — schema.sql:898 AND db/functions/02_rtsdata_functions.sql:422, SAME canonical
  signature `(uuid, varchar, integer p_businessunitid, integer)`. (The DROP at 02:420 clears an OLD text[] overload.)
  => pure DUPLICATE. Do NOT move. Just STRIP the schema.sql copy. (Confirm db/functions body is canonical first — part i.)
- **fn_daytrendinteractions**: ONLY in schema.sql:1011 `(uuid, varchar, text[] p_queuelist, integer)` — db/functions has NO
  CREATE for it. => MUST be MOVED into db/functions/02 (preserve the body) BEFORE stripping schema.sql, or it is lost.

## THE WORK (one db: commit)

### (i) Single-source the two DayTrend functions — BACKEND CO-AWARE (gate)
- **Move** fn_daytrendinteractions: copy its full body from schema.sql:1011.. into db/functions/02_rtsdata_functions.sql
  (next to fn_daytrendagentstatus, same pattern: `DROP FUNCTION IF EXISTS public.fn_daytrendinteractions(uuid, character varying, text[], integer); CREATE OR REPLACE FUNCTION ...`). Preserve the exact body/return shape.
- **Dedup** fn_daytrendagentstatus: keep the db/functions/02:422 version (canonical); it will be removed from schema.sql in (ii).
- ✅ RESOLVED — backend-0620 canon-confirm (inbox/dba.md 15:05) + dba object-store pin:
  * fn_daytrendagentstatus: token-normalized body is IDENTICAL across schema.sql:898 == db/functions/02:422 == migration
    _008 (md5 644ce053bea7b21289bbb400637b3263, 5113 chars; line-count diffs were pure whitespace/comments). => KEEP the
    02:422 copy as-is (it IS canonical); just STRIP schema.sql:898. NO prod-234 verify needed (all three logically equal).
    Optional minor: also drop the stale staging/verify_p3_daytrend_fn.sql copy (outside db/ claim — flag, don't gate).
  * fn_daytrendinteractions: HEAD:db/schema.sql:1011 body is POST-_002 canonical (backend: L-33 filter folded; 17 markers).
    MOVE that body into db/functions/02. SOURCE: HEAD:db/schema.sql, db/migrations/20260605_002_fix_daytrendinteractions.
  * SOURCE OF TRUTH = HEAD:db/schema.sql (working tree NUL-corrupt — STEP 0.5 restore first). Do NOT read the WT copy.

### (ii) Strip ALL functions from schema.sql -> pure table DDL (§39.1)
Remove every `CREATE [OR REPLACE] FUNCTION|PROCEDURE ... $$ ... $$;` block from db/schema.sql (41 routines incl both
daytrend). schema.sql keeps ONLY: CREATE SCHEMA IF NOT EXISTS public; CREATE EXTENSION (none currently); CREATE TABLE (26);
indexes; constraints; sequences; ALTER TABLE FK. Verify: `grep -c "CREATE .*FUNCTION\|CREATE .*PROCEDURE" db/schema.sql` = 0.

### (iii) Export-All.ps1 — confirm tables-only (no re-introduction)
The pg_dump already uses the `@rtmTables` -t whitelist (26 tables) + --schema-only -> pg_dump with -t dumps ONLY those
tables, NOT functions. So a future Export-All will NOT re-introduce functions. VERIFY this (no function dump path exists);
add a one-line comment documenting that functions are sourced from db/functions/* and intentionally excluded from schema.sql.
(No logic change expected — confirm only. If any function-dump path exists, remove it.)

### (iv) Compare-ToBaseline [A] carve-aware — MANDATORY (else stripping schema.sql makes A WORSE)
After (ii), schema.sql has no functions; the live rebuild has them (from db/functions/*). Compare [A] currently diffs the
full server dump vs schema.sql ALONE -> it would now flag ALL ~43 server functions as "extra". FIX: build the [A] BASELINE
as schema.sql + db/functions/01..04 concatenated (tables from schema.sql, routines from db/functions/*), matching what the
rebuild actually applies. Then the line-diff reflects REAL drift only. (Normalize-Schema already strips comments/SET/blank.)
Expected after fix: A:0 on a clean rebuild.

## ACCEPTANCE (object-store + functional)
- `grep -cE "^CREATE (OR REPLACE )?(FUNCTION|PROCEDURE)" db/schema.sql` = 0 (schema.sql tables-only).
- db/functions/02 now CREATEs BOTH fn_daytrendagentstatus AND fn_daytrendinteractions (grep both present).
- Export-All confirmed tables-only (functions never re-enter schema.sql).
- Compare-ToBaseline [A] baseline = schema.sql + db/functions/*; routine drift computed against db/functions/*.
- RE-RUN db/tools/Rebuild-Proof.ps1 on a scratch DB -> Compare **A:0 / B:0 / C:0 / F:0**, zero rebuild errors.
  (Windows/.NET -> operator runs; do NOT claim Delivered without the A:0 result.)

## COMMIT (db:, commit.lock, NO push)
`db: R0d functions single-source — move fn_daytrendinteractions to db/functions, strip 41 fn/proc from schema.sql (tables-only §39.1), Export-All tables-only confirm, Compare [A] carve-aware (baseline=schema+functions) -> A:0`
then §0.6 verify + §0.7 re-sync.

## CAPTURE (NORM-CUR-11 — MANDATORY): append to .claude/skills/role-dba/role-dba.md §B:
`2026-06-21 · FUNCTION SINGLE-SOURCE: routines must live ONLY in db/functions/* (§39.1); schema.sql = table DDL. Duplicating functions in BOTH (pg_dump --schema-only without -t pulls them into schema.sql) -> silent drift: the rebuild applies db/functions/* LAST (CREATE OR REPLACE wins) so runtime is correct, but Compare [A] flags the stale schema.sql copies. Compare's [A] baseline must = schema.sql + db/functions/* (not schema.sql alone) to be carve-aware. Verify CREATE (not mere reference/DROP) when deciding if a fn exists in a file; check the signature (overloads coexist). · SOURCE: R0c rebuild-proof Compare A=12 2026-06-21, R0d fix · status: active`

## REPORT -> binding cc/dba.md RESULT + inbox/coordinator.md. NO push.
