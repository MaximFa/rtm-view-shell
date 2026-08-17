-- ==============================================================================
-- ALIGNMENT SCRIPT -- Bring server up to baseline
-- Target: rtmviewdb@localhost:5432
-- Generated: 2026-07-03 11:23:35
-- Run as: psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f <thisfile>
-- ==============================================================================
-- ##############################################################################
-- !!! REVIEW BEFORE RUNNING -- DO NOT APPLY BLINDLY !!!
-- This script assumes the REPO BASELINE is the source of truth. If the baseline is
-- itself stale/wrong, applying it will DAMAGE a correct server. In particular the
-- DIMENSION B (routine-kind) section can DROP+recreate routines in the WRONG kind
-- (e.g. revert a correct PROCEDURE back to FUNCTION) -> PostgreSQL 42809 on every RTM
-- CALL (RTM-SEC-002). Verify the DIRECTION of each change per object against the live
-- server before running. When in doubt, fix the BASELINE, not the server.
-- ##############################################################################
\set ON_ERROR_STOP on

-- ===== DIMENSION A: SCHEMA =====
-- MANUAL REVIEW: Schema drift detected but not auto-fixed.
-- Apply unapplied migrations below. For remaining drift, review manually.

-- ===== DIMENSION D: UNAPPLIED MIGRATIONS =====

-- ===== migration 20260604_001_add_agent_state_pct_metrics =====
-- Migration: 20260604_001_add_agent_state_pct_metrics
-- Adds TotalStatusGroupPercent metrics for AVAILABLE, BREAK, PAPERWORK, TRAINING
-- Modelled after existing MonAgentTalkDurationPct (ONPHONE).
-- Idempotent: ON CONFLICT DO NOTHING.

INSERT INTO "RTSGrid_Metric"
    ("MetricId", "Description", "DataType", "MetricFunction", "MetricParameter",
     "MetricFormat", "DefaultValue", "ValueType", "MetricType")
VALUES
    ('MonAgentAvailableDurationPct',
     'Agent - Cumulative Available Duration Percent',
     'User', 'TotalStatusGroupPercent', 'AVAILABLE',
     NULL, NULL, 'number', 'Agent'),

    ('MonAgentBreakDurationPct',
     'Agent - Cumulative Break Duration Percent',
     'User', 'TotalStatusGroupPercent', 'BREAK',
     NULL, NULL, 'number', 'Agent'),

    ('MonAgentPaperworkDurationPct',
     'Agent - Cumulative Paperwork Duration Percent',
     'User', 'TotalStatusGroupPercent', 'PAPERWORK',
     NULL, NULL, 'number', 'Agent'),

    ('MonAgentTrainingDurationPct',
     'Agent - Cumulative Training Duration Percent',
     'User', 'TotalStatusGroupPercent', 'TRAINING',
     NULL, NULL, 'number', 'Agent')

ON CONFLICT ("MetricId") DO NOTHING;

-- Verify: should return 4 rows after first run, 0 on repeat
SELECT "MetricId", "MetricParameter"
FROM   "RTSGrid_Metric"
WHERE  "MetricId" IN (
    'MonAgentAvailableDurationPct',
    'MonAgentBreakDurationPct',
    'MonAgentPaperworkDurationPct',
    'MonAgentTrainingDurationPct'
)
ORDER BY "MetricParameter";


-- ===== migration 20260606_005_history_unavailable_metrics =====
-- ============================================================================
-- Migration: Add UNAVAILABLE history metrics for DayTrend Agent Metrics
-- Date: 2026-06-06
--
-- Purpose: Add UNAVAILABLE agent-status history metrics (DayTrend Agent Metrics
-- â€” 6th status group). Mirrors the existing statuslog.* AgentStatusLog family.
-- fn_daytrendagentstatus will EMIT these ids in P3 (BU-scoped rewrite);
-- seeded for fresh installs via DatabaseInitializer (metrics task).
--
-- This migration is DATA ONLY â€” no function changes here.
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

-- UNKNOWN (no ledger entry, probe absent) -- operator verify: 20260605_004_metrics_dedup
-- UNKNOWN (no ledger entry, probe absent) -- operator verify: 20260606_008_daytrend_fn_bu_scope
-- UNKNOWN (no ledger entry, probe absent) -- operator verify: 20260622_001_arch_contour_indexes