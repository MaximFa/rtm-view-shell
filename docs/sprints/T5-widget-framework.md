# Sprint T5: Widget framework tests

**Status:** **Approved — ready for execution** *(all §2 micro-choices signed 2026-05-25)*  
**Estimate:** ~4–5 h Claude Code (single phase, ~30 tests)  
**Unblocked by:** B1 #11 (BackendEmulationDbContext — BeDb seeding for RTS tables)  
**Unblocks:** Documentation catch-up D1 (widget architecture input)  
**Related TS:** §18 (Widget catalogue), §15 (Permission model WGT-*), ARCH-09 (SignalR TenantId guard)

---

## 1. Scope

### Why T5 exists

T4 covered Permission Group authorization semantics. T5 closes the remaining
widget-framework test gaps:

- **Widget catalogue permissions** (WGT-01..04): cross-tenant isolation of
  `WidgetCatalogItem` (platform-wide, no GQF), role-gated access, Superadmin-only
  management, deactivated items hidden from non-Superadmin
- **DashboardWidget lifecycle**: create/update/delete widget on a dashboard, tenant
  isolation, soft-delete (IsDeleted flag)
- **RTS grid lifecycle**: `SaveAgentGridRtsCommand` / `SaveQueueGridRtsCommand` /
  `DeleteAgentGridRtsCommand` / `DeleteQueueGridRtsCommand` — dual-write to BeDb
  tables + API hook notification; these use `BackendEmulationDbContext` (B1 #11)
- **Dual-write API hook calls**: verify `IConfigurationApiHook.NotifyAsync` is called
  for every RTS mutation (NoOp stub by design — but the call must happen)
- **ARCH-09**: SignalR Hub methods must verify `TenantId` from `ClaimsPrincipal`
  before adding a connection — unit test with mock HubContext

### In scope

| Cluster | Requirements |
|---|---|
| Widget catalogue isolation | WGT-01 (cross-tenant entity — visible to all), WGT-03 (Superadmin-only add/edit/deactivate), WGT-03 (deactivated hidden from non-Superadmin) |
| Widget catalogue access | WGT-02 (browse accessible to Editor / Administrator / Superadmin), role rejection for Viewer |
| DashboardWidget lifecycle | Widget create/update/delete on a dashboard; tenant isolation; soft-delete; GridId round-trip (PreassignedGridId path) |
| RTS grid lifecycle | SaveAgentGridRts (new + update), SaveQueueGridRts (new + update), Delete variants — all write to BeDb RtsUserGrid_*/RTSGrid_* tables and call apiHook |
| Dual-write assertion | `IConfigurationApiHook.NotifyAsync` called on every RTS create/update/delete |
| SignalR TenantId guard | ARCH-09: Hub method rejects connection if token TenantId ≠ group TenantId |

### Explicitly out of scope

- Widget rendering / real-time data (out of scope for the whole shell — §1)
- Drag-and-drop layout (out of scope)
- Full SignalR E2E with live CC-platform (OQ-13 / OQ-Sim-1 — blocked on real backend)
- `Session.RejectedLicenseLimit` SignalR channel (deferred from T2 — still blocked on OQ-13)
- Widget template (WidgetTemplate) CRUD — already covered by existing unit tests
- Full RTS column lifecycle permutation testing (not security-critical; unit tests sufficient)

---

## 2. Architectural micro-choices (gate — sign before coding)

All T1 baseline choices inherited (Testcontainers PostgreSQL, real Identity for
integration tests, `[Trait("Req","...")]` markers, shared fixtures).

### MC-T5-1. Widget catalogue tests — unit or integration?

- **A. Integration** (Testcontainers + real AppDbContext): tests GQF absence
  (WGT-01 — WidgetCatalogItem is cross-tenant, no TenantId filter), Superadmin
  restriction, deactivation visibility — all need DB
- **B. Unit** (mock IWidgetCatalogRepository): faster, but misses the cross-tenant
  aspect that only a real DB + GQF demonstrates
- **Recommendation: A** — WGT-01 (cross-tenant entity visible to all) is the
  mirror of ARCH-01 and worth a DB-backed test to confirm no GQF is applied

`Decision: A — Integration (Testcontainers + real AppDbContext)`

### MC-T5-2. RTS grid lifecycle tests — integration (BeDb) or unit (mock)?

- **A. Integration** (Testcontainers, BeDb for seeding and assertion): validates
  the full dual-write path — DB row inserted + apiHook called. B1 #11 was built
  exactly for this. Confirms `BackendEmulationDbContext` works end-to-end.
- **B. Unit** (mock `IRtsRepository`): faster, already partially done in
  `Tests.Unit/Commands/SaveDashboardWidgetCommandHandlerTests`. But misses the
  actual table writes and the dual-write verification at DB level.
- **Recommendation: A** — the whole point of B1 #11 was to enable real RTS
  integration tests. T5 is the first consumer. Mock tests already exist in
  `Tests.Unit`; T5 should add integration coverage.

`Decision: A — Integration (Testcontainers + BeDb seeding)`

### MC-T5-3. ARCH-09 SignalR TenantId guard — unit test or defer?

- **A. Unit test** (inject mock `HubCallerContext` + `ClaimsPrincipal`, call hub
  method directly): verifies guard logic without live SignalR; fast; the hub
  method logic is ~10 lines and fully testable in isolation
- **B. Defer** (blocked on real SignalR CC-platform per OQ-13): skip for now
- **Recommendation: A** — hub method TenantId guard is server-side logic
  independent of the real CC-platform. Test the guard, not the subscription.

`Decision: A — Unit test (mock HubCallerContext)`

### MC-T5-4. Dual-write API hook assertion level

- **A. Mock apiHook** (`IConfigurationApiHook` substituted via NSubstitute):
  assert `NotifyAsync` called with correct eventType after DB write. Works in
  both unit and integration tests.
- **B. Real-call verification** (intercept HTTP calls in test): not feasible —
  `NoOpConfigurationApiHook` is in-process; no HTTP to intercept.
- **Recommendation: A** — substitute the hook and verify the call. This is the
  standard pattern already used in T3 `ConfigWriteProtectionTests`.

`Decision: A — Mock NSubstitute IConfigurationApiHook`

### MC-T5-5. Test location — Tests.Security or Tests.Unit?

- **A. Tests.Security** (with `[Collection("Postgres")]` for integration tests):
  consistent with T3/T4 pattern; keeps all security/integration tests in one place;
  unit-style tests (ARCH-09, dual-write mock) can also live here as non-collection
- **B. Tests.Unit** (extend existing widget unit tests): faster to run, but mixes
  test concerns — widget lifecycle security (tenant isolation) in the same project
  as pure unit logic
- **Recommendation: A** — keeps the T1–T5 coverage programme cohesive in
  `Tests.Security`; non-database tests still benefit from being near their
  integration counterparts

`Decision: A — Tests.Security (with [Collection("Postgres")] for integration tests)`

---

## 3. Definition of Done

- **DoD-1: Test count.** ≥ **28 passing tests** in `Tests.Security/` across T5
  clusters. New files: `Widgets/WidgetCatalogTests.cs`,
  `Widgets/DashboardWidgetTests.cs`, `Widgets/RtsGridLifecycleTests.cs`,
  `Infrastructure/SignalRTenantGuardTests.cs`.

- **DoD-2: Widget catalogue cross-tenant.** ≥ 3 integration tests confirming
  `WidgetCatalogItem` is readable from any tenant context (no GQF). Covers **WGT-01**.

- **DoD-3: Widget catalogue access control.** ≥ 3 tests: Editor/Admin can browse;
  Viewer role cannot access management commands; Superadmin can deactivate/add items;
  deactivated item hidden from non-Superadmin browse. Covers **WGT-02, WGT-03**.

- **DoD-4: DashboardWidget lifecycle.** ≥ 5 tests: create widget on own-tenant
  dashboard succeeds; cross-tenant dashboard access rejected (NotFoundException);
  update existing widget updates fields; soft-delete sets IsDeleted; GridId
  returned on create. Covers **WGT-04**.

- **DoD-5: RTS grid lifecycle.** ≥ 8 tests using BeDb for assertions:
  (a) SaveAgentGridRts — new grid: inserts `RtsUserGrid_Grid` + `RtsUserGrid_Column`
  rows via BeDb assertion;
  (b) SaveAgentGridRts — update: updates ColumnsSet, adds/removes columns;
  (c) SaveQueueGridRts — new + update;
  (d) DeleteAgentGridRts / DeleteQueueGridRts — rows removed from BeDb.
  Covers dual-write DB side.

- **DoD-6: Dual-write API hook.** ≥ 4 tests asserting `IConfigurationApiHook
  .NotifyAsync` is called once per RTS create/update/delete operation with correct
  `eventType` string. Use NSubstitute mock. Covers the API hook pattern (CLAUDE.md §29.6).

- **DoD-7: SignalR TenantId guard.** ≥ 3 unit tests for `ARCH-09`:
  (a) valid token with matching TenantId → group added;
  (b) token with mismatched TenantId → connection rejected / not added to group;
  (c) unauthenticated request → rejected.

- **DoD-8: No regression on OQ-16.** Read `NgcBusinessUnitQueueClassification`
  schema (check if `QueueId` is string or int — OQ-16 open question from
  `PROJECT_STATUS`). If schema differs from what RTS tests assume, surface as
  SF-008 or OQ note. Document finding in gap analysis.

- **DoD-9: Traceability matrix updated.** `docs/traceability-matrix.md` rows for
  WGT-01..04, ARCH-09 populated.

- **DoD-10: All tests pass, no regressions.** `dotnet test CcDashboard.sln` —
  all 285 + new T5 tests pass; 0 build errors; 0 new warnings.

---

## 4. Known limitations

- **OQ-13 (real SignalR protocol):** `SubscribeToGrid` / `ReceiveGridData` — the
  actual CC-platform SignalR contract is not finalised. DoD-7 tests only the
  server-side TenantId guard, not the subscription end-to-end.
- **`NoOpConfigurationApiHook`:** dual-write tests assert the call is made but
  cannot assert the payload reaches the real CC-platform API. By design (stub is
  intentional until OQ-14 resolved).
- **Widget layout / drag-and-drop:** out of scope for the entire shell v1.
- **BeDb migrations vs AppDbContext:** same note as T3 — `PostgresFixture` does
  not run `BackendEmulationDbContext` migrations separately; backend tables exist
  from `AppDbContext` migrations in dev. BeDb used for seeding + assertion only.

---

## 5. Open questions

- **OQ-16:** `NGC_BusinessUnitQueueClassification.QueueId` — in current entity
  definition (`NgcBusinessUnitQueueClassification`) it is `string`. Backend schema
  may differ. Read `Domain/Domain/NgcEntities.cs` before writing RTS grid tests that
  reference queue IDs. If string vs int mismatch found → document as SF-008.
- **OQ-17:** Does `SaveQueueGridRtsCommand` handler exist, or is it a stub /
  not-yet-implemented? Read
  `src/CcDashboard.Application/Commands/Dashboards/SaveQueueGridRtsCommand.cs` before
  coding DoD-5. If missing → add production stub as part of T5.
- **OQ-18:** `WidgetCatalogItem.IsActive` — confirm the query handler in
  `GetWidgetCatalogQuery` filters deactivated items for non-Superadmin before writing
  DoD-3 tests. Read `src/CcDashboard.Application/Queries/Widgets/GetWidgetCatalogQuery.cs`.

---

## 6. Key files to read before writing any test

```
src/CcDashboard.Application/Commands/Dashboards/SaveDashboardWidgetCommand.cs
src/CcDashboard.Application/Commands/Dashboards/SaveAgentGridRtsCommand.cs
src/CcDashboard.Application/Commands/Dashboards/SaveQueueGridRtsCommand.cs        # OQ-17
src/CcDashboard.Application/Commands/Dashboards/DeleteAgentGridRtsCommand.cs
src/CcDashboard.Application/Commands/Dashboards/DeleteQueueGridRtsCommand.cs
src/CcDashboard.Application/Queries/Widgets/GetWidgetCatalogQuery.cs              # OQ-18
src/CcDashboard.Domain/Domain/NgcEntities.cs                                       # OQ-16
src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs                         # GQF on WidgetCatalogItem
tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs                       # BeDb pattern
```

---

## 7. Claude Code hand-off prompt

```
Read: docs/sprints/T5-widget-framework.md

§2 micro-choices are signed:
- MC-T5-1 = A (widget catalogue: integration, Testcontainers + real AppDbContext)
- MC-T5-2 = A (RTS grid lifecycle: Testcontainers + BeDb seeding)
- MC-T5-3 = A (ARCH-09 SignalR guard: unit test, mock HubCallerContext)
- MC-T5-4 = A (dual-write hook: NSubstitute mock IConfigurationApiHook)
- MC-T5-5 = A (test location: Tests.Security)

Implement Sprint T5 per the brief. DoD-1 through DoD-10 are the
acceptance criteria.

Working agreement (inherited from T1–T4):
- Write T3-gap-analysis.md equivalent as FIRST close-out artefact (not last)
  → file: docs/sprints/T5-gap-analysis.md
- All new test methods carry [Trait("Req","<REQ-ID>")] matching the DoD
- Use Python atomic writes for all file edits (§0.3 of CLAUDE.md)
- Verify tail -3 + wc -l after every file write
- On completion: update docs/traceability-matrix.md (DoD-9) and
  PROJECT_STATUS.md (test counts, commit hash)
- Commit all production code changes and test files together
- Run dotnet test CcDashboard.sln and confirm 0 failures before reporting done
- Report: gap-analysis path, commit hash, test counts per file, DoD status table
```
