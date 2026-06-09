-- RTSGrid_Metric catalogue backfill
-- Generated from docs/metrics-catalog.json
-- Metrics: 202

BEGIN;

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Active Chats (agent)',
    "ShortDescription" = 'Number of chats the agent is handling right now.',
    "LongDescription" = 'Real-time count of chat interactions currently open at the agent (chat concurrency).',
    "Comparison" = 'Completed counterpart: MonAgentNumChatsCompleted.',
    "StandardKpi" = 'Chat concurrency (real-time)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentNumChatsActive';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Chats (agent)',
    "ShortDescription" = 'Number of incoming chats the agent answered and finished today.',
    "LongDescription" = 'Counts incoming chats answered by the agent that have already ended.',
    "Comparison" = 'Live counterpart: MonAgentNumChatsActive.',
    "StandardKpi" = 'Chat volume (agent)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentNumChatsCompleted';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Incoming Calls (agent)',
    "ShortDescription" = 'Number of incoming calls/callbacks the agent answered and finished today.',
    "LongDescription" = 'Counts incoming calls and callbacks answered by the agent that are already completed (talk ended). NOTE: the MetricId mentions "MakeCalls" for historical reasons — the metric actually counts INCOMING answered interactions.',
    "Comparison" = 'In-progress interactions are excluded until they end.',
    "StandardKpi" = 'Handled volume (agent)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = 'Misleading MetricId (historical).'
WHERE "MetricId" = 'MonAgentNumMakeCallsInCompleted';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Consultation Calls (agent)',
    "ShortDescription" = 'Number of consultation calls the agent made today.',
    "LongDescription" = 'Cumulative count of times the agent entered the "Consulting Call" state — consulting a colleague/expert during interaction handling.',
    "Comparison" = 'Frequent consults may indicate knowledge gaps or complex traffic.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentNumberOfConsultCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Long Calls > 10 min (agent)',
    "ShortDescription" = 'Number of incoming calls the agent handled with talk time over 10 minutes today.',
    "LongDescription" = 'Counts incoming external calls/callbacks whose talk time exceeded 600 seconds. Highlights unusually long conversations for coaching or complexity analysis.',
    "Comparison" = 'Opposite profile: MonAgentNumberOfInboundCalls15sec.',
    "StandardKpi" = 'Long-call indicator',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentNumberOfInboundCalls10Min';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Short Calls < 15 sec (agent)',
    "ShortDescription" = 'Number of incoming calls the agent handled with talk time under 15 seconds today.',
    "LongDescription" = 'Counts incoming external calls/callbacks whose talk time was below 15 seconds. A spike usually means premature disconnects or "call dumping" and is a standard quality red flag.',
    "Comparison" = 'Opposite profile: MonAgentNumberOfInboundCalls10Min (very long calls).',
    "StandardKpi" = 'Short-call indicator',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentNumberOfInboundCalls15sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming External Calls (agent) — DEFECT',
    "ShortDescription" = 'Intended: incoming external calls only. Actual: identical to the External+Internal metric (filter bug).',
    "LongDescription" = 'The description promises external calls only, but the stored filter also admits intercom calls, making this row an exact duplicate of MonAgentNumberOfInboundCallsWithIntercom. Recommended fix: remove CallType=="Intercom" from the filter so the metric matches its name.',
    "Comparison" = 'Until fixed, both metrics return the same value.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'duplicate',
    "CatalogNotes" = 'Exact duplicate of MonAgentNumberOfInboundCallsWithIntercom; fix filter (drop Intercom) or delete.'
WHERE "MetricId" = 'MonAgentNumberOfInboundCallsOnly';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming Calls — External + Internal (agent)',
    "ShortDescription" = 'Number of incoming calls and callbacks the agent received today, external and internal.',
    "LongDescription" = 'Counts incoming voice interactions (calls and callbacks) handled by the agent today, including both external and intercom (internal) calls.',
    "Comparison" = 'MonAgentNumberOfInboundCallsOnly currently has an IDENTICAL filter (duplicate) although its name promises external-only — see duplicate analysis.',
    "StandardKpi" = 'Inbound volume (agent)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentNumberOfInboundCallsWithIntercom';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Outbound Calls (agent)',
    "ShortDescription" = 'Number of outgoing external calls the agent made today.',
    "LongDescription" = 'Counts outgoing external voice calls initiated by the agent today.',
    "Comparison" = 'Group counterpart: MonSumAgentsMakeCalls. Average duration: MonAgentAverageMakeCallDuration.',
    "StandardKpi" = 'Outbound volume (agent)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentNumberOfMakeCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Outgoing Callbacks (agent)',
    "ShortDescription" = 'Number of callback return-calls the agent completed today.',
    "LongDescription" = 'Counts outgoing callback interactions (dial-backs to customers) made by the agent and answered today.',
    "Comparison" = 'Incoming side: MonAgentProxyCallsNum.',
    "StandardKpi" = 'Callback productivity',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentOutgoingCallbacksNum';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming Callbacks (agent)',
    "ShortDescription" = 'Number of incoming callback interactions the agent answered today.',
    "LongDescription" = 'Counts incoming callback interactions answered by the agent today (excluding the original callback requests themselves).',
    "Comparison" = 'Outgoing side: MonAgentOutgoingCallbacksNum.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentProxyCallsNum';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Calls per Hour (agent)',
    "ShortDescription" = 'Incoming calls handled by the agent per hour.',
    "LongDescription" = 'Agent-level throughput: incoming calls handled normalised per hour of work, computed by the engine CPH function.',
    "Comparison" = 'Queue counterpart: QueueCPH.',
    "StandardKpi" = 'Contacts per hour (agent)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'UserCPH';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Internal Calls (agent)',
    "ShortDescription" = 'Number of internal (intercom) calls involving the agent today.',
    "LongDescription" = 'Counts intercom interactions of the agent today, any direction. Internal communication load.',
    "Comparison" = NULL,
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'UserNumAllIntercom';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Missed Calls (agent)',
    "ShortDescription" = 'Number of times the agent missed a routed interaction today.',
    "LongDescription" = 'Cumulative count of times today the agent entered the "Missed Call" state — an interaction was routed to the agent and not answered. Discipline/availability indicator.',
    "Comparison" = 'Group real-time counterpart: MonSumAgentsInMissedCall.',
    "StandardKpi" = 'Missed routings',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.counters',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'UserNumMissedCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Avg First Response Time — messages (agent)',
    "ShortDescription" = 'Average time to the agent’s first reply in messaging conversations today.',
    "LongDescription" = 'Agent-level FRT: average time from conversation arrival to the agent’s first reply.',
    "Comparison" = 'Queue counterpart: MessagesAvgFirstResponseTime.',
    "StandardKpi" = 'FRT (agent)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'AgentMessagesAvgFirstResponseTime';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Avg Response Time — messages (agent)',
    "ShortDescription" = 'Average reply time of the agent to customer messages today.',
    "LongDescription" = 'Agent-level average time between a customer message and the agent’s reply (all replies).',
    "Comparison" = 'Queue counterpart: MessagesAvgResponseTime.',
    "StandardKpi" = 'Response time (agent)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'AgentMessagesAvgResponseTime';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Available State Duration',
    "ShortDescription" = 'Total time the agent spent in AVAILABLE-group states today.',
    "LongDescription" = 'Cumulative time today in statuses of the AVAILABLE group — idle-ready time waiting for interactions.',
    "Comparison" = 'Percent of login: MonAgentAvailableDurationPct.',
    "StandardKpi" = 'Idle/ready time',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentAvailableDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Dialer Call Duration (agent)',
    "ShortDescription" = 'Average duration of the agent’s dialer (campaign) calls today.',
    "LongDescription" = 'Average time per stay in the "Campaign Call" status today.',
    "Comparison" = 'Dialer volume: MonAgentNumberOfInboundCallsDialer.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentAverageAgentDialerDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Handling Duration (agent)',
    "ShortDescription" = 'Average duration of one ONPHONE engagement of the agent today.',
    "LongDescription" = 'Average time per stay in ONPHONE-group statuses today — a practical per-interaction handling-time proxy at agent level.',
    "Comparison" = 'Components: talk (MonAgentTalkDuration), hold (MonAgentHeldDuration), wrap-up (MonAgentWrapUpDuration).',
    "StandardKpi" = 'AHT (approx.)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentAverageCallDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Incoming Call Duration (agent)',
    "ShortDescription" = 'Average talk duration of incoming calls/callbacks completed by the agent today.',
    "LongDescription" = 'Average talk time of the agent’s completed incoming external calls and callbacks (interaction-based, excludes in-progress).',
    "Comparison" = 'Status-based handling average: MonAgentAverageCallDuration.',
    "StandardKpi" = 'ATT (agent)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentAverageInboundCallDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Outbound Call Duration (agent)',
    "ShortDescription" = 'Average duration of the agent’s outbound calls today.',
    "LongDescription" = 'Average time per stay in the "Out Ext Call" status today.',
    "Comparison" = 'Outbound count: MonAgentNumberOfMakeCalls.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentAverageMakeCallDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Cumulative Break Duration',
    "ShortDescription" = 'Total time the agent spent in BREAK-group states today.',
    "LongDescription" = 'Cumulative time today in break-type statuses (lunch, short break, etc.).',
    "Comparison" = 'Percent of login: MonAgentBreakDurationPct. Single-state alternative: see specific states.',
    "StandardKpi" = 'Shrinkage (agent)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentBreakDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Current Login Duration',
    "ShortDescription" = 'Time since the agent’s current login.',
    "LongDescription" = 'Duration of the agent’s current login session, ticking in real time.',
    "Comparison" = 'Cumulative counterpart: MonAgentLoginTime (all sessions today).',
    "StandardKpi" = 'Adherence support',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentCurrentLoginDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Cumulative Incoming Call Duration',
    "ShortDescription" = 'Total time the agent spent on incoming external calls today.',
    "LongDescription" = 'Cumulative time today in the "Incoming Ext Call" status — incoming-talk subset of total talk time.',
    "Comparison" = 'Total talk (all interaction types): MonAgentTalkDuration.',
    "StandardKpi" = 'Inbound talk time',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentDurationOfCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Current Incoming Call Duration',
    "ShortDescription" = 'Duration of the incoming external call the agent is handling right now.',
    "LongDescription" = 'Real-time duration of the agent’s current "Incoming Ext Call" status; zero/empty when not on an incoming external call.',
    "Comparison" = 'Group max: MonSumAgentsLongestCurrentCall.',
    "StandardKpi" = 'Live call timer',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentDurationOfCurrentCall';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Cumulative Hold Duration',
    "ShortDescription" = 'Total time the agent kept customers on hold today.',
    "LongDescription" = 'Cumulative time today in the "Hold" status. Hold time is an AHT component and a customer-experience irritant.',
    "Comparison" = 'AHT = talk + hold + wrap-up; see MonAgentTalkDuration and MonAgentWrapUpDuration.',
    "StandardKpi" = 'Hold time (AHT component)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentHeldDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Cumulative Login Duration',
    "ShortDescription" = 'Total logged-in time of the agent today (all sessions).',
    "LongDescription" = 'Sum of all the agent’s login sessions today. Denominator for all "percent of login time" metrics.',
    "Comparison" = 'Current session only: MonAgentCurrentLoginDuration.',
    "StandardKpi" = 'Staffed time',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentLoginTime';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Max Call Duration (agent)',
    "ShortDescription" = 'Longest talk time of a single incoming call of the agent today.',
    "LongDescription" = 'Maximum talk duration among the agent’s incoming external calls/callbacks today.',
    "Comparison" = 'Real-time current call: MonAgentDurationOfCurrentCall.',
    "StandardKpi" = 'Long-call indicator',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentMaxCallDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Cumulative Paperwork Duration',
    "ShortDescription" = 'Total time the agent spent in PAPERWORK-group states today.',
    "LongDescription" = 'Cumulative time today in after-call-work / back-office statuses (PAPERWORK group).',
    "Comparison" = 'Percent of login: MonAgentPaperworkDurationPct. Single Wrap Up state: MonAgentWrapUpDuration.',
    "StandardKpi" = 'ACW time',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentPaperworkDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Current Status Group Duration',
    "ShortDescription" = 'How long the agent has been in the current status GROUP.',
    "LongDescription" = 'Real-time duration of the agent’s stay in the current status group: switching between states inside one group (e.g. Lunch to Coffee Break) does not reset this timer.',
    "Comparison" = 'State-level timer: MonAgentStateDuration.',
    "StandardKpi" = 'Group timer',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentStateDescDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Current Status Duration',
    "ShortDescription" = 'How long the agent has been in the current status.',
    "LongDescription" = 'Real-time duration of the agent’s current status, whatever it is. Universal wallboard timer column.',
    "Comparison" = 'Group-level duration of current status group: MonAgentStateDescDuration.',
    "StandardKpi" = 'Status timer',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentStateDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Cumulative Talk Duration',
    "ShortDescription" = 'Total time the agent spent in ONPHONE-group states today.',
    "LongDescription" = 'Sum of all time today in statuses of the ONPHONE group — total customer-facing talk time.',
    "Comparison" = 'Percent of login: MonAgentTalkDurationPct. Per-call average: MonAgentAverageCallDuration.',
    "StandardKpi" = 'Talk time (occupancy input)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentTalkDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Active Interaction State Duration',
    "ShortDescription" = 'How long the agent’s longest active interaction has been in its current state.',
    "LongDescription" = 'Real-time duration of the current state (e.g. talking, hold) of the agent’s longest active interaction.',
    "Comparison" = 'Interaction state itself: MonAgentTelState.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentTelStateDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Cumulative Unavailable Duration',
    "ShortDescription" = 'Total time the agent spent in the "Unavailable" state today.',
    "LongDescription" = 'Cumulative time today in the specific "Unavailable" status.',
    "Comparison" = NULL,
    "StandardKpi" = 'Shrinkage (state)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentUnavailableStateDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Cumulative Wrap Up Duration',
    "ShortDescription" = 'Total time the agent spent in the "Wrap Up" state today.',
    "LongDescription" = 'Cumulative time today in the specific "Wrap Up" status (one state of the PAPERWORK group).',
    "Comparison" = 'Group-wide ACW: MonAgentPaperworkDuration.',
    "StandardKpi" = 'ACW (state)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentWrapUpDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Login Name',
    "ShortDescription" = 'Display/login name of the agent.',
    "LongDescription" = 'Static attribute used as the row label in Agent Grid widgets.',
    "Comparison" = NULL,
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'AgentLoginName';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Active Interaction Queue',
    "ShortDescription" = 'Queue (workgroup) name of the agent’s longest active interaction.',
    "LongDescription" = 'Real-time attribute: which queue the longest active interaction came from.',
    "Comparison" = NULL,
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonActiveCampaign';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Active Interaction ID',
    "ShortDescription" = 'Identifier of the agent’s longest active interaction.',
    "LongDescription" = 'Real-time attribute: the interaction ID of the agent’s longest currently-active interaction.',
    "Comparison" = 'Companions: type, state, queue, customer number of the same interaction.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentActiveInteractionId';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Current Login Time',
    "ShortDescription" = 'Timestamp of the agent’s current login.',
    "LongDescription" = 'Attribute: start time of the current login session.',
    "Comparison" = NULL,
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'defect-candidate',
    "CatalogNotes" = 'CONFIRMED dead (engine inventory 2026-06-05): MetricFunction ''CurLoginTimeStamp'' has no case in UserManager.cs (engine label ''CurLoginTimestamp'', case-sensitive switch). Fix: UPDATE MetricFunction to ''CurLoginTimestamp''.'
WHERE "MetricId" = 'MonAgentCurrentLoginTimeStamp';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Extension',
    "ShortDescription" = 'Telephony extension of the agent.',
    "LongDescription" = 'Static attribute: the agent’s extension number.',
    "Comparison" = NULL,
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentExtension';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'First Login Time',
    "ShortDescription" = 'Timestamp of the agent’s first login today.',
    "LongDescription" = 'Static-per-day attribute: when the agent first logged in today.',
    "Comparison" = 'Current session start: MonAgentCurrentLoginTimeStamp.',
    "StandardKpi" = 'Adherence support',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentFirstLoginTimeStamp';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Current Status',
    "ShortDescription" = 'Name of the agent’s current status.',
    "LongDescription" = 'Real-time text attribute: the title of the agent’s current Agent State (e.g. Available, Lunch, Wrap Up).',
    "Comparison" = 'Group name: MonAgentStateDesc. Timer: MonAgentStateDuration.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentState';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Current Status Group',
    "ShortDescription" = 'Status group of the agent’s current status.',
    "LongDescription" = 'Real-time text attribute: the status group (AVAILABLE / ONPHONE / BREAK / PAPERWORK / TRAINING) of the agent’s current state.',
    "Comparison" = 'State name: MonAgentState.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentStateDesc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Station ID',
    "ShortDescription" = 'Workstation/phone station identifier of the agent.',
    "LongDescription" = 'Static attribute: the station the agent is logged into.',
    "Comparison" = NULL,
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentStation';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Active Interaction State',
    "ShortDescription" = 'State of the agent’s longest active interaction.',
    "LongDescription" = 'Real-time attribute: current state (e.g. talking, hold) of the longest active interaction.',
    "Comparison" = 'Duration of that state: MonAgentTelStateDuration.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentTelState';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Logged In Today (flag)',
    "ShortDescription" = 'Flag/ID indicating the agent logged in today.',
    "LongDescription" = 'Technical attribute marking agents who connected during the current day. NOTE: its Description in the DB ("Change -ID of a representative...") lacks the standard "Agent -" prefix and needs normalisation.',
    "Comparison" = NULL,
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'defect-candidate',
    "CatalogNotes" = 'Description lacks category prefix; normalise to "Agent - ..." form.'
WHERE "MetricId" = 'MonAgentTodayLogin';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'User ID',
    "ShortDescription" = 'Platform user identifier of the agent.',
    "LongDescription" = 'Static attribute: the agent’s user ID on the CC platform.',
    "Comparison" = NULL,
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentUserId';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Active Interaction Type',
    "ShortDescription" = 'Type (Call/Chat/...) of the agent’s longest active interaction.',
    "LongDescription" = 'Real-time attribute: interaction type of the longest active interaction.',
    "Comparison" = NULL,
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonInteractionType';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Customer Phone Number',
    "ShortDescription" = 'Customer phone number of the agent’s longest active interaction.',
    "LongDescription" = 'Real-time attribute: remote-party number of the longest active interaction. PII — apply masking policies where required.',
    "Comparison" = NULL,
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.identity',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = 'PII field; consider masking in widgets.'
WHERE "MetricId" = 'RemotePhoneNumber';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Available Time of Login',
    "ShortDescription" = 'Share of the agent’s login time spent in AVAILABLE states today.',
    "LongDescription" = 'Cumulative AVAILABLE-group time divided by total login time — the idle-ready share.',
    "Comparison" = 'High % Available + low % Talk = under-utilisation; the inverse suggests overload.',
    "StandardKpi" = 'Availability share',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.percent',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentAvailableDurationPct';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Break Time of Login',
    "ShortDescription" = 'Share of the agent’s login time spent in BREAK states today.',
    "LongDescription" = 'Cumulative BREAK-group time divided by total login time — per-agent break shrinkage.',
    "Comparison" = 'Group counterpart: MonSumAgentsBreakDurationPercent.',
    "StandardKpi" = 'Shrinkage % (agent)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.percent',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentBreakDurationPct';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Paperwork Time of Login',
    "ShortDescription" = 'Share of the agent’s login time spent in PAPERWORK states today.',
    "LongDescription" = 'Cumulative PAPERWORK-group time divided by total login time — ACW share.',
    "Comparison" = 'Group counterpart: MonSumAgentsPaperworkDurationPercent.',
    "StandardKpi" = 'ACW % (agent)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.percent',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentPaperworkDurationPct';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Talk Time of Login',
    "ShortDescription" = 'Share of the agent’s login time spent in ONPHONE states today.',
    "LongDescription" = 'Cumulative ONPHONE-group time divided by total login time. Practical per-agent occupancy proxy (talk-based; excludes wrap-up).',
    "Comparison" = 'Companions: % Available, % Break, % Paperwork, % Training.',
    "StandardKpi" = 'Occupancy (proxy)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.percent',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentTalkDurationPct';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Training Time of Login',
    "ShortDescription" = 'Share of the agent’s login time spent in TRAINING states today.',
    "LongDescription" = 'Cumulative TRAINING-group time divided by total login time.',
    "Comparison" = NULL,
    "StandardKpi" = 'Training shrinkage %',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Agent',
    "Family" = 'agent.percent',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonAgentTrainingDurationPct';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Max Current Break Duration (group)',
    "ShortDescription" = 'Longest time any agent of the group has currently been in a Break-group state.',
    "LongDescription" = 'Real-time maximum: among agents currently in a BREAK-group state, the duration of the longest ongoing break. Highlights overstayed breaks on wallboards.',
    "Comparison" = 'Percent counterpart: MonSumAgentsBreakDurationPercent.',
    "StandardKpi" = 'Break overrun (real-time)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonSumAgentsBreakDurationMax';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Time in Break Group (group)',
    "ShortDescription" = 'Share of the group’s logged-in time spent in Break-group states.',
    "LongDescription" = 'Cumulative percentage for today: total time agents of the Business Unit spent in BREAK-group states divided by their total logged-in time. Core shrinkage indicator.',
    "Comparison" = 'Per-agent counterpart: MonAgentBreakDurationPct.',
    "StandardKpi" = 'Shrinkage %',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonSumAgentsBreakDurationPercent';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Time in Paperwork Group (group)',
    "ShortDescription" = 'Share of the group’s logged-in time spent in Paperwork-group states.',
    "LongDescription" = 'Cumulative percentage for today: total PAPERWORK-group time divided by total logged-in time of the group. Measures ACW/back-office load.',
    "Comparison" = 'Per-agent counterpart: MonAgentPaperworkDurationPct.',
    "StandardKpi" = 'ACW %',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.duration',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonSumAgentsPaperworkDurationPercent';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Dialer Calls',
    "ShortDescription" = 'Number of incoming dialer (campaign) interactions today.',
    "LongDescription" = 'Counts dialer-type interactions (outbound-campaign calls delivered to agents as incoming) registered today, external or intercom. NOTE: description prefix says "Agent Group" while DataType is "User"; the engine resolves the non-"UsersInteraction" DataType to the queue interaction set, so this behaves as a queue-scope counter.',
    "Comparison" = 'Average duration counterpart: MonAgentAverageAgentDialerDuration.',
    "StandardKpi" = 'Dialer volume',
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.interactions',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'defect-candidate',
    "CatalogNotes" = 'Category/DataType inconsistency — review and normalise.'
WHERE "MetricId" = 'MonAgentNumberOfInboundCallsDialer';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Calls + Callbacks (group)',
    "ShortDescription" = 'Number of incoming calls and callbacks answered and completed by agents of this group today.',
    "LongDescription" = 'Counts incoming external calls and callbacks that agents of the Business Unit answered and have already finished (talk ended, no longer in queue). Computed over the agent-group interaction set (UsersInteraction).',
    "Comparison" = 'Queue-side near-equivalent: QueueNumAnsweredCallsAndCallbacks (counts on answer, includes in-progress).',
    "StandardKpi" = 'Handled volume (group)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.interactions',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonSumAgentsAnsweredCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Avg Talk Duration — Calls+Callbacks (group)',
    "ShortDescription" = 'Average talk duration of incoming calls and callbacks completed by this group today.',
    "LongDescription" = 'Average conversation time of incoming external calls and callbacks finished today by agents of the Business Unit, computed over the agent-group interaction set.',
    "Comparison" = 'Queue-side counterpart: QueueAvgTalkingDurationCallsAndCallbacks.',
    "StandardKpi" = 'ATT (group)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.interactions',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonSumAgentsAverageCallDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Avg Talk Duration — Chats (group)',
    "ShortDescription" = 'Average handling duration of incoming chats completed by this group today.',
    "LongDescription" = 'Average chat-handling time of incoming chats finished today by agents of the Business Unit (agent-group interaction set).',
    "Comparison" = 'Queue-side counterpart: QueueAvgTalkingDurationChats.',
    "StandardKpi" = 'Chat ATT (group)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.interactions',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonSumAgentsAverageChatDuration';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Longest Current Call (group)',
    "ShortDescription" = 'Duration of the longest interaction currently being handled by an agent of this group.',
    "LongDescription" = 'Real-time maximum talk duration among interactions currently in progress within the Business Unit. Flags conversations running unusually long.',
    "Comparison" = 'Per-agent counterpart: MonAgentDurationOfCurrentCall.',
    "StandardKpi" = 'Long-call alarm (real-time)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.interactions',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonSumAgentsLongestCurrentCall';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Outbound Calls (group)',
    "ShortDescription" = 'Number of outgoing external interactions made by agents of this group today.',
    "LongDescription" = 'Counts outgoing external interactions initiated by agents of the Business Unit today (computed over the agent-group interaction set).',
    "Comparison" = 'Queue-side counterpart: QueueNumOutboundCalls. Per-agent: MonAgentNumberOfMakeCalls.',
    "StandardKpi" = 'Outbound volume (group)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.interactions',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonSumAgentsMakeCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents in "Missed Call" State',
    "ShortDescription" = 'Number of agents currently in the "Missed Call" state.',
    "LongDescription" = 'Real-time count of agents whose current state is "Missed Call" — the state an agent enters after failing to answer a routed interaction. Persistent non-zero values signal routing or discipline issues.',
    "Comparison" = 'Per-agent cumulative counterpart: UserNumMissedCalls.',
    "StandardKpi" = 'Missed-routing indicator',
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.state_count',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MonSumAgentsInMissedCall';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents in "Available" State',
    "ShortDescription" = 'Number of agents currently in the specific "Available" Agent State.',
    "LongDescription" = 'Real-time count of agents whose current Agent State is exactly "Available". Counts the raw platform state, not the status group: custom states mapped to the AVAILABLE group (e.g. "Ready-Chat") are NOT included.',
    "Comparison" = 'Group-level counterpart: QueueLoginDataNumAvailableUsers.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.state_count',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'StateCountAvailable';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents in "Break" State',
    "ShortDescription" = 'Number of agents currently in the specific "Break" Agent State.',
    "LongDescription" = 'Real-time count of agents whose current Agent State is exactly "Break". States like "Lunch" or "Coffee Break" are not included even though they belong to the BREAK group.',
    "Comparison" = 'Group-level counterpart: QueueLoginDataNumBreakUsers.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.state_count',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'StateCountBreak';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents in "On Phone" State',
    "ShortDescription" = 'Number of agents currently in the specific "On Phone" Agent State.',
    "LongDescription" = 'Real-time count of agents whose current Agent State is exactly "On Phone" (raw state, not the ONPHONE group).',
    "Comparison" = 'Group-level counterpart: UsersSumOnCall.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.state_count',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'StateCountOnPhone';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents in "Paperwork" State',
    "ShortDescription" = 'Number of agents currently in the specific "Paperwork" Agent State.',
    "LongDescription" = 'Real-time count of agents whose current Agent State is exactly "Paperwork" (raw state, not the PAPERWORK group).',
    "Comparison" = 'Group-level counterpart: QueueLoginDataNumPaperworkUsers.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.state_count',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'StateCountPaperwork';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents in "Training" State',
    "ShortDescription" = 'Number of agents currently in the specific "Training" Agent State.',
    "LongDescription" = 'Real-time count of agents whose current Agent State is exactly "Training" (raw state, not the TRAINING group).',
    "Comparison" = 'Group-level counterpart: QueueLoginDataNumTrainingUsers.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.state_count',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'StateCountTraining';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents Available (group)',
    "ShortDescription" = 'Number of agents currently in the AVAILABLE status group.',
    "LongDescription" = 'Real-time count of agents of the Business Unit whose current status belongs to the AVAILABLE status group (ready to take an interaction).',
    "Comparison" = 'StateCountAvailable counts the specific "Available" Agent State only; this metric counts the whole group.',
    "StandardKpi" = 'Available agents (real-time)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.state_group_count',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueLoginDataNumAvailableUsers';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents in Break Group',
    "ShortDescription" = 'Number of agents currently in any Break-group state.',
    "LongDescription" = 'Real-time count of agents whose current status belongs to the BREAK status group (lunch, short break, coffee break etc.).',
    "Comparison" = 'StateCountBreak counts only the specific "Break" state; this metric covers all break-type states.',
    "StandardKpi" = 'Shrinkage (real-time)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.state_group_count',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueLoginDataNumBreakUsers';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents Logged In',
    "ShortDescription" = 'Number of agents of the Business Unit currently logged in.',
    "LongDescription" = 'Real-time count of agents currently signed into the platform within this Business Unit, in any status. Baseline for staffing and occupancy assessment.',
    "Comparison" = 'QueueNumberOfLoggedAgents is its (deprecated) duplicate. Available/Break/Paperwork counts are subsets.',
    "StandardKpi" = 'Staffed agents (real-time)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.state_group_count',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueLoginDataNumLoggedUsers';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents in Paperwork Group',
    "ShortDescription" = 'Number of agents currently in any Paperwork-group state (ACW/back-office).',
    "LongDescription" = 'Real-time count of agents whose current status belongs to the PAPERWORK status group (after-call work, administrative tasks).',
    "Comparison" = 'QueueNumWrapUpAgents counts the single "Wrap Up" state only.',
    "StandardKpi" = 'ACW staffing',
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.state_group_count',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueLoginDataNumPaperworkUsers';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents in Training Group',
    "ShortDescription" = 'Number of agents currently in any Training-group state.',
    "LongDescription" = 'Real-time count of agents whose current status belongs to the TRAINING status group. NOTE: this row carries an anomalous DataType ("String" instead of "UsersSummary") and empty default columns — harmless to the engine (DataType is ignored for status counters) but should be normalised.',
    "Comparison" = 'StateCountTraining counts the specific "Training" state only.',
    "StandardKpi" = 'Shrinkage (training)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.state_group_count',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'defect-candidate',
    "CatalogNotes" = 'DataType="String" anomaly; normalise to UsersSummary.'
WHERE "MetricId" = 'QueueLoginDataNumTrainingUsers';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents On Call',
    "ShortDescription" = 'Number of agents currently in the ONPHONE status group (handling an interaction).',
    "LongDescription" = 'Real-time count of agents whose current status belongs to the ONPHONE group — actively handling customer interactions.',
    "Comparison" = 'QueueNumOnCallAgents is its (deprecated) duplicate. StateCountOnPhone counts the specific state only.',
    "StandardKpi" = 'Agents on contact (real-time)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'AgentGroup',
    "Family" = 'group.state_group_count',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'UsersSumOnCall';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Time to Abandon — Callbacks',
    "ShortDescription" = 'Average time callback interactions (customer-requested return calls handled by the queue) waited in queue before being abandoned today.',
    "LongDescription" = 'Average queue time of abandoned callback interactions (customer-requested return calls handled by the queue): how long customers were prepared to wait before giving up. Useful for setting realistic Service Level targets — if customers abandon at 40 seconds, a 60-second target is too slow.',
    "Comparison" = 'Subset of ''Average Wait Time'' restricted to abandoned interactions.',
    "StandardKpi" = 'Average time to abandon (ATA)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.abandon.time_avg',
    "Channel" = 'callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgTimeToAbandCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Time to Abandon — Calls',
    "ShortDescription" = 'Average time external incoming voice calls waited in queue before being abandoned today.',
    "LongDescription" = 'Average queue time of abandoned external incoming voice calls: how long customers were prepared to wait before giving up. Useful for setting realistic Service Level targets — if customers abandon at 40 seconds, a 60-second target is too slow.',
    "Comparison" = 'Subset of ''Average Wait Time'' restricted to abandoned interactions.',
    "StandardKpi" = 'Average time to abandon (ATA)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.abandon.time_avg',
    "Channel" = 'calls',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgTimeToAbandCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Time to Abandon — Calls + Callbacks',
    "ShortDescription" = 'Average time combined voice load: external incoming calls and callbacks waited in queue before being abandoned today.',
    "LongDescription" = 'Average queue time of abandoned combined voice load: external incoming calls and callbacks: how long customers were prepared to wait before giving up. Useful for setting realistic Service Level targets — if customers abandon at 40 seconds, a 60-second target is too slow.',
    "Comparison" = 'Subset of ''Average Wait Time'' restricted to abandoned interactions.',
    "StandardKpi" = 'Average time to abandon (ATA)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.abandon.time_avg',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgTimeToAbandCallsAndCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Time to Abandon — Chats',
    "ShortDescription" = 'Average time incoming chat interactions waited in queue before being abandoned today.',
    "LongDescription" = 'Average queue time of abandoned incoming chat interactions: how long customers were prepared to wait before giving up. Useful for setting realistic Service Level targets — if customers abandon at 40 seconds, a 60-second target is too slow.',
    "Comparison" = 'Subset of ''Average Wait Time'' restricted to abandoned interactions.',
    "StandardKpi" = 'Average time to abandon (ATA)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.abandon.time_avg',
    "Channel" = 'chats',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgTimeToAbandChats';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Time to Abandon — Digital Interactions',
    "ShortDescription" = 'Average time non-voice digital interactions (chat and e-mail) waited in queue before being abandoned today.',
    "LongDescription" = 'Average queue time of abandoned non-voice digital interactions (chat and e-mail): how long customers were prepared to wait before giving up. Useful for setting realistic Service Level targets — if customers abandon at 40 seconds, a 60-second target is too slow.',
    "Comparison" = 'Subset of ''Average Wait Time'' restricted to abandoned interactions.',
    "StandardKpi" = 'Average time to abandon (ATA)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.abandon.time_avg',
    "Channel" = 'digital',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgTimeToAbandInteractions';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Avg First Response Time (messages)',
    "ShortDescription" = 'Average time to the first agent reply in messaging channels today.',
    "LongDescription" = 'Average time between message arrival and the first agent response. The key responsiveness KPI (FRT) for chat/messaging channels.',
    "Comparison" = 'MessagesAvgResponseTime covers ALL replies, not only the first one.',
    "StandardKpi" = 'First Response Time (FRT)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.messages',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MessagesAvgFirstResponseTime';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Avg Response Time (messages)',
    "ShortDescription" = 'Average agent response time to customer messages today (all replies).',
    "LongDescription" = 'Average time between any customer message and the following agent reply. Measures sustained conversation responsiveness, not only the first touch.',
    "Comparison" = 'MessagesAvgFirstResponseTime isolates the first reply.',
    "StandardKpi" = 'Response time',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.messages',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MessagesAvgResponseTime';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Max First Response Time (messages)',
    "ShortDescription" = 'Longest first-response time to an incoming message today.',
    "LongDescription" = 'The maximum time customers waited today for the FIRST agent reply in messaging channels. Worst-case indicator of digital responsiveness.',
    "Comparison" = 'Average counterpart: MessagesAvgFirstResponseTime.',
    "StandardKpi" = 'First Response Time (max)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.messages',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'MessagesMaxFirstResponseTime';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Abandoned Callbacks',
    "ShortDescription" = 'Share of incoming callback interactions (customer-requested return calls handled by the queue) abandoned in queue, out of all that finished queuing today.',
    "LongDescription" = 'Abandoned callback interactions (customer-requested return calls handled by the queue) divided by incoming completed callback interactions (customer-requested return calls handled by the queue). The standard Abandonment Rate KPI: a direct measure of customers lost in the queue. Callback requests are not counted as abandoned.',
    "Comparison" = 'Complementary to ''% Answered''.',
    "StandardKpi" = 'Abandonment rate',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.abandoned_total',
    "Channel" = 'callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAbandonedCallbacksTotal';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Abandoned Calls',
    "ShortDescription" = 'Share of incoming external incoming voice calls abandoned in queue, out of all that finished queuing today.',
    "LongDescription" = 'Abandoned external incoming voice calls divided by incoming completed external incoming voice calls. The standard Abandonment Rate KPI: a direct measure of customers lost in the queue. Callback requests are not counted as abandoned.',
    "Comparison" = 'Complementary to ''% Answered''.',
    "StandardKpi" = 'Abandonment rate',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.abandoned_total',
    "Channel" = 'calls',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAbandonedCallsTotal';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Abandoned Calls + Callbacks',
    "ShortDescription" = 'Share of incoming combined voice load: external incoming calls and callbacks abandoned in queue, out of all that finished queuing today.',
    "LongDescription" = 'Abandoned combined voice load: external incoming calls and callbacks divided by incoming completed combined voice load: external incoming calls and callbacks. The standard Abandonment Rate KPI: a direct measure of customers lost in the queue. Callback requests are not counted as abandoned.',
    "Comparison" = 'Complementary to ''% Answered''.',
    "StandardKpi" = 'Abandonment rate',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.abandoned_total',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAbandonedCallsAndCallbacksTotal';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Abandoned Chats',
    "ShortDescription" = 'Share of incoming incoming chat interactions abandoned in queue, out of all that finished queuing today.',
    "LongDescription" = 'Abandoned incoming chat interactions divided by incoming completed incoming chat interactions. The standard Abandonment Rate KPI: a direct measure of customers lost in the queue. Callback requests are not counted as abandoned.',
    "Comparison" = 'Complementary to ''% Answered''.',
    "StandardKpi" = 'Abandonment rate',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.abandoned_total',
    "Channel" = 'chats',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAbandonedChatsTotal';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Abandoned Digital Interactions',
    "ShortDescription" = 'Share of incoming non-voice digital interactions (chat and e-mail) abandoned in queue, out of all that finished queuing today.',
    "LongDescription" = 'Abandoned non-voice digital interactions (chat and e-mail) divided by incoming completed non-voice digital interactions (chat and e-mail). The standard Abandonment Rate KPI: a direct measure of customers lost in the queue. Callback requests are not counted as abandoned.',
    "Comparison" = 'Complementary to ''% Answered''.',
    "StandardKpi" = 'Abandonment rate',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.abandoned_total',
    "Channel" = 'digital',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAbandonedInteractionsTotal';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Callbacks in 30 sec (of answered)',
    "ShortDescription" = 'Share of answered callback interactions (customer-requested return calls handled by the queue) that were picked up within 30 seconds.',
    "LongDescription" = 'Answered-in-30-seconds callback interactions (customer-requested return calls handled by the queue) divided by all answered callback interactions (customer-requested return calls handled by the queue). Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'callbacks',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallbacks30secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Callbacks in 60 sec (of answered)',
    "ShortDescription" = 'Share of answered callback interactions (customer-requested return calls handled by the queue) that were picked up within 60 seconds.',
    "LongDescription" = 'Answered-in-60-seconds callback interactions (customer-requested return calls handled by the queue) divided by all answered callback interactions (customer-requested return calls handled by the queue). Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'callbacks',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallbacks60secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Callbacks in 120 sec (of answered)',
    "ShortDescription" = 'Share of answered callback interactions (customer-requested return calls handled by the queue) that were picked up within 120 seconds.',
    "LongDescription" = 'Answered-in-120-seconds callback interactions (customer-requested return calls handled by the queue) divided by all answered callback interactions (customer-requested return calls handled by the queue). Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'callbacks',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallbacks120secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls in 30 sec (of answered)',
    "ShortDescription" = 'Share of answered external incoming voice calls that were picked up within 30 seconds.',
    "LongDescription" = 'Answered-in-30-seconds external incoming voice calls divided by all answered external incoming voice calls. Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'calls',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCalls30secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls in 60 sec (of answered)',
    "ShortDescription" = 'Share of answered external incoming voice calls that were picked up within 60 seconds.',
    "LongDescription" = 'Answered-in-60-seconds external incoming voice calls divided by all answered external incoming voice calls. Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'calls',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCalls60secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls in 120 sec (of answered)',
    "ShortDescription" = 'Share of answered external incoming voice calls that were picked up within 120 seconds.',
    "LongDescription" = 'Answered-in-120-seconds external incoming voice calls divided by all answered external incoming voice calls. Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'calls',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCalls120secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls + Callbacks in 30 sec (of answered)',
    "ShortDescription" = 'Share of answered combined voice load: external incoming calls and callbacks that were picked up within 30 seconds.',
    "LongDescription" = 'Answered-in-30-seconds combined voice load: external incoming calls and callbacks divided by all answered combined voice load: external incoming calls and callbacks. Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallsAndCallbacks30secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls + Callbacks in 60 sec (of answered)',
    "ShortDescription" = 'Share of answered combined voice load: external incoming calls and callbacks that were picked up within 60 seconds.',
    "LongDescription" = 'Answered-in-60-seconds combined voice load: external incoming calls and callbacks divided by all answered combined voice load: external incoming calls and callbacks. Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallsAndCallbacks60secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls + Callbacks in 120 sec (of answered)',
    "ShortDescription" = 'Share of answered combined voice load: external incoming calls and callbacks that were picked up within 120 seconds.',
    "LongDescription" = 'Answered-in-120-seconds combined voice load: external incoming calls and callbacks divided by all answered combined voice load: external incoming calls and callbacks. Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallsAndCallbacks120secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Chats in 30 sec (of answered)',
    "ShortDescription" = 'Share of answered incoming chat interactions that were picked up within 30 seconds.',
    "LongDescription" = 'Answered-in-30-seconds incoming chat interactions divided by all answered incoming chat interactions. Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'chats',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredChats30secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Chats in 60 sec (of answered)',
    "ShortDescription" = 'Share of answered incoming chat interactions that were picked up within 60 seconds.',
    "LongDescription" = 'Answered-in-60-seconds incoming chat interactions divided by all answered incoming chat interactions. Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'chats',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredChats60secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Chats in 120 sec (of answered)',
    "ShortDescription" = 'Share of answered incoming chat interactions that were picked up within 120 seconds.',
    "LongDescription" = 'Answered-in-120-seconds incoming chat interactions divided by all answered incoming chat interactions. Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'chats',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredChats120secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Digital Interactions in 30 sec (of answered)',
    "ShortDescription" = 'Share of answered non-voice digital interactions (chat and e-mail) that were picked up within 30 seconds.',
    "LongDescription" = 'Answered-in-30-seconds non-voice digital interactions (chat and e-mail) divided by all answered non-voice digital interactions (chat and e-mail). Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'digital',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredInteractions30secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Digital Interactions in 60 sec (of answered)',
    "ShortDescription" = 'Share of answered non-voice digital interactions (chat and e-mail) that were picked up within 60 seconds.',
    "LongDescription" = 'Answered-in-60-seconds non-voice digital interactions (chat and e-mail) divided by all answered non-voice digital interactions (chat and e-mail). Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'digital',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredInteractions60secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Digital Interactions in 120 sec (of answered)',
    "ShortDescription" = 'Share of answered non-voice digital interactions (chat and e-mail) that were picked up within 120 seconds.',
    "LongDescription" = 'Answered-in-120-seconds non-voice digital interactions (chat and e-mail) divided by all answered non-voice digital interactions (chat and e-mail). Measures the speed profile of answered traffic only: of the contacts agents did answer, how many were answered quickly. Abandoned contacts are ignored entirely.',
    "Comparison" = 'Always ≥ the ''…of incoming'' (Service Level) variant. Use the ''of incoming'' variant for SLA reporting; use this one to analyse answering speed.',
    "StandardKpi" = 'Speed-of-answer profile',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_ans',
    "Channel" = 'digital',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredInteractions120secAns';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Callbacks in 30 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed callback interactions (customer-requested return calls handled by the queue) answered within 30 seconds — the Service Level (TSF) with a 30-second target.',
    "LongDescription" = 'Answered-in-30-seconds callback interactions (customer-requested return calls handled by the queue) divided by incoming completed callback interactions (customer-requested return calls handled by the queue). This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 30 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'callbacks',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallbacks30secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Callbacks in 60 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed callback interactions (customer-requested return calls handled by the queue) answered within 60 seconds — the Service Level (TSF) with a 60-second target.',
    "LongDescription" = 'Answered-in-60-seconds callback interactions (customer-requested return calls handled by the queue) divided by incoming completed callback interactions (customer-requested return calls handled by the queue). This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 60 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'callbacks',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallbacks60secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Callbacks in 120 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed callback interactions (customer-requested return calls handled by the queue) answered within 120 seconds — the Service Level (TSF) with a 120-second target.',
    "LongDescription" = 'Answered-in-120-seconds callback interactions (customer-requested return calls handled by the queue) divided by incoming completed callback interactions (customer-requested return calls handled by the queue). This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 120 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'callbacks',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallbacks120secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls in 30 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed external incoming voice calls answered within 30 seconds — the Service Level (TSF) with a 30-second target.',
    "LongDescription" = 'Answered-in-30-seconds external incoming voice calls divided by incoming completed external incoming voice calls. This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 30 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'calls',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCalls30secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls in 60 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed external incoming voice calls answered within 60 seconds — the Service Level (TSF) with a 60-second target.',
    "LongDescription" = 'Answered-in-60-seconds external incoming voice calls divided by incoming completed external incoming voice calls. This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 60 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'calls',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCalls60secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls in 120 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed external incoming voice calls answered within 120 seconds — the Service Level (TSF) with a 120-second target.',
    "LongDescription" = 'Answered-in-120-seconds external incoming voice calls divided by incoming completed external incoming voice calls. This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 120 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'calls',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCalls120secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls in 360 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed external incoming voice calls answered within 360 seconds — the Service Level (TSF) with a 360-second target.',
    "LongDescription" = 'Answered-in-360-seconds external incoming voice calls divided by incoming completed external incoming voice calls. This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 360 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'calls',
    "ThresholdSec" = 360,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCalls360secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls + Callbacks in 30 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed combined voice load: external incoming calls and callbacks answered within 30 seconds — the Service Level (TSF) with a 30-second target.',
    "LongDescription" = 'Answered-in-30-seconds combined voice load: external incoming calls and callbacks divided by incoming completed combined voice load: external incoming calls and callbacks. This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 30 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallsAndCallbacks30secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls + Callbacks in 60 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed combined voice load: external incoming calls and callbacks answered within 60 seconds — the Service Level (TSF) with a 60-second target.',
    "LongDescription" = 'Answered-in-60-seconds combined voice load: external incoming calls and callbacks divided by incoming completed combined voice load: external incoming calls and callbacks. This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 60 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallsAndCallbacks60secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls + Callbacks in 120 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed combined voice load: external incoming calls and callbacks answered within 120 seconds — the Service Level (TSF) with a 120-second target.',
    "LongDescription" = 'Answered-in-120-seconds combined voice load: external incoming calls and callbacks divided by incoming completed combined voice load: external incoming calls and callbacks. This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 120 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallsAndCallbacks120secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Chats in 30 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed incoming chat interactions answered within 30 seconds — the Service Level (TSF) with a 30-second target.',
    "LongDescription" = 'Answered-in-30-seconds incoming chat interactions divided by incoming completed incoming chat interactions. This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 30 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'chats',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredChats30secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Chats in 60 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed incoming chat interactions answered within 60 seconds — the Service Level (TSF) with a 60-second target.',
    "LongDescription" = 'Answered-in-60-seconds incoming chat interactions divided by incoming completed incoming chat interactions. This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 60 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'chats',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredChats60secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Chats in 120 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed incoming chat interactions answered within 120 seconds — the Service Level (TSF) with a 120-second target.',
    "LongDescription" = 'Answered-in-120-seconds incoming chat interactions divided by incoming completed incoming chat interactions. This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 120 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'chats',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredChats120secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Digital Interactions in 30 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed non-voice digital interactions (chat and e-mail) answered within 30 seconds — the Service Level (TSF) with a 30-second target.',
    "LongDescription" = 'Answered-in-30-seconds non-voice digital interactions (chat and e-mail) divided by incoming completed non-voice digital interactions (chat and e-mail). This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 30 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'digital',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredInteractions30secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Digital Interactions in 60 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed non-voice digital interactions (chat and e-mail) answered within 60 seconds — the Service Level (TSF) with a 60-second target.',
    "LongDescription" = 'Answered-in-60-seconds non-voice digital interactions (chat and e-mail) divided by incoming completed non-voice digital interactions (chat and e-mail). This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 60 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'digital',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredInteractions60secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Digital Interactions in 120 sec (of incoming)',
    "ShortDescription" = 'Share of incoming completed non-voice digital interactions (chat and e-mail) answered within 120 seconds — the Service Level (TSF) with a 120-second target.',
    "LongDescription" = 'Answered-in-120-seconds non-voice digital interactions (chat and e-mail) divided by incoming completed non-voice digital interactions (chat and e-mail). This is the industry Service Level / Telephone Service Factor: ''X% of contacts answered within 120 seconds''. Abandoned contacts stay in the denominator and therefore lower the result.',
    "Comparison" = 'The ''…of answered'' variant uses only answered contacts as denominator and is always higher or equal; it measures answering speed, not service accessibility.',
    "StandardKpi" = 'Service Level (TSF)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_threshold_inc',
    "Channel" = 'digital',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredInteractions120secInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Callbacks',
    "ShortDescription" = 'Share of incoming callback interactions (customer-requested return calls handled by the queue) that were answered, out of all that finished queuing today.',
    "LongDescription" = 'Answered callback interactions (customer-requested return calls handled by the queue) divided by incoming completed callback interactions (customer-requested return calls handled by the queue) (answered + abandoned, waiting excluded). Shown as a percentage. This is the classic Answer Rate of the queue.',
    "Comparison" = 'Complementary to ''% Abandoned''. Differs from ''Base Answered Percent'', which divides by ALL incoming including still-waiting items.',
    "StandardKpi" = 'Answer rate',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_total',
    "Channel" = 'callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallbacksTotal';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls',
    "ShortDescription" = 'Share of incoming external incoming voice calls that were answered, out of all that finished queuing today.',
    "LongDescription" = 'Answered external incoming voice calls divided by incoming completed external incoming voice calls (answered + abandoned, waiting excluded). Shown as a percentage. This is the classic Answer Rate of the queue.',
    "Comparison" = 'Complementary to ''% Abandoned''. Differs from ''Base Answered Percent'', which divides by ALL incoming including still-waiting items.',
    "StandardKpi" = 'Answer rate',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_total',
    "Channel" = 'calls',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallsTotal';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls + Callbacks',
    "ShortDescription" = 'Share of incoming combined voice load: external incoming calls and callbacks that were answered, out of all that finished queuing today.',
    "LongDescription" = 'Answered combined voice load: external incoming calls and callbacks divided by incoming completed combined voice load: external incoming calls and callbacks (answered + abandoned, waiting excluded). Shown as a percentage. This is the classic Answer Rate of the queue.',
    "Comparison" = 'Complementary to ''% Abandoned''. Differs from ''Base Answered Percent'', which divides by ALL incoming including still-waiting items.',
    "StandardKpi" = 'Answer rate',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_total',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredCallsAndCallbacksTotal';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Chats',
    "ShortDescription" = 'Share of incoming incoming chat interactions that were answered, out of all that finished queuing today.',
    "LongDescription" = 'Answered incoming chat interactions divided by incoming completed incoming chat interactions (answered + abandoned, waiting excluded). Shown as a percentage. This is the classic Answer Rate of the queue.',
    "Comparison" = 'Complementary to ''% Abandoned''. Differs from ''Base Answered Percent'', which divides by ALL incoming including still-waiting items.',
    "StandardKpi" = 'Answer rate',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_total',
    "Channel" = 'chats',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredChatsTotal';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Digital Interactions',
    "ShortDescription" = 'Share of incoming non-voice digital interactions (chat and e-mail) that were answered, out of all that finished queuing today.',
    "LongDescription" = 'Answered non-voice digital interactions (chat and e-mail) divided by incoming completed non-voice digital interactions (chat and e-mail) (answered + abandoned, waiting excluded). Shown as a percentage. This is the classic Answer Rate of the queue.',
    "Comparison" = 'Complementary to ''% Abandoned''. Differs from ''Base Answered Percent'', which divides by ALL incoming including still-waiting items.',
    "StandardKpi" = 'Answer rate',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.answered_total',
    "Channel" = 'digital',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueuePctAnsweredInteractionsTotal';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Base Answered % (of all incoming)',
    "ShortDescription" = 'Answered calls divided by ALL incoming calls today, including those still waiting.',
    "LongDescription" = 'Unlike "% Answered Calls" (denominator = completed only), this variant divides answered calls by the full incoming volume including calls still in queue. During busy periods the value is "pessimistic": waiting calls already count against the queue.',
    "Comparison" = 'Use % Answered Calls for end-of-day reporting; Base Answered % reacts faster intraday.',
    "StandardKpi" = 'Answer rate (gross denominator)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.special',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueBaseAnsweredPct';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered % excl. Callback Requests',
    "ShortDescription" = 'Answered calls divided by incoming calls minus callback requests.',
    "LongDescription" = 'Removes callback requests from the denominator: customers who chose a callback are not counted against the answer rate. Shows queue performance for customers who actually stayed in the queue. Note: denominator is incoming-online (includes waiting).',
    "Comparison" = 'Compare with Base Answered % (callback requests kept in denominator) and "Answered % incl. Callback Requests" (requests counted as success).',
    "StandardKpi" = 'Answer rate variant',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.special',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueExclCallbackReqAnsweredPct';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered % incl. Callback Requests',
    "ShortDescription" = 'Answered calls plus callback requests, divided by all incoming calls.',
    "LongDescription" = 'Treats a callback request as a positive outcome: numerator = answered + callback requests. The most "optimistic" answer-rate variant — useful when callback is promoted as a legitimate service path.',
    "Comparison" = 'Compare with the Excl. variant (requests removed from both sides) and Base Answered % (requests ignored in numerator).',
    "StandardKpi" = 'Answer rate variant',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.special',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueInclCallbackReqAnsweredPct';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered % incl. Completed Callbacks',
    "ShortDescription" = 'Answered calls plus completed callbacks, divided by all incoming calls.',
    "LongDescription" = 'Counts a callback as success only when it was actually completed (customer reached on dial-back), unlike the "incl. Callback Requests" variant which credits the request itself.',
    "Comparison" = 'Stricter than Incl. Callback Requests; usually between the Base and Incl-Requests values.',
    "StandardKpi" = 'Answer rate variant',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.special',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueInclCompCallbacksAnsweredPct';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = '% Answered Calls in 60 sec — Last 30 min',
    "ShortDescription" = 'Service Level (60-sec target) intended to cover only the last 30 minutes.',
    "LongDescription" = 'Intended as a rolling Service Level: share of incoming completed calls answered within 60 seconds over the last 30 minutes. WARNING: the stored formula appends the time-window condition to the Calc expression in a syntactically dubious way ("…&&InQueueDateTime>=DateTime.Now.AddHours(-0.5)"), so the time window most likely does not work as intended. Needs engine-side verification.',
    "Comparison" = 'For a verified whole-day Service Level use "% Answered Calls in 60 sec (of incoming)".',
    "StandardKpi" = 'Rolling Service Level',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.special',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'deprecated',
    "CatalogNotes" = 'CONFIRMED broken (engine analysis 2026-06-05): unresolved identifier InQueueDateTime + double&&bool — Eval() throws every calc cycle; always empty. Deleted by migration 20260605_004; references re-pointed to QueuePctAnsweredCalls60secInc.'
WHERE "MetricId" = 'QueuePctAnsweredCalls60secIncLast30min';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'SLA: % Answered in 30 sec vs 80% Target',
    "ShortDescription" = 'Answered-in-30-sec calls divided by 80% of incoming completed calls — progress against an 80/30 SLA.',
    "LongDescription" = 'Variant of Service Level normalised against the 80/30 target: numerator = calls answered within 30 seconds, denominator = 0.8 x incoming completed calls. A value of 100% means the 80/30 SLA is exactly met; values above 100% mean over-performance. WARNING: the formula references "[QueueNumAnsweredCalls30sec ]" with a trailing space inside the brackets — verify the engine tolerates this.',
    "Comparison" = 'Plain "in 30 sec (of incoming)" reports the raw percentage; this metric reports attainment vs the 80% goal.',
    "StandardKpi" = 'SLA attainment',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.pct.special',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'defect-candidate',
    "CatalogNotes" = 'CONFIRMED (engine analysis 2026-06-05): exact-match key lookup fails on the trailing space in [QueueNumAnsweredCalls30sec ] — numerator always 0. Fixed by migration 20260605_004 (space trimmed).'
WHERE "MetricId" = 'QueueSLAIn30secFrom80PctInc';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Calls per Hour (queue)',
    "ShortDescription" = 'Incoming call throughput of the queue, normalised per hour.',
    "LongDescription" = 'Number of incoming calls handled per hour by the Business Unit, computed by the engine CPH function. Productivity/throughput indicator for intraday comparison regardless of shift length.',
    "Comparison" = 'UserCPH is the per-agent equivalent.',
    "StandardKpi" = 'Contacts per hour',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.staffing',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueCPH';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'On Call Agents (duplicate)',
    "ShortDescription" = 'Duplicate of "Number of On Call Agents" (UsersSumOnCall) — identical definition.',
    "LongDescription" = 'Counts agents currently in the ONPHONE status group. The RTM engine ignores the DataType column for status counters, so this metric is functionally identical to UsersSumOnCall. Kept under a "QM" description prefix only.',
    "Comparison" = 'Use UsersSumOnCall as the canonical metric.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.staffing',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'duplicate',
    "CatalogNotes" = 'Functional duplicate of UsersSumOnCall (engine ignores DataType for status counters).'
WHERE "MetricId" = 'QueueNumOnCallAgents';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Agents in Wrap Up',
    "ShortDescription" = 'Number of agents of this Business Unit currently in Wrap Up status.',
    "LongDescription" = 'Real-time count of agents whose current status is "Wrap Up" (after-call work entry state). Counts a specific Agent State, not a status group.',
    "Comparison" = 'For group-level counts see "Agents in Paperwork State Group" (PAPERWORK covers all ACW-type states).',
    "StandardKpi" = 'ACW staffing (real-time)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.staffing',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumWrapUpAgents';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Logged In Agents (duplicate)',
    "ShortDescription" = 'Duplicate of "Number of Currently Logged in Users" — identical definition.',
    "LongDescription" = 'Counts agents of the Business Unit currently logged in. Functionally identical to QueueLoginDataNumLoggedUsers (the engine ignores DataType for status counters).',
    "Comparison" = 'Use QueueLoginDataNumLoggedUsers as the canonical metric.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.staffing',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'duplicate',
    "CatalogNotes" = 'Functional duplicate of QueueLoginDataNumLoggedUsers.'
WHERE "MetricId" = 'QueueNumberOfLoggedAgents';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Talk Duration — Callbacks',
    "ShortDescription" = 'Average handling (talk) time of completed incoming callback interactions (customer-requested return calls handled by the queue) today.',
    "LongDescription" = 'Average talk-phase duration of incoming callback interactions (customer-requested return calls handled by the queue) that have been completed today (currently active ones are excluded until they finish). Talk time is the agent-customer conversation phase, one of the components of Average Handling Time (AHT) together with hold and wrap-up.',
    "Comparison" = 'For per-agent talk metrics see the Agent category (e.g. ''Average Call Duration'').',
    "StandardKpi" = 'Average Talk Time (ATT), AHT component',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.talk.avg',
    "Channel" = 'callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgTalkingDurationCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Talk Duration — Calls',
    "ShortDescription" = 'Average handling (talk) time of completed incoming external incoming voice calls today.',
    "LongDescription" = 'Average talk-phase duration of incoming external incoming voice calls that have been completed today (currently active ones are excluded until they finish). Talk time is the agent-customer conversation phase, one of the components of Average Handling Time (AHT) together with hold and wrap-up.',
    "Comparison" = 'For per-agent talk metrics see the Agent category (e.g. ''Average Call Duration'').',
    "StandardKpi" = 'Average Talk Time (ATT), AHT component',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.talk.avg',
    "Channel" = 'calls',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgTalkingDurationCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Talk Duration — Calls + Callbacks',
    "ShortDescription" = 'Average handling (talk) time of completed incoming combined voice load: external incoming calls and callbacks today.',
    "LongDescription" = 'Average talk-phase duration of incoming combined voice load: external incoming calls and callbacks that have been completed today (currently active ones are excluded until they finish). Talk time is the agent-customer conversation phase, one of the components of Average Handling Time (AHT) together with hold and wrap-up.',
    "Comparison" = 'For per-agent talk metrics see the Agent category (e.g. ''Average Call Duration'').',
    "StandardKpi" = 'Average Talk Time (ATT), AHT component',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.talk.avg',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgTalkingDurationCallsAndCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Talk Duration — Chats',
    "ShortDescription" = 'Average handling (talk) time of completed incoming incoming chat interactions today.',
    "LongDescription" = 'Average talk-phase duration of incoming incoming chat interactions that have been completed today (currently active ones are excluded until they finish). Talk time is the agent-customer conversation phase, one of the components of Average Handling Time (AHT) together with hold and wrap-up.',
    "Comparison" = 'For per-agent talk metrics see the Agent category (e.g. ''Average Call Duration'').',
    "StandardKpi" = 'Average Talk Time (ATT), AHT component',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.talk.avg',
    "Channel" = 'chats',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgTalkingDurationChats';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Talk Duration — Digital Interactions',
    "ShortDescription" = 'Average handling (talk) time of completed incoming non-voice digital interactions (chat and e-mail) today.',
    "LongDescription" = 'Average talk-phase duration of incoming non-voice digital interactions (chat and e-mail) that have been completed today (currently active ones are excluded until they finish). Talk time is the agent-customer conversation phase, one of the components of Average Handling Time (AHT) together with hold and wrap-up.',
    "Comparison" = 'For per-agent talk metrics see the Agent category (e.g. ''Average Call Duration'').',
    "StandardKpi" = 'Average Talk Time (ATT), AHT component',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.talk.avg',
    "Channel" = 'digital',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgTalkingDurationInteractions';

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
    "DisplayName" = 'Abandoned Calls + Callbacks',
    "ShortDescription" = 'Number of incoming combined voice load: external incoming calls and callbacks abandoned in queue today (caller left before an agent answered).',
    "LongDescription" = 'Counts incoming combined voice load: external incoming calls and callbacks that left the queue without being answered (caller hung up / closed the chat). Interactions that converted to a callback request are excluded, so requesting a callback is not treated as abandonment.',
    "Comparison" = 'Counterpart of ''Answered''. See ''Average Time to Abandon'' for how long abandoning customers waited.',
    "StandardKpi" = 'Abandoned contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.abandoned',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAbandonedCallsAndCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Abandoned Chats',
    "ShortDescription" = 'Number of incoming incoming chat interactions abandoned in queue today (caller left before an agent answered).',
    "LongDescription" = 'Counts incoming incoming chat interactions that left the queue without being answered (caller hung up / closed the chat). Interactions that converted to a callback request are excluded, so requesting a callback is not treated as abandonment.',
    "Comparison" = 'Counterpart of ''Answered''. See ''Average Time to Abandon'' for how long abandoning customers waited.',
    "StandardKpi" = 'Abandoned contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.abandoned',
    "Channel" = 'chats',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAbandonedChats';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Abandoned Digital Interactions',
    "ShortDescription" = 'Number of incoming non-voice digital interactions (chat and e-mail) abandoned in queue today (caller left before an agent answered).',
    "LongDescription" = 'Counts incoming non-voice digital interactions (chat and e-mail) that left the queue without being answered (caller hung up / closed the chat). Interactions that converted to a callback request are excluded, so requesting a callback is not treated as abandonment.',
    "Comparison" = 'Counterpart of ''Answered''. See ''Average Time to Abandon'' for how long abandoning customers waited.',
    "StandardKpi" = 'Abandoned contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.abandoned',
    "Channel" = 'digital',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAbandonedInteractions';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Active Callbacks',
    "ShortDescription" = 'Number of callback interactions (customer-requested return calls handled by the queue) currently being handled by agents (in talk state).',
    "LongDescription" = 'Real-time snapshot: how many callback interactions (customer-requested return calls handled by the queue) are connected to agents at this moment (talk state). Together with ''Waiting'' it shows total live load of the queue.',
    "Comparison" = '''Waiting'' = still in queue; ''Active'' = already with an agent.',
    "StandardKpi" = 'Active contacts (real-time)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.active',
    "Channel" = 'callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumActiveCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Active Calls',
    "ShortDescription" = 'Number of external incoming voice calls currently being handled by agents (in talk state).',
    "LongDescription" = 'Real-time snapshot: how many external incoming voice calls are connected to agents at this moment (talk state). Together with ''Waiting'' it shows total live load of the queue.',
    "Comparison" = '''Waiting'' = still in queue; ''Active'' = already with an agent.',
    "StandardKpi" = 'Active contacts (real-time)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.active',
    "Channel" = 'calls',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumActiveCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Active Calls + Callbacks',
    "ShortDescription" = 'Number of combined voice load: external incoming calls and callbacks currently being handled by agents (in talk state).',
    "LongDescription" = 'Real-time snapshot: how many combined voice load: external incoming calls and callbacks are connected to agents at this moment (talk state). Together with ''Waiting'' it shows total live load of the queue.',
    "Comparison" = '''Waiting'' = still in queue; ''Active'' = already with an agent.',
    "StandardKpi" = 'Active contacts (real-time)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.active',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumActiveCallsAndCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Active Chats',
    "ShortDescription" = 'Number of incoming chat interactions currently being handled by agents (in talk state).',
    "LongDescription" = 'Real-time snapshot: how many incoming chat interactions are connected to agents at this moment (talk state). Together with ''Waiting'' it shows total live load of the queue.',
    "Comparison" = '''Waiting'' = still in queue; ''Active'' = already with an agent.',
    "StandardKpi" = 'Active contacts (real-time)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.active',
    "Channel" = 'chats',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumActiveChats';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Active Digital Interactions',
    "ShortDescription" = 'Number of non-voice digital interactions (chat and e-mail) currently being handled by agents (in talk state).',
    "LongDescription" = 'Real-time snapshot: how many non-voice digital interactions (chat and e-mail) are connected to agents at this moment (talk state). Together with ''Waiting'' it shows total live load of the queue.',
    "Comparison" = '''Waiting'' = still in queue; ''Active'' = already with an agent.',
    "StandardKpi" = 'Active contacts (real-time)',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.active',
    "Channel" = 'digital',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumActiveInteractions';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Accepted Callbacks (duplicate)',
    "ShortDescription" = 'Duplicate of "Answered Callbacks" — identical definition under a different ID.',
    "LongDescription" = 'This metric has exactly the same filter as QueueNumAnsweredCallbacks (incoming external callbacks, answered). It exists under a second ID for historical reasons and should be removed in favour of the canonical metric.',
    "Comparison" = 'Use QueueNumAnsweredCallbacks instead.',
    "StandardKpi" = NULL,
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'duplicate',
    "CatalogNotes" = 'Exact duplicate of QueueNumAnsweredCallbacks; scheduled for cleanup.'
WHERE "MetricId" = 'QueueNumAcceptedCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Callbacks',
    "ShortDescription" = 'Number of incoming callback interactions (customer-requested return calls handled by the queue) answered by agents today.',
    "LongDescription" = 'Counts incoming callback interactions (customer-requested return calls handled by the queue) that were successfully connected to an agent today. The interaction is counted as soon as it is answered, even if it is still in progress.',
    "Comparison" = 'Counterpart of ''Abandoned''. Threshold variants (30/60/120/360 sec) count only those answered within the given wait-time limit.',
    "StandardKpi" = 'Answered/handled contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered',
    "Channel" = 'callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Calls',
    "ShortDescription" = 'Number of incoming external incoming voice calls answered by agents today.',
    "LongDescription" = 'Counts incoming external incoming voice calls that were successfully connected to an agent today. The interaction is counted as soon as it is answered, even if it is still in progress.',
    "Comparison" = 'Counterpart of ''Abandoned''. Threshold variants (30/60/120/360 sec) count only those answered within the given wait-time limit.',
    "StandardKpi" = 'Answered/handled contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered',
    "Channel" = 'calls',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Calls + Callbacks',
    "ShortDescription" = 'Number of incoming combined voice load: external incoming calls and callbacks answered by agents today.',
    "LongDescription" = 'Counts incoming combined voice load: external incoming calls and callbacks that were successfully connected to an agent today. The interaction is counted as soon as it is answered, even if it is still in progress.',
    "Comparison" = 'Counterpart of ''Abandoned''. Threshold variants (30/60/120/360 sec) count only those answered within the given wait-time limit.',
    "StandardKpi" = 'Answered/handled contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredCallsAndCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Chats',
    "ShortDescription" = 'Number of incoming incoming chat interactions answered by agents today.',
    "LongDescription" = 'Counts incoming incoming chat interactions that were successfully connected to an agent today. The interaction is counted as soon as it is answered, even if it is still in progress.',
    "Comparison" = 'Counterpart of ''Abandoned''. Threshold variants (30/60/120/360 sec) count only those answered within the given wait-time limit.',
    "StandardKpi" = 'Answered/handled contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered',
    "Channel" = 'chats',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredChats';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Digital Interactions',
    "ShortDescription" = 'Number of incoming non-voice digital interactions (chat and e-mail) answered by agents today.',
    "LongDescription" = 'Counts incoming non-voice digital interactions (chat and e-mail) that were successfully connected to an agent today. The interaction is counted as soon as it is answered, even if it is still in progress.',
    "Comparison" = 'Counterpart of ''Abandoned''. Threshold variants (30/60/120/360 sec) count only those answered within the given wait-time limit.',
    "StandardKpi" = 'Answered/handled contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered',
    "Channel" = 'digital',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredInteractions';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Callbacks in 30 sec',
    "ShortDescription" = 'Number of incoming callback interactions (customer-requested return calls handled by the queue) answered with queue wait under 30 seconds.',
    "LongDescription" = 'Counts incoming callback interactions (customer-requested return calls handled by the queue) answered by an agent where the time in queue was less than 30 seconds. This is the numerator for Service Level calculations with a 30-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'callbacks',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredCallbacks30sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Callbacks in 60 sec',
    "ShortDescription" = 'Number of incoming callback interactions (customer-requested return calls handled by the queue) answered with queue wait under 60 seconds.',
    "LongDescription" = 'Counts incoming callback interactions (customer-requested return calls handled by the queue) answered by an agent where the time in queue was less than 60 seconds. This is the numerator for Service Level calculations with a 60-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'callbacks',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'defect-candidate',
    "CatalogNotes" = 'Description says "Answered Calls in 60 sec" but the metric counts CALLBACKS — fix Description.'
WHERE "MetricId" = 'QueueNumAnsweredCallbacks60sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Callbacks in 120 sec',
    "ShortDescription" = 'Number of incoming callback interactions (customer-requested return calls handled by the queue) answered with queue wait under 120 seconds.',
    "LongDescription" = 'Counts incoming callback interactions (customer-requested return calls handled by the queue) answered by an agent where the time in queue was less than 120 seconds. This is the numerator for Service Level calculations with a 120-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'callbacks',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredCallbacks120sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Calls in 30 sec',
    "ShortDescription" = 'Number of incoming external incoming voice calls answered with queue wait under 30 seconds.',
    "LongDescription" = 'Counts incoming external incoming voice calls answered by an agent where the time in queue was less than 30 seconds. This is the numerator for Service Level calculations with a 30-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'calls',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredCalls30sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Calls in 60 sec',
    "ShortDescription" = 'Number of incoming external incoming voice calls answered with queue wait under 60 seconds.',
    "LongDescription" = 'Counts incoming external incoming voice calls answered by an agent where the time in queue was less than 60 seconds. This is the numerator for Service Level calculations with a 60-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'calls',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredCalls60sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Calls in 120 sec',
    "ShortDescription" = 'Number of incoming external incoming voice calls answered with queue wait under 120 seconds.',
    "LongDescription" = 'Counts incoming external incoming voice calls answered by an agent where the time in queue was less than 120 seconds. This is the numerator for Service Level calculations with a 120-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'calls',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredCalls120sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Calls in 360 sec',
    "ShortDescription" = 'Number of incoming external incoming voice calls answered with queue wait under 360 seconds.',
    "LongDescription" = 'Counts incoming external incoming voice calls answered by an agent where the time in queue was less than 360 seconds. This is the numerator for Service Level calculations with a 360-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'calls',
    "ThresholdSec" = 360,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredCalls360sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Calls + Callbacks in 30 sec',
    "ShortDescription" = 'Number of incoming combined voice load: external incoming calls and callbacks answered with queue wait under 30 seconds.',
    "LongDescription" = 'Counts incoming combined voice load: external incoming calls and callbacks answered by an agent where the time in queue was less than 30 seconds. This is the numerator for Service Level calculations with a 30-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredCallsAndCallbacks30sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Calls + Callbacks in 60 sec',
    "ShortDescription" = 'Number of incoming combined voice load: external incoming calls and callbacks answered with queue wait under 60 seconds.',
    "LongDescription" = 'Counts incoming combined voice load: external incoming calls and callbacks answered by an agent where the time in queue was less than 60 seconds. This is the numerator for Service Level calculations with a 60-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredCallsAndCallbacks60sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Calls + Callbacks in 120 sec',
    "ShortDescription" = 'Number of incoming combined voice load: external incoming calls and callbacks answered with queue wait under 120 seconds.',
    "LongDescription" = 'Counts incoming combined voice load: external incoming calls and callbacks answered by an agent where the time in queue was less than 120 seconds. This is the numerator for Service Level calculations with a 120-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredCallsAndCallbacks120sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Chats in 30 sec',
    "ShortDescription" = 'Number of incoming incoming chat interactions answered with queue wait under 30 seconds.',
    "LongDescription" = 'Counts incoming incoming chat interactions answered by an agent where the time in queue was less than 30 seconds. This is the numerator for Service Level calculations with a 30-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'chats',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredChats30sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Chats in 60 sec',
    "ShortDescription" = 'Number of incoming incoming chat interactions answered with queue wait under 60 seconds.',
    "LongDescription" = 'Counts incoming incoming chat interactions answered by an agent where the time in queue was less than 60 seconds. This is the numerator for Service Level calculations with a 60-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'chats',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredChats60sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Chats in 120 sec',
    "ShortDescription" = 'Number of incoming incoming chat interactions answered with queue wait under 120 seconds.',
    "LongDescription" = 'Counts incoming incoming chat interactions answered by an agent where the time in queue was less than 120 seconds. This is the numerator for Service Level calculations with a 120-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'chats',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredChats120sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Digital Interactions in 30 sec',
    "ShortDescription" = 'Number of incoming non-voice digital interactions (chat and e-mail) answered with queue wait under 30 seconds.',
    "LongDescription" = 'Counts incoming non-voice digital interactions (chat and e-mail) answered by an agent where the time in queue was less than 30 seconds. This is the numerator for Service Level calculations with a 30-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'digital',
    "ThresholdSec" = 30,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredInteractions30sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Digital Interactions in 60 sec',
    "ShortDescription" = 'Number of incoming non-voice digital interactions (chat and e-mail) answered with queue wait under 60 seconds.',
    "LongDescription" = 'Counts incoming non-voice digital interactions (chat and e-mail) answered by an agent where the time in queue was less than 60 seconds. This is the numerator for Service Level calculations with a 60-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'digital',
    "ThresholdSec" = 60,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredInteractions60sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Answered Digital Interactions in 120 sec',
    "ShortDescription" = 'Number of incoming non-voice digital interactions (chat and e-mail) answered with queue wait under 120 seconds.',
    "LongDescription" = 'Counts incoming non-voice digital interactions (chat and e-mail) answered by an agent where the time in queue was less than 120 seconds. This is the numerator for Service Level calculations with a 120-second target.',
    "Comparison" = 'The same event family exists with 30/60/120/360-second targets; pick the threshold that matches the Business Unit''s SLA.',
    "StandardKpi" = 'Service Level numerator',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.answered_threshold',
    "Channel" = 'digital',
    "ThresholdSec" = 120,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumAnsweredInteractions120sec';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming Callbacks Today (excl. waiting)',
    "ShortDescription" = 'Number of incoming callback interactions (customer-requested return calls handled by the queue) that have finished queuing today (answered or abandoned); excludes those still waiting and callback requests.',
    "LongDescription" = 'Counts incoming callback interactions (customer-requested return calls handled by the queue) whose queue phase has completed: each was either answered by an agent or abandoned. Interactions still waiting in queue and callback requests are excluded. Because the value only changes when an interaction leaves the queue, it is the standard denominator for ''percent answered'' and ''percent abandoned'' metrics.',
    "Comparison" = 'Equals ''Incoming … incl. waiting'' minus currently waiting items and callback requests.',
    "StandardKpi" = 'Handled + abandoned contacts (denominator)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.incoming_completed',
    "Channel" = 'callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumIncomingCompletedCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming Calls Today (excl. waiting)',
    "ShortDescription" = 'Number of incoming external incoming voice calls that have finished queuing today (answered or abandoned); excludes those still waiting and callback requests.',
    "LongDescription" = 'Counts incoming external incoming voice calls whose queue phase has completed: each was either answered by an agent or abandoned. Interactions still waiting in queue and callback requests are excluded. Because the value only changes when an interaction leaves the queue, it is the standard denominator for ''percent answered'' and ''percent abandoned'' metrics.',
    "Comparison" = 'Equals ''Incoming … incl. waiting'' minus currently waiting items and callback requests.',
    "StandardKpi" = 'Handled + abandoned contacts (denominator)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.incoming_completed',
    "Channel" = 'calls',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumIncomingCompletedCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming Calls + Callbacks Today (excl. waiting)',
    "ShortDescription" = 'Number of incoming combined voice load: external incoming calls and callbacks that have finished queuing today (answered or abandoned); excludes those still waiting and callback requests.',
    "LongDescription" = 'Counts incoming combined voice load: external incoming calls and callbacks whose queue phase has completed: each was either answered by an agent or abandoned. Interactions still waiting in queue and callback requests are excluded. Because the value only changes when an interaction leaves the queue, it is the standard denominator for ''percent answered'' and ''percent abandoned'' metrics.',
    "Comparison" = 'Equals ''Incoming … incl. waiting'' minus currently waiting items and callback requests.',
    "StandardKpi" = 'Handled + abandoned contacts (denominator)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.incoming_completed',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumIncomingCompletedCallsAndCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming Chats Today (excl. waiting)',
    "ShortDescription" = 'Number of incoming incoming chat interactions that have finished queuing today (answered or abandoned); excludes those still waiting and callback requests.',
    "LongDescription" = 'Counts incoming incoming chat interactions whose queue phase has completed: each was either answered by an agent or abandoned. Interactions still waiting in queue and callback requests are excluded. Because the value only changes when an interaction leaves the queue, it is the standard denominator for ''percent answered'' and ''percent abandoned'' metrics.',
    "Comparison" = 'Equals ''Incoming … incl. waiting'' minus currently waiting items and callback requests.',
    "StandardKpi" = 'Handled + abandoned contacts (denominator)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.incoming_completed',
    "Channel" = 'chats',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumIncomingCompletedChats';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming Digital Interactions Today (excl. waiting)',
    "ShortDescription" = 'Number of incoming non-voice digital interactions (chat and e-mail) that have finished queuing today (answered or abandoned); excludes those still waiting and callback requests.',
    "LongDescription" = 'Counts incoming non-voice digital interactions (chat and e-mail) whose queue phase has completed: each was either answered by an agent or abandoned. Interactions still waiting in queue and callback requests are excluded. Because the value only changes when an interaction leaves the queue, it is the standard denominator for ''percent answered'' and ''percent abandoned'' metrics.',
    "Comparison" = 'Equals ''Incoming … incl. waiting'' minus currently waiting items and callback requests.',
    "StandardKpi" = 'Handled + abandoned contacts (denominator)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.incoming_completed',
    "Channel" = 'digital',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumIncomingCompletedInteractions';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming Callbacks Today (incl. waiting)',
    "ShortDescription" = 'Number of incoming callback interactions (customer-requested return calls handled by the queue) received today, including those still waiting in queue.',
    "LongDescription" = 'Counts every incoming callback interactions (customer-requested return calls handled by the queue) interaction registered since the start of the business day, regardless of current state — waiting in queue, in progress, answered or abandoned. This is the gross inbound load (offered contacts) for the Business Unit. Unlike the ''excluding waiting'' counterpart, interactions still sitting in the queue are included, so the value can grow before any agent has answered.',
    "Comparison" = 'Use ''Incoming … excluding waiting'' as the stable denominator for percentages; use ''Waiting'' for the current queue depth only.',
    "StandardKpi" = 'Offered contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.incoming_online',
    "Channel" = 'callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumIncomingOnlineCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming Calls Today (incl. waiting)',
    "ShortDescription" = 'Number of incoming external incoming voice calls received today, including those still waiting in queue.',
    "LongDescription" = 'Counts every incoming external incoming voice calls interaction registered since the start of the business day, regardless of current state — waiting in queue, in progress, answered or abandoned. This is the gross inbound load (offered contacts) for the Business Unit. Unlike the ''excluding waiting'' counterpart, interactions still sitting in the queue are included, so the value can grow before any agent has answered.',
    "Comparison" = 'Use ''Incoming … excluding waiting'' as the stable denominator for percentages; use ''Waiting'' for the current queue depth only.',
    "StandardKpi" = 'Offered contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.incoming_online',
    "Channel" = 'calls',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumIncomingOnlineCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming Calls + Callbacks Today (incl. waiting)',
    "ShortDescription" = 'Number of incoming combined voice load: external incoming calls and callbacks received today, including those still waiting in queue.',
    "LongDescription" = 'Counts every incoming combined voice load: external incoming calls and callbacks interaction registered since the start of the business day, regardless of current state — waiting in queue, in progress, answered or abandoned. This is the gross inbound load (offered contacts) for the Business Unit. Unlike the ''excluding waiting'' counterpart, interactions still sitting in the queue are included, so the value can grow before any agent has answered.',
    "Comparison" = 'Use ''Incoming … excluding waiting'' as the stable denominator for percentages; use ''Waiting'' for the current queue depth only.',
    "StandardKpi" = 'Offered contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.incoming_online',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumIncomingOnlineCallsAndCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming Chats Today (incl. waiting)',
    "ShortDescription" = 'Number of incoming incoming chat interactions received today, including those still waiting in queue.',
    "LongDescription" = 'Counts every incoming incoming chat interactions interaction registered since the start of the business day, regardless of current state — waiting in queue, in progress, answered or abandoned. This is the gross inbound load (offered contacts) for the Business Unit. Unlike the ''excluding waiting'' counterpart, interactions still sitting in the queue are included, so the value can grow before any agent has answered.',
    "Comparison" = 'Use ''Incoming … excluding waiting'' as the stable denominator for percentages; use ''Waiting'' for the current queue depth only.',
    "StandardKpi" = 'Offered contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.incoming_online',
    "Channel" = 'chats',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumIncomingOnlineChats';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Incoming Digital Interactions Today (incl. waiting)',
    "ShortDescription" = 'Number of incoming non-voice digital interactions (chat and e-mail) received today, including those still waiting in queue.',
    "LongDescription" = 'Counts every incoming non-voice digital interactions (chat and e-mail) interaction registered since the start of the business day, regardless of current state — waiting in queue, in progress, answered or abandoned. This is the gross inbound load (offered contacts) for the Business Unit. Unlike the ''excluding waiting'' counterpart, interactions still sitting in the queue are included, so the value can grow before any agent has answered.',
    "Comparison" = 'Use ''Incoming … excluding waiting'' as the stable denominator for percentages; use ''Waiting'' for the current queue depth only.',
    "StandardKpi" = 'Offered contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.incoming_online',
    "Channel" = 'digital',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'defect-candidate',
    "CatalogNotes" = 'MetricId typo: "Icoming" instead of "Incoming". Rename requires updating any referencing cells/configs.'
WHERE "MetricId" = 'QueueNumIcomingOnlineInteractions';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Callback Requests',
    "ShortDescription" = 'Number of incoming interactions converted to a callback request today.',
    "LongDescription" = 'Counts customers who, instead of waiting in queue, requested a callback. These interactions are excluded from abandoned counts and from completed-volume denominators, and appear later as callback interactions when dialled back.',
    "Comparison" = 'See Completed/Accepted Callbacks for the return-call side of the lifecycle.',
    "StandardKpi" = 'Callback requests',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.misc',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumCallbackRequests';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Completed Callbacks',
    "ShortDescription" = 'Number of callbacks successfully completed (dialled back and connected) today.',
    "LongDescription" = 'Counts outgoing callback interactions that were answered — i.e. the system called the customer back and the conversation took place. Closing stage of the callback lifecycle: request → dial-back → completed.',
    "Comparison" = 'QueueNumAnsweredCallbacks counts the incoming leg; this metric counts the outgoing (return) leg.',
    "StandardKpi" = 'Completed callbacks',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.misc',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumCompletedCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Completed Incoming Digital Interactions',
    "ShortDescription" = 'Number of incoming digital interactions (chat + e-mail) fully finished today: not waiting, not active, not abandoned.',
    "LongDescription" = 'Counts incoming chat and e-mail interactions that have completely finished processing: they are no longer in queue, no longer being handled, and were not abandoned. Effectively "successfully handled to the end".',
    "Comparison" = 'Differs from Answered Digital Interactions, which counts an interaction as soon as it is answered even if still in progress.',
    "StandardKpi" = 'Handled contacts',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.misc',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumIncomingHandledInteractions';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Chats Today (all)',
    "ShortDescription" = 'Total number of chat interactions registered today (any direction, any state).',
    "LongDescription" = 'Counts all chat interactions seen today with no additional filter: incoming and outgoing, waiting, active, answered or abandoned. Broadest possible chat counter.',
    "Comparison" = 'Narrower chat counters: Incoming Chats (incl./excl. waiting), Answered/Abandoned Chats, Waiting Chats, Active Chats.',
    "StandardKpi" = 'Chat volume',
    "StandardRef" = NULL,
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.misc',
    "Channel" = NULL,
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumOnlineChats';

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

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Waiting Callbacks',
    "ShortDescription" = 'Number of callback interactions (customer-requested return calls handled by the queue) waiting in queue right now.',
    "LongDescription" = 'Real-time snapshot: how many callback interactions (customer-requested return calls handled by the queue) are currently in the queue, not yet connected to an agent. Rises when arrivals exceed answering capacity. This is a ''now'' metric — it has no daily accumulation.',
    "Comparison" = 'See ''Current Max Wait Time'' for how long the longest waiting item has been queuing; see ''Active'' for items already connected to agents.',
    "StandardKpi" = 'Calls in queue (real-time)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.waiting',
    "Channel" = 'callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumWaitingCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Waiting Calls',
    "ShortDescription" = 'Number of external incoming voice calls waiting in queue right now.',
    "LongDescription" = 'Real-time snapshot: how many external incoming voice calls are currently in the queue, not yet connected to an agent. Rises when arrivals exceed answering capacity. This is a ''now'' metric — it has no daily accumulation.',
    "Comparison" = 'See ''Current Max Wait Time'' for how long the longest waiting item has been queuing; see ''Active'' for items already connected to agents.',
    "StandardKpi" = 'Calls in queue (real-time)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.waiting',
    "Channel" = 'calls',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumWaitingCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Waiting Calls + Callbacks',
    "ShortDescription" = 'Number of combined voice load: external incoming calls and callbacks waiting in queue right now.',
    "LongDescription" = 'Real-time snapshot: how many combined voice load: external incoming calls and callbacks are currently in the queue, not yet connected to an agent. Rises when arrivals exceed answering capacity. This is a ''now'' metric — it has no daily accumulation.',
    "Comparison" = 'See ''Current Max Wait Time'' for how long the longest waiting item has been queuing; see ''Active'' for items already connected to agents.',
    "StandardKpi" = 'Calls in queue (real-time)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.waiting',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueNumWaitingCallsAndCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Waiting Chats',
    "ShortDescription" = 'Number of incoming chat interactions waiting in queue right now.',
    "LongDescription" = 'Real-time snapshot: how many incoming chat interactions are currently in the queue, not yet connected to an agent. Rises when arrivals exceed answering capacity. This is a ''now'' metric — it has no daily accumulation.',
    "Comparison" = 'See ''Current Max Wait Time'' for how long the longest waiting item has been queuing; see ''Active'' for items already connected to agents.',
    "StandardKpi" = 'Calls in queue (real-time)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.waiting',
    "Channel" = 'chats',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = 'Computed via NumWaitings engine function (voice variants use InteractionsCount + IsInQueue) — result semantics identical.'
WHERE "MetricId" = 'QueueNumWaitingChats';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Waiting Digital Interactions',
    "ShortDescription" = 'Number of non-voice digital interactions (chat and e-mail) waiting in queue right now.',
    "LongDescription" = 'Real-time snapshot: how many non-voice digital interactions (chat and e-mail) are currently in the queue, not yet connected to an agent. Rises when arrivals exceed answering capacity. This is a ''now'' metric — it has no daily accumulation.',
    "Comparison" = 'See ''Current Max Wait Time'' for how long the longest waiting item has been queuing; see ''Active'' for items already connected to agents.',
    "StandardKpi" = 'Calls in queue (real-time)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.volume.waiting',
    "Channel" = 'digital',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = 'Computed via NumWaitings engine function (voice variants use InteractionsCount + IsInQueue) — result semantics identical.'
WHERE "MetricId" = 'QueueNumWaitingInteractions';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Wait Time — Callbacks',
    "ShortDescription" = 'Average queue wait time of callback interactions (customer-requested return calls handled by the queue) that finished queuing today (answered and abandoned).',
    "LongDescription" = 'Average time spent in queue by callback interactions (customer-requested return calls handled by the queue) whose queue phase has completed today. Note: both answered and abandoned interactions are included, so this is broader than the classic ASA (Average Speed of Answer), which covers answered contacts only.',
    "Comparison" = 'Close to ASA when abandonment is low. See ''Average Time to Abandon'' for the abandoned-only view.',
    "StandardKpi" = 'Average wait (≈ASA)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.wait.avg',
    "Channel" = 'callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgWaitTimeCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Wait Time — Calls',
    "ShortDescription" = 'Average queue wait time of external incoming voice calls that finished queuing today (answered and abandoned).',
    "LongDescription" = 'Average time spent in queue by external incoming voice calls whose queue phase has completed today. Note: both answered and abandoned interactions are included, so this is broader than the classic ASA (Average Speed of Answer), which covers answered contacts only.',
    "Comparison" = 'Close to ASA when abandonment is low. See ''Average Time to Abandon'' for the abandoned-only view.',
    "StandardKpi" = 'Average wait (≈ASA)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.wait.avg',
    "Channel" = 'calls',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgWaitTimeCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Wait Time — Calls + Callbacks',
    "ShortDescription" = 'Average queue wait time of combined voice load: external incoming calls and callbacks that finished queuing today (answered and abandoned).',
    "LongDescription" = 'Average time spent in queue by combined voice load: external incoming calls and callbacks whose queue phase has completed today. Note: both answered and abandoned interactions are included, so this is broader than the classic ASA (Average Speed of Answer), which covers answered contacts only.',
    "Comparison" = 'Close to ASA when abandonment is low. See ''Average Time to Abandon'' for the abandoned-only view.',
    "StandardKpi" = 'Average wait (≈ASA)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.wait.avg',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgWaitTimeCallsAndCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Wait Time — Chats',
    "ShortDescription" = 'Average queue wait time of incoming chat interactions that finished queuing today (answered and abandoned).',
    "LongDescription" = 'Average time spent in queue by incoming chat interactions whose queue phase has completed today. Note: both answered and abandoned interactions are included, so this is broader than the classic ASA (Average Speed of Answer), which covers answered contacts only.',
    "Comparison" = 'Close to ASA when abandonment is low. See ''Average Time to Abandon'' for the abandoned-only view.',
    "StandardKpi" = 'Average wait (≈ASA)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.wait.avg',
    "Channel" = 'chats',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgWaitTimeChats';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Average Wait Time — Digital Interactions',
    "ShortDescription" = 'Average queue wait time of non-voice digital interactions (chat and e-mail) that finished queuing today (answered and abandoned).',
    "LongDescription" = 'Average time spent in queue by non-voice digital interactions (chat and e-mail) whose queue phase has completed today. Note: both answered and abandoned interactions are included, so this is broader than the classic ASA (Average Speed of Answer), which covers answered contacts only.',
    "Comparison" = 'Close to ASA when abandonment is low. See ''Average Time to Abandon'' for the abandoned-only view.',
    "StandardKpi" = 'Average wait (≈ASA)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.wait.avg',
    "Channel" = 'digital',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueAvgWaitTimeInteractions';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Current Max Wait Time — Callbacks',
    "ShortDescription" = 'Longest time a callback interactions (customer-requested return calls handled by the queue) currently in queue has been waiting (right now).',
    "LongDescription" = 'Real-time metric: among callback interactions (customer-requested return calls handled by the queue) currently waiting in queue, the wait time of the longest-waiting one. Falls to zero when the queue is empty. The classic wallboard ''Longest Wait'' indicator for immediate intervention.',
    "Comparison" = '''Average Wait Time'' is a daily average over completed items; this metric reflects only the present queue.',
    "StandardKpi" = 'Longest wait in queue (real-time)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.wait.curmax',
    "Channel" = 'callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueCurMaxWaitTimeCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Current Max Wait Time — Calls',
    "ShortDescription" = 'Longest time a external incoming voice call currently in queue has been waiting (right now).',
    "LongDescription" = 'Real-time metric: among external incoming voice calls currently waiting in queue, the wait time of the longest-waiting one. Falls to zero when the queue is empty. The classic wallboard ''Longest Wait'' indicator for immediate intervention.',
    "Comparison" = '''Average Wait Time'' is a daily average over completed items; this metric reflects only the present queue.',
    "StandardKpi" = 'Longest wait in queue (real-time)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.wait.curmax',
    "Channel" = 'calls',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueCurMaxWaitTimeCalls';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Current Max Wait Time — Calls + Callbacks',
    "ShortDescription" = 'Longest time a combined voice load: external incoming calls and callback currently in queue has been waiting (right now).',
    "LongDescription" = 'Real-time metric: among combined voice load: external incoming calls and callbacks currently waiting in queue, the wait time of the longest-waiting one. Falls to zero when the queue is empty. The classic wallboard ''Longest Wait'' indicator for immediate intervention.',
    "Comparison" = '''Average Wait Time'' is a daily average over completed items; this metric reflects only the present queue.',
    "StandardKpi" = 'Longest wait in queue (real-time)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.wait.curmax',
    "Channel" = 'calls_callbacks',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueCurMaxWaitTimeCallsAndCallbacks';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Current Max Wait Time — Chats',
    "ShortDescription" = 'Longest time a incoming chat interaction currently in queue has been waiting (right now).',
    "LongDescription" = 'Real-time metric: among incoming chat interactions currently waiting in queue, the wait time of the longest-waiting one. Falls to zero when the queue is empty. The classic wallboard ''Longest Wait'' indicator for immediate intervention.',
    "Comparison" = '''Average Wait Time'' is a daily average over completed items; this metric reflects only the present queue.',
    "StandardKpi" = 'Longest wait in queue (real-time)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.wait.curmax',
    "Channel" = 'chats',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueCurMaxWaitTimeChats';

UPDATE "RTSGrid_Metric" SET
    "DisplayName" = 'Current Max Wait Time — Digital Interactions',
    "ShortDescription" = 'Longest time a non-voice digital interactions (chat and e-mail) currently in queue has been waiting (right now).',
    "LongDescription" = 'Real-time metric: among non-voice digital interactions (chat and e-mail) currently waiting in queue, the wait time of the longest-waiting one. Falls to zero when the queue is empty. The classic wallboard ''Longest Wait'' indicator for immediate intervention.',
    "Comparison" = '''Average Wait Time'' is a daily average over completed items; this metric reflects only the present queue.',
    "StandardKpi" = 'Longest wait in queue (real-time)',
    "StandardRef" = 'ISO 18295-1:2017, Annex A (informative) — Metrics guidelines',
    "CatalogCategory" = 'Queue',
    "Family" = 'queue.wait.curmax',
    "Channel" = 'digital',
    "ThresholdSec" = NULL,
    "CatalogStatus" = 'active',
    "CatalogNotes" = NULL
WHERE "MetricId" = 'QueueCurMaxWaitTimeInteractions';

COMMIT;