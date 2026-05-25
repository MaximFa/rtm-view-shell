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
| ARCH-03 | ADR-TBD | `TenantResolutionMiddleware` | (T3 planned) |
| ARCH-04 | ADR-TBD | `IdentityAuthService.SignInAsync` (tenant match) | `Tests.Security/MultiTenancy/TenantMismatchLoginTests` (Phase A, negative) + `Tests.Security/Identity/GoldenPathLoginTests.PasswordSignInAsync_CorrectTenant_ReturnsSuccess` (Phase C, positive) — SF-002 fixed |
| ARCH-05 | ADR-TBD | `AppDbContext` (no GQF on Tenant, etc.) | `Tests.Security/MultiTenancy/CrossTenantEntitiesTests` (Phase A) |
| ARCH-06 | ADR-TBD | `TenantStatus` enum + login guard | `Tests.Security/TenantLifecycle/SuspendedAndDeletedTenantTests` (Phase A, negative) + `Tests.Security/Identity/GoldenPathLoginTests.{PasswordSignInAsync_ActiveTenant_SucceedsWithCorrectCredentials, TenantStatus_Transition_AffectsLoginBehavior}` (Phase C) — SF-003 fixed |
| ARCH-07 | ADR-TBD | (background services pending) | TBD |
| ARCH-08 | ADR-TBD | `RedisCacheService` (key prefix) | (T3 / scale-out sprint) |
| ARCH-09 | ADR-TBD | SignalR hub method guards | (T5 — widget framework) |
| ARCH-10 | ADR-TBD | `IBlobStorage` impl (pending) | (no impl yet — deferred per DEF-09) |

## Authentication — Web (AUTH-WEB-01..04)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| AUTH-WEB-01 | ADR-TBD | `Program.cs` Identity + cookie options | `Tests.Security/Smoke/WebFixtureSmokeTests` (Phase C — smoke verifies pipeline) |
| AUTH-WEB-02 | ADR-TBD | `IdentityAuthService.CompleteSignInAsync` (claims) | `Tests.Security/Identity/GoldenPathLoginTests.CompleteSignInAsync_ValidUser_MaterialisesClaimsCorrectly` (Phase C) |
| AUTH-WEB-03 | ADR-TBD | `IdentityAuthService.SignOutAsync` + SecurityStamp | (T2 / T4 — force-logout flow planned) |
| AUTH-WEB-04 | ADR-012 | `IdentityAuthService` LICENSE-SESSION pre-check | `Tests.Security/Identity/GoldenPathLoginTests.PasswordSignInAsync_{NoLimit, WithinLimit, SameIp, ExpiredSession, RevokedSession}_*` (Phase C — 5 golden-path tests) |

## Authentication — API (AUTH-API-01..06)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| AUTH-API-01 | ADR-TBD | `Api/Program.cs` JwtBearer | (covered via JtiRevocationTests pipeline) |
| AUTH-API-02 | ADR-TBD | `Infrastructure/Security/TokenService.IssueAccessToken` | `Tests.Security/ApiAuth/RefreshTokenRotationTests` |
| AUTH-API-03 | ADR-TBD | `Infrastructure/Security/TokenService.IssueRefreshToken` + cookie | `Tests.Security/ApiAuth/RefreshTokenRotationTests` |
| AUTH-API-04 | ADR-TBD | `TokenService.RotateAsync` + reuse-detection | `Tests.Security/ApiAuth/RefreshTokenRotationTests` (5 tests) |
| AUTH-API-05 | ADR-TBD | `TokenService.RevokeJtiAsync` (Redis) | `Tests.Security/ApiAuth/JtiRevocationTests` (5 tests; SF-004 fixed) |
| AUTH-API-06 | ADR-TBD | RSA key configuration | (T2 — key-rotation tests planned) |

## Password policy (PWD-01..05)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

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
| AUD-01 | ADR-TBD | `AuditBehavior` + `AuditService` (separate DbContext, fire-and-forget) | `Tests.Security/Authorization/PermissionGroupAuditTests` (4 tests — PermissionGroup.Created/Updated/Deleted/PermissionChanged) |

## Dashboards (DASH-01..05)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## Widget catalogue (WGT-01..04)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## User management (USR-01..14)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

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

After T1 Phase A + Phase B + Phase C + T4 (commits `ca0ccd9` + `b846f1b` + `77e1537` + T4):

- **Requirements with regression-safety tests:** ARCH-01, ARCH-04 (positive + negative), ARCH-05, ARCH-06 (positive + negative + transition), AUTH-WEB-01, AUTH-WEB-02, AUTH-WEB-04, AUTH-API-02..05, BFP-01..04, LICENSE-SESSION (positive + negative), PG-01, PG-03, PG-04, PG-06, PG-07, AUD-01
- **Phase A tests:** 32 passing
- **Phase B tests:** 30 passing
- **Phase C tests:** 18 passing
- **T4 Authorization tests:** 46 passing (9 test files in Authorization/)
- **Total `Tests.Security` count:** 126+ passing
- **`CcDashboard.Infrastructure` line coverage:** ~87% (T1 baseline)

Remaining sections to be populated by T2..T5:
- PWD-01..05 (T1 left unscoped; consider T2)
- 2FA-01..07, SSO-01..04 (T2 / future)
- AUTH-WEB-03 (force-logout / SecurityStamp) — T2
- AUTH-API-01, AUTH-API-06 (JWT issuance pipeline / RSA key rotation) — T2
- PG-02, PG-05 (T4+ — additional PG semantics)
- AUD-02..08 (audit retention, export, etc.) — future
- DASH-01..05 (T5)
- WGT-01..04 (T5)
- ARCH-02, ARCH-03, ARCH-07..10 (T3 / T5)
- USR-01..14, I18N-01..06, NFR, DEPLOY, CODE, DATA (TBD)

Updated: 2026-05-25 (T4 — PG authorization semantics completed)
