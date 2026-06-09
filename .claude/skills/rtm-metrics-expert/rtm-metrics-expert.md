# RTM Metrics Expert Skill

> Domain expert for **creating, describing and analysing** RTSGrid real-time metrics in RTM View Shell.
> Built from the RTM Metrics audit session (2026-06-05): full catalogue audit of 202 metrics,
> engine source verification (`RTM/RTM/Union.cs`), dedup migration `20260605_004` (→ 198 metrics).
>
> **Use this skill when:** adding a new metric, writing/fixing metric descriptions, building the metric
> wizard or Viewer field help, analysing duplicates/defects, mapping metrics to ISO/industry KPIs,
> or answering "what does metric X actually measure".

---

## 1. Source of truth — artefacts

| Artefact | Path | Role |
|---|---|---|
| Live catalogue | `RTSGrid_Metric` table (dev: `rtmviewdb`) | What the engine actually computes |
| Git baseline | `db/data/02_metrics.sql` | Versioned export (run `db/tools/Export-All.ps1` after ANY change) |
| Human catalogue | `docs/RTM_Shell_Metrics_Overview.md` | Families, matrices, comparisons, ISO mapping, audit findings |
| Machine catalogue | `docs/metrics-catalog.json` | Wizard / Viewer-tooltip data source (schema in §8) |
| Field reference | `docs/rtsgrid-metric-reference.md` | Column semantics + full MetricFunction table (§3.4 there) |
| Dedup migration | `db/migrations/20260605_004_metrics_dedup.sql` | Applied 2026-06-05 (commits 886dfe0 db, 2e72606 web) |

**Keep all of Overview.md + metrics-catalog.json + 02_metrics.sql in sync** — any metric change touches all three.

---

## 2. Engine ground truths (verified in RTM/RTM source, 2026-06-05)

These facts override any assumption and any older doc:

1. **`DataType` only selects the interaction bag.** `getInteractionBag(metric.DataType)`:
   `"UsersInteraction"` → the BU''s *agent* interactions; **anything else** ("Interactions Summary",
   "UsersSummary", "User", "String", …) → the BU''s *queue* interactions.
2. **Agent-status counters ignore `DataType` completely.** `getUsersInStatusGroupCount`,
   `getUsersInStatusCount`, `getLogedInUsersCount` iterate `Union.Users` only. Therefore two metrics
   with the same status function+parameter are **functional duplicates regardless of DataType**.
3. **Calc resolution is exact-match.** `Regex \[(.*?)\]` extracts the key *verbatim* (including spaces);
   lookup is `AllDataMetrics.ContainsKey(key)`; a miss silently substitutes `0`.
   → `[QueueNumAnsweredCalls30sec ]` (trailing space) made `QueueSLAIn30secFrom80PctInc` return 0.00% forever.
4. **Calc evaluates pure C# expressions** via `ExpressionEvaluator` 2.0.4 (`CompiledExpression.Eval()`),
   wrapped in try/catch that only logs (`Union.getData.Calc`). Unknown identifiers (e.g. a row field like
   `InQueueDateTime`) or type errors (`double && bool`) → exception **every calc cycle (default 2 s)**,
   metric stays empty. **Rolling time windows are NOT expressible in Calc.**
5. Calc pads minus signs (`calc1.Replace("-", " - ")`) before substitution — cosmetic, but keep MetricIds dash-free.
6. **Metric→cell binding lives ONLY in `RTSGrid_Cell."Value"`.** `RTSGrid_Column` has NO `MetricId`
   column (columns are `ColumnId, GridId, ColumnNumber, CellTemplateId`). Don''t write reference-fix SQL
   against a column that doesn''t exist.
7. Engine state resets at midnight (`RTSData_MidnightClear`) — all "today" counters are broadcast-day scoped.
8. `MetricFormat` (e.g. `##0.0%`) is applied server-side: the SignalR push delivers a **formatted string**.

---

## 3. Catalogue conventions (decoded during the audit)

* **Categories by Description prefix:** `QM - *` (queue/BU scope), `Agent Group - *` (aggregates over BU agents),
  `Agent - *` (per-agent, `MetricType=Agent`, Agent Grid only). Users see **Description only — never MetricId**.
* **Channels in MetricIds:** `Calls` (external voice), `Callbacks`, `CallsAndCallbacks` (combined voice),
  `Chats`, `Interactions` = **chat + e-mail only** (digital pair, NOT "all types").
* **Lifecycle words:** `IncomingOnline` = received today incl. still-waiting; `IncomingCompleted` = finished
  queueing (answered+abandoned, excl. waiting & callback requests) — the standard % denominator;
  `Waiting` / `Active` = real-time snapshots; `Answered` counts at answer moment (incl. in-progress);
  `Abandoned` excludes callback requests.
* **Percent suffixes:** `…Inc` = denominator IncomingCompleted (true **Service Level**, abandoned lower it);
  `…Ans` = denominator Answered only (speed profile; always ≥ Inc). Threshold set: 30/60/120 s (+360 s Calls only).
  Gaps in the channel×threshold matrix are intentional — fill only on widget demand.
* **Status Group vs Agent State:** `UsersInStatusGroupCount(''BREAK'')` counts ALL states mapped to BREAK;
  `UsersInStatusCount(''Break'')` counts the single raw state. Canonical groups:
  `AVAILABLE, ONPHONE, BREAK, PAPERWORK, TRAINING, UNAVAILABLE`. Group param = CC code (UPPERCASE), state param = exact
  state title (case-sensitive).
* **Real-time vs cumulative:** `Cur*`, `*CurMax`, `Waiting`, `Active`, state counts = now; the rest = since midnight.
* **Filter atoms** (`MetricParameter` C# expressions): `InteractionType`, `CallType (External/Intercom)`,
  `Direction`, `IsAnswered`, `IsAbandoned`, `IsCallbackRequest`, `IsInQueue`, `IsTalk`, `TimeInQueue<N`,
  `TalkTime<N/>N`, `IsTransferred`. Whitespace variations are insignificant — compare predicates canonically.

---

## 4. Creating a new metric — rules

1. **Never seed `RTSGrid_Metric`** (no DatabaseInitializer entries). One-time SQL migration in
   `db/migrations/` only, idempotent (`ON CONFLICT ("MetricId") DO NOTHING`).
2. **Never invent a MetricFunction.** Use an existing one (full list: `docs/rtsgrid-metric-reference.md` §3.4).
   Pattern: find the closest existing metric, copy its row, change only the parameter
   (e.g. `QueueLoginDataNumBreakUsers` → `...TrainingUsers`: same function, param `BREAK`→`TRAINING`).
3. MetricId: PascalCase, no dots (dotted ids belong to `History_Metric`), no dashes, follow the family
   naming (`QueueNum…`, `QueuePct…`, `QueueAvg…`, `MonAgent…`, `MonSumAgents…`).
4. Description: correct category prefix + precise wording — it must match the filter EXACTLY
   (audit found 3 metrics whose names lied about their filters).
5. Fill `ValueType` (`number`/`time`/`text`) and `MetricType` (`Data`/`Agent`) correctly; `DataType` per
   intended bag (§2.1): queue scope → `Interactions Summary`, agent-group interactions → `UsersInteraction`,
   per-agent → `User`, status summaries → `UsersSummary`.
6. For Calc: reference only existing MetricIds, **no spaces inside `[...]`**, ternary zero-guard
   (`[Den]==0 ? 0 : ((double)[Num]/[Den])`), set `MetricFormat` (`##0.0%`).
7. After DB change: `Export-All.ps1` (db: commit) + add the metric to `docs/metrics-catalog.json`
   and the family table/matrix in `docs/RTM_Shell_Metrics_Overview.md`.

---

## 5. Describing metrics — house style (wizard + Viewer help)

Each metric carries four text layers (English; stored in `metrics-catalog.json`):

| Layer | Audience | Rules |
|---|---|---|
| `displayName` | dropdowns/wizard | Concise, channel + lifecycle explicit, e.g. "% Answered Calls in 60 sec (of incoming)" |
| `shortDescription` | Viewer tooltip | ONE sentence, plain words, no MetricIds, no engine jargon |
| `longDescription` | expanded help | What is counted, when it changes, what is excluded, scope (BU/agent), day vs now |
| `comparison` | help "related fields" | How it differs from look-alikes (the №1 user confusion: Inc vs Ans, Online vs Completed, Group vs State) |

Family-first approach: ~112 of the metrics are channel×threshold matrix instances — describe the family
once with templates, render per-channel variants programmatically (see `/tmp` generator pattern or rebuild
from `metrics-catalog.json`). Hand-write only unique metrics (~90).

---

## 6. Analysing duplicates & defects — methodology

**Duplicate key:** `(MetricFunction, canonicalised MetricParameter, effective bag)` where
- canonicalise predicate: trim, collapse whitespace, split top-level `&&` atoms, strip redundant parens, sort atoms;
- effective bag: `UsersInteraction` vs queue (others) for interaction functions; **ignore DataType entirely**
  for status/login counters (§2.2).

**Defect checklist per metric:**
- Description ↔ filter mismatch (name promises something the predicate doesn''t do)
- Calc refs: every `[Key]` exists verbatim in catalogue (exact match, watch spaces)
- Calc expression is valid C# over numbers only (no row fields, no time windows)
- ValueType/MetricType/DataType consistent with the family
- MetricId typos (kept if referenced — fixing an ID requires reference migration)

**Before deleting/renaming any MetricId — reference check (ALL of):**
1. `RTSGrid_Cell."Value"` (the only grid binding — §2.6)
2. Calc formulas: `MetricParameter LIKE ''%[<Id>]%''`
3. Widget configs: `dashboard_widgets."ConfigJson"::text ILIKE ''%<Id>%''` (jsonb → text cast, widget-creator §26)
4. Shell/simulator code: `grep -rn "<Id>" src/ tools/SignalRSimulator/` (seeds in `DatabaseInitializer.cs`,
   hardcoded ids in widgets — ASD widget had `QueueNumOnCallAgents`)
Re-point references to the canonical metric FIRST, then delete, then `Export-All.ps1`.

**Audit history (2026-06-05, applied in 886dfe0):** deleted `QueueNumAcceptedCallbacks`
(≡ `QueueNumAnsweredCallbacks`), `QueueNumOnCallAgents` (≡ `UsersSumOnCall`), `QueueNumberOfLoggedAgents`
(≡ `QueueLoginDataNumLoggedUsers`), `QueuePctAnsweredCalls60secIncLast30min` (Calc structurally broken);
fixed `MonAgentNumberOfInboundCallsOnly` (dropped Intercom → matches its name), `QueueSLAIn30secFrom80PctInc`
(trimmed space), 11 descriptions, 1 DataType. Catalogue: 202 → **198**.

**Open observations (candidates for the next pass — document, discuss, don''t fix silently):**
- `MonAgentNumMakeCallsInCompleted`: no `CallType` filter → counts intercom too; counts only completed
  (`!IsTalk`); MetricId says "MakeCalls" but counts incoming. Option A: add External filter (changes values!),
  option B: clarify Description only.
- `MonAgentNumberOfInboundCallsDialer`: Description prefix "Agent Group" but `DataType="User"` → engine
  computes over the queue bag; normalise category or DataType.
- `QueueNumIcomingOnlineInteractions`: ID typo "Icoming" kept (referenced); Description already fixed.
- `QueueAvgWaitTime*` ≈ ASA but includes abandoned waits (predicate `!IsInQueue`, not `IsAnswered`).
- **`MonAgentCurrentLoginTimeStamp` is DEAD**: catalogue function `CurLoginTimeStamp` vs engine case `CurLoginTimestamp` (case-sensitive switch) — found 2026-06-05 during engine inventory. Fix: `UPDATE "RTSGrid_Metric" SET "MetricFunction"=''CurLoginTimestamp'' WHERE "MetricId"=''MonAgentCurrentLoginTimeStamp'';` (next dedup/fix migration).

---

## 7. ISO / industry mapping — how to do it correctly

**ISO 18295 (Customer contact centres):**
- **Part 1 (ISO 18295-1:2017)** — requirements for CCCs (in-house & outsourced, all channels).
  Key anchors: §4.3 measuring/monitoring customer experience; §5.2 performance measures agreed between
  CCC and client; §5.3 employee engagement (Annex A metric 9); §7.3 workforce planning;
  **Annex A (informative) "Metrics — Guidelines"** — numbered metric guidance across customer experience,
  service accessibility, efficiency, quality, HR.
- **Part 2 (ISO 18295-2:2017)** — requirements for the *client* organisation commissioning the CCC.
- The standard does **NOT prescribe formulas or targets** — targets are a client/CCC agreement (§5.2).
  Annex A is informative. → In docs write "ISO 18295-1:2017, Annex A (informative)" + area; never invent
  clause/metric numbers beyond what is verified (metric 9 = employee satisfaction is verified).

**Industry KPI vocabulary to use in descriptions** (de-facto: COPC CX Standard, Erlang/WFM practice):
- **Service Level / TSF** = answered ≤ N sec ÷ (answered+abandoned). RTM: `QueuePctAnswered{Ch}{N}secInc`.
- **ASA** = avg wait of *answered*. RTM `QueueAvgWaitTime*` is a near-ASA (includes abandoned waits — say so).
- **Abandonment Rate** = `QueuePctAbandoned{Ch}Total`; **ATA** = `QueueAvgTimeToAband*`.
- **AHT = Talk + Hold + ACW(Wrap-Up)**. RTM per-agent components: `MonAgentTalkDuration`,
  `MonAgentHeldDuration`, `MonAgentWrapUpDuration`; practical AHT proxy: `MonAgentAverageCallDuration`.
- **ATT** = `QueueAvgTalkingDuration*` / `MonAgentAverageInboundCallDuration`.
- **Occupancy** ≈ talk share of staffed time → proxy `MonAgentTalkDurationPct` (say "proxy": true occupancy
  = handling time ÷ (handling+available)).
- **FRT / Response Time** (digital) = `Messages*FirstResponseTime` / `MessagesAvgResponseTime` (+ Agent variants).
- **CPH** = `QueueCPH` / `UserCPH`; **Transfer rate (FCR proxy)** = `QueueNumTransferredCalls`;
  staffing/adherence inputs = `QueueLoginDataNum*Users`, `MonAgentLoginTime`, login timestamps.
- EN 15838 is the withdrawn predecessor of ISO 18295 — mention only as history.

**Client-facing claim template:** "The RTM catalogue provides the quantitative inputs recommended by
ISO 18295-1 Annex A for service accessibility, efficiency and workforce planning; targets and review
cadences remain a client/CCC agreement as required by §5.2."

---

## 8. metrics-catalog.json schema (wizard / Viewer contract)

Top level: `schemaVersion, generated, source, metricCount, postCleanupMetricCount, cleanupMigration,
cleanupApplied{date, dbCommit, webCommit}, categories{}, duplicatePairs[{duplicate, canonical, reason?}], metrics[]`.

Per metric: `metricId, originalDescription, displayName, category (Queue|AgentGroup|Agent),
family (e.g. queue.pct.answered_threshold_inc), channel (calls|callbacks|calls_callbacks|chats|digital|null),
thresholdSec (30|60|120|360|null), shortDescription, longDescription, comparison, similarMetrics[],
standardKpi, standardRef, metricFunction, metricParameter, metricFormat, valueType, metricType, dataType,
status (active|duplicate|deprecated|defect-candidate), duplicateOf, notes`.

Wizard rules: hide `duplicate`/`deprecated`; warn on `defect-candidate`; drill-down by
category → family → channel → thresholdSec; search over displayName+shortDescription+standardKpi.
Viewer help: tooltip = `shortDescription`; expanded panel = `longDescription` + `comparison` (+ related via `similarMetrics`).

---

## 9. Session lessons (process)

- **L-M1:** Verify metric semantics in engine source (`RTM/RTM/Union.cs`, `UserManager.cs`), not from
  field names — DataType looked meaningful for status counters and wasn''t.
- **L-M2:** A "duplicate" may really be a **filter bug** (InboundCallsOnly): prefer fixing the filter to
  match the name over deleting, when the name describes a useful distinct metric.
- **L-M3:** Broken Calc metrics fail **silently for users** (always 0/empty) but spam the RTM log every
  calc cycle — check `Union.getData.Calc` errors in RTM logs as a health probe after any Calc change.
- **L-M4:** Schema assumptions kill migrations: confirm columns via `db/schema.sql` before writing
  reference-fix SQL (RTSGrid_Column.MetricId did not exist).
- **L-M5:** Mount artifacts: after CC commits, Cowork cache write-back appends a whitespace padding line
  to files (EOF) and git status may show stale `M` even when content == HEAD. Trust
  `git hash-object <f>` vs `git rev-parse HEAD:<f>`, not `git status`.

---

## 10. Architecture reference — RTSGrid_Metric fields & MetricFunction catalogue

### 10.1 Full column reference (all 9 fields)

| Field | Type | Values / format | Semantics & rules |
|---|---|---|---|
| `MetricId` | varchar, **PK** | PascalCase; **no dots** (dotted ids belong to `History_Metric`), **no dashes** (Calc pads `-` with spaces); family prefixes: `QueueNum…`, `QueuePct…`, `QueueAvg…`, `QueueCurMax…`, `MonAgent…`, `MonSumAgents…`, `StateCount…`, `User…` | Referenced **verbatim** by `RTSGrid_Cell."Value"` and by `[MetricId]` refs inside Calc formulas (exact match, spaces break it). Renaming = full reference migration (§6). Never shown to end users |
| `Description` | varchar | `"QM - …"` / `"Agent Group - …"` / `"Agent - …"` — prefix IS the category | The only text users see (dropdowns, wizard). Must describe the filter EXACTLY — the audit found 3 metrics whose names lied. Fix wording freely (no references break), keep the prefix |
| `DataType` | varchar | `Interactions Summary` (queue bag) · `UsersInteraction` (agent-group bag) · `UsersSummary` (status summaries) · `User` (per-agent) | Engine effect: **only** selects the interaction bag — `"UsersInteraction"` → BU agents'' interactions, anything else → queue interactions (`getInteractionBag`). **Ignored entirely by status/login counters** (§2.2). Keep it consistent with the family anyway (audit normalised a stray `"String"`) |
| `MetricFunction` | varchar | One of the closed catalogue below (§10.2) | What the engine computes. `Union.cs` switch serves `MetricType=Data`; `UserManager.cs` has the parallel switch for `MetricType=Agent`. **Never invent a new value** — the switch silently returns nothing for unknown names |
| `MetricParameter` | varchar | Depends on function: **filter expr** (C# predicate over §3 atoms) · **StatusGroup code** (`AVAILABLE` `ONPHONE` `BREAK` `PAPERWORK` `TRAINING`) · **State title** (exact, case-sensitive: `Break`, `Wrap Up`, `Missed Call`, `Incoming Ext Call`, `Out Ext Call`, `Campaign Call`, `Hold`, `Unavailable`, `Consulting Call`…) · **empty** (login/identity functions) · **Calc formula** (C# expr with `[MetricId]` refs, zero-guard ternary) | The "how". For Calc: no spaces inside `[...]`, refs must exist, only numeric metrics referencable, no row fields / time windows (§2.3–2.4) |
| `MetricFormat` | varchar, mostly empty | .NET numeric format string: `##0.0%`, `##0.00%`, `F2` | Applied **server-side**: the SignalR push delivers an already-formatted **string** (`"85.3%"`). Empty → plain numeric string. Widgets must parse accordingly; percent Calc metrics should always set it |
| `DefaultValue` | varchar, mostly empty / `0` | — | Initial value before first computation. Transparent to the Shell |
| `ValueType` | varchar | `number` · `time` · `text` | **Shell-added** field — drives the filter UI in grid widgets: `number`/`time` → `< ≤ > ≥ =` operators (with `MM:SS` parsing for time), `text` → contains / equal / startsWith / endsWith + distinct-value list. Also used by threshold MatchType detection |
| `MetricType` | varchar | `Data` · `Agent` | Widget routing: `Data` → Queue Grid / Data Slot metric dropdowns; `Agent` → Agent Grid columns. Filter widgets by **MetricFunction** when selecting metrics for a feature, not by MetricType alone (L-24: ASD bug) |

### 10.2 MetricFunction catalogue — FULL engine inventory (verified against switch statements, 2026-06-05)

Two independent evaluation contexts. The function name must match the `case` label **exactly
(case-sensitive ordinal)** — an unknown name falls through silently and the metric never gets a value
(this is how the `CurLoginTimeStamp` vs `CurLoginTimestamp` defect stayed invisible).

Dispatch types: **[tpl]** = Roslyn-compiled template (METRIC_PARAMETER = filter expr, §12.2) ·
**[inline]** = hardcoded computation over `Union.Users` / UserManager state ·
**[calc]** = runtime formula evaluation · **[T]** = pushes `"+"+start-timestamp`, the CLIENT renders the ticking duration.

#### Data context — `Union.cs` switch (MetricType=Data; queue or agent-group bag per DataType)

| Function | Dispatch | Computes | Catalogue use |
|---|---|---|---|
| `InteractionsCount` | tpl | Count of bag interactions matching filter | 63 |
| `AnsweredCount` | tpl | Count, `IsAnswered` auto-prepended to filter | reserve |
| `AbandonedCount` | tpl | Count, `IsAbandoned` auto-prepended | reserve |
| `AnsweredPercent` / `AbandonedPercent` | tpl | Share of answered/abandoned within filter | reserve/reserve |
| `NumWaitings` | tpl | Count of `IsInQueue` && filter (0 if no applics registered) | 2 |
| `WaitDurationAvg` | tpl | Avg `TimeInQueue` over filter | 10 |
| `WaitDurationMax` | tpl | Max `TimeInQueue` today | reserve |
| `WaitDurationCurMax` | tpl, **T** | Start timestamp of longest currently-waiting item | 5 |
| `TalkDurationAvg` | tpl | Avg `TalkTime` over filter | 8 |
| `TalkDurationTotal` | tpl | Sum of `TalkTime` today | reserve |
| `TalkDurationMax` | tpl | Max `TalkTime` today | 1 |
| `TalkDurationCurMax` | tpl, **T** | Start timestamp of longest current talk | 1 |
| `CPH` | tpl | ⚠ Template body = plain count (identical to InteractionsCount); per-hour normalisation NOT visible in engine template — verify client side before relying on "per hour" semantics | 2 |
| `MessagesCount` / `MessagesInteractionsCount` | tpl | Chat-message count / messaging-interaction count | reserve/reserve |
| `MessagesPercent` / `MessagesInteractionsPercent` | tpl | Message-based shares | reserve/reserve |
| `MessagesMaxFirstResponseTime` | tpl | Max first-response time (ChatStats) | 1 |
| `MessagesAvgFirstResponseTime` / `MessagesAvgResponseTime` | tpl | Avg first / avg any response time | 2/2 |
| `LogedInUsersCount` | inline | `Users.Count(isLoggedId)` — **DataType ignored** | 1 |
| `UsersInStatusCount` / `UsersInStatusGroupCount` | inline | Agents now in exact state / in group — **DataType ignored** | 7/6 |
| `UsersInStatusPercent` / `UsersInStatusGroupPercent` | inline | Share of agents now in state/group | reserve/reserve |
| `UsersInStatusDurationAvg` / `…GroupDurationAvg` | inline | Avg duration of current stay in state/group | reserve/reserve |
| `UsersInStatusDurationPercent` / `…GroupDurationPercent` | inline | Cumulative state/group time share across BU agents | reserve/2 |
| `UsersInStatusDurationCurMax` / `…GroupDurationCurMax` | inline, **T** | Longest current stay in state/group | reserve/1 |
| `UsersInStatusDurationMax` / `…GroupDurationMax` | inline | Max stay duration today | reserve/reserve |
| `Calc` | calc | §2.3–2.4 formula over other Data metrics | 46 |

#### Agent context — `UserManager.cs` switch (MetricType=Agent; evaluated per agent)

| Function | Dispatch | Computes | Catalogue use |
|---|---|---|---|
| `UserID` / `FirstName` / `LastName` / `DisplayName` / `UserExtension` / `Station` | inline | Static identity attributes | 1/reserve/reserve/1/1/1 |
| `UserCustomAttribute` | inline | Custom attribute by name (Parameter = attribute name) | reserve |
| `IsTodayLogin` | inline | Flag: agent connected today | 1 |
| `CurLoginDuration` | inline, **T** | Current session timer (resets at midnight) | 1 |
| `CurLoginDurationReal` | inline, **T** | Current session timer, **not reset at midnight** | reserve |
| `CurLoginTimestamp` | inline, **T** | Current login start. ⚠ catalogue had `CurLoginTimeStamp` (capital S) → metric dead (open defect) | 0 (broken ref) |
| `FirstLoginTimestamp` | inline, **T** | First login today | 1 |
| `TotalLoginDuration` | inline, **T** | Total logged-in time today | 1 |
| `CurStatus` / `CurStatusTitle` / `CurStatusGroup` | inline | Current state id / display title / group name | reserve/1/1 |
| `CurStatusDuration` / `CurStatusGroupDuration` | inline, **T** | Time in current state / current group (group timer survives state switches inside the group) | 2/1 |
| `CalculatedStatus` / `CalculatedStatusTime` | inline (/T) | Derived status from call state + its timer | reserve/reserve |
| `OnPhoneDuration` | inline, **T** | Current on-phone timer | reserve |
| `TotalStatusDuration` / `TotalStatusGroupDuration` | inline, **T** | Cumulative time today in state (Parameter=StatusId) / group | 4/4 |
| `TotalStatusPercent` / `TotalStatusGroupPercent` | inline | Cumulative state/group time ÷ login time | reserve/5 |
| `TotalStatusCount` / `TotalStatusGroupCount` | inline | Number of entries into state / group today | 2/reserve |
| `TotalStatusDurationAvg` / `TotalStatusGroupDurationAvg` | inline | Avg duration per stay | 2/1 |
| `TotalStatusDurationMax` / `TotalStatusGroupDurationMax` | inline | Longest stay today | reserve/reserve |
| `LongestInteraction{Id,Workgroup,Type,RemoteAddress,State,CustomCallData}` | inline | Attributes of agent''s longest active interaction | 6 used / CustomCallData reserve |
| `LongestInteractionDuration` / `LongestInteractionStateDuration` | inline, **T** | Timers of that interaction / its state | reserve/1 |
| `InteractionsCount` / `CPH` | tpl | Count of agent''s interactions matching filter (`i.UserId == userId &&` auto-prepended). Same ⚠ CPH caveat | 63/2 |
| `TalkDurationAvg` / `TalkDurationMax` | tpl | Agent talk-time aggregates | 8/1 |
| `MessagesAvgFirstResponseTime` / `MessagesAvgResponseTime` | tpl | Agent digital response times | 2/2 |
| `Productivity` / `Efficiency` | inline | Derived productivity scores (semantics in UserManager.cs — read before use) | reserve/reserve |
| `Calc` | calc | Formula over the agent''s other metrics | 46 |

**"reserve" = implemented in the engine but unused by the catalogue** — 30+ functions available for new
metrics with ZERO engine changes (e.g. `AnsweredCount`, `WaitDurationMax`, `TalkDurationTotal`,
`UsersInStatusGroupPercent`, `TotalStatusGroupCount`, `UserCustomAttribute`, `Productivity`).

## 11. Catalogue inventory — family map (snapshot 2026-06-05, 197 live metrics)

> The per-metric source of truth is `docs/metrics-catalog.json` — ALWAYS read it for actual IDs,
> parameters and statuses. This map only shows the shape of the catalogue.

| Family | Count | Example |
|---|---|---|
| `agent.counters` | 13 | `MonAgentNumChatsActive …` |
| `agent.duration` | 21 | `AgentMessagesAvgFirstResponseTime …` |
| `agent.identity` | 14 | `AgentLoginName …` |
| `agent.percent` | 5 | `MonAgentAvailableDurationPct …` |
| `group.duration` | 3 | `MonSumAgentsBreakDurationMax …` |
| `group.interactions` | 6 | `MonAgentNumberOfInboundCallsDialer …` |
| `group.state_count` | 6 | `MonSumAgentsInMissedCall …` |
| `group.state_group_count` | 6 | `QueueLoginDataNumAvailableUsers …` |
| `queue.abandon.time_avg` | 5 | `QueueAvgTimeToAbandCallbacks …` |
| `queue.messages` | 3 | `MessagesAvgFirstResponseTime …` |
| `queue.pct.abandoned_total` | 5 | `QueuePctAbandonedCallbacksTotal …` |
| `queue.pct.answered_threshold_ans` | 15 | `QueuePctAnsweredCallbacks30secAns …` |
| `queue.pct.answered_threshold_inc` | 16 | `QueuePctAnsweredCallbacks30secInc …` |
| `queue.pct.answered_total` | 5 | `QueuePctAnsweredCallbacksTotal …` |
| `queue.pct.special` | 5 | `QueueBaseAnsweredPct …` |
| `queue.staffing` | 2 | `QueueCPH …` |
| `queue.talk.avg` | 5 | `QueueAvgTalkingDurationCallbacks …` |
| `queue.volume.abandoned` | 5 | `QueueNumAbandonedCallbacks …` |
| `queue.volume.active` | 5 | `QueueNumActiveCallbacks …` |
| `queue.volume.answered` | 5 | `QueueNumAnsweredCallbacks …` |
| `queue.volume.answered_threshold` | 16 | `QueueNumAnsweredCallbacks30sec …` |
| `queue.volume.incoming_completed` | 5 | `QueueNumIncomingCompletedCallbacks …` |
| `queue.volume.incoming_online` | 5 | `QueueNumIncomingOnlineCallbacks …` |
| `queue.volume.misc` | 6 | `QueueNumCallbackRequests …` |
| `queue.volume.waiting` | 5 | `QueueNumWaitingCallbacks …` |
| `queue.wait.avg` | 5 | `QueueAvgWaitTimeCallbacks …` |
| `queue.wait.curmax` | 5 | `QueueCurMaxWaitTimeCallbacks …` |

Channel dimension for `queue.*` matrix families: `calls / callbacks / calls_callbacks / chats / digital`;
threshold dimension: 30/60/120 (+360 calls-only).

---

## 12. RTM Service — metric processing pipeline (infrastructure level)

End-to-end path of every metric value, verified in source 2026-06-05. File map:
`Engine.cs` (orchestration, compilation, events) · `Union.cs` (Data metrics) · `UserManager.cs` (Agent metrics)
· `CollectData.cs` (calc loop) · `Grid.cs`/`Cell.cs` (change tracking) · `RTMAdapter.cs`/`RTMHub.cs` (SignalR)
· `RealtimeData.cs`/`DBMng.cs` (DB access) · `MetricDef.cs` (runtime metric model).

### 12.1 Startup — loading & compiling

1. `RealtimeData.GetAllMetrics()` → SQL function `RTSGrid_GetAllMetrics()` → `Dictionary<MetricId, MetricDef>`.
   **Only 7 columns are read:** MetricId, Description, DataType, MetricFunction, MetricParameter,
   MetricFormat, DefaultValue. **`ValueType` and `MetricType` are NEVER read by RTM Service** — they are
   Shell-only fields (filter UI / widget routing). Changing them never affects engine behaviour.
2. `RTSGrid_GetDataCells()` → cells registered into Grid + Union in memory (`Cell.Value` = MetricId);
   `RTSGrid_GetAllUnionQueueClassifications(tenant)` → `union.addWorkgroup(QueueId)` for rows with
   `ClassificationId=''ALL''` (see widget-planner L-11 for the two historical bugs here).
3. For every metric whose Function has a **template** (`MetricFunctionList` for Data,
   `MetricUserFunctionList` for Agent), the engine generates a C# class
   `Metric{MetricId}Container.MetricFunction(Bag, …)` — template body with `METRIC_PARAMETER` replaced by
   the transformed filter — and **compiles it with Roslyn into an in-memory assembly (one per metric)**.
   A third delegate `InteractionsListFunction` (`Bag.Where(i => filter).ToList()`) is compiled for
   drill-down interaction lists. Status/identity functions need no compilation (inline switch).
4. **Compilation failure** → `AsyncLogger.Error` with the full generated code, the delegate stays null,
   the metric silently never produces values. **Always check the RTM log for
   `Engine.CompileAndSetMetricFunction` errors after adding/altering a metric.**

### 12.2 TransformQuery — what filter expressions really are

`TransformQuery` rewrites the stored `MetricParameter` by prefixing **every public property name of
`IDInteraction` and `ChatMessage`** (reflection, longest-name-first) with `i.` → the filter becomes a real
LINQ lambda body. Consequences:

* The usable filter vocabulary = ALL public `IDInteraction` properties, not just the common atoms (§3):
  `InteractionId, Segment, Workgroup, LastWorkgroup, State, ClassificationCode, InteractionType, CallType,
  Direction, CustomCallData, CustomCallData1..10, RemoteAddress, UserId, LastUserId, IsTransferred,
  IsAnswered, IsAbandoned, IsMessaging, IsInQueue, IsTalk, TimeInQueue (sec), TalkTime (sec),
  InQueueDateTime, AnsweredDateTime, DisconnectDateTime (+Local variants), IsCallbackRequest, …`
  plus `ChatMessage` properties for message functions. Full C#/LINQ syntax is allowed (it compiles).
* ⚠ **String-literal gotcha:** the regex does NOT respect quotes. A literal containing a property name
  breaks the filter: `Workgroup=="Sales Workgroup"` → `i.Workgroup=="Sales i.Workgroup"` → compile error
  or wrong match. Never put property names inside string literals in MetricParameter.
* `DateTime`-based windows ARE possible in **interaction filters** (e.g. `InQueueDateTime >= …` compiles
  fine there) — it is only **Calc** that cannot resolve row fields (§2.4).

### 12.3 Runtime data — the bags

CC-platform events (Finesse adapter) maintain two `ConcurrentBag<IDInteraction>` sets per Union:
`QueueInteractions` (attributed via queue/workgroup) and `UsersInteractions` (attributed via the BU''s
agents), plus per-agent `UserManager` state (statuses, logins, longest interaction). `DataType` picks the
bag (§2.1). Agent-status data lives in `Union.Users` (list of UserManager) — no bag involved.

### 12.4 Calc loop — evaluation & change detection

* `CollectData` runs `getData()` every **`AppConfig.CalcInterval` seconds (default 2)** on a long-running
  task; per-union evaluation is parallelised with `Task.WaitAll(CalcInterval*1000)` timeout; a union
  already busy (`IsGettingData`) is skipped this tick.
* For each registered metric the Union/UserManager switch produces a **string** value
  (numbers pre-formatted by `MetricFormat` server-side), stored via `Metrics[id].setValue` →
  sets `Cell.IsChanged` only when the value actually differs.
* `Calc` metrics are evaluated in the same pass against the latest values of their referenced metrics.
* Every ~100 ticks the loop logs `CollectData.getData … LongestAction = N ms` — the health metric for
  engine load (if LongestAction approaches CalcInterval*1000, the engine is saturated).

### 12.5 Delivery — SignalR push (changed cells only)

* After evaluation, `grid.report()` collects cells with `IsChanged`, resets the flag and fires `GridEvent`.
* `RTMAdapter` forwards to SignalR groups:
  - Queue/Data grids: group `"{gridId}"` → `updateGridData([{CellId, Value}, …])`
  - Agent grids: group `"u{unionId}"` → `updateUserGrid(DateTime, unionId, payload)` and `removeUser(unionId, [{name}])`
  - Per-user views: group `"a{userId}"` → `updateUserView(userData)`
* Shell side: `RtmRelayService` joins via `init("{gridId}")` / `init("u{unionId}")`; `refreshCells(gridId)`
  forces a full push (otherwise only deltas arrive). Use `JToken`, not `JsonElement` (widget-creator §24.1).
* **Timer metrics ([T], §10.2) push `"+dd/MM/yyyy HH:mm:ss"` start timestamps** — the widget renders the
  ticking duration client-side. Empty value = `"&nbsp;"`. Parsers must handle both.

### 12.6 Day boundary & failure modes

* `RTSData_MidnightClear` + engine midnight logic reset day counters; `CurLoginDurationReal` deliberately
  survives midnight (agent stays logged in overnight).
* Silent-failure matrix (why a metric shows nothing):

| Symptom | Cause | Where to look |
|---|---|---|
| Metric always empty | Function name has no `case` (typo/case-sensitivity — e.g. `CurLoginTimeStamp`) | switch labels §10.2 |
| Metric always empty + startup errors | Filter failed Roslyn compilation (syntax, string-literal gotcha) | RTM log `Engine.CompileAndSetMetricFunction` |
| Calc always 0 | `[Ref ]` whitespace / nonexistent MetricId → substituted 0 | §2.3 |
| Calc always empty + log spam every 2 s | Invalid expression (unknown identifier, type error) | RTM log `Union.getData.Calc` |
| No values for whole grid | Cells/queues not registered at startup | widget-planner L-11 checklist |
| Value frozen | Cell never marked changed / SignalR group not joined (`init` missing) | §12.5 |

---

*rtm-metrics-expert skill v1.2 — created 2026-06-05, extended 2026-06-06 with UNAVAILABLE 6th group. Catalogue state: 202 metrics
(post-migration 20260606_006). Next stage: wizard UX spec + Viewer field help built on metrics-catalog.json.*

---

## Metric Lifecycle — vendor product-constants, deploy-only (2026-06-09)

Metrics are **PRODUCT CONSTANTS owned by the vendor**. The canonical metric list lives in the vendor source
(repo: `db/data/02_metrics.sql`, catalogue JSON). Client installations NEVER mutate metrics in-app.

### Client = fully read-only
`MetricsPage` (Shell) is **fully read-only**: no create / edit / delete, no Parameter/Format/Function editing,
no DisplayName/Description/localization editing. The ONLY mutation channel is the **vendor deploy**. A client
needing ANY metric change (even a description) raises a request to the vendor.

**Security rationale:** metric `Parameter`/`Format` are string-interpolated into C# and Roslyn-compiled in the
RTM process (RCE-capable). Allowing client free-text = code-injection / privilege escalation (app-admin -> server
RCE). Read-only client + vendor-curated source removes the input surface entirely (closes finding F-1).

### Vendor process (Metrics session, via the опросник)
ADD / CHANGE / DELETE a metric = vendor-initiated, authored on the vendor source FIRST, shipped in product
versions; installed clients receive a TARGETED deploy.

- **ADD:** опросник -> migration (+ history mirror if applicable) -> install package (migration + manifest carrying
  per-migration SHA-256 + RT/history flag) -> deploy. Dev-first validation (Calc/[MetricId] compiles, mirror complete).
- **CHANGE:** any field (Parameter/Format/Function/DisplayName/Description/localization) — same path, NO in-app edit.
  The package carries localization too, not only Parameter.
- **DELETE: NEVER naked.** The Metrics session MUST author a REPLACEMENT — create a new replacing metric OR
  designate an existing one. The deletion package carries the mapping `{deletedMetricId -> replacementMetricId}`.
  Deploy applies: remove the metric + RE-POINT every usage to the replacement so screens never break. Usage spans
  TWO layers: (1) the **grid binding** `RTSGrid_Cell.Value` — the PRIMARY metric reference in vendor-shipped
  widget grids, re-pointed in the same migration (exactly as the `20260605_004` dedup did). NB: `RTSGrid_Column`
  has NO MetricId — the binding is `RTSGrid_Cell.Value` (common error). (2) **client widget configs** —
  `dashboard_widgets` ConfigJson / dashboard layout that reference the metricId, re-pointed at the client on deploy.
  Usage-validation = locate every reference across BOTH layers; the mandatory replacement closes the gap.

### Deploy mechanism (hot-reload)
The change ships in the install package (migration + manifest). At the client, the read-only MetricsPage **Deploy**
tab shows the delta (package vs the per-metric deploy-ledger, §38a) -> Superadmin clicks Deploy -> privileged
apply-service applies the migration (catalogue-owner DB role, fail-closed token, SHA-256 hash-integrity) + writes
the ledger + audit -> SignalR `compileMetrics(RT MetricIds)` -> RTM incrementally compiles the new/changed metric
**live, no restart**. History half (dotted-id) = no compile (query-time). See `docs/metrics-hot-reload-contract.md`.
