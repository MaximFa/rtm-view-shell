# CC Task — P3: fn_daytrendagentstatus BU-scoped rewrite (+ UNAVAILABLE outputs + colors)

## Mandatory — read before starting (§40)
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md
Read file: .claude/skills/session-coord/session-coord.md
Only after reading all files: proceed.

## DEPENDENCY — DO NOT RUN until P1 + P2 are deployed AND populated
Requires: P1 table NGC_UserAgentgroup (metrics) populated by P2 (RTM persist) — i.e. RTM Service has
run and filled membership. If NGC_UserAgentgroup is empty/missing, agent metrics will be empty.
Confirm rows exist before relying on output. This task only changes the READ side.

## Git push (§37)
Do NOT run `git push`. Commit only.

## Step 0 — integrity + fetch (§0.6a + §42.7.6)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git fetch origin
git status --short
echo "HEAD=$(git rev-parse --short HEAD)  origin/v2=$(git rev-parse --short origin/v2)"
# §0.6a restore truncated M files. SKIP known false-M / binary (hash differs but content==HEAD; never line-count):
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do
  case "$f" in db/data/02_metrics.sql|db/schema.sql|docs/RTMViewShell_SecurityOverview.docx) echo "SKIP false-M/binary: $f"; continue;; esac
  HL=$(git show HEAD:"$f" 2>/dev/null | wc -l); WL=$(wc -l < "$f" 2>/dev/null)
  if [ "$((HL-WL))" -gt 0 ]; then echo "TRUNCATED $f (HEAD=$HL wt=$WL)"; git show HEAD:"$f" > "$f"; echo "RESTORED $f"; else echo "OK $f ($WL)"; fi
done
sync
```

## Multi-session sync (§42) — slug: daytrend-2-0607
Claims: db/functions/02_rtsdata_functions.sql, db/migrations/20260606_008_daytrend_fn_bu_scope.sql,
        src/CcDashboard.Infrastructure/Handlers/DayTrendQueryHandler.cs,
        src/CcDashboard.Application/Queries/Widgets/DayTrendQuery.cs,
        src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
```bash
# S1 barrier (content-based, L-SC-10)
if [ -s ".coord/push/request.md" ] && cat ".coord/push/request.md" >/dev/null 2>&1; then
  echo "PUSH BARRIER ACTIVE"; cat .coord/push/request.md; echo "STOP"; exit 1; fi
# S2 claims
python3 tools/coord_check_claims.py daytrend-2-0607 db/functions/02_rtsdata_functions.sql \
  db/migrations/20260606_008_daytrend_fn_bu_scope.sql \
  src/CcDashboard.Infrastructure/Handlers/DayTrendQueryHandler.cs \
  src/CcDashboard.Application/Queries/Widgets/DayTrendQuery.cs \
  src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
# exit 1 -> STOP (queue). Touch ONLY these files (+ /tmp named /tmp/daytrend-2-0607_*). Edit tool BANNED (§0.3): Python+fsync.
```
- S3 commit.lock: phantom-aware acquire (the /tmp acquire_lock.py from tools/cc_prompt_sync_block.md; retry 5x60s).
- S4+S4b: after EACH commit + §0.6 verify, the LAST step is the Track 2 wrapper:
  `bash tools/cc_post_commit.sh daytrend-2-0607 $(git log -1 --format=%h)`
  (journal + coordinator flush + lock release, exit-gated). Do NOT hand-write journal/flush inline.
- S5: NO git push (§37).

---

# TASK — three coordinated changes (one rtm/db rewrite of the read side)

## Change A — fn_daytrendagentstatus: BU-scoped, status-log-sourced, + UNAVAILABLE
Signature CHANGES: p_queuelist text[] -> p_businessunitid integer (agent scope now comes from BU
membership, not calls). Update BOTH db/functions/02_rtsdata_functions.sql (canonical) AND the deploy
migration (Change D) with this exact body:

```sql
DROP FUNCTION IF EXISTS public.fn_daytrendagentstatus(uuid, character varying, text[], integer);

CREATE OR REPLACE FUNCTION public.fn_daytrendagentstatus(
    p_tenantid uuid, p_ondate character varying, p_businessunitid integer, p_intervalmin integer)
RETURNS TABLE(interval_start timestamp with time zone, metric_id text, value double precision)
LANGUAGE sql STABLE
AS $$
    -- Agents scoped to the BU via persisted membership (NGC_UserAgentgroup, P1/P2),
    -- NOT via calls. Intervals generated from the day's status span (no interaction dependency).
    -- BU agent scope. Membership semantics (operator-confirmed 2026-06-06):
    --   * SG -> AgentGroup = AND: an agent belongs to a Supergroup ONLY IF it is a member of
    --     ALL of that Supergroup's agent groups (intersection).
    --   * BU -> Supergroup = OR: an agent is in the BU if it belongs to ANY of the BU's supergroups.
    WITH bu_supergroups AS (
        SELECT bus."SupergroupId"
        FROM "NGC_BusinessUnitSupergroup" bus
        WHERE bus."BusinessUnitId" = p_businessunitid AND bus."TenantId" = p_tenantid
    ),
    sg_ag_total AS (   -- total agent groups per supergroup (BU's supergroups only)
        SELECT sa."SupergroupId", COUNT(DISTINCT sa."AgentgroupId") AS total_ag
        FROM "NGC_SupergroupAgentgroup" sa
        JOIN bu_supergroups b ON b."SupergroupId" = sa."SupergroupId"
        WHERE sa."TenantId" = p_tenantid
        GROUP BY sa."SupergroupId"
    ),
    supergroup_agents AS (   -- AND: agent must be in ALL of the SG's agent groups
        SELECT ua."UserId", sa."SupergroupId"
        FROM "NGC_SupergroupAgentgroup" sa
        JOIN bu_supergroups b ON b."SupergroupId" = sa."SupergroupId"
        JOIN "NGC_UserAgentgroup" ua
          ON ua."AgentgroupId" = sa."AgentgroupId" AND ua."TenantId" = sa."TenantId"
        WHERE sa."TenantId" = p_tenantid
        GROUP BY ua."UserId", sa."SupergroupId"
        HAVING COUNT(DISTINCT sa."AgentgroupId")
             = (SELECT t.total_ag FROM sg_ag_total t WHERE t."SupergroupId" = sa."SupergroupId")
    ),
    agents_in_bu AS (   -- OR across the BU's supergroups
        SELECT DISTINCT "UserId" FROM supergroup_agents
    ),
    status_rows AS (
        SELECT usl."UserId", usl."StatusGroup", usl."StartTime",
               COALESCE(usl."EndTime", now()) AS end_time
        FROM "RTSData_UserStatusLog" usl
        JOIN agents_in_bu a ON a."UserId" = usl."UserId"
        WHERE usl."TenantId" = p_tenantid
          AND usl."OnDate"   = p_ondate
          AND usl."StatusGroup" IS NOT NULL
          AND usl."StartTime"  IS NOT NULL
    ),
    span AS (
        SELECT date_trunc('hour', MIN("StartTime"))
                 + (FLOOR(EXTRACT(MINUTE FROM MIN("StartTime")) / p_intervalmin)
                    * (p_intervalmin || ' minutes')::interval) AS first_start,
               MAX(end_time) AS last_end
        FROM status_rows
    ),
    intervals AS (
        SELECT gs AS interval_start
        FROM span,
             generate_series(span.first_start, span.last_end,
                             (p_intervalmin || ' minutes')::interval) AS gs
        WHERE span.first_start IS NOT NULL
    ),
    agent_status AS (
        SELECT iv.interval_start, sr."UserId", sr."StatusGroup",
               GREATEST(0, EXTRACT(EPOCH FROM (
                   LEAST(sr.end_time, iv.interval_start + (p_intervalmin || ' minutes')::interval)
                   - GREATEST(sr."StartTime", iv.interval_start)))::bigint * 1000) AS overlap_ms
        FROM intervals iv
        JOIN status_rows sr
          ON sr."StartTime" < iv.interval_start + (p_intervalmin || ' minutes')::interval
         AND sr.end_time   > iv.interval_start
    ),
    pool_summary AS (
        SELECT interval_start, COUNT(DISTINCT "UserId") AS logged_in_agents
        FROM agent_status GROUP BY interval_start
    ),
    status_summary AS (
        SELECT interval_start,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='AVAILABLE')   AS available_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='ONPHONE')     AS onphone_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='BREAK')       AS break_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='PAPERWORK')   AS paperwork_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='TRAINING')    AS training_agents,
            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup"='UNAVAILABLE') AS unavailable_agents,
            COUNT(DISTINCT "UserId")                                            AS total_agents,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='AVAILABLE'),0)   AS available_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='ONPHONE'),0)     AS onphone_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='BREAK'),0)       AS break_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='PAPERWORK'),0)   AS paperwork_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='TRAINING'),0)    AS training_time_ms,
            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup"='UNAVAILABLE'),0) AS unavailable_time_ms,
            COALESCE(SUM(overlap_ms),0)                                           AS total_active_time_ms
        FROM agent_status GROUP BY interval_start
    )
    SELECT ps.interval_start, 'statuslog.logged_in_agents',     ps.logged_in_agents::double precision     FROM pool_summary ps
    UNION ALL SELECT ss.interval_start,'statuslog.available_agents',   ss.available_agents::double precision   FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.onphone_agents',     ss.onphone_agents::double precision     FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.break_agents',       ss.break_agents::double precision       FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.paperwork_agents',   ss.paperwork_agents::double precision   FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.training_agents',    ss.training_agents::double precision    FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.unavailable_agents', ss.unavailable_agents::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.total_agents',       ss.total_agents::double precision       FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.available_time_ms',  ss.available_time_ms::double precision  FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.onphone_time_ms',    ss.onphone_time_ms::double precision    FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.break_time_ms',      ss.break_time_ms::double precision      FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.paperwork_time_ms',  ss.paperwork_time_ms::double precision  FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.training_time_ms',   ss.training_time_ms::double precision   FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.unavailable_time_ms',ss.unavailable_time_ms::double precision FROM status_summary ss
    UNION ALL SELECT ss.interval_start,'statuslog.total_active_time_ms',ss.total_active_time_ms::double precision FROM status_summary ss
    ORDER BY 1, 2;
$$;
```

## Change B — DayTrendQueryHandler.cs: pass BU id instead of queues to the agent fn
The interactions call (fn_daytrendinteractions) keeps p_queues UNCHANGED. ONLY the agent call changes:
replace the p_queues2 array param with an integer p_businessunitid = query.BusinessUnitId, and update
the SQL to `SELECT * FROM fn_daytrendagentstatus(@p_tenant, @p_date, @p_businessunitid, @p_interval)`.
Use NpgsqlDbType.Integer for the BU param. Do not change the interactions query.

## Change C — DayTrendQuery.cs
BusinessUnitId is already on the query record — likely NO change needed. Touch ONLY if a new field is
required; otherwise leave it. (Claimed defensively.)

## Change D — db/migrations/20260606_008_daytrend_fn_bu_scope.sql (NEW, deploy artifact)
Idempotent: the DROP FUNCTION(old sig) + CREATE FUNCTION(new sig) block from Change A verbatim.
Header comment (purpose + 2026-06-06). Deploy needs the table owner (postgres) since it (re)creates a
function — run as postgres (like _004). Migration number _008 (mine; _007 = devops P1 NGC_UserAgentgroup table+SPs; _006 = metrics UNAVAILABLE). fn references the table so it MUST sort after _007.

## Change E — DayTrendWidget.razor: colors for the 2 new metrics
Add to the DefaultColors dictionary (near the other statuslog.* entries):
```csharp
["statuslog.unavailable_agents"]  = "#ef4444",
["statuslog.unavailable_time_ms"] = "#fca5a5",
```

## Verify before commit
```bash
dotnet build src/CcDashboard.Web -c Debug 2>&1 | tail -5
bash tools/pre-commit-check.sh db/functions/02_rtsdata_functions.sql db/migrations/20260606_008_daytrend_fn_bu_scope.sql src/CcDashboard.Infrastructure/Handlers/DayTrendQueryHandler.cs src/CcDashboard.Web/Components/Widgets/DayTrendWidget.razor
grep -c "p_businessunitid" db/functions/02_rtsdata_functions.sql                 # >=1
grep -c "NGC_UserAgentgroup" db/functions/02_rtsdata_functions.sql              # >=1
grep -c "supergroup_agents\|HAVING COUNT" db/functions/02_rtsdata_functions.sql  # >=1 (AND-membership)
grep -c "statuslog.unavailable_agents\|statuslog.unavailable_time_ms" db/functions/02_rtsdata_functions.sql  # 2
grep -c "fn_daytrendagentstatus(@p_tenant, @p_date, @p_businessunitid" src/CcDashboard.Infrastructure/Handlers/DayTrendQueryHandler.cs  # 1
```

## Commit (under commit.lock)
Acquire commit.lock FIRST (S3 phantom-aware). Two commits, prefixes per §39.3:
- `db: fn_daytrendagentstatus BU-scoped via NGC_UserAgentgroup + UNAVAILABLE outputs`  (db/functions + migration)
- `web: DayTrend handler passes BusinessUnitId; UNAVAILABLE colors`                       (handler + query + widget)
After EACH commit: §0.6 post-commit verify + PD-007 re-sync of touched files, then as the LAST step run the
Track 2 wrapper (journal + S4b flush + lock release, exit-gated):
  `bash tools/cc_post_commit.sh daytrend-2-0607 $(git log -1 --format=%h)`
The wrapper RELEASES the lock — re-acquire (S3) before the second commit, run the wrapper again after it.
Do NOT hand-write journal/flush inline.

## Deploy (operator, after P1+P2 live)
Run migration _008 as POSTGRES (function recreate = DDL):
psql -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f db/migrations/20260606_008_daytrend_fn_bu_scope.sql
Then DayTrend Agent Metrics (incl. Unavailable*) populate for the BU's agents, calls or not.

## NOTE on signature change
The handler is the ONLY caller of fn_daytrendagentstatus (verified). Changing p_queuelist->p_businessunitid
is safe. fn_daytrendinteractions keeps p_queuelist — do not touch it.
