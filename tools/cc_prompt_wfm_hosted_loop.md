# CC Task — WFM Phase 1 (B1): WfmInputQueryService + WfmRealtimeLoop (against dba-LOCKED window-frame)

> Consumes docs/wfm-phase1-datalayer-spec.md v0.2 + ErlangCalculatorService (4e21796) + B0 (07b48a1: WfmSnapshot,
> IWfmSnapshotStore, TenantSettings WFM §5). Implements the λ/AHT/N inputs + the 30s hosted loop, honoring the
> dba-LOCKED window-frame (14:22) EXACTLY. NO SignalR (store is the hand-off). Territory: **web**. NO push. Prefix `web:`.

## STEP 0 — §0.6a integrity (branch v3). §40 reads + role-backend §A/§C. §37 NO push. §0.3 Python+fsync (Edit BANNED). commit.lock.
## STEP 1 — Sync slug backend-0626. Claims (all new unless noted):
##   - src/CcDashboard.Infrastructure/Wfm/WfmInputQueryService.cs              (new)
##   - src/CcDashboard.Application/Interfaces/IWfmInputQueryService.cs         (new)
##   - src/CcDashboard.Infrastructure/Wfm/WfmRealtimeLoop.cs                    (new: IHostedService 30s)
##   - src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs (MODIFY: +AddHostedService<WfmRealtimeLoop>; store already registered in B0)
##   - tests/CcDashboard.Tests.Unit/Wfm/*  (optional plumbing test)
## STEP 2 — BINDING preamble to .coord/cc/backend.md.

---

## ⚠⚠ DBA-LOCKED WINDOW-FRAME (14:22) — implement EXACTLY, mark `-- DBA-FRAME: INTERIM`

1. **OFFSET SOURCE = the interaction's OWN `"TimeZone"` column** (self-consistent with the stamp) — NOT a fresh
   NGC_Site.TimeZone lookup (geo-right but frame-WRONG). Build a CACHED per-tenant `Workgroup -> TimeZone` map:
   `SELECT DISTINCT "Workgroup","TimeZone" FROM "RTSData_Interaction" WHERE "TenantId" = @t` (refresh slowly — TTL
   e.g. 5 min / every N ticks). Group Workgroups by TimeZone → per-offset PARTITIONS.
   - Mixed TimeZone within one Workgroup → pick the DOMINANT TimeZone + `AsyncLogger`/Serilog WARN; **NO per-row
     fallback** (that would be non-SARGable).

2. **BOUNDS computed APP-SIDE (byte-mirror the stamp), NOT now()/UTC in SQL:** per distinct TimeZone partition:
   ```csharp
   // ⚠ C1 PARITY — wallNow MUST be a VERBATIM mirror of RTM/RTM/IDInteraction.getLocalDateTime (Shell cannot call it;
   //   cross-project). Port its body EXACTLY, incl. edge cases (null/empty/malformed -> UtcNow, offset 0). Do NOT use
   //   ConvertTimeFromUtc (diverges on the edge cases). Reference: RTM/RTM/IDInteraction.cs:253-288.
   //   static DateTime StampWallNow(string tz):
   //     DateTime t = DateTime.UtcNow;
   //     if (string.IsNullOrWhiteSpace(tz)) return t;                 // null/empty/whitespace -> UtcNow (offset 0)
   //     try {
   //         string cleaned = tz.Trim();
   //         bool negative = cleaned.StartsWith("-");
   //         string stripped = cleaned.TrimStart('+').TrimStart('-');
   //         TimeSpan offset;
   //         if (TimeSpan.TryParse(stripped, out offset)) { if (negative) offset = offset.Negate(); }
   //         else { offset = TimeZoneInfo.FindSystemTimeZoneById(tz).GetUtcOffset(DateTime.UtcNow); }  // IANA/Windows id
   //         t = t.Add(offset);
   //     } catch { /* unknown -> silently UtcNow (offset 0) */ }
   //     return t;
   var wallNow = StampWallNow(siteTimeZoneString);   // byte-mirror of the stamp, incl. edge cases
   var winHi   = DateTime.SpecifyKind(wallNow, DateTimeKind.Utc);
   var winLo   = winHi.AddMinutes(-winMin);
   ```
   Pass @winLo/@winHi as `timestamptz`. Predicate = **plain range on the BARE `InQueueDateTime`** (SARGable on
   ix_rtsint_wfm_inq): `AND i."InQueueDateTime" >= @winLo AND i."InQueueDateTime" < @winHi`. AHT identical with
   `AnsweredDateTime` + ix_rtsint_wfm_ans + `IsAnswered=true AND IsInQueue=false`.

3. **Scenario A** (backend-confirmed): NO exclusion predicate. Short-abandon + callback-requests INCLUDED (locked λ).
   λ per §1: `Direction='Incoming' AND InteractionType IN ('Call','Callback') AND CallType='External'` + the range.
   AHT per §2: same + `IsAnswered=true AND IsInQueue=false`, `COALESCE(AVG(NULLIF("TalkTime",0)),0)`, guard aht>0 else nodata.

4. **ONE-PASS GROUP BY "Workgroup"** WITHIN each TZ partition (`WHERE ... AND "Workgroup" = ANY(@wgList)`), not per-queue,
   not one global union pass. FromSqlInterpolated (CODE-01), AsNoTracking.

5. Mark the frame block `-- DBA-FRAME: INTERIM` with the comment: *collapses to ONE global one-pass (winHi=UtcNow, no
   per-TZ partition) when the backlogged store-true-UTC fix lands — tag for removal.*

## N (§3) — current snapshot, NO window-frame
`SELECT COUNT(DISTINCT us."UserId") FROM "RTSData_UserStatus" us WHERE us."TenantId"=@t AND us."StatusGroup" = ANY(@servingGroups) AND us."UserId" = ANY(@servingAgents)`.
- `@servingGroups` from `TenantSettings.WfmServingStateGroups` resolved via Agent State Definitions (not hard-coded).
- `@servingAgents` = the queue's serving set from the EXISTING agent-pool: REUSE `IBuMembershipResolver`/`BuMembershipResolver` (§36a workgroup-activation, per-queue = your O-2 confirmed) — the SAME set the AgentGrid uses. CACHE per-queue membership (changes slowly), resolve NOT per-tick. Do NOT reinvent.
- SARGable on ix_rtsus_wfm. Guard NActual>0 else nodata.

## WfmRealtimeLoop (IHostedService, 30s)
- `PeriodicTimer(TimeSpan.FromSeconds(30))`; CancellationToken from StopAsync. Per active tenant with `EnableWfmRealtime=true`: create a DI scope, set `ITenantContext.TenantId` (§ARCH-07) BEFORE any query.
- For each queue: A=`TrafficIntensity(λ,aht)`; call ErlangCalculatorService (ErlangC/PredictedSl/PredictedAsaSec/RequiredAgents/OccupancyPct/UnderstaffPct/StaffVariance/ErlangB); map nullable→`state` (overloaded when N<=A; nodata when aht<=0 or N=0); RAG from `WfmThresholds`. Build `WfmSnapshot` (§4, B0 record) → `IWfmSnapshotStore.Set`.
- Per-tenant try/catch (one tenant's failure must NOT kill the loop). Serilog structured, NO PII (no caller ids). NO SignalR.

## §4 CONDITIONS (coordinator 14:52) — MANDATORY

### C1 — PARITY VERIFY (correctness crux; do BEFORE commit, do NOT assume)
B1's `StampWallNow` RE-IMPLEMENTS RTM's `IDInteraction.getLocalDateTime` (Shell cannot call it cross-project). Before commit:
1. READ `RTM/RTM/IDInteraction.cs` getLocalDateTime (currently lines 253-288) and confirm `StampWallNow` mirrors it EXACTLY, including EVERY edge case: null / empty / whitespace `TimeZone` -> `UtcNow` (offset 0); offset-form parse (`Trim`, leading `-` = negative, `TrimStart('+').TrimStart('-')`, `TimeSpan.TryParse`, `Negate` if negative); IANA/Windows id -> `FindSystemTimeZoneById(tz).GetUtcOffset(UtcNow)`; ANY exception (incl. unknown id) -> silently `UtcNow` (offset 0). `wallNow = UtcNow + offset` (NOT ConvertTimeFromUtc).
2. In the BINDING RESULT, STATE the exact null/empty/malformed handling and confirm it matches the stamp byte-for-byte. If getLocalDateTime does anything `StampWallNow` cannot mirror, FLAG it (do not silently diverge).

### C2 — STANDING FUNCTIONAL GATE (do NOT declare WFM numbers correct on the CC gate alone)
build0 + pins-honored (object-store) = the LANDING gate only (zero prod impact until the store is consumed). The FRAME
correctness — does the 30-min window read the RIGHT rows; do λ/AHT/N match reality per queue on 140 — is a LIVE-DATA gate
that happens AFTER the store is inspectable (WFM-3c shell widgets / a debug read), by QA/operator on 140. Mark this the
standing functional gate in the RESULT; the CC gate is landing-only.

## STEP 3 — build + tests
`dotnet build src/CcDashboard.Web` — 0 errors. Optional unit test: a call→callback deflection sample yields λ += 1 (Scenario A, spec §1) if doable without DB; else note as integration follow-up.

## STEP 4 — pre-commit + commit (commit.lock) — ONE commit:
`web: WFM Phase1 B1 — WfmInputQueryService (dba-locked per-TZ frame) + WfmRealtimeLoop 30s [wfm]`
§0.6 verify -> journal -> lock release -> §0.7 re-sync. NO push.

## STEP 5 — BINDING RESULT: commit hash, files, build/test, confirm the DBA-FRAME pins honored (offset=own TimeZone col; app-side winLo/winHi byte-mirror; bare-column SARGable range; per-TZ one-pass; INTERIM tag), status.

## Acceptance
- [ ] Offset source = interaction's OWN "TimeZone" column via cached Workgroup->TimeZone map; mixed-TZ workgroup → dominant + WARN, no per-row fallback.
- [ ] winLo/winHi computed APP-SIDE (ConvertTimeFromUtc→SpecifyKind(Utc)→AddMinutes), siteTz resolved with getLocalDateTime parity; SQL predicate = plain range on bare InQueueDateTime/AnsweredDateTime (SARGable), NO now()/UTC in SQL.
- [ ] Scenario A (no exclusion), short-abandon+callback INCLUDED; one-pass GROUP BY Workgroup per TZ partition.
- [ ] N = current snapshot (no window) via BuMembershipResolver §36a (per-queue, cached), servingGroups from config.
- [ ] C1: StampWallNow is a VERBATIM mirror of getLocalDateTime incl. null/empty/malformed->UtcNow(offset 0); RESULT states the edge handling + byte-parity (no ConvertTimeFromUtc).
- [ ] C2: RESULT marks live λ/AHT/N-vs-reality on 140 as the STANDING functional gate (CC gate = landing-only).
- [ ] `-- DBA-FRAME: INTERIM` tagged for removal on store-true-UTC. IHostedService registered. Erlang via 4e21796 → WfmSnapshot → store. NO SignalR. build green. Prefix web:. NO push.

## Git push: do NOT run git push. Commit only.
