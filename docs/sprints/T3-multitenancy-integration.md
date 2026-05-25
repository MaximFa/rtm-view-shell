# Sprint T3: Multi-tenancy integration tests

**Estimate:** ~3–4 h Claude Code (single phase, ~30 tests)
**Unblocked by:** B1 #11 (BackendEmulationDbContext available in PostgresFixture as `BeDb`)
**Unblocks:** T5 (clears the multi-tenancy coverage gap before widget framework)

---

## 1. Scope

### Why T3 exists

T1 covered multi-tenancy isolation for **shell-owned tables** (Users, Dashboards,
PermissionGroups). T3 closes the remaining gaps:

- **Backend-owned reference data** (NGC_* entities) — GQF correctness, including
  junction tables that may lack coverage
- **TenantResolutionMiddleware** (ARCH-03) — subdomain → TenantId pipeline
- **Password policy** (PWD-01..05) — deferred from T1, currently untested
- **Redis key prefix** (ARCH-08) — tenant data isolation in cache
- **JWT claims completeness** (AUTH-API-01) — correct claim set on token issuance
- **Cross-tenant write protection** on configuration commands (NGC CRUD)

### In scope

| Cluster | Requirements |
|---|---|
| NGC reference data isolation | ARCH-01 (GQF on NgcSite/BU/Supergroup/Queue/AgentGroup), junction tables (potential SF gap) |
| Tenant resolution | ARCH-03 (TenantResolutionMiddleware: valid slug, unknown, suspended, deleted) |
| Password policy | PWD-01 (min 12), PWD-02 (complexity), PWD-03 (PBKDF2 iterations), PWD-04 (history, last 10), PWD-05 (forced change) |
| Redis isolation | ARCH-08 (key prefix `{tenantId}:`) |
| JWT claims | AUTH-API-01 (sub, tenant_id, role, pg_id, jti, iat, exp, iss, aud all present and correct) |
| Config write protection | Cross-tenant write rejection on SaveSite/SaveBU/SaveSupergroup/SaveRtsGridMetric |

### Explicitly out of scope

- ARCH-02 (TenantSwitcher UI component) — Blazor E2E, deferred
- ARCH-07 (background services TenantId setup) — complex lifecycle, separate sprint
- ARCH-09 (SignalR hub TenantId guard) — T5
- ARCH-10 (IBlobStorage tenant isolation) — no impl yet (DEF-09)
- 2FA flows (2FA-01..07) — deferred
- SSO flows (SSO-01..04) — deferred
- Full NGC CRUD lifecycle tests — integration contract tests, out of security scope

---

## 2. Architectural micro-choices (gate — sign before coding)

All T1 baseline choices inherited unchanged (Testcontainers PostgreSQL, real Identity,
hybrid audit assertion, `[Trait("Req","...")]`, shared fixtures). Only T3-specific choices:

### MC-T3-1. Password policy tests — integration or unit?
- **A. Integration** (real DB, Testcontainers): required for PWD-04 (history stored in
  `identity.user_password_history`); consistent with T1 pattern
- **B. Mixed**: PWD-01/02 validator unit tests + PWD-03/04/05 integration tests
- **Recommendation: A** — keeps fixture reuse simple; PWD-03 (hash iterations) needs
  real `UserManager` to verify. Mark as `[Trait("Req","PWD-01")]` etc.

`Decision: A — Integration (Testcontainers + real UserManager)`

### MC-T3-2. TenantResolutionMiddleware tests — unit or WAF?
- **A. Unit** (inject `HttpContext` mock, test middleware in isolation): fast, no WAF
  overhead; middleware is ~40 lines and has no complex DI
- **B. WAF** (full WebApplicationFactory): heavier but tests the full pipeline
- **Recommendation: A** — middleware has a clean `InvokeAsync(HttpContext)` signature;
  unit test is sufficient and runs 10× faster

`Decision: A — Unit test (InvokeAsync isolation)`

### MC-T3-3. JWT claims test approach — unit or integration?
- **A. Unit** (call `TokenService.GenerateAccessToken(user, tenant)` directly): tests
  the claim set without HTTP round-trip; fast
- **B. Integration** (POST /v1/auth/login, inspect response token): slower but tests
  real pipeline
- **Recommendation: A** — AUTH-API-01 is about claim *content*, not HTTP mechanics;
  that's already covered by T1 AUTH-API-02 tests

`Decision: A — Unit (TokenService directly)`

### MC-T3-4. NGC junction tables — investigate GQF gap before or during sprint?
- **A. Pre-sprint audit** (read `AppDbContext.OnModelCreating` for junction table
  configs, confirm presence/absence of GQF before coding tests)
- **B. Test-driven discovery** (write tests, see what fails)
- **Recommendation: A** — executor should read AppDbContext junction table config
  (NgcSupergroupAgentgroup, NgcBusinessUnitQueueClassification,
  NgcBusinessUnitSupergroup) in §5 key-file pass, document finding in DoD-3 assertion.
  If gap found → fix + tag as SF-008

`Decision: A — Pre-sprint GQF audit as first task`

### MC-T3-5. BeDb seeding pattern for NGC data
- **A. Use `PostgresFixture.CreateBackendEmulationDbContext()`** to seed NgcSite/BU/
  Supergroup rows; use `AppDbContext` (via `PostgresFixture.Db`) for querying with GQF
- **B. Seed directly via raw SQL** (INSERT INTO "NGC_*")
- **Recommendation: A** — `BeDb` is the purpose of B1 #11; this validates the fixture
  works as designed

`Decision: A — BeDb for seeding, AppDbContext for GQF assertion`

---

## 3. Definition of Done

- **DoD-1: Test count.** ≥ **28 passing tests** in `Tests.Security/` across T3
  clusters. New folder structure: `MultiTenancy/NgcIsolationTests.cs`,
  `MultiTenancy/TenantResolutionTests.cs`, `PasswordPolicy/PasswordPolicyTests.cs`,
  `Infrastructure/RedisKeyPrefixTests.cs`, `Authentication/JwtClaimsTests.cs`.

- **DoD-2: NGC entity GQF isolation.** For each of `NgcSite`, `NgcBusinessUnit`,
  `NgcSupergroup`, `NgcQueue`, `NgcAgentGroup`: row written in tenant A context is NOT
  visible when queried in tenant B context. ≥ 5 tests; covers **ARCH-01** extension.
  Use `BeDb` (BackendEmulationDbContext) to seed, `AppDbContext` with tenant switch
  to assert isolation.

- **DoD-3: NGC junction table GQF audit.** `NgcSupergroupAgentgroup`,
  `NgcBusinessUnitQueueClassification`, `NgcBusinessUnitSupergroup` — each tested for
  cross-tenant isolation. If any junction table lacks GQF → fix and tag **SF-008**
  (or SF-009 etc. if multiple). ≥ 3 tests.

- **DoD-4: TenantResolutionMiddleware.** ≥ 4 unit tests:
  (a) known slug resolves to correct `TenantId` in `ITenantContext`;
  (b) unknown slug → `NextDelegate` not called, redirect/error response;
  (c) `Suspended` tenant → `403` or appropriate error;
  (d) `Deleted` tenant → treated as unknown. Covers **ARCH-03**.

- **DoD-5: Password policy.** Integration tests using real `UserManager`:
  (a) PWD-01: password shorter than `PasswordMinLength` rejected;
  (b) PWD-02: missing uppercase / lowercase / digit / special char — each rejected
  (parametrised, 4 cases);
  (c) PWD-03: `PasswordHasherOptions.IterationCount` is ≥ 100000 (config assertion);
  (d) PWD-04: reuse of one of last 10 passwords rejected;
  (e) PWD-05: `MustChangePasswordAt` set on user creation; login redirects before
  accessing other pages.
  ≥ 8 tests. Covers **PWD-01..05**.

- **DoD-6: Redis key prefix.** ≥ 3 tests verifying `RedisCacheService` (or equivalent)
  writes keys with prefix `"{tenantId}:{namespace}:{key}"` pattern; key written for
  tenant A is NOT accessible from tenant B namespace. Use `RedisFixture` (existing
  from T1). Covers **ARCH-08**.

- **DoD-7: JWT claims.** ≥ 4 tests calling `TokenService.GenerateAccessToken` directly:
  (a) access token contains `sub`, `tenant_id`, `role`, `permission_group_id`, `jti`;
  (b) `exp` is NOW + 15 min (use `IDateTimeProvider` mock);
  (c) `iss` and `aud` match configuration values;
  (d) role claim matches the user's `ApplicationRole`. Covers **AUTH-API-01**.

- **DoD-8: Cross-tenant write protection.** ≥ 4 tests: user from tenant A invoking
  `SaveSiteCommand` / `SaveBusinessUnitCommand` with a `TenantId` belonging to tenant
  B → rejected (ForbiddenException or equivalent). Tests invoke MediatR handlers
  directly with spoofed `ICurrentUserAccessor`. Covers **ARCH-01** + **[PG-04]** 
  enforcement at Application layer.

- **DoD-9: Traceability matrix updated.** `docs/traceability-matrix.md` rows for
  ARCH-03, ARCH-08, AUTH-API-01, PWD-01..05 populated with test file references.

- **DoD-10: All tests pass, no regressions.** `dotnet test CcDashboard.sln` — all
  247 + new T3 tests pass; 0 build errors; 0 new warnings.

---

## 4. Known limitations

- **ARCH-02 (TenantSwitcher):** Blazor UI component; no server-side logic to unit
  test in isolation. Deferred.
- **ARCH-07 (IHostedService TenantId):** requires mock background service lifecycle;
  complex; deferred.
- **PWD-05 redirect enforcement:** testing the Blazor redirect (after `MustChangePasswordAt`
  check) requires WAF. DoD-5(e) tests only the service-layer flag — not the Blazor
  page redirect. Note this as ⚠ in gap analysis.
- **BeDb migrations vs AppDbContext:** `PostgresFixture` does NOT run
  `BackendEmulationDbContext` migrations (comment in `PostgresFixture.cs` line 97–99).
  Backend tables exist from `AppDbContext` migrations. `BeDb` is used for seeding only.

---

## 5. Open questions

- **OQ-1:** Do `NgcBusinessUnitQueueClassification` and `NgcSupergroupAgentgroup`
  have GQF in `AppDbContext`? (Read `AppDbContext.OnModelCreating` ~line 261+ before
  coding DoD-3.) If no → SF-008 candidate.
- **OQ-2:** `RtsGridMetric` — is this intentionally cross-tenant (no TenantId) or a
  gap? (Check entity definition; T1 DoD-3 treats `RTSGrid_Metric` as cross-tenant. 
  Confirm in DoD-2 — no test needed if intentional.)
- **OQ-3:** `TokenService.GenerateAccessToken` — does it accept `ApplicationUser` +
  `Tenant` directly, or go through a higher-level method? Read
  `src/CcDashboard.Infrastructure/Security/TokenService.cs` before writing DoD-7 tests.

---

## 6. Implementation notes

### Key files to read before writing any test

```
src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs          # GQF config for ALL entities
src/CcDashboard.Infrastructure/Security/TokenService.cs              # JWT claims (DoD-7)
src/CcDashboard.Web/Middleware/TenantResolutionMiddleware.cs         # DoD-4
src/CcDashboard.Application/Commands/Configuration/ConfigurationCommands.cs  # DoD-8
src/CcDashboard.Infrastructure/Identity/IdentityAuthService.cs      # PWD-04/05 enforcement
src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs # PWD-03 config
src/CcDashboard.Infrastructure/Caching/RedisCacheService.cs          # ARCH-08 key pattern
tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs        # BeDb.CreateBackendEmulationDbContext()
```

### Recommended file structure

```
tests/CcDashboard.Tests.Security/
  MultiTenancy/
    NgcIsolationTests.cs          # DoD-2 + DoD-3
    TenantResolutionTests.cs      # DoD-4
  PasswordPolicy/
    PasswordPolicyTests.cs        # DoD-5
  Infrastructure/
    RedisKeyPrefixTests.cs        # DoD-6
  Authentication/
    JwtClaimsTests.cs             # DoD-7
    ConfigWriteProtectionTests.cs # DoD-8
```

### Approximate effort sizing

| Cluster | Tests | h |
|---|---|---|
| NgcIsolationTests | 8 | 1.0 |
| TenantResolutionTests | 4 | 0.5 |
| PasswordPolicyTests | 8 | 0.75 |
| RedisKeyPrefixTests | 3 | 0.5 |
| JwtClaimsTests | 4 | 0.5 |
| ConfigWriteProtectionTests | 4 | 0.5 |
| Gap analysis + traceability | — | 0.25 |
| **Total** | **~31** | **~4 h** |

### BeDb seeding pattern (per MC-T3-5)

```csharp
// In test setup — seed NGC data via BeDb, query via AppDbContext with tenancy
await using var beDb = _postgres.CreateBackendEmulationDbContext();
beDb.NgcSites.Add(new NgcSite { SiteId = "S1", TenantId = tenantA.Id, SiteName = "Site A" });
beDb.NgcSites.Add(new NgcSite { SiteId = "S2", TenantId = tenantB.Id, SiteName = "Site B" });
await beDb.SaveChangesAsync();

// Assert GQF: tenant A context sees only S1
var dbA = _postgres.CreateAppDbContextForTenant(tenantA.Id);
var sites = await dbA.NgcSites.ToListAsync();
Assert.Single(sites);
Assert.Equal("S1", sites[0].SiteId);
```

---

## 7. Hand-off to Claude Code

```
Read: docs/sprints/T3-multitenancy-integration.md

§2 micro-choices are signed:
- MC-T3-1 = A (integration tests for all PWD)
- MC-T3-2 = A (unit tests for TenantResolutionMiddleware)
- MC-T3-3 = A (unit tests for JWT claims via TokenService directly)
- MC-T3-4 = A (pre-sprint GQF audit as first task in implementation)
- MC-T3-5 = A (BeDb for seeding, AppDbContext for GQF assertion)

Implement Sprint T3 per the brief. DoD-1 through DoD-10 are the
acceptance criteria.

Working agreement:
1. Read ALL files listed in §6 before writing any test code.
2. First task: OQ-1 audit — read AppDbContext.OnModelCreating for
   NgcSupergroupAgentgroup, NgcBusinessUnitQueueClassification,
   NgcBusinessUnitSupergroup GQF presence. Document finding before
   proceeding. If gap found: fix production code and tag SF-008.
3. [Trait("Req", "ARCH-01")] (or relevant req ID) on EVERY test.
4. Diagnostics first, fix later — expected vs actual + root cause
   before any code change.
5. Do not touch existing test files (except PostgresFixture.cs if
   BeDb seeding helpers are needed).
6. Use Python read→modify→write for any file with ≥2 edits
   (CLAUDE.md §0.3). After each write: tail -3 + wc -l via bash.
7. Do not commit until ALL DoD-1..10 are satisfied.

On completion:
- Write gap-analysis table as FIRST close-out artefact
  (docs/sprints/T3-gap-analysis.md) before traceability update.
- Commit message: "test(Sprint T3): multi-tenancy integration — NGC
  isolation, tenant resolution, PWD policy, Redis prefix, JWT claims"
```

---

## 8. Sprint close-out checklist

- [ ] Gap analysis written (`docs/sprints/T3-gap-analysis.md`)
- [ ] Traceability matrix updated (ARCH-03, ARCH-08, AUTH-API-01, PWD-01..05)
- [ ] Security findings logged if any SF-00N found
- [ ] Process deviations logged if any PD-00N found
- [ ] PROJECT_STATUS.md updated (T3 → ✅ CLOSED)
- [ ] MEMORY.md sprint inventory updated
