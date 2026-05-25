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
| ARCH-01 | ADR-TBD | `AppDbContext.OnModelCreating` (GQF) | `Tests.Architecture/MultiTenancyTests` |
| ARCH-02 | ADR-TBD | `Admin/TenantSwitcher.razor` + audit | `Tests.Security/TenantSwitchAuditTests` |
| ARCH-03 | ADR-TBD | `TenantResolutionMiddleware` | `Tests.Integration/TenantResolutionTests` |
| ARCH-04 | ADR-TBD | `IdentityAuthService.SignInAsync` | `Tests.Security/CrossTenantLoginTests` |
| ARCH-05 | ADR-TBD | `AppDbContext` (no GQF on Tenant, etc.) | `Tests.Architecture/CrossTenantEntitiesTests` |
| ARCH-06 | ADR-TBD | `TenantStatus` enum + login guard | `Tests.Security/SuspendedTenantTests` |
| ARCH-07 | ADR-TBD | (background services pending) | TBD |
| ARCH-08 | ADR-TBD | `RedisCacheService` (key prefix) | `Tests.Architecture/RedisKeyPrefixTests` |
| ARCH-09 | ADR-TBD | SignalR hub method guards | `Tests.Security/SignalRHubTests` |
| ARCH-10 | ADR-TBD | `IBlobStorage` impl (pending) | TBD |

## Authentication — Web (AUTH-WEB-01..03)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|
| AUTH-WEB-01 | ADR-TBD | `Program.cs` Identity + cookie options | (covered via integration smoke; T1 Phase C planned) |
| AUTH-WEB-02 | ADR-TBD | `IdentityAuthService.CompleteSignInAsync` (claims) | (Phase C — WAF) |
| AUTH-WEB-03 | ADR-TBD | `IdentityAuthService.SignOutAsync` + SecurityStamp | (Phase C — WAF) |

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
| LICENSE-SESSION (rejection) | ADR-012 | `IdentityAuthService` session-limit guard | `Tests.Security/Licensing/LicenseSessionTests` (1 test) |
| LICENSE-SESSION (golden path) | ADR-012 | Same | Phase C — WAF (5 skipped tests) |

## 2FA (2FA-01..07)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## SSO (SSO-01..04)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## Permission Groups (PG-01..07)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## Audit (AUD-01..08)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

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

After T1 Phase A + Phase B (commits `ca0ccd9` + `b846f1b`):

- **Requirements with regression-safety tests:** ARCH-01, ARCH-04, ARCH-06, AUTH-API-02..05, BFP-01..04, LICENSE-SESSION (rejection path)
- **Phase A tests inherited:** 31 passing, 3 skipped
- **Phase B tests added:** 30 passing, 5 skipped
- **Total `Tests.Security` count:** 61 passing, 8 skipped (8 awaiting Phase C / WAF)
- **`CcDashboard.Infrastructure` line coverage:** 86.88%

Remaining sections to be populated by T2..T5:
- PWD-01..05 (T1 left unscoped; consider T2/T4)
- 2FA-01..07, SSO-01..04 (T2 / future)
- PG-01..07 (T4)
- AUD-01..08 (T4)
- DASH-01..05 (T5)
- WGT-01..04 (T5)
- USR-01..14, I18N-01..06, NFR, DEPLOY, CODE, DATA (TBD)

Updated: 2026-05-25 (T1 Phase B close-out)
