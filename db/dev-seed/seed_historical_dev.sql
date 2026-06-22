-- ============================================================================
-- DEV SEED: Historical Reports Test Data (Q1/Q5/A4/A5 tabs) — DATA-ONLY
-- ============================================================================
-- Owner: role-bi (bi-0619). DEV ONLY — DO NOT RUN ON PROD.
-- §4-PASS: coordinator-0622 approved. dba-REVIEWED before run.
-- Idempotent: ON CONFLICT DO UPDATE. Reusable.
--
-- CORE RULE (2026-06-22 lesson): This seed is DATA-ONLY (INSERT).
-- Schema + functions come from EF migrations ONLY — NEVER CREATE TABLE/FUNCTION here.
-- That desyncs __ef_migrations_history and omits migration functions -> startup 42883.
-- Always: migrate-first, seed data-only.
--
-- PREREQUISITE: Run EF migrations FIRST (dotnet ef database update), which creates:
--   - fn_hist_ensure_partitions, fn_hist_drop_aged
--   - hist_queue_intervals, hist_agent_intervals (partitioned)
--   - arch_* tables, user_reports, etc.
--
-- USAGE:
--   psql -U ccdashboard_user -d rtmviewdb -v DEV_CONFIRM=1 -f seed_historical_dev.sql
--
-- GUARD: refuses unless DB name == 'rtmviewdb' AND DEV_CONFIRM=1 passed.
-- ============================================================================

-- DEV-ONLY GUARD: refuse prod
\if :{?DEV_CONFIRM}
\else
\echo 'GUARD FAIL: pass -v DEV_CONFIRM=1 to confirm dev-only run'
\quit
\endif

DO $$
BEGIN
    IF current_database() NOT IN ('rtmviewdb', 'rtmviewdb_test', 'rtmviewdb_dev') THEN
        RAISE EXCEPTION 'GUARD FAIL: this script runs ONLY on dev DBs, not on %', current_database();
    END IF;
    RAISE NOTICE 'DEV GUARD PASS: database=%', current_database();
END $$;

-- ============================================================================
-- PREREQUISITE CHECK: Verify EF migrations were applied (tables + functions exist)
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hist_queue_intervals') THEN
        RAISE EXCEPTION 'PREREQUISITE FAIL: hist_queue_intervals does not exist. Run EF migrations first: dotnet ef database update';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hist_agent_intervals') THEN
        RAISE EXCEPTION 'PREREQUISITE FAIL: hist_agent_intervals does not exist. Run EF migrations first.';
    END IF;
    IF to_regprocedure('fn_hist_ensure_partitions(text,int,int)') IS NULL THEN
        RAISE EXCEPTION 'PREREQUISITE FAIL: fn_hist_ensure_partitions does not exist. Run EF migrations first.';
    END IF;
    RAISE NOTICE 'PREREQUISITE PASS: hist_* tables + fn_hist_ensure_partitions exist (EF migrations applied)';
END $$;

-- Ensure partitions exist for the data range (function exists from EF migration)
SELECT fn_hist_ensure_partitions('hist_queue_intervals', 1, 2);
SELECT fn_hist_ensure_partitions('hist_agent_intervals', 1, 2);

-- ============================================================================
-- MAIN SEED BLOCK
-- ============================================================================
DO $$
DECLARE
    v_tenant_id uuid;
    v_sl_threshold int := 20;
    v_day date;
    v_bucket timestamptz;
    v_bucket_end timestamptz;
    v_queue text;
    v_agent text;
    v_interaction_id text;
    v_in_queue_dt timestamptz;
    v_answered_dt timestamptz;
    v_time_in_queue int;
    v_talk_time int;
    v_is_answered boolean;
    v_is_abandoned boolean;
    v_call_count int;
    v_answered_count int;
    v_queues text[] := ARRAY['SALES', 'SUPPORT', 'BILLING'];
    v_agents text[] := ARRAY['agent101', 'agent102', 'agent103', 'agent104', 'agent105'];
    v_hour int;
    v_minute int;
    v_segment int := 1;
    v_server_id text := 'DEV_SERVER';
    v_log_id int := 100000;
    v_status_duration int;
    v_current_time timestamptz;
    v_has_answered_calls boolean;
    v_answered_times timestamptz[];
    v_answered_time timestamptz;
BEGIN
    -- Get tenant
    SELECT "Id" INTO v_tenant_id FROM tenants WHERE "Slug" = 'platform' LIMIT 1;
    IF v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'Platform tenant not found';
    END IF;
    RAISE NOTICE 'Using tenant: %', v_tenant_id;

    -- Set SL threshold
    UPDATE tenant_settings SET "SlThresholdSeconds" = v_sl_threshold WHERE "TenantId" = v_tenant_id;

    -- Create queues (NGC_Queues)
    INSERT INTO "NGC_Queues" ("Id", "TenantId", "ExternalId", "Name", "IsActive")
    VALUES
        (gen_random_uuid(), v_tenant_id, 'SALES', 'Sales', true),
        (gen_random_uuid(), v_tenant_id, 'SUPPORT', 'Support', true),
        (gen_random_uuid(), v_tenant_id, 'BILLING', 'Billing', true)
    ON CONFLICT ("ExternalId", "TenantId") DO UPDATE SET "Name" = EXCLUDED."Name", "IsActive" = true;
    RAISE NOTICE 'Queues created/updated: SALES, SUPPORT, BILLING';

    -- ========================================================================
    -- STEP 3: Generate RTSData_Interaction records (last 7 days)
    -- ========================================================================
    RAISE NOTICE 'Generating RTSData_Interaction records...';

    FOR v_day IN SELECT generate_series(CURRENT_DATE - 6, CURRENT_DATE, '1 day'::interval)::date LOOP
        FOR v_hour IN 9..17 LOOP
            FOR v_minute IN SELECT unnest(ARRAY[0, 30]) LOOP
                IF v_hour = 17 AND v_minute = 30 THEN CONTINUE; END IF;

                v_bucket := (v_day || ' ' || v_hour || ':' || v_minute || ':00')::timestamptz;

                FOREACH v_queue IN ARRAY v_queues LOOP
                    v_call_count := 5 + floor(random() * 26)::int;
                    v_answered_count := floor(v_call_count * (0.85 + random() * 0.10))::int;

                    FOR i IN 1..v_call_count LOOP
                        v_interaction_id := 'DEV_' || v_queue || '_' || to_char(v_bucket, 'YYYYMMDD_HH24MI') || '_' || i;
                        v_in_queue_dt := v_bucket + (floor(random() * 29) || ' minutes')::interval
                                        + (floor(random() * 60) || ' seconds')::interval;

                        IF i <= v_answered_count THEN
                            v_is_answered := true;
                            v_is_abandoned := false;
                            IF random() < 0.6 THEN
                                v_time_in_queue := 1 + floor(random() * 20)::int;
                            ELSE
                                v_time_in_queue := 21 + floor(random() * 60)::int;
                            END IF;
                            v_answered_dt := v_in_queue_dt + (v_time_in_queue || ' seconds')::interval;
                            v_talk_time := 120 + floor(random() * 281)::int;
                            v_agent := v_agents[1 + floor(random() * 5)::int];
                        ELSE
                            v_is_answered := false;
                            v_is_abandoned := true;
                            v_time_in_queue := 30 + floor(random() * 120)::int;
                            v_answered_dt := '1753-01-01 00:00:00'::timestamptz;
                            v_talk_time := 0;
                            v_agent := '';
                        END IF;

                        INSERT INTO "RTSData_Interaction" (
                            "TenantId", "InteractionId", "Segment", "OnDate", "ServerId", "Workgroup",
                            "UserId", "InteractionType", "CallType", "Direction",
                            "IsAnswered", "IsAbandoned", "TimeInQueue", "TalkTime",
                            "InQueueDateTime", "AnsweredDateTime", "UpdateTime"
                        ) VALUES (
                            v_tenant_id, v_interaction_id, v_segment, to_char(v_day, 'DD/MM/YYYY'), v_server_id, v_queue,
                            v_agent, 'Call', 'External', 'Incoming',
                            v_is_answered, v_is_abandoned, v_time_in_queue, v_talk_time,
                            v_in_queue_dt, v_answered_dt, now()
                        ) ON CONFLICT ("InteractionId", "Segment", "OnDate", "ServerId", "Workgroup")
                          DO UPDATE SET
                            "UserId" = EXCLUDED."UserId",
                            "IsAnswered" = EXCLUDED."IsAnswered",
                            "IsAbandoned" = EXCLUDED."IsAbandoned",
                            "TimeInQueue" = EXCLUDED."TimeInQueue",
                            "TalkTime" = EXCLUDED."TalkTime",
                            "InQueueDateTime" = EXCLUDED."InQueueDateTime",
                            "AnsweredDateTime" = EXCLUDED."AnsweredDateTime",
                            "UpdateTime" = EXCLUDED."UpdateTime";
                    END LOOP;
                END LOOP;
            END LOOP;
        END LOOP;
    END LOOP;
    RAISE NOTICE 'RTSData_Interaction seed complete';

    -- ========================================================================
    -- STEP 3b: Generate RTSData_UserStatusLog records
    -- ========================================================================
    RAISE NOTICE 'Generating RTSData_UserStatusLog records...';

    FOR v_day IN SELECT generate_series(CURRENT_DATE - 6, CURRENT_DATE, '1 day'::interval)::date LOOP
        FOREACH v_agent IN ARRAY v_agents LOOP
            FOR v_hour IN 9..17 LOOP
                FOR v_minute IN SELECT unnest(ARRAY[0, 30]) LOOP
                    IF v_hour = 17 AND v_minute = 30 THEN CONTINUE; END IF;

                    v_bucket := (v_day || ' ' || v_hour || ':' || v_minute || ':00')::timestamptz;
                    v_bucket_end := v_bucket + '30 minutes'::interval;
                    v_current_time := v_bucket;

                    SELECT array_agg("AnsweredDateTime" ORDER BY "AnsweredDateTime")
                    INTO v_answered_times
                    FROM "RTSData_Interaction"
                    WHERE "TenantId" = v_tenant_id
                      AND "UserId" = v_agent
                      AND "IsAnswered" = true
                      AND "AnsweredDateTime" >= v_bucket
                      AND "AnsweredDateTime" < v_bucket_end
                      AND "AnsweredDateTime" > '1753-01-02'::timestamptz;

                    v_has_answered_calls := v_answered_times IS NOT NULL AND array_length(v_answered_times, 1) > 0;

                    -- AVAILABLE at start (3-8 min)
                    v_status_duration := (3 + floor(random() * 6)::int) * 60 * 1000;
                    INSERT INTO "RTSData_UserStatusLog" (
                        "Id", "TenantId", "UserId", "StatusId", "StatusGroup", "ServerId", "OnDate",
                        "StartTime", "EndTime", "Duration", "UpdateTime"
                    ) VALUES (
                        v_log_id, v_tenant_id, v_agent, 'Available', 'AVAILABLE', v_server_id, to_char(v_day, 'DD/MM/YYYY'),
                        v_current_time, v_current_time + (v_status_duration/1000 || ' seconds')::interval, v_status_duration, now()
                    ) ON CONFLICT DO NOTHING;
                    v_log_id := v_log_id + 1;
                    v_current_time := v_current_time + (v_status_duration/1000 || ' seconds')::interval;

                    IF v_has_answered_calls THEN
                        FOREACH v_answered_time IN ARRAY v_answered_times LOOP
                            IF v_current_time < v_answered_time AND v_answered_time - v_current_time > '10 seconds'::interval THEN
                                v_status_duration := EXTRACT(EPOCH FROM (v_answered_time - v_current_time - '5 seconds'::interval))::int * 1000;
                                IF v_status_duration > 0 THEN
                                    INSERT INTO "RTSData_UserStatusLog" (
                                        "Id", "TenantId", "UserId", "StatusId", "StatusGroup", "ServerId", "OnDate",
                                        "StartTime", "EndTime", "Duration", "UpdateTime"
                                    ) VALUES (
                                        v_log_id, v_tenant_id, v_agent, 'Available', 'AVAILABLE', v_server_id, to_char(v_day, 'DD/MM/YYYY'),
                                        v_current_time, v_current_time + (v_status_duration/1000 || ' seconds')::interval, v_status_duration, now()
                                    ) ON CONFLICT DO NOTHING;
                                    v_log_id := v_log_id + 1;
                                    v_current_time := v_current_time + (v_status_duration/1000 || ' seconds')::interval;
                                END IF;
                            END IF;

                            -- ONPHONE (2-6 min)
                            v_status_duration := (120 + floor(random() * 240)::int) * 1000;
                            INSERT INTO "RTSData_UserStatusLog" (
                                "Id", "TenantId", "UserId", "StatusId", "StatusGroup", "ServerId", "OnDate",
                                "StartTime", "EndTime", "Duration", "UpdateTime"
                            ) VALUES (
                                v_log_id, v_tenant_id, v_agent, 'OnPhone', 'ONPHONE', v_server_id, to_char(v_day, 'DD/MM/YYYY'),
                                v_current_time, v_current_time + (v_status_duration/1000 || ' seconds')::interval, v_status_duration, now()
                            ) ON CONFLICT DO NOTHING;
                            v_log_id := v_log_id + 1;
                            v_current_time := v_current_time + (v_status_duration/1000 || ' seconds')::interval;

                            -- Hold (30-60 sec) - 70% chance
                            IF random() > 0.3 THEN
                                v_status_duration := (30 + floor(random() * 31)::int) * 1000;
                                INSERT INTO "RTSData_UserStatusLog" (
                                    "Id", "TenantId", "UserId", "StatusId", "StatusGroup", "ServerId", "OnDate",
                                    "StartTime", "EndTime", "Duration", "UpdateTime"
                                ) VALUES (
                                    v_log_id, v_tenant_id, v_agent, 'Hold', 'ONPHONE', v_server_id, to_char(v_day, 'DD/MM/YYYY'),
                                    v_current_time - '45 seconds'::interval, v_current_time - '15 seconds'::interval, v_status_duration, now()
                                ) ON CONFLICT DO NOTHING;
                                v_log_id := v_log_id + 1;
                            END IF;

                            -- PAPERWORK (1-3 min)
                            v_status_duration := (60 + floor(random() * 120)::int) * 1000;
                            INSERT INTO "RTSData_UserStatusLog" (
                                "Id", "TenantId", "UserId", "StatusId", "StatusGroup", "ServerId", "OnDate",
                                "StartTime", "EndTime", "Duration", "UpdateTime"
                            ) VALUES (
                                v_log_id, v_tenant_id, v_agent, 'Wrap Up', 'PAPERWORK', v_server_id, to_char(v_day, 'DD/MM/YYYY'),
                                v_current_time, v_current_time + (v_status_duration/1000 || ' seconds')::interval, v_status_duration, now()
                            ) ON CONFLICT DO NOTHING;
                            v_log_id := v_log_id + 1;
                            v_current_time := v_current_time + (v_status_duration/1000 || ' seconds')::interval;
                        END LOOP;
                    ELSE
                        v_status_duration := (60 + floor(random() * 180)::int) * 1000;
                        INSERT INTO "RTSData_UserStatusLog" (
                            "Id", "TenantId", "UserId", "StatusId", "StatusGroup", "ServerId", "OnDate",
                            "StartTime", "EndTime", "Duration", "UpdateTime"
                        ) VALUES (
                            v_log_id, v_tenant_id, v_agent, 'OnPhone', 'ONPHONE', v_server_id, to_char(v_day, 'DD/MM/YYYY'),
                            v_current_time, v_current_time + (v_status_duration/1000 || ' seconds')::interval, v_status_duration, now()
                        ) ON CONFLICT DO NOTHING;
                        v_log_id := v_log_id + 1;
                        v_current_time := v_current_time + (v_status_duration/1000 || ' seconds')::interval;
                    END IF;

                    -- Fill remaining with AVAILABLE or BREAK
                    WHILE v_current_time < v_bucket_end LOOP
                        IF random() < 0.15 AND v_bucket_end - v_current_time > '5 minutes'::interval THEN
                            v_status_duration := LEAST(
                                (300 + floor(random() * 300)::int) * 1000,
                                EXTRACT(EPOCH FROM (v_bucket_end - v_current_time))::int * 1000
                            );
                            INSERT INTO "RTSData_UserStatusLog" (
                                "Id", "TenantId", "UserId", "StatusId", "StatusGroup", "ServerId", "OnDate",
                                "StartTime", "EndTime", "Duration", "UpdateTime"
                            ) VALUES (
                                v_log_id, v_tenant_id, v_agent, 'Break', 'BREAK', v_server_id, to_char(v_day, 'DD/MM/YYYY'),
                                v_current_time, v_current_time + (v_status_duration/1000 || ' seconds')::interval, v_status_duration, now()
                            ) ON CONFLICT DO NOTHING;
                        ELSE
                            v_status_duration := EXTRACT(EPOCH FROM (v_bucket_end - v_current_time))::int * 1000;
                            IF v_status_duration > 0 THEN
                                INSERT INTO "RTSData_UserStatusLog" (
                                    "Id", "TenantId", "UserId", "StatusId", "StatusGroup", "ServerId", "OnDate",
                                    "StartTime", "EndTime", "Duration", "UpdateTime"
                                ) VALUES (
                                    v_log_id, v_tenant_id, v_agent, 'Available', 'AVAILABLE', v_server_id, to_char(v_day, 'DD/MM/YYYY'),
                                    v_current_time, v_bucket_end, v_status_duration, now()
                                ) ON CONFLICT DO NOTHING;
                            END IF;
                        END IF;
                        v_log_id := v_log_id + 1;
                        v_current_time := v_bucket_end;
                    END LOOP;
                END LOOP;
            END LOOP;
        END LOOP;
    END LOOP;
    RAISE NOTICE 'RTSData_UserStatusLog seed complete';

    -- ========================================================================
    -- STEP 4: Populate hist_queue_intervals
    -- ========================================================================
    RAISE NOTICE 'Populating hist_queue_intervals (SL threshold = %s)...', v_sl_threshold;

    INSERT INTO hist_queue_intervals (
        "Id", "TenantId", "IntervalStart", "Workgroup", "QueueId",
        "Offered", "Answered", "Abandoned", "AnsweredInSl", "SumWaitAnswered", "SumTalk",
        "CreatedAt", "UpdatedAt"
    )
    SELECT
        gen_random_uuid(),
        v_tenant_id,
        date_trunc('hour', i."InQueueDateTime") +
            floor(EXTRACT(MINUTE FROM i."InQueueDateTime") / 30) * interval '30 minutes',
        i."Workgroup",
        q."Id",
        COUNT(*),
        COUNT(*) FILTER (WHERE i."IsAnswered" = true),
        COUNT(*) FILTER (WHERE i."IsAbandoned" = true),
        COUNT(*) FILTER (WHERE i."IsAnswered" = true AND i."TimeInQueue" <= v_sl_threshold),
        COALESCE(SUM(i."TimeInQueue") FILTER (WHERE i."IsAnswered" = true), 0),
        COALESCE(SUM(i."TalkTime") FILTER (WHERE i."IsAnswered" = true), 0),
        now(),
        now()
    FROM "RTSData_Interaction" i
    LEFT JOIN "NGC_Queues" q ON q."ExternalId" = i."Workgroup" AND q."TenantId" = v_tenant_id
    WHERE i."TenantId" = v_tenant_id
      AND i."InteractionType" = 'Call'
      AND i."CallType" = 'External'
      AND i."Direction" = 'Incoming'
      AND i."InQueueDateTime" IS NOT NULL
      AND i."InQueueDateTime" >= CURRENT_DATE - 7
    GROUP BY
        date_trunc('hour', i."InQueueDateTime") +
            floor(EXTRACT(MINUTE FROM i."InQueueDateTime") / 30) * interval '30 minutes',
        i."Workgroup",
        q."Id"
    ON CONFLICT ("TenantId", "IntervalStart", "Workgroup")
    DO UPDATE SET
        "Offered" = EXCLUDED."Offered",
        "Answered" = EXCLUDED."Answered",
        "Abandoned" = EXCLUDED."Abandoned",
        "AnsweredInSl" = EXCLUDED."AnsweredInSl",
        "SumWaitAnswered" = EXCLUDED."SumWaitAnswered",
        "SumTalk" = EXCLUDED."SumTalk",
        "UpdatedAt" = now();

    RAISE NOTICE 'hist_queue_intervals populated';

    -- ========================================================================
    -- STEP 5: Populate hist_agent_intervals
    -- ========================================================================
    RAISE NOTICE 'Populating hist_agent_intervals...';

    WITH status_intervals AS (
        SELECT
            s."UserId",
            date_trunc('hour', s."StartTime") +
                floor(EXTRACT(MINUTE FROM s."StartTime") / 30) * interval '30 minutes' AS "IntervalStart",
            SUM(CASE WHEN s."StatusGroup" = 'AVAILABLE' THEN s."Duration" ELSE 0 END) AS "SumAvailableMs",
            SUM(CASE WHEN s."StatusGroup" = 'ONPHONE' THEN s."Duration" ELSE 0 END) AS "SumOnphoneMs",
            SUM(CASE WHEN s."StatusGroup" = 'ONPHONE' AND s."StatusId" = 'Hold' THEN s."Duration" ELSE 0 END) AS "SumHoldMs",
            SUM(CASE WHEN s."StatusGroup" = 'PAPERWORK' THEN s."Duration" ELSE 0 END) AS "SumPaperworkMs",
            SUM(CASE WHEN s."StatusGroup" = 'BREAK' THEN s."Duration" ELSE 0 END) AS "SumBreakMs",
            SUM(CASE WHEN s."StatusGroup" = 'TRAINING' THEN s."Duration" ELSE 0 END) AS "SumTrainingMs",
            SUM(CASE WHEN s."StatusGroup" = 'UNAVAILABLE' THEN s."Duration" ELSE 0 END) AS "SumUnavailableMs",
            SUM(COALESCE(s."Duration", 0)) AS "SumLoggedInMs"
        FROM "RTSData_UserStatusLog" s
        WHERE s."TenantId" = v_tenant_id
          AND s."StartTime" IS NOT NULL
          AND s."Duration" IS NOT NULL
          AND s."StartTime" >= CURRENT_DATE - 7
        GROUP BY s."UserId", 2
    ),
    handled_counts AS (
        SELECT
            i."UserId",
            date_trunc('hour', i."AnsweredDateTime") +
                floor(EXTRACT(MINUTE FROM i."AnsweredDateTime") / 30) * interval '30 minutes' AS "IntervalStart",
            COUNT(*) AS "Handled"
        FROM "RTSData_Interaction" i
        WHERE i."TenantId" = v_tenant_id
          AND i."IsAnswered" = true
          AND i."UserId" IS NOT NULL
          AND i."UserId" <> ''
          AND i."AnsweredDateTime" IS NOT NULL
          AND i."AnsweredDateTime" > '1753-01-02'::timestamptz
          AND i."AnsweredDateTime" >= CURRENT_DATE - 7
        GROUP BY i."UserId", 2
    )
    INSERT INTO hist_agent_intervals (
        "Id", "TenantId", "IntervalStart", "AgentExternalId", "AgentDisplayName",
        "SumAvailableMs", "SumOnphoneMs", "SumHoldMs", "SumPaperworkMs", "SumBreakMs",
        "SumTrainingMs", "SumUnavailableMs", "SumLoggedInMs", "Handled",
        "CreatedAt", "UpdatedAt"
    )
    SELECT
        gen_random_uuid(),
        v_tenant_id,
        si."IntervalStart",
        si."UserId",
        NULL,
        si."SumAvailableMs", si."SumOnphoneMs", si."SumHoldMs", si."SumPaperworkMs", si."SumBreakMs",
        si."SumTrainingMs", si."SumUnavailableMs", si."SumLoggedInMs",
        COALESCE(hc."Handled", 0),
        now(),
        now()
    FROM status_intervals si
    LEFT JOIN handled_counts hc ON si."UserId" = hc."UserId" AND si."IntervalStart" = hc."IntervalStart"
    ON CONFLICT ("TenantId", "IntervalStart", "AgentExternalId")
    DO UPDATE SET
        "SumAvailableMs" = EXCLUDED."SumAvailableMs",
        "SumOnphoneMs" = EXCLUDED."SumOnphoneMs",
        "SumHoldMs" = EXCLUDED."SumHoldMs",
        "SumPaperworkMs" = EXCLUDED."SumPaperworkMs",
        "SumBreakMs" = EXCLUDED."SumBreakMs",
        "SumTrainingMs" = EXCLUDED."SumTrainingMs",
        "SumUnavailableMs" = EXCLUDED."SumUnavailableMs",
        "SumLoggedInMs" = EXCLUDED."SumLoggedInMs",
        "Handled" = EXCLUDED."Handled",
        "UpdatedAt" = now();

    RAISE NOTICE 'hist_agent_intervals populated';

    -- ========================================================================
    -- VERIFICATION
    -- ========================================================================
    DECLARE
        v_queue_count bigint;
        v_agent_count bigint;
        v_interaction_count bigint;
        v_status_log_count bigint;
    BEGIN
        SELECT COUNT(*) INTO v_queue_count FROM hist_queue_intervals WHERE "TenantId" = v_tenant_id;
        SELECT COUNT(*) INTO v_agent_count FROM hist_agent_intervals WHERE "TenantId" = v_tenant_id;
        SELECT COUNT(*) INTO v_interaction_count FROM "RTSData_Interaction" WHERE "TenantId" = v_tenant_id;
        SELECT COUNT(*) INTO v_status_log_count FROM "RTSData_UserStatusLog" WHERE "TenantId" = v_tenant_id;

        RAISE NOTICE '=== DEV SEED COMPLETE ===';
        RAISE NOTICE 'Tenant: %', v_tenant_id;
        RAISE NOTICE 'RTSData_Interaction rows: %', v_interaction_count;
        RAISE NOTICE 'RTSData_UserStatusLog rows: %', v_status_log_count;
        RAISE NOTICE 'hist_queue_intervals rows: %', v_queue_count;
        RAISE NOTICE 'hist_agent_intervals rows: %', v_agent_count;

        IF v_queue_count = 0 THEN
            RAISE WARNING 'hist_queue_intervals is EMPTY';
        END IF;
        IF v_agent_count = 0 THEN
            RAISE WARNING 'hist_agent_intervals is EMPTY';
        END IF;
    END;
END $$;