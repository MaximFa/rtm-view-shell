# Hot-reload metrics — metrics-side contract (v1.2 — FINAL)

> Owner: metrics specialist (metrics-2-0607). Audience: Shell (builds the "Deploy new metrics" tab + SignalR invoke)
> and Backend/RTM (builds incremental single-metric compile). This doc is the metrics-DOMAIN contract only — NOT UI,
> NOT the SignalR transport, NOT the RTM compiler internals. Confirmed with operator (Max) 2026-06-09.
> Normative metric reference: .claude/skills/rtm-metrics-expert/rtm-metrics-expert.md.
>
> **Status: FINAL v1.0 (2026-06-09).** Design locked; R1/R2 folded per SYNC-AUDIT (meeting brief
> 2026-06-09T13:30Z). Implementation (Backend Engine.HotReloadMetrics + Shell Deploy tab) starts from this doc.
> **v1.1 addendum (2026-06-09):** package manifest carries an explicit per-metric `metricType` flag (§3.1) —
> devops apply-endpoint classifies RT-vs-history from the flag, not from id-shape (devops-2 ASK, relayed by coordinator).
> **v1.2 addendum (2026-06-09):** manifest also carries a TRUSTED per-migration SHA-256 (§3.2) — apply-service
> verifies the migration file hash fail-closed before execution (Security review F-4, deploy-blocking for 234).

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

### 3.1 Package manifest schema — explicit per-metric `metricType` flag (v1.1 addendum, devops-2 ASK)
The install-package manifest enumerates every shipped MetricId. **v1.1 requirement:** each manifest entry MUST
carry an explicit `metricType: "RT" | "history"` flag.
Why: the devops apply-endpoint classifies which ids go into its `appliedRtMetricIds` response (RT-only, §6/R1)
from THIS explicit flag — it does NOT infer the type from id-shape. The id-shape rule (§1: dotted ⇒ history,
PascalCase ⇒ RT) stays as a human/validation convention and defense-in-depth, but the apply-endpoint's
classification authority is the manifest flag, removing any ambiguity at apply time.
Mirror entry (§2): the manifest lists BOTH halves, each with its own `metricType` (RT half = `RT`, history half
= `history`); apply puts ONLY the RT half into `appliedRtMetricIds`. Metrics owns emitting the manifest with
correct flags as part of the опросник→package step — the type is already known at creation (a `RTSGrid_Metric`
INSERT ⇒ `RT`, a `history_metrics` seed ⇒ `history`).

### 3.2 Package manifest schema — F-4 integrity (trusted per-migration SHA-256) (v1.2 addendum, Security F-4)
Security review F-4 (`docs/security-review-hotreload-0609.md`, HIGH): the apply-service executes the migration
file as raw SQL with catalogue-owner privileges; whoever can write `PackageMigrationsDir` controls that SQL
(chains to the F-1 Roslyn RCE). **Fail-closed fix:** the manifest MUST declare a trusted SHA-256 for every
migration it ships, and the apply-service verifies the on-disk file's hash against it BEFORE execution —
mismatch OR missing hash ⇒ reject (HTTP 409), nothing applied.

Manifest entry, per migration shipped in the package:
```jsonc
{
  "migrationRef": "20260609_0NN_add_<metric>.sql",   // file in the package (path-traversal already blocked by apply-svc)
  "sha256":       "<hex>",                            // TRUSTED expected hash of the migration file bytes (REQUIRED)
  "metricIds": [
    { "metricId": "<RtMetricId>",        "metricType": "RT" },
    { "metricId": "<dotted.history.id>", "metricType": "history" }
  ]
}
```
Rules:
- `sha256` is REQUIRED per migration. The apply-service computes SHA-256 over the exact file bytes and compares
  byte-for-byte; absent or mismatched ⇒ 409, fail-closed (F-4). Verification is the apply-service's job (devops);
  the manifest is the TRUSTED source it verifies against — metrics produces the manifest, does not run the check.
- `metricType` per MetricId stays as §3.1 (drives the RT-only `appliedRtMetricIds`, §6/R1).
- The manifest must itself be tamper-evident end-to-end: ship it inside the signed/locked package and pin
  `PackageMigrationsDir` to admin-write-only NTFS ACLs (deploy hardening, devops). A manifest an attacker can
  rewrite defeats the hash, so the manifest's own integrity (package signature / ACL) is part of the F-4 control.
- **Generator:** the package BUILD step emits this manifest, computing each `sha256` at pack time from the
  committed migration file. Metrics owns the SCHEMA (this section); the build/packaging owner implements the emit.

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
restart. Backend defines the message shape, the compile, and concurrency-safety on the live engine.

**Exactly which ids Shell sends (R1, ratified SYNC-AUDIT 2026-06-09):** Shell sends EXACTLY the
`appliedRtMetricIds` returned by the devops apply-endpoint response — NOT the whole package manifest. The
history half is excluded by devops at apply time — classified via the manifest `metricType` flag (§3.1), not
by id-shape (history metrics are query-time, never compiled), so the wire
already carries RT-only ids. RTM's internal history-skip (dotted-id ⇒ skip) remains as **defense-in-depth**,
not the primary filter: the contract guarantees Shell never sends a history id, and Backend does not rely on
Shell to do the filtering. Transport: `compileMetrics(string[] metricIds)`, fire-and-forget.

### 6.1 "deployed (ledger) != compiled (RTM)" — v1 reconciliation (R2, ratified 2026-06-09)
The ledger records a metric as DEPLOYED the moment devops apply succeeds; the SignalR compile that follows is
**fire-and-forget (best-effort)**. A window therefore exists where a metric is deployed-but-not-yet-compiled
(e.g. the push dropped, or RTM was momentarily down). v1 accepts this window:
- `compileMetrics` is **idempotent** — RTM skips a MetricId already in its in-memory set (skip-if-ContainsKey /
  TryAdd), so re-firing the same id set is always safe.
- On compile failure RTM logs `AsyncLogger.Error`; nothing is half-applied (additive only).
- Shell exposes a **"Recompile" affordance** in the Deploy tab that re-fires `compileMetrics` for the deployed
  ids — the operator-driven recovery for the rare gap (Superadmin operation).
- A compile-status badge (deployed-and-compiled vs deployed-only) is a **v2 enhancement**, out of scope for v1.

## 7. Out of scope v1
- Editing an EXISTING metric (MetricParameter/Format/Function change) → requires RTM restart; NOT hot-deployable.
- Deleting a metric → restart (a live grid may reference it).
- Full reload/recompile of all metrics on a live engine → forbidden.
- In-app metric CREATION wizard (creation stays the dev-first опросник→migration path, metrics session).

## 8. Session responsibilities
- **Metrics (me):** опросник→migration (RTSGrid_Metric + history_metrics mirror) + 02_metrics/baseline/seed +
  catalogue json + translations; this contract; validation rules; dedup/defect/ISO analysis. NO UI, NO SignalR code.
- **Shell:** the "Deploy new metrics" tab (ledger-based delta per §3, granularity per §2/§4) + the SignalR invoke.
- **Backend/RTM:** incremental single-metric compile handler (§6); the history half is query-time (no action).
