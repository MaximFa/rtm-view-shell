-- One-time apply: RTSData_GetInteractions TZ-guard (arity-2) to 140. Run as POSTGRES (function owner).
-- Source: db/functions/02_rtsdata_functions.sql @0b07651. CREATE OR REPLACE, body-only (signature/RETURNS/kind UNCHANGED) -> safe standalone, NO Shell redeploy. Pair with devops RTMService bounce.
-- WHERE now filters UpdateTime local-date=today (per-row TimeZone offset) so restart ignores stale accumulated interactions.

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
      AND (
            ("UpdateTime" AT TIME ZONE (COALESCE(NULLIF("TimeZone", ''), '+00:00')::interval))::date
          = (now()        AT TIME ZONE (COALESCE(NULLIF("TimeZone", ''), '+00:00')::interval))::date
          )
    ORDER BY "Segment", "UpdateTime" DESC;
$$;

-- VERIFY (expect tz_guard_present = t):
SELECT pg_get_functiondef('public."RTSData_GetInteractions"(text, uuid)'::regprocedure) LIKE '%UpdateTime%AT TIME ZONE%' AS tz_guard_present;
