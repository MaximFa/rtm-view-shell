# CC Task — Part B: RTSData_SetInteraction + RTSData_SetChatMessage FUNCTION->PROCEDURE (file 02, RTM-SEC-002)

> Session devops-2-0607. Completes the RTM-write routine kind fix in db/functions/02_rtsdata_functions.sql.
> Two RTM-write routines are stale FUNCTION and must be PROCEDURE (called via CALL, §33.3/§33.8):
>   1. RTSData_SetInteraction — prod already PROCEDURE; source of the correct def = db/schema.sql.
>   2. RTSData_SetChatMessage — broken in BOTH repo AND prod (still FUNCTION) -> Compare's prokind-diff did NOT
>      catch it; HAND-CONVERT (schema.sql is NOT a valid source here). Same method as _009.
> Also verify RTSData_SetUserStatus is already PROCEDURE (fix if not). Do NOT touch the RTSData READ functions
> (RTSData_getUsersStatuses / RTSData_getInteractions — group C, SELECT, stay FUNCTION, §33.3 E).

## Step 0 — MANDATORY INTEGRITY CHECK (§0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l)
    WT_LINES=$(wc -l < "$f" 2>/dev/null)
    DIFF=$((HEAD_LINES - WT_LINES))
    if [ "$DIFF" -gt 0 ]; then
        echo "TRUNCATED: $f (HEAD=$HEAD_LINES, working=$WT_LINES, missing=$DIFF)"
        git show HEAD:"$f" > "$f"; echo "RESTORED: $f"
    else echo "OK: $f ($WT_LINES lines)"; fi
done
sync; echo "=== Integrity check complete ==="
```
db/functions/02_rtsdata_functions.sql was just GRANTED from daytrend — RE-READ from fresh HEAD before editing;
confirm hash-object == HEAD. Known false-M: db/data/02_metrics.sql, db/schema.sql.

---

## Multi-session sync — MANDATORY, NO EXCEPTIONS
Session slug: `devops-2-0607`
Claims for this task: `db/functions/02_rtsdata_functions.sql`

### S1. Push barrier check (marker-based)
```bash
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md; echo STOP; exit 1
fi
```
### S2. Claim discipline
```bash
python3 tools/coord_check_claims.py devops-2-0607 db/functions/02_rtsdata_functions.sql
```
Modify ONLY db/functions/02_rtsdata_functions.sql (plus /tmp throwaways).
### S3. Commit lock — `/tmp/acquire_lock.py` (owner devops-2-0607), retry 5×60s, phantom-aware. While holding:
`bash tools/pre-commit-check.sh` -> `git add db/functions/02_rtsdata_functions.sql`
-> `git commit -m "db: RTSData_SetInteraction + RTSData_SetChatMessage FUNCTION->PROCEDURE (RTM-SEC-002)"`
-> §0.6 post-commit verify.
### S4 + S4b. `bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)` ; then `sync`.
### S5. NO push (§37).

---

## Fix 1 — RTSData_SetInteraction (source = db/schema.sql)
Same method as the 12-NGC fix. In 02_rtsdata_functions.sql, replace the stale
`CREATE OR REPLACE FUNCTION "RTSData_SetInteraction"( ... ) ... $$;` block with:
```sql
DROP FUNCTION IF EXISTS "RTSData_SetInteraction"(<OLD function arg-type list>);
CREATE OR REPLACE PROCEDURE "RTSData_SetInteraction"(<current arg list from db/schema.sql PROCEDURE>)
LANGUAGE plpgsql AS $$
<body from db/schema.sql PROCEDURE>
$$;
```
- Source = the `CREATE PROCEDURE public."RTSData_SetInteraction"(...)` in db/schema.sql (strip `public.` to match
  file style; UNQUALIFIED, search_path=public).
- R2 body-equivalence: confirm the schema.sql PROCEDURE body is logically the current behaviour; if the 01/02
  FUNCTION body has logic NOT in the schema.sql procedure, STOP + flag (don't silently overwrite). NOTE schema.sql
  also contains an OLD 28-param FUNCTION overload of this name — IGNORE that; adopt the PROCEDURE (~50-param) which
  is what RTM CALLs. DROP FUNCTION IF EXISTS must target the OLD signature present in db/functions today.

## Fix 2 — RTSData_SetChatMessage (HAND-CONVERT — schema.sql is NOT a source; prod is also broken)
db/schema.sql has this as FUNCTION too (prod is latently broken). Do NOT copy from schema.sql. Instead convert the
EXISTING db/functions/02 definition in place, preserving its body 1:1:
```sql
DROP FUNCTION IF EXISTS "RTSData_SetChatMessage"(<OLD function arg-type list>);
CREATE OR REPLACE PROCEDURE "RTSData_SetChatMessage"(<same param list, MINUS any RETURNS, IN-qualified as needed>)
LANGUAGE plpgsql AS $$
<EXACT existing body, unchanged>
$$;
```
- Remove `RETURNS void`. Keep the parameter list and body IDENTICAL to the current function (only kind changes).
- If the function `RETURN`s a value anywhere in its body (not just RETURNS void), STOP + flag — a value-returning
  function cannot become a void procedure without logic review.
- ALSO STOP + flag if the function has any OUT/INOUT parameters — that changes the CALL arity contract the RTM
  DBAdapter depends on (fixed positional param list). Convert ONLY if it is IN-params + RETURNS void.

## Fix 3 — verify RTSData_SetUserStatus
Confirm it is already `CREATE ... PROCEDURE "RTSData_SetUserStatus"` in 02 (it should be). If it is FUNCTION,
convert it the same way (hand-convert, body 1:1). If already PROCEDURE, leave it untouched.

## Do NOT
- Do NOT touch RTSData_getUsersStatuses / RTSData_getInteractions (group C reads — SELECT, stay FUNCTION).
- Do NOT touch any other file. Do NOT run Export-All / regenerate schema.sql. Do NOT add a migration (prod
  follow-up migration is a separate post-release task).

## Self-test (no live DB)
```bash
for r in RTSData_SetInteraction RTSData_SetChatMessage RTSData_SetUserStatus; do
  echo -n "$r: "; grep -hoE "CREATE (OR REPLACE )?(PROCEDURE|FUNCTION) \"$r\"" db/functions/02_rtsdata_functions.sql | head -1
done
# expect all three PROCEDURE. Reads stay FUNCTION:
for r in RTSData_getUsersStatuses RTSData_getInteractions; do
  echo -n "$r: "; grep -hoE "CREATE (OR REPLACE )?(PROCEDURE|FUNCTION) \"$r\"" db/functions/02_rtsdata_functions.sql | head -1
done
grep -c "DROP FUNCTION IF EXISTS" db/functions/02_rtsdata_functions.sql   # expect >= 2 (SetInteraction + SetChatMessage)
# whole-file balanced $$ / proper ending (pre-commit-check catches truncation)
```

## Commit
ONE commit, prefix `db:`, message:
`db: RTSData_SetInteraction + RTSData_SetChatMessage FUNCTION->PROCEDURE (RTM-SEC-002)`
Then the S4 wrapper. NO push.

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately (§37).
