-- Migration: 20260605_004_metrics_dedup
-- Source: docs/RTM_Shell_Metrics_Overview.md (metrics audit 2026-06-05)
-- Engine evidence: RTM/RTM/Union.cs — status counters ignore DataType; Calc key lookup is
-- exact-match (trailing space breaks it); Calc cannot evaluate rolling-window predicates.
-- Idempotent: safe to run repeatedly.

-- ============================================================
-- 1) Re-point grid references to canonical / working metrics
-- ============================================================
UPDATE "RTSGrid_Cell"   SET "Value"    = 'QueueNumAnsweredCallbacks'    WHERE "Value"    = 'QueueNumAcceptedCallbacks';
UPDATE "RTSGrid_Column" SET "MetricId" = 'QueueNumAnsweredCallbacks'    WHERE "MetricId" = 'QueueNumAcceptedCallbacks';

UPDATE "RTSGrid_Cell"   SET "Value"    = 'UsersSumOnCall'               WHERE "Value"    = 'QueueNumOnCallAgents';
UPDATE "RTSGrid_Column" SET "MetricId" = 'UsersSumOnCall'               WHERE "MetricId" = 'QueueNumOnCallAgents';

UPDATE "RTSGrid_Cell"   SET "Value"    = 'QueueLoginDataNumLoggedUsers' WHERE "Value"    = 'QueueNumberOfLoggedAgents';
UPDATE "RTSGrid_Column" SET "MetricId" = 'QueueLoginDataNumLoggedUsers' WHERE "MetricId" = 'QueueNumberOfLoggedAgents';

-- broken rolling-window Calc -> nearest working equivalent (whole-day 60-sec Service Level)
UPDATE "RTSGrid_Cell"   SET "Value"    = 'QueuePctAnsweredCalls60secInc' WHERE "Value"    = 'QueuePctAnsweredCalls60secIncLast30min';
UPDATE "RTSGrid_Column" SET "MetricId" = 'QueuePctAnsweredCalls60secInc' WHERE "MetricId" = 'QueuePctAnsweredCalls60secIncLast30min';

-- ============================================================
-- 2) Delete duplicates + structurally broken Calc metric
--    (QueuePctAnsweredCalls60secIncLast30min: unresolved identifier
--     InQueueDateTime -> Eval() throws every calc cycle)
-- ============================================================
DELETE FROM "RTSGrid_Metric" WHERE "MetricId" IN
 ('QueueNumAcceptedCallbacks',
  'QueueNumOnCallAgents',
  'QueueNumberOfLoggedAgents',
  'QueuePctAnsweredCalls60secIncLast30min');

-- ============================================================
-- 3) Fix MonAgentNumberOfInboundCallsOnly: external-only, matching its name
--    (was an exact duplicate of MonAgentNumberOfInboundCallsWithIntercom)
-- ============================================================
UPDATE "RTSGrid_Metric"
SET "MetricParameter" = ' (InteractionType=="Call" ||  InteractionType=="Callback") && CallType=="External" && Direction=="Incoming"'
WHERE "MetricId" = 'MonAgentNumberOfInboundCallsOnly';

-- ============================================================
-- 4) Fix QueueSLAIn30secFrom80PctInc: trim trailing space inside [MetricId] ref
--    (exact-match dictionary lookup fails -> numerator always 0)
-- ============================================================
UPDATE "RTSGrid_Metric"
SET "MetricParameter" = REPLACE("MetricParameter", '[QueueNumAnsweredCalls30sec ]', '[QueueNumAnsweredCalls30sec]')
WHERE "MetricId" = 'QueueSLAIn30secFrom80PctInc';

-- ============================================================
-- 5) Description fixes (audit findings, cosmetic)
-- ============================================================
UPDATE "RTSGrid_Metric" SET "Description" = 'QM - Number of Answered Callbacks in 60 sec'             WHERE "MetricId" = 'QueueNumAnsweredCallbacks60sec';
UPDATE "RTSGrid_Metric" SET "Description" = 'QM - Number of Wrap Up Agents in Queue Skill'            WHERE "MetricId" = 'QueueNumWrapUpAgents';
UPDATE "RTSGrid_Metric" SET "Description" = 'Agent - ID of a representative who was connected today'  WHERE "MetricId" = 'MonAgentTodayLogin';
UPDATE "RTSGrid_Metric" SET "Description" = REPLACE("Description", 'exluding', 'excluding')           WHERE "Description" LIKE '%exluding%';
UPDATE "RTSGrid_Metric" SET "Description" = 'Agent Group - Number of Outbound Calls'                  WHERE "MetricId" = 'MonSumAgentsMakeCalls';
UPDATE "RTSGrid_Metric" SET "Description" = 'Agent - Average Outbound Call Duration'                  WHERE "MetricId" = 'MonAgentAverageMakeCallDuration';
UPDATE "RTSGrid_Metric" SET "Description" = 'Agent - Cumulative Talk Duration Percent'                WHERE "MetricId" = 'MonAgentTalkDurationPct';
UPDATE "RTSGrid_Metric" SET "Description" = 'Agent - Current Status'                                  WHERE "MetricId" = 'MonAgentState';
UPDATE "RTSGrid_Metric" SET "Description" = 'Agent - Active Interaction ID'                           WHERE "MetricId" = 'MonAgentActiveInteractionId';
UPDATE "RTSGrid_Metric" SET "Description" = 'Agent Group - Number of Currently Logged in Users'       WHERE "MetricId" = 'QueueLoginDataNumLoggedUsers';
UPDATE "RTSGrid_Metric" SET "Description" = 'QM - Number of Incoming Chats and Emails including Waiting' WHERE "MetricId" = 'QueueNumIcomingOnlineInteractions';

-- ============================================================
-- 6) DataType anomaly
-- ============================================================
UPDATE "RTSGrid_Metric" SET "DataType" = 'UsersSummary' WHERE "MetricId" = 'QueueLoginDataNumTrainingUsers' AND "DataType" = 'String';

-- ============================================================
-- Verification
-- ============================================================
SELECT count(*) AS total_metrics FROM "RTSGrid_Metric";                          -- expected: 198
SELECT count(*) AS remaining_deleted FROM "RTSGrid_Metric"
WHERE "MetricId" IN ('QueueNumAcceptedCallbacks','QueueNumOnCallAgents',
                     'QueueNumberOfLoggedAgents','QueuePctAnsweredCalls60secIncLast30min');  -- expected: 0
SELECT "MetricId","MetricParameter" FROM "RTSGrid_Metric" WHERE "MetricId" = 'MonAgentNumberOfInboundCallsOnly';  -- no Intercom
SELECT "MetricId","MetricParameter" FROM "RTSGrid_Metric" WHERE "MetricId" = 'QueueSLAIn30secFrom80PctInc';       -- no '30sec ]'
SELECT count(*) AS orphan_cells FROM "RTSGrid_Cell"
WHERE "Value" IN ('QueueNumAcceptedCallbacks','QueueNumOnCallAgents',
                  'QueueNumberOfLoggedAgents','QueuePctAnsweredCalls60secIncLast30min');     -- expected: 0
