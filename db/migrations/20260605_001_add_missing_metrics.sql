-- Migration: 20260605_001_add_missing_metrics
-- Adds QueueNumAbandonedCalls, QueueNumAbandonedCallbacks, QueueNumOutboundCalls,
-- QueueNumTransferredCalls to RTSGrid_Metric.
-- QueueNumAbandonedCalls/Callbacks fix broken [MetricId] refs in Calc metrics.
-- Idempotent: ON CONFLICT DO NOTHING.

INSERT INTO "RTSGrid_Metric"
    ("MetricId", "Description", "DataType", "MetricFunction", "MetricParameter",
     "MetricFormat", "DefaultValue", "ValueType", "MetricType")
VALUES
    ('QueueNumAbandonedCalls',
     'QM - Number of Abandoned Calls',
     'Interactions Summary', 'InteractionsCount',
     '(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsAbandoned && !IsCallbackRequest',
     NULL, NULL, 'number', 'Data'),

    ('QueueNumAbandonedCallbacks',
     'QM - Number of Abandoned Callbacks',
     'Interactions Summary', 'InteractionsCount',
     '(InteractionType=="Callback") && (CallType=="External")  && Direction == "Incoming" && IsAbandoned && !IsCallbackRequest',
     NULL, NULL, 'number', 'Data'),

    ('QueueNumOutboundCalls',
     'QM - Number of Outbound Calls',
     'Interactions Summary', 'InteractionsCount',
     '(InteractionType=="Call") && (CallType=="External")  && Direction == "Outgoing"',
     NULL, NULL, 'number', 'Data'),

    ('QueueNumTransferredCalls',
     'QM - Number of Transferred Calls',
     'Interactions Summary', 'InteractionsCount',
     '(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && IsTransferred',
     NULL, NULL, 'number', 'Data')

ON CONFLICT ("MetricId") DO NOTHING;

-- Verify: should return 4 rows after first run, 0 on repeat
SELECT "MetricId", "MetricFunction", "MetricParameter"
FROM   "RTSGrid_Metric"
WHERE  "MetricId" IN (
    'QueueNumAbandonedCalls',
    'QueueNumAbandonedCallbacks',
    'QueueNumOutboundCalls',
    'QueueNumTransferredCalls'
)
ORDER BY "MetricId";
