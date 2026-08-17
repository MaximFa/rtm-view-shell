# WFM Phase 1 — data-layer spec (feeds ErlangCalculatorService 4e21796) — v0.2 (O-1/O-3/O-5 locked)

> Author/lead: metrics-3-0609. Paired with: DBA (SARGability). Design-first, NO code, NO push. Inputs LOCKED by
> operator 2026-07-21. Feeds the pure-math `ErlangCalculatorService` (commit 4e21796). Basis: `docs/wfm-phase1-erlang-core-spec.md`.
> Tables (EXISTING, no new): `RTSData_Interaction`, `RTSData_UserStatus` (current), `RTSData_UserStatusLog` (history).

## 0. LOCKED inputs (operator 2026-07-21)
- Window: **30 min rolling** (per-tenant configurable). Scope: **per (tenant, queue=Workgroup)**.
- **λ** = OFFERED incoming = Direction Incoming, InteractionType ∈ {Call, Callback}, that ARRIVED in the window
  (answered + abandoned + still-queued). Scaled to **calls/hour**.
- **AHT** = talk + hold + wrap, avg over the window.
- **N** = agents in **serving state-groups = Ready + Talking + Wrap** (configurable set), tied to Agent State
  Definitions (reuse the mapping). SL default 80% @ 20 s.

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

## 3. N — serving agents on the queue, real-time snapshot
```sql
-- serving groups from config (default): 'Available','On Phone','Paperwork'  (Ready/Talking/Wrap)
SELECT COUNT(DISTINCT us."UserId") AS n_actual
FROM public."RTSData_UserStatus" us
WHERE us."TenantId" = @tenant
  AND us."StatusGroup" = ANY(@servingGroups)            -- config set, mapped via Agent State Definitions
  AND us."UserId" IN ( /* agents serving @queue */ );    -- membership resolver — see below
```
**Membership resolver (reuse, do NOT reinvent):** the set "agents serving @queue" reuses the EXISTING agent-pool /
workgroup-activation logic (NGC_UserAgentgroup ↔ workgroup activation, per §36a agent-resolution; the same pool the
AgentGrid/agent-scoped metrics use). Coordinate the exact join with backend/dba — it must equal what the agent grid
shows for that queue. `StatusGroup` values come from `tenant_agent_state_groups.GroupName` (§21); the serving set is the
CONFIG list (§5), resolved through Agent State Definitions — not hard-coded strings.
**⚠ OPEN:** confirm the queue↔serving-agents join source (workgroup activation vs skill assignment) with backend.

## 4. WfmSnapshot — loop output contract (per tenant+queue, every 30 s)
```jsonc
{
  "tenantId": "...", "queueId": "<Workgroup>", "asOf": "<UTC>", "windowMin": 30,
  "inputs":  { "lambdaPerHour": 160.0, "ahtSec": 180.0, "nActual": 10, "wrapIncluded": false },
  "erlang":  { "trafficA": 8.0, "pWaitC": 0.409, "predictedSlPct": 67.2, "predictedAsaSec": 36.8,
               "requiredAgents": 11, "requiredCapped": false, "erlangBPct": 0.0,
               "occupancyPct": 80.0, "understaffPct": 9.1, "staffVariance": -1 },
  "state":   "ok" | "overloaded" | "nodata",     // overloaded when nActual<=A; nodata when aht<=0 or nActual=0
  "rag":     { "predictedSl":"red", "occupancy":"green", ... }   // per-metric band, from config thresholds
}
```
Values/sentinels come straight from `ErlangCalculatorService` (nullable → `overloaded`/`nodata`). Erlang B uses
`TrunkCapacity` config; M-10 FTE (daily, DefaultShrinkage fallback) MAY ride here later.

## 5. TenantSettings — WFM config schema (new section)
| Key | Type | Default | Used by |
|---|---|---|---|
| `WfmServingStateGroups` | text[] | `{Available, On Phone, Paperwork}` | N (§3) — resolved via Agent State Definitions |
| `WfmWindowMinutes` | int | 30 | λ, AHT window |
| `SlTargetPct` | double | 80 | RequiredAgents, SL rag |
| `SlThresholdSec` | int | 20 | PredictedSL/ASA `t`, RequiredAgents |
| `TrunkCapacity` | int | 100 | ErlangB |
| `DefaultShrinkage` | double | 0.28 | FteRequired fallback (Phase 1b) |
| `EnableWfmRealtime` | bool | true | loop gate |
| `WfmThresholds` | jsonb | per-metric defaults (spec §3) | RAG bands, per-tenant override |

## 6. SARGability / indexing (pair with DBA — 30 s cadence, many (tenant,queue))
- λ + AHT filter on `("TenantId","Workgroup","Direction","InteractionType")` + range on `InQueueDateTime` /
  `AnsweredDateTime`. Need composite index e.g. `("TenantId","Workgroup","InQueueDateTime")` and
  `("TenantId","Workgroup","AnsweredDateTime")` to avoid full scans of `RTSData_Interaction` every 30 s.
- N: index `RTSData_UserStatus("TenantId","StatusGroup")`; the membership resolver should be cached (per-queue agent
  set changes slowly). Consider computing λ/AHT/N for ALL active queues in ONE pass per tick (GROUP BY Workgroup)
  rather than N queries — DBA to advise.
- OnDate is `varchar` — do NOT filter time on it; use the `timestamptz` columns (`InQueueDateTime`/`AnsweredDateTime`).

## 7. Open items (→ §4 / operator / backend / dba)
- O-1 AHT wrap decomposition — **LOCKED**: v1 = `TalkTime` only, `wrapIncluded=false` (§2). Wrap = follow-up. [operator ✔]
- O-2 N queue↔serving-agents join source (workgroup activation vs skill) — reuse agent-pool logic (§3). [backend/dba]
- O-3 λ callback-requests — **LOCKED: INCLUDE** as offered demand, with NO-DOUBLE-COUNT dedup (§1); backend to pin the RTM deflection model. [operator ✔ / backend to confirm scenario]
- O-4 one-pass GROUP BY Workgroup vs per-queue query at 30 s (§6). [dba]
- O-5 short-abandon — **LOCKED: INCLUDE** (<5 s counted; NO exclusion filter, confirmed §1). [operator ✔]

## 8. Handoffs
Data-layer (this spec, mine + dba SARGability) → backend authors the IHostedService 30 s loop consuming these queries
+ ErlangCalculatorService (4e21796) → emits WfmSnapshot (§4) → Shell WFM widgets render + RAG. self-§4 done → coordinator §4.
