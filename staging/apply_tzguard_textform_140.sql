-- Apply TZ-guard (text-form) fix for RTSData_GetInteractions on server 140
-- Replaces the 0b07651 ::interval cast (dies 22007 on IANA zone 'Israel') with
-- text-form AT TIME ZONE COALESCE(NULLIF("TimeZone",''),'UTC') — accepts offset
-- strings AND IANA names; empty->UTC. "UpdateTime" is timestamptz (probed 140).
-- Run as: postgres (function owner). Body-only WHERE change; signature/RETURNS/kind unchanged.

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
            ("UpdateTime" AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))::date
          = (now()        AT TIME ZONE COALESCE(NULLIF("TimeZone", ''), 'UTC'))::date
          )
    ORDER BY "Segment", "UpdateTime" DESC;
$$;

-- VERIFY 1: definition carries text-form, no ::interval date-cast
SELECT
  pg_get_functiondef('public."RTSData_GetInteractions"(text, uuid)'::regprocedure) LIKE '%AT TIME ZONE COALESCE(NULLIF(%'  AS textform_present,
  pg_get_functiondef('public."RTSData_GetInteractions"(text, uuid)'::regprocedure) LIKE '%::interval))::date%'             AS interval_cast_still_present;
-- Expect: textform_present = t , interval_cast_still_present = f

-- VERIFY 2: executes with no 22007 and returns today's rows (replace <TENANT> with 140 tenant uuid; p_on_date is ignored by the guard)
-- SELECT count(*) AS today_rows FROM "RTSData_GetInteractions"('', '<TENANT>'::uuid);
