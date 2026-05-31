-- ============================================================================
-- Fix RTSData_SetInteraction signature
-- C# DBMng.cs sends 47 parameters in positional order.
-- Old function had wrong signature (27 params, different order).
-- Deploy: psql -U ccdashboard_user -d rtmviewdb -h 127.0.0.1 -f fix_set_interaction.sql
-- ============================================================================

-- Drop old signature variants
DROP FUNCTION IF EXISTS "RTSData_SetInteraction"(
    text, integer, text, text, text, text,
    text, text, text, text, text,
    boolean, boolean, boolean, boolean, boolean,
    integer, integer, timestamptz, timestamptz, timestamptz,
    text, text, boolean, text, boolean, text
);

DROP FUNCTION IF EXISTS "RTSData_SetInteraction"(
    text, integer, text, text, text, text, text, text, text, text,
    boolean, boolean, boolean, boolean, boolean, boolean,
    double precision, double precision,
    timestamp with time zone, timestamp without time zone,
    text, text,
    text, text, text, text, text, text, text, text, text, text,
    text, text, text, text, text, text, text, text, text, text,
    boolean, text, text,
    timestamp with time zone, text
);

DROP FUNCTION IF EXISTS "RTSData_SetInteraction"(
    text, integer, text, text, text, text, text, text, text, text,
    boolean, boolean, boolean, boolean, boolean, boolean,
    double precision, double precision,
    timestamptz, timestamptz,
    text, text,
    text, text, text, text, text, text, text, text, text, text,
    text, text, text, text, text, text, text, text, text, text,
    boolean, text, text,
    timestamp with time zone, text
);

-- Create function matching exact C# parameter order (DBMng.cs lines 376-422)
DROP PROCEDURE IF EXISTS "RTSData_SetUserStatus"(
    text, integer, text, text, text, text, text, text, text, text,
    boolean, boolean, boolean, boolean, boolean, boolean,
    double precision, double precision,
    timestamptz, timestamptz,
    text, text,
    text, text, text, text, text, text, text, text, text, text,
    text, text, text, text, text, text, text, text, text, text,
    boolean, text, text,
    timestamp with time zone, text
);

CREATE OR REPLACE PROCEDURE "RTSData_SetInteraction"(
    p_interaction_id        text,               -- @InteractionId
    p_segment               integer,            -- @Segment
    p_workgroup             text,               -- @Workgroup
    p_classification_code   text,               -- @ClassificationCode
    p_interaction_type      text,               -- @InteractionType
    p_call_type             text,               -- @CallType
    p_direction             text,               -- @Direction
    p_custom_call_data      text,               -- @CustomCallData
    p_remote_address        text,               -- @RemoteAddress
    p_user_id               text,               -- @UserId
    p_is_transferred        boolean,            -- @IsTransferred
    p_is_answered           boolean,            -- @IsAnswered
    p_is_in_queue           boolean,            -- @IsInQueue
    p_is_talk               boolean,            -- @IsTalk
    p_is_abandoned          boolean,            -- @IsAbandoned
    p_is_messaging          boolean,            -- @IsMessaging
    p_time_in_queue         double precision,   -- @TimeInQueue
    p_talk_time             double precision,   -- @TalkTime
    p_in_queue_date_time    timestamp with time zone,       -- @InQueueDateTime
    p_answered_date_time    timestamptz,                    -- @AnsweredDateTime
    p_last_user_id          text,               -- @LastUserId
    p_last_workgroup        text,               -- @LastWorkgroup
    p_custom_call_data1     text,               -- @CustomCallData1
    p_custom_call_data2     text,               -- @CustomCallData2
    p_custom_call_data3     text,               -- @CustomCallData3
    p_custom_call_data4     text,               -- @CustomCallData4
    p_custom_call_data5     text,               -- @CustomCallData5
    p_custom_call_data6     text,               -- @CustomCallData6
    p_custom_call_data7     text,               -- @CustomCallData7
    p_custom_call_data8     text,               -- @CustomCallData8
    p_custom_call_data9     text,               -- @CustomCallData9
    p_custom_call_data10    text,               -- @CustomCallData10
    p_custom_call_data11    text,               -- @CustomCallData11
    p_custom_call_data12    text,               -- @CustomCallData12
    p_custom_call_data13    text,               -- @CustomCallData13
    p_custom_call_data14    text,               -- @CustomCallData14
    p_custom_call_data15    text,               -- @CustomCallData15
    p_custom_call_data16    text,               -- @CustomCallData16
    p_custom_call_data17    text,               -- @CustomCallData17
    p_custom_call_data18    text,               -- @CustomCallData18
    p_custom_call_data19    text,               -- @CustomCallData19
    p_custom_call_data20    text,               -- @CustomCallData20
    p_is_callback_request   boolean,            -- @IsCallbackRequest
    p_time_zone             text,               -- @TimeZone
    p_server_id             text,               -- @ServerId
    p_update_time           timestamp with time zone,       -- @UpdateTime
    p_on_date               text                -- @OnDate
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "RTSData_Interaction" (
        "InteractionId", "Segment", "OnDate", "ServerId", "Workgroup", "UserId",
        "ClassificationCode", "InteractionType", "CallType", "Direction", "CustomCallData",
        "IsTransferred", "IsAnswered", "IsInQueue", "IsTalk", "IsAbandoned",
        "TimeInQueue", "TalkTime",
        "InQueueDateTime", "AnsweredDateTime", "UpdateTime",
        "LastUserId", "LastWorkgroup", "IsMessaging", "RemoteAddress",
        "CustomCallData1",  "CustomCallData2",  "CustomCallData3",  "CustomCallData4",
        "CustomCallData5",  "CustomCallData6",  "CustomCallData7",  "CustomCallData8",
        "CustomCallData9",  "CustomCallData10", "CustomCallData11", "CustomCallData12",
        "CustomCallData13", "CustomCallData14", "CustomCallData15", "CustomCallData16",
        "CustomCallData17", "CustomCallData18", "CustomCallData19", "CustomCallData20",
        "IsCallbackRequest", "TimeZone"
    )
    VALUES (
        p_interaction_id, p_segment, p_on_date, p_server_id, p_workgroup, p_user_id,
        p_classification_code, p_interaction_type, p_call_type, p_direction, p_custom_call_data,
        p_is_transferred, p_is_answered, p_is_in_queue, p_is_talk, p_is_abandoned,
        p_time_in_queue::integer, p_talk_time::integer,
        p_in_queue_date_time, p_answered_date_time, p_update_time,
        p_last_user_id, p_last_workgroup, p_is_messaging, p_remote_address,
        p_custom_call_data1,  p_custom_call_data2,  p_custom_call_data3,  p_custom_call_data4,
        p_custom_call_data5,  p_custom_call_data6,  p_custom_call_data7,  p_custom_call_data8,
        p_custom_call_data9,  p_custom_call_data10, p_custom_call_data11, p_custom_call_data12,
        p_custom_call_data13, p_custom_call_data14, p_custom_call_data15, p_custom_call_data16,
        p_custom_call_data17, p_custom_call_data18, p_custom_call_data19, p_custom_call_data20,
        p_is_callback_request, p_time_zone
    )
    ON CONFLICT ("InteractionId", "Segment", "ServerId")
    DO UPDATE SET
        "OnDate"              = EXCLUDED."OnDate",
        "Workgroup"           = EXCLUDED."Workgroup",
        "UserId"              = EXCLUDED."UserId",
        "ClassificationCode"  = EXCLUDED."ClassificationCode",
        "InteractionType"     = EXCLUDED."InteractionType",
        "CallType"            = EXCLUDED."CallType",
        "Direction"           = EXCLUDED."Direction",
        "CustomCallData"      = EXCLUDED."CustomCallData",
        "IsTransferred"       = EXCLUDED."IsTransferred",
        "IsAnswered"          = EXCLUDED."IsAnswered",
        "IsInQueue"           = EXCLUDED."IsInQueue",
        "IsTalk"              = EXCLUDED."IsTalk",
        "IsAbandoned"         = EXCLUDED."IsAbandoned",
        "TimeInQueue"         = EXCLUDED."TimeInQueue",
        "TalkTime"            = EXCLUDED."TalkTime",
        "InQueueDateTime"     = EXCLUDED."InQueueDateTime",
        "AnsweredDateTime"    = EXCLUDED."AnsweredDateTime",
        "UpdateTime"          = EXCLUDED."UpdateTime",
        "LastUserId"          = EXCLUDED."LastUserId",
        "LastWorkgroup"       = EXCLUDED."LastWorkgroup",
        "IsMessaging"         = EXCLUDED."IsMessaging",
        "RemoteAddress"       = EXCLUDED."RemoteAddress",
        "CustomCallData1"     = EXCLUDED."CustomCallData1",
        "CustomCallData2"     = EXCLUDED."CustomCallData2",
        "CustomCallData3"     = EXCLUDED."CustomCallData3",
        "CustomCallData4"     = EXCLUDED."CustomCallData4",
        "CustomCallData5"     = EXCLUDED."CustomCallData5",
        "CustomCallData6"     = EXCLUDED."CustomCallData6",
        "CustomCallData7"     = EXCLUDED."CustomCallData7",
        "CustomCallData8"     = EXCLUDED."CustomCallData8",
        "CustomCallData9"     = EXCLUDED."CustomCallData9",
        "CustomCallData10"    = EXCLUDED."CustomCallData10",
        "CustomCallData11"    = EXCLUDED."CustomCallData11",
        "CustomCallData12"    = EXCLUDED."CustomCallData12",
        "CustomCallData13"    = EXCLUDED."CustomCallData13",
        "CustomCallData14"    = EXCLUDED."CustomCallData14",
        "CustomCallData15"    = EXCLUDED."CustomCallData15",
        "CustomCallData16"    = EXCLUDED."CustomCallData16",
        "CustomCallData17"    = EXCLUDED."CustomCallData17",
        "CustomCallData18"    = EXCLUDED."CustomCallData18",
        "CustomCallData19"    = EXCLUDED."CustomCallData19",
        "CustomCallData20"    = EXCLUDED."CustomCallData20",
        "IsCallbackRequest"   = EXCLUDED."IsCallbackRequest",
        "TimeZone"            = EXCLUDED."TimeZone";
END;
$$;
