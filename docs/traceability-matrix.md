# Traceability Matrix — RTM View Shell

Maps every numbered requirement from the TZ to:
- The **ADR** that records the decision behind it (if any)
- The **implementation file(s)** that satisfy it
- The **test(s)** that verify it

Updated as part of every sprint close-out.

---

## Multi-tenancy (ARCH-01..ARCH-10)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| ARCH-01 | ADR-TBD | `AppDbContext.OnModelCreating` (GQF) | `Tests.Security/MultiTenancy/GlobalQueryFilterTests` (Phase A; SF-001 fixed) |
| ARCH-02 | ADR-TBD | `Admin/TenantSwitcher.razor` + audit | (T3 planned) |
| ARCH-03 | ADR-TBD | `TenantResolutionMiddleware` | `Tests.Security/MultiTenancy/TenantResolutionTests` (5 tests: known slug, unknown, suspended, deleted, no-subdomain) — T3 |
| ARCH-04 | ADR-TBD | `IdentityAuthService.SignInAsync` (tenant match) | `Tests.Security/MultiTenancy/TenantMismatchLoginTests` (Phase A, negative) + `Tests.Security/Identity/GoldenPathLoginTests.PasswordSignInAsync_CorrectTenant_ReturnsSuccess` (Phase C, positive) — SF-002 fixed |
| ARCH-05 | ADR-TBD | `AppDbContext` (no GQF on Tenant, etc.) | `Tests.Security/MultiTenancy/CrossTenantEntitiesTests` (Phase A) |
| ARCH-06 | ADR-TBD | `TenantStatus` enum + login guard | `Tests.Security/TenantLifecycle/SuspendedAndDeletedTenantTests` (Phase A, negative) + `Tests.Security/Identity/GoldenPathLoginTests.{PasswordSignInAsync_ActiveTenant_SucceedsWithCorrectCredentials, TenantStatus_Transition_AffectsLoginBehavior}` (Phase C) — SF-003 fixed |
| ARCH-07 | ADR-TBD | (background services pending) | TBD |
| ARCH-08 | ADR-TBD | `RedisCacheService` (key prefix `{tenantId}:{ns}:{key}`) | `Tests.Security/Infrastructure/RedisKeyPrefixTests` (4 tests: revoked-jti, different-tenants, pg-cache, 2fa-resend keys) — T3 |
| ARCH-09 | ADR-TBD | `Web/Hubs/GridNotificationHub` (token TenantId check) | `Tests.Security/Widgets/SignalRTenantGuardTests` (4 tests: matching tenant, mismatched tenant, unauthenticated, leave group) — T5 |
| ARCH-10 | ADR-TBD | `IBlobStorage` impl (pending) | (no impl yet — deferred per DEF-09) |

## Authentication — Web (AUTH-WEB-01..04)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| AUTH-WEB-01 | ADR-TBD | `Program.cs` Identity + cookie options | `Tests.Security/Smoke/WebFixtureSmokeTests` (Phase C — smoke verifies pipeline) |
| AUTH-WEB-02 | ADR-TBD | `IdentityAuthService.CompleteSignInAsync` (claims) | `Tests.Security/Identity/GoldenPathLoginTests.CompleteSignInAsync_ValidUser_MaterialisesClaimsCorrectly` (Phase C) |
| AUTH-WEB-03 | ADR-TBD | `IdentityAuthService.SignOutAsync` + SecurityStamp invalidation | `Tests.Security/Authentication/ForceLogoutTests` (4 tests: force-logout, deactivation, SecurityStamp patterns) — T2 |
| AUTH-WEB-04 | ADR-012 | `IdentityAuthService` LICENSE-SESSION pre-check | `Tests.Security/Identity/GoldenPathLoginTests.PasswordSignInAsync_{NoLimit, WithinLimit, SameIp, ExpiredSession, RevokedSession}_*` (Phase C — 5 golden-path tests) |

## Authentication — API (AUTH-API-01..06)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| AUTH-API-01 | ADR-TBD | `Infrastructure/Security/TokenService.CreateTokenPairAsync` | `Tests.Security/Authentication/JwtClaimsTests` (5 tests: required claims, 15-min expiry, iss/aud, role claim, Superadmin no-pg-claim) — T3 |
| AUTH-API-02 | ADR-TBD | `Infrastructure/Security/TokenService.IssueAccessToken` | `Tests.Security/ApiAuth/RefreshTokenRotationTests` |
| AUTH-API-03 | ADR-TBD | `Infrastructure/Security/TokenService.IssueRefreshToken` + cookie | `Tests.Security/ApiAuth/RefreshTokenRotationTests` |
| AUTH-API-04 | ADR-TBD | `TokenService.RotateAsync` + reuse-detection | `Tests.Security/ApiAuth/RefreshTokenRotationTests` (5 tests) |
| AUTH-API-05 | ADR-TBD | `TokenService.RevokeJtiAsync` (Redis) | `Tests.Security/ApiAuth/JtiRevocationTests` (5 tests; SF-004 fixed) |
| AUTH-API-06 | ADR-TBD | `TokenService` RS256/RSA-2048 configuration | `Tests.Security/Authentication/JwtKeyConfigurationTests` (6 tests: algorithm, key size, round-trip integrity) — T2 |

## Password policy (PWD-01..05)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| PWD-01 | ADR-TBD | `Identity PasswordOptions.RequiredLength` (min 12) | `Tests.Security/PasswordPolicy/PasswordPolicyTests` (2 tests: too-short rejected, min-length accepted) — T3 |
| PWD-02 | ADR-TBD | `Identity PasswordOptions` (upper/lower/digit/special) | `Tests.Security/PasswordPolicy/PasswordPolicyTests` (4 [Theory] cases: missing upper/lower/digit/special) — T3 |
| PWD-03 | ADR-TBD | `PasswordHasherOptions.IterationCount` ≥ 100000 | `Tests.Security/PasswordPolicy/PasswordPolicyTests` (1 config assertion) — T3 |
| PWD-04 | ADR-TBD | `IdentityAuthService` password history check (last 10) | `Tests.Security/PasswordPolicy/PasswordPolicyTests` (1 integration test: reuse rejected) — T3 |
| PWD-05 | ADR-TBD | `ApplicationUser.MustChangePasswordAt` set on creation/expiry | `Tests.Security/PasswordPolicy/PasswordPolicyTests` (2 tests: flag set on creation, expired flag present) — T3 ⚠ Blazor redirect deferred |

## Brute-force protection (BFP-01..04)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| BFP-01 | ADR-TBD | Identity `LockoutOptions` + `IdentityAuthService` | `Tests.Security/BruteForce/LockoutTests` (5 tests) |
| BFP-02 | ADR-TBD | `Web/Middleware/LoginRateLimitMiddleware` (Redis) | `Tests.Security/BruteForce/RateLimitTests` (8 tests) |
| BFP-03 | ADR-TBD | `IdentityAuthService` uniform-error returns | `Tests.Security/BruteForce/UniformErrorTests` (6 tests) |
| BFP-04 | ADR-TBD | Audit subtype emission in `IdentityAuthService` | `Tests.Security/TenantMismatchLoginTests` + `BruteForce/UniformErrorTests` |

## Licensing (LICENSE-SESSION — v1.3)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| LICENSE-SESSION (rejection) | ADR-012 | `IdentityAuthService` session-limit guard | `Tests.Security/Licensing/LicenseSessionTests` (Phase B — 1 test, negative) |
| LICENSE-SESSION (golden path) | ADR-012 | Same | `Tests.Security/Identity/GoldenPathLoginTests.PasswordSignInAsync_{NoLimit, WithinLimit, SameIp, ExpiredSession, RevokedSession}_*` (Phase C — 5 tests, positive) |

## Licensing (LICENSE-USER / LIC-01 — v1.3)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| LIC-01 (limit enforcement) | ADR-TBD | `UserManagementService.CreateAsync` (PurchasedLicences check) | `Tests.Security/Licensing/LicenseUserLimitTests` (4 tests: at limit, below limit, no limit, concurrent race) — T2 |
| LIC-01 (race protection) | SF-007 | `UserManagementService.CreateAsync` (transaction + `FOR UPDATE`) | `Tests.Security/Licensing/LicenseUserLimitTests.ConcurrentCreation_AtLimit_OnlyOneSucceeds` — T2 |
| LIC-01 (audit emission) | SF-006 | `UserManagementService.CreateAsync` (audit.LogAsync on rejection) | `Tests.Security/Licensing/LicenseUserAuditTests` (3 tests: emits event, no event on success, contains count/limit) — T2 |

## 2FA (2FA-01..07)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## SSO (SSO-01..04)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## Permission Groups (PG-01..07)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| PG-01 | ADR-TBD | `CreateDashboardCommandHandler` (creator auto-grant) | `Tests.Security/Authorization/CreatorAutoGrantTests` (4 tests) |
| PG-03 | ADR-TBD | `IPermissionService.HasResourceAccessAsync` (empty = denied) | `Tests.Security/Authorization/ResourceAccessTests` (7 tests) |
| PG-04 | ADR-TBD | `AuthorizationBehavior` + `PermissionService.HasDashboardAccessAsync` (bitmask) | `Tests.Security/Authorization/DashboardAccessTests` (5 tests) + `AuthorizationBehaviorTests` (7 tests) + `PermissionGroupAssignmentTests` (5 tests) |
| PG-06 | ADR-TBD | `DeletePermissionGroupCommandHandler` (users assigned check) | `Tests.Security/Authorization/PermissionGroupDeletionTests` (5 tests) |
| PG-07 | ADR-TBD | `PermissionService.InvalidateCacheAsync` (Redis invalidation) | `Tests.Security/Authorization/PermissionCacheInvalidationTests` (5 tests) |

## Audit (AUD-01..08)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| AUD-01 | ADR-TBD | `AuditService` (separate `AuditDbContext`, immediate write) | `Tests.Security/Audit/AuditIsolationTests` (5 tests: TX rollback survival, separate context, schema, UoW independence) + `Authorization/PermissionGroupAuditTests` (4 tests) — T6 |
| AUD-02 | ADR-TBD | `AuditDbContext` (INSERT-only, no Update/Delete exposed) | `Tests.Security/Audit/AuditInsertOnlyTests` (5 tests: no Update/Remove methods, no soft-delete, DbSet type) — T6 |
| AUD-03 | ADR-TBD | `TenantSettings.AuditRetentionDays` (default 365) | `Tests.Security/Audit/AuditRetentionTests` (6 tests: property exists, default value, persistence, custom values) — T6 |
| AUD-04 | ADR-TBD | `Program.cs` `UseForwardedHeaders()` + `ForwardedHeadersOptions` | `Tests.Security/Audit/AuditIpExtractionTests` (4 tests: X-Forwarded-For → audit IP, failed login, multiple IPs) — T6 |
| AUD-05 | ADR-TBD | `UserManagementService` (User.Created/Updated/RoleChanged/PermissionGroupChanged/Deactivated/Activated) | `Tests.Security/Audit/AuditUserEventsTests` (6 tests: all User.* events emitted) — T6 |
| AUD-06 | ADR-TBD | `GetAuditLogsQueryHandler` (role-aware scoping: Admin→own tenant, Superadmin→all or filtered) | `Tests.Security/Audit/AuditScopingTests` (9 tests: Admin own tenant, Superadmin all/filtered, pagination, event type filter, date range) — T6 |
| AUD-08 | ADR-TBD | `IAuditLogRepository.CountAsync` (export boundary check ≤50k) | `Tests.Security/Audit/AuditExportTests` (8 tests: count methods, boundary checks, tenant filter) — T6 |

## Dashboards (DASH-01..05)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## Widget catalogue (WGT-01..04)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| WGT-01 | ADR-TBD | `WidgetCatalogItem` (no TenantId, no GQF) | `Tests.Security/Widgets/WidgetCatalogTests` (3 tests: visible from any tenant, no GQF applied, all categories visible) — T5 |
| WGT-02 | ADR-TBD | `GetWidgetCatalogQueryHandler` (role-gated) | `Tests.Security/Widgets/WidgetCatalogTests` (1 test: Editor sees active only) — T5 |
| WGT-03 | ADR-TBD | `GetWidgetCatalogQueryHandler` (Superadmin IncludeInactive) | `Tests.Security/Widgets/WidgetCatalogTests` (2 tests: Superadmin sees all, non-Superadmin filters inactive) — T5 |
| WGT-04 | ADR-TBD | `SaveDashboardWidgetCommandHandler`, `SaveAgentGridRtsCommandHandler`, `SaveQueueGridRtsCommandHandler`, `DeleteAgentGridRtsCommandHandler`, `DeleteQueueGridRtsCommandHandler` | `Tests.Security/Widgets/DashboardWidgetTests` (5 tests) + `Tests.Security/Widgets/RtsGridLifecycleTests` (13 tests: CRUD + API hooks) — T5 |

## User management (USR-01..14)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| USR-01 | ADR-TBD | `UserManagementService.CreateAsync` (Admin/Superadmin can create) | `Tests.Security/UserManagement/UserCreateTests` (8 tests: roles, required fields, email validation, temp password, audit) — T6 |
| USR-02 | ADR-TBD | `UserManagementService.CreateAsync` (required: UserName, Email, Role, PG) | `Tests.Security/UserManagement/UserCreateTests` (required fields validation) — T6 |
| USR-03 | ADR-TBD | `UserManagementService.CreateAsync` (generates temp password, sets MustChangePasswordAt) | `Tests.Security/UserManagement/UserCreateTests` (2 tests: password generated, audit event) — T6 |
| USR-04 | ADR-TBD | `CreateUserRequestValidator` (email format + uniqueness) | `Tests.Security/UserManagement/UserCreateTests` (email validation test) — T6 |
| USR-05 | ADR-TBD | `UserManagementService.CreateAsync` (Admin cannot create Superadmin or cross-tenant) | `Tests.Security/UserManagement/UserCreateTests` (2 tests: Superadmin guard, cross-tenant guard) — T6 |
| USR-06 | ADR-TBD | `UserManagementService.UpdateAsync` (editable fields: name, email, role, PG, IsActive, locale) | `Tests.Security/UserManagement/UserUpdateTests` (6 tests: field updates, role change audit, PG change audit) — T6 |
| USR-07 | ADR-TBD | `UserManagementService.UpdateAsync` (role change → User.RoleChanged audit with old/new) | `Tests.Security/UserManagement/UserUpdateTests` + `Audit/AuditUserEventsTests` — T6 |
| USR-08 | ADR-TBD | `UserManagementService.UpdateAsync` (Admin cannot change own role) | `Tests.Security/UserManagement/UserUpdateTests` (self-role-change guard test) — T6 |
| USR-09 | ADR-TBD | `UserManagementService.SetActiveAsync` (SecurityStamp on deactivation) | `Tests.Security/Authentication/ForceLogoutTests` (4 tests) + `UserManagement/UserDeactivationTests` (7 tests: audit, SecurityStamp, token revocation) — T2/T6 |
| USR-11 | ADR-TBD | `UserManagementService.AdminResetPasswordAsync` (one-time token, 24h TTL) | `Tests.Security/UserManagement/PasswordResetTests` (7 tests: admin reset, self-reset, uniform response) — T6 |
| USR-12 | ADR-TBD | `UserManagementService.SelfResetPasswordAsync` (uniform response) | `Tests.Security/UserManagement/PasswordResetTests` (BFP-03 uniform response test) — T6 |
| USR-13 | ADR-TBD | `GetUsersQuery` (server-side pagination, filter by role/PG/active) | `Tests.Security/UserManagement/UserListTests` (7 tests: pagination, filtering, sorting) — T6 |
| USR-14 | ADR-TBD | `GetUsersQuery` (Admin sees own tenant, Superadmin sees all/filtered) | `Tests.Security/UserManagement/UserListTests` (tenant scoping tests) — T6 |

## i18n / l10n (I18N-01..06)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## NFR — Performance / Reliability / Scalability / Maintainability

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## Deployment (DEPLOY-01..15)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## Code conventions & security (CODE-01..07)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## Data / EF Core (DATA-01..08)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

---

## Coverage summary

After T1 Phase A + Phase B + Phase C + T4 + T2 + T3 + T5 + T6:

- **Requirements with regression-safety tests:** ARCH-01 (extended), ARCH-03, ARCH-04 (positive + negative), ARCH-05, ARCH-06 (positive + negative + transition), ARCH-08, ARCH-09, AUTH-WEB-01..04, AUTH-API-01..06, BFP-01..04, PWD-01..05, LICENSE-SESSION (positive + negative), LIC-01 (LICENSE-USER), PG-01, PG-03, PG-04, PG-06, PG-07, AUD-01..06, AUD-08, USR-01..09, USR-11..14, WGT-01..04
- **T1 Phase A tests:** 32 passing
- **T1 Phase B tests:** 30 passing
- **T1 Phase C tests:** 18 passing
- **T4 Authorization tests:** 46 passing (9 test files in Authorization/)
- **T2 Licensing + Auth tests:** 20 passing
- **T3 Multi-tenancy tests:** 36 passing (6 files)
- **T5 Widget framework tests:** 28 passing (4 files)
- **T6 Phase A (User Management) tests:** 35 passing (5 files: UserCreate, UserUpdate, UserDeactivation, PasswordReset, UserList)
- **T6 Phase B (Audit Trail) tests:** 44 passing (7 files: AuditInsertOnly, AuditIsolation, AuditIpExtraction, AuditUserEvents, AuditScoping, AuditExport, AuditRetention)
- **Total `Tests.Security` count:** 311 passing
- **Total solution test count:** 392 passing (1+72+8+311)

Remaining sections to be populated:
- 2FA-01..07, SSO-01..04 (future)
- PG-02, PG-05 (T4+ — additional PG semantics)
- AUD-07 (audit CSV export async job — stub only)
- DASH-01..05 (partial by T5 DashboardWidget tests)
- ARCH-02, ARCH-07, ARCH-10 (future)
- USR-10 (deleted user handling), I18N-01..06, NFR, DEPLOY, CODE, DATA (TBD)

Updated: 2026-05-26 (T6 — User Management + Audit Trail; USR-01..14, AUD-01..08; 311/311 Security tests passing)
