-- 20260606_006_unavailable_rtsgrid_metrics: real-time RTSGrid metrics for the UNAVAILABLE status group.
-- Mirrors the BREAK-group metrics. Pairs _005 history (statuslog.unavailable_*). Idempotent.
INSERT INTO "RTSGrid_Metric"
 ("MetricId","Description","DataType","MetricFunction","MetricParameter","MetricFormat","DefaultValue","ValueType","MetricType",
  "CatalogCategory","CatalogStatus","Comparison","DisplayName","Family","LongDescription","ShortDescription","StandardKpi")
VALUES
 ('QueueLoginDataNumUnavailableUsers','Agent Group - Number of Agents in Unavailable State Group','UsersSummary','UsersInStatusGroupCount','UNAVAILABLE',NULL,NULL,'number','Data',
  'AgentGroup','active','Pairs the historical statuslog.unavailable_agents. State-level counters target specific states.','Agents in Unavailable Group','group.state_group_count','Real-time count of agents whose current status belongs to the UNAVAILABLE group (logged in but not available for interactions).','Number of agents currently in the UNAVAILABLE status group.','Shrinkage (real-time)'),
 ('MonAgentUnavailableDuration','Agent - Cumulative Unavailable Group Duration','User','TotalStatusGroupDuration','UNAVAILABLE',NULL,NULL,'time','Agent',
  'Agent','active','Percent-of-login counterpart: % Unavailable Time of Login. State-level (status "Unavailable") is MonAgentUnavailableStateDuration.','Cumulative Unavailable Duration','agent.duration','Cumulative time today in statuses of the UNAVAILABLE group. Pairs the historical statuslog.unavailable_time_ms.','Total time the agent spent in UNAVAILABLE-group states today.','Shrinkage (agent)'),
 ('MonAgentUnavailableDurationPct','Agent - Cumulative Unavailable Duration Percent','User','TotalStatusGroupPercent','UNAVAILABLE',NULL,NULL,'number','Agent',
  'Agent','active','Companions: % Available, % Break, % Paperwork, % Training, % Talk of login.','% Unavailable Time of Login','agent.percent','Cumulative UNAVAILABLE-group time divided by total login time.','Share of the agent''s login time spent in UNAVAILABLE-group states today.','Shrinkage % (agent)'),
 ('MonSumAgentsUnavailableDurationPercent','Agent Group - Percent of Agents in Unavailable State Group','UsersInteraction','UsersInStatusGroupDurationPercent','UNAVAILABLE','##0.00%',NULL,'number','Data',
  'AgentGroup','active','Per-agent counterpart: MonAgentUnavailableDurationPct.','% Time in Unavailable Group (group)','group.duration','Cumulative percentage for today: total UNAVAILABLE-group time divided by total logged-in time of the group.','Share of the group''s logged-in time spent in UNAVAILABLE-group states.','Shrinkage %')
ON CONFLICT ("MetricId") DO NOTHING;

SELECT "MetricId","MetricFunction","MetricParameter","MetricType" FROM "RTSGrid_Metric" WHERE "MetricParameter"='UNAVAILABLE' ORDER BY "MetricId";
