-- ============================================================================
-- Migration: Add UNAVAILABLE history metrics for DayTrend Agent Metrics
-- Date: 2026-06-06
--
-- Purpose: Add UNAVAILABLE agent-status history metrics (DayTrend Agent Metrics
-- — 6th status group). Mirrors the existing statuslog.* AgentStatusLog family.
-- fn_daytrendagentstatus will EMIT these ids in P3 (BU-scoped rewrite);
-- seeded for fresh installs via DatabaseInitializer (metrics task).
--
-- This migration is DATA ONLY — no function changes here.
-- ============================================================================

INSERT INTO public.history_metrics
  ("MetricId","Description","DataType","MetricFunction","MetricParameter","MetricFormat","DefaultValue","ValueType","MetricType")
VALUES
  ('statuslog.unavailable_agents',  'Unavailable Agents', 'int',    'COUNT_DISTINCT', 'group:UNAVAILABLE', '0',     '0', 'Number', 'AgentStatusLog'),
  ('statuslog.unavailable_time_ms', 'Unavailable Time',   'bigint', 'SUM_OVERLAP_MS', 'group:UNAVAILABLE', 'mm:ss', '0', 'Time',   'AgentStatusLog')
ON CONFLICT ("MetricId") DO NOTHING;

-- ============================================================================
-- End of migration
-- ============================================================================
