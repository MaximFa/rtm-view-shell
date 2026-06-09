-- =====================================================================
-- patch_abandoned_metrics.sql  —  idempotent server-side follow-up patch
-- =====================================================================
-- Adds the canonical QueueNum* metrics that fix broken Calc [MetricId] refs
-- and backfills their catalogue fields (the main backfill ran before these
-- rows existed). Source: db/migrations/20260605_001 + the 4 matching backfill
-- blocks of db/migrations/20260606_003.
--
-- Canonical 'QueueNumAbandonedCalls/Callbacks' (correct spelling) replace the
-- broken refs; the typo'd legacy rows 'QueueNumAbandonefCalls/Callbacks' from
-- the old baseline remain as inert, un-catalogued rows (see verify section 3).
--
-- Safe to re-run (ON CONFLICT DO NOTHING / value-matched UPDATEs).
-- Run as table owner or superuser:
--   psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f patch_abandoned_metrics.sql
-- =====================================================================

\set ON_ERROR_STOP on
\timing on

\echo '== Section 1: add canonical metrics (20260605_001, ON CONFLICT DO NOTHING) =='
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

\echo '== Section 2: backfill catalogue for the 4 canonical metrics =='
BEGIN;

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Abandoned Calls',
    "ShortDescription" = 'Number of incoming external incoming voice calls abandoned in queue today (caller left before an agent answered).',
    "LongDescription" = 'Counts incoming external incoming voice calls that left the queue without being answered (caller hung up / closed the chat). Interactions that converted to a callback request are excluded, so requesting a callback is not treated as abandonment.',
    "Comparison" = 'Counterpart of ''Answered''. See ''Average Time to Abandon'' for how long abandoning customers waited.',
    "StandardKpi" = 'Abandoned contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.abandoned',
    "Channel" = 'calls',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAbandonedCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Abandoned Callbacks',
    "ShortDescription" = 'Number of incoming callback interactions (customer-requested return calls handled by the queue) abandoned in queue today (caller left before an agent answered).',
    "LongDescription" = 'Counts incoming callback interactions (customer-requested return calls handled by the queue) that left the queue without being answered (caller hung up / closed the chat). Interactions that converted to a callback request are excluded, so requesting a callback is not treated as abandonment.',
    "Comparison" = 'Counterpart of ''Answered''. See ''Average Time to Abandon'' for how long abandoning customers waited.',
    "StandardKpi" = 'Abandoned contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.abandoned',
    "Channel" = 'callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAbandonedCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Outbound Calls',
    "ShortDescription" = 'Number of outgoing external calls today.',
    "LongDescription" = 'Counts outgoing external voice calls placed today within the Business Unit scope (any outcome).',
    "Comparison" = 'Per-agent equivalent: "Agent - Number of Outbound Calls". For group aggregation see "Agent Group - Number of Outbound Calls" (MonSumAgentsMakeCalls).',
    "StandardKpi" = 'Outbound volume',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.misc',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumOutboundCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Transferred Calls',
    "ShortDescription" = 'Number of incoming calls transferred today.',
    "LongDescription" = 'Counts incoming external calls flagged as transferred (IsTransferred). High values may indicate routing/skill mismatch or first-contact-resolution problems.',
    "Comparison" = 'Related to FCR analysis: transfers are a proxy for unresolved-at-first-touch contacts.',
    "StandardKpi" = 'Transfer rate input',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.misc',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumTransferredCalls';

COMMIT;

\echo '== Section 3: verification =='
\echo '-- (a) the 4 canonical metrics: present + catalogued (DisplayName not null):'
SELECT "MetricId",
       ("DisplayName" IS NOT NULL) AS catalogued,
       "MetricFunction", "MetricParameter"
FROM   public."RTSGrid_Metric"
WHERE  "MetricId" IN ('QueueNumAbandonedCalls','QueueNumAbandonedCallbacks',
                      'QueueNumOutboundCalls','QueueNumTransferredCalls')
ORDER BY "MetricId";

\echo '-- (b) overall coverage (typos remain uncatalogued):'
SELECT count(*) AS total_metrics,
       count(*) FILTER (WHERE "DisplayName" IS NOT NULL) AS catalogued,
       count(*) FILTER (WHERE "DisplayName" IS NULL)     AS uncatalogued
FROM public."RTSGrid_Metric";

\echo '-- (c) any remaining NULL DisplayName (expected: the 2 typo rows only):'
SELECT "MetricId" FROM public."RTSGrid_Metric" WHERE "DisplayName" IS NULL ORDER BY "MetricId";

\echo '== patch_abandoned_metrics.sql complete =='
