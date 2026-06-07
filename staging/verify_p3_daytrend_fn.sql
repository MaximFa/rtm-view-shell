-- staging/verify_p3_daytrend_fn.sql
-- DEV validation of P3 fn_daytrendagentstatus (BU-scope AND/OR membership + UNAVAILABLE).
-- Self-contained: applies the NEW fn, seeds a test scenario, calls fn, ROLLS BACK (dev untouched).
-- Run on DEV:  psql -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f staging/verify_p3_daytrend_fn.sql
\set ON_ERROR_STOP on
\set tid '00000000-0000-0000-0000-0000000000aa'
BEGIN;

-- 0. apply the NEW fn (DDL is transactional -> rolled back at the end)
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

-- 1. fixtures (test tenant). Scenario:
--    BU 990001 -> SG-A(990001){TST_US, TST_Support}  +  SG-B(990002){TST_Sales}
--    agentAND   : US+Support  -> qualifies SG-A (AND ok)            -> IN BU
--    agentPartial: US only    -> SG-A AND fails                     -> NOT in BU
--    agentB     : Sales       -> qualifies SG-B                     -> IN BU (OR)
--    agentOutside: TST_Other  -> not in any SG of the BU            -> NOT in BU
-- parent rows (FK: NGC_BusinessUnitSupergroup -> NGC_BusinessUnit + NGC_Supergroup; NGC_SupergroupAgentgroup -> NGC_Supergroup)
INSERT INTO "NGC_BusinessUnit"("BusinessUnitId","TenantId","BusinessUnitName","CreatedDatetime") OVERRIDING SYSTEM VALUE VALUES
  (990001, :'tid'::uuid, 'TST_BU', now());
INSERT INTO "NGC_Supergroup"("SupergroupId","TenantId","SupergroupName","CreatedDatetime") OVERRIDING SYSTEM VALUE VALUES
  (990001, :'tid'::uuid, 'TST_SG_A', now()),
  (990002, :'tid'::uuid, 'TST_SG_B', now());
INSERT INTO "NGC_BusinessUnitSupergroup"("BusinessUnitId","SupergroupId","TenantId") VALUES
  (990001, 990001, :'tid'::uuid),
  (990001, 990002, :'tid'::uuid);
INSERT INTO "NGC_SupergroupAgentgroup"("SupergroupId","AgentgroupId","TenantId") VALUES
  (990001,'TST_US',:'tid'::uuid),(990001,'TST_Support',:'tid'::uuid),
  (990002,'TST_Sales',:'tid'::uuid);
INSERT INTO "NGC_UserAgentgroup"("UserId","AgentgroupId","TenantId","CreatedDatetime") VALUES
  ('agentAND','TST_US',:'tid'::uuid,now()),('agentAND','TST_Support',:'tid'::uuid,now()),
  ('agentPartial','TST_US',:'tid'::uuid,now()),
  ('agentB','TST_Sales',:'tid'::uuid,now()),
  ('agentOutside','TST_Other',:'tid'::uuid,now());
INSERT INTO "RTSData_UserStatusLog"
  ("TenantId","UserId","StatusId","ServerId","OnDate","StartTime","EndTime","Duration","UpdateTime","TimeZone","StatusGroup") VALUES
  (:'tid'::uuid,'agentAND','s','srv',to_char(current_date,'DD/MM/YYYY'), now()-interval '90 min', now()-interval '60 min', 1800000, now(),'IST','AVAILABLE'),
  (:'tid'::uuid,'agentAND','s','srv',to_char(current_date,'DD/MM/YYYY'), now()-interval '60 min', now()-interval '30 min', 1800000, now(),'IST','UNAVAILABLE'),
  (:'tid'::uuid,'agentB','s','srv',to_char(current_date,'DD/MM/YYYY'), now()-interval '90 min', now()-interval '30 min', 3600000, now(),'IST','ONPHONE'),
  (:'tid'::uuid,'agentPartial','s','srv',to_char(current_date,'DD/MM/YYYY'), now()-interval '90 min', now()-interval '30 min', 3600000, now(),'IST','AVAILABLE'),
  (:'tid'::uuid,'agentOutside','s','srv',to_char(current_date,'DD/MM/YYYY'), now()-interval '90 min', now()-interval '30 min', 3600000, now(),'IST','BREAK');

-- 2. call fn for BU 990001
\echo ''
\echo '=== fn output for BU 990001 (summed over intervals) ==='
SELECT metric_id, SUM(value) AS total
FROM fn_daytrendagentstatus(:'tid'::uuid, to_char(current_date,'DD/MM/YYYY'), 990001, 30)
GROUP BY metric_id ORDER BY metric_id;

\echo ''
\echo 'EXPECT: only agentAND + agentB scoped in (NOT agentPartial[AND-fail], NOT agentOutside).'
\echo '  statuslog.total_agents max per interval = 2; statuslog.unavailable_agents >= 1 (agentAND UNAVAILABLE);'
\echo '  statuslog.onphone_agents >= 1 (agentB); statuslog.available_agents from agentAND only (NOT agentPartial).'

ROLLBACK;
\echo 'ROLLBACK done — dev untouched (fn + fixtures reverted).'
