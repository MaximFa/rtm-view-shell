# CC task — SUPERSEDE per-row-TZ guard: filter interaction load by UpdateTime SERVER-LOCAL date = today
> §4-PASS (coordinator 2026-07-16) — server-local via current_setting, no per-row TZ. ⚠ HARD CONDITION: DBA must confirm current_setting('TimeZone') resolves to SERVER-LOCAL (+03) in RTM's ACTUAL Npgsql session (NOT DBeaver) before seal — if UTC there, the filter is UTC-date (WRONG) -> escalate to an explicit server zone. + decisive test: loaded-row-count + Incoming recount. RUN-CLEARED.

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/role-backend/role-backend.md
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md
Only after all: proceed.

## Step 0 — INTEGRITY
cd "D:\Claude\Projects\RTM View Shell"; git status --short
Every M file: if HEAD line-count > working → `git show HEAD:"$f" > "$f"`. sync.

## Git push — do NOT push.

## BINDING preamble
Append to `.coord/cc/backend.md`:
`## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_interactions_serverlocal_date.md | status: open`
`### DIRECTIVE: supersede per-row-TZ guard — filter by UpdateTime SERVER-LOCAL date=today (no TimeZone/CASE/interval). Claim: db/functions/02_rtsdata_functions.sql. prefix db.`

## CONTEXT (operator directive — supersedes the whole per-row-TZ line 0b07651→0329bf0→e58cac8)
Operator: 'при перезапуске подхватываем только звонки с UpdateDate=today по локальному времени СЕРВЕРА. Убираем таймзону.' The startup load must filter RTSData_Interaction by UpdateTime's date in the SERVER's LOCAL timezone = today. The per-row "TimeZone" column, the CASE, and ::interval are REMOVED entirely. This equals legacy behaviour (legacy filters OnDate = server-local DateTime.Today) and is robust across servers (uses the DB session/server timezone, not a hardcoded zone).

## CLAIM (touch ONLY this)
- db/functions/02_rtsdata_functions.sql

## CHANGE — RTSData_GetInteractions(p_on_date text, p_tenant_id uuid) WHERE
Replace the current CASE-based WHERE (the per-row `CASE WHEN "TimeZone" ~ ... THEN ... AT TIME ZONE (("TimeZone")::interval) ELSE ... END::date = ...` block) with the SERVER-LOCAL date rule:
```
    FROM "RTSData_Interaction"
    WHERE "TenantId" = p_tenant_id
      AND ("UpdateTime" AT TIME ZONE current_setting('TimeZone'))::date
        = (now()        AT TIME ZONE current_setting('TimeZone'))::date
    ORDER BY "Segment", "UpdateTime" DESC;
```
Notes:
- `current_setting('TimeZone')` = the DB session timezone (= the server-local zone on the RTM DB host). `timestamptz AT TIME ZONE '<that zone>'` yields the server-local wall-clock; `::date` gives the SERVER-LOCAL calendar date. Comparing UpdateTime's server-local date to now()'s server-local date = "updated today in server-local time" — matches legacy's OnDate=DateTime.Today.
- NO reference to the per-row "TimeZone" column. NO CASE. NO ::interval. NO 'Israel'/'+02:00' hardcoding.
- Keep the SELECT column list, the function SIGNATURE (p_on_date stays, unused → C# untouched), RETURNS TABLE, and ORDER BY unchanged. FUNCTION kind preserved (CREATE OR REPLACE FUNCTION, §33.8). Do NOT touch any other function.

## CONSTRAINTS
- db/functions/02_rtsdata_functions.sql ONLY. No C#/legacy/adapter/Shell. No push. §0.3 Python+fsync. After write: sync; tail -3; wc -l.

## ACCEPTANCE
- WHERE now uses `("UpdateTime" AT TIME ZONE current_setting('TimeZone'))::date = (now() AT TIME ZONE current_setting('TimeZone'))::date`; NO "TimeZone"-column ref, NO CASE, NO ::interval.
- Signature/RETURNS/SELECT/ORDER BY unchanged.
- SQL parse-valid (careful review; DBA applies + probes server-local-today on 140 before seal).
- pre-commit-check.sh green.

## COMMIT (commit.lock)
`bash tools/pre-commit-check.sh` → if exit 1 restore+retry.
prefix: `db: supersede per-row-TZ guard — interaction load filter by UpdateTime SERVER-LOCAL date=today (no per-row TimeZone; legacy-equivalent, cross-server)`
NO push. Journal + lock release + §0.7 re-sync.

## BINDING postamble
Append RESULT to `.coord/cc/backend.md`: commit hash, new WHERE quoted, verified: object-store. Plus the HONEST FLAG below.

## HONEST FLAG (state in RESULT — operator must know)
This server-local date change removes ALL per-row TimeZone complexity and matches legacy's date rule, BUT the DBA's analysis showed the ~20x CUMULATIVE inflation (Incoming US All 1317 vs legacy 87; CallbackRequests 259 vs 2; Abandoned 90 vs 0) is NOT the date filter (snapshot metrics already matched legacy; the sign-fix already made the date correct). It looked like metric AGGREGATION (the cumulative 'IncomingOnline…including Waiting' possibly over-counted vs legacy). So after this change the US CUMULATIVE counts may STILL be >> legacy — if so, the residual is the metric-aggregation / current-vs-cumulative question (resume that diagnosis: OUR QueueNumIncomingOnlineCallsAndCallbacks is cumulative InteractionsCount with predicate (Call||Callback)&&External&&Incoming; need the legacy predicate + a Direction/InteractionType/CallType/IsInQueue breakdown to pin the delta). State this so the operator is not surprised.

## NOTE (DBA/coordinator)
- Apply on 140 (CREATE OR REPLACE, body-only) → PROBE that the expression yields the SERVER-LOCAL today (spot-check a near-midnight row + now()) BEFORE seal → RTM reload → operator re-check US grid.
- getUsersStatuses guard follow-up: same server-local date rule when authored.
- Mirrors reconcile via Export-All.
