-- fix_setchatmessage_server45.sql — signature-agnostic fix for RTSData_SetChatMessage (RTM-SEC-002)
-- The functions/02 DROP used a fixed 14-arg signature that did not match server45's existing FUNCTION,
-- so the DROP no-op'd and the CREATE PROCEDURE failed (name+args clash). This drops ANY SetChatMessage
-- FUNCTION regardless of signature, then creates the PROCEDURE. Idempotent. Run as postgres:
--   psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f fix_setchatmessage_server45.sql
\set ON_ERROR_STOP on

-- 1) Drop any RTSData_SetChatMessage FUNCTION (any signature). Leaves an existing PROCEDURE untouched.
DO $drop$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT oid::regprocedure AS sig
    FROM pg_proc
    WHERE proname = 'RTSData_SetChatMessage' AND prokind = 'f'
  LOOP
    EXECUTE 'DROP FUNCTION ' || r.sig::text;
    RAISE NOTICE 'Dropped function %', r.sig;
  END LOOP;
END
$drop$;

-- 2) Create the PROCEDURE (verbatim from db/functions/02_rtsdata_functions.sql). Guard against re-run.
DROP PROCEDURE IF EXISTS "RTSData_SetChatMessage"(
    text, text, integer, text, text, text,
    text, text, text, text, timestamptz, text, timestamptz, uuid
);

CREATE PROCEDURE "RTSData_SetChatMessage"(
    IN p_message_id text,
    IN p_interaction_id text,
    IN p_segment_id integer,
    IN p_user_id text,
    IN p_msg_direction text,
    IN p_sender text,
    IN p_recipient text,
    IN p_body text,
    IN p_delivery_status text,
    IN p_server_id text,
    IN p_update_time timestamptz,
    IN p_on_date text,
    IN p_time_stamp timestamptz,
    IN p_tenant_id uuid
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "RTSData_ChatMessage" (
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
    )
    ON CONFLICT ("MessageId", "ServerId")
    DO UPDATE SET
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

-- 3) Verify
SELECT proname, prokind FROM pg_proc WHERE proname = 'RTSData_SetChatMessage';
-- expect exactly one row, prokind = 'p'
