# CC Task — Fix 12 stale FUNCTION defs in db/functions/01_ngc_functions.sql -> PROCEDURE (RTM-SEC-002)

> Session devops-2-0607. Compare-ToBaseline (run on prod) proved db/functions/01_ngc_functions.sql is STALE:
> 12 NGC_* write routines are CREATE OR REPLACE FUNCTION there, but RTM calls them via CALL
> (CommandType.StoredProcedure) and they MUST be PROCEDURE (§33.8 / RTM-SEC-002). Prod + db/schema.sql already
> have them as PROCEDURE; a fresh install from db/functions/ would create FUNCTIONs -> 42809 on every RTM event.
> Same class as the _009 incident, scaled. Prod is already correct — do NOT touch prod.
> NOTE: the 13th routine (RTSData_SetInteraction, in 02_rtsdata_functions.sql) is handled separately — it is
> currently claimed by another session (queued). This task covers ONLY the 12 NGC_* routines in file 01.

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
db/functions/01_ngc_functions.sql may be PD-007-truncated — the loop restores from HEAD. Confirm it matches HEAD
(git hash-object vs git rev-parse HEAD:db/functions/01_ngc_functions.sql) BEFORE editing.
Known false-M: db/data/02_metrics.sql, db/schema.sql.

---

## Multi-session sync — MANDATORY, NO EXCEPTIONS
Session slug: `devops-2-0607`
Claims for this task: `db/functions/01_ngc_functions.sql`  (ONLY — do NOT touch 02_rtsdata_functions.sql)

### S1. Push barrier check
```bash
# marker-based freeze gate (canon update R1): match FREEZE ACTIVE, not mere presence (tombstone re-cache safe)
if cat ".coord/push/request.md" 2>/dev/null | grep -q "FREEZE ACTIVE"; then
    echo "PUSH BARRIER ACTIVE:"; cat .coord/push/request.md; echo STOP; exit 1
fi
```
### S2. Claim discipline
```bash
python3 tools/coord_check_claims.py devops-2-0607 db/functions/01_ngc_functions.sql
```
Modify ONLY db/functions/01_ngc_functions.sql (plus /tmp throwaways).
### S3. Commit lock — `/tmp/acquire_lock.py` (owner devops-2-0607), retry 5×60s, phantom-aware. While holding:
`bash tools/pre-commit-check.sh` -> `git add db/functions/01_ngc_functions.sql`
-> `git commit -m "db: convert 12 NGC_* write routines FUNCTION->PROCEDURE (RTM-SEC-002 fresh-install fix)"`
-> §0.6 post-commit verify.
### S4 + S4b. `bash tools/cc_post_commit.sh devops-2-0607 $(git log -1 --format=%h)` ; then `sync`.
### S5. NO push (§37).

---

## The fix — 12 NGC_* routines in db/functions/01_ngc_functions.sql
NGC_GetOrCreateQueue, NGC_GetOrCreateAgentGroup, NGC_DeleteBusinessUnit, NGC_ModifyBusinessUnit,
NGC_DeleteSupergroup, NGC_ModifySupergroup, NGC_CreateBusinessUnitSupergroupMapping,
NGC_DeleteBusinessUnitSupergroupMapping, NGC_CreateSupergroupAgentgroupMapping,
NGC_DeleteSupergroupAgentgroupMapping, NGC_CreateBusinessUnitQueueClassificationMapping,
NGC_DeleteBusinessUnitQueueClassificationMapping

### Source of truth = db/schema.sql
For EACH, db/schema.sql has the correct prod-matching `CREATE PROCEDURE public."<name>"(<current sig>) ...`
(LANGUAGE plpgsql, full body). Use THAT signature and body — extract it, do NOT invent/hand-edit the body.

### R2 (MANDATORY) — body-equivalence pre-check BEFORE replacing each routine
For EACH of the 12: confirm the schema.sql PROCEDURE body is LOGICALLY IDENTICAL to the current FUNCTION body in
01_ngc_functions.sql — the only differences allowed are (a) routine kind FUNCTION->PROCEDURE and (b) removal of
`RETURNS void`. If any routine's logic DIFFERS (the 01 function body has logic not present in the schema.sql
procedure, or vice versa), STOP and report it to the operator — do NOT silently overwrite. A divergence means 01
carries uncommitted logic that is not on prod; that must be resolved by a human, not blindly replaced.

### Per-routine transformation (in 01_ngc_functions.sql)
Replace the entire stale `CREATE OR REPLACE FUNCTION "<name>"( ... ) ... $$;` block with, in order:
```sql
DROP FUNCTION IF EXISTS "<name>"(<OLD function arg-type list>);   -- can't REPLACE a function with a procedure
CREATE OR REPLACE PROCEDURE "<name>"(<current arg list from schema.sql>)
LANGUAGE plpgsql AS $$
<body from schema.sql>
$$;
```
- Keep db/functions style: UNQUALIFIED name (strip schema.sql's `public.`); file relies on search_path=public.
- DROP FUNCTION IF EXISTS uses the OLD function's arg TYPE list (from the current stale def) so existing servers
  transition cleanly; IF EXISTS so fresh installs don't error.
- CREATE OR REPLACE PROCEDURE for idempotency. Preserve each routine's surrounding comments/headers.

### Do NOT
- Do NOT touch 02_rtsdata_functions.sql or RTSData_SetInteraction (separate, queued).
- Do NOT touch the routines already PROCEDURE (NGC_SetUserAgentgroup, NGC_DeleteUserAgentgroup).
- Do NOT add a migration, do NOT run Export-All / regenerate schema.sql, do NOT modify any other file.

## Self-test (no live DB)
```bash
for r in NGC_GetOrCreateQueue NGC_GetOrCreateAgentGroup NGC_DeleteBusinessUnit NGC_ModifyBusinessUnit NGC_DeleteSupergroup NGC_ModifySupergroup NGC_CreateBusinessUnitSupergroupMapping NGC_DeleteBusinessUnitSupergroupMapping NGC_CreateSupergroupAgentgroupMapping NGC_DeleteSupergroupAgentgroupMapping NGC_CreateBusinessUnitQueueClassificationMapping NGC_DeleteBusinessUnitQueueClassificationMapping; do
  echo -n "$r: "; grep -hoE "CREATE (OR REPLACE )?(PROCEDURE|FUNCTION) \"$r\"" db/functions/01_ngc_functions.sql | head -1
done
# expect every line PROCEDURE; zero FUNCTION among the 12. Balanced $$ (pre-commit-check catches truncation).
# each converted routine must be preceded by DROP FUNCTION IF EXISTS:
grep -c "DROP FUNCTION IF EXISTS" db/functions/01_ngc_functions.sql   # expect >= 12
```

## Commit
ONE commit, prefix `db:`, message:
`db: convert 12 NGC_* write routines FUNCTION->PROCEDURE (RTM-SEC-002 fresh-install fix)`
Then the S4 wrapper. NO push.

## Git push
Do NOT run `git push` automatically. Commit only. Push will be requested separately (§37).
