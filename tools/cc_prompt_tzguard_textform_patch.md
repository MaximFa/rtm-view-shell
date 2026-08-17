# CC Task — TZ-guard text-form patch (fix 0b07651 ::interval bug in repo)
> §4-PASS (coordinator 2026-07-16) — WHERE-only ::interval->text-form, VALIDATED on 140 (6 zones no 22007, UpdateTime=timestamptz). SCOPE: GetInteractions ONLY (getUsersStatuses DEFERRED). RUN-CLEARED. Lifts the v3 push-blocker.

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/role-dba/role-dba.md   (§A CORE + §C VERIFY)
Only after reading all files: proceed.

## Git push
Do NOT run `git push`. Commit only.

## Step 0 — INTEGRITY (mandatory, §0.6a)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
    HEAD_LINES=$(git show HEAD:"$f" 2>/dev/null | wc -l); WT_LINES=$(wc -l < "$f" 2>/dev/null)
    if [ "$((HEAD_LINES - WT_LINES))" -gt 0 ]; then git show HEAD:"$f" > "$f"; echo "RESTORED $f"; else echo "OK $f"; fi
done
sync
```

## BINDING preamble (append to .coord/cc/dba.md via Python+fsync)
```
## BINDING <UTC> | spec: dba | directive: tools/cc_prompt_tzguard_textform_patch.md | status: open
### DIRECTIVE (spec->CC): patch db/functions/02_rtsdata_functions.sql arity-2 RTSData_GetInteractions WHERE — replace ::interval cast with text-form AT TIME ZONE (fixes 0b07651 22007 on IANA zone 'Israel'). claim: db/functions/02_rtsdata_functions.sql + .claude/skills/role-dba/role-dba.md (§B). NO push.
```

## TASK (Python-only writes, §0.3 — Edit tool BANNED)

### 1. Patch db/functions/02_rtsdata_functions.sql
In the **arity-2** `RTSData_GetInteractions(p_on_date text, p_tenant_id uuid)` (LANGUAGE sql), replace EXACTLY this block:

OLD:
```
      AND (
            ("UpdateTime" AT TIME ZONE (COALESCE(NULLIF("TimeZone", ''), '+00:00')::interval))::date
          = (now()        AT TIME ZONE (COALESCE(NULLIF("TimeZone", ''), '+00:00')::interval))::date
          )
```
NEW:
```
      AND (
            ("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))::date
          = (now()        AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))::date
          )
```
Rationale (verified on 140): "TimeZone" holds MIXED content — offset strings (-04:00,+02:00), '<empty>', and IANA name 'Israel'. `::interval` cast raises 22007 on 'Israel' -> function errors -> zero rows. Text-form `AT TIME ZONE <zone>` accepts BOTH offset strings and IANA names; empty->'UTC'. "UpdateTime" is timestamptz (probed) so AT TIME ZONE returns the correct agent-local wall-clock date.
DO NOT touch: arity-1 overload, the lowercase `RTSData_getInteractions` aliases (they delegate), RETURNS, LANGUAGE, or any other function. Single WHERE-block change only.

### 2. Append lesson to .claude/skills/role-dba/role-dba.md §B
`2026-07-16 · 0b07651 TZ-guard shipped `TimeZone`::interval — dies 22007 on IANA zone names ('Israel') present in prod-140 (mixed name/offset/empty TZ column) -> RTSData_GetInteractions errored -> today blank; rolled back on 140, repo patched to text-form AT TIME ZONE COALESCE(...,'UTC'). RULE: before ANY TZ-date rewrite, probe target-server TimeZone field CONTENTS (name vs offset vs empty) + UpdateTime tz-kind; never assume offset-only. · SOURCE:db/functions/02_rtsdata_functions.sql arity-2 GetInteractions WHERE, incident 2026-07-16 · status: active`

## Verify (before commit)
```bash
# no ::interval remains in the GetInteractions WHERE
git diff db/functions/02_rtsdata_functions.sql
grep -n "::interval))::date" db/functions/02_rtsdata_functions.sql && echo "FAIL: old cast still present" || echo "OK: no ::interval date-cast"
grep -n "AT TIME ZONE COALESCE(NULLIF(\"TimeZone\"" db/functions/02_rtsdata_functions.sql && echo "OK: text-form present"
bash tools/pre-commit-check.sh db/functions/02_rtsdata_functions.sql
```
NOTE: db/functions/*.sql are applied wholesale on deploy — NOT ledgered migrations. Do NOT add a db_patch_history INSERT (that ledger is for db/migrations only, §38a).

## Commit (commit.lock per §26.3/§42.4; prefix db:)
Message: `db: fix RTSData_GetInteractions TZ-guard — text-form AT TIME ZONE (0b07651 ::interval dies on IANA names)`
Then journal append + lock release + §0.7 re-sync from HEAD. NO push.

## BINDING postamble (write RESULT into .coord/cc/dba.md)
```
### RESULT (CC->spec): commit <hash> . files 02_rtsdata_functions.sql + role-dba.md(§B) . WHERE ::interval->text-form . grep OK . pre-commit OK . status done . verified: object-store
```

## Acceptance criteria
- [ ] arity-2 GetInteractions WHERE uses text-form `AT TIME ZONE COALESCE(NULLIF("TimeZone",''),'UTC')`; NO `::interval`.
- [ ] arity-1, aliases, RETURNS, LANGUAGE unchanged.
- [ ] role-dba §B lesson appended.
- [ ] commit db: on v3, journal + re-sync, NO push.
