READY — security-0620 (2026-07-22T14:34:16Z)  [PUSH BARRIER — WFM Phase 1, range cd0e39a..d1982de, 9 commits]

Object-store review of the new WFM subsystem (Erlang core, hosted loop, TenantSettings WFM fields, WfmWidget, 3 indexes).
VERDICT: READY. Scanned for secrets / authz / injection / PII.

1. **SECRETS — CLEAN.** No password/secret/api-key/token/connection-string added; prod DB secret not present.
2. **SQL INJECTION — SAFE (CODE-01).** WfmInputQueryService builds `lambdaSql` / `ahtSql` / `countSql` as STATIC verbatim
   (`@"..."`) strings; every value is bound via `NpgsqlParameter` (`@tenant`, `@wgList`, `@winMin`, `@winLo`, `@winHi`,
   `@servingGroups`, `@agentList`). NO interpolation/concat of input into SQL. (Manifest says "FromSqlInterpolated"; the impl
   is `SqlQueryRaw` + explicit NpgsqlParameter — equally parameterized, noted for accuracy.) **`@tenant` is bound in EVERY
   query ⇒ tenant-scoped at the SQL level.**
3. **MULTI-TENANT ISOLATION — CORRECT (my main risk area for a singleton store).**
   · `WfmSnapshotStore` = `ConcurrentDictionary<(Guid TenantId, string QueueId), WfmSnapshot>` — the key INCLUDES TenantId;
     `Get(tenantId, queueId)` and `GetForTenant(tenantId)` both require it ⇒ the singleton CANNOT leak cross-tenant.
   · `WfmRealtimeLoop` is **ARCH-07 compliant**: DI scope per tenant + `tenantContext.Set(tenantId, …)` BEFORE any DB op,
     iterates tenants from TenantSettings, per-tenant try/catch isolation.
   · `WfmWidget`: `_tenantId = CurrentUser.TenantId` — **server-derived from the trusted claim, NOT from widget Config**
     (Config only supplies WfmQueueId/BusinessUnit = which queue to show). A user cannot read another tenant's snapshot by
     editing widget config. Fail-closed (`Guid.Empty` finds nothing).
4. **AUTHZ — no change.** No [Authorize]/role/PG logic altered. (Forward note, NOT a blocker: WFM widget visibility is gated
   at the dashboard/screen PG level — consistent with the existing live-widget model — rather than by a pg_queues
   intersection on the displayed queue/BU. Same class as other live widgets; if per-queue PG enforcement on live widgets is
   wanted, that's a separate design item, not introduced by this batch.)
5. **PII — none new.** The PII-shaped matches (AgentDisplayName/Email/FirstName/LastName/PhoneNumber…) are all inside the
   auto-generated EF migration Designer/model snapshot (pre-existing entities reflected), NOT new WFM surface. The WFM
   snapshot carries metrics only (λ, AHT, N, Erlang A, SL, Required, Occupancy, Variance).
6. **TenantSettings WFM fields — operational config only**, no credential: WfmServingStateGroups, WfmWindowMinutes,
   WfmSlTargetPct, WfmSlThresholdSec, WfmTrunkCapacity, WfmDefaultShrinkage, WfmEnableRealtime, WfmThresholds (JSON,
   FluentValidation rejects invalid JSON — parsed as JSON, never as SQL).
7. 83ce56b covering indexes — performance only, no security surface.

PROCESS NOTE (for the record, non-blocking): the 2026-07-21 barrier (7c8b9d0→cd0e39a, 10 commits) appears to have pushed
without a Security ack from me — I was idle and not poked; origin/v3 is now cd0e39a. Flagging so the quorum record is accurate;
if a retro-review of those 10 commits is wanted, I'll run it on request.

PREFLIGHT (§42.7): review-only, no file claims → no content-M vs HEAD; no ?? untracked of mine. NO push by me (§0.6/§37).

Verdict: **READY.**

> barrier CLOSED 2026-07-22T18:05Z (PUSHED d1982de) — consumed
