# Changelog — RTM View Shell (CC Dashboard Shell)

All notable changes to this project are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions correspond to Technical Specification revisions.

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
