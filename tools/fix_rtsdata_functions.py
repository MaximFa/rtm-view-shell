import os

path = r'RTM\sql\pgsql\02_rtsdata_functions.sql'

with open(path, 'r', encoding='utf-8') as f:
    text = f.read()

# ============================================================================
# 1. RTSData_SetInteraction - add p_tenant_id as LAST param, set TenantId column
# ============================================================================
text = text.replace(
    '''CREATE OR REPLACE FUNCTION "RTSData_SetInteraction"(
    p_interaction_id text,
    p_segment integer,
    p_on_date text,
    p_server_id text,
    p_workgroup text,
    p_user_id text,
    p_classification_code text,
    p_interaction_type text,
    p_call_type text,
    p_direction text,
    p_custom_call_data text,
    p_is_transferred boolean,
    p_is_answered boolean,
    p_is_in_queue boolean,
    p_is_talk boolean,
    p_is_abandoned boolean,
    p_time_in_queue integer,
    p_talk_time integer,
    p_in_queue_date_time timestamptz,
    p_answered_date_time timestamptz,
    p_update_time timestamptz,
    p_last_user_id text,
    p_last_workgroup text,
    p_is_messaging boolean,
    p_remote_address text,
    p_is_callback_request boolean,
    p_time_zone text
)''',
    '''CREATE OR REPLACE FUNCTION "RTSData_SetInteraction"(
    p_interaction_id text,
    p_segment integer,
    p_on_date text,
    p_server_id text,
    p_workgroup text,
    p_user_id text,
    p_classification_code text,
    p_interaction_type text,
    p_call_type text,
    p_direction text,
    p_custom_call_data text,
    p_is_transferred boolean,
    p_is_answered boolean,
    p_is_in_queue boolean,
    p_is_talk boolean,
    p_is_abandoned boolean,
    p_time_in_queue integer,
    p_talk_time integer,
    p_in_queue_date_time timestamptz,
    p_answered_date_time timestamptz,
    p_update_time timestamptz,
    p_last_user_id text,
    p_last_workgroup text,
    p_is_messaging boolean,
    p_remote_address text,
    p_is_callback_request boolean,
    p_time_zone text,
    p_tenant_id uuid
)'''
)

# Add TenantId to INSERT columns and values
text = text.replace(
    '''INSERT INTO "RTSData_Interaction" (
        "InteractionId", "Segment", "OnDate", "ServerId", "Workgroup", "UserId",
        "ClassificationCode", "InteractionType", "CallType", "Direction", "CustomCallData",
        "IsTransferred", "IsAnswered", "IsInQueue", "IsTalk", "IsAbandoned",
        "TimeInQueue", "TalkTime", "InQueueDateTime", "AnsweredDateTime", "UpdateTime",
        "LastUserId", "LastWorkgroup", "IsMessaging", "RemoteAddress", "IsCallbackRequest", "TimeZone"
    )
    VALUES (
        p_interaction_id, p_segment, p_on_date, p_server_id, p_workgroup, p_user_id,
        p_classification_code, p_interaction_type, p_call_type, p_direction, p_custom_call_data,
        p_is_transferred, p_is_answered, p_is_in_queue, p_is_talk, p_is_abandoned,
        p_time_in_queue, p_talk_time, p_in_queue_date_time, p_answered_date_time, p_update_time,
        p_last_user_id, p_last_workgroup, p_is_messaging, p_remote_address, p_is_callback_request, p_time_zone
    )''',
    '''INSERT INTO "RTSData_Interaction" (
        "InteractionId", "Segment", "OnDate", "ServerId", "Workgroup", "UserId",
        "ClassificationCode", "InteractionType", "CallType", "Direction", "CustomCallData",
        "IsTransferred", "IsAnswered", "IsInQueue", "IsTalk", "IsAbandoned",
        "TimeInQueue", "TalkTime", "InQueueDateTime", "AnsweredDateTime", "UpdateTime",
        "LastUserId", "LastWorkgroup", "IsMessaging", "RemoteAddress", "IsCallbackRequest", "TimeZone",
        "TenantId"
    )
    VALUES (
        p_interaction_id, p_segment, p_on_date, p_server_id, p_workgroup, p_user_id,
        p_classification_code, p_interaction_type, p_call_type, p_direction, p_custom_call_data,
        p_is_transferred, p_is_answered, p_is_in_queue, p_is_talk, p_is_abandoned,
        p_time_in_queue, p_talk_time, p_in_queue_date_time, p_answered_date_time, p_update_time,
        p_last_user_id, p_last_workgroup, p_is_messaging, p_remote_address, p_is_callback_request, p_time_zone,
        p_tenant_id
    )'''
)

# Add TenantId to ON CONFLICT UPDATE
text = text.replace(
    '''DO UPDATE SET
        "OnDate" = EXCLUDED."OnDate",
        "Workgroup" = EXCLUDED."Workgroup",
        "UserId" = EXCLUDED."UserId",
        "ClassificationCode" = EXCLUDED."ClassificationCode",
        "InteractionType" = EXCLUDED."InteractionType",
        "CallType" = EXCLUDED."CallType",
        "Direction" = EXCLUDED."Direction",
        "CustomCallData" = EXCLUDED."CustomCallData",
        "IsTransferred" = EXCLUDED."IsTransferred",
        "IsAnswered" = EXCLUDED."IsAnswered",
        "IsInQueue" = EXCLUDED."IsInQueue",
        "IsTalk" = EXCLUDED."IsTalk",
        "IsAbandoned" = EXCLUDED."IsAbandoned",
        "TimeInQueue" = EXCLUDED."TimeInQueue",
        "TalkTime" = EXCLUDED."TalkTime",
        "InQueueDateTime" = EXCLUDED."InQueueDateTime",
        "AnsweredDateTime" = EXCLUDED."AnsweredDateTime",
        "UpdateTime" = EXCLUDED."UpdateTime",
        "LastUserId" = EXCLUDED."LastUserId",
        "LastWorkgroup" = EXCLUDED."LastWorkgroup",
        "IsMessaging" = EXCLUDED."IsMessaging",
        "RemoteAddress" = EXCLUDED."RemoteAddress",
        "IsCallbackRequest" = EXCLUDED."IsCallbackRequest",
        "TimeZone" = EXCLUDED."TimeZone";
END;
$$;

-- ============================================================================
-- 2. RTSData_SetUserStatus''',
    '''DO UPDATE SET
        "OnDate" = EXCLUDED."OnDate",
        "Workgroup" = EXCLUDED."Workgroup",
        "UserId" = EXCLUDED."UserId",
        "ClassificationCode" = EXCLUDED."ClassificationCode",
        "InteractionType" = EXCLUDED."InteractionType",
        "CallType" = EXCLUDED."CallType",
        "Direction" = EXCLUDED."Direction",
        "CustomCallData" = EXCLUDED."CustomCallData",
        "IsTransferred" = EXCLUDED."IsTransferred",
        "IsAnswered" = EXCLUDED."IsAnswered",
        "IsInQueue" = EXCLUDED."IsInQueue",
        "IsTalk" = EXCLUDED."IsTalk",
        "IsAbandoned" = EXCLUDED."IsAbandoned",
        "TimeInQueue" = EXCLUDED."TimeInQueue",
        "TalkTime" = EXCLUDED."TalkTime",
        "InQueueDateTime" = EXCLUDED."InQueueDateTime",
        "AnsweredDateTime" = EXCLUDED."AnsweredDateTime",
        "UpdateTime" = EXCLUDED."UpdateTime",
        "LastUserId" = EXCLUDED."LastUserId",
        "LastWorkgroup" = EXCLUDED."LastWorkgroup",
        "IsMessaging" = EXCLUDED."IsMessaging",
        "RemoteAddress" = EXCLUDED."RemoteAddress",
        "IsCallbackRequest" = EXCLUDED."IsCallbackRequest",
        "TimeZone" = EXCLUDED."TimeZone",
        "TenantId" = EXCLUDED."TenantId";
END;
$$;

-- ============================================================================
-- 2. RTSData_SetUserStatus'''
)

# ============================================================================
# 2. RTSData_SetUserStatus - add p_tenant_id as LAST param
# ============================================================================
text = text.replace(
    '''CREATE OR REPLACE FUNCTION "RTSData_SetUserStatus"(
    p_user_id text,
    p_status_id text,
    p_status_name text,
    p_status_group text,
    p_total_duration integer,
    p_max_duration integer,
    p_total_count integer,
    p_source_server text,
    p_on_date text,
    p_update_time timestamptz,
    p_display_name text,
    p_time_zone text
)''',
    '''CREATE OR REPLACE FUNCTION "RTSData_SetUserStatus"(
    p_user_id text,
    p_status_id text,
    p_status_name text,
    p_status_group text,
    p_total_duration integer,
    p_max_duration integer,
    p_total_count integer,
    p_source_server text,
    p_on_date text,
    p_update_time timestamptz,
    p_display_name text,
    p_time_zone text,
    p_tenant_id uuid
)'''
)

# Add TenantId to INSERT
text = text.replace(
    '''INSERT INTO "RTSData_UserStatus" (
        "UserId", "StatusId", "ServerId", "OnDate",
        "StatusName", "StatusGroup", "TotalDuration", "MaxDuraction",
        "TotalCount", "UpdateTime", "DisplayName", "TimeZone"
    )
    VALUES (
        p_user_id, p_status_id, p_source_server, p_on_date,
        p_status_name, p_status_group, p_total_duration, p_max_duration,
        p_total_count, p_update_time, p_display_name, p_time_zone
    )''',
    '''INSERT INTO "RTSData_UserStatus" (
        "UserId", "StatusId", "ServerId", "OnDate",
        "StatusName", "StatusGroup", "TotalDuration", "MaxDuraction",
        "TotalCount", "UpdateTime", "DisplayName", "TimeZone", "TenantId"
    )
    VALUES (
        p_user_id, p_status_id, p_source_server, p_on_date,
        p_status_name, p_status_group, p_total_duration, p_max_duration,
        p_total_count, p_update_time, p_display_name, p_time_zone, p_tenant_id
    )'''
)

# Add TenantId to ON CONFLICT UPDATE
text = text.replace(
    '''DO UPDATE SET
        "StatusName" = EXCLUDED."StatusName",
        "StatusGroup" = EXCLUDED."StatusGroup",
        "TotalDuration" = EXCLUDED."TotalDuration",
        "MaxDuraction" = EXCLUDED."MaxDuraction",
        "TotalCount" = EXCLUDED."TotalCount",
        "UpdateTime" = EXCLUDED."UpdateTime",
        "DisplayName" = EXCLUDED."DisplayName",
        "TimeZone" = EXCLUDED."TimeZone";
END;
$$;

-- ============================================================================
-- 3. RTSData_SetChatMessage''',
    '''DO UPDATE SET
        "StatusName" = EXCLUDED."StatusName",
        "StatusGroup" = EXCLUDED."StatusGroup",
        "TotalDuration" = EXCLUDED."TotalDuration",
        "MaxDuraction" = EXCLUDED."MaxDuraction",
        "TotalCount" = EXCLUDED."TotalCount",
        "UpdateTime" = EXCLUDED."UpdateTime",
        "DisplayName" = EXCLUDED."DisplayName",
        "TimeZone" = EXCLUDED."TimeZone",
        "TenantId" = EXCLUDED."TenantId";
END;
$$;

-- ============================================================================
-- 3. RTSData_SetChatMessage'''
)

# ============================================================================
# 3. RTSData_SetChatMessage - add p_tenant_id as LAST param
# ============================================================================
text = text.replace(
    '''CREATE OR REPLACE FUNCTION "RTSData_SetChatMessage"(
    p_message_id text,
    p_interaction_id text,
    p_segment_id integer,
    p_user_id text,
    p_msg_direction text,
    p_sender text,
    p_recipient text,
    p_body text,
    p_delivery_status text,
    p_server_id text,
    p_update_time timestamptz,
    p_on_date text,
    p_time_stamp timestamptz
)''',
    '''CREATE OR REPLACE FUNCTION "RTSData_SetChatMessage"(
    p_message_id text,
    p_interaction_id text,
    p_segment_id integer,
    p_user_id text,
    p_msg_direction text,
    p_sender text,
    p_recipient text,
    p_body text,
    p_delivery_status text,
    p_server_id text,
    p_update_time timestamptz,
    p_on_date text,
    p_time_stamp timestamptz,
    p_tenant_id uuid
)'''
)

# Add TenantId to INSERT
text = text.replace(
    '''INSERT INTO "RTSData_ChatMessage" (
        "MessageId", "ServerId", "OnDate",
        "InteractionId", "SegmentId", "UserId", "MsgDirection",
        "Sender", "Recipient", "Body", "DeliveryStatus",
        "UpdateTime", "TimeStamp"
    )
    VALUES (
        p_message_id, p_server_id, p_on_date,
        p_interaction_id, p_segment_id, p_user_id, p_msg_direction,
        p_sender, p_recipient, p_body, p_delivery_status,
        p_update_time, p_time_stamp
    )''',
    '''INSERT INTO "RTSData_ChatMessage" (
        "MessageId", "ServerId", "OnDate",
        "InteractionId", "SegmentId", "UserId", "MsgDirection",
        "Sender", "Recipient", "Body", "DeliveryStatus",
        "UpdateTime", "TimeStamp", "TenantId"
    )
    VALUES (
        p_message_id, p_server_id, p_on_date,
        p_interaction_id, p_segment_id, p_user_id, p_msg_direction,
        p_sender, p_recipient, p_body, p_delivery_status,
        p_update_time, p_time_stamp, p_tenant_id
    )'''
)

# Add TenantId to ON CONFLICT UPDATE
text = text.replace(
    '''DO UPDATE SET
        "OnDate" = EXCLUDED."OnDate",
        "InteractionId" = EXCLUDED."InteractionId",
        "SegmentId" = EXCLUDED."SegmentId",
        "UserId" = EXCLUDED."UserId",
        "MsgDirection" = EXCLUDED."MsgDirection",
        "Sender" = EXCLUDED."Sender",
        "Recipient" = EXCLUDED."Recipient",
        "Body" = EXCLUDED."Body",
        "DeliveryStatus" = EXCLUDED."DeliveryStatus",
        "UpdateTime" = EXCLUDED."UpdateTime",
        "TimeStamp" = EXCLUDED."TimeStamp";
END;
$$;

-- ============================================================================
-- 4. RTSData_MidnightClear''',
    '''DO UPDATE SET
        "OnDate" = EXCLUDED."OnDate",
        "InteractionId" = EXCLUDED."InteractionId",
        "SegmentId" = EXCLUDED."SegmentId",
        "UserId" = EXCLUDED."UserId",
        "MsgDirection" = EXCLUDED."MsgDirection",
        "Sender" = EXCLUDED."Sender",
        "Recipient" = EXCLUDED."Recipient",
        "Body" = EXCLUDED."Body",
        "DeliveryStatus" = EXCLUDED."DeliveryStatus",
        "UpdateTime" = EXCLUDED."UpdateTime",
        "TimeStamp" = EXCLUDED."TimeStamp",
        "TenantId" = EXCLUDED."TenantId";
END;
$$;

-- ============================================================================
-- 4. RTSData_MidnightClear'''
)

# ============================================================================
# 4. RTSData_MidnightClear - CRITICAL: add p_tenant_id and scope DELETE
# ============================================================================
text = text.replace(
    '''DROP FUNCTION IF EXISTS "RTSData_MidnightClear"();

CREATE OR REPLACE FUNCTION "RTSData_MidnightClear"()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "RTSData_Interaction";
    DELETE FROM "RTSData_UserStatus";
    -- RTSData_ChatMessage is intentionally NOT cleared per production behavior
END;
$$;''',
    '''DROP FUNCTION IF EXISTS "RTSData_MidnightClear"();
DROP FUNCTION IF EXISTS "RTSData_MidnightClear"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_MidnightClear"(p_tenant_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    -- [RTM-SEC-001] CRITICAL: Must scope DELETE by TenantId to prevent cross-tenant data loss
    DELETE FROM "RTSData_Interaction" WHERE "TenantId" = p_tenant_id;
    DELETE FROM "RTSData_UserStatus" WHERE "TenantId" = p_tenant_id;
    -- RTSData_ChatMessage is intentionally NOT cleared per production behavior
END;
$$;'''
)

# ============================================================================
# 5. RTSData_GetInteractions - add p_tenant_id parameter and WHERE filter
# ============================================================================
text = text.replace(
    '''DROP FUNCTION IF EXISTS "RTSData_GetInteractions"();

CREATE OR REPLACE FUNCTION "RTSData_GetInteractions"()''',
    '''DROP FUNCTION IF EXISTS "RTSData_GetInteractions"();
DROP FUNCTION IF EXISTS "RTSData_GetInteractions"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_GetInteractions"(p_tenant_id uuid)'''
)
text = text.replace(
    '''FROM "RTSData_Interaction" i;
END;
$$;

-- Lowercase alias (C# calls "RTSData_getInteractions")
DROP FUNCTION IF EXISTS "RTSData_getInteractions"();''',
    '''FROM "RTSData_Interaction" i
    WHERE i."TenantId" = p_tenant_id;
END;
$$;

-- Lowercase alias (C# calls "RTSData_getInteractions")
DROP FUNCTION IF EXISTS "RTSData_getInteractions"();
DROP FUNCTION IF EXISTS "RTSData_getInteractions"(uuid);'''
)

# Fix the lowercase alias
text = text.replace(
    '''CREATE OR REPLACE FUNCTION "RTSData_getInteractions"()
RETURNS TABLE(
    "TenantId" uuid,
    "InteractionId" text,
    "Segment" integer,
    "OnDate" text,
    "ServerId" text,
    "Workgroup" text,
    "UserId" text,
    "ClassificationCode" text,
    "InteractionType" text,
    "CallType" text,
    "Direction" text,
    "CustomCallData" text,
    "IsTransferred" boolean,
    "IsAnswered" boolean,
    "IsInQueue" boolean,
    "IsTalk" boolean,
    "IsAbandoned" boolean,
    "TimeInQueue" integer,
    "TalkTime" integer,
    "InQueueDateTime" timestamptz,
    "AnsweredDateTime" timestamptz,
    "UpdateTime" timestamptz,
    "LastUserId" text,
    "LastWorkgroup" text,
    "IsMessaging" boolean,
    "RemoteAddress" text,
    "IsCallbackRequest" boolean,
    "TimeZone" text
)
LANGUAGE sql
AS $$ SELECT * FROM "RTSData_GetInteractions"(); $$;''',
    '''CREATE OR REPLACE FUNCTION "RTSData_getInteractions"(p_tenant_id uuid)
RETURNS TABLE(
    "TenantId" uuid,
    "InteractionId" text,
    "Segment" integer,
    "OnDate" text,
    "ServerId" text,
    "Workgroup" text,
    "UserId" text,
    "ClassificationCode" text,
    "InteractionType" text,
    "CallType" text,
    "Direction" text,
    "CustomCallData" text,
    "IsTransferred" boolean,
    "IsAnswered" boolean,
    "IsInQueue" boolean,
    "IsTalk" boolean,
    "IsAbandoned" boolean,
    "TimeInQueue" integer,
    "TalkTime" integer,
    "InQueueDateTime" timestamptz,
    "AnsweredDateTime" timestamptz,
    "UpdateTime" timestamptz,
    "LastUserId" text,
    "LastWorkgroup" text,
    "IsMessaging" boolean,
    "RemoteAddress" text,
    "IsCallbackRequest" boolean,
    "TimeZone" text
)
LANGUAGE sql
AS $$ SELECT * FROM "RTSData_GetInteractions"(p_tenant_id); $$;'''
)

# ============================================================================
# 6. RTSData_GetUsersStatuses - add p_tenant_id parameter and WHERE filter
# ============================================================================
text = text.replace(
    '''DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"();

CREATE OR REPLACE FUNCTION "RTSData_GetUsersStatuses"()''',
    '''DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"();
DROP FUNCTION IF EXISTS "RTSData_GetUsersStatuses"(uuid);

CREATE OR REPLACE FUNCTION "RTSData_GetUsersStatuses"(p_tenant_id uuid)'''
)
text = text.replace(
    '''FROM "RTSData_UserStatus" s;
END;
$$;

-- Lowercase alias (C# calls "RTSData_getUsersStatuses")
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"();''',
    '''FROM "RTSData_UserStatus" s
    WHERE s."TenantId" = p_tenant_id;
END;
$$;

-- Lowercase alias (C# calls "RTSData_getUsersStatuses")
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"();
DROP FUNCTION IF EXISTS "RTSData_getUsersStatuses"(uuid);'''
)

# Fix the lowercase alias
text = text.replace(
    '''CREATE OR REPLACE FUNCTION "RTSData_getUsersStatuses"()
RETURNS TABLE(
    "TenantId" uuid,
    "UserId" text,
    "StatusId" text,
    "ServerId" text,
    "OnDate" text,
    "StatusName" text,
    "StatusGroup" text,
    "TotalDuration" integer,
    "MaxDuraction" integer,
    "TotalCount" integer,
    "UpdateTime" timestamptz,
    "DisplayName" text,
    "TimeZone" text
)
LANGUAGE sql
AS $$ SELECT * FROM "RTSData_GetUsersStatuses"(); $$;''',
    '''CREATE OR REPLACE FUNCTION "RTSData_getUsersStatuses"(p_tenant_id uuid)
RETURNS TABLE(
    "TenantId" uuid,
    "UserId" text,
    "StatusId" text,
    "ServerId" text,
    "OnDate" text,
    "StatusName" text,
    "StatusGroup" text,
    "TotalDuration" integer,
    "MaxDuraction" integer,
    "TotalCount" integer,
    "UpdateTime" timestamptz,
    "DisplayName" text,
    "TimeZone" text
)
LANGUAGE sql
AS $$ SELECT * FROM "RTSData_GetUsersStatuses"(p_tenant_id); $$;'''
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

count = text.count('p_tenant_id')
print(f'Updated 02_rtsdata_functions.sql - {count} p_tenant_id references')
