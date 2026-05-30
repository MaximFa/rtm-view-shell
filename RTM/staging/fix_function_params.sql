-- Fix: Add @OnDate parameter to RTSData_getInteractions and RTSData_getUsersStatuses
-- C# passes text parameter: date string format "dd/MM/yyyy"
-- Original SQL Server procs: @OnDate nvarchar(50) with WHERE OnDate = @OnDate

-- ============================================================
-- 1. RTSData_GetInteractions / RTSData_getInteractions
-- ============================================================
DROP FUNCTION IF EXISTS "RTSData_GetInteractions"(text);
DROP FUNCTION IF EXISTS "RTSData_GetInteractions"();
DROP FUNCTION IF EXISTS "RTSData_getInteractions"(text);
DROP FUNCTION IF EXISTS "RTSData_getInteractions"();

CREATE OR REPLACE FUNCTION "RTSData_GetInteractions"(p_on_date text)
RETURNS TABLE (
    "InteractionId"      text,
    "Segment"            int,
    "Workgroup"          text,
    "ClassificationCode" text,
    "InteractionType"    text,
    "CallType"           text,
    "Direction"          text,
    "CustomCallData"     text,
    "RemoteAddress"      text,
    "UserId"             text,
    "IsTransferred"      boolean,
    "IsAnswered"         boolean,
    "IsInQueue"          boolean,
    "IsTalk"             boolean,
    "IsAbandoned"        boolean,
    "IsMessaging"        boolean,
    "TimeInQueue"        int,
    "TalkTime"           int,
    "InQueueDateTime"    timestamp,
    "AnsweredDateTime"   timestamp,
    "UpdateTime"         timestamp,
    "LastUserId"         text,
    "LastWorkgroup"      text,
    "CustomCallData1"    text,
    "CustomCallData2"    text,
    "CustomCallData3"    text,
    "CustomCallData4"    text,
    "CustomCallData5"    text,
    "CustomCallData6"    text,
    "CustomCallData7"    text,
    "CustomCallData8"    text,
    "CustomCallData9"    text,
    "CustomCallData10"   text,
    "CustomCallData11"   text,
    "CustomCallData12"   text,
    "CustomCallData13"   text,
    "CustomCallData14"   text,
    "CustomCallData15"   text,
    "CustomCallData16"   text,
    "CustomCallData17"   text,
    "CustomCallData18"   text,
    "CustomCallData19"   text,
    "CustomCallData20"   text,
    "IsCallbackRequest"  boolean,
    "TimeZone"           text,
    "ServerId"           text,
    "OnDate"             text
)
LANGUAGE sql AS $$
    SELECT
        "InteractionId"::text, "Segment", "Workgroup"::text,
        "ClassificationCode"::text, "InteractionType"::text,
        "CallType"::text, "Direction"::text, "CustomCallData"::text,
        "RemoteAddress"::text, "UserId"::text,
        "IsTransferred", "IsAnswered", "IsInQueue", "IsTalk", "IsAbandoned",
        "IsMessaging", "TimeInQueue", "TalkTime",
        "InQueueDateTime", "AnsweredDateTime", "UpdateTime",
        "LastUserId"::text, "LastWorkgroup"::text,
        "CustomCallData1"::text, "CustomCallData2"::text,
        "CustomCallData3"::text, "CustomCallData4"::text,
        "CustomCallData5"::text, "CustomCallData6"::text,
        "CustomCallData7"::text, "CustomCallData8"::text,
        "CustomCallData9"::text, "CustomCallData10"::text,
        "CustomCallData11"::text, "CustomCallData12"::text,
        "CustomCallData13"::text, "CustomCallData14"::text,
        "CustomCallData15"::text, "CustomCallData16"::text,
        "CustomCallData17"::text, "CustomCallData18"::text,
        "CustomCallData19"::text, "CustomCallData20"::text,
        "IsCallbackRequest", "TimeZone"::text,
        "ServerId"::text, "OnDate"::text
    FROM "RTSData_Interaction"
    WHERE "OnDate" = p_on_date
    ORDER BY "Segment", "UpdateTime" DESC;
$$;

CREATE OR REPLACE FUNCTION "RTSData_getInteractions"(p_on_date text)
RETURNS TABLE (
    "InteractionId" text, "Segment" int, "Workgroup" text,
    "ClassificationCode" text, "InteractionType" text, "CallType" text,
    "Direction" text, "CustomCallData" text, "RemoteAddress" text,
    "UserId" text, "IsTransferred" boolean, "IsAnswered" boolean,
    "IsInQueue" boolean, "IsTalk" boolean, "IsAbandoned" boolean,
    "IsMessaging" boolean, "TimeInQueue" int, "TalkTime" int,
    "InQueueDateTime" timestamp, "AnsweredDateTime" timestamp,
    "UpdateTime" timestamp, "LastUserId" text, "LastWorkgroup" text,
    "CustomCallData1" text, "CustomCallData2" text, "CustomCallData3" text,
    "CustomCallData4" text, "CustomCallData5" text, "CustomCallData6" text,
    "CustomCallData7" text, "CustomCallData8" text, "CustomCallData9" text,
    "CustomCallData10" text, "CustomCallData11" text, "CustomCallData12" text,
    "CustomCallData13" text, "CustomCallData14" text, "CustomCallData15" text,
    "CustomCallData16" text, "CustomCallData17" text, "CustomCallData18" text,
    "CustomCallData19" text, "CustomCallData20" text,
    "IsCallbackRequest" boolean, "TimeZone" text, "ServerId" text, "OnDate" text
)
LANGUAGE sql AS $$
    SELECT * FROM "RTSData_GetInteractions"(p_on_date);
$$;

-- ============================================================
-- 2. RTSData_GetUsersStatuses / RTSData_getUsersStatuses
-- ============================================================
DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"(text);
DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"();
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"(text);
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"();

CREATE OR REPLACE FUNCTION "RTSData_GetUsersStatuses"(p_on_date text)
RETURNS TABLE (
    "UserId"        text,
    "StatusId"      text,
    "StatusName"    text,
    "StatusGroup"   text,
    "TotalDuration" int,
    "MaxDuraction"  int,
    "TotalCount"    int,
    "DisplayName"   text,
    "TimeZone"      text,
    "UpdateTime"    timestamp,
    "ServerId"      text
)
LANGUAGE sql AS $$
    SELECT
        "UserId"::text, "StatusId"::text, "StatusName"::text,
        "StatusGroup"::text, "TotalDuration", "MaxDuraction",
        "TotalCount", "DisplayName"::text, "TimeZone"::text,
        "UpdateTime", "ServerId"::text
    FROM "RTSData_UserStatus"
    WHERE "OnDate" = p_on_date
    ORDER BY "UpdateTime" DESC;
$$;

CREATE OR REPLACE FUNCTION "RTSData_getUsersStatuses"(p_on_date text)
RETURNS TABLE (
    "UserId" text, "StatusId" text, "StatusName" text,
    "StatusGroup" text, "TotalDuration" int, "MaxDuraction" int,
    "TotalCount" int, "DisplayName" text, "TimeZone" text,
    "UpdateTime" timestamp, "ServerId" text
)
LANGUAGE sql AS $$
    SELECT * FROM "RTSData_GetUsersStatuses"(p_on_date);
$$;

-- Verify: should show 4 rows, pronargs=1 for all
SELECT proname, pronargs,
       pg_get_function_arguments(oid) AS args
FROM pg_proc
WHERE proname IN ('RTSData_GetInteractions','RTSData_getInteractions',
                  'RTSData_GetUsersStatuses','RTSData_getUsersStatuses')
ORDER BY proname;
