-- Apply SERVER-LOCAL interaction load-guard (01dbc2c) for RTSData_GetInteractions arity-2 on 140
-- Supersedes e58cac8 per-row-TZ: 'today' = UpdateTime vs now() both AT TIME ZONE current_setting('TimeZone')
-- (one server-local date for ALL rows; legacy-equivalent server-day). Body-only WHERE. Run as POSTGRES (owner).
-- NOTE: current_setting('TimeZone') = the CALLER SESSION's TimeZone. Confirm RTMService's connection
--       resolves to the intended server day (see verify 2) — if RTM connects in UTC, 'today' = UTC day.

CREATE OR REPLACE FUNCTION "RTSData_GetInteractions"(p_on_date text, p_tenant_id uuid)
RETURNS TABLE(
    "InteractionId" text, "Segment" integer, "Workgroup" text, "ClassificationCode" text,
    "InteractionType" text, "CallType" text, "Direction" text, "CustomCallData" text,
    "RemoteAddress" text, "UserId" text, "IsTransferred" boolean, "IsAnswered" boolean,
    "IsInQueue" boolean, "IsTalk" boolean, "IsAbandoned" boolean, "IsMessaging" boolean,
    "TimeInQueue" integer, "TalkTime" integer, "InQueueDateTime" timestamp without time zone,
    "AnsweredDateTime" timestamp without time zone, "LastUserId" text, "LastWorkgroup" text,
    "CustomCallData1" text, "CustomCallData2" text, "CustomCallData3" text, "CustomCallData4" text,
    "CustomCallData5" text, "CustomCallData6" text, "CustomCallData7" text, "CustomCallData8" text,
    "CustomCallData9" text, "CustomCallData10" text, "CustomCallData11" text, "CustomCallData12" text,
    "CustomCallData13" text, "CustomCallData14" text, "CustomCallData15" text, "CustomCallData16" text,
    "CustomCallData17" text, "CustomCallData18" text, "CustomCallData19" text, "CustomCallData20" text,
    "IsCallbackRequest" boolean, "TimeZone" text, "ServerId" text, "OnDate" text
)
LANGUAGE sql AS $$
    SELECT "InteractionId"::text, "Segment", "Workgroup"::text, "ClassificationCode"::text,
        "InteractionType"::text, "CallType"::text, "Direction"::text, "CustomCallData"::text,
        "RemoteAddress"::text, "UserId"::text, "IsTransferred", "IsAnswered", "IsInQueue",
        "IsTalk", "IsAbandoned", "IsMessaging", "TimeInQueue", "TalkTime",
        ("InQueueDateTime" AT TIME ZONE 'UTC'), ("AnsweredDateTime" AT TIME ZONE 'UTC'),
        "LastUserId"::text, "LastWorkgroup"::text,
        "CustomCallData1"::text, "CustomCallData2"::text, "CustomCallData3"::text, "CustomCallData4"::text,
        "CustomCallData5"::text, "CustomCallData6"::text, "CustomCallData7"::text, "CustomCallData8"::text,
        "CustomCallData9"::text, "CustomCallData10"::text, "CustomCallData11"::text, "CustomCallData12"::text,
        "CustomCallData13"::text, "CustomCallData14"::text, "CustomCallData15"::text, "CustomCallData16"::text,
        "CustomCallData17"::text, "CustomCallData18"::text, "CustomCallData19"::text, "CustomCallData20"::text,
        "IsCallbackRequest", "TimeZone"::text, "ServerId"::text, "OnDate"::text
    FROM "RTSData_Interaction"
    WHERE "TenantId" = p_tenant_id
      AND ("UpdateTime" AT TIME ZONE current_setting('TimeZone'))::date
        = (now()        AT TIME ZONE current_setting('TimeZone'))::date
    ORDER BY "Segment", "UpdateTime" DESC;
$$;

-- VERIFY 1: definition carries the server-local current_setting form (distinguishes 01dbc2c)
SELECT
  pg_get_functiondef('public."RTSData_GetInteractions"(text, uuid)'::regprocedure) LIKE '%current_setting(''TimeZone'')%' AS serverlocal_present,
  pg_get_functiondef('public."RTSData_GetInteractions"(text, uuid)'::regprocedure) LIKE '%::interval))%'                 AS old_interval_present;
-- Expect: serverlocal_present = t , old_interval_present = f

-- VERIFY 2: what server-local date does THIS session resolve to (RTM connection may differ)
SELECT current_setting('TimeZone') AS session_tz, (now() AT TIME ZONE current_setting('TimeZone'))::date AS serverlocal_today;
