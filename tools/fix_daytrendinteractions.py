#!/usr/bin/env python3
"""Fix fn_daytrendinteractions — align filters with RTSGrid_Metric (L-33)."""

import os

# 1. Update the EF Core migration file
migration_path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Infrastructure\Migrations\BackendEmulation\20260526214442_AddDayTrendFunctions.cs"

new_fn_daytrendinteractions = r'''CREATE OR REPLACE FUNCTION fn_daytrendinteractions(
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
                $$;'''

# Old function text to replace (unique enough to match)
old_fn_start = r'''CREATE OR REPLACE FUNCTION fn_daytrendinteractions(
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
                            "InteractionType", "Direction",
                            "IsAnswered", "IsAbandoned", "IsTransferred",
                            "TimeInQueue", "TalkTime"
                        FROM "RTSData_Interaction"
                        WHERE "TenantId"  = p_tenantid
                          AND "OnDate"    = p_ondate
                          AND "Workgroup" = ANY(p_queuelist)
                          AND "InQueueDateTime" IS NOT NULL
                    ),
                    agg AS (
                        SELECT
                            interval_start,
                            COUNT(*) FILTER (WHERE "InteractionType" = 'Call' AND "Direction" = 'Incoming')  AS incoming_calls,
                            COUNT(*) FILTER (WHERE "IsAnswered" = true)                                       AS answered_calls,
                            COUNT(*) FILTER (WHERE "IsAbandoned" = true)                                      AS abandoned_calls,
                            COUNT(*) FILTER (WHERE "InteractionType" = 'Callback' AND "Direction" = 'Incoming') AS callback_requests,
                            COUNT(*) FILTER (WHERE "InteractionType" = 'Callback'
                                               AND "Direction" = 'Outgoing' AND "IsAnswered" = true)         AS completed_callbacks,
                            COUNT(*) FILTER (WHERE "InteractionType" = 'Call' AND "Direction" = 'Outgoing') AS outbound_calls,
                            COUNT(*) FILTER (WHERE "IsTransferred" = true)                                AS transferred_calls,
                            AVG("TimeInQueue") FILTER (WHERE "IsAnswered" = true)                           AS avg_wait_time,
                            MAX("TimeInQueue") FILTER (WHERE "IsAnswered" = true)                           AS max_wait_time,
                            AVG("TalkTime")    FILTER (WHERE "IsAnswered" = true)                           AS avg_talk_time,
                            AVG("TimeInQueue") FILTER (WHERE "IsAbandoned" = true)                          AS avg_abandon_wait
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
                $$;'''

with open(migration_path, "r", encoding="utf-8") as f:
    content = f.read()

if old_fn_start not in content:
    print("ERROR: Old fn_daytrendinteractions not found in migration file!")
    exit(1)

content = content.replace(old_fn_start, new_fn_daytrendinteractions)

with open(migration_path, "w", encoding="utf-8") as f:
    f.write(content)
    f.flush()
    os.fsync(f.fileno())

print(f"Updated: {migration_path}")

# 2. Create the new SQL migration file
sql_migration_path = r"D:\Claude\Projects\RTM View Shell\db\migrations\20260605_002_fix_daytrendinteractions.sql"

sql_migration_content = r'''-- Migration: 20260605_002_fix_daytrendinteractions
-- Aligns fn_daytrendinteractions filters with RTSGrid_Metric definitions (widget-planner L-33).
-- Changes: base CTE adds CallType/IsCallbackRequest/IsInQueue/IsTalk;
--          all 11 metric filters now match exact RTSGrid_Metric MetricParameter expressions.
-- Idempotent: CREATE OR REPLACE.

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

-- Verify: should return rows for today if RTSData_Interaction has data
-- SELECT count(*) FROM fn_daytrendinteractions(
--   '<tenant_id>', to_char(now(), 'DD/MM/YYYY'), ARRAY['Everyone'], 30
-- );
'''

with open(sql_migration_path, "w", encoding="utf-8") as f:
    f.write(sql_migration_content)
    f.flush()
    os.fsync(f.fileno())

print(f"Created: {sql_migration_path}")
print("Done.")
