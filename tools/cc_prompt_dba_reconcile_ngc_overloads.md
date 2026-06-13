# CC Task — DBA: reconcile db/functions/01 (NGC) + 02 (RTSData_get*) to authoritative source — ALL 45 failing routines (release-blocker)

> Authored by dba-0610 (RTM DBA, role #5). Consolidated db/functions/01 NGC-routine fix.
> Closes the 45 release-blocker (42883 arity + 42809 re-apply) by aligning baseline routine
> definitions to the authoritative dev DB. Read-only diagnosis already done (dba flush 2026-06-13T09:51Z).
> SUPERSEDES/CONSOLIDATES the separate queue items on this same file: devops E-016 (sig-agnostic DROP)
> + backend E-004 (NGC_GetOrCreate* Id+IsActive INSERT). One file = one fix (L-SC-09). Coordinator §4 + the
> 2 host-confirms in STEP 0 are PREREQUISITES — do not skip.

## Git push
Do NOT run `git push`. Commit only. Push is requested separately (§37).

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/rtm-service-expert/rtm-service-expert.md   (§4 routine-kind, §10 baseline-can-be-wrong)
Only after reading all files: proceed.

## STEP 0 — MANDATORY integrity + sync + binding (NO EXCEPTIONS)

### 0a. Integrity (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
  HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
  if [ "$((HEAD_LINES - WT_LINES))" -gt 0 ]; then echo "TRUNCATED $f"; git show HEAD:"$f" > "$f"; echo "RESTORED $f"; else echo "OK $f"; fi
done
sync
```

### 0b. Barrier + sync block (session-coord)
- If `.coord/push/request.md` exists with content -> PUSH BARRIER ACTIVE -> STOP, do not start.
- Slug: dba-0610. CLAIM (file-mode, this task ONLY): `db/functions/01_ngc_functions.sql` + `db/functions/02_rtsdata_functions.sql`.
  Touch NO file outside that claim. `db/schema.sql` is READ-ONLY reference (do not edit it).
- commit.lock around the commit (atomic open(x), retry 5x60s, never delete a lock you do not own).

### 0c. CC<->spec binding (NORM-CUR-07)
Append a BINDING-OPEN block to `.coord/cc/dba.md` (Python+fsync):
```
## <UTC> | binding: dba <-> CC | directive: tools/cc_prompt_dba_reconcile_ngc_overloads.md | status: open
```
At the END (after commit) append the RESULT block (commit hash, files, prokind/arity verify output, blockers) to `.coord/cc/dba.md`. Do NOT write the result to inbox/coordinator.md.

## STEP 1 — AUTHORITY VERIFICATION (read-only; STOP-on-mismatch)  [the 2 host-confirms]
RTM DB ops use PowerShell + psql.exe on the Windows host (psql is not on PATH in WSL2 bash — use PowerShell).

(a) **Confirm the authoritative source.** Export-All (or `\sf`) the NGC_Create* routines from the KNOWN-GOOD dev DB
    (`rtmviewdb`) and diff the routine SET vs `db/schema.sql`. Expected authoritative overloads (already present in
    db/schema.sql — port THESE exact bodies):
      - NGC_CreateBusinessUnit            : FUNCTION(text,text,uuid) + FUNCTION(text,text,text,uuid)            [schema.sql:54,70]
      - NGC_CreateSupergroup              : FUNCTION(text,text,uuid) + FUNCTION(text,text,text,uuid) + PROCEDURE(integer,text,text,text,uuid)  [schema.sql:153,169,185]
      - NGC_CreateSupergroupAgentgroupMapping : FUNCTION(int,text,uuid) RETURNS void + PROCEDURE(int,text,text,uuid)  [schema.sql:202,216]
      - RTSData_getInteractions / RTSData_getUsersStatuses (in db/functions/02): FUNCTION(uuid) + FUNCTION(text,uuid)  [schema.sql:1018/1027, 1038/1047]
    If the dev DB and schema.sql DISAGREE on these -> STOP, report to dba/coordinator (dev DB wins as authority; schema.sql may be stale on something else).

(b) **Confirm 42703 is TABLE drift, not a function bug.** On 45: `\d "NGC_Queues"` and `\d "NGC_AgentGroups"` — verify
    whether `"CreatedDatetime"` column EXISTS. Repo (schema.sql + functions/01) both expect it. If the 45 table lacks it,
    that EXPLAINS the 42703 (stale functions/01 INSERTed it; 45 table lacks it). FIX is function-side (STEP 2.3b: port schema.sql GetOrCreate body WITHOUT CreatedDatetime). Do NOT add/rename the column inside functions, and no table DDL is required (option A).

(c) **Confirm C# caller arities.** `grep -n` in `RTM/RTM/BusinessUnitData.cs` + `RTM/RTM/DBMng.cs` for every
    GetScalar / ExecuteNonQuery call to NGC_CreateBusinessUnit / NGC_CreateSupergroup / NGC_CreateSupergroupAgentgroupMapping.
    The ported overload set MUST cover each invoked arity AND kind (GetScalar => FUNCTION RETURNS; ExecuteNonQuery => PROCEDURE).
    ALSO RTSData_getInteractions / RTSData_getUsersStatuses: callers DBMng.cs:494/483 pass **2 params (@OnDate,@TenantId)** via GetDataTable (=SELECT => FUNCTION). Current 02 has ONLY arity-1 (p_tenant_id) => the 2-arg call = 42883.

## STEP 2 — TASK: reconcile db/functions/01 (NGC) + db/functions/02 (RTSData_get*)
### 2A — in 01_ngc_functions.sql, for the 3 NGC_Create* routines (NGC_CreateBusinessUnit, NGC_CreateSupergroup, NGC_CreateSupergroupAgentgroupMapping):
1. **Kind-&-sig-agnostic DROP guard** (FIX C / E-016 pattern — pg_proc loop, drops ALL overloads regardless of kind):
   ```sql
   DO $drop$ DECLARE r record; BEGIN
     FOR r IN SELECT oid::regprocedure AS sig, prokind FROM pg_proc WHERE proname='<RoutineName>' LOOP
       IF r.prokind='p' THEN EXECUTE 'DROP PROCEDURE '||r.sig::text;
       ELSE                  EXECUTE 'DROP FUNCTION ' ||r.sig::text; END IF;
     END LOOP; END $drop$;
   ```
   (Mirror the existing NGC_CreateSupergroup guard at functions/01:384-393 — already correct; replicate for the other two.)
2. **CREATE every overload** from the authoritative source (STEP 1a), bodies VERBATIM from db/schema.sql (port, do not invent).
   Keep `p_tenant_id uuid` LAST (§33.3). RETURNS-TABLE FUNCTIONs stay FUNCTION (GetScalar callers); the (integer,...) upsert
   stays PROCEDURE (ExecuteNonQuery/CALL caller, §33.8).
3b. **[coord §4 — REQUIRED scope add, verified vs schema.sql] ALSO regenerate NGC_GetOrCreateQueue + NGC_GetOrCreateAgentGroup**
   from schema.sql (PROCEDURE arity 3, schema.sql:493 / :479). Authoritative body inserts
   `("Id","ExternalId","Name","IsActive","TenantId") VALUES (gen_random_uuid(), p_external_id, p_name, true, p_tenant_id) ON CONFLICT ... DO NOTHING`
   — **NO "CreatedDatetime"**. This is the 42703 FIX (function-side, option A — the stale functions/01 body INSERTed CreatedDatetime
   which 45's NGC_Queues/NGC_AgentGroups lack) AND it INCORPORATES E-004 (Id=gen_random_uuid() + IsActive=true). Wrap both in the
   same kind-agnostic DROP guard. backend (10:30) + schema.sql both confirm: GetOrCreate is IN SCOPE here; no table DDL needed.
3. **PRESERVE the E-004 fix** if already in HEAD: NGC_GetOrCreateQueue / NGC_GetOrCreateAgentGroup INSERTs must include
   `Id = gen_random_uuid()` + `IsActive = true` (23502 NULL fix). If a fresh-HEAD diff shows it landed, keep it; if not, do
   NOT regress it. Do NOT otherwise modify GetOrCreate* here unless STEP 1b proves a function-side issue.
### 2B — [scope add caught by dba post-§4] in db/functions/02_rtsdata_functions.sql, regenerate RTSData_getInteractions + RTSData_getUsersStatuses
- Port from schema.sql the **arity-2 FUNCTION** overload `(p_on_date text, p_tenant_id uuid)` RETURNS TABLE — schema.sql:1027 (getInteractions) / :1047 (getUsersStatuses). FUNCTION kind (callers DBMng.cs:494/483 use GetDataTable=SELECT, pass @OnDate+@TenantId). Current 02 has only arity-1 => 2-arg call = 42883.
- Port BOTH overloads as defined in schema.sql (arity-1 :1018/:1038 + arity-2 :1027/:1047) so existing callers of either arity resolve. STAY FUNCTION (SELECT-called, never PROCEDURE — §33.8). p_tenant_id LAST.
- Wrap each in the SAME kind-&-sig-agnostic DROP guard (pg_proc loop).

4. Do NOT touch table DDL, db/schema.sql, or any non-claimed file.
5. **§38a self-record is NOT needed** — this edits db/functions/ (re-applied wholesale on deploy), not a db/migrations/ ledger file.

## STEP 3 — VERIFY (must pass before commit)
On dev DB after applying the edited 01_ngc_functions.sql + 02_rtsdata_functions.sql:
- `SELECT proname, pg_get_function_identity_arguments(oid), prokind FROM pg_proc WHERE proname LIKE 'NGC_Create%' OR proname LIKE 'NGC_GetOrCreate%' OR proname IN ('RTSData_getInteractions','RTSData_getUsersStatuses') ORDER BY 1,2;`
  -> shows exactly the authoritative overload+kind set (matches STEP 1a); GetOrCreate/RTSData_get* with correct prokind ('p' for GetOrCreate PROCEDURE, 'f' for RTSData FUNCTION). 
- **Idempotent re-apply:** run the file TWICE in one session -> second run clean (no 'cannot change routine kind' 42809, no 42883). This is the deploy Phase-5 re-apply simulation — the whole point of the DROP guards.
- Each invoked C# arity (STEP 1c) resolves (no 42883).
- `bash tools/pre-commit-check.sh db/functions/01_ngc_functions.sql db/functions/02_rtsdata_functions.sql` -> exit 0 (no truncation; proper closing).

## STEP 4 — COMMIT (commit.lock held; §0.6 post-commit; PD-007 re-sync; NO push)
```bash
# acquire commit.lock (atomic, retry) ...
bash tools/pre-commit-check.sh db/functions/01_ngc_functions.sql db/functions/02_rtsdata_functions.sql   # exit 0 required
GIT_INDEX_FILE=/tmp/dba-idx git add db/functions/01_ngc_functions.sql db/functions/02_rtsdata_functions.sql   # explicit paths only
GIT_INDEX_FILE=/tmp/dba-idx git commit -m "db: reconcile NGC_Create*/GetOrCreate (01) + RTSData_get* arity-2 (02) to authoritative set + kind-agnostic DROP guards (45 42883/42703/42809 fix)"
# §0.6 post-commit: git status --short clean; git diff HEAD -- db/functions/01_ngc_functions.sql empty; line counts match
# journal append (Python+fsync) ; release commit.lock ; sync ; PD-007 re-sync BOTH: for f in db/functions/01_ngc_functions.sql db/functions/02_rtsdata_functions.sql; do git show HEAD:"$f" > "$f"; done
# NORM-CUR-07: write RESULT block to .coord/cc/dba.md (commit hash + STEP-3 verify output + status: done)
# bash tools/cc_post_commit.sh dba-0610 <hash>
```
Do NOT push.

## Acceptance criteria
- [ ] STEP 1 authority confirmed (dev DB == schema.sql for ALL failing routines: NGC_Create* + GetOrCreate + RTSData_get*) OR stopped-with-report on mismatch.
- [ ] All authoritative overloads present, bodies ported verbatim from schema.sql, p_tenant_id last, correct kind per caller.
- [ ] Kind-&-sig-agnostic DROP guard on ALL touched routines in 01 AND 02 (idempotent double-apply clean — no 42809/42883).
- [ ] RTSData_getInteractions/getUsersStatuses carry the arity-2 FUNCTION (DBMng 2-arg call resolves); BOTH files committed.
- [ ] E-004 Id+IsActive INSERT preserved (not regressed); no table DDL / schema.sql / out-of-claim edits.
- [ ] pre-commit-check exit 0; §0.6 post-commit clean; RESULT in .coord/cc/dba.md; no push.

## NOTES for coordinator (read before §4 / dispatch)
- This CONSOLIDATES queue items on db/functions/01: devops **E-016** (sig-agnostic DROP — incorporated in STEP 2.1) + backend **E-004** (Id+IsActive INSERT — preserved in STEP 2.3). Recommend RETIRE/sequence those two queue items into THIS single fix to avoid same-file lost-update (L-SC-09). Coordinator arbitrates ownership.
- Barrier-class: this is a schema/migration-class DB change -> at push barrier it triggers the Tech Writer doc-sync gate (§42.7 / L-SC-23).
- 42703 CreatedDatetime IS fixed here FUNCTION-SIDE (STEP 2.3b: port schema.sql GetOrCreate body, no CreatedDatetime = option A, no table DDL) — corrected per coord §4 + backend authority + schema.sql:493/479. (The optional table ADD COLUMN = option B, NOT needed.)
- ⚠ **dba post-§4 SCOPE CATCH (needs coordinator re-confirm before dispatch):** the §4-GO covered 5 routines in 01, but the 45 42883 failure set ALSO includes RTSData_getInteractions/getUsersStatuses — they live in **db/functions/02_rtsdata_functions.sql** (arity-1 only; DBMng.cs:494/483 pass 2 args). Added STEP 2B + extended CLAIM/commit to 02. coord_check = no conflict on 01 or 02. Re-confirm the 01+02 claim before dispatch.
