# RTM Shell Metrics Overview

**Version 1.0 — 2026-06-05**
**Source:** `db/data/02_metrics.sql` (`RTSGrid_Metric` baseline, 202 metrics)
**Machine-readable companion:** `docs/metrics-catalog.json` (same content, structured for the dashboard-creation wizard and Viewer field help)

---

## 1. Purpose and intended use

This document is the consolidated catalogue of all real-time metrics available in the RTM View Shell
(`RTSGrid_Metric` table). It serves two product features:

1. **Dashboard-creation wizard** — guided metric search while configuring widgets: the editor narrows down
   by category → family → channel → threshold instead of scrolling through 200 raw entries.
2. **Viewer field help** — end users (Viewer role) can request an explanation of any widget field on a screen;
   the short and long descriptions in `docs/metrics-catalog.json` are the content source for those tooltips.

Each metric has a short description (one line, tooltip-ready), a detailed description (what is counted, when it
changes, what is excluded), comparison notes against similar metrics, and an industry/ISO mapping where applicable.

## 2. How a metric is defined

Every row of `RTSGrid_Metric` is a combination of:

| Field | Role |
|---|---|
| `MetricId` | Stable identifier referenced by grid cells and `Calc` formulas. Never shown to end users. |
| `Description` | Display name in metric dropdowns. Prefix encodes the category (`QM -`, `Agent Group -`, `Agent -`). |
| `MetricFunction` | What the engine computes (e.g. `InteractionsCount`, `WaitDurationAvg`, `UsersInStatusGroupCount`, `Calc`). |
| `MetricParameter` | How: a C# filter expression over interaction fields, a status (group) name, or a `Calc` formula referencing other metrics via `[MetricId]`. |
| `DataType` | Engine-internal: selects the interaction bag (`UsersInteraction` → agent-group interactions; anything else → queue interactions). **Ignored for agent-status counters** (verified in `RTM/RTM/Union.cs`). |
| `MetricFormat` | Format of the value as it arrives in the SignalR push (e.g. `##0.0%`). |
| `ValueType` | Shell-side filter behaviour: `number` / `time` / `text`. |
| `MetricType` | `Data` → Queue Grid / Data Slot widgets; `Agent` → Agent Grid widgets. |

**Evaluation model.** All Queue and Agent Group metrics are evaluated per **Business Unit (Union)** over the
current broadcasting day and pushed via SignalR whenever the underlying state changes. Agent metrics are
evaluated per agent. "Today" counters reset at midnight (`RTSData_MidnightClear`).

### 2.1 Filter-atom glossary (used in `MetricParameter` expressions)

| Atom | Meaning |
|---|---|
| `InteractionType=="Call" / "Callback" / "Chat" / "email" / "Dialer"` | Interaction channel. **Note:** metrics named "…Interactions" cover the digital pair `Chat + email` only. |
| `CallType=="External" / "Intercom"` | External (customer) vs internal call. |
| `Direction=="Incoming" / "Outgoing"` | Who initiated the interaction. |
| `IsAnswered` | Connected to an agent (set at the moment of answer, even if still in progress). |
| `IsAbandoned` | Left the queue without being answered. |
| `IsCallbackRequest` | Customer opted for a callback instead of waiting; excluded from abandoned counts and completed-volume denominators. |
| `IsInQueue` | Currently waiting in queue. |
| `IsTalk` | Currently being handled by an agent. |
| `TimeInQueue<N` | Queue wait below N seconds (Service-Level thresholds). |
| `TalkTime<N / >N` | Talk-phase duration bounds (short-call / long-call indicators). |
| `IsTransferred` | The call was transferred. |

## 3. Naming and semantic conventions

These conventions apply across the whole catalogue and are essential for choosing the right metric:

* **"Online" vs "Completed" vs "Waiting" vs "Active".**
  *Incoming Online* = everything received today **including** items still waiting.
  *Incoming Completed* = items whose queue phase has finished (answered or abandoned) — the standard percentage denominator.
  *Waiting* = current queue depth (snapshot). *Active* = currently in talk (snapshot).
* **Channels.** `Calls` (external voice), `Callbacks` (return calls), `CallsAndCallbacks` (combined voice load),
  `Chats`, `Interactions` = **digital pair: chat + e-mail** (not "all interaction types"!).
* **`…Inc` vs `…Ans` percent suffixes.** `Inc` = denominator is *incoming completed* (true Service Level — abandoned
  calls lower the result). `Ans` = denominator is *answered only* (speed profile of answered traffic; always ≥ the `Inc` value).
* **Status Group vs Agent State.** Group-level counters (`UsersInStatusGroupCount`, parameter `AVAILABLE`/`ONPHONE`/`BREAK`/`PAPERWORK`/`TRAINING`)
  cover **all** states mapped to the group. State-level counters (`UsersInStatusCount`, parameter e.g. `Break`, `Wrap Up`, `Missed Call`)
  count **one specific state** only. See `StateCount*` vs `QueueLoginDataNum*Users`.
* **Real-time snapshot vs daily cumulative.** `Cur*` / `*CurMax` / `Waiting` / `Active` / state counts = "now".
  Everything else accumulates since midnight.

## 4. Duplicate analysis

Exact duplicates = different `MetricId`, functionally identical computation. Engine evidence: status-count
functions iterate `Union.Users` and never read `DataType` (`RTM/RTM/Union.cs`, `getUsersInStatusGroupCount`,
`getLogedInUsersCount`); for interaction counters `DataType` only switches the interaction bag, and both members
of each pair below use the same bag.

| # | Duplicate (remove/fix) | Canonical (keep) | Evidence | Recommendation |
|---|---|---|---|---|
| 1 | `QueueNumAcceptedCallbacks` | `QueueNumAnsweredCallbacks` | Identical filter: incoming external callbacks, answered | Delete duplicate; canonical follows the `QueueNumAnswered{Ch}` family naming |
| 2 | `MonAgentNumberOfInboundCallsOnly` | `MonAgentNumberOfInboundCallsWithIntercom` | Identical predicates (same atoms, different order) | **Fix, don't delete:** drop `CallType=="Intercom"` from the *Only* filter so the metric matches its name ("External calls only") — restores a useful distinct metric |
| 3 | `QueueNumOnCallAgents` | `UsersSumOnCall` | Both `UsersInStatusGroupCount(ONPHONE)`; `DataType` ignored by engine | Delete duplicate |
| 4 | `QueueNumberOfLoggedAgents` | `QueueLoginDataNumLoggedUsers` | Both `LogedInUsersCount`; `DataType` ignored by engine | Delete duplicate; canonical is consistent with the `QueueLoginDataNum*Users` family |

**Cleanup procedure:** migration `db/migrations/20260605_004_metrics_dedup.sql` re-points references
(`RTSGrid_Cell.Value`, `RTSGrid_Column.MetricId`) to canonical metrics, deletes the three duplicates **and**
the confirmed-broken `QueuePctAnsweredCalls60secIncLast30min` (see §5), fixes the `InboundCallsOnly` filter,
the SLA-80 reference and the audited descriptions. Applied via CC (`tools/cc_prompt_metrics_dedup.md`):
pre-flight reference snapshot → apply → grep Shell/simulator code → `Export-All.ps1` (`db:` commit).
Post-cleanup catalogue size: **198 metrics** (202 − 3 duplicates − 1 broken Calc).
**Status: APPLIED 2026-06-05** — db commit `886dfe0`, web commit `2e72606` (seed entries + ASD widget updated).

## 5. Data-quality findings

Non-duplicate defects found during the audit:

| MetricId | Issue | Suggested fix |
|---|---|---|
| `QueueNumAnsweredCallbacks60sec` | Description says "Answered **Calls** in 60 sec" but the filter counts **Callbacks** | Fix Description |
| `QueueNumIcomingOnlineInteractions` | MetricId typo "Icoming"; also Description says "Interactions" while scope is chat + e-mail | Keep ID (referenced), fix Description; optionally add alias on next major cleanup |
| `QueuePctAnsweredCalls60secIncLast30min` | **CONFIRMED broken** (engine analysis, `Union.cs` Calc): after `[MetricId]` substitution the expression still contains the unresolved identifier `InQueueDateTime` and an invalid `double && bool` — `CompiledExpression.Eval()` throws every calc cycle, the metric is always empty and spams the error log. Rolling windows are not supported by the Calc mechanism | **Delete**; references re-pointed to `QueuePctAnsweredCalls60secInc` (migration `20260605_004`) |
| `QueueSLAIn30secFrom80PctInc` | **CONFIRMED broken** (engine analysis): Calc resolves `[refs]` via exact-match `AllDataMetrics.ContainsKey`; the trailing space in `[QueueNumAnsweredCalls30sec ]` makes the lookup fail, the reference is substituted with 0 and the metric always returns 0.00% | Trim the space (migration `20260605_004`) |
| `QueueLoginDataNumTrainingUsers` | `DataType="String"` anomaly (family uses `UsersSummary`); empty default columns | Normalise row |
| `MonAgentNumberOfInboundCallsDialer` | Description prefix "Agent Group" but `DataType="User"`; engine resolves it to the queue bag | Decide intended scope, normalise prefix/DataType |
| `MonAgentTodayLogin` | Description "Change -ID of a representative…" lacks the standard `Agent -` prefix | Fix Description |
| `MonAgentCurrentLoginTimeStamp` | **CONFIRMED dead** (engine inventory): `MetricFunction='CurLoginTimeStamp'` has no case in `UserManager.cs` (engine label is `CurLoginTimestamp`, switch is case-sensitive) — metric never produces a value | Set function to `CurLoginTimestamp` (next fix migration) |

Description typos (cosmetic, fix in the same pass): "Wpap Up" (`QueueNumWrapUpAgents`), "exluding" (5 × IncomingCompleted family),
"Otbound" (`MonSumAgentsMakeCalls`), "Oubound" (`MonAgentAverageMakeCallDuration`), "Cumlative" (`MonAgentTalkDurationPct`),
"Satatus" (`MonAgentState`), "Interction" (`MonAgentActiveInteractionId`), "Curently" (`QueueLoginDataNumLoggedUsers`).
Also note: `MonAgentNumMakeCallsInCompleted` counts **incoming** answered calls despite "MakeCalls" in the ID (historical; do not rename without reference migration).

## 6. Queue metrics (category `QM`)

All Queue metrics are Business-Unit-scoped, `MetricType = Data` (Queue Grid / Data Slot widgets).

### 6.1 Volume counters — channel matrix

Family functions: `InteractionsCount` (voice waiting counters) / `NumWaitings` (digital waiting counters — identical semantics).

| | Calls | Callbacks | Calls + Callbacks | Chats | Digital (chat + e-mail) |
|---|---|---|---|---|---|
| **Incoming today (incl. waiting)** | `QueueNumIncomingOnlineCalls` | `QueueNumIncomingOnlineCallbacks` | `QueueNumIncomingOnlineCallsAndCallbacks` | `QueueNumIncomingOnlineChats` | `QueueNumIcomingOnlineInteractions` |
| **Incoming today (excl. waiting)** | `QueueNumIncomingCompletedCalls` | `QueueNumIncomingCompletedCallbacks` | `QueueNumIncomingCompletedCallsAndCallbacks` | `QueueNumIncomingCompletedChats` | `QueueNumIncomingCompletedInteractions` |
| **Waiting now** | `QueueNumWaitingCalls` | `QueueNumWaitingCallbacks` | `QueueNumWaitingCallsAndCallbacks` | `QueueNumWaitingChats` | `QueueNumWaitingInteractions` |
| **Active now (in talk)** | `QueueNumActiveCalls` | `QueueNumActiveCallbacks` | `QueueNumActiveCallsAndCallbacks` | `QueueNumActiveChats` | `QueueNumActiveInteractions` |
| **Answered today** | `QueueNumAnsweredCalls` | `QueueNumAnsweredCallbacks` | `QueueNumAnsweredCallsAndCallbacks` | `QueueNumAnsweredChats` | `QueueNumAnsweredInteractions` |
| **Abandoned today** | `QueueNumAbandonedCalls` | `QueueNumAbandonedCallbacks` | `QueueNumAbandonedCallsAndCallbacks` | `QueueNumAbandonedChats` | `QueueNumAbandonedInteractions` |

**Reading the matrix.** Each row is one lifecycle slice; full set of definitions, comparisons and tooltips —
in `metrics-catalog.json` (families `queue.volume.*`). Key relations:
*Incoming incl. waiting* − *currently waiting* − *callback requests* ≈ *Incoming excl. waiting* = *Answered today* + *Abandoned today*.

### 6.2 Answered within threshold (Service-Level numerators)

| | Calls | Callbacks | Calls + Callbacks | Chats | Digital (chat + e-mail) |
|---|---|---|---|---|---|
| **Answered in 30 sec** | `QueueNumAnsweredCalls30sec` | `QueueNumAnsweredCallbacks30sec` | `QueueNumAnsweredCallsAndCallbacks30sec` | `QueueNumAnsweredChats30sec` | `QueueNumAnsweredInteractions30sec` |
| **Answered in 60 sec** | `QueueNumAnsweredCalls60sec` | `QueueNumAnsweredCallbacks60sec` | `QueueNumAnsweredCallsAndCallbacks60sec` | `QueueNumAnsweredChats60sec` | `QueueNumAnsweredInteractions60sec` |
| **Answered in 120 sec** | `QueueNumAnsweredCalls120sec` | `QueueNumAnsweredCallbacks120sec` | `QueueNumAnsweredCallsAndCallbacks120sec` | `QueueNumAnsweredChats120sec` | `QueueNumAnsweredInteractions120sec` |
| **Answered in 360 sec** | `QueueNumAnsweredCalls360sec` | — | — | — | — |

Only `Calls` has a 360-second variant; other channels stop at 120 seconds — gaps are intentional, add via one-time
migration only when a widget needs them (CLAUDE.md §1.5 of `rtsgrid-metric-reference.md`).

### 6.3 Percentages — totals

| | Calls | Callbacks | Calls + Callbacks | Chats | Digital (chat + e-mail) |
|---|---|---|---|---|---|
| **% Answered (of completed)** | `QueuePctAnsweredCallsTotal` | `QueuePctAnsweredCallbacksTotal` | `QueuePctAnsweredCallsAndCallbacksTotal` | `QueuePctAnsweredChatsTotal` | `QueuePctAnsweredInteractionsTotal` |
| **% Abandoned (of completed)** | `QueuePctAbandonedCallsTotal` | `QueuePctAbandonedCallbacksTotal` | `QueuePctAbandonedCallsAndCallbacksTotal` | `QueuePctAbandonedChatsTotal` | `QueuePctAbandonedInteractionsTotal` |

### 6.4 Percentages — Service Level (`…Inc`: of incoming completed)

| | Calls | Callbacks | Calls + Callbacks | Chats | Digital (chat + e-mail) |
|---|---|---|---|---|---|
| **% in 30 sec of incoming (Service Level)** | `QueuePctAnsweredCalls30secInc` | `QueuePctAnsweredCallbacks30secInc` | `QueuePctAnsweredCallsAndCallbacks30secInc` | `QueuePctAnsweredChats30secInc` | `QueuePctAnsweredInteractions30secInc` |
| **% in 60 sec of incoming (Service Level)** | `QueuePctAnsweredCalls60secInc` | `QueuePctAnsweredCallbacks60secInc` | `QueuePctAnsweredCallsAndCallbacks60secInc` | `QueuePctAnsweredChats60secInc` | `QueuePctAnsweredInteractions60secInc` |
| **% in 120 sec of incoming (Service Level)** | `QueuePctAnsweredCalls120secInc` | `QueuePctAnsweredCallbacks120secInc` | `QueuePctAnsweredCallsAndCallbacks120secInc` | `QueuePctAnsweredChats120secInc` | `QueuePctAnsweredInteractions120secInc` |
| **% in 360 sec of incoming (Service Level)** | `QueuePctAnsweredCalls360secInc` | — | — | — | — |

This family is the **Service Level / Telephone Service Factor (TSF)**: "X% of contacts answered within N seconds".
Abandoned contacts remain in the denominator.

### 6.5 Percentages — speed profile (`…Ans`: of answered)

| | Calls | Callbacks | Calls + Callbacks | Chats | Digital (chat + e-mail) |
|---|---|---|---|---|---|
| **% in 30 sec of answered** | `QueuePctAnsweredCalls30secAns` | `QueuePctAnsweredCallbacks30secAns` | `QueuePctAnsweredCallsAndCallbacks30secAns` | `QueuePctAnsweredChats30secAns` | `QueuePctAnsweredInteractions30secAns` |
| **% in 60 sec of answered** | `QueuePctAnsweredCalls60secAns` | `QueuePctAnsweredCallbacks60secAns` | `QueuePctAnsweredCallsAndCallbacks60secAns` | `QueuePctAnsweredChats60secAns` | `QueuePctAnsweredInteractions60secAns` |
| **% in 120 sec of answered** | `QueuePctAnsweredCalls120secAns` | `QueuePctAnsweredCallbacks120secAns` | `QueuePctAnsweredCallsAndCallbacks120secAns` | `QueuePctAnsweredChats120secAns` | `QueuePctAnsweredInteractions120secAns` |

Always ≥ the corresponding `Inc` value; measures answering speed of answered traffic, not service accessibility.
Use `Inc` for SLA reporting, `Ans` for operational speed analysis.

### 6.6 Special answer-rate variants (Calls)

| MetricId | Name | Short description |
|---|---|---|
| `QueueBaseAnsweredPct` | Base Answered % (of all incoming) | Answered calls divided by ALL incoming calls today, including those still waiting. |
| `QueueExclCallbackReqAnsweredPct` | Answered % excl. Callback Requests | Answered calls divided by incoming calls minus callback requests. |
| `QueueInclCallbackReqAnsweredPct` | Answered % incl. Callback Requests | Answered calls plus callback requests, divided by all incoming calls. |
| `QueueInclCompCallbacksAnsweredPct` | Answered % incl. Completed Callbacks | Answered calls plus completed callbacks, divided by all incoming calls. |
| `QueuePctAnsweredCalls60secIncLast30min` | % Answered Calls in 60 sec — Last 30 min | Service Level (60-sec target) intended to cover only the last 30 minutes. |
| `QueueSLAIn30secFrom80PctInc` | SLA: % Answered in 30 sec vs 80% Target | Answered-in-30-sec calls divided by 80% of incoming completed calls — progress against an 80/30 SLA. |

### 6.7 Wait and talk times — channel matrix

| | Calls | Callbacks | Calls + Callbacks | Chats | Digital (chat + e-mail) |
|---|---|---|---|---|---|
| **Current max wait (now)** | `QueueCurMaxWaitTimeCalls` | `QueueCurMaxWaitTimeCallbacks` | `QueueCurMaxWaitTimeCallsAndCallbacks` | `QueueCurMaxWaitTimeChats` | `QueueCurMaxWaitTimeInteractions` |
| **Average wait (today)** | `QueueAvgWaitTimeCalls` | `QueueAvgWaitTimeCallbacks` | `QueueAvgWaitTimeCallsAndCallbacks` | `QueueAvgWaitTimeChats` | `QueueAvgWaitTimeInteractions` |
| **Average time to abandon** | `QueueAvgTimeToAbandCalls` | `QueueAvgTimeToAbandCallbacks` | `QueueAvgTimeToAbandCallsAndCallbacks` | `QueueAvgTimeToAbandChats` | `QueueAvgTimeToAbandInteractions` |
| **Average talk duration** | `QueueAvgTalkingDurationCalls` | `QueueAvgTalkingDurationCallbacks` | `QueueAvgTalkingDurationCallsAndCallbacks` | `QueueAvgTalkingDurationChats` | `QueueAvgTalkingDurationInteractions` |

**ASA caveat:** `QueueAvgWaitTime*` averages the queue wait of **completed** items (answered *and* abandoned), so it is
slightly broader than the classic ASA (answered only). The difference is negligible at low abandonment.

### 6.8 Messaging response times

| MetricId | Name | Short description |
|---|---|---|
| `MessagesAvgFirstResponseTime` | Avg First Response Time (messages) | Average time to the first agent reply in messaging channels today. |
| `MessagesAvgResponseTime` | Avg Response Time (messages) | Average agent response time to customer messages today (all replies). |
| `MessagesMaxFirstResponseTime` | Max First Response Time (messages) | Longest first-response time to an incoming message today. |

### 6.9 Queue staffing and throughput

| MetricId | Name | Short description |
|---|---|---|
| `QueueCPH` | Calls per Hour (queue) | Incoming call throughput of the queue, normalised per hour. |
| `QueueNumOnCallAgents` | On Call Agents (duplicate) | Duplicate of "Number of On Call Agents" (UsersSumOnCall) — identical definition. |
| `QueueNumWrapUpAgents` | Agents in Wrap Up | Number of agents of this Business Unit currently in Wrap Up status. |
| `QueueNumberOfLoggedAgents` | Logged In Agents (duplicate) | Duplicate of "Number of Currently Logged in Users" — identical definition. |

### 6.10 Other queue counters

| MetricId | Name | Short description |
|---|---|---|
| `QueueNumCallbackRequests` | Callback Requests | Number of incoming interactions converted to a callback request today. |
| `QueueNumCompletedCallbacks` | Completed Callbacks | Number of callbacks successfully completed (dialled back and connected) today. |
| `QueueNumIncomingHandledInteractions` | Completed Incoming Digital Interactions | Number of incoming digital interactions (chat + e-mail) fully finished today: not waiting, not active, not abandoned. |
| `QueueNumOnlineChats` | Chats Today (all) | Total number of chat interactions registered today (any direction, any state). |
| `QueueNumOutboundCalls` | Outbound Calls | Number of outgoing external calls today. |
| `QueueNumTransferredCalls` | Transferred Calls | Number of incoming calls transferred today. |

## 7. Agent Group metrics (category `Agent Group`)

Aggregates over the agents of the Business Unit; `MetricType = Data`.

### 7.1 Status counts — group level vs state level

Group-level (`UsersInStatusGroupCount` — covers **all** states mapped to the group):

| MetricId | Name | Short description |
|---|---|---|
| `QueueLoginDataNumAvailableUsers` | Agents Available (group) | Number of agents currently in the AVAILABLE status group. |
| `QueueLoginDataNumBreakUsers` | Agents in Break Group | Number of agents currently in any Break-group state. |
| `QueueLoginDataNumLoggedUsers` | Agents Logged In | Number of agents of the Business Unit currently logged in. |
| `QueueLoginDataNumPaperworkUsers` | Agents in Paperwork Group | Number of agents currently in any Paperwork-group state (ACW/back-office). |
| `QueueLoginDataNumTrainingUsers` | Agents in Training Group | Number of agents currently in any Training-group state. |
| `UsersSumOnCall` | Agents On Call | Number of agents currently in the ONPHONE status group (handling an interaction). |

State-level (`UsersInStatusCount` — **one specific** Agent State only):

| MetricId | Name | Short description |
|---|---|---|
| `MonSumAgentsInMissedCall` | Agents in "Missed Call" State | Number of agents currently in the "Missed Call" state. |
| `StateCountAvailable` | Agents in "Available" State | Number of agents currently in the specific "Available" Agent State. |
| `StateCountBreak` | Agents in "Break" State | Number of agents currently in the specific "Break" Agent State. |
| `StateCountOnPhone` | Agents in "On Phone" State | Number of agents currently in the specific "On Phone" Agent State. |
| `StateCountPaperwork` | Agents in "Paperwork" State | Number of agents currently in the specific "Paperwork" Agent State. |
| `StateCountTraining` | Agents in "Training" State | Number of agents currently in the specific "Training" Agent State. |

> Rule of thumb for the wizard: dashboards about *capacity* use group-level counts; dashboards about
> *specific behaviours* (e.g. who is exactly in "Missed Call") use state-level counts.

### 7.2 Duration and shrinkage aggregates

| MetricId | Name | Short description |
|---|---|---|
| `MonSumAgentsBreakDurationMax` | Max Current Break Duration (group) | Longest time any agent of the group has currently been in a Break-group state. |
| `MonSumAgentsBreakDurationPercent` | % Time in Break Group (group) | Share of the group’s logged-in time spent in Break-group states. |
| `MonSumAgentsPaperworkDurationPercent` | % Time in Paperwork Group (group) | Share of the group’s logged-in time spent in Paperwork-group states. |

### 7.3 Group interaction aggregates

| MetricId | Name | Short description |
|---|---|---|
| `MonAgentNumberOfInboundCallsDialer` | Dialer Calls | Number of incoming dialer (campaign) interactions today. |
| `MonSumAgentsAnsweredCalls` | Answered Calls + Callbacks (group) | Number of incoming calls and callbacks answered and completed by agents of this group today. |
| `MonSumAgentsAverageCallDuration` | Avg Talk Duration — Calls+Callbacks (group) | Average talk duration of incoming calls and callbacks completed by this group today. |
| `MonSumAgentsAverageChatDuration` | Avg Talk Duration — Chats (group) | Average handling duration of incoming chats completed by this group today. |
| `MonSumAgentsLongestCurrentCall` | Longest Current Call (group) | Duration of the longest interaction currently being handled by an agent of this group. |
| `MonSumAgentsMakeCalls` | Outbound Calls (group) | Number of outgoing external interactions made by agents of this group today. |

These are computed over the **agent-group interaction bag** (`DataType = UsersInteraction`): interactions are
attributed to the BU through its agents, slightly different from the queue-side counters which attribute through queues.

## 8. Agent metrics (category `Agent`)

Per-agent metrics for Agent Grid widgets; `MetricType = Agent`.

### 8.1 Interaction counters

| MetricId | Name | Short description |
|---|---|---|
| `MonAgentNumChatsActive` | Active Chats (agent) | Number of chats the agent is handling right now. |
| `MonAgentNumChatsCompleted` | Answered Chats (agent) | Number of incoming chats the agent answered and finished today. |
| `MonAgentNumMakeCallsInCompleted` | Answered Incoming Calls (agent) | Number of incoming calls/callbacks the agent answered and finished today. |
| `MonAgentNumberOfConsultCalls` | Consultation Calls (agent) | Number of consultation calls the agent made today. |
| `MonAgentNumberOfInboundCalls10Min` | Long Calls > 10 min (agent) | Number of incoming calls the agent handled with talk time over 10 minutes today. |
| `MonAgentNumberOfInboundCalls15sec` | Short Calls < 15 sec (agent) | Number of incoming calls the agent handled with talk time under 15 seconds today. |
| `MonAgentNumberOfInboundCallsOnly` | Incoming External Calls (agent) — DEFECT | Intended: incoming external calls only. Actual: identical to the External+Internal metric (filter bug). |
| `MonAgentNumberOfInboundCallsWithIntercom` | Incoming Calls — External + Internal (agent) | Number of incoming calls and callbacks the agent received today, external and internal. |
| `MonAgentNumberOfMakeCalls` | Outbound Calls (agent) | Number of outgoing external calls the agent made today. |
| `MonAgentOutgoingCallbacksNum` | Outgoing Callbacks (agent) | Number of callback return-calls the agent completed today. |
| `MonAgentProxyCallsNum` | Incoming Callbacks (agent) | Number of incoming callback interactions the agent answered today. |
| `UserCPH` | Calls per Hour (agent) | Incoming calls handled by the agent per hour. |
| `UserNumAllIntercom` | Internal Calls (agent) | Number of internal (intercom) calls involving the agent today. |
| `UserNumMissedCalls` | Missed Calls (agent) | Number of times the agent missed a routed interaction today. |

### 8.2 Durations and timers

| MetricId | Name | Short description |
|---|---|---|
| `AgentMessagesAvgFirstResponseTime` | Avg First Response Time — messages (agent) | Average time to the agent’s first reply in messaging conversations today. |
| `AgentMessagesAvgResponseTime` | Avg Response Time — messages (agent) | Average reply time of the agent to customer messages today. |
| `MonAgentAvailableDuration` | Available State Duration | Total time the agent spent in AVAILABLE-group states today. |
| `MonAgentAverageAgentDialerDuration` | Average Dialer Call Duration (agent) | Average duration of the agent’s dialer (campaign) calls today. |
| `MonAgentAverageCallDuration` | Average Handling Duration (agent) | Average duration of one ONPHONE engagement of the agent today. |
| `MonAgentAverageInboundCallDuration` | Average Incoming Call Duration (agent) | Average talk duration of incoming calls/callbacks completed by the agent today. |
| `MonAgentAverageMakeCallDuration` | Average Outbound Call Duration (agent) | Average duration of the agent’s outbound calls today. |
| `MonAgentBreakDuration` | Cumulative Break Duration | Total time the agent spent in BREAK-group states today. |
| `MonAgentCurrentLoginDuration` | Current Login Duration | Time since the agent’s current login. |
| `MonAgentDurationOfCalls` | Cumulative Incoming Call Duration | Total time the agent spent on incoming external calls today. |
| `MonAgentDurationOfCurrentCall` | Current Incoming Call Duration | Duration of the incoming external call the agent is handling right now. |
| `MonAgentHeldDuration` | Cumulative Hold Duration | Total time the agent kept customers on hold today. |
| `MonAgentLoginTime` | Cumulative Login Duration | Total logged-in time of the agent today (all sessions). |
| `MonAgentMaxCallDuration` | Max Call Duration (agent) | Longest talk time of a single incoming call of the agent today. |
| `MonAgentPaperworkDuration` | Cumulative Paperwork Duration | Total time the agent spent in PAPERWORK-group states today. |
| `MonAgentStateDescDuration` | Current Status Group Duration | How long the agent has been in the current status GROUP. |
| `MonAgentStateDuration` | Current Status Duration | How long the agent has been in the current status. |
| `MonAgentTalkDuration` | Cumulative Talk Duration | Total time the agent spent in ONPHONE-group states today. |
| `MonAgentTelStateDuration` | Active Interaction State Duration | How long the agent’s longest active interaction has been in its current state. |
| `MonAgentUnavailableStateDuration` | Cumulative Unavailable Duration | Total time the agent spent in the "Unavailable" state today. |
| `MonAgentWrapUpDuration` | Cumulative Wrap Up Duration | Total time the agent spent in the "Wrap Up" state today. |

### 8.3 Percent-of-login metrics

| MetricId | Name | Short description |
|---|---|---|
| `MonAgentAvailableDurationPct` | % Available Time of Login | Share of the agent’s login time spent in AVAILABLE states today. |
| `MonAgentBreakDurationPct` | % Break Time of Login | Share of the agent’s login time spent in BREAK states today. |
| `MonAgentPaperworkDurationPct` | % Paperwork Time of Login | Share of the agent’s login time spent in PAPERWORK states today. |
| `MonAgentTalkDurationPct` | % Talk Time of Login | Share of the agent’s login time spent in ONPHONE states today. |
| `MonAgentTrainingDurationPct` | % Training Time of Login | Share of the agent’s login time spent in TRAINING states today. |

All five use `TotalStatusGroupPercent`: cumulative group time ÷ total login time today. Together they decompose
an agent's paid day; `% Talk` is the practical occupancy proxy.

### 8.4 Identity and live-state attributes (`text`)

| MetricId | Name | Short description |
|---|---|---|
| `AgentLoginName` | Login Name | Display/login name of the agent. |
| `MonActiveCampaign` | Active Interaction Queue | Queue (workgroup) name of the agent’s longest active interaction. |
| `MonAgentActiveInteractionId` | Active Interaction ID | Identifier of the agent’s longest active interaction. |
| `MonAgentCurrentLoginTimeStamp` | Current Login Time | Timestamp of the agent’s current login. |
| `MonAgentExtension` | Extension | Telephony extension of the agent. |
| `MonAgentFirstLoginTimeStamp` | First Login Time | Timestamp of the agent’s first login today. |
| `MonAgentState` | Current Status | Name of the agent’s current status. |
| `MonAgentStateDesc` | Current Status Group | Status group of the agent’s current status. |
| `MonAgentStation` | Station ID | Workstation/phone station identifier of the agent. |
| `MonAgentTelState` | Active Interaction State | State of the agent’s longest active interaction. |
| `MonAgentTodayLogin` | Logged In Today (flag) | Flag/ID indicating the agent logged in today. |
| `MonAgentUserId` | User ID | Platform user identifier of the agent. |
| `MonInteractionType` | Active Interaction Type | Type (Call/Chat/...) of the agent’s longest active interaction. |
| `RemotePhoneNumber` | Customer Phone Number | Customer phone number of the agent’s longest active interaction. |

`RemotePhoneNumber` is PII — apply masking policy in widgets where required.

## 9. ISO and industry-standard mapping

ISO 18295-1:2017 ("Customer contact centres — Part 1: Requirements") requires CCC leadership and the client to
agree performance measures and lists recommended metrics in **Annex A (informative, "Metrics — Guidelines")**.
The standard does not prescribe formulas, so the mapping below links RTM metric families to the metric *areas* of
Annex A and to the de-facto industry KPI vocabulary (COPC and common WFM practice):

| RTM family / metric | Industry KPI | Standard anchor |
|---|---|---|
| `queue.pct.answered_threshold_inc` (`QueuePctAnswered*secInc`) | **Service Level / TSF** | ISO 18295-1 Annex A — service accessibility |
| `queue.pct.abandoned_total` | **Abandonment Rate** | ISO 18295-1 Annex A — service accessibility |
| `queue.pct.answered_total` | Answer Rate | ISO 18295-1 Annex A — service accessibility |
| `queue.wait.avg` | ≈ **ASA** (see §6.7 caveat) | ISO 18295-1 Annex A — service accessibility |
| `queue.wait.curmax` | Longest Wait (real-time ops) | — (operational practice) |
| `queue.abandon.time_avg` | Average Time to Abandon (ATA) | — (operational practice) |
| `queue.talk.avg`, `MonAgentAverageInboundCallDuration` | **ATT**, component of **AHT** | ISO 18295-1 Annex A — efficiency |
| `MonAgentAverageCallDuration` (+ hold, wrap-up durations) | **AHT** decomposition | ISO 18295-1 Annex A — efficiency |
| `queue.messages` / `AgentMessages*` | **First Response Time (FRT)**, Response Time | ISO 18295-1 Annex A — service accessibility (digital) |
| `MonAgentTalkDurationPct` | **Occupancy** (proxy) | ISO 18295-1 Annex A — efficiency |
| `MonAgentLoginTime`, `MonAgentCurrentLoginDuration` | Adherence support data | ISO 18295-1 §7.3 Workforce planning |
| `QueueCPH`, `UserCPH` | Contacts per Hour | — (productivity practice) |
| `QueueNumTransferredCalls` | Transfer Rate input (FCR proxy) | ISO 18295-1 Annex A — quality |
| Employee-related metrics (not in RTM scope) | Employee satisfaction (Annex A metric 9) | ISO 18295-1 §5.3 |

When a client asks "are these metrics ISO-aligned" — the correct claim is: *the RTM catalogue provides the
quantitative inputs recommended by ISO 18295-1 Annex A for service accessibility, efficiency and workforce
planning; targets and review cadences remain a client/CCC agreement as the standard requires (§5.2).*

## 10. Using this catalogue

**Wizard flow (stage 2 of this project):** category → family → channel → threshold/denominator → metric.
`metrics-catalog.json` carries `family`, `channel`, `thresholdSec`, `similarMetrics`, `standardKpi` for exactly
this drill-down, plus `status` so the wizard can hide `duplicate` rows and warn on `defect-candidate` ones.

**Viewer field help:** `shortDescription` = tooltip; `longDescription` + `comparison` = expanded help panel.
Descriptions never reference MetricIds in user-visible text except in the comparison notes, which the help panel
may render as "related fields".

---

## Appendix A. Full A–Z metric index

| MetricId | Display name | Family | Value | Type | Status |
|---|---|---|---|---|---|
| `AgentLoginName` | Login Name | agent.identity | text | Agent | active |
| `AgentMessagesAvgFirstResponseTime` | Avg First Response Time — messages (agent) | agent.duration | time | Agent | active |
| `AgentMessagesAvgResponseTime` | Avg Response Time — messages (agent) | agent.duration | time | Agent | active |
| `MessagesAvgFirstResponseTime` | Avg First Response Time (messages) | queue.messages | time | Data | active |
| `MessagesAvgResponseTime` | Avg Response Time (messages) | queue.messages | time | Data | active |
| `MessagesMaxFirstResponseTime` | Max First Response Time (messages) | queue.messages | time | Data | active |
| `MonActiveCampaign` | Active Interaction Queue | agent.identity | text | Agent | active |
| `MonAgentActiveInteractionId` | Active Interaction ID | agent.identity | text | Agent | active |
| `MonAgentAvailableDuration` | Available State Duration | agent.duration | time | Agent | active |
| `MonAgentAvailableDurationPct` | % Available Time of Login | agent.percent | number | Agent | active |
| `MonAgentAverageAgentDialerDuration` | Average Dialer Call Duration (agent) | agent.duration | time | Agent | active |
| `MonAgentAverageCallDuration` | Average Handling Duration (agent) | agent.duration | time | Agent | active |
| `MonAgentAverageInboundCallDuration` | Average Incoming Call Duration (agent) | agent.duration | time | Agent | active |
| `MonAgentAverageMakeCallDuration` | Average Outbound Call Duration (agent) | agent.duration | time | Agent | active |
| `MonAgentBreakDuration` | Cumulative Break Duration | agent.duration | time | Agent | active |
| `MonAgentBreakDurationPct` | % Break Time of Login | agent.percent | number | Agent | active |
| `MonAgentCurrentLoginDuration` | Current Login Duration | agent.duration | time | Agent | active |
| `MonAgentCurrentLoginTimeStamp` | Current Login Time | agent.identity | text | Agent | active |
| `MonAgentDurationOfCalls` | Cumulative Incoming Call Duration | agent.duration | time | Agent | active |
| `MonAgentDurationOfCurrentCall` | Current Incoming Call Duration | agent.duration | time | Agent | active |
| `MonAgentExtension` | Extension | agent.identity | text | Agent | active |
| `MonAgentFirstLoginTimeStamp` | First Login Time | agent.identity | text | Agent | active |
| `MonAgentHeldDuration` | Cumulative Hold Duration | agent.duration | time | Agent | active |
| `MonAgentLoginTime` | Cumulative Login Duration | agent.duration | time | Agent | active |
| `MonAgentMaxCallDuration` | Max Call Duration (agent) | agent.duration | time | Agent | active |
| `MonAgentNumberOfConsultCalls` | Consultation Calls (agent) | agent.counters | number | Agent | active |
| `MonAgentNumberOfInboundCalls10Min` | Long Calls > 10 min (agent) | agent.counters | number | Agent | active |
| `MonAgentNumberOfInboundCalls15sec` | Short Calls < 15 sec (agent) | agent.counters | number | Agent | active |
| `MonAgentNumberOfInboundCallsDialer` | Dialer Calls | group.interactions | number | Data ⚠ defect-candidate | defect-candidate |
| `MonAgentNumberOfInboundCallsOnly` | Incoming External Calls (agent) — DEFECT | agent.counters | number | Agent ⚠ duplicate | duplicate |
| `MonAgentNumberOfInboundCallsWithIntercom` | Incoming Calls — External + Internal (agent) | agent.counters | number | Agent | active |
| `MonAgentNumberOfMakeCalls` | Outbound Calls (agent) | agent.counters | number | Agent | active |
| `MonAgentNumChatsActive` | Active Chats (agent) | agent.counters | number | Agent | active |
| `MonAgentNumChatsCompleted` | Answered Chats (agent) | agent.counters | number | Agent | active |
| `MonAgentNumMakeCallsInCompleted` | Answered Incoming Calls (agent) | agent.counters | number | Agent | active |
| `MonAgentOutgoingCallbacksNum` | Outgoing Callbacks (agent) | agent.counters | number | Agent | active |
| `MonAgentPaperworkDuration` | Cumulative Paperwork Duration | agent.duration | time | Agent | active |
| `MonAgentPaperworkDurationPct` | % Paperwork Time of Login | agent.percent | number | Agent | active |
| `MonAgentProxyCallsNum` | Incoming Callbacks (agent) | agent.counters | number | Agent | active |
| `MonAgentState` | Current Status | agent.identity | text | Agent | active |
| `MonAgentStateDesc` | Current Status Group | agent.identity | text | Agent | active |
| `MonAgentStateDescDuration` | Current Status Group Duration | agent.duration | time | Agent | active |
| `MonAgentStateDuration` | Current Status Duration | agent.duration | time | Agent | active |
| `MonAgentStation` | Station ID | agent.identity | text | Agent | active |
| `MonAgentTalkDuration` | Cumulative Talk Duration | agent.duration | time | Agent | active |
| `MonAgentTalkDurationPct` | % Talk Time of Login | agent.percent | number | Agent | active |
| `MonAgentTelState` | Active Interaction State | agent.identity | text | Agent | active |
| `MonAgentTelStateDuration` | Active Interaction State Duration | agent.duration | time | Agent | active |
| `MonAgentTodayLogin` | Logged In Today (flag) | agent.identity | text | Agent ⚠ defect-candidate | defect-candidate |
| `MonAgentTrainingDurationPct` | % Training Time of Login | agent.percent | number | Agent | active |
| `MonAgentUnavailableStateDuration` | Cumulative Unavailable Duration | agent.duration | time | Agent | active |
| `MonAgentUserId` | User ID | agent.identity | text | Agent | active |
| `MonAgentWrapUpDuration` | Cumulative Wrap Up Duration | agent.duration | time | Agent | active |
| `MonInteractionType` | Active Interaction Type | agent.identity | text | Agent | active |
| `MonSumAgentsAnsweredCalls` | Answered Calls + Callbacks (group) | group.interactions | number | Data | active |
| `MonSumAgentsAverageCallDuration` | Avg Talk Duration — Calls+Callbacks (group) | group.interactions | time | Data | active |
| `MonSumAgentsAverageChatDuration` | Avg Talk Duration — Chats (group) | group.interactions | time | Data | active |
| `MonSumAgentsBreakDurationMax` | Max Current Break Duration (group) | group.duration | number | Data | active |
| `MonSumAgentsBreakDurationPercent` | % Time in Break Group (group) | group.duration | number | Data | active |
| `MonSumAgentsInMissedCall` | Agents in "Missed Call" State | group.state_count | number | Data | active |
| `MonSumAgentsLongestCurrentCall` | Longest Current Call (group) | group.interactions | time | Data | active |
| `MonSumAgentsMakeCalls` | Outbound Calls (group) | group.interactions | number | Data | active |
| `MonSumAgentsPaperworkDurationPercent` | % Time in Paperwork Group (group) | group.duration | number | Data | active |
| `QueueAvgTalkingDurationCallbacks` | Average Talk Duration — Callbacks | queue.talk.avg | time | Data | active |
| `QueueAvgTalkingDurationCalls` | Average Talk Duration — Calls | queue.talk.avg | time | Data | active |
| `QueueAvgTalkingDurationCallsAndCallbacks` | Average Talk Duration — Calls + Callbacks | queue.talk.avg | time | Data | active |
| `QueueAvgTalkingDurationChats` | Average Talk Duration — Chats | queue.talk.avg | time | Data | active |
| `QueueAvgTalkingDurationInteractions` | Average Talk Duration — Digital Interactions | queue.talk.avg | time | Data | active |
| `QueueAvgTimeToAbandCallbacks` | Average Time to Abandon — Callbacks | queue.abandon.time_avg | time | Data | active |
| `QueueAvgTimeToAbandCalls` | Average Time to Abandon — Calls | queue.abandon.time_avg | time | Data | active |
| `QueueAvgTimeToAbandCallsAndCallbacks` | Average Time to Abandon — Calls + Callbacks | queue.abandon.time_avg | time | Data | active |
| `QueueAvgTimeToAbandChats` | Average Time to Abandon — Chats | queue.abandon.time_avg | time | Data | active |
| `QueueAvgTimeToAbandInteractions` | Average Time to Abandon — Digital Interactions | queue.abandon.time_avg | time | Data | active |
| `QueueAvgWaitTimeCallbacks` | Average Wait Time — Callbacks | queue.wait.avg | time | Data | active |
| `QueueAvgWaitTimeCalls` | Average Wait Time — Calls | queue.wait.avg | time | Data | active |
| `QueueAvgWaitTimeCallsAndCallbacks` | Average Wait Time — Calls + Callbacks | queue.wait.avg | time | Data | active |
| `QueueAvgWaitTimeChats` | Average Wait Time — Chats | queue.wait.avg | time | Data | active |
| `QueueAvgWaitTimeInteractions` | Average Wait Time — Digital Interactions | queue.wait.avg | time | Data | active |
| `QueueBaseAnsweredPct` | Base Answered % (of all incoming) | queue.pct.special | number | Data | active |
| `QueueCPH` | Calls per Hour (queue) | queue.staffing | number | Data | active |
| `QueueCurMaxWaitTimeCallbacks` | Current Max Wait Time — Callbacks | queue.wait.curmax | time | Data | active |
| `QueueCurMaxWaitTimeCalls` | Current Max Wait Time — Calls | queue.wait.curmax | time | Data | active |
| `QueueCurMaxWaitTimeCallsAndCallbacks` | Current Max Wait Time — Calls + Callbacks | queue.wait.curmax | time | Data | active |
| `QueueCurMaxWaitTimeChats` | Current Max Wait Time — Chats | queue.wait.curmax | time | Data | active |
| `QueueCurMaxWaitTimeInteractions` | Current Max Wait Time — Digital Interactions | queue.wait.curmax | time | Data | active |
| `QueueExclCallbackReqAnsweredPct` | Answered % excl. Callback Requests | queue.pct.special | number | Data | active |
| `QueueInclCallbackReqAnsweredPct` | Answered % incl. Callback Requests | queue.pct.special | number | Data | active |
| `QueueInclCompCallbacksAnsweredPct` | Answered % incl. Completed Callbacks | queue.pct.special | number | Data | active |
| `QueueLoginDataNumAvailableUsers` | Agents Available (group) | group.state_group_count | number | Data | active |
| `QueueLoginDataNumBreakUsers` | Agents in Break Group | group.state_group_count | number | Data | active |
| `QueueLoginDataNumLoggedUsers` | Agents Logged In | group.state_group_count | number | Data | active |
| `QueueLoginDataNumPaperworkUsers` | Agents in Paperwork Group | group.state_group_count | number | Data | active |
| `QueueLoginDataNumTrainingUsers` | Agents in Training Group | group.state_group_count | number | Data ⚠ defect-candidate | defect-candidate |
| `QueueNumAbandonedCallbacks` | Abandoned Callbacks | queue.volume.abandoned | number | Data | active |
| `QueueNumAbandonedCalls` | Abandoned Calls | queue.volume.abandoned | number | Data | active |
| `QueueNumAbandonedCallsAndCallbacks` | Abandoned Calls + Callbacks | queue.volume.abandoned | number | Data | active |
| `QueueNumAbandonedChats` | Abandoned Chats | queue.volume.abandoned | number | Data | active |
| `QueueNumAbandonedInteractions` | Abandoned Digital Interactions | queue.volume.abandoned | number | Data | active |
| `QueueNumAcceptedCallbacks` | Accepted Callbacks (duplicate) | queue.volume.answered | number | Data ⚠ duplicate | duplicate |
| `QueueNumActiveCallbacks` | Active Callbacks | queue.volume.active | number | Data | active |
| `QueueNumActiveCalls` | Active Calls | queue.volume.active | number | Data | active |
| `QueueNumActiveCallsAndCallbacks` | Active Calls + Callbacks | queue.volume.active | number | Data | active |
| `QueueNumActiveChats` | Active Chats | queue.volume.active | number | Data | active |
| `QueueNumActiveInteractions` | Active Digital Interactions | queue.volume.active | number | Data | active |
| `QueueNumAnsweredCallbacks` | Answered Callbacks | queue.volume.answered | number | Data | active |
| `QueueNumAnsweredCallbacks120sec` | Answered Callbacks in 120 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredCallbacks30sec` | Answered Callbacks in 30 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredCallbacks60sec` | Answered Callbacks in 60 sec | queue.volume.answered_threshold | number | Data ⚠ defect-candidate | defect-candidate |
| `QueueNumAnsweredCalls` | Answered Calls | queue.volume.answered | number | Data | active |
| `QueueNumAnsweredCalls120sec` | Answered Calls in 120 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredCalls30sec` | Answered Calls in 30 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredCalls360sec` | Answered Calls in 360 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredCalls60sec` | Answered Calls in 60 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredCallsAndCallbacks` | Answered Calls + Callbacks | queue.volume.answered | number | Data | active |
| `QueueNumAnsweredCallsAndCallbacks120sec` | Answered Calls + Callbacks in 120 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredCallsAndCallbacks30sec` | Answered Calls + Callbacks in 30 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredCallsAndCallbacks60sec` | Answered Calls + Callbacks in 60 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredChats` | Answered Chats | queue.volume.answered | number | Data | active |
| `QueueNumAnsweredChats120sec` | Answered Chats in 120 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredChats30sec` | Answered Chats in 30 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredChats60sec` | Answered Chats in 60 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredInteractions` | Answered Digital Interactions | queue.volume.answered | number | Data | active |
| `QueueNumAnsweredInteractions120sec` | Answered Digital Interactions in 120 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredInteractions30sec` | Answered Digital Interactions in 30 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumAnsweredInteractions60sec` | Answered Digital Interactions in 60 sec | queue.volume.answered_threshold | number | Data | active |
| `QueueNumberOfLoggedAgents` | Logged In Agents (duplicate) | queue.staffing | number | Data ⚠ duplicate | duplicate |
| `QueueNumCallbackRequests` | Callback Requests | queue.volume.misc | number | Data | active |
| `QueueNumCompletedCallbacks` | Completed Callbacks | queue.volume.misc | number | Data | active |
| `QueueNumIcomingOnlineInteractions` | Incoming Digital Interactions Today (incl. waiting) | queue.volume.incoming_online | number | Data ⚠ defect-candidate | defect-candidate |
| `QueueNumIncomingCompletedCallbacks` | Incoming Callbacks Today (excl. waiting) | queue.volume.incoming_completed | number | Data | active |
| `QueueNumIncomingCompletedCalls` | Incoming Calls Today (excl. waiting) | queue.volume.incoming_completed | number | Data | active |
| `QueueNumIncomingCompletedCallsAndCallbacks` | Incoming Calls + Callbacks Today (excl. waiting) | queue.volume.incoming_completed | number | Data | active |
| `QueueNumIncomingCompletedChats` | Incoming Chats Today (excl. waiting) | queue.volume.incoming_completed | number | Data | active |
| `QueueNumIncomingCompletedInteractions` | Incoming Digital Interactions Today (excl. waiting) | queue.volume.incoming_completed | number | Data | active |
| `QueueNumIncomingHandledInteractions` | Completed Incoming Digital Interactions | queue.volume.misc | number | Data | active |
| `QueueNumIncomingOnlineCallbacks` | Incoming Callbacks Today (incl. waiting) | queue.volume.incoming_online | number | Data | active |
| `QueueNumIncomingOnlineCalls` | Incoming Calls Today (incl. waiting) | queue.volume.incoming_online | number | Data | active |
| `QueueNumIncomingOnlineCallsAndCallbacks` | Incoming Calls + Callbacks Today (incl. waiting) | queue.volume.incoming_online | number | Data | active |
| `QueueNumIncomingOnlineChats` | Incoming Chats Today (incl. waiting) | queue.volume.incoming_online | number | Data | active |
| `QueueNumOnCallAgents` | On Call Agents (duplicate) | queue.staffing | number | Data ⚠ duplicate | duplicate |
| `QueueNumOnlineChats` | Chats Today (all) | queue.volume.misc | number | Data | active |
| `QueueNumOutboundCalls` | Outbound Calls | queue.volume.misc | number | Data | active |
| `QueueNumTransferredCalls` | Transferred Calls | queue.volume.misc | number | Data | active |
| `QueueNumWaitingCallbacks` | Waiting Callbacks | queue.volume.waiting | number | Data | active |
| `QueueNumWaitingCalls` | Waiting Calls | queue.volume.waiting | number | Data | active |
| `QueueNumWaitingCallsAndCallbacks` | Waiting Calls + Callbacks | queue.volume.waiting | number | Data | active |
| `QueueNumWaitingChats` | Waiting Chats | queue.volume.waiting | number | Data | active |
| `QueueNumWaitingInteractions` | Waiting Digital Interactions | queue.volume.waiting | number | Data | active |
| `QueueNumWrapUpAgents` | Agents in Wrap Up | queue.staffing | number | Data | active |
| `QueuePctAbandonedCallbacksTotal` | % Abandoned Callbacks | queue.pct.abandoned_total | number | Data | active |
| `QueuePctAbandonedCallsAndCallbacksTotal` | % Abandoned Calls + Callbacks | queue.pct.abandoned_total | number | Data | active |
| `QueuePctAbandonedCallsTotal` | % Abandoned Calls | queue.pct.abandoned_total | number | Data | active |
| `QueuePctAbandonedChatsTotal` | % Abandoned Chats | queue.pct.abandoned_total | number | Data | active |
| `QueuePctAbandonedInteractionsTotal` | % Abandoned Digital Interactions | queue.pct.abandoned_total | number | Data | active |
| `QueuePctAnsweredCallbacks120secAns` | % Answered Callbacks in 120 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredCallbacks120secInc` | % Answered Callbacks in 120 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredCallbacks30secAns` | % Answered Callbacks in 30 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredCallbacks30secInc` | % Answered Callbacks in 30 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredCallbacks60secAns` | % Answered Callbacks in 60 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredCallbacks60secInc` | % Answered Callbacks in 60 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredCallbacksTotal` | % Answered Callbacks | queue.pct.answered_total | number | Data | active |
| `QueuePctAnsweredCalls120secAns` | % Answered Calls in 120 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredCalls120secInc` | % Answered Calls in 120 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredCalls30secAns` | % Answered Calls in 30 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredCalls30secInc` | % Answered Calls in 30 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredCalls360secInc` | % Answered Calls in 360 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredCalls60secAns` | % Answered Calls in 60 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredCalls60secInc` | % Answered Calls in 60 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredCalls60secIncLast30min` | % Answered Calls in 60 sec — Last 30 min | queue.pct.special | number | Data ⚠ defect-candidate | defect-candidate |
| `QueuePctAnsweredCallsAndCallbacks120secAns` | % Answered Calls + Callbacks in 120 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredCallsAndCallbacks120secInc` | % Answered Calls + Callbacks in 120 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredCallsAndCallbacks30secAns` | % Answered Calls + Callbacks in 30 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredCallsAndCallbacks30secInc` | % Answered Calls + Callbacks in 30 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredCallsAndCallbacks60secAns` | % Answered Calls + Callbacks in 60 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredCallsAndCallbacks60secInc` | % Answered Calls + Callbacks in 60 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredCallsAndCallbacksTotal` | % Answered Calls + Callbacks | queue.pct.answered_total | number | Data | active |
| `QueuePctAnsweredCallsTotal` | % Answered Calls | queue.pct.answered_total | number | Data | active |
| `QueuePctAnsweredChats120secAns` | % Answered Chats in 120 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredChats120secInc` | % Answered Chats in 120 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredChats30secAns` | % Answered Chats in 30 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredChats30secInc` | % Answered Chats in 30 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredChats60secAns` | % Answered Chats in 60 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredChats60secInc` | % Answered Chats in 60 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredChatsTotal` | % Answered Chats | queue.pct.answered_total | number | Data | active |
| `QueuePctAnsweredInteractions120secAns` | % Answered Digital Interactions in 120 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredInteractions120secInc` | % Answered Digital Interactions in 120 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredInteractions30secAns` | % Answered Digital Interactions in 30 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredInteractions30secInc` | % Answered Digital Interactions in 30 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredInteractions60secAns` | % Answered Digital Interactions in 60 sec (of answered) | queue.pct.answered_threshold_ans | number | Data | active |
| `QueuePctAnsweredInteractions60secInc` | % Answered Digital Interactions in 60 sec (of incoming) | queue.pct.answered_threshold_inc | number | Data | active |
| `QueuePctAnsweredInteractionsTotal` | % Answered Digital Interactions | queue.pct.answered_total | number | Data | active |
| `QueueSLAIn30secFrom80PctInc` | SLA: % Answered in 30 sec vs 80% Target | queue.pct.special | number | Data ⚠ defect-candidate | defect-candidate |
| `RemotePhoneNumber` | Customer Phone Number | agent.identity | text | Agent | active |
| `StateCountAvailable` | Agents in "Available" State | group.state_count | number | Data | active |
| `StateCountBreak` | Agents in "Break" State | group.state_count | number | Data | active |
| `StateCountOnPhone` | Agents in "On Phone" State | group.state_count | number | Data | active |
| `StateCountPaperwork` | Agents in "Paperwork" State | group.state_count | number | Data | active |
| `StateCountTraining` | Agents in "Training" State | group.state_count | number | Data | active |
| `UserCPH` | Calls per Hour (agent) | agent.counters | number | Agent | active |
| `UserNumAllIntercom` | Internal Calls (agent) | agent.counters | number | Agent | active |
| `UserNumMissedCalls` | Missed Calls (agent) | agent.counters | number | Agent | active |
| `UsersSumOnCall` | Agents On Call | group.state_group_count | number | Data | active |

---

*RTM Shell Metrics Overview v1.1 — 2026-06-05. Stage 1 deliverable: catalogue + duplicate analysis + engine-verified Calc defects (migration 20260605_004 prepared).
Stage 2 (planned): wizard UX spec, Viewer help integration, docx export. Companion: `docs/metrics-catalog.json`.*
