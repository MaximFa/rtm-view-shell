using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CcDashboard.Infrastructure.Migrations.BackendEmulation
{
    /// <inheritdoc />
    public partial class AddDayTrendFunctions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                CREATE OR REPLACE FUNCTION fn_daytrendinteractions(
                    p_tenantid    uuid,
                    p_ondate      varchar(50),
                    p_queuelist   text[],
                    p_intervalmin integer
                )
                RETURNS TABLE (
                    interval_start  timestamptz,
                    metric_id       text,
                    value           double precision
                )
                LANGUAGE sql STABLE
                AS $$
                    WITH base AS (
                        SELECT
                            DATE_TRUNC('hour', "InQueueDateTime") +
                                (FLOOR(EXTRACT(MINUTE FROM "InQueueDateTime") / p_intervalmin)
                                 * (p_intervalmin || ' minutes')::interval)  AS interval_start,
                            "InteractionType",
                            "Direction",
                            "CallType",
                            "IsAnswered",
                            "IsAbandoned",
                            "IsTransferred",
                            "IsCallbackRequest",
                            "IsInQueue",
                            "IsTalk",
                            "TimeInQueue",
                            "TalkTime"
                        FROM "RTSData_Interaction"
                        WHERE "TenantId"  = p_tenantid
                          AND "OnDate"    = p_ondate
                          AND "Workgroup" = ANY(p_queuelist)
                          AND "InQueueDateTime" IS NOT NULL
                    ),
                    agg AS (
                        SELECT
                            interval_start,
                            -- QueueNumIncomingOnlineCalls: Call + External + Incoming
                            COUNT(*) FILTER (WHERE "InteractionType" = 'Call'
                                               AND "CallType"        = 'External'
                                               AND "Direction"       = 'Incoming')                            AS incoming_calls,
                            -- QueueNumAnsweredCalls: Call + External + Incoming + IsAnswered
                            COUNT(*) FILTER (WHERE "InteractionType" = 'Call'
                                               AND "CallType"        = 'External'
                                               AND "Direction"       = 'Incoming'
                                               AND "IsAnswered"      = true)                                  AS answered_calls,
                            -- QueueNumAbandonedCalls: Call + External + Incoming + IsAbandoned + !IsCallbackRequest
                            COUNT(*) FILTER (WHERE "InteractionType"    = 'Call'
                                               AND "CallType"           = 'External'
                                               AND "Direction"          = 'Incoming'
                                               AND "IsAbandoned"        = true
                                               AND "IsCallbackRequest"  = false)                              AS abandoned_calls,
                            -- QueueNumCallbackRequests: IsCallbackRequest + Incoming + External
                            COUNT(*) FILTER (WHERE "IsCallbackRequest" = true
                                               AND "CallType"          = 'External'
                                               AND "Direction"         = 'Incoming')                          AS callback_requests,
                            -- QueueNumCompletedCallbacks: Callback + External + Outgoing + IsAnswered
                            COUNT(*) FILTER (WHERE "InteractionType" = 'Callback'
                                               AND "CallType"        = 'External'
                                               AND "Direction"       = 'Outgoing'
                                               AND "IsAnswered"      = true)                                  AS completed_callbacks,
                            -- QueueNumOutboundCalls: Call + External + Outgoing
                            COUNT(*) FILTER (WHERE "InteractionType" = 'Call'
                                               AND "CallType"        = 'External'
                                               AND "Direction"       = 'Outgoing')                            AS outbound_calls,
                            -- QueueNumTransferredCalls: Call + External + Incoming + IsTransferred
                            COUNT(*) FILTER (WHERE "InteractionType" = 'Call'
                                               AND "CallType"        = 'External'
                                               AND "Direction"       = 'Incoming'
                                               AND "IsTransferred"   = true)                                  AS transferred_calls,
                            -- QueueAvgWaitTimeCalls: Call + External + Incoming + completed (!IsInQueue)
                            AVG("TimeInQueue") FILTER (WHERE "InteractionType" = 'Call'
                                                         AND "CallType"        = 'External'
                                                         AND "Direction"       = 'Incoming'
                                                         AND "IsInQueue"       = false
                                                         AND "IsAnswered"      = true)                        AS avg_wait_time,
                            -- QueueCurMaxWaitTimeCalls: Call + External + Incoming
                            MAX("TimeInQueue") FILTER (WHERE "InteractionType" = 'Call'
                                                         AND "CallType"        = 'External'
                                                         AND "Direction"       = 'Incoming'
                                                         AND "IsAnswered"      = true)                        AS max_wait_time,
                            -- QueueAvgTalkingDurationCalls: Call + External + Incoming + !IsTalk + !IsInQueue
                            AVG("TalkTime")    FILTER (WHERE "InteractionType" = 'Call'
                                                         AND "CallType"        = 'External'
                                                         AND "Direction"       = 'Incoming'
                                                         AND "IsAnswered"      = true
                                                         AND "IsTalk"          = false
                                                         AND "IsInQueue"       = false)                       AS avg_talk_time,
                            -- QueueAvgTimeToAbandCalls: Call + External + Incoming + !IsInQueue + IsAbandoned
                            AVG("TimeInQueue") FILTER (WHERE "InteractionType" = 'Call'
                                                         AND "CallType"        = 'External'
                                                         AND "Direction"       = 'Incoming'
                                                         AND "IsAbandoned"     = true
                                                         AND "IsInQueue"       = false)                       AS avg_abandon_wait
                        FROM base
                        GROUP BY interval_start
                    )
                    SELECT interval_start, 'interaction.incoming_calls',      incoming_calls::double precision      FROM agg
                    UNION ALL
                    SELECT interval_start, 'interaction.answered_calls',      answered_calls::double precision      FROM agg
                    UNION ALL
                    SELECT interval_start, 'interaction.abandoned_calls',     abandoned_calls::double precision     FROM agg
                    UNION ALL
                    SELECT interval_start, 'interaction.callback_requests',   callback_requests::double precision   FROM agg
                    UNION ALL
                    SELECT interval_start, 'interaction.completed_callbacks', completed_callbacks::double precision FROM agg
                    UNION ALL
                    SELECT interval_start, 'interaction.outbound_calls',      outbound_calls::double precision      FROM agg
                    UNION ALL
                    SELECT interval_start, 'interaction.transferred_calls',   transferred_calls::double precision   FROM agg
                    UNION ALL
                    SELECT interval_start, 'interaction.avg_wait_time',       avg_wait_time                         FROM agg
                    UNION ALL
                    SELECT interval_start, 'interaction.max_wait_time',       max_wait_time                         FROM agg
                    UNION ALL
                    SELECT interval_start, 'interaction.avg_talk_time',       avg_talk_time                         FROM agg
                    UNION ALL
                    SELECT interval_start, 'interaction.avg_abandon_wait',    avg_abandon_wait                      FROM agg
                    ORDER BY 1, 2;
                $$;

                CREATE OR REPLACE FUNCTION fn_daytrendagentstatus(
                    p_tenantid    uuid,
                    p_ondate      varchar(50),
                    p_queuelist   text[],
                    p_intervalmin integer
                )
                RETURNS TABLE (
                    interval_start  timestamptz,
                    metric_id       text,
                    value           double precision
                )
                LANGUAGE sql STABLE
                AS $$
                    WITH interval_agents AS (
                        SELECT
                            DATE_TRUNC('hour', "InQueueDateTime") +
                                (FLOOR(EXTRACT(MINUTE FROM "InQueueDateTime") / p_intervalmin)
                                 * (p_intervalmin || ' minutes')::interval) AS interval_start,
                            "UserId"
                        FROM "RTSData_Interaction"
                        WHERE "TenantId"  = p_tenantid
                          AND "OnDate"    = p_ondate
                          AND "Workgroup" = ANY(p_queuelist)
                          AND "IsAnswered" = true
                          AND "Direction"  = 'Incoming'
                          AND "InQueueDateTime" IS NOT NULL
                    ),
                    agent_pool AS (
                        SELECT DISTINCT interval_start, "UserId" FROM interval_agents
                    ),
                    pool_summary AS (
                        SELECT interval_start,
                               COUNT(DISTINCT "UserId") AS logged_in_agents
                        FROM agent_pool
                        GROUP BY interval_start
                    ),
                    agent_status AS (
                        SELECT
                            ap.interval_start,
                            ap.interval_start + (p_intervalmin || ' minutes')::interval AS interval_end,
                            usl."UserId",
                            usl."StatusGroup",
                            GREATEST(0,
                                EXTRACT(EPOCH FROM (
                                    LEAST(
                                        COALESCE(usl."EndTime",
                                                 ap.interval_start + (p_intervalmin || ' minutes')::interval),
                                        ap.interval_start + (p_intervalmin || ' minutes')::interval
                                    )
                                    - GREATEST(usl."StartTime", ap.interval_start)
                                ))::bigint * 1000
                            ) AS overlap_ms
                        FROM agent_pool ap
                        JOIN "RTSData_UserStatusLog" usl ON usl."UserId" = ap."UserId"
                        WHERE usl."TenantId"    = p_tenantid
                          AND usl."OnDate"      = p_ondate
                          AND usl."StatusGroup" IS NOT NULL
                          AND usl."StartTime"   < ap.interval_start
                                                   + (p_intervalmin || ' minutes')::interval
                          AND (usl."EndTime" IS NULL OR usl."EndTime" > ap.interval_start)
                    ),
                    status_summary AS (
                        SELECT
                            interval_start,
                            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'AVAILABLE') AS available_agents,
                            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'ONPHONE')   AS onphone_agents,
                            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'BREAK')     AS break_agents,
                            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'PAPERWORK') AS paperwork_agents,
                            COUNT(DISTINCT "UserId") FILTER (WHERE "StatusGroup" = 'TRAINING')  AS training_agents,
                            COUNT(DISTINCT "UserId")                                             AS total_agents,
                            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'AVAILABLE'),  0) AS available_time_ms,
                            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'ONPHONE'),    0) AS onphone_time_ms,
                            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'BREAK'),      0) AS break_time_ms,
                            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'PAPERWORK'),  0) AS paperwork_time_ms,
                            COALESCE(SUM(overlap_ms) FILTER (WHERE "StatusGroup" = 'TRAINING'),   0) AS training_time_ms,
                            COALESCE(SUM(overlap_ms),                                              0) AS total_active_time_ms
                        FROM agent_status
                        GROUP BY interval_start
                    )
                    SELECT ps.interval_start, 'statuslog.logged_in_agents',    ps.logged_in_agents::double precision    FROM pool_summary ps
                    UNION ALL
                    SELECT ss.interval_start, 'statuslog.available_agents',    ss.available_agents::double precision    FROM status_summary ss
                    UNION ALL
                    SELECT ss.interval_start, 'statuslog.onphone_agents',      ss.onphone_agents::double precision      FROM status_summary ss
                    UNION ALL
                    SELECT ss.interval_start, 'statuslog.break_agents',        ss.break_agents::double precision        FROM status_summary ss
                    UNION ALL
                    SELECT ss.interval_start, 'statuslog.paperwork_agents',    ss.paperwork_agents::double precision    FROM status_summary ss
                    UNION ALL
                    SELECT ss.interval_start, 'statuslog.training_agents',     ss.training_agents::double precision     FROM status_summary ss
                    UNION ALL
                    SELECT ss.interval_start, 'statuslog.total_agents',        ss.total_agents::double precision        FROM status_summary ss
                    UNION ALL
                    SELECT ss.interval_start, 'statuslog.available_time_ms',   ss.available_time_ms::double precision   FROM status_summary ss
                    UNION ALL
                    SELECT ss.interval_start, 'statuslog.onphone_time_ms',     ss.onphone_time_ms::double precision     FROM status_summary ss
                    UNION ALL
                    SELECT ss.interval_start, 'statuslog.break_time_ms',       ss.break_time_ms::double precision       FROM status_summary ss
                    UNION ALL
                    SELECT ss.interval_start, 'statuslog.paperwork_time_ms',   ss.paperwork_time_ms::double precision   FROM status_summary ss
                    UNION ALL
                    SELECT ss.interval_start, 'statuslog.training_time_ms',    ss.training_time_ms::double precision    FROM status_summary ss
                    UNION ALL
                    SELECT ss.interval_start, 'statuslog.total_active_time_ms',ss.total_active_time_ms::double precision FROM status_summary ss
                    ORDER BY 1, 2;
                $$;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("""
                DROP FUNCTION IF EXISTS fn_daytrendinteractions(uuid, varchar, text[], integer);
                DROP FUNCTION IF EXISTS fn_daytrendagentstatus(uuid, varchar, text[], integer);
                """);
        }
    }
}
