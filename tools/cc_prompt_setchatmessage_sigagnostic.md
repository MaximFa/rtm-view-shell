# CC Task — Sig-agnostic DROP for ALL 3 FUNCTION->PROCEDURE conversions in db/functions/02 (durable RTM-SEC-002)

> Session devops-2-0607. server45 deploy proved functions/02's fixed-14-arg DROP FUNCTION for RTSData_SetChatMessage
> does not match a server where the function has a different signature -> DROP no-ops -> CREATE PROCEDURE clashes
> (B=1). Fold the sig-agnostic fix (from staging/fix_setchatmessage_server45.sql) into the canonical functions/02
> so future deploys don't hit it. SCOPE: SetChatMessage ONLY (see devops verdict in coordinator.md — the 12 NGC +
> SetInteraction + SetUserStatus are already PROCEDURE on all observed servers + carry multi-sig DROPs -> deferred
> to a separate, fresh-DB-tested hardening task; not in this commit).

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES-WT_LINES))" -gt 0 ]; then echo "TRUNCATED: $f"; git show HEAD:"$f" > "$f"; echo "RESTORED"; else echo "OK: $f"; fi
done
sync; echo done
```
NOTE: db/functions/02_rtsdata_functions.sql is BOM-less UTF-8 (psql-fed file — NO BOM, keep it BOM-less; only PS1
need BOM). Known false-M: db/data/02_metrics.sql, db/schema.sql.

---

## Multi-session sync — MANDATORY
Session slug: `devops-2-0607`
Claims: `db/functions/02_rtsdata_functions.sql`

### S1. Push barrier check (marker-based)
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo STOP; exit 1; fi
```
### S2. Claim
```bash
python3 tools/coord_check_claims.py devops-2-0607 db/functions/02_rtsdata_functions.sql
```
Modify ONLY db/functions/02_rtsdata_functions.sql (plus /tmp throwaways).
### S3. Commit lock — `/tmp/acquire_lock.py` (owner devops-2-0607), retry 5×60s. While holding:
`bash tools/pre-commit-check.sh` -> `git add db/functions/02_rtsdata_functions.sql`
-> `git commit -m "db: sig-agnostic DROP for RTSData_SetChatMessage in functions/02 (RTM-SEC-002 durable fix)"`
-> §0.6 verify.
### S4 + S4b. `bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)` ; then `sync`.
### S5. NO push (§37). Joins the mini-barrier with the 3 deploy commits.

## The change — apply the SAME sig-agnostic pattern to ALL 3 conversions in file 02

The 3 routines, each currently a fixed-arg `DROP FUNCTION IF EXISTS "name"(...)` (SetUserStatus also has a
`DROP PROCEDURE IF EXISTS`) followed by CREATE PROCEDURE / CREATE OR REPLACE PROCEDURE:
  1. RTSData_SetInteraction   (~line 16 DROP)
  2. RTSData_SetUserStatus    (~lines 161 DROP FUNCTION + 165 DROP PROCEDURE)
  3. RTSData_SetChatMessage   (~line 238 DROP)

For EACH, REPLACE the fixed-arg DROP FUNCTION line(s) with a signature-AGNOSTIC DO-loop, and ensure the CREATE is
`CREATE OR REPLACE PROCEDURE` (idempotent). The param list and body of each routine stay EXACTLY as-is. Pattern
(use a DISTINCT dollar-tag per routine — $drop_setinteraction$, $drop_setuserstatus$, $drop_setchatmessage$ — all
distinct from the body's $$):
```sql
-- Signature-agnostic: drop ANY existing FUNCTION of this name (sig may differ across servers) before the procedure.
DO $drop_<routine>$
DECLARE r record;
BEGIN
    FOR r IN
        SELECT oid::regprocedure AS sig
        FROM pg_proc
        WHERE proname = '<RoutineName>' AND prokind = 'f'
    LOOP
        EXECUTE 'DROP FUNCTION ' || r.sig::text;
    END LOOP;
END
$drop_<routine>$;

CREATE OR REPLACE PROCEDURE "<RoutineName>"( ... SAME params UNCHANGED ... )
LANGUAGE plpgsql AS $$ ... SAME body UNCHANGED ... $$;
```
For SetUserStatus: replace its `DROP FUNCTION IF EXISTS` with the DO-loop; you MAY drop the now-redundant
`DROP PROCEDURE IF EXISTS "RTSData_SetUserStatus"(...)` line (CREATE OR REPLACE PROCEDURE handles re-runs) OR keep
it — either is fine, but the DO-loop must be present and the CREATE must be OR REPLACE.

Do NOT touch any other routine: RTSData_MidnightClear, RTSData_GetInteractions/getInteractions,
RTSData_GetUsersStatuses/getUsersStatuses, fn_daytrendagentstatus all STAY functions — leave their DROP/CREATE
exactly as-is.

## Self-test (no live DB; if a scratch DB is available, even better)
```bash
for r in RTSData_SetInteraction RTSData_SetUserStatus RTSData_SetChatMessage; do
  echo "== $r =="
  grep -c "DO \$drop_$(echo $r | sed 's/RTSData_//' | tr A-Z a-z)\$\|prokind = 'f'" db/functions/02_rtsdata_functions.sql
  echo -n "fixed-arg DROP FUNCTION remaining (expect 0): "; grep -c "DROP FUNCTION IF EXISTS \"$r\"" db/functions/02_rtsdata_functions.sql
  echo -n "CREATE OR REPLACE PROCEDURE (expect 1): "; grep -c "CREATE OR REPLACE PROCEDURE \"$r\"" db/functions/02_rtsdata_functions.sql
done
# 3 DO-loops total for the conversions:
grep -c "prokind = 'f'" db/functions/02_rtsdata_functions.sql   # expect 3
# stay-function routines untouched (still FUNCTION):
for r in RTSData_MidnightClear RTSData_GetInteractions fn_daytrendagentstatus; do
  echo -n "$r still function: "; grep -c "CREATE OR REPLACE FUNCTION \"\?$r" db/functions/02_rtsdata_functions.sql
done
# optional scratch PG: psql -v ON_ERROR_STOP=1 -f db/functions/02_rtsdata_functions.sql twice (idempotent)
```

## Commit
ONE commit, prefix `db:`, message:
`db: sig-agnostic DROP for the 3 FUNCTION->PROCEDURE conversions in functions/02 (RTM-SEC-002 durable fix)`
Then S4 wrapper. NO push.

## Git push
Do NOT run `git push` automatically. Commit only (§37).
