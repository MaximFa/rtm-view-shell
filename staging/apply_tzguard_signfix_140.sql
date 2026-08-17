-- Apply TZ sign-fix (e58cac8) for RTSData_GetInteractions arity-2 on server 140
-- CASE: offset strings (^[+-]dd:dd$) -> AT TIME ZONE (tz::interval) [sign-correct]; IANA names/empty -> bare COALESCE(...,'UTC').
-- Supersedes 0329bf0 (bare text-form inverted the sign on offset strings). Body-only WHERE change; run as POSTGRES (owner).

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
            (CASE WHEN "TimeZone" ~ '^[+-][0-9]{2}:[0-9]{2}$'
                  THEN ("UpdateTime" AT TIME ZONE (("TimeZone")::interval))
                  ELSE ("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))
             END)::date
          = (CASE WHEN "TimeZone" ~ '^[+-][0-9]{2}:[0-9]{2}$'
                  THEN (now()        AT TIME ZONE (("TimeZone")::interval))
                  ELSE (now()        AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))
             END)::date
          )
    ORDER BY "Segment", "UpdateTime" DESC;
$$;

-- VERIFY: definition carries the CASE + interval path (distinguishes e58cac8 from 0329bf0)
SELECT
  pg_get_functiondef('public."RTSData_GetInteractions"(text, uuid)'::regprocedure) LIKE '%CASE WHEN%'    AS case_present,
  pg_get_functiondef('public."RTSData_GetInteractions"(text, uuid)'::regprocedure) LIKE '%::interval))%' AS interval_path_present;
-- Expect: case_present = t , interval_path_present = t
