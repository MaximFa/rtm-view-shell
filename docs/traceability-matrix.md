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

## Authentication — API (AUTH-API-01..06)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## Password policy (PWD-01..05)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

## Brute-force protection (BFP-01..04)

| Req ID | ADR | Implementation | Test |
|---|---|---|---|

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

- **Total numbered requirements:** TBD
- **With ADR:** TBD
- **Implemented:** TBD
- **Tested:** TBD
- **Coverage (tested / total):** TBD %

Updated: YYYY-MM-DD
