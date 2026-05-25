# Sprint T1 — Phase C Gap Analysis

**Sprint:** T1 (Security & Multi-Tenancy)  
**Phase:** C — Golden-Path Auth Tests via WebApplicationFactory  
**Date:** 2026-05-25  
**Author:** Claude (AI assistant)

---

## Executive Summary

Phase C completed all DoD items. WebFixture using `WebApplicationFactory<Program>` with Testcontainers
now enables full ASP.NET Core auth pipeline testing. All 8 previously skipped tests have been
migrated to `GoldenPathLoginTests` and pass. Zero [Skip] attributes remain in Tests.Security.

---

## DoD Completion Status

| DoD | Requirement | Status | Evidence |
|-----|-------------|--------|----------|
| 13 | WebFixture lands and is reused | ✅ DONE | `Fixtures/WebFixture.cs` with `[Collection("Web")]` |
| 14 | Un-skip 3 Phase A tests | ✅ DONE | Migrated to `GoldenPathLoginTests` |
| 15 | Un-skip 5 Phase B LicenseSession tests | ✅ DONE | Migrated to `GoldenPathLoginTests` |
| 16 | AUTH-WEB-02 claims materialization test | ✅ DONE | `CompleteSignInAsync_ValidUser_MaterialisesClaimsCorrectly` |
| 17 | Zero remaining [Skip] in Tests.Security | ✅ DONE | `grep -r "Skip" tests/CcDashboard.Tests.Security` returns no matches |
| 18 | Coverage ≥80% on Infrastructure | ✅ DONE | 87.88% line coverage |
| 19 | Gap analysis filed + commit | ✅ DONE | This document |

---

## Architecture Decisions

### MC-C1: WebApplicationFactory composition
**Choice:** `WebApplicationFactory<Program>` with `ConfigureWebHost` overriding data-layer registrations.

**Rationale:** Tests against real ASP.NET Core pipeline with production middleware order.
Only data-layer (Postgres/Redis) swapped to Testcontainers. No re-implementation of auth handlers.

### MC-C2: Cookie handling
**Choice:** `CreateClient` with `HandleCookies=true` (default).

**Rationale:** Cookie jar auto-managed by HttpClient; no manual cookie propagation needed.

### MC-C3: Secure cookie override
**Choice:** `PostConfigure<CookieAuthenticationOptions>` sets `SecurePolicy = None` for HTTP tests.

**Rationale:** WebApplicationFactory uses HTTP by default. Production cookie policy (`Secure=Always`)
would reject cookies over non-HTTPS test connections.

### MC-C4: Fixture composition
**Choice:** New `WebFixture` alongside existing `PostgresFixture`/`RedisFixture`.

**Rationale:** Separation of concerns — unit-style tests continue using lightweight fixtures;
integration tests use WebFixture with full WAF. Both share xUnit `ICollectionFixture` pattern.

---

## Test Inventory

### New Tests (GoldenPathLoginTests)

| Test | Requirement | Description |
|------|-------------|-------------|
| `Login_DiagnosticTest` | — | Smoke test verifying full login flow |
| `PasswordSignInAsync_CorrectTenant_ReturnsSuccess` | ARCH-04 | Phase A positive path |
| `PasswordSignInAsync_WrongTenant_DoesNotRedirectToScreens` | ARCH-04, BFP-03 | Contrast test |
| `PasswordSignInAsync_ActiveTenant_SucceedsWithCorrectCredentials` | ARCH-06 | Phase A positive path |
| `TenantStatus_Transition_AffectsLoginBehavior` | ARCH-06 | Phase A transition test |
| `CompleteSignInAsync_ValidUser_MaterialisesClaimsCorrectly` | AUTH-WEB-02 | Claims verification |
| `Login_WithWrongPassword_DoesNotRedirect` | BFP-03 | Negative path |
| `Login_NonExistentUser_DoesNotRedirect` | BFP-03 | Negative path |
| `PasswordSignInAsync_NoLimit_AllowsMultipleConnections` | AUTH-WEB-04 | LICENSE-SESSION unlimited |
| `PasswordSignInAsync_WithinLimit_AllowsLogin` | AUTH-WEB-04 | LICENSE-SESSION within limit |
| `PasswordSignInAsync_SameIp_AllowsUnlimitedConnections` | AUTH-WEB-04 | LICENSE-SESSION same IP |
| `PasswordSignInAsync_ExpiredSession_NotCounted` | AUTH-WEB-04 | LICENSE-SESSION expired |
| `PasswordSignInAsync_RevokedSession_NotCounted` | AUTH-WEB-04 | LICENSE-SESSION revoked |

### Retired Skipped Tests

The following tests were removed as stubs; their functionality is now covered by GoldenPathLoginTests:

- `TenantMismatchLoginTests.PasswordSignInAsync_CorrectTenant_ReturnsSuccess`
- `SuspendedAndDeletedTenantTests.PasswordSignInAsync_ActiveTenant_SucceedsWithCorrectCredentials`
- `SuspendedAndDeletedTenantTests.TenantStatus_Transition_AffectsLoginBehavior`
- `LicenseSessionTests.PasswordSignInAsync_NoLimit_AllowsMultipleConnections`
- `LicenseSessionTests.PasswordSignInAsync_WithinLimit_AllowsLogin`
- `LicenseSessionTests.PasswordSignInAsync_SameIp_AllowsUnlimitedConnections`
- `LicenseSessionTests.PasswordSignInAsync_ExpiredSession_NotCounted`
- `LicenseSessionTests.PasswordSignInAsync_RevokedSession_NotCounted`

---

## WebFixture Implementation

### Key Components

```
tests/CcDashboard.Tests.Security/
├── Fixtures/
│   └── WebFixture.cs          # NEW: WAF-based fixture
├── Smoke/
│   └── WebFixtureSmokeTests.cs # NEW: 5 smoke tests
└── Identity/
    └── GoldenPathLoginTests.cs # NEW: 13 golden-path tests
```

### WebFixture Capabilities

1. **Testcontainers:** PostgreSQL 16 + Redis 7 spun up per test collection
2. **Dual DbContext migration:** Both `AppDbContext` and `AuditDbContext` migrated
3. **LoginAsync helper:** Extracts antiforgery token, handles Blazor SSR `_handler` field
4. **IP simulation:** X-Forwarded-For header for LICENSE-SESSION tests
5. **Session manipulation:** `CreateUserSessionAsync`, `ClearUserSessionsAsync`
6. **Settings control:** `SetMaxConcurrentConnectionsAsync`

### Test Isolation

Each test in GoldenPathLoginTests:
- Resets `MaxConcurrentConnections` to 0 (unlimited) via `ResetSessionStateAsync()`
- Clears user sessions before session-limit tests
- Uses `IAsyncLifetime.DisposeAsync` for cleanup after all tests

---

## Production Code Changes

### Minimal changes required:

1. **`Program.cs`** — Added `public partial class Program { }` at end
   - Required for `WebApplicationFactory<Program>` to access top-level statement entry point
   - Standard Microsoft pattern per [integration testing docs](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests)

2. **`DatabaseInitializer.cs`** — Changed `InitializeAsync` to `virtual`
   - Allows `NoOpDatabaseInitializer` to override in tests
   - Prevents duplicate migrations when WebFixture has already migrated

---

## Coverage Report

```
Total tests: 79
Passed: 79
Skipped: 0

Infrastructure line coverage: 87.88%
```

---

## Known Limitations

1. **X-Forwarded-For simulation:** LICENSE-SESSION tests use header injection, not actual network
   isolation. Real multi-IP testing would require more complex test infrastructure.

2. **Cookie detection for session limit:** `IsSessionLimitExceeded` detection relies on response
   content containing "SessionLimitExceeded" text. If UI changes error messaging, detection may fail.

3. **Parallel test execution:** Tests in `[Collection("Web")]` share a single WebFixture instance.
   Tests must clean up shared state (TenantSettings, UserSessions) to avoid interference.

---

## Recommendations for Future Sprints

1. **Add more golden-path scenarios:** 2FA flow, password change flow, SSO callback
2. **Refactor cleanup pattern:** Consider using xUnit `IClassFixture` per-class isolation
3. **Add API tests:** WebFixture can be extended for REST API auth (JWT Bearer)
4. **Performance baseline:** Record login latency under load for regression detection

---

## Commit Message

```
feat(test): Phase C — WebFixture golden-path auth tests (DoD-13..19)

- Add WebFixture with WebApplicationFactory<Program> + Testcontainers
- Add 13 GoldenPathLoginTests covering ARCH-04, ARCH-06, AUTH-WEB-02, AUTH-WEB-04
- Migrate 8 skipped Phase A/B tests to WebFixture implementation
- Remove [Skip] stubs — zero skipped tests remain in Tests.Security
- Infrastructure coverage: 87.88% (≥80% requirement met)

Closes: Sprint T1 Phase C
```
