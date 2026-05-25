# Sprint T3: Multi-tenancy integration — Gap Analysis

**Status:** ✅ CLOSED  
**Commit:** Pending (gap-analysis complete; awaiting commit)  
**Date:** 2026-05-25  
**Tests added:** 36 new test cases (6 files)  
**Tests.Security total:** 168 + 36 = 204 passing  
**Solution total:** 285 passing (72 Unit + 1 Integration + 8 Architecture + 204 Security)  
**Production code changes:** 1 fix (TokenService NotBefore — see below)  
**Security findings:** None (OQ-1 resolved — GQF already present on all junction tables)

---

## DoD Checklist

| DoD | Description | Status | Evidence |
|---|---|---|---|
| DoD-1 | ≥28 passing tests across T3 clusters | ✅ 36 test cases | See test count per file below |
| DoD-2 | NGC entity GQF isolation (5 entities) | ✅ 5 tests | `NgcIsolationTests.cs` lines 18–116 |
| DoD-3 | Junction table GQF audit; SF-008 if gap | ✅ 3 tests; **no SF-008** (GQF already present) | See OQ-1 resolution |
| DoD-4 | TenantResolutionMiddleware (4+ unit tests) | ✅ 5 tests | `TenantResolutionTests.cs` |
| DoD-5 | Password policy PWD-01..05 (8+ tests) | ✅ 8 test cases | `PasswordPolicyTests.cs` |
| DoD-6 | Redis key prefix ARCH-08 (3+ tests) | ✅ 4 tests | `RedisKeyPrefixTests.cs` |
| DoD-7 | JWT claims AUTH-API-01 (4+ tests) | ✅ 5 tests | `JwtClaimsTests.cs` |
| DoD-8 | Cross-tenant write protection (4+ tests) | ✅ 6 tests | `ConfigWriteProtectionTests.cs` |
| DoD-9 | Traceability matrix updated | ✅ | `docs/traceability-matrix.md` (this session) |
| DoD-10 | All tests pass; 0 regressions | ✅ PASS | 285/285 tests passing (verified on dev machine) |

---

## Test count per file

| File | Tests | DoD | Requirements |
|---|---|---|---|
| `MultiTenancy/NgcIsolationTests.cs` | 8 | DoD-2 (5) + DoD-3 (3) | ARCH-01 |
| `MultiTenancy/TenantResolutionTests.cs` | 5 | DoD-4 | ARCH-03 |
| `PasswordPolicy/PasswordPolicyTests.cs` | 8 (6 [Fact] + 1 [Theory] ×4) | DoD-5 | PWD-01..05 |
| `Infrastructure/RedisKeyPrefixTests.cs` | 4 | DoD-6 | ARCH-08 |
| `Authentication/JwtClaimsTests.cs` | 5 | DoD-7 | AUTH-API-01 |
| `Authentication/ConfigWriteProtectionTests.cs` | 6 | DoD-8 | ARCH-01, PG-04 |
| **Total** | **36** | | |

---

## Open questions resolved

### OQ-1: NGC junction table GQF gap
**Finding:** GQF IS present on all three junction tables in `AppDbContext.OnModelCreating`:
- `NgcSupergroupAgentgroup` — line 322: `HasQueryFilter(x => x.TenantId == tenantContext.TenantId)`
- `NgcBusinessUnitQueueClassification` — line 298: `HasQueryFilter(x => x.TenantId == tenantContext.TenantId)`
- `NgcBusinessUnitSupergroup` — line 310: `HasQueryFilter(x => x.TenantId == tenantContext.TenantId)`

**Decision:** No SF-008. T3 DoD-3 tests verify the existing GQF is correct.

### OQ-2: RtsGridMetric cross-tenant intentional?
**Finding:** Confirmed intentional — `RtsGridMetric` has no `TenantId` column and is
platform-wide (cross-tenant entity per ARCH-05). Verified by existing `CrossTenantEntitiesTests`
(committed T1A, `ca0ccd9`). No gap.

### OQ-3: TokenService.GenerateAccessToken signature
**Finding:** Method is `CreateTokenPairAsync(userId, tenantId, role, pgId, ipAddress, userAgent)`
— accepts parameters directly without requiring an `ApplicationUser` instance.
Tests in `JwtClaimsTests.cs` use this signature; `[Collection("Postgres")]` kept for
fixture access to `TenantAId` / `PgAId` / `PlatformTenantId` constants.

---

## Security findings

None. OQ-1 was expected to be the SF-008 candidate; resolved as non-gap.  
Running security finding count remains at **SF-007** (from T2).

---

## Cross-tenant write protection — architecture note (DoD-8)

`SaveSiteCommandHandler` and `SaveBusinessUnitCommandHandler` derive TenantId exclusively
from `ICurrentUserAccessor.TenantId` — not from the incoming request DTO. This means:

- A user in tenant A cannot write data with tenant B's TenantId: the handler always stamps
  the row with the caller's tenant.
- Cross-tenant update attempts on existing records fail at repository level:
  `GetByIdAsync(id, tenantId)` returns `null` for foreign-tenant records (GQF isolation),
  causing `Result.Failure("... not found.")`.
- No additional authorization check is needed beyond the GQF — the architecture enforces
  it structurally.

`ConfigWriteProtectionTests.cs` tests both paths: (1) create always stamps caller's TenantId,
(2) update foreign-tenant record returns not-found.

---

## Production code changes

| File | Change | Reason |
|---|---|---|
| `TokenService.cs` (line 96) | Added `NotBefore = now` to `SecurityTokenDescriptor` | JWT library defaults `NotBefore` to `DateTime.UtcNow` if unset; test using mock clock failed with "Expires must be after NotBefore". Fix ensures both nbf and exp use the same time source (`IDateTimeProvider`). |
| `Tests.Security.csproj` | Added `NSubstitute` package | Required by unit tests (TenantResolutionTests, JwtClaimsTests, ConfigWriteProtectionTests) |

## Process deviations

None in this sprint. T3 executed cleanly:
- All 6 test files created without truncation
- Production code fix was minimal (1 line) and fixes a testability bug, not a behavioral one

---

## Known limitations carried forward

- **PWD-05 redirect (Blazor):** Only service-layer `MustChangePasswordAt` flag is tested.
  Blazor page redirect enforcement requires WAF — deferred per T3 brief §4.
- **ARCH-02 (TenantSwitcher):** Blazor UI component, deferred.
- **ARCH-07 (IHostedService TenantId):** Complex lifecycle, deferred.
- **Junction table PK design:** `NgcBusinessUnitSupergroup` PK is `(BusinessUnitId, SupergroupId)`
  without TenantId. Tests use separate BU/SG pairs per tenant. Legacy schema decision, not a gap.

---

## Next sprint

**T5** — Widget framework (~30 tests). B1 #11 unblocked T5 Phase B.
Confirmed sequence: T3 → T5.
