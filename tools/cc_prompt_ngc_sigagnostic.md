# CC Task — Make NGC FUNCTION→PROCEDURE DROPs signature-agnostic (db/functions/01)

> Session devops-2-0607. Durable RTM-SEC-002 hardening. File-01 converts NGC routines to
> PROCEDURE using FIXED-signature `DROP FUNCTION IF EXISTS "NGC_X"(args)`. On a server where the
> old routine is a FUNCTION with a DIFFERENT signature, the fixed DROP no-ops → CREATE PROCEDURE
> clashes → routine stays FUNCTION → RTM 42809. Same defect class fixed in file-02 (commit 55eb049).
> Make file-01 robust the same way. NON-blocking for Server 234 (its NGC are already PROCEDURE),
> but durable for every other server.

## 0. §0.6a integrity check (run FIRST), 0b §40 skill reads — as in the standard CC preamble.

## Multi-session sync (§42.6) — slug devops-2-0607
Claims (file-mode): `db/functions/01_ngc_functions.sql` ONLY.
- S1 push-barrier check (non-empty `.coord/push/request.md` → STOP).
- S2 `python3 tools/coord_check_claims.py devops-2-0607 db/functions/01_ngc_functions.sql` (exit1 → STOP).
- S3/S4 commit.lock + `bash tools/cc_post_commit.sh devops-2-0607 <hash>`.
- Modify ONLY `db/functions/01_ngc_functions.sql`.

## Git push — DO NOT (§37). §0.3 — Edit BANNED, Python+fsync only, then `tail -3`+`wc -l`.

---

## The change

File-01 defines **14** NGC procedures (12 `CREATE OR REPLACE PROCEDURE`, 2 `CREATE PROCEDURE`
from the _009 hotfix) and uses **~40 fixed-signature `DROP FUNCTION IF EXISTS "NGC_X"(...)`** lines
to clear any prior FUNCTION before each `CREATE ... PROCEDURE`. There are currently **0** DO-loops.

For **each NGC procedure**, replace the fixed-signature `DROP FUNCTION IF EXISTS "NGC_<Name>"(...)`
line(s) that immediately precede its `CREATE [OR REPLACE] PROCEDURE "NGC_<Name>"` with **one
signature-agnostic DO-loop** keyed on `proname` (verbatim pattern from file-02 55eb049):

```sql
DO $drop_<name>$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT oid::regprocedure AS sig
    FROM pg_proc
    WHERE proname = 'NGC_<Name>' AND prokind = 'f'
  LOOP
    EXECUTE 'DROP FUNCTION ' || r.sig::text;
  END LOOP;
END $drop_<name>$;
```

Rules:
- One DO-block per routine, with a UNIQUE dollar-tag (`$drop_getorcreatequeue$`, etc.) — no tag reused.
- `prokind='f'` filter means an existing PROCEDURE is left untouched (idempotent re-run).
- Drop ALL fixed-arg `DROP FUNCTION IF EXISTS "NGC_<Name>"(...)` overloads for that routine
  (some routines have several historical-signature DROP lines) — the DO-loop replaces all of them.
- Keep every `CREATE [OR REPLACE] PROCEDURE` body **byte-for-byte unchanged**. Only the DROP lines change.
- Do NOT touch any non-NGC routine or any `DROP PROCEDURE` lines.
- The 14 routines (verify by scanning, do not trust this list blindly):
  NGC_GetOrCreateQueue, NGC_GetOrCreateAgentGroup, NGC_ModifyBusinessUnit, NGC_DeleteBusinessUnit,
  NGC_ModifySupergroup, NGC_DeleteSupergroup, NGC_CreateBusinessUnitQueueClassificationMapping,
  NGC_DeleteBusinessUnitQueueClassificationMapping, NGC_CreateBusinessUnitSupergroupMapping,
  NGC_DeleteBusinessUnitSupergroupMapping, NGC_CreateSupergroupAgentgroupMapping,
  NGC_DeleteSupergroupAgentgroupMapping, NGC_SetUserAgentgroup, NGC_DeleteUserAgentgroup.
  (If file-01 also creates NGC_CreateBusinessUnit / NGC_CreateSupergroup as procedures, cover them too.)

## Self-test — fresh DB (REQUIRED; this is the durability proof)
```powershell
# fresh DB from baseline, then apply the edited file-01, then assert
powershell -ExecutionPolicy Bypass -File db\tools\Create-FreshDb.ps1 -AppPassword "!@#qweASDzxc" -SuperPassword "!@#qweASDzxc"  # or Restore-All.ps1 -DropAndRecreate
$env:PGPASSWORD="!@#qweASDzxc"; $psql="C:\Program Files\PostgreSQL\18\bin\psql.exe"
& $psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f db\functions\01_ngc_functions.sql   # must exit 0
# every NGC routine must be a PROCEDURE:
& $psql -h localhost -U postgres -d rtmviewdb -t -A -c "SELECT proname,prokind FROM pg_proc WHERE proname LIKE 'NGC_%' AND prokind<>'p';"  # expect ZERO rows
$env:PGPASSWORD=$null
```
Also (static): `grep -c '\$drop_' db/functions/01_ngc_functions.sql` ≥ 14;
`grep -c 'DROP FUNCTION IF EXISTS "NGC_' db/functions/01_ngc_functions.sql` == 0;
dollar-quote balance even; `tail -3` ends on a proper closing token (`$$;`/`;`/`END`); `wc -l` sane.

If no Postgres in the CC env, run the static checks and clearly report that the fresh-DB apply
was NOT executed — do NOT claim GREEN without it.

## Commit
- `bash tools/pre-commit-check.sh` → 0; commit.lock → `git add db/functions/01_ngc_functions.sql`
  → `git commit -m "db: NGC FUNCTION->PROCEDURE drops sig-agnostic (RTM-SEC-002 durable, file-01)"`
- §0.6 post-commit + `tools/cc_post_commit.sh` + journal + lock release + HEAD re-sync. NO push.

## Report
DO-loop count, residual fixed-sig NGC DROP count (must be 0), fresh-DB apply result (exit code +
zero non-procedure rows) OR explicit "static-only, not run", commit hash.
