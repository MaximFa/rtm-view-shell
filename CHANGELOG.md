# Changelog — RTM View Shell (CC Dashboard Shell)

All notable changes to this project are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions correspond to Technical Specification revisions.

---

## [1.6.0] — 2026-05-31

### Summary

RTM Relay Infrastructure (CC-003): single-port browser model replacing the
two-port design. Shell now acts as a server-side SignalR client to RTM Service;
browsers only need one connection (port 443).

### Added

- `IRtmRelayService` (Application layer) — subscribe/unsubscribe per `(TenantId, UnionId/GridId)`
- `RtmRelayService` (Infrastructure, Singleton) — `HubConnection` per `(TenantId, UnionId)` and
  `(TenantId, GridId)` with ref-count, 30 s grace timer, in-memory snapshot, reconnect backoff
- Domain models: `CellValue`, `AgentSnapshot`, `UnionStateChange`, `GridCellUpdate`
- `RtmRelayHub` — browser-facing `/hubs/rtm-relay` for JS / external widget clients
- `DisconnectTenantAsync(tenantId)` — called on tenant Suspend/Delete

### Changed

- `DI`: `AddSingleton<IRtmRelayService, RtmRelayService>()` + `MapHub<RtmRelayHub>` in Program.cs
- `tenant_settings.SignalRConnectionUrl` — existing field, now used by `RtmRelayService`
- Architecture docs updated: widget-framework.md §6.2, diagrams/architecture.md

### Architecture note

Previous design required browser to open two WebSockets (Shell port 443 + RTM Service port N).
New design: one WebSocket (port 443) only. RTM Service is internal-network only.
See CLAUDE.md §34.

---

## [1.3.3] — 2026-05-26

### Summary

Template widget instantiation (#19) and dashboard clone RTS fix (#20).
Dragging a widget from templates now resets all RTS IDs so fresh DB records
are created on first save. Dashboard clone now correctly creates fresh RTS
records for all three widget types (Queue Grid, Agent Grid, Data Slot).

### Added

- `RtsRepository`: `DeleteQueueGridCellAsync(cellId)`,
  `DeleteQueueGridCellsByRowIdAsync(rowId)`,
  `DeleteQueueGridCellsByColumnIdAsync(columnId)` — granular cell-level deletion
  methods for future partial-update scenarios.
- `CloneDashboardCommand.CreateDataSlotRtsRecords` — new method that creates a
  fresh 1×1×1 `RTSGrid_*` structure for cloned DataSlot widgets.

### Changed

- `ScreenEditorPage.razor` — template drop now resets all RTS IDs to null:
  `GridId`, `HeaderRowId`, `ColumnsSetId`, `RtsUserGridId`, per-column `DbColumnId`,
  `DataSlotGridId/ColumnId/RowId/CellId`. Ensures fresh INSERT on first save of the
  instantiated widget (previously IDs were copied from template, causing RTS conflicts).
- `CloneDashboardCommand`:
  - `ClearRtsIdsFromConfig`: now clears `rtsUserGridId` (Agent Grid) and all
    `dataSlot*Id` fields (DataSlot) in addition to Queue Grid fields.
  - `CreateAgentGridRtsRecords`: now correctly writes `rtsUserGridId` back into
    ConfigJson (was missing, causing Agent Grid clone to have no RTS record reference).
  - All three widget types fully handled: Queue Grid, Agent Grid, Data Slot.

### Fixed

- **#19** — Dragging widget from template palette onto canvas preserved old RTS IDs
  from the template source, causing the new widget instance to share RTS records with
  the template. Fixed by resetting all RTS IDs to null on template drop.
- **#20** — `CloneDashboardCommand` did not handle Agent Grid `rtsUserGridId` or
  DataSlot RTS fields — cloned widgets shared RTS records with the original dashboard.
  Fixed: all three widget types now get fresh RTS records on clone.

---

## [1.3.2] — 2026-05-26

### Summary

Widget catalogue cleanup (#16) and DataSlot + AgentGrid RTS persistence fixes (#17, #18).
Catalogue trimmed to 3 SignalR-backed widgets. DataSlot now writes to RTSGrid_* tables on
config save. Critical AgentGrid RTS ID bug fixed (orphan data eliminated).

### Added

- `SaveDataSlotRtsCommand` / `SaveDataSlotRtsResult` — creates/updates a 1×1×1 structure
  in `RTSGrid_*` tables (1 Grid → 1 Column → 1 Row → 1 Cell with `CellType="Data"`,
  `Value=MetricId`). Includes existence-check-before-UPDATE pattern to guard against stale
  ConfigJson IDs (e.g. after dashboard clone).
- `WidgetConfig.DataSlotGridId`, `DataSlotColumnId`, `DataSlotRowId`, `DataSlotCellId`
  (all `int?`) — persisted in ConfigJson after first save.
- `WidgetConfig.RtsUserGridId` (`int?`) — stores `RTSUserGrid_Grid.GridId` for Agent Grid;
  replaces the previous (wrong) use of `DashboardWidget.GridId` for RTS operations.

### Changed

- `ScreenEditorPage.razor`:
  - `SaveWidgetConfig` (DataSlot): calls `SaveDataSlotRtsCommand` when `DataSlotMetricId`
    is set; writes back all four RTS IDs into temp fields and new `WidgetConfig`.
  - `SaveWidgetConfig` (Agent Grid): uses `Config.RtsUserGridId ?? 0` as input to
    `SaveAgentGridRtsCommand` (was incorrectly using `DashboardWidget.GridId`).
  - `OpenWidgetConfig`: loads `DataSlotGridId/ColumnId/RowId/CellId` and `RtsUserGridId`
    from `widget.Config`.
  - `ConfirmDeleteWidget`: queues Agent Grid widgets using `Config.RtsUserGridId > 0`;
    queues DataSlot widgets using `Config.DataSlotGridId > 0` (deferred deletion pattern).
  - `SaveLayout` delete loop: `DeleteAgentGridRtsCommand(Config.RtsUserGridId)` for Agent
    Grid; `DeleteQueueGridRtsCommand(Config.DataSlotGridId)` for DataSlot.
  - Template drop: resets `RtsUserGridId=null`, `ColumnsSetId=null`, `AgentGridColumnDef.DbColumnId=null`
    to force fresh INSERT on next save; also resets `DataSlotGridId/ColumnId/RowId/CellId`.
- `DatabaseInitializer.SeedWidgetCatalogAsync`: seeds only 3 entries; removes 11 obsolete
  stub entries on startup.
- `RenderWidget.razor`: trimmed to 3 widget type branches.

### Fixed

- **#18 Critical** — `SaveAgentGridRtsCommand` was called with `DashboardWidget.GridId`
  (auto-increment from `dashboard_widgets`, e.g. 14/15/16) instead of the true RTS key
  `Config.RtsUserGridId` (e.g. 1). This caused: (a) save creating new RTS records instead
  of updating; (b) deletion targeting non-existent RTS IDs; (c) orphan data in
  `RTSUserGrid_*` tables. Fixed by introducing `WidgetConfig.RtsUserGridId`.
- Delete modal RTS warning now correctly checks `Config.RtsUserGridId > 0` for Agent Grid
  (was checking `PlacedWidget.GridId`).
- Cleaned up 2 orphan `RTSUserGrid_Column` rows (ColumnsSetId=14, non-existent in
  `RTSUserGrid_ColumnsSet`).

### Removed

- `KpiWidget.razor`, `AgentStatusWidget.razor`, `QueueSummaryWidget.razor` — mock
  components emptied to single comment line (compile-clean).
- 11 obsolete `widget_catalog` entries cleaned by `DatabaseInitializer` on startup.

### Gap / known issues

- `SaveDataSlotRtsCommand` has no test coverage.
- `DataSlotBusinessUnitId` stored and passed to command but SignalR subscriber reads
  first row regardless — BU-based row filtering not yet active.
- `WidgetConfig` ConfigJson round-trip for DataSlot RTS fields is not tested.

---

## [1.3.1] — 2026-05-26

### Summary

Patch release closing T6 (User Management + Audit Trail, 79 new tests) and Backlog #15
(NGC_*/RTS_* table ownership separation per ADR-007). All 382 tests pass.

### Added

#### User Management (T6 Phase A — USR-01..14)
- `UserManagementService`: full CRUD with cross-tenant guard, role-change audit events
  (`User.RoleChanged`, `User.PermissionGroupChanged`), self-role-change guard for Admins,
  Superadmin-creation restriction. (GAP-T6-01..04)
- `GetUsersQuery`: server-side pagination, sort, filter by role / PG / status / search.
  Role-aware tenant scoping (Admin → own tenant; Superadmin → all). (USR-13, USR-14)
- Admin-initiated password reset (one-time token, 24h TTL) and self-service reset with
  uniform response regardless of email existence. (USR-11, USR-12, BFP-03)
- Force-logout via `SecurityStamp` rotation. (USR-09)

#### Audit Trail (T6 Phase B — AUD-01..08)
- `ForwardedHeadersMiddleware` wired in `Program.cs` — `X-Forwarded-For` IP extraction
  stored in `audit_logs.IpAddress`. (AUD-04)
- `IAuditLogRepository.CountAsync` + `AuditLogRepository` implementation — CSV export
  boundary check (≤50 000 records → data; >50 000 → async job indicator). (AUD-08)
- `GetAuditLogsQuery`: role-aware tenant scoping (Admin own-tenant only; Superadmin all).

#### Infrastructure (Backlog #15)
- `AppDbContext` migration `SeparateBackendTablesToBeDb` — NO-OP DDL migration that
  removes NGC_*/RTS_* entity mappings from AppDbContext model snapshot.
- `BackendEmulationDbContext` migrations rewritten with `CREATE TABLE IF NOT EXISTS`
  for compatibility with databases where tables pre-exist from prior AppDbContext migrations.
- `NgcRepositories`, `RtsRepository`, `PermissionGroupRepository`: constructors updated
  to inject `BackendEmulationDbContext` instead of `AppDbContext` for backend tables.
- `DatabaseInitializer.SeedSampleCcEntitiesAsync`: all `SaveChangesAsync` calls use
  `beDb` (not `db`) — fixes silent seed failure introduced in B1 #11 migration.

### Fixed

- **GAP-T6-01**: `UpdateAsync` now emits `User.RoleChanged` / `User.PermissionGroupChanged`
  when role or PG changes (was emitting only generic `User.Updated`). (USR-07)
- **GAP-T6-02**: `UpdateAsync` / `DeleteAsync` / `SetActiveAsync` / `ForceLogoutAsync` now
  verify `user.TenantId == currentUser.TenantId` — prevents cross-tenant mutation by userId leak.
- **GAP-T6-03**: Admins cannot change their own role. (USR-08)
- **GAP-T6-04**: Only Superadmin can create Superadmin users. (USR-05)
- **#15 seed bug**: NGC seed data was added to `beDb` ChangeTracker but saved via
  `db.SaveChangesAsync()` — data was never persisted. Fixed to `beDb.SaveChangesAsync()`.

### Removed

- `NgcIsolationTests.cs` (10 tests) — GQF does not apply to backend-owned tables; tests
  were testing an invariant that intentionally does not exist. (ADR-007)
- `CrossTenantEntitiesTests.cs` NGC section (-42 lines) — same reason.

### Process

- `CLAUDE.md §0.5` — mandatory pre-commit `tail -3` + `wc -l` on every staged file.
- `CLAUDE.md §0.6` — mandatory post-commit `git status --short` must be empty.
- Post-migration procedure for #15: clear `__BackendEmulationMigrationsHistory`,
  restart app, reimport `Metrics_fixed.sql` (190 rows).

---

## [1.3.0] — 2026-05-25

### Summary

v1.3 closes the T1–T5 test-coverage programme (313 tests total), introduces the widget
framework foundation, resolves 7 security findings, and establishes the BackendEmulationDbContext
pattern for dev/CI isolation. All architecture decisions from the spec review are documented
as ADR-001 through ADR-008.

### Added

#### Infrastructure
- `BackendEmulationDbContext` — separate EF DbContext for backend-owned tables
  (`NGC_*`, `RTSGrid_*`, `RTSUserGrid_*`) with dedicated migration history
  (`__BackendEmulationMigrationsHistory`). Guards EF migrations from touching
  CC-platform tables. (B1 #11, ADR-007)
- `PostgresFixture.CreateBackendEmulationDbContext()` — helper for integration tests
  to access backend emulation tables on the same Testcontainers Postgres instance.
- `GridNotificationHub.cs` — SignalR hub for RTS grid live updates, with tenant
  prefix enforcement (`t:{tenantId}:{groupName}`). (ARCH-09, T5)
- Queue Grid entities in `RtsEntities.cs` — `RtsGrid`, `RtsUserGrid`, `RtsGridQueue`
  with TenantId GQF. (T5)
- `NoOpConfigurationApiHook` — `IConfigurationApiHook` stub that logs dual-write
  events without HTTP calls; replaces direct-call pattern. (ADR-008)

#### Domain / Application
- `WidgetCatalogItem` entity — cross-tenant, no GQF; populated via seed migration.
  Category / Name / Description / IconUrl / IsActive fields. ([WGT-01..03], ADR-001)
- `DashboardWidget` entity — stub for future widget placement; `PositionJson` /
  `ConfigJson` jsonb fields reserved for widget-library sprint. ([WGT-04])
- `SaveDashboardWidgetCommand` / handler — creates `DashboardWidget` record;
  triggers dual-write API hook. (T5)
- `SaveAgentGridRtsCommand` / handler — lifecycle management for RTS grid entities. (T5)
- `WidgetCatalogService` — browse by category, filtered by `IsActive` for non-Superadmin.

#### Tests (T1–T5 programme)
- **T1** (closed): 79 tests — `AuthTests`, `PasswordPolicyTests`, `BruteForceTests`,
  `TwoFactorTests`, `SsoTests`. SF-001..SF-004 found and fixed.
- **T2** (closed): ~80 tests — `UserManagementTests`, `PermissionGroupTests`,
  `DashboardTests`, `AuditTests`. SF-005 (Critical — cross-tenant dashboard leak) found and fixed.
- **T3** (closed): 38 tests — `TenantResolutionTests`, `RedisKeyPrefixTests`,
  `JwtClaimsTests`, `PasswordPolicyTests` (extended), `MultiTenancyGqfTests`. SF-006 found.
- **T4** (closed): 46 tests — `LocalisationTests`, `SecurityHeadersTests`,
  `RateLimitingTests`, `ConcurrencyTests`, `AuditRetentionTests`. PD-003 resolved.
- **T5** (closed): 28 tests — `WidgetCatalogTests` (6), `DashboardWidgetTests` (5),
  `RtsGridLifecycleTests` (13), `SignalRTenantGuardTests` (4). SF-007 found and fixed.
- **Total: 313 tests** across unit, integration, security, and architecture test projects.

#### Architecture decisions (ADR)
- ADR-001: Widget Catalogue scope — entity yes, admin CRUD screen no
- ADR-002: Navigation menu redesign — section grouping + extended menu keys
- ADR-003: Per-tenant licensing model — schema placeholder; enforcement deferred to v1.4
- ADR-004: External widget data feed seam — per-tenant SignalR Connection URL in tenant_settings
- ADR-005: Per-tenant theme palette — CSS variable injection + font-size presets
- ADR-006: Permission Groups model redesign — drop Skills, split SG/AG, AccessLevel bitmask
- ADR-007: Database boundary — BackendEmulationDbContext; PascalCase vs snake_case naming
- ADR-008: Dual-write pattern — fire-and-forget v1.3; outbox deferred to v1.4

#### Documentation
- `decisions/ADR-001..ADR-008` — all 8 decision records created from template.
- `docs/architecture/widget-framework.md` — widget framework technical architecture.
- `docs/diagrams/architecture.md` — C4 diagrams (Context, Container, Component, ER, Sequences).
- `docs/traceability-matrix.md` — updated through T5 (T3 additions: ARCH-03, ARCH-08, AUTH-API-01, PWD-01..05).
- `docs/sprints/T1..T5` — sprint briefs and gap analyses for all five sprints.

### Changed

- **CLAUDE.md §0.3** — Strengthened verification rule: "`tail -3` + `wc -l` after every
  Python write — NO EXCEPTIONS — before staging or further edits." (2026-05-25)
- **`AppDbContext` Global Query Filters** — Added GQF on junction tables
  `NgcSupergroupAgentgroup`, `NgcBusinessUnitQueueClassification`, `NgcBusinessUnitSupergroup`
  (lines 298, 310, 322). (T3 OQ-1 resolution)
- **`TokenService.cs`** — `NotBefore = now` (instead of `IssuedAt - 30s`) to close
  timing window. (SF-006)
- **`NSubstitute`** added to `Tests.Security.csproj` (v5.1.0) — required by
  `TenantResolutionTests` and `JwtClaimsTests`.
- **Permission Groups model** — `pg_skills` removed; `pg_agent_supergroups` split from
  agent groups; `dashboard_permissions.AccessLevel` changed to INTEGER bitmask. (ADR-006)
- **`tenant_settings`** — Added schema columns: `PurchasedSeats`, `LicenceExpiresAt`,
  `BackendSignalRUrl`, `ThemeBgColour`, `ThemeFgColour`, `ThemeFontSize`. (ADR-003..005)
- **`_index.md`** in `decisions/` — moved ADRs from "Open" placeholder to "Accepted" once
  files are created.

### Fixed (Security Findings)

- **SF-001** — Password history check bypassed on admin-initiated reset. Fixed: history
  check now applies to all password change paths.
- **SF-002** — 2FA code brute-force: attempt counter not persisted across Blazor reconnect.
  Fixed: `AttemptCount` persisted to `identity.two_factor_codes` before each check.
- **SF-003** — Refresh token reuse detection did not revoke sibling tokens. Fixed:
  `AuthorizationService.RevokeAllForUserAsync()` called on reuse detection.
- **SF-004** — SSO stub threw `NotImplementedException` leaking stack trace to client.
  Fixed: exception caught in middleware; generic 500 returned; stack trace in structured log only.
- **SF-005** *(Critical)* — Cross-tenant dashboard leak: dashboard query lacked combined
  GQF (`TenantId` + `!IsDeleted`). Users from tenant A could view tenant B dashboards
  via direct URL. Fixed: combined GQF enforced in `AppDbContext`; regression test added.
- **SF-006** — JWT `NotBefore` set 30s before `IssuedAt`, allowing token use before issue
  time. Fixed: `NotBefore = now`.
- **SF-007** — `GridNotificationHub` Hub methods did not verify `TenantId` from
  `ClaimsPrincipal`. Fixed: explicit claim check added; test added in `SignalRTenantGuardTests`.

### Process Deviations

- **PD-001** — T1 gap file not committed before sprint hand-off. Resolved: gap file added
  in follow-up commit.
- **PD-002** — `DatabaseInitializer` lacks interface (`IDatabaseInitializer`); makes unit
  testing harder. Status: Backlog #13 (low priority).
- **PD-003** — T4 test file for `SecurityHeadersTests` initially absent from project file.
  Resolved: `.csproj` updated; all tests passing.
- **PD-004** — T4 gap analysis file missing. Resolved: no gap analysis required (no OQs open).
- **PD-005** — Cowork mount partial-write failures (3 incidents in one session).
  Resolved: CLAUDE.md §0.3 strengthened with mandatory `tail -3` + `wc -l` rule.

---

## [1.2.0] — 2026-05-09

### Summary

v1.2 established the full solution structure, EF Core data model, authentication stack,
and interactive wireframes for all 5 screens. Seed data, deployment scripts, and the
traceability matrix introduced.

### Added

- Complete Clean Architecture solution structure (Domain, Contracts, Application,
  Infrastructure, Web, Api, 4 test projects).
- All domain entities per TZ §6: `ApplicationUser`, `ApplicationRole`, `Tenant`,
  `TenantSettings`, `SsoConfiguration`, `PermissionGroup`, `MenuPermission`,
  `DashboardPermission`, `Dashboard`, `WidgetCatalogItem`, `AuditLog`,
  `RefreshToken`, `TwoFactorCode`, `UserPasswordHistory`, reference tables.
- EF Core Global Query Filters on all multi-tenant entities.
- ASP.NET Core Identity + cookie auth (Blazor) + JWT Bearer (API).
- `SecurityHeadersMiddleware`, `TenantResolutionMiddleware`, `ExceptionHandlingMiddleware`.
- MediatR pipeline: `LoggingBehavior`, `ValidationBehavior`, `TransactionBehavior`,
  `AuthorizationBehavior`, `AuditBehavior`.
- `IAuditService` with separate `AuditDbContext`; `audit.audit_logs` partitioned by month.
- `IEmailSender` + `SmtpEmailSender`; `IConfigurationApiHook` + `NoOpConfigurationApiHook`.
- Interactive wireframes: `wireframes/en/01..05`.
- `docs/diagrams/architecture.md` (C4 diagrams).
- `Install-CcDashboard.ps1` and `Update-CcDashboard.ps1` deployment scripts.
- `docs/traceability-matrix.md` (initial).

### Architecture decisions

- TZ version 1.2 codified: multi-tenancy model, password policy, 2FA, SSO stub,
  brute-force protection, audit trail, dashboard management.
- Blazor Server (SignalR circuit) chosen over Blazor WebAssembly for server-side
  state isolation per tenant.

---

## [1.1.0] — 2026-05-01

### Summary

Initial proof-of-concept: Blazor Server project scaffolding, PostgreSQL connection,
basic Identity setup. Not suitable for production.

### Added

- `CcDashboard.sln` with `CcDashboard.Web` and `CcDashboard.Infrastructure` projects.
- Basic `AppDbContext` with `ApplicationUser : IdentityUser<Guid>`.
- Local development `appsettings.Development.json` (excluded from source control).
- Initial README.

---

*Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)*
