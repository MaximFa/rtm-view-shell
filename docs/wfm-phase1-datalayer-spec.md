# WFM Phase 1 — data-layer spec (feeds ErlangCalculatorService 4e21796) — v0.3 (O-1/O-2/O-3/O-5 locked)

> Author/lead: metrics-3-0609. Paired with: DBA (SARGability). Design-first, NO code, NO push. Inputs LOCKED by
> operator 2026-07-21. Feeds the pure-math `ErlangCalculatorService` (commit 4e21796). Basis: `docs/wfm-phase1-erlang-core-spec.md`.
> Sources (EXISTING, no new): `RTSData_Interaction` (λ, AHT). N is NOT read from the database — see §3.
> v0.3 (metrics-1014, 2026-10-17): §3 rewritten to the operator's rule of 2026-10-14 and to the code on v4
> (704b335, f90c3f5). The v0.2 premise "`RTSData_UserStatus` (current)" was WRONG — see §3 "Why not the database".

## 0. LOCKED inputs (operator 2026-07-21)
- Window: **30 min rolling** (per-tenant configurable). Scope: **per (tenant, queue=Workgroup)**.
- **λ** = OFFERED incoming = Direction Incoming, InteractionType ∈ {Call, Callback}, that ARRIVED in the window
  (answered + abandoned + still-queued). Scaled to **calls/hour**.
- **AHT** = talk + hold + wrap, avg over the window.
- **N** = agents of the **BU's skill** who are NOW in a **serving state-group** (configurable set, picked from the
  groups the engine publishes for that BU). SL default 80% @ 20 s.
- **Isolated calculations (operator 2026-10-14, verbatim):** «поток и звонки считать по очереди, агентов по скилу».
  λ and AHT are per queue; N is per the skill of the BU that owns the queue. The BU's queue and skill classification is
  operator data and is correct as configured — Wfm does not widen or re-derive it.

## 1. λ — offered inbound DEMAND, per (tenant, queue), 30-min window → calls/hour
**Locked (operator 2026-07-21):** λ = ALL real offered inbound demand — INCLUDE callback-requests (O-3) and
INCLUDE short-abandons (<5 s, O-5). No down-filtering. **CRITICAL: count each distinct inbound contact ONCE**
(a call deflected to a callback = ONE arrival, not two).

Base query (arrivals by `InQueueDateTime` in window; covers answered + abandoned + still-queued):
```sql
-- @tenant uuid, @queue text (Workgroup), @winMin int (=30), @now timestamptz
SELECT COALESCE(COUNT(*),0)::double precision / @winMin * 60.0 AS lambda_per_hour
FROM public."RTSData_Interaction" i
WHERE i."TenantId" = @tenant
  AND i."Workgroup" = @queue
  AND i."Direction" = 'Incoming'
  AND i."InteractionType" IN ('Call','Callback')
  AND i."CallType" = 'External'
  AND i."InQueueDateTime" >= @now - (@winMin || ' minutes')::interval
  AND i."InQueueDateTime" <  @now;
  -- NO IsAbandoned filter (short-abandon INCLUDED, O-5). NO !IsCallbackRequest filter (callback demand INCLUDED, O-3).
```

**NO-DOUBLE-COUNT — dedup logic (⚠ depends on the RTM deflection model — backend MUST confirm):**
The risk: one contact represented as TWO rows (the original incoming Call with `IsCallbackRequest=true` AND a
resulting Callback row). Two scenarios:
- **Scenario A (realized callback is OUTBOUND):** the callback dial to the customer is `Direction='Outgoing'`
  (consistent with our `QueueNumCompletedCallbacks` = Outgoing). Then the `Direction='Incoming'` filter above ALREADY
  excludes the realized callback → the original incoming Call (incl. `IsCallbackRequest=true`) is counted once →
  **no dedup needed, base query is correct.**
- **Scenario B (deflection creates an extra INCOMING Callback row):** the request produces both an incoming Call and
  an incoming Callback → the base query double-counts. Dedup: count the incoming Call once and EXCLUDE its linked
  incoming Callback, e.g. keep Calls + only STANDALONE incoming Callbacks (those with no originating call in-window):
  ```sql
  -- Scenario B variant: exclude incoming Callback rows that duplicate a deflected call already counted
  ... AND NOT (i."InteractionType"='Callback' AND i."IsCallbackRequest" = true)   -- adjust to the real link column
  ```
**ACTION [backend]:** confirm which scenario the RTM model uses (is the realized callback Outgoing? is there a link
column between a deflected Call and its Callback — `IsCallbackRequest`, `CustomCallData*`, shared `InteractionId`?).
Pick A or B, pin the exact predicate, and add a plumbing test that a call→callback deflection yields λ += 1 (not 2).
Default assumption pending confirmation = **Scenario A** (Outgoing realized callback → base query already dedup-safe).

## 2. AHT — avg handle time (sec), completed interactions in window
```sql
SELECT COALESCE(AVG(NULLIF(i."TalkTime",0)),0)::double precision AS aht_sec
FROM public."RTSData_Interaction" i
WHERE i."TenantId" = @tenant AND i."Workgroup" = @queue
  AND i."Direction" = 'Incoming' AND i."InteractionType" IN ('Call','Callback') AND i."CallType"='External'
  AND i."IsAnswered" = true AND i."IsInQueue" = false
  AND i."AnsweredDateTime" >= @now - (@winMin || ' minutes')::interval
  AND i."AnsweredDateTime" <  @now;
```
**⚠ OPEN (data-model, flag to backend/dba/operator):** `RTSData_Interaction` has **`TalkTime` only** — no explicit
Hold or Wrap column. Locked AHT = talk+hold+wrap. Options: (a) v1 AHT = `AVG(TalkTime)` assuming TalkTime already
includes hold, wrap approximated separately; (b) add wrap = avg PAPERWORK-group duration per handled agent from
`RTSData_UserStatusLog` in the window (join by UserId) — heavier. RECOMMEND (a) for v1 with a `wrapIncluded=false`
flag on the snapshot; refine in a follow-up. Do NOT block Phase 1 on the wrap decomposition. Guard `aht_sec>0` else NoData.

## 3. N — serving agents of the BU's skill, NOW (engine counters, not the database)
**Rule (operator 2026-10-14):** agents by skill. N for a queue = N of the ONE BU that owns that queue.

**Source — the engine's live per-group counters**, the same cells the ASD widget draws:
`UsersInStatusGroupCount_<Group>` on the grid rows of the BU.
- Per-skill by construction: the engine admits an agent to a BU only when the agent's activated skills contain every
  group the BU requires (RTM/RTM/UserManager.cs:572, `ContainsAllItems`); the per-group metric counts exactly those
  agents (RTM/RTM/Union.cs:859-865).
- BU → cells: through `RTSGrid_Row.UnionId` = BusinessUnitId (the only level that carries it; `RTSGrid_Grid.UnionId` and
  `RTSGrid_Cell.UnionId` are -1 on 234, measured by devops 2026-10-14). One BU spans many grids; only the BU's rows are read.
- Group → cell: by the metric catalogue (`MetricFunction = 'UsersInStatusGroupCount'`, group = `MetricParameter`), not
  by a guessed metric name.
- N = Σ over the configured serving groups of that group's counter (the same counter repeated in several grids is taken
  once — max, not sum; a disagreement between grids is logged as a stale grid).
- Implementation: `src/CcDashboard.Infrastructure/Wfm/WfmEngineAgentCountProvider.cs` (singleton, relay subscriptions).

**Unknown is not zero.** N is UNKNOWN (snapshot `state = nodata`, `nActual = null`, with a reason) when: no serving group
is configured; the BU has no grid rows; a configured group has no cell; no value has arrived yet; or the queue belongs
to no BU or to SEVERAL BUs (no single skill defines N — summing would double-count agents holding both skills).
Zero means "nobody is serving"; unknown means "we do not know", and Erlang must not compute on a guess.

**Why not the database** (measured 2026-10-14, PR234-V4-WFM-N-SOURCE-01):
- the database holds NO current agent state. The engine writes a status only when it ENDS (UserManager.cs:502-517 →
  UserStatusData.addDur → `RTSData_SetUserStatus`); the procedure writes the log only when `EndTime > StartTime`
  (db/functions/02_rtsdata_functions.sql:183-195) — on 234: 123 041 log rows, 0 open;
- `RTSData_UserStatus` is a per-agent, per-status, PER-DAY aggregate, and the midnight clear is commented out
  (RTM/RTM/Engine.cs:960-975) — on 234: 13 630 rows over 29 dates since 2026-09-08;
- so the v0.2 query counted roster agents who had a serving status on ANY day: N = 38 against 25 logged in (BU 22);
- "last log row per agent" is NOT a fix: it returns the status the agent LEFT;
- the v0.2 roster (§36a BU→SG→AG→user walk) is not used for N: for BU 22 it gave 41 agents mostly answering other BUs' queues.

**Serving groups.** `WfmServingStateGroups` is picked from the groups the engine publishes for the BU
(`GetPublishedGroupNamesAsync` — the `MetricParameter` values), so a saved name matches a counter exactly; no casing
reconciliation. Which groups count as "serving" (e.g. whether PAPERWORK does) is the operator's decision.

## 4. WfmSnapshot — loop output contract (per tenant+queue, every 30 s)
```jsonc
{
  "tenantId": "...", "queueId": "<Workgroup>", "asOf": "<UTC>", "windowMin": 30,
  "inputs":  { "lambdaPerHour": 160.0, "ahtSec": 180.0, "nActual": 10, "wrapIncluded": false },
  "erlang":  { "trafficA": 8.0, "pWaitC": 0.409, "predictedSlPct": 67.2, "predictedAsaSec": 36.8,
               "requiredAgents": 11, "requiredCapped": false, "erlangBPct": 0.0,
               "occupancyPct": 80.0, "understaffPct": 9.1, "staffVariance": -1 },
  "state":   "ok" | "overloaded" | "nodata",     // overloaded when nActual<=A; nodata when aht<=0, nActual=0 or N unknown
  "unknownReason": null | "<why N is unknown>",  // set together with nActual = null (§3)
  "rag":     { "predictedSl":"red", "occupancy":"green", ... }   // per-metric band, from config thresholds
}
```
Values/sentinels come straight from `ErlangCalculatorService` (nullable → `overloaded`/`nodata`). Erlang B uses
`TrunkCapacity` config; M-10 FTE (daily, DefaultShrinkage fallback) MAY ride here later.

## 5. TenantSettings — WFM config schema (new section)
| Key | Type | Default | Used by |
|---|---|---|---|
| `WfmServingStateGroups` | text[] | `{}` (empty → N unknown) | N (§3) — picked from the engine's published group names |
| `WfmWindowMinutes` | int | 30 | λ, AHT window |
| `SlTargetPct` | double | 80 | RequiredAgents, SL rag |
| `SlThresholdSec` | int | 20 | PredictedSL/ASA `t`, RequiredAgents |
| `TrunkCapacity` | int | 100 | ErlangB |
| `DefaultShrinkage` | double | 0.28 | FteRequired fallback (Phase 1b) — ⚠ stored and editable in UI, NOT applied by any calculation on v4 (2026-10-17) |
| `EnableWfmRealtime` | bool | true | loop gate |
| `WfmThresholds` | jsonb | per-metric defaults (spec §3) | RAG bands, per-tenant override |

## 6. SARGability / indexing (pair with DBA — 30 s cadence, many (tenant,queue))
- λ + AHT filter on `("TenantId","Workgroup","Direction","InteractionType")` + range on `InQueueDateTime` /
  `AnsweredDateTime`. Need composite index e.g. `("TenantId","Workgroup","InQueueDateTime")` and
  `("TenantId","Workgroup","AnsweredDateTime")` to avoid full scans of `RTSData_Interaction` every 30 s.
- N: no database query (§3) — engine counters through the relay; the BU→cells map is cached.
  Consider computing λ/AHT for ALL active queues in ONE pass per tick (GROUP BY Workgroup) — DBA to advise.
- OnDate is `varchar` — do NOT filter time on it; use the `timestamptz` columns (`InQueueDateTime`/`AnsweredDateTime`).

## 7. Open items (→ §4 / operator / backend / dba)
- O-1 AHT wrap decomposition — **LOCKED**: v1 = `TalkTime` only, `wrapIncluded=false` (§2). Wrap = follow-up. [operator ✔]
- O-2 N source — **LOCKED (operator 2026-10-14): agents by the BU's SKILL**, from the engine's live counters (§3);
  not the database, not the §36a roster. [operator ✔ / backend 704b335, f90c3f5]
- O-3 λ callback-requests — **LOCKED: INCLUDE** as offered demand, with NO-DOUBLE-COUNT dedup (§1); backend to pin the RTM deflection model. [operator ✔ / backend to confirm scenario]
- O-4 one-pass GROUP BY Workgroup vs per-queue query at 30 s (§6). [dba]
- O-5 short-abandon — **LOCKED: INCLUDE** (<5 s counted; NO exclusion filter, confirmed §1). [operator ✔]

## 8. Handoffs
Data-layer (this spec, mine + dba SARGability) → backend authors the IHostedService 30 s loop consuming these queries
+ ErlangCalculatorService (4e21796) → emits WfmSnapshot (§4) → Shell WFM widgets render + RAG. self-§4 done → coordinator §4.
