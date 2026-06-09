# Hot-reload metrics — metrics-side contract (v1)

> Owner: metrics specialist (metrics-2-0607). Audience: Shell (builds the "Deploy new metrics" tab + SignalR invoke)
> and Backend/RTM (builds incremental single-metric compile). This doc is the metrics-DOMAIN contract only — NOT UI,
> NOT the SignalR transport, NOT the RTM compiler internals. Confirmed with operator (Max) 2026-06-09.
> Normative metric reference: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md.

## 0. Principle (operator)
A new metric is created DEV-FIRST → committed to git (migration + 02_metrics/baseline/seed + catalogue) → ships in the
install package → applied SELECTIVELY at a client via a Shell "Deploy new metrics" tab → on Deploy: migration applied
at the client + a SignalR push triggers RTM to **incrementally compile ONLY the new metric**.
**Forbidden:** full reload/recompile of all metrics on a live engine (heavy, long). v1 = ADDITIVE only.

## 1. Metric types & identity (the core distinction)
| Type | Table | MetricId form | How RTM uses it | Needs compile on deploy? |
|---|---|---|---|---|
| Real-time | `RTSGrid_Metric` | PascalCase, NO dots, NO dashes (e.g. `QueueNumAbandonedCalls`) | Loaded into memory at startup; `MetricFunction=Calc` is Roslyn-compiled | **YES** — incremental compile of this MetricId |
| History | `history_metrics` | dotted (e.g. `statuslog.unavailable_agents`) | Read at QUERY time by `fn_daytrend*` SQL fns; NOT in the live calc cycle | **NO** — live on next query; but its `fn_daytrend*` must EMIT the id (a DB-function deploy, not a SignalR push) |

Identity rule: dotted id ⇒ history; PascalCase id ⇒ real-time. A MetricId is unique within its type.

## 2. Mirror rule (RT ↔ history)
Some concepts need BOTH halves so they appear in live grids (RT) AND in DayTrend history (history). Operator rule:
**every history metric that must also be live needs a paired real-time RTSGrid_Metric, and vice-versa.**
Example (UNAVAILABLE feature): history `statuslog.unavailable_agents` / `statuslog.unavailable_time_ms`
↔ RT `QueueLoginDataNumUnavailableUsers` / `MonAgentUnavailableDuration` / `MonAgentUnavailableDurationPct`.

Deploy semantics for a mirror ENTRY (granularity (3), confirmed):
- treat the RT+history pair as ONE logical entry in the Deploy tab;
- the migration applies BOTH halves (RTSGrid_Metric INSERT + history_metrics seed);
- the SignalR push compiles ONLY the RT half (the history half is live on next DayTrend query, provided its
  `fn_daytrend*` already emits the id — that emission ships as part of the same package migration, NOT via SignalR).

## 3. "New / undeployed" — definition for Shell's delta (stitch (1), RATIFIED in meeting brief 2026-06-09)
A metric is NEW/UNDEPLOYED at a client when its **MetricId is present in the install-package manifest but NOT yet
recorded as applied in the per-metric LEDGER** (devops §38a: {MetricId, deployedAt, sourceCommit} — one mechanism,
two consumers: this metric-deploy delta + devops E-010b). Shell reads the ledger to compute the delta
(package MetricId ∉ ledger-applied). NOT a raw manifest-vs-live-table diff — the ledger is the source of truth.
Mirror entry is "new" if EITHER half is unrecorded; the tab shows it as one entry with both halves.

## 4. What the Deploy tab displays (catalogue data — Shell reads, metrics owns the source)
Source of truth = `docs/metrics-catalog.json` (schema in rtm-metrics-expert §8). Per metric the tab can show:
`metricId`, `displayName` (concise, channel+lifecycle explicit), `shortDescription` (one plain sentence),
`category`/`family`, `metricType` (Data/Agent…), `metricFunction`, and — for the deploy view — the type (RT/history)
and the mirror-pair link (which RT id ↔ which history id). The catalogue is localised (ru-RU/he-IL via
`RTSGrid_MetricTranslation`); the tab uses the localised DisplayName/ShortDescription (same path as MetricWizard).

## 5. Validation rules (dev-first gate — caught on dev, BEFORE git/package)
A metric must pass these on DEV (apply to dev DB + compile) before it is committed/packaged:
1. `MetricFunction` is an EXISTING engine function (never invented) — list: `docs/rtsgrid-metric-reference.md` §3.4.
2. For `MetricFunction=Calc`: the expression compiles AND every `[MetricId]` reference resolves to an existing
   MetricId (the `QueuePctAnsweredCalls60secIncLast30min` "unresolved identifier → Eval throws every cycle" class
   MUST be caught here). No trailing spaces inside `[MetricId]` (exact-match dictionary lookup).
3. MetricId conventions: PascalCase no-dots-no-dashes (RT) / dotted (history); follows the family naming.
4. Mirror completeness: if the concept is mirrored, BOTH halves exist AND the history half's `fn_daytrend*` emits it.
5. Catalogue completeness: entry added to `metrics-catalog.json` (+ ru/he translations) and the Overview family table.
**Because creation is dev-first, dev IS the validation gate** — a bad metric fails on the dev apply+compile, never
reaching prod. An RTM dry-compile/validate endpoint is a nice-to-have, not a v1 blocker.

## 6. SignalR push contract (metrics-side view; Backend owns the handler)
On Deploy, after the client migration is applied, Shell sends RTM the set of NEW **RT** MetricId(s) to compile.
RTM compiles ONLY those (incremental), adds them to the in-memory metric set, and they appear on grids without
restart. Payload (metrics-side requirement): the RT MetricId(s) just inserted. History-half ids are NOT sent
(no compile). Backend defines the message shape, the compile, and concurrency-safety on the live engine.

## 7. Out of scope v1
- Editing an EXISTING metric (MetricParameter/Format/Function change) → requires RTM restart; NOT hot-deployable.
- Deleting a metric → restart (a live grid may reference it).
- Full reload/recompile of all metrics on a live engine → forbidden.
- In-app metric CREATION wizard (creation stays the dev-first опросник→migration path, metrics session).

## 8. Session responsibilities
- **Metrics (me):** опросник→migration (RTSGrid_Metric + history_metrics mirror) + 02_metrics/baseline/seed +
  catalogue json + translations; this contract; validation rules; dedup/defect/ISO analysis. NO UI, NO SignalR code.
- **Shell:** the "Deploy new metrics" tab (manifest-diff delta per §3, granularity per §2/§4) + the SignalR invoke.
- **Backend/RTM:** incremental single-metric compile handler (§6); the history half is query-time (no action).
