

## 2026-06-14T07:07:05Z | binding: backend <-> CC | directive: tools/cc_prompt_r1_ef_maxduraction_align.md | status: open
### DIRECTIVE: EF map RtsDataUserStatus.MaxDuration -> column "MaxDuraction" + BackendEmulation rename migration. Claims: BackendEmulationDbContext.cs + Migrations/BackendEmulation/**. web:. NO push.

### RESULT (by CC): commit c1f66af; HasColumnName("MaxDuraction") added to RtsDataUserStatus; migration AlignRtsDataUserStatusMaxDuractionColumn = RenameColumn MaxDuration->MaxDuraction; has-pending-model-changes CLEAN; build OK (0 errors, 9 warnings). NO push. verified: object-store.
## 2026-06-14T07:10:29Z | binding: backend <-> CC | directive: tools/cc_prompt_r1_ef_maxduraction_align.md | status: done
> consumed 2026-06-18T15:13:05Z by coordinator-0612 — 234 STEP-1 NGC verdict: NGC_Delete*Mapping (BusinessUnitData.cs:484/534/583) all ExecuteNonQuery=CALL -> B=1 overload canonical = PROCEDURE (RTM-SEC-002), self-heal on fn re-apply CORRECT. ✅ STEP-1 gate satisfied (dba list + backend NGC). STEP 2 routed.


## 2026-06-20T09:56:33Z | binding: backend <-> CC | directive: tools/cc_prompt_hist_a3_callid.md (DIAGNOSIS) | status: done
### DIRECTIVE: A3/B3 feasibility — can RTM Engine reliably stamp active-call InteractionId onto agent status rows? Contour, DIAGNOSIS ONLY, no code.
### RESULT (by backend-0620, read-only analysis; no commit):
- VERDICT: PARTIAL-YES. Implement at the calc-status PRODUCER (Call.SetCall -> UserManager.setStatus calc path), NOT at Engine.userStatusChanged (which has no interaction context).
- Class A (Hold Call.cs:241 / Wrap-Up Call.cs:529 / Talk states) = EXACT InteractionId at producer. Class B (READY/NOT_READY/LOGOUT via userStatusChanged) = NULL.
- Grain: RTSData_UserStatusLog INSERT is per-occurrence (correct C1 target); RTSData_UserStatus is aggregate bucket (do NOT stamp).
- Rule: UserManager stashes InteractionId-in-effect per open status interval; written when interval closes via UserStatusData.addDur. Concurrent interactions (consult/conf/blended) -> stamp triggering interaction or NULL; per-agent single timeline = non-fabricable limit.
- C2: p_interaction_id appended LAST, set on UserStatusLog INSERT only, keep PROCEDURE (RTM-SEC-002). C3 additive last-param plumbing setStatus->addDur->DBMng. One-release Shell+DB+RTM.
- Full reasoning + edge cases: inbox/coordinator.md 2026-06-20T09:56:33Z. No contour change made.
- verified: object-store (read of Engine.cs/Call.cs/UserManager.cs/UserStatusData.cs/DBMng.cs/IDInteraction*.cs + db/functions/02 at HEAD-worktree).


## 2026-06-22T21:00:21Z | binding: backend <-> CC | directive: tools/cc_prompt_v3_audit_fixa.md | status: done (reconciled from object-store — CC skipped the binding)
### DIRECTIVE: Audit Fix-A 1-line + fresh-DB migrate PROOF. Claims: InfrastructureServiceExtensions.cs. commit-prefix web:.
### RESULT (reconciled by backend-0620 via object-store, L-SC-28 — CC wrote no binding):
- commit d648fb0 (v3) "web: v3 Audit Fix-A" — 1 file, +1 line: `npg.MigrationsHistoryTable("__ef_migrations_history", "audit")` in the AuditDbContext registration (InfrastructureServiceExtensions.cs:58). Scoped, correct, runtime==design-time now.
- App half 187e8ca (Designer.cs) intact. Code half of the EF integrity fix = COMPLETE (187e8ca + d648fb0).
- ⚠ PD-007: the working-tree file was TRUNCATED to 151 lines (ended mid-statement) after the commit — RESTORED from HEAD (now 160 == HEAD, hash 1624052). HEAD/commit always correct.
- ❌ PROOF NOT DONE: STEP 3 fresh-DB `Web.exe migrate` (App+Audit, no 42883/42P07, idempotent) was NOT run/recorded. Acceptance "PROVEN" is UNMET. Requires a Windows fresh-DB migrate run (native CC / operator) — I cannot run it from Cowork.
- status: code done|failed=done; PROOF=pending. verified: object-store (d648fb0 diff + hash).


## 2026-06-22T21:37:01Z | binding: backend <-> CC | directive: tools/cc_prompt_v3_seed_tenantcontext_fix.md | status: done (reconciled from object-store — CC skipped the binding)
### DIRECTIVE: inject ITenantContext into DatabaseInitializer + Set(platformTenant.Id,Slug) before tenant-scoped seeds (ARCH-07). Claims: DatabaseInitializer.cs.
### RESULT (reconciled by backend-0620 via object-store, L-SC-28):
- commit f59c3bc (v3) "web: v3 seed fix — resolve platform ITenantContext ... (ARCH-07)" — 1 file, +7 lines: `using CcDashboard.Domain.Interfaces;` + ctor param `ITenantContext tenantContext,` + `tenantContext.Set(platformTenant.Id, platformTenant.Slug);` after SeedPlatformTenantAsync. EXACTLY the approved fix; scoped to DatabaseInitializer.cs.
- ⚠ PD-007: working-tree DatabaseInitializer.cs was TRUNCATED (862 vs HEAD 895) after the commit — RESTORED from HEAD (now == HEAD). Commit always correct.
- ❌ PROOF: fresh-DB startup proof NOT run by CC ("requires operator to verify"). Acceptance pending operator/fresh-DB run (restart Shell on the same fresh DB that threw -> expect superadmin created, no 'Tenant not resolved').
- status: code done; PROOF pending. verified: object-store (f59c3bc diff + hash).
 files DatabaseInitializer.cs (+1 ctor param, +4 lines incl Set call) . status done . blockers: none . verified: object-store
- Changes:
  - Added using CcDashboard.Domain.Interfaces;
  - Added ITenantContext tenantContext to constructor
  - Added tenantContext.Set(platformTenant.Id, platformTenant.Slug); after SeedPlatformTenantAsync
- fresh-DB startup proof: NOT run (no fresh Postgres available in CC session; operator must verify)
- Recommended verification: run Shell startup on fresh DB, check Created superadmin user log, verify no Tenant not resolved exception
---


## 2026-06-24T09:37:08Z | binding: backend <-> CC | directive: tools/cc_prompt_reports_f1_entities.md | status: done (reconciled from object-store — CC skipped the binding)
### DIRECTIVE: Ф1 Reports entities + EF migration + widget-type seed (5 SEPARATE entities). Claims: Domain/Reports/**, Configurations/Report*, Migrations/App new, AppDbContext.cs, spec doc.
### RESULT (reconciled by backend-0620 via object-store, L-SC-28):
- commit 473363c (v3) "feat(reports): Ф1 ..." — 19 files, +3022 insertions, ZERO deletions (narrow-add clean; only-claimed paths: 9 Domain/Reports/*.cs [5 entities + 4 enums], 5 Configurations/Report*, migration 20260624093015_AddReportEntities (.cs +202 / .Designer.cs +1979), AppDbContextModelSnapshot.cs, AppDbContext.cs +89, docs/Reports-AsDashboards-v1-Spec.md). NO CLAUDE.md/shared sweep.
- flag B APPLIED: report_screens AND report_widgets both have combined GQF `TenantId && !IsDeleted`; report_permissions/_categories/_schedules TenantId-only. ✓
- ⚠ PD-007: AppDbContext.cs (381->475) + AppDbContextModelSnapshot.cs (1722->1976) were truncated in the working tree after commit — RESTORED from HEAD (now == HEAD). Commit always correct.
- DBA DDL co-review: PENDING (committed but unpushed — amend-able if DBA flags). build/ef-probe per CC.
- status: code done; DBA DDL review pending. verified: object-store (473363c diff + hashes).

> reconciled-from-object-store 2026-06-24T09:38:28Z by coordinator-0623 (Ф1 binding not yet written by CC, L-SC-28): 473363c (v3) VERIFIED — parent 2a90c05 (correct branch), ZERO deletions, ONLY claimed (Reports entities + 5 configs + migration/Designer/snapshot + AppDbContext + spec doc; 19 files/3022 ins). New discipline (branch-by-SHA + zero-deletion) PASS. Ф2 UNBLOCKED.


## 2026-06-24T10:52:25Z | binding: backend <-> CC | directive: tools/cc_prompt_reports_f2_resolver.md | status: done (reconciled from object-store — CC skipped the binding)
### DIRECTIVE: Ф2 BuMembershipResolver (BU->queues IN; agent detail-union; cumulative ∪_SG(∩_AG); PG-intersect SF-BI-001) + tests. Claims: resolver (App/Infra) + tests.
### RESULT (reconciled by backend-0620 via object-store, L-SC-28):
- commit 2a8cffe (v3) "feat(reports): Ф2 — BuMembershipResolver ..." — 5 files, +551, ZERO deletions. Only-claimed: IBuMembershipResolver.cs (App/HistoricalReports), BuMembershipResolver.cs (Infra/Services, 174L), InfrastructureServiceExtensions.cs (+1 DI), Tests.Unit.csproj (+1), BuMembershipResolverTests.cs (329L). NARROW-ADD clean.
- PG-intersect symmetric (my Ф2 flag SATISFIED): IntersectWithPgScope(queueIds, AllowedWorkgroups, FullScope) [L43] + IntersectWithPgScope(agentSet, AllowedAgentExternalIds, FullScope) [L154]; Empty PG = DENY (PG-03) [L168-169]; FullScope=superadmin full. ✓
- NGC chain correct: BU->NGC_BusinessUnitQueueClassification ClassificationId='ALL' (§36) -> Workgroups; BU->SG->AG->NGC_UserAgentgroup (external id, IDENT). Cumulative ∪_SG(∩_AG) per-SG with empty-guards.
- Tests comprehensive: ResolveQueues (ClassificationAll/PgIntersect/EmptyPg-deny/NoBus); ResolveAgents Detail (union, partial-AG included); Cumulative (Conv-1, Conv-2, MultipleSgs union-of-intersections); PgIntersect-narrows; EmptyPg-deny; Superadmin-full; NoBus/NoSupergroups empty. ALL mandatory cases. ✓
- working-tree integrity OK (no PD-007 truncation this run). build/tests GREEN per CC (committed; I can't run dotnet from Cowork).
- status: code+tests done. verified: object-store (2a8cffe diff + hashes). NO push.

> reconciled+consumed 2026-06-24T10:52:29Z by coordinator-0623 — Ф2 2a8cffe object-store VERIFIED: parent 7410f34 (v3), ZERO deletions, only-claimed (IBuMembershipResolver[App] + BuMembershipResolver[Infra] + DI + tests). PG-intersect PRESENT via IntersectWithPgScope (queues=AllowedWorkgroups, agents=AllowedAgentExternalIds; FullScope passthrough; empty-PG=DENY PG-03) — my IntersectAgents=0 flag RESOLVED (custom helper, functionally equiv; minor DRY vs ReportScope.IntersectAgents, non-blocking). cumulative ∪_SG(∩_AG) correct (IntersectWith per SG + union). tests present. PASS. → Ф3 unblocked; security PG-review + dba NGC-join confirm (standing post-commit gate).


## 2026-06-24T11:07:37Z | binding: backend <-> CC | directive: tools/cc_prompt_maint_sfms003_contracts.md | status: done (reconciled from object-store — CC skipped the binding)
### DIRECTIVE: SF-MS-003 anti-RCE contract layer into MaintenanceService ISignalValidator seam (enum catalog + allow-list + arg-arrays + async-job + injection tests). Branch v2-backend.
### RESULT (reconciled by backend-0620 via object-store, L-SC-28):
- commit 43bb430 (v2-backend, parent c915d4d) "web: SF-MS-003 anti-RCE contract layer" — 9 files, +1007, ZERO file-deletions (the -1 = single DI line swap in Program.cs).
- Contract layer: SignalScriptMap.cs (enum-complete VerifyCompleteness(), startup fail-fast), CollectIncidentValidator.cs (ISignalValidator impl: enum allow-list + span-cap FromDays(7) + empty-reject + Since<Until), ArgumentArrayGuard.cs (ArgumentList + ISO 'o' format, no shell-concat), Jobs/Contracts/IScriptInvocation.cs + ISingleCollectLock.cs. Used the scaffold's existing enum (SignalType) + ISignalValidator seam — NO duplication. ✓
- Tests: InjectionSecurityTests.cs = 52 Fact/Theory/InlineData (injection corpus, far > the >=12 mandate); ArchitectureSecurityTests.cs = no-ProcessStartInfo.Arguments arch test (6 hits). + Tests.csproj.
- Program.cs (devops scaffold file) touched +6/-1: DI swap ISignalValidator->CollectIncidentValidator + startup SignalScriptMap.VerifyCompleteness() — the seam wiring (minor claim-boundary note; expected integration).
- build/tests GREEN per CC (committed). status: code+tests done; SECURITY post-commit re-review pending (§G RCE surface). verified: object-store (43bb430 diff). NO push.


## 2026-06-24T12:09:08Z | binding: backend <-> CC | directive: tools/cc_prompt_backend_fqa9_r1_foundation.md | status: done (reconciled from object-store — CC skipped the binding)
### DIRECTIVE: F-QA-9 R1 — IAppDbContext/IBackendEmulationDbContext seam + move AgentStateHandlers to Application (ADR-009, ARCH-11 foundation).
### RESULT (reconciled by backend-0620 via object-store, L-SC-28):
- commit f4a9b93 (v3) — 9 files. name-status: R097 Infra/Handlers/AgentStateHandlers.cs -> Application/Handlers/AgentStateHandlers.cs (rename, the move); A 3 interfaces (IAppDbContext/IBackendEmulationDbContext/IBackendEmulationDbContextFactory); M Application.csproj (+EF Core ref); M InfrastructureServiceExtensions (DI: IAppDbContext/IBackendEmulationDbContext scoped + factory singleton); M AppDbContext + BackendEmulationDbContext (implement interface); A BackendEmulationDbContextFactory. SINGLE move (rename) — no unexpected deletions.
- Application↛Infra HOLDS: moved handlers namespace=CcDashboard.Application.Handlers, ctor deps = IAppDbContext + IBackendEmulationDbContextFactory (Application interfaces), NO `using CcDashboard.Infrastructure`. ✓
- Infra AgentStateHandlers.cs: GONE from the commit + git status CLEAN. (Stale copy lingers in the Cowork mount only — unlink blocked §0.4; benign, a native checkout won't have it.)
- REMAINING-N = 20 IRequestHandler still in Infrastructure (the R2 scope, 7 files): DayTrendQueryHandler(1), DeleteUserWidgetSettings(1), GetUserWidgetSettings(1), SaveUserWidgetSettings(1), InfoSlotHandlers(12) [-> IAppDbContext seam]; HistoricalReportHandlers(4) [-> existing IHistoricalReportRepository]. MediatR-handlers arch test STILL RED with 20 = EXPECTED.
- Restored PD-007 drift: InfrastructureServiceExtensions.cs (now == HEAD). build/unit/Application↛Infra GREEN per CC (I can't run dotnet from Cowork). status: R1 code done. verified: object-store (f4a9b93). NO push.


## 2026-06-24T13:09:00Z | binding: backend <-> CC | directive: tools/cc_prompt_backend_fqa9_r2_bulkmove.md | status: done (reconciled from object-store — CC skipped the binding)
### DIRECTIVE: F-QA-9 R2 — move remaining handlers to Application + IAppDbContextFactory + drop Infra MediatR scan -> Architecture 8/8.
### RESULT (reconciled by backend-0620 via object-store, L-SC-28):
- commit 9eb8c29 (v3). Deletions = EXACTLY the 6 remaining Infra handler files moved->Application (DayTrend, Delete/Get/Save UserWidgetSettings, HistoricalReportHandlers, InfoSlotHandlers); nothing else deleted. (R1 already moved AgentStateHandlers; "7 files" in the prompt = 6 actual — benign off-by-one; all remaining handler files moved.)
- REMAINING IRequestHandler in Infrastructure = 0 -> `MediatR_handlers_should_live_in_Application_only` PASSES.
- Application↛Infra HOLDS: moved handlers (DayTrend/InfoSlot/HistoricalReport/GetUserWidgetSettings) have ZERO `using CcDashboard.Infrastructure`.
- Infra MediatR scan REMOVED (RegisterServicesFromAssemblyContaining<DayTrendQueryHandler> gone); pre-verified NO other MediatR types in Infra (no INotificationHandler/IPipelineBehavior) -> safe.
- Seam: IAppDbContext extended + NEW IAppDbContextFactory (App) + NEW AppDbContextFactory (Infra). 
- JUSTIFIED scope-add (outside literal claim, correct call): IUserRepository.GetDisplayNamesAsync + UserRepository impl ADDED — a moved handler needed user display-names; routed via the existing IUserRepository abstraction (cleaner than exposing Identity Users on IAppDbContext). 3 test files updated to match moved namespaces.
- Restored 2 PD-007 drifts (IAppDbContext.cs + InfrastructureServiceExtensions.cs == HEAD). build/unit/Tests.Architecture 8/8 GREEN per CC.
- status: F-QA-9 CODE COMPLETE -> arch suite 8/8, v3-push-blocker cleared. verified: object-store (9eb8c29). NO push.

> consumed 2026-06-24T13:22:06Z by coordinator-0623 — F-QA-9 R1 (f4a9b93) + R2 (9eb8c29) bindings CONSUMED. Both object-store VERIFIED clean (R1 single-rename AgentStateHandlers + seam; R2 6 R-renames, 0 Infra handlers, Application↛Infra holds, IUserRepository scope-add justified-as-flagged). ARCH-11 structurally COMPLETE; awaiting test live-seal (Soma /ops/test?suite=architecture). Journal reconciled (R1/F-QA-8 a2318ae/R2 were mount-dropped, now added §26.6).


## 2026-06-24T14:59:10Z | binding: backend <-> CC | directive: tools/cc_prompt_backend_fqa10_di_scoped.md | status: done (reconciled from object-store — CC skipped the binding)
### DIRECTIVE: F-QA-10 — IAppDbContextFactory registration Singleton->Scoped (fix DI captive-dependency; v3-push-blocker). Claim: InfrastructureServiceExtensions.cs (1 line, line 74).
### RESULT (reconciled by backend-0620 via object-store, L-SC-28):
- commit 051feea (v3, parent 9eb8c29) "fix(di): F-QA-10 — IAppDbContextFactory Singleton->Scoped". name-status: M InfrastructureServiceExtensions.cs ONLY. diffstat = 1 file, 1 insertion(+), 1 deletion(-). ZERO file-deletions. ✓
- THE diff (object-store verified): line 74 `services.AddSingleton<IAppDbContextFactory, AppDbContextAbstractionFactory>();` -> `services.AddScoped<...>();`. Nothing else changed.
- line 80 `AddSingleton<IBackendEmulationDbContextFactory, BackendEmulationDbContextFactory>()` UNTOUCHED (correct — Singleton-wraps-Singleton, NOT captive; F-QA-10 was ONLY the App factory). ✓
- Captive-dep root resolved: IAppDbContextFactory now Scoped, so it can legally consume the Scoped IDbContextFactory<AppDbContext> (inner) — ValidateOnBuild no longer trips. Moved handler GetUserWidgetSettings (consumes IAppDbContextFactory) now resolvable.
- working-tree was PD-007 NUL-corrupted post-commit (3 NUL bytes) — RESTORED from HEAD; WT hash now == HEAD c4f523b, NUL=0.
- build 0 / arch 8/8 / unit 146/146 GREEN per CC (committed; I can't run dotnet from Cowork). STARTUP smoke = QA (test-5-0607) live-seal pending.
- status: code done, 1-line narrow correct, object-store VERIFIED (051feea). NO push. v3-push-blocker cleared pending QA runtime seal.

> consumed 2026-06-24T15:05:00Z by coordinator-0624 — F-QA-10 binding CONSUMED. Object-store VERIFIED 051feea myself: `git show --stat` = 1 file/+1/-1; diff @@-71,7 = line 74 AddSingleton<IAppDbContextFactory>→AddScoped (ONLY change); line 80 AddSingleton<IBackendEmulationDbContextFactory> UNTOUCHED. Captive-dep root resolved. CODE done; runtime-smoke SEAL routed to QA (test-5-0607).


## 2026-06-25T08:50:05Z | binding: backend <-> CC | directive: tools/cc_prompt_backend_purge_dashboard.md | status: done (reconciled from object-store — CC skipped the binding)
### DIRECTIVE: NEW PurgeDashboardCommand(Guid Id) — physical hard-delete of a soft-deleted dashboard + cascade + idempotent RTS sweep. Guards: IsDeleted-only + Delete-perm(4)/Superadmin. Audit Dashboard.PermanentlyDeleted. Claim: PurgeDashboardCommand.cs + test.
### RESULT (reconciled by backend-0620 via object-store, L-SC-28):
- commit cad6868 (v3, parent f343b43=bi's PurgeReportScreen) "feat(dashboards): PurgeDashboardCommand — permanent hard-delete from Trash". name-status: A PurgeDashboardCommand.cs (+105) + A PurgeDashboardCommandHandlerTests.cs (+180). 2 files, 285 insertions, ZERO deletions, only-claimed. ✓
- IMPL object-store VERIFIED: record IRequest+ITransactional+IAuditable, AuditEventType "Dashboard.PermanentlyDeleted". Handler deps IDashboardRepository+IRtsRepository+IPermissionService+ICurrentUserAccessor. Flow: GetDeletedByIdAsync->NotFound; !IsDeleted->DomainException; non-superadmin->HasDashboardAccessAsync(pgId,tenantId,id,4)->Forbidden, superadmin bypass; idempotent RTS sweep (AgentGrid GridId + QueueGrid ExtractQueueGridId, mirrors DeleteDashboardCommand); dashboards.Remove(dashboard) (DB ON DELETE CASCADE widgets+permissions); 1 tx via ITransactional. NO repo methods added, NO migration, NO report code. ✓
- Tests: 6 [Fact] — RemovesCalled (cascade), NotSoftDeleted->Domain (guard), NoDeletePermission->Forbidden, Superadmin bypass, NotFound, WidgetWithGridId->RTS sweep. ✓
- working-tree integrity OK (both files hash==HEAD, NUL=0; NO PD-007 this run). build0+unit GREEN per CC (committed; I can't run dotnet from Cowork).
- ⚠ MINOR (non-blocking, flagged): GetDeletedByIdAsync does NOT eager-load .Widgets, so the RTS safety-net loops over an empty collection for Trash items -> effectively INERT. HARMLESS: RTS rows are already cleaned at soft-delete (DeleteDashboardCommand), and loading widgets for a soft-deleted dashboard would need a new repo method (out of scope: "DO NOT add repo methods"). Primary path (physical delete + DB cascade) unaffected. Test #6 stubs a widget to assert the sweep code-path itself.
- status: code+tests done, object-store VERIFIED (cad6868). NO push. SIGNATURE published below for shell 01c.

> consumed 2026-06-25T11:30:00Z by coordinator-0624 — PurgeDashboardCommand cad6868 object-store VERIFIED (PurgeDashboardCommand.cs +test; NO migration; IsDeleted-guard + Delete4/Superadmin + Remove(dashboard) DB-cascade + 1 tx; audit Dashboard.PermanentlyDeleted). Signature published → shell dashboards-Trash icon. MINOR RTS-inert ACCEPTED as harmless (RTS cleaned at soft-delete; eager-load widgets = out-of-scope, no follow-up). HARD-DEL-01b DONE.


## 2026-06-25T16:44:32Z | binding: backend <-> CC | directive: tools/cc_prompt_backend_r3_getqueues_superadmin_fallback.md | status: done (reconciled from object-store — CC skipped the binding)
### DIRECTIVE: R3 Superadmin tenant fallback — siblings-included (GetSites/GetSupergroups/GetQueues/GetAgentGroups). Claim: ConfigurationQueries.cs + test.
### RESULT (reconciled by backend-0620 via object-store, L-SC-28):
- commit 1e3efce (v3) "fix(reports): GetQueues/Sites/Supergroups/AgentGroups Superadmin tenant fallback". diffstat = ConfigurationQueries.cs 8± (4 lines) + ConfigurationQueriesSuperadminFallbackTests.cs +174 = 2 files, 178 ins / 4 del, ZERO file-deletions, only-claimed. ✓
- All 4 target handlers collapsed to uniform `var tenantId = q.TenantId ?? user.TenantId!.Value;` @ :20 GetSites, :114 GetSupergroups, :159 GetQueues, :174 GetAgentGroups. Non-Superadmin path byte-identical (was already that expr) → ZERO dashboard-config regression. Superadmin no-arg now resolves current tenant; explicit q.TenantId cross-tenant still honoured. ✓
- CORRECTLY UNTOUCHED: :36 GetBusinessUnits (already `q.TenantId.HasValue?...:user.TenantId`, fine); :236/:252 GetBusinessUnitsUsingSite/Supergroup (`Superadmin ? null : user.TenantId` — intentional all-tenant lookup semantics, out of scope). No scope creep. ✓
- Tests: ConfigurationQueriesSuperadminFallbackTests.cs — per-handler Superadmin-no-arg→current + Superadmin-explicit→that-tenant for all 4 + GetQueues non-Superadmin regression. ✓
- ⚠ MINOR claim-name deviation (benign): CC named the test `ConfigurationQueriesSuperadminFallbackTests.cs` (one combined file for all 4) instead of the literal claimed `GetQueuesQueryHandlerTests.cs`. Same dir (tests/Unit/Queries), single test file, more apt for 4 handlers, zero other files touched — not a narrow-add violation.
- PD-007: ConfigurationQueries.cs WT NUL-corrupted post-commit (172 NUL) — RESTORED from HEAD; WT==HEAD 449524f, NUL=0. Test file clean.
- build0+unit GREEN per CC (committed; I can't run dotnet from Cowork). status: code+tests done, object-store VERIFIED (1e3efce). NO push.

> consumed 2026-06-25T17:05:00Z by coordinator-0624 — R3 1e3efce object-store-VERIFIED (backend report) + LIVE-CONFIRMED (shell re-visual: Queue picker populates 3 queues). All 4 handlers collapsed to `q.TenantId ?? user.TenantId!.Value` (:20/:114/:159/:174); non-Superadmin byte-identical=zero dashboard regress; :36/:236/:252 correctly untouched; tests per-handler; PD-007 restored. Minor test-file naming (combined, benign). PASS. R3 DONE → Scope picker (queues + agent-scope) unblocked.

## BINDING 2026-06-25T20:45:44Z | spec: backend | directive: tools/cc_prompt_backend_seeder_gate.md | status: open
### DIRECTIVE: prod-mirror rebuild-safety seeder gate — Seed:SampleData flag (default false) + data-presence belt (SampleSeedGate) gating SeedSampleCcEntitiesAsync + Dev-RTS seeds; SITE001 point-probe hardened. System seeds ungated. Claim: DatabaseInitializer.cs + SampleSeedGate.cs + SampleSeedGateTests.cs. gate: build 0 + unit GREEN. commit-prefix fix:.
### RESULT: commit f794b39 . files SampleSeedGate.cs(new 29L) + DatabaseInitializer.cs(+16 lines: flag read + 2 gates + SITE001 harden) + SampleSeedGateTests.cs(new 91L, 6 tests) . build 0 errors . unit 260/261 GREEN (6/6 new; 1 pre-existing ReportScreenCrudTests.Restore failure unrelated) . only-claimed/zero-deletion . status done . blockers none . verified: object-store

System seeds (Roles, PlatformTenant, Superadmin, WidgetCatalog, RtsGridMetrics, HistoryMetrics, AgentStateDefinitions) UNGATED.
Sample+Dev-RTS seeds now gated by: Seed:SampleData flag (default FALSE) AND no NGC data-presence for tenant.
RUNTIME N-rebuild acceptance -> QA seal pending.

```
dotnet build CcDashboard.sln: Build succeeded. 0 Error(s)
dotnet test --filter SampleSeedGateTests: Passed! 6/6 GREEN
```
> consumed 2026-06-25T20:52:11Z by coordinator
## BINDING 2026-06-26T04:08Z | spec: backend | directive: tools/cc_prompt_backend_arch02_tenant_switch.md | status: done (RECONCILED from object-store by backend-0626 — CC binding write dropped, L-SC-04/L-SC-28)
### DIRECTIVE: ARCH-02 server contract — active_tenant_id claim (default home) + SwitchTenantCommand (Superadmin-only authz, validate target Active, Tenant.Switched audit) + publish contract for shell. Claim: CustomClaimsPrincipalFactory.cs + SwitchTenantCommand.cs + SwitchTenantCommandTests.cs. feat:.
### RESULT: commit 1f4d6dc (v3) "feat(auth): ARCH-02 server contract..." . git show --stat = 3 files, +264, ZERO file-deletions, NO src/CcDashboard.Web/** touched . object-store VERIFIED by backend-0626 .
- CustomClaimsPrincipalFactory.cs: +1 line `active_tenant_id` claim (= user.TenantId default). Non-Superadmin active_tenant_id==tenant_id => byte-identical behaviour. ✓
- SwitchTenantCommand.cs (73L): record(TargetTenantId)->Result(TenantId,Slug,Name); validator NotEmpty; handler — Role!="Superadmin" => Authorization.Failure audit(subtype TenantSwitchForbidden, attemptedTarget) + ForbiddenException (C1 server-side: Role from trusted ICurrentUserAccessor claim); ARCH-05 GetByIdAsync target -> NotFound if null -> DomainException if Status!=Active (Suspended/Deleted not switchable); Tenant.Switched audit {from=tenantContext.TenantId,to=target}; returns target. NO cookie/Web code (correct layering). ✓
- SwitchTenantCommandTests.cs (190L, 5 cases per prompt). ✓
- ⚠ PD-007: CustomClaimsPrincipalFactory.cs WT truncated post-commit (24/30 lines, mid-line `if (user.PermissionGroupId.`, 0 NUL) — RESTORED from HEAD; WT==HEAD c2737004, proper close, active_tenant_id intact. Other 2 files OK.
- build/unit: per-CC report LOST with the dropped binding; source compiles against existing interfaces; commit landed clean. Joint-land build+test (with shell Web half) to confirm 5/5 SwitchTenantCommandTests GREEN.
- status: done . verified: object-store (1f4d6dc) . NO push.

PUBLISHED CONTRACT FOR SHELL (build the Web half to this):
- CLAIM `active_tenant_id` (Guid string) on every principal; default = home tenant_id.
- RESOLUTION RULE (CurrentUserAccessor + TenantCircuitHandler + TenantResolutionMiddleware): effective ITenantContext.TenantId / CurrentUserAccessor.TenantId for a **Superadmin** = active_tenant_id claim; all other roles unchanged (tenant_id/subdomain). [C1 MAKE-OR-BREAK] apply override ONLY when Role=="Superadmin" (Role from the trusted ClaimTypes.Role, NOT the forgeable active_tenant_id); a forged active_tenant_id on a non-Superadmin principal MUST be ignored. For Superadmin, active_tenant_id overrides subdomain too.
- SWITCH ENDPOINT (SSR/HTTP — cookies cannot be set from an interactive circuit): POST /auth/switch-tenant {targetTenantId}, [Authorize]+Superadmin. Flow: call SwitchTenantCommand(targetTenantId) -> on success re-issue Identity cookie: build principal via factory then REPLACE active_tenant_id claim with targetTenantId -> HttpContext.SignInAsync(IdentityConstants.ApplicationScheme, principal) -> redirect forceLoad so a fresh circuit reads the new active tenant. "Exit impersonation" = switch back to home tenant_id.
- AUDIT: backend writes Tenant.Switched (from/to) inside the command; endpoint need not duplicate.
- UI: Superadmin-only searchable tenant switcher in TopBar invoking the endpoint.
- RISKS for security post-commit re-review: C1 no-escalation (make-or-break); AUTH-WEB-02 SecurityStamp on cookie reissue; GQF-for-Superadmin (verify Users/PG/Tenants admin screens use IgnoreQueryFilters+Where, §29.2).
 filters to X; admin screens using IgnoreQueryFilters + explicit Where should be unaffected), AUTH-WEB-02 re-auth (shell endpoint must keep SecurityStamp validation), no-escalation (resolution override is Superadmin-gated).

dotnet build src/CcDashboard.Application + src/CcDashboard.Infrastructure: 0 errors
Test project: pre-existing broken tests in ReportWidgetConfigValidatorTests/ReportWidgetScopeServiceTests (unrelated); my SwitchTenantCommandTests.cs compiles clean (no errors grep)

> consumed 2026-06-26T11:45:00Z by backend

## BINDING 2026-07-10T13:41Z | spec: backend | directive: tools/cc_prompt_rtm_legacy_port_usermanager.md | status: done (RECONCILED from object-store by backend-0626 — CC binding write not in cc/ tail, L-SC-04)
### DIRECTIVE: PORT-2026-07-10-A — RTM UserManager.cs legacy→v3 port. 5 edits (st→st1; TotalStatusGroupPercent /0-NaN guard keep fmt2; 3A-D wait-for-call machine, Hebrew literals); DELETE NOTHING; preserve calc-quarantine/getLocalDateTime/fmt1/fmt2/ForceRefreshMetrics. v3, fix(rtm):, NO push.
### RESULT: commit 7ae4507 (v3, HEAD) "fix(rtm): UserManager legacy port — st→st1 + TotalStatusGroupPercent /0 guard + restore wait-for-call status machine" (journal: amended +EDIT2,3A) . object-store VERIFIED by backend-0626:
- git show --stat = 1 file RTM/RTM/UserManager.cs, +81/-15, SINGLE-FILE scope respected (no other file). ✓
- EDIT1: `st1 = TimeInStatus` present (1). ✓
- EDIT2: `case "TotalStatusGroupPercent"` @1278 + /0-NaN guard `if (!double.IsNaN(dCalc2) && !double.IsInfinity(dCalc2))` @1294; fmt2 KEPT (2). ✓
- EDIT3A-D: wait-for-call Hebrew literals בשיחה/ממתין לשיחה present (6), UTF-8 intact. ✓
- PRESERVE (DELETE NOTHING): getLocalDateTime(1), fmt1(2), fmt2(2), ForceRefreshMetrics(3) all present; -15 = replaced OLD lines in the 5 edits, NOT feature removal. ✓
- HEAD content: 1907 lines, proper close (}}), NO BOM (starts 'usi'), 0 CRLF (LF). ✓
- ⚠ PD-007: WT copy of UserManager.cs was TRUNCATED post-commit (tail `get { return _` mid-line, WT hash != HEAD) — RESTORED from HEAD; WT==HEAD c753b076 now. Commit itself was always intact.
- build: DoD = dotnet build RTM 0 err; I CANNOT run dotnet from Cowork — build-0 is per-CC report (not in the dropped binding). RECOMMEND a build-count confirm (Soma /ops/build or native) before this rides a push barrier.
- status: done . verified: object-store (7ae4507) . NO push.

## BINDING 2026-07-11 | spec: backend | directive: tools/cc_prompt_rtm_configurable_pipename.md | status: done (RECONCILED from object-store by backend-0626 — CC binding write dropped, L-SC-04)
### DIRECTIVE: Part B — RTM Service configurable NamedPipe name (AppConfig.PipeName default "rtmpipe") for parallel-run vs legacy. 3 files, v3, fix(rtm):, NO push. backward-compat.
### RESULT: commit 116416c (v3, HEAD) "fix(rtm): configurable NamedPipe name (AppConfig.PipeName, default rtmpipe) for parallel-run vs legacy" . object-store VERIFIED by backend-0626:
- git show --stat = 3 files, +10/-4, ALL under RTM/, ZERO file-deletions. ✓
- AppConfig.cs:29 `public static string PipeName { get; private set; }` + :63 `PipeName = string.IsNullOrWhiteSpace(configuration["RTM:PipeName"]) ? "rtmpipe" : configuration["RTM:PipeName"];` + :64 log. BACKWARD-COMPAT (missing/empty → "rtmpipe" = current). ✓
- RTMAdapter.cs:155 `server = new NamedPipeServer(AppConfig.PipeName);` (was `"rtmpipe"`). ✓
- appsettings.json:19 `"PipeName": "rtmpipe"`. ✓
- no-BOM, LF-only on AppConfig.cs + appsettings.json. ✓
- ⚠ PD-007: WT copies of AppConfig.cs + RTMAdapter.cs truncated post-commit — RESTORED from HEAD; all 3 WT==HEAD now. Commit intact.
- build: DoD = dotnet build RTM 0 err WITH counts; I CANNOT run dotnet from Cowork; no CC build report (dropped binding). NEED build-count confirm (native CC / Soma) — this is the build gate before 234 deploy + push.
- status: done . verified: object-store (116416c) . NO push.

## BINDING 2026-07-13 | spec: backend | directive: tools/cc_prompt_migrate_only.md | status: done (RECONCILED from object-store by backend-0626 — binding write dropped, L-SC-04)
### DIRECTIVE: RED DEFECT B — Web.exe migrate = migrate-only+exit. MigrateOnlyAsync (App+Audit) + Program.cs migrate-arg branch return before seed/app.Run. Claim: IDatabaseInitializer.cs + DatabaseInitializer.cs + Program.cs. fix(deploy):.
### RESULT: commit 72882f0 (v3, HEAD) "fix(deploy): Web.exe migrate = migrate-only + exit (no seed/hosted services) - fresh-install ordering" . object-store VERIFIED by backend-0626:
- git show --stat = 4 files, +33/-3, ZERO file-deletions.
- IDatabaseInitializer.cs (+7): `Task MigrateOnlyAsync(CancellationToken ct = default)` added. ✓
- DatabaseInitializer.cs (+15/-...): MigrateOnlyAsync @36 (App+Audit MigrateAsync only); InitializeAsync @48 calls `await MigrateOnlyAsync(ct)` then BE-migrate(dev/test) + full seed body INTACT (SeedRoles @57 ... SeedSampleCcEntities @75 seeder-gate preserved). DRY, -3 = the 2 inline MigrateAsync lines moved into MigrateOnlyAsync (not feature deletion). ✓
- Program.cs (+13): migrate-arg branch @147 `if (args.Any(a => string.Equals(a,"migrate",OrdinalIgnoreCase)))` → MigrateOnlyAsync @151 → Log @152 → `return;` @153 — BEFORE InitializeAsync @160 + app.Run @188. Hosted services never start; exits promptly. ✓
- ⚠ 4th FILE (benign/NECESSARY, flagged not hidden): tests/CcDashboard.Tests.Security/Fixtures/WebFixture.cs (+1) = `NoOpDatabaseInitializer` test double now implements `MigrateOnlyAsync(...) => Task.CompletedTask;` (@641). MANDATORY interface-ripple compile-fix (adding a method to IDatabaseInitializer breaks the NoOp). Not scope creep; keeps Tests.Security building. Outside the literal 3-file claim but zero-risk + required.
- ⚠ PD-007: all 3 claimed WT files truncated post-commit — RESTORED from HEAD (all ==HEAD). WebFixture not restored (+1 line, benign). Commit intact.
- build/unit: per-CC report LOST (dropped binding); I can't run dotnet from Cowork. The WebFixture compile-fix is EVIDENCE CC iterated to a green build (it added the NoOp method because the build required it). Automated counts unconfirmed by me → recommend a build/unit-count confirm.
- DEFINITIVE acceptance = fresh-DB migrate-only runtime (only App+Audit tables, no seed/Archiver/HistAgg logs, exits, no 42P01) → devops/QA seal during 140 re-provision.
- status: done . verified: object-store (72882f0) . NO push.

## BINDING 2026-07-13 | spec: backend | directive: tools/cc_prompt_fix_ngc_queues_live_populate.md | status: done (RECONCILED from object-store by backend-0626 — binding write dropped, L-SC-04)
### DIRECTIVE: RED — NGC_Queues empty on live path. Add BusinessUnitData.getOrCreateQueue(id,id) in getOrAddWGManager new-WG branch (Engine.cs ~1890), symmetric with classification write / LoadData :477. Claim: RTM/RTM/Engine.cs. gate: build 0. rtm:.
### RESULT: commit cf18c8b (v3, HEAD) "rtm: populate NGC_Queues on live workgroup-add (getOrCreateQueue in getOrAddWGManager) - BU queue picker" . object-store VERIFIED by backend-0626:
- git show --stat = 1 file RTM/RTM/Engine.cs, +2 insertions, ZERO deletions. Pure insertion (comment + call). ✓
- Insertion @~1895 INSIDE `if (createBusinessUnitQueueClassificationMapping(businessUnitId, id, "ALL", "admin"))` body, right after `union.Queues.Add(id); union.addWorkgroup(id,_applicList);` → `// Persist queue to NGC_Queues (symmetric with LoadData :477) — idempotent` + `BusinessUnitData.getOrCreateQueue(id, id);`. EXACT location per prompt. ✓
- getOrCreateQueue now 2 call-sites: :477 (LoadData, unchanged) + :1895 (NEW live path). id,id symmetric with :477 getOrCreateQueue(QueueId,QueueId). Idempotent (ON CONFLICT DO NOTHING). No other line touched. ✓
- ⚠ PD-007: Engine.cs WT truncated post-commit — RESTORED from HEAD (WT==HEAD). Commit intact.
- build: RTM compile gate — I can't run dotnet from Cowork; the insertion calls an existing method (BusinessUnitData.getOrCreateQueue(string,string)) so it compiles; recommend a build-0 confirm (native CC/Soma).
- DEFINITIVE acceptance = runtime NGC_Queues>0 on 140 after RTMService redeploy (BU picker populates) → coordinator/operator seal.
- status: done . verified: object-store (cf18c8b) . NO push.

## BINDING 2026-07-13 | spec: backend | directive: tools/cc_prompt_platform_tenant_slug.md | status: done (RECONCILED from object-store by backend-0626 — binding dropped, L-SC-04)
### DIRECTIVE: G — parametrize platform-tenant Slug (Seed:PlatformTenantSlug default platform); idempotency by STABLE Name=="Platform" (COND2 deterministic OrderBy CreatedAt + >1 guard); COND3 full method byte-preserved. Claim: DatabaseInitializer.cs. fix(web):.
### RESULT: commit a261840 (v3, HEAD) "fix(web): parametrize platform-tenant slug (Seed:PlatformTenantSlug), idempotency by stable Name==Platform" . object-store VERIFIED by backend-0626:
- git show --stat = 1 file DatabaseInitializer.cs, +25/-4, ZERO file-deletions, only-claimed. ✓
- @119 `slug = config["Seed:PlatformTenantSlug"]` (default "platform" via IsNullOrWhiteSpace). ✓
- COND2 @124-132: `.Where(Name=="Platform").OrderBy(t=>t.CreatedAt).ToListAsync()` + `if (Count>1) LogError(...naming ids, "Using the OLDEST")` + `FirstOrDefault()` → deterministic (oldest=real/original), self-defending. ✓
- Create @139-140: `Slug = slug`, `Name = "Platform"`. Re-run sync @152 `tenant.Slug = slug`. ✓
- COND3: full TenantSettings palette (Background+Font colour arrays) + SaveChanges + `return tenant;` @198 preserved byte-identical (method grew to ~200 from the COND2 additions). ✓
- ⚠ PD-007: DatabaseInitializer.cs WT truncated post-commit — RESTORED from HEAD (WT==HEAD). Commit intact.
- build/unit: can't run from Cowork; coordinator confirms build0+unit0 via Soma §47.
- ⚠ DEPLOY reminder: 140 redeploy MUST set Seed:PlatformTenantSlug=nayax else slug re-syncs to "platform".
- status: done . verified: object-store (a261840) . NO push.

## BINDING 2026-07-13 | spec: backend | directive: tools/cc_prompt_pertenant_username_index.md | status: done (RECONCILED from object-store by backend-0626 — binding dropped, L-SC-04)
### DIRECTIVE: H — per-tenant username unique index (dba-ruled: keep UserNameIndex non-unique; composite (NormalizedUserName,TenantId) unique WHERE IsActive; no §38a). Claim: AppDbContext.cs + Migrations/App. fix(db):.
### RESULT: commit f486e4c (v3, HEAD) "fix(db): per-tenant username unique index ... §6.2" . object-store VERIFIED by backend-0626 — ALL 3 dba rulings applied faithfully:
- git show --stat = 4 files (+2044/-2): AppDbContext.cs(+3), 20260713041952_PerTenantUserNameIndex.cs(+54), .Designer.cs(+1982), AppDbContextModelSnapshot.cs(7). Only-claimed; zero unrelated. ✓
- AppDbContext @88 `e.HasIndex(x=>x.NormalizedUserName).HasDatabaseName("UserNameIndex").IsUnique(false)` = KEEP non-unique (ruling 1). @89 `e.HasIndex(x=>new{NormalizedUserName,TenantId}).IsUnique().HasFilter("\"IsActive\" = true")` = composite unique WHERE IsActive (ruling 2, mirrors email @86). ✓
- Migration Up(): DropIndex "UserNameIndex" → CreateIndex "IX_users_NormalizedUserName_TenantId" (NormalizedUserName,TenantId) unique:true filter:IsActive → CreateIndex "UserNameIndex" (NormalizedUserName) NON-unique. Down() reverses (drop composite + recreate UserNameIndex unique). ✓
- NO db_patch_history / §38a line in the migration (grep=0, ruling 3). ✓
- ⚠ PRE-RUN BLOCKER I CAUGHT+FIXED: AppDbContextModelSnapshot.cs WT was PD-007-truncated (1913 vs 1976) BEFORE H ran → would have mis-generated the EF diff; restored from HEAD, then H generated cleanly on re-run.
- ⚠ PD-007 post-commit: AppDbContext.cs + snapshot WT truncated again — RESTORED from HEAD (all 4 ==HEAD). Commit intact.
- build/unit: rides the devops Shell rebuild (build0 + unit counts), with G a261840 — I can't run dotnet from Cowork.
- 140 apply = coordinator's redeploy precondition (C1 active-dup probe).
- status: done . verified: object-store (f486e4c) . NO push.

## BINDING 2026-07-14 | spec: backend | directive: tools/cc_prompt_defect_k_flush_bedb.md | status: done (RECONCILED from object-store by backend-0626 — binding dropped, L-SC-04)
### DIRECTIVE: Defect K — NGC config handlers flush beDb. repo.SaveChangesAsync on Site/BU/SG interfaces+impls + call in 6 Save/Delete handlers before apiHook/return (sequential, before UoW AppDbContext). Claim: INgcRepositories.cs + NgcRepositories.cs + ConfigurationCommands.cs + test. fix(web):.
### RESULT: commit d30e9b4 (v3, HEAD) "fix(web): NGC config handlers flush BackendEmulationDbContext ..." . object-store VERIFIED by backend-0626:
- git show --stat = 4 files, +120/-0, ZERO deletions, only-claimed. ✓
- INgcRepositories.cs +3: SaveChangesAsync on INgcSite/BusinessUnit/SupergroupRepository. NgcRepositories.cs +3: impl `=> db.SaveChangesAsync(ct)` (beDb). ✓ (3/3)
- ConfigurationCommands.cs +9: `await repo.SaveChangesAsync(ct)` in ALL 6 handlers (Site/BU/SG Save+Delete) — count=6, before apiHook/return, inside next() before UoW AppDbContext save (concurrency guard held; beDb NOT in UoW). ✓
- SaveSupergroupPersistTests.cs (+105): regression test (repo.SaveChangesAsync called on save+delete). ✓
- ⚠ PD-007: INgcRepositories.cs + NgcRepositories.cs + ConfigurationCommands.cs WT truncated post-commit — RESTORED from HEAD (all ==HEAD). Commit intact.
- build/unit: rides devops Shell rebuild (build0+unit0 via Soma §47) — can't run dotnet from Cowork.
- ACCEPTANCE (runtime): create SG/BU/Site → reload → persists = coordinator/operator persist-seal on 140 after rebuild+redeploy.
- status: done . verified: object-store (d30e9b4) . NO push.

## BINDING 2026-07-14 | spec: backend | directive: tools/cc_prompt_adapter_autoreconnect.md | status: done (RECONCILED from object-store by backend-0626 — binding dropped/L-SC-04)
### DIRECTIVE: adapter auto-reconnect — per-target supervisor loop (INFINITE, backoff cap 30s, reset 1s on connect, CT clean-stop) + NamedPipeBase disconnect hardening + §48 WIRE gate. Claim: RTMAdapter.cs + RtmTarget.cs + NamedPipeBase.cs. adapters branch, feat:.
### RESULT: commit 6ebd39f (adapters, HEAD) "feat(adapter): auto-reconnect per-target supervisor (infinite retry, 30s backoff cap) + harden pipe-disconnect detection" . object-store VERIFIED by backend-0626:
- git show --stat = 3 files, ONLY RTMAdapter.cs + RtmTarget.cs + NamedPipeBase.cs. NO serializer/DTO/framing file touched (DictionarySerializer/StreamString/Agent UNTOUCHED) → §48 wire FORMAT unchanged. ✓
- SuperviseAsync (@70): `while(!ct.IsCancellationRequested){ try ConnectAndReadAsync(target,ct) catch(OperationCanceled)break/catch(Exception)log; if(ct)break; Delay(target.Backoff,ct); Backoff=Min(*2,30); }` → INFINITE, cap 30s, CT clean-stop. ConnectAndReadAsync(@88): new NamedPipeClient → wire ConnectedToServer→Client_ConnectedToServer(snapshot) + Disconnected(log) → Connect() blocks until break → returns → loop reconnects. ✓
- Client_ConnectedToServer(@101): `target.Backoff = FromSeconds(1)` (reset on every successful connect) + ServerConnectEvent (per-target snapshot re-sync, unchanged). ✓
- connect(@50-58): _cts?.Cancel(); new CTS; ONE `SuperviseAsync(t,_cts.Token)` per target. Stop(@66): _cts?.Cancel() (no runaway). Multi-target: only dropped target reconnects; legacy unaffected. ✓
- RtmTarget.cs +4: Backoff field. NamedPipeBase.cs @53: `catch (Exception ex) when (ex is InvalidOperationException or IOException or ObjectDisposedException) OnDisconnected()` — any pipe-break. No ReadString/framing change. ✓
- ⚠ Large diff (RTMAdapter 1084 changed/-596) = EOL churn (adapters branch CRLF, known cosmetic — .gitattributes normalization pending) + the real ~46-line supervisor; file 556 ln, proper close, all methods intact (SendToAll/PostToAll/snapshot present). Not a real loss.
- build 0 + WIRE 14/14: ride the adapter rebuild (Soma/native) — can't run dotnet from Cowork; no format change so contract holds.
- ACCEPTANCE (runtime): restart RTM → adapter reconnects w/o restart + re-registers (per-target snapshot); legacy unaffected = coordinator/operator after adapter rebuild+redeploy 140.
- status: done . verified: object-store (6ebd39f) . NO push.

## BINDING 2026-07-14 | spec: backend | directive: tools/cc_prompt_rtm_server_reaccept.md + tools/cc_prompt_adapter_connect_timeout.md | status: done (RECONCILED object-store by backend-0626, L-SC-04)
### RESULT — RECONNECT FIX (both halves) object-store VERIFIED:
- SERVER commit 870a033 (v3) "rtm: NamedPipeServer re-accept loop": RTM/RTM.Tools/NamedPipeServer.cs +47/-8, ONLY that file, zero deletions. Re-accept: BeginWaitForConnection re-armed @81 in a finally after StartReading; ObjectDisposedException guards @63/@83 (clean stop on Dispose); Disconnect @96. CC verified NamedPipeServerStream can't be reused after Disconnect → used FRESH-STREAM fallback (stated @78). No framing/param change. PD-007 WT restored ==v3. ✓
- CLIENT commit fc51ae0 (adapters) "fix(adapter): bounded ConnectAsync timeout": NamedPipeClient.cs (ConnectTimeoutMs=5000 @13; Connect(CancellationToken ct=default) @31; ConnectAsync(ConnectTimeoutMs, ct) @39; TimeoutException/OperationCanceled catches) + RTMAdapter.cs (passes ct to Connect) + IPCConnection.cs. 
  ⚠ 3rd file IPCConnection.cs = NECESSARY interface ripple (IClient.Connect() -> Connect(CancellationToken ct=default) @26; NamedPipeClient implements IClient). Benign/required compile-fix, not scope creep; flagged not hidden.
  §48: NO wire-format file touched (DictionarySerializer/StreamString/Agent UNTOUCHED — confirmed absent from stat) → format intact; WIRE 14/14 rides the adapter rebuild (can't run dotnet from Cowork). Large diff = adapters-branch EOL churn (CRLF) + the real change.
- build0 (server=RTMService rebuild; client=adapter rebuild) + WIRE 14/14 ride the rebuilds. LIVE gate = restart OUR RTMService only → adapter reconnects rtmpipe_v3, legacy untouched.
- status: done . verified: object-store (870a033 v3, fc51ae0 adapters) . NO push.

## BINDING 2026-07-15 | spec: backend | directive: tools/cc_prompt_rtm_diaglog.md | status: done (RECONCILED object-store by backend-0626, L-SC-04)
### RESULT — DIAG LOG-ONLY object-store VERIFIED:
- commit d8c239f (v3) 'chore(rtm): diag log-only — membership arrival + refreshUnions MISS token-diff': RTM/RTM/{RTMAdapter.cs +4/-1, UserManager.cs +6, Engine.cs +1} = +10/-1, 3 files, claim-exact.
- 6 discriminator log lines present in committed tree (SERVER<=method, RECV userWorkgroupActivation, RECV setWorkgroups count=, _workgroups[] x2, refreshUnions MISS, LoadData union=). Control-flow untouched (only { } braces around the else-if MISS log; no new if/return/for logic). Log-only confirmed.
- NOT pushed: origin/v3=116416c (pre-diag); d8c239f local on v3. §37 OK. build0/grep: ride devops rebuild (can't dotnet from Cowork).
- status: done . verified: object-store (d8c239f v3) . NO push.

## BINDING 2026-07-15 | spec: backend | directive: tools/cc_prompt_rtm_phase1_pipe.md | status: done (RECONCILED object-store by backend-0626, L-SC-04)
### RESULT — PHASE 1 pipe hardening object-store VERIFIED:
- commit d7144a6 (v3) 'fix(rtm): phase-1 pipe hardening': RTM/RTM.Tools/{NamedPipeBase.cs, NamedPipeServer.cs} = 2 files, +38/-26. Claim-exact (RTM.Tools only; legacy/adapter/db/src untouched).
- NamedPipeBase.StartReading: BlockingCollection<string> worker (GetConsumingEnumerable, ordered single-consumer) + CompleteAdding + OnDisconnected in finally; NO Dispose() call inside (read loop drains off-thread, survives handler exc, completes only on real pipe break). ✓
- NamedPipeServer.WaitForConnectionCallBack: async void; captures connectedPipe=Pipe; await StartReading() to completion; disposes connectedPipe in finally; re-accept Initialize(CreatePipe()) ONLY after (fixes 870a033 _stream reassign race). ✓
- NOT pushed: origin/v3=116416c. §37 OK. build0 (BOTH RTM.Tools+RTM) + 140 functional seal RIDE the devops v3 rebuild (Cowork can't dotnet). Condition-1 caller check: StartReading signature UNCHANGED (protected async Task) → no ripple; the only behavior change (no Dispose() in StartReading) is server-owned teardown now in WaitForConnectionCallBack finally.
- status: done . verified: object-store (d7144a6 v3) . NO push. NEXT: devops build v3 RTMService (Phase1 d7144a6 + diag d8c239f) + bounce OUR RTM 140 → operator retest w/ agents → grep RECV setWorkgroups/userWorkgroupActivation + AgentGrid.

## BINDING 2026-07-15 | spec: backend | directive: tools/cc_prompt_defectA_agentgrid_default.md | status: done (object-store VERIFIED by backend-0626)
### RESULT — DEFECT A default-metrics fix:
- 6dc2b9c web: ScreenEditorPage.razor GetDefaultColumnDefs → 5 real catalog IDs (Agent=AgentLoginName, State=MonAgentState, Duration=MonAgentStateDuration, OCC%=MonAgentAvailableDurationPct, ADH%=MonAgentAverageCallDuration).
- 46a1ce7 db: db/data/03_rtsgrid.sql RTSUserGrid_Column (5 rows, set 1) → same 5 real IDs.
- Phantom IDs (AgentName/AgentState/AgentStateDuration/AgentOccupancy/AgentAdherence) FULLY GONE from both (the lone grep 'hit' = substring 'AgentStateDuration' inside the correct 'MonAgentStateDuration' — false positive, verified). All 5 real IDs confirmed present in 02_metrics.sql. NO new metrics.
- NOT pushed (23 commits on v3 ahead of origin). Two commits web:/db: per §39.3. status: done. verified: object-store (6dc2b9c, 46a1ce7).

## BINDING 2026-07-16 | spec: backend | directive: tools/cc_prompt_grid_ondemand_register.md | status: done (object-store VERIFIED by backend-0626)
### RESULT — on-demand grid+cell registration:
- 961a979 fix(rtm): RTM/RTM/Engine.cs only (+80/-3). RegisterGridOnDemand(int gridId) @2040 mirrors the LoadData DataCells registration scoped to gridId, union gate `if(!UnionList.ContainsKey(unionId)) continue` @2053. Note-1 FOLDED: `_gridList.GetOrAdd(gridId, id=>{var g=new Grid(id); g.GridEvent+=Grid_GridEvent; return g;})` @2059-2062 (race-safe single stored instance, event wired once). AddGridConnection @2141 calls RegisterGridOnDemand before rejecting, re-checks TryGetValue @2142, rejects only if still absent @2144, then grid.InUse=true @2149. LoadData loop untouched.
- ⚠ Note-3: functional seal MUST use a queue whose BU/union EXISTED at RTM startup (union-guard). NOT pushed (v3 +2 vs origin). build0/test + 140 functional seal ride devops rebuild + operator.
- status: done. verified: object-store (961a979).

## BINDING 2026-07-16 | spec: backend | directive: tools/cc_prompt_interactions_updatetime_guard.md | status: done (object-store VERIFIED by backend-0626)
### RESULT — interaction load TZ-guard:
- 0b07651 db: db/functions/02_rtsdata_functions.sql (+6/-1). RTSData_GetInteractions(p_on_date,p_tenant_id) WHERE replaced: now `WHERE "TenantId"=p_tenant_id AND (("UpdateTime" AT TIME ZONE (COALESCE(NULLIF("TimeZone",''),'+00:00')::interval))::date = (now() AT TIME ZONE (same offset))::date)`. Old `WHERE "OnDate"=p_on_date` REMOVED from the interaction fn (0 hits). Signature p_on_date kept (unused) → C# untouched. ORDER BY "Segment","UpdateTime" DESC unchanged. §33.8 FUNCTION-kind preserved (CREATE OR REPLACE FUNCTION).
- NOT pushed (v3 +3 vs origin). status: done. verified: object-store (0b07651).
- FOLLOW-UP (flagged, separate): RTSData_getUsersStatuses/RTSData_GetUserStatuses still uses WHERE OnDate=p_on_date (02_rtsdata_functions.sql:405) → same TZ-guard needed for agent-state accumulation.

## BINDING 2026-07-16 | spec: backend | directive: tools/cc_prompt_tzguard_signfix.md | status: done (object-store VERIFIED by backend-0626)
### RESULT — TZ sign-bug fix:
- e58cac8 db: db/functions/02_rtsdata_functions.sql. RTSData_GetInteractions WHERE now uses CASE: offset-format (^[+-][0-9]{2}:[0-9]{2}$) → `AT TIME ZONE (("TimeZone")::interval)` (sign-correct, +02→UTC+2, -04→UTC-4); else (Israel/UTC/name) → bare `AT TIME ZONE COALESCE(NULLIF("TimeZone",''),'UTC')` (IANA-safe); applied to BOTH UpdateTime and now(). Signature/RETURNS/ORDER BY/§33.8-kind unchanged.
- Chain: 0b07651 (::interval, died on 'Israel') → 0329bf0 (bare, inverted offsets) → e58cac8 (CASE, correct). Final state correct.
- NOT pushed (v3 +5 vs origin). status: done. verified: object-store (e58cac8). CONDITION: per-zone 140 PROBE before operator seal (probe query issued).

## BINDING 2026-07-16 | spec: backend | directive: tools/cc_prompt_interactions_serverlocal_date.md | status: done (object-store VERIFIED by backend-0626)
### RESULT — server-local date guard:
- 01dbc2c db: db/functions/02_rtsdata_functions.sql. RTSData_GetInteractions arity-2 WHERE → `WHERE "TenantId"=p_tenant_id AND ("UpdateTime" AT TIME ZONE current_setting('TimeZone'))::date = (now() AT TIME ZONE current_setting('TimeZone'))::date`. NO per-row TimeZone col, NO CASE, NO ::interval (the interaction fn). Server-local (session TZ) = legacy OnDate=DateTime.Today rule, cross-server. Signature/RETURNS/ORDER BY/§33.8-kind unchanged; p_on_date unused → C# untouched.
- Supersedes e58cac8 (per-row-TZ CASE) — that push-blocker cleared. Chain: 0b07651→0329bf0→e58cac8→01dbc2c (final).
- NOT pushed (v3 +6). status: done. verified: object-store (01dbc2c). Operator waived the current_setting-probe/row-count/legacy-predicate ceremony (1524) — dba apply + RTM reload + operator eyeballs US grid.


## BINDING 2026-07-16 | spec: backend | directive: tools/cc_prompt_maxwait_diag_log.md | status: done (RECONCILED from object store — RESULT write dropped, L-SC-28)
### RESULT — Max-Wait LOG-ONLY diagnostic:
- ad73870 rtm: RTM/RTM/Engine.cs (+7) + RTM/RTM/Union.cs (+3), 10 insertions, log-only.
- Tags verified in HEAD: Engine.cs MAXWAIT-STREAM@921 (base=cell.Value2, emitted), MAXWAIT-REFRESH-ENTER@1388 (grid), MAXWAIT-REFRESH@1414 (servedBase=cellValue.Value.Value2, emitted); Union.cs MAXWAIT-RECOMPUTE@385 (UnionId, metric.ID, QueueInteractions.Bag.Count, result). C1 grep-count == 3/1 SATISFIED. All guarded try/catch, zero flow change.
- NOT pushed (v3 ahead of origin). status: done. verified: object-store (ad73870). Binding RESULT reconciled by spec (CC postamble write was dropped; git = truth).
- PENDING: build0 not independently confirmable by spec (no RESULT block); code compiles logically (UnionId resolved, $-interp, guarded). 140 deploy + F5 capture = next.


## BINDING 2026-07-21 | spec: backend | directive: tools/cc_prompt_revert_maxwait_diag.md | status: done (RECONCILED from object store — RESULT write dropped, L-SC-28)
### RESULT — revert MAXWAIT diag:
- cd0e39a rtm: revert MAXWAIT diag log-only (ad73870) — 140 capture complete. Clean inverse: RTM/RTM/Engine.cs (-7), RTM/RTM/Union.cs (-3).
- VERIFIED object-store: HEAD Engine.cs MAXWAIT- == 0, Union.cs MAXWAIT- == 0 (all tags removed). Touches only Engine.cs+Union.cs.
- status: done. verified: object-store (cd0e39a). Binding reconciled by spec (CC postamble dropped; git=truth).


## BINDING 2026-07-21 | spec: backend | directive: tools/cc_prompt_wfm_erlang_service.md | status: done (RECONCILED from object store — RESULT write dropped, L-SC-28)
### RESULT — WFM Phase1 ErlangCalculatorService:
- 4e21796 web: WFM Phase1 ErlangCalculatorService (pure Erlang B/C math + unit tests) [wfm]. New files only: IErlangCalculatorService.cs (Application/Interfaces), ErlangCalculatorService.cs (Infrastructure/Wfm), ErlangCalculatorServiceTests.cs (Tests.Unit/Wfm) — all present in HEAD; Program.cs DI.
- Tests verified by object-store: 18 [Fact]/[Theory]; anchors match spec §7 exactly — TrafficIntensity==8.0, ErlangB(10,8)≈0.1217(±.005), ErlangC(10,8)≈0.4092, PredictedSl≈0.6724, PredictedAsaSec≈36.83(±.5), RequiredAgents==11 & capped==false, StaffVariance(10,11)==-1 (+ ErlangB(100,8)<1e-60 + overload/edge null tests).
- build0 + `dotnet test --filter Erlang` GREEN = CC pre-commit gate (commit implies pass); NOT independently runnable by spec (no dotnet in sandbox). status: done. verified: object-store (4e21796). Binding reconciled by spec (CC postamble dropped; git=truth).


## BINDING 2026-07-21 | spec: backend | directive: tools/cc_prompt_wfm_indexes.md | status: done (RECONCILED from object store — RESULT dropped, L-SC-28)
### RESULT — WFM covering indexes:
- 83ce56b db: WFM Phase1 covering indexes [wfm]. New file db/migrations/20260721_001_wfm_indexes.sql only.
- Verified object-store: ix_rtsint_wfm_inq (TenantId,InQueueDateTime) INCLUDE Workgroup/Direction/InteractionType/CallType/IsCallbackRequest; ix_rtsint_wfm_ans (TenantId,AnsweredDateTime) INCLUDE Workgroup/Direction/InteractionType/CallType/IsAnswered/IsInQueue/TalkTime PARTIAL WHERE AnsweredDateTime IS NOT NULL; ix_rtsus_wfm (TenantId,StatusGroup) INCLUDE UserId; §38a self-record present. All CREATE INDEX IF NOT EXISTS (idempotent).
- status: done. verified: object-store (83ce56b). Binding reconciled by spec. 140 apply CONCURRENTLY = dba/operator variant (note in file).


## BINDING 2026-07-21 | spec: backend | directive: tools/cc_prompt_wfm_loop_B0.md | status: done (RECONCILED from object store — L-SC-28)
### RESULT — WFM B0 (config + snapshot + store, no loop):
- 07b48a1 web: WFM Phase1 B0 [wfm]. 8 files, +2253/-12.
- Verified object-store: IWfmSnapshotStore.cs (new), WfmSnapshotStore.cs (new, Singleton); WfmTypes.cs +WfmSnapshot/WfmInputs/WfmErlang (§4, 3 records); TenantSettings.cs +WFM §5 fields (+18); EF App migration 20260721110721_WfmTenantSettings.cs (+105) + Designer + AppDbContextModelSnapshot; store DI in InfrastructureServiceExtensions.cs (+3).
- CORRECTLY SCOPED: NO WfmRealtimeLoop, NO query service, NO window-frame (all B1). build green = CC gate.
- status: done. verified: object-store (07b48a1). Binding reconciled. v3 +2 vs origin, NOT pushed.


## BINDING 2026-07-21 | spec: backend | directive: tools/cc_prompt_wfm_hosted_loop.md (B1) | status: done (RECONCILED from object store — RESULT dropped, L-SC-28)
### RESULT — WFM B1 (WfmInputQueryService + WfmRealtimeLoop) + C1 PARITY VERIFIED:
- 515c355 web: WFM Phase1 B1 [wfm]. Files: IWfmInputQueryService.cs (+26), WfmInputQueryService.cs (+346), WfmRealtimeLoop.cs (+208), InfrastructureServiceExtensions.cs (+6, AddHostedService). build green = CC gate.
- ✅ C1 PARITY = PASS (verified object-store, byte-for-byte vs IDInteraction.getLocalDateTime:253-288): StampWallNow (WfmInputQueryService.cs:306-337) mirrors ALL 4 edges EXACTLY —
  (1) IsNullOrWhiteSpace(tz) -> return UtcNow (offset 0), no default zone [:310];
  (2) offset-form: cleaned=Trim, negative=StartsWith("-"), stripped=TrimStart('+').TrimStart('-'), TimeSpan.TryParse, Negate-if-negative (the specific strip-sign quirk, "03:00" no-sign->positive) [:318-324];
  (3) else FindSystemTimeZoneById(tz).GetUtcOffset(UtcNow), DST-aware [:329-330];
  (4) catch {} -> offset 0 silent UTC (malformed/unknown) [:335-337].
  Uses wallNow = UtcNow + offset (localTime.Add) — NOT ConvertTimeFromUtc -> the edge-1/4 throw-divergence risk is AVOIDED. NO FIX NEEDED.
- DBA-FRAME pins honored (object-store): offset from own TimeZone col via cached wg->TZ map (:11, TzCacheTtl :267/296); app-side winLo/winHi (:52-54); `-- DBA-FRAME: INTERIM` tag (:28); per-TZ one-pass.
- ⚠ C2 STANDING FUNCTIONAL GATE: CC gate = LANDING-only (build0 + pins, zero prod impact until consumed). Live λ/AHT/N-vs-reality per queue on 140 = QA/operator AFTER the store is inspectable (WFM-3c widgets / debug read). WFM numbers NOT declared correct on the CC gate.
- status: done. verified: object-store (515c355). Binding reconciled by spec. v3 +3 vs origin, NOT pushed.


## BINDING 2026-07-21 | spec: backend | directive: tools/cc_prompt_wfm_n_alias_fix.md | status: done (RECONCILED from object store — L-SC-28)
### RESULT — WFM N-42703 fix:
- 6e3c922 fix: WFM N-query 42703 — alias scalar AS "Value" [wfm]. ONE line, WfmInputQueryService.cs only.
- Verified object-store: :237 now `SELECT COUNT(DISTINCT us."UserId")::int AS "Value"` (was `AS N`). lambdaSql/ahtSql UNTOUCHED (2 typed SqlQueryRaw<LambdaRow>/<AhtRow> present). No other scalar<primitive> non-Value alias in the file.
- build green = CC gate. status: done. verified: object-store (6e3c922). Binding reconciled. v3 +4 vs origin, NOT pushed.


## BINDING 2026-07-21 | spec: backend | directive: tools/cc_prompt_wfm_bu_aggregate.md | status: done (RECONCILED, L-SC-28)
### RESULT — WFM per-BU aggregate:
- fb9a6a4 feat: WFM per-BU aggregate snapshot [wfm]. Files: IWfmInputQueryService.cs (+20), WfmInputQueryService.cs (+179, BU-N distinct query), WfmRealtimeLoop.cs (+216, BU aggregation).
- Verified object-store: keyed by BusinessUnitName (WfmRealtimeLoop:198-204 BuildSnapshot(bu.BusinessUnitName)->Set) => matches widget Get, NO widget change; pooled λ=Σ (:185), AHT arrival-weighted =weightedAhtSum/lambdaSum (:192), N=DISTINCT via §36a BU pool cached (:194); Erlang RE-RUN via shared BuildSnapshot (:225); collision-guard WARN (:171-173). BU-N + per-queue-N BOTH aliased `AS "Value"` (:241/:283) — N-42703 lesson applied. build green=CC gate.
- status: done. verified: object-store (fb9a6a4). Binding reconciled. v3 +5 vs origin, NOT pushed.


## BINDING 2026-07-22 | spec: backend | directive: tools/cc_prompt_wfm_bu_key_id.md | status: done (RECONCILED, L-SC-28)
### RESULT — WFM per-BU key -> BusinessUnitId:
- d1982de fix: WFM per-BU snapshot keyed by BusinessUnitId [wfm]. WfmRealtimeLoop.cs only.
- Verified object-store: :171 `var buKey = bu.BusinessUnitId.ToString();`; :175 collision-check `queueKeys.Contains(buKey)` (id-based, won't fire); :203 `BuildSnapshot(tenantId, buKey, ...)` (BU snapshot keyed by id = what widget Gets); :215 log keeps BusinessUnitName; per-queue key :122 (Workgroup) UNTOUCHED.
- => BU widget Get(Config.BusinessUnit=BusinessUnitId) now matches; ~20 BU-name==Workgroup collisions eliminated (prefix-hardening obsolete). build green=CC gate.
- status: done. verified: object-store (d1982de). Binding reconciled. v3 +6 vs origin, NOT pushed.
