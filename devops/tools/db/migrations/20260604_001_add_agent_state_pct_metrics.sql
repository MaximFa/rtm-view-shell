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
