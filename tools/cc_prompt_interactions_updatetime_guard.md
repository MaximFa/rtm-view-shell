# CC task — Queue-count guard: load interactions by UpdateTime local-date = today (TZ-offset aware)
> §4-PASS (coordinator 2026-07-16) — DB-func WHERE-only, signature/C# untouched, TZ-null guard, operator-directed semantics. CONDITION: functional seal on 140 = queue counts MATCH legacy (US-Support 71->4) after apply+reload, not object-store. RUN-CLEARED.

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/role-backend/role-backend.md
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md
Only after reading all: proceed.

## Step 0 — INTEGRITY
cd "D:\Claude\Projects\RTM View Shell"; git status --short
Every M file: if HEAD line-count > working → `git show HEAD:"$f" > "$f"`. sync.

## Git push
Do NOT run `git push`. Commit only.

## BINDING preamble
Append to `.coord/cc/backend.md`:
`## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_interactions_updatetime_guard.md | status: open`
`### DIRECTIVE: load-guard — filter startup interaction load by UpdateTime local-date=today (TZ-offset). Claim: db/functions/02_rtsdata_functions.sql. prefix db.`

## CONTEXT (operator-directed)
On RTM restart the engine reloads interactions from DB (RTSData_Interaction) via RTSData_getInteractions(OnDate=today, tenant). Because RTSData_Interaction is never cleared (DB midnight-clear not wired) and OnDate is computed in the SERVER timezone (updateTime.Date), the reloaded "today" set is polluted → queue counts inflated vs legacy (US-Support 71 vs 4).
Operator directive: introduce a GUARD so that — even with accumulated data — the load returns ONLY interactions whose UpdateTime local-date = today, honoring each row's TimeZone offset. This is robust regardless of the daily clear or the server timezone.
Legacy parity note: legacy write sets OnDate=updateTime.Date and loads OnDate=DateTime.Today (identical to ours); legacy is correct because its clear runs + its server TZ matches the business TZ. This guard makes ours correct WITHOUT depending on either.

## CLAIM (touch ONLY this)
- db/functions/02_rtsdata_functions.sql

## CHANGE — RTSData_GetInteractions(p_on_date text, p_tenant_id uuid)
This function (~line 305-335) currently ends with:
```
    FROM "RTSData_Interaction" WHERE "OnDate" = p_on_date AND "TenantId" = p_tenant_id
    ORDER BY "Segment", "UpdateTime" DESC;
```
Replace the WHERE clause (keep the SELECT column list and ORDER BY unchanged; keep the function signature — p_on_date stays but is no longer used for filtering, so the C# caller needs no change):
```
    FROM "RTSData_Interaction"
    WHERE "TenantId" = p_tenant_id
      AND (
            ("UpdateTime" AT TIME ZONE (COALESCE(NULLIF("TimeZone", ''), '+00:00')::interval))::date
          = (now()        AT TIME ZONE (COALESCE(NULLIF("TimeZone", ''), '+00:00')::interval))::date
          )
    ORDER BY "Segment", "UpdateTime" DESC;
```
Notes for the implementer:
- "UpdateTime" is `timestamp with time zone` (timestamptz); "TimeZone" is varchar(10) holding an ISO offset like `+03:00`. Casting the offset text to `interval` (`'+03:00'::interval`) and using `timestamptz AT TIME ZONE interval` yields the local wall-clock timestamp for that offset; `::date` gives the local date. Comparing UpdateTime's local date to now()'s local date (same per-row offset) = "updated today in the row's timezone".
- COALESCE(NULLIF("TimeZone",''),'+00:00') guards NULL/empty TimeZone → default UTC.
- Do NOT change the function name, parameters, or RETURNS TABLE(...) column list — only the WHERE. Do NOT touch the p_tenant_id-only overload, RTSData_GetInteractions signatures order, or any other function.
- Keep the lowercase alias `RTSData_getInteractions(p_on_date, p_tenant_id)` (delegates to this) unchanged.

## CONSTRAINTS
- DB function only (db/functions/02_rtsdata_functions.sql). No C#/legacy/adapter touch. No `git push`.
- Edit via Python + os.fsync (§0.3). After write: `sync; tail -3 <f>; wc -l <f>`.

## ACCEPTANCE
- The function body's WHERE now filters by UpdateTime local-date=today with TZ offset; OnDate no longer used in the filter; signature + RETURNS unchanged.
- SQL syntax valid (psql \i or a dry parse if available; else careful review — the file is applied by DBA/devops).
- pre-commit-check.sh green.

## COMMIT (commit.lock)
`bash tools/pre-commit-check.sh` → if exit 1 restore+retry.
prefix: `db: interaction load guard — filter by UpdateTime local-date=today (TZ-offset) so restart ignores stale accumulated interactions (queue-count fix)`
NO push. Journal append + lock release + §0.7 re-sync from HEAD.

## BINDING postamble
Append RESULT to `.coord/cc/backend.md`: commit hash, file+line counts, the new WHERE clause quoted, verified: object-store.

## NOTE (for coordinator/DBA — NOT this task)
- Same guard likely applies to RTSData_getUsersStatuses (agent-state accumulation) — flag as follow-up.
- The DB midnight-clear (RTSData_MidnightClear) is still not wired into the scheduler (task #32) — this guard fixes the DISPLAY; the clear is still worth wiring for table-size hygiene. Separate item.
- Mirrors (staging/regen234, devops/tools) carry the old function — reconcile via Export-All after this canonical fix.
