-- 20260713_001_add_completed_incoming_calls.sql
-- Add client-parity metric QueueNumberOfCompletedIncomingCalls (client gap, 2026-07-13 diff).
-- Completed incoming external voice calls = not in queue AND not currently talking (disconnected).
-- Distinct from QueueNumIncomingCompletedCalls (which excludes callback requests, not active talk).
-- Idempotent; §38a self-record.
\set ON_ERROR_STOP on

INSERT INTO public."RTSGrid_Metric"
  ("MetricId","Description","DataType","MetricFunction","MetricParameter","MetricFormat","DefaultValue",
   "ValueType","MetricType","CatalogCategory","CatalogStatus","Channel","DisplayName","Family",
   "LongDescription","ShortDescription","Comparison","ThresholdSec")
VALUES ('QueueNumberOfCompletedIncomingCalls', 'QM - Number of Completed Incoming Calls', 'Interactions Summary', 'InteractionsCount',
        '(InteractionType=="Call") && (CallType=="External")  && Direction == "Incoming" && !IsInQueue && !IsTalk', NULL, NULL, 'number', 'Data', 'Queue', 'active', 'calls',
        'Completed Incoming Calls Today', 'queue.volume.incoming_completed',
        'Counts incoming external voice calls that have completed the interaction today - no longer in queue and not currently talking (i.e. disconnected). Distinct from QueueNumIncomingCompletedCalls, which counts calls that finished queuing (excludes callback requests) rather than fully-disconnected calls.',
        'Number of incoming external voice calls that have completed the interaction today (not in queue and not currently talking = disconnected).',
        'Differs from QueueNumIncomingCompletedCalls: this counts calls whose interaction finished (not in queue AND not currently talking = disconnected); QueueNumIncomingCompletedCalls excludes callback requests instead of active talk.', NULL)
ON CONFLICT ("MetricId") DO NOTHING;

INSERT INTO public.db_patch_history (migration_name)
VALUES ('20260713_001_add_completed_incoming_calls') ON CONFLICT (migration_name) DO NOTHING;

SELECT "MetricId","MetricFunction","MetricParameter" FROM public."RTSGrid_Metric" WHERE "MetricId" = 'QueueNumberOfCompletedIncomingCalls';
