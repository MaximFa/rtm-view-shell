-- seed_dataproof_screen.sql
-- PURPOSE: DATA-PROOF seed — one report-screen with 1 widget per type, bound to REAL scope with rows.
-- DATA-ONLY: NO CREATE TABLE / NO CREATE FUNCTION / NO EF migration.
-- Guard: run ONLY on dev/mirror DB (rtmviewdb or operator-named mirror), NEVER on production.
-- Idempotent: ON CONFLICT upserts. Fixed UUIDs for repeatable runs.
-- BU-ONLY scope (operator 2026-06-26): ALL 5 widgets use {"scope":{"businessUnitIds":[<int>],"agentAxis":"detail"}}.

-- ============================================================================
-- STEP 1: PRECONDITION CHECKS (abort if schema missing — DATA-ONLY)
-- ============================================================================

DO $$
BEGIN
  -- Check report tables exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='report_screens') THEN
    RAISE EXCEPTION 'ABORT: report_screens table missing — run EF migration 20260624093015_AddReportEntities first';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='report_widgets') THEN
    RAISE EXCEPTION 'ABORT: report_widgets table missing — run EF migration 20260624093015_AddReportEntities first';
  END IF;

  -- Check hist tables exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='hist_queue_intervals') THEN
    RAISE EXCEPTION 'ABORT: hist_queue_intervals table missing — run EF migration 20260621080000_AddHistoricalReportsTables first';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='hist_agent_intervals') THEN
    RAISE EXCEPTION 'ABORT: hist_agent_intervals table missing — run EF migration 20260621080000_AddHistoricalReportsTables first';
  END IF;

  -- Check partition function exists
  IF to_regprocedure('fn_hist_ensure_partitions(text,int,int)') IS NULL THEN
    RAISE EXCEPTION 'ABORT: fn_hist_ensure_partitions function missing — run EF migration 20260621080000 first';
  END IF;

  RAISE NOTICE 'STEP 1 PASS: Schema preconditions verified';
END $$;

-- ============================================================================
-- STEP 2: SELF-DISCOVER data-bearing tenant + scopes
-- ============================================================================

DO $$
DECLARE
  v_tenant_id    uuid;
  v_owner_user   uuid;
  v_bu_id        int;
  v_queues_count int;
  v_agents_count int;
  v_qact         bigint;
BEGIN
  -- 2a. Tenant with MOST hist rows
  SELECT t."Id" INTO v_tenant_id
  FROM tenants t
  JOIN (
    SELECT "TenantId", COUNT(*) n FROM hist_queue_intervals GROUP BY "TenantId"
    UNION ALL
    SELECT "TenantId", COUNT(*) n FROM hist_agent_intervals GROUP BY "TenantId"
  ) h ON h."TenantId" = t."Id"
  GROUP BY t."Id" ORDER BY SUM(h.n) DESC LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'ABORT: No hist data anywhere — seed/load data first';
  END IF;
  RAISE NOTICE 'STEP 2a: tenant_id = %', v_tenant_id;

  -- 2b. Owner user (prefer Superadmin/Admin in that tenant; fall back to any user)
  SELECT u."Id" INTO v_owner_user
  FROM "AspNetUsers" u
  WHERE u."TenantId" = v_tenant_id
  ORDER BY (u."NormalizedUserName" LIKE '%SUPER%') DESC, u."Id"
  LIMIT 1;

  IF v_owner_user IS NULL THEN
    -- Fall back to platform Superadmin
    SELECT u."Id" INTO v_owner_user
    FROM "AspNetUsers" u
    ORDER BY (u."NormalizedUserName" LIKE '%SUPER%') DESC, u."Id"
    LIMIT 1;
    RAISE NOTICE 'STEP 2b: owner_user = % (platform fallback)', v_owner_user;
  ELSE
    RAISE NOTICE 'STEP 2b: owner_user = %', v_owner_user;
  END IF;

  IF v_owner_user IS NULL THEN
    RAISE EXCEPTION 'ABORT: No users in database to own the screen';
  END IF;

  -- 2c. BU with BOTH queue-data AND agent-data
  WITH bu_q AS (
    SELECT bqc."BusinessUnitId" AS bu_id,
           COUNT(DISTINCT h."Workgroup") AS queues_with_data,
           SUM(h."Answered") + SUM(h."Abandoned") AS qact
    FROM "NGC_BusinessUnitQueueClassification" bqc
    JOIN hist_queue_intervals h ON h."Workgroup" = bqc."QueueId" AND h."TenantId" = bqc."TenantId"
    WHERE bqc."TenantId" = v_tenant_id AND bqc."ClassificationId" = 'ALL'
    GROUP BY bqc."BusinessUnitId"
  ), bu_a AS (
    SELECT bus."BusinessUnitId" AS bu_id,
           COUNT(DISTINCT h."AgentExternalId") AS agents_with_data
    FROM "NGC_BusinessUnitSupergroup" bus
    JOIN "NGC_SupergroupAgentgroup" sag ON sag."SupergroupId" = bus."SupergroupId"
         AND sag."TenantId" = bus."TenantId" AND sag."AgentgroupId" IS NOT NULL
    JOIN "NGC_UserAgentgroup" uag ON uag."AgentgroupId" = sag."AgentgroupId"
         AND uag."TenantId" = bus."TenantId" AND uag."UserId" IS NOT NULL
    JOIN hist_agent_intervals h ON h."AgentExternalId" = uag."UserId" AND h."TenantId" = bus."TenantId"
    WHERE bus."TenantId" = v_tenant_id
    GROUP BY bus."BusinessUnitId"
  )
  SELECT q.bu_id, q.queues_with_data, q.qact, a.agents_with_data
  INTO v_bu_id, v_queues_count, v_qact, v_agents_count
  FROM bu_q q JOIN bu_a a ON a.bu_id = q.bu_id
  ORDER BY q.qact DESC, a.agents_with_data DESC
  LIMIT 1;

  IF v_bu_id IS NULL THEN
    RAISE EXCEPTION 'ABORT: No single BU has BOTH queue-data AND agent-data — check BU mappings or pick per-widget-family';
  END IF;
  RAISE NOTICE 'STEP 2c: bu_id = %, queues_with_data = %, agents_with_data = %, qact = %',
               v_bu_id, v_queues_count, v_agents_count, v_qact;

  -- Store discovered values in temp table for subsequent statements
  CREATE TEMP TABLE IF NOT EXISTS _dataproof_params (
    tenant_id uuid, owner_user uuid, bu_id int
  ) ON COMMIT DROP;
  DELETE FROM _dataproof_params;
  INSERT INTO _dataproof_params VALUES (v_tenant_id, v_owner_user, v_bu_id);

  RAISE NOTICE 'STEP 2 COMPLETE: Discovery successful';
END $$;

-- ============================================================================
-- STEP 3: SEED the screen + 5 widgets (idempotent, fixed UUIDs)
-- ============================================================================

-- Screen
INSERT INTO public.report_screens
  ("Id", "TenantId", "Name", "Description", "CategoryId", "Status", "IsPublic", "IsDarkMode", "LayoutJson",
   "CreatedByUserId", "CreatedAt", "UpdatedByUserId", "UpdatedAt", "IsDeleted", "DeletedAt", "DeletedByUserId")
SELECT
  '11111111-1111-4111-8111-111111111111'::uuid,
  p.tenant_id,
  'DATA PROOF',
  'Auto-seeded data-proof screen — 1 widget per type bound to a real scope with rows.',
  NULL,
  'Published',
  true,
  false,
  NULL,
  p.owner_user,
  now(),
  p.owner_user,
  now(),
  false,
  NULL,
  NULL
FROM _dataproof_params p
ON CONFLICT ("Id") DO UPDATE SET
  "TenantId" = EXCLUDED."TenantId",
  "Status" = 'Published',
  "IsPublic" = true,
  "IsDeleted" = false,
  "DeletedAt" = NULL,
  "DeletedByUserId" = NULL,
  "UpdatedByUserId" = EXCLUDED."UpdatedByUserId",
  "UpdatedAt" = now();

-- Widget: QueueInterval
INSERT INTO public.report_widgets
  ("Id", "ReportScreenId", "TenantId", "WidgetType", "PositionJson", "ConfigJson", "IsDeleted")
SELECT
  '21111111-1111-4111-8111-111111111111'::uuid,
  '11111111-1111-4111-8111-111111111111'::uuid,
  p.tenant_id,
  'QueueInterval',
  '{"x":0,"y":0,"width":600,"height":320}'::jsonb,
  jsonb_build_object('scope', jsonb_build_object('businessUnitIds', jsonb_build_array(p.bu_id), 'agentAxis', 'detail'), 'interval', 30),
  false
FROM _dataproof_params p
ON CONFLICT ("Id") DO UPDATE SET
  "TenantId" = EXCLUDED."TenantId",
  "WidgetType" = EXCLUDED."WidgetType",
  "PositionJson" = EXCLUDED."PositionJson",
  "ConfigJson" = EXCLUDED."ConfigJson",
  "IsDeleted" = false;

-- Widget: QueueWaitTime
INSERT INTO public.report_widgets
  ("Id", "ReportScreenId", "TenantId", "WidgetType", "PositionJson", "ConfigJson", "IsDeleted")
SELECT
  '22222222-2222-4222-8222-222222222222'::uuid,
  '11111111-1111-4111-8111-111111111111'::uuid,
  p.tenant_id,
  'QueueWaitTime',
  '{"x":620,"y":0,"width":600,"height":320}'::jsonb,
  jsonb_build_object('scope', jsonb_build_object('businessUnitIds', jsonb_build_array(p.bu_id), 'agentAxis', 'detail')),
  false
FROM _dataproof_params p
ON CONFLICT ("Id") DO UPDATE SET
  "TenantId" = EXCLUDED."TenantId",
  "WidgetType" = EXCLUDED."WidgetType",
  "PositionJson" = EXCLUDED."PositionJson",
  "ConfigJson" = EXCLUDED."ConfigJson",
  "IsDeleted" = false;

-- Widget: AgentMonthly
INSERT INTO public.report_widgets
  ("Id", "ReportScreenId", "TenantId", "WidgetType", "PositionJson", "ConfigJson", "IsDeleted")
SELECT
  '23333333-3333-4333-8333-333333333333'::uuid,
  '11111111-1111-4111-8111-111111111111'::uuid,
  p.tenant_id,
  'AgentMonthly',
  '{"x":0,"y":340,"width":600,"height":320}'::jsonb,
  jsonb_build_object('scope', jsonb_build_object('businessUnitIds', jsonb_build_array(p.bu_id), 'agentAxis', 'detail')),
  false
FROM _dataproof_params p
ON CONFLICT ("Id") DO UPDATE SET
  "TenantId" = EXCLUDED."TenantId",
  "WidgetType" = EXCLUDED."WidgetType",
  "PositionJson" = EXCLUDED."PositionJson",
  "ConfigJson" = EXCLUDED."ConfigJson",
  "IsDeleted" = false;

-- Widget: AgentShiftDetail
INSERT INTO public.report_widgets
  ("Id", "ReportScreenId", "TenantId", "WidgetType", "PositionJson", "ConfigJson", "IsDeleted")
SELECT
  '24444444-4444-4444-8444-444444444444'::uuid,
  '11111111-1111-4111-8111-111111111111'::uuid,
  p.tenant_id,
  'AgentShiftDetail',
  '{"x":620,"y":340,"width":600,"height":320}'::jsonb,
  jsonb_build_object('scope', jsonb_build_object('businessUnitIds', jsonb_build_array(p.bu_id), 'agentAxis', 'detail')),
  false
FROM _dataproof_params p
ON CONFLICT ("Id") DO UPDATE SET
  "TenantId" = EXCLUDED."TenantId",
  "WidgetType" = EXCLUDED."WidgetType",
  "PositionJson" = EXCLUDED."PositionJson",
  "ConfigJson" = EXCLUDED."ConfigJson",
  "IsDeleted" = false;

-- Widget: Distribution
INSERT INTO public.report_widgets
  ("Id", "ReportScreenId", "TenantId", "WidgetType", "PositionJson", "ConfigJson", "IsDeleted")
SELECT
  '25555555-5555-4555-8555-555555555555'::uuid,
  '11111111-1111-4111-8111-111111111111'::uuid,
  p.tenant_id,
  'Distribution',
  '{"x":0,"y":680,"width":600,"height":320}'::jsonb,
  jsonb_build_object('scope', jsonb_build_object('businessUnitIds', jsonb_build_array(p.bu_id), 'agentAxis', 'detail')),
  false
FROM _dataproof_params p
ON CONFLICT ("Id") DO UPDATE SET
  "TenantId" = EXCLUDED."TenantId",
  "WidgetType" = EXCLUDED."WidgetType",
  "PositionJson" = EXCLUDED."PositionJson",
  "ConfigJson" = EXCLUDED."ConfigJson",
  "IsDeleted" = false;

-- ============================================================================
-- STEP 4: ROW-COUNT PROOF per widget
-- ============================================================================

DO $$
DECLARE
  v_tenant_id       uuid;
  v_bu_id           int;
  v_aggregated_rows bigint;
  v_raw_rows        bigint;
  v_qact            bigint;
  v_interval_rows   bigint;
  v_distinct_months bigint;
  v_distinct_agents bigint;
BEGIN
  SELECT tenant_id, bu_id INTO v_tenant_id, v_bu_id FROM _dataproof_params;

  -- Queue widgets proof (BU-aggregated: one row per interval)
  WITH wg AS (
    SELECT DISTINCT bqc."QueueId" AS workgroup
    FROM "NGC_BusinessUnitQueueClassification" bqc
    WHERE bqc."BusinessUnitId" = v_bu_id AND bqc."TenantId" = v_tenant_id AND bqc."ClassificationId" = 'ALL'
  )
  SELECT COUNT(DISTINCT h."IntervalStart"), COUNT(*), SUM(h."Answered") + SUM(h."Abandoned")
  INTO v_aggregated_rows, v_raw_rows, v_qact
  FROM hist_queue_intervals h JOIN wg ON wg.workgroup = h."Workgroup"
  WHERE h."TenantId" = v_tenant_id
    AND h."IntervalStart" >= '2000-01-01' AND h."IntervalStart" < '2100-01-01';

  RAISE NOTICE 'PROOF QueueInterval/WaitTime/Distribution: aggregated_rows=% raw_rows=% qact=%',
               COALESCE(v_aggregated_rows, 0), COALESCE(v_raw_rows, 0), COALESCE(v_qact, 0);

  IF COALESCE(v_aggregated_rows, 0) = 0 THEN
    RAISE WARNING 'INCOMPLETE: Queue widgets will show no data (0 aggregated rows)';
  END IF;

  -- Agent widgets proof
  WITH agents AS (
    SELECT DISTINCT uag."UserId" AS ext
    FROM "NGC_BusinessUnitSupergroup" bus
    JOIN "NGC_SupergroupAgentgroup" sag ON sag."SupergroupId" = bus."SupergroupId"
         AND sag."TenantId" = bus."TenantId" AND sag."AgentgroupId" IS NOT NULL
    JOIN "NGC_UserAgentgroup" uag ON uag."AgentgroupId" = sag."AgentgroupId"
         AND uag."TenantId" = bus."TenantId" AND uag."UserId" IS NOT NULL
    WHERE bus."BusinessUnitId" = v_bu_id AND bus."TenantId" = v_tenant_id
  )
  SELECT COUNT(*), COUNT(DISTINCT to_char(h."IntervalStart", 'YYYY-MM')), COUNT(DISTINCT h."AgentExternalId")
  INTO v_interval_rows, v_distinct_months, v_distinct_agents
  FROM hist_agent_intervals h JOIN agents a ON a.ext = h."AgentExternalId"
  WHERE h."TenantId" = v_tenant_id
    AND h."IntervalStart" >= '2000-01-01' AND h."IntervalStart" < '2100-01-01';

  RAISE NOTICE 'PROOF AgentMonthly/ShiftDetail: interval_rows=% distinct_months=% distinct_agents=%',
               COALESCE(v_interval_rows, 0), COALESCE(v_distinct_months, 0), COALESCE(v_distinct_agents, 0);

  IF COALESCE(v_interval_rows, 0) = 0 THEN
    RAISE WARNING 'INCOMPLETE: Agent widgets will show no data (0 interval rows)';
  END IF;

  RAISE NOTICE 'STEP 4 COMPLETE: Row-count proof generated';
END $$;

-- Summary
DO $$
DECLARE
  v_tenant_id  uuid;
  v_owner_user uuid;
  v_bu_id      int;
BEGIN
  SELECT tenant_id, owner_user, bu_id INTO v_tenant_id, v_owner_user, v_bu_id FROM _dataproof_params;
  RAISE NOTICE '=== DATA-PROOF SEED COMPLETE ===';
  RAISE NOTICE 'Screen ID: 11111111-1111-4111-8111-111111111111';
  RAISE NOTICE 'Tenant: %', v_tenant_id;
  RAISE NOTICE 'Owner: %', v_owner_user;
  RAISE NOTICE 'BU scope: %', v_bu_id;
  RAISE NOTICE 'Widgets: QueueInterval, QueueWaitTime, AgentMonthly, AgentShiftDetail, Distribution';
  RAISE NOTICE 'Status: Published, IsPublic=true';
END $$;
