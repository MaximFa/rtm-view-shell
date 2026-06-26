# CC-HIST-B0 — SF-BI-001 PG-filter retrofit + UserReport soft-delete + export caps (Track B-0, HARD GATE)

> Owner: role-bi (bi-0619). Execute: NATIVE CC. Branch: v3. Reviews: security (SF-BI-001) + dba (migration) + coordinator §4.
> STATUS: §4-PASS coordinator-0612 (2026-06-21T21:09:06Z) — EXECUTE authorized: native CC, branch v3, web:/db:, commit.lock, security(SF-BI-001)+dba(migration) review AFTER, NO push. (FREEZE #3 is LIFTED — barrier pushed; v3 commits proceed.)
> WHY HARD GATE: SF-BI-001 [HIGH, PG-04/CODE-03] — the landed report handlers return ALL tenant queues/agents when the
> client list is null/empty, and honor an arbitrary client list with NO PG check. Latent (no UI yet). MUST be fixed
> BEFORE any reports UI/endpoint (Track B). Reads-only on RTM contour (NGC_*/RTSData_* read for scope resolution only).

## STEP 0 — integrity (§0.6a) + branch
```bash
cd "D:\Claude\Projects\RTM View Shell"; git fetch; git checkout v3; git status --short
for f in $(git status --short | grep "^ M" | awk '{print $2}'); do H=$(git show HEAD:"$f" 2>/dev/null|wc -l); W=$(wc -l <"$f" 2>/dev/null); [ "$((H-W))" -gt 0 ] && { git show HEAD:"$f">"$f"; echo "RESTORED $f"; } || echo "OK $f"; done; sync
# Confirm ADDENDUM A rev1.2 (three-tier) is committed on v3; if docs/bi/TZ lacks "THREE tiers", flag coordinator (docs commit pending).
```
## STEP 1 — skills + sync block
Read role-bi (§A/§C/§D) + session-coord + frontend-design (n/a here) ; run §C VERIFY. Apply tools/cc_prompt_sync_block.md:
slug=`bi-0619`, claims=`src/CcDashboard.Application/HistoricalReports/**`,
`src/CcDashboard.Infrastructure/Persistence/Repositories/HistoricalReportRepository.cs`,
`src/CcDashboard.Infrastructure/Handlers/HistoricalReportHandlers.cs`,
`src/CcDashboard.Domain/Domain/Historical/UserReport.cs`,
`src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs` (UserReport GQF + DbSet only),
new EF migration under `src/CcDashboard.Infrastructure/Migrations/App/`,
`tests/CcDashboard.Tests.Unit/HistoricalReports/**`, new `tests/CcDashboard.Tests.Security/**` if that project exists (else add to Unit).
## STEP 2 — binding PREAMBLE -> .coord/cc/bi.md.

---

## THE WORK

### A. SF-BI-001 — server-side PG scope (MANDATORY, non-bypassable)
The vulnerable methods (HistoricalReportRepository): `GetQueueIntervalsAsync(..., IReadOnlyList<string>? workgroups, ...)`
and `GetAgentIntervalsAsync(..., IReadOnlyList<string>? agentExternalIds, ...)` — today: `if (list is {Count:>0}) Where(Contains)`
=> null/empty = NO filter = ALL tenant rows; arbitrary client list honored. FIX:

A1. ReportScopeResolver (Application service, e.g. src/CcDashboard.Application/HistoricalReports/ReportScopeResolver.cs)
   injecting ICurrentUserAccessor + IPermissionGroupRepository (+ a queue/agent ext-id lookup). Produces a ReportScope:
   - `bool FullScope` = true ONLY if Role == Superadmin (full tenant; no queue/agent restriction).
   - else from currentUser.PermissionGroupId:
     * allowedWorkgroups = PG.AllowedQueues (PgQueue -> NGC_Queues.Id) MAPPED to NGC_Queues.ExternalId (= hist Workgroup)
       for the tenant. (AvailableEntityDto exposes Guid Id only -> join NGC_Queues to get ExternalId.)
     * allowedAgentExternalIds = agents in PG scope = NGC supergroup/agentgroup pool of PG.AllowedSupergroups +
       PG.AllowedBusinessUnits -> NGC_SupergroupAgentgroup -> NGC_UserAgentgroup.UserId (external agent id), tenant-scoped
       (same pool shape as fn_daytrendagentstatus). De-dup.
   - PG-03: if !FullScope AND the relevant allowed set is EMPTY -> DENY (return empty result; do NOT fall through to all).

A2. Effective filter = INTERSECT(clientRequested ?? allowedSet, allowedSet). Out-of-PG client entries are DROPPED
   (or 403 — choose: drop silently for usability, but LOG; security to confirm). Null/empty client list => allowedSet (NOT all).

A3. Enforce at the HANDLER->REPO boundary, NOT bypassable by a null list. Change repo signatures so non-superadmin ALWAYS
   filters: e.g. `GetQueueIntervalsAsync(Guid tenantId, DateTime from, DateTime to, ReportScope scope, CancellationToken ct)`
   where the repo applies `if (!scope.FullScope) query = query.Where(x => scope.AllowedWorkgroups.Contains(x.Workgroup))`
   UNCONDITIONALLY. The handler builds ReportScope (resolver) + intersects the client filter into scope.AllowedWorkgroups
   BEFORE calling the repo. There is no code path where a non-superadmin gets an unfiltered query.
   (Alternative the coordinator allowed: a MediatR AuthorizationBehavior for the 4 report queries — repo-scope chosen here
   for explicitness/testability. If you prefer Behavior, keep filtering MANDATORY + null-list non-bypassable.)

A4. Apply to ALL FOUR: Q1 GetQueueInterval, Q5 GetQueueWaitTime (queues); A4 GetAgentMonthly, A5 GetAgentShiftDetail (agents).

### B. UserReport soft-delete (minor) — dba §4 nit folded
Add to UserReport (Domain): IsDeleted bool, DeletedAt timestamptz?, DeletedByUserId uuid?. AppDbContext: combined GQF
on user_reports (TenantId && !IsDeleted). EF-app (App context) migration.
- dba NIT (explicit in DDL): `"IsDeleted" boolean NOT NULL DEFAULT false` (existing rows stay visible + GQF works);
  `"DeletedAt" timestamptz NULL`, `"DeletedByUserId" uuid NULL`. Mirrors the Dashboard soft-delete (CLAUDE.md §6/§7).
- ⚠ EF-APP MIGRATION — do NOT INSERT into db_patch_history (EF migrations are tracked by __ef_migrations_history; §38a
  self-record is for db/migrations/*.sql ONLY; a db_patch_history INSERT in an EF migration regresses the CC-HIST-001
  42P01 fresh-rebuild bug — 11622f0). No companion db/migrations file for this EF-app change.
(No seed/use yet — Track C uses it; land the columns now.)

### C. Export caps (minor)
Add a date-range cap (configurable, default 92 days) validated in the report query validators (FluentValidation) — reject
ranges over cap. CSV row cap per AUD-08 (max 50,000) — enforce where the export/query is bounded (reject/deny over-cap in v1;
async export = v2). Audit `Report.Exported` is wired in Track B (note here, not implemented).

### D. Tests (security-focused)
ReportScope/PG tests: (1) non-superadmin + null client list => results limited to PG-allowed queues/agents (NOT all);
(2) client list with an out-of-PG entry => that entry excluded; (3) empty PG (no allowed queues) => DENY (empty/forbid);
(4) Superadmin => full tenant scope; (5) agent-scope pool resolution from PG supergroups/BUs; (6) date-range cap rejects over-cap.

### ACCEPTANCE
- `dotnet build` green; new + existing tests green (>=6 incl. the SF-BI-001 cases).
- No code path returns unfiltered tenant queues/agents for a non-superadmin (grep/inspect: repo filter unconditional when !FullScope).
- UserReport migration applies fresh+existing; GQF active. Export caps reject over-cap.
- Reads-only on NGC_*/RTSData_* (scope resolution); zero contour writes.
- Commit `web:` (+ `db:` for the migration) on v3, commit.lock, object-store-verified, NO push.

## STEP 3 — binding POSTAMBLE RESULT -> .coord/cc/bi.md. STEP 4 — journal + §0.7 re-sync. Ping security-0620 + dba-0620 to review. NO git push (§37).
