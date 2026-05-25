# Sprint T1: Security & cross-tenant isolation tests

**Status:** **Approved — ready for execution** *(all §2 micro-choices signed off 2026-05-17)*
**Window:** TBD (~ 5 working days)
**Owner:** Claude Code (executing per this brief)
**Related ADRs:** ADR-003 (Licensing), ADR-006 (PG model), ADR-007 (DB boundary)
**Related TS sections:** §2.2 Multi-tenancy, §5.1-5.5 Auth & Security, §6 Audit

---

## 1. Scope

### In scope

Replace the `PlaceholderTests.cs` stubs in
`tests/CcDashboard.Tests.Security/` with **real automated tests**
covering the highest-OWASP-risk requirements that currently have
no automated coverage (per `docs/traceability-matrix.md`):

| Cluster | Requirements covered |
|---|---|
| **Multi-tenancy isolation** | ARCH-01 (Global Query Filter), ARCH-04 (TenantMismatch on login), ARCH-05 (cross-tenant entities NOT filtered), ARCH-06 (Suspended / Deleted tenant blocks login), ARCH-08 (Redis key prefix per tenant) |
| **API authentication** | AUTH-API-02 (JWT signature / claims), AUTH-API-03 (refresh-token storage as SHA-256 hash), AUTH-API-04 (refresh-token rotation + reuse detection), AUTH-API-05 (JTI revocation list) |
| **Web authentication** | AUTH-WEB-02 (claims materialisation), AUTH-WEB-03 (logout deletes cookie + invalidates circuit), AUTH-WEB-04 (LICENSE-SESSION pre-condition for Blazor) |
| **Brute-force protection** | BFP-01 (lockout after 5 failures), BFP-02 (rate limit 10/min/IP), BFP-03 (uniform "Invalid credentials" error), BFP-04 (audit subtype on failure) |
| **Licensing enforcement** | AUTH-API-07 (LICENSE-SESSION on refresh-token issue) — paired with AUTH-WEB-04 above |
| **Audit append-only** | AUD-01 (audit write decoupled from business tx), AUD-02 (no UPDATE / DELETE for app role) |

### Explicitly out of scope

- 2FA flows (`2FA-01..07`) — Deferred per DEF-03; skip.
- SSO flows (`SSO-01..04`) — Deferred per DEF-04; skip.
- Password policy enforcement details (`PWD-01..04`) — relies on
  standard Identity defaults; separate small sprint.
- Voluntary Change Password flow (`PWD-06`) — addressed via Forced
  scenario only (per USR-19).
- Widget framework tests (`WGT-*`, `SR-*`) — Sprint T5.
- PG authorisation semantics (`PG-09..12`) — Sprint T4.
- Reference-data admin (`NGC_*` CRUD) — Sprint T3.
- Performance tests, load tests, browser-compat tests.
- Mutation testing.

---

## 2. Architectural micro-choices (gate — answer before coding)

**These must be agreed before any test is written. Each item has a
recommendation; deviation requires justification.**

### MC-1. Database for integration tests

- **A.** Testcontainers PostgreSQL 16 (real Postgres in Docker / Podman).
- **B.** EF Core In-Memory provider.
- **C.** EF Core Sqlite In-Memory provider.

**Recommendation: A (Testcontainers).** Reasons: GQF, `inet` type,
`xmin` concurrency, `jsonb`, `pg_trgm` — all Postgres-specific and
must work in tests for any value to flow from them. EF In-Memory
ignores GQF semantics; Sqlite doesn't support `inet` / `jsonb`
properly. Yes, this needs a working Docker daemon on dev machines
and on CI agents — that's the cost of meaningful tests.

→ **Decision: A — Testcontainers PostgreSQL 16.** Approved 2026-05-17.

### MC-2. Identity stack: real or mocked?

- **A.** Use real `UserManager<ApplicationUser>` /
  `SignInManager<ApplicationUser>` against a Testcontainers DB
  (heavy fixture but accurate).
- **B.** Mock the Identity stack via Moq / NSubstitute (fast but
  asserts only our adapter logic, not Identity semantics).

**Recommendation: A** for the auth-flow tests; **B** for the licensing
gate (`AUTH-WEB-04`, `AUTH-API-07`, `USR-17`) where we test our own
pre-condition logic in isolation. Two fixture classes, both registered
in DI. **No mocking of `UserManager` for tests of `IdentityAuthService`
itself** — that would test the test, not the code.

→ **Decision: A for auth-flow tests; B for licensing-gate tests (hybrid per recommendation).** Approved 2026-05-17.

### MC-3. Audit assertion pattern

- **A.** Read the `audit.audit_logs` table directly after the
  business operation (verifies the actual append-only contract,
  AUD-01 / AUD-02).
- **B.** Replace `IAuditService` with a Moq spy
  (`MockAuditService.Verify(...)`).
- **C.** Hybrid — Moq for ergonomics in unit tests, real DB read
  in `Tests.Security` integration tests.

**Recommendation: C.** Unit tests use Moq spy for ergonomics
(`auditService.Verify(s => s.WriteAsync(It.Is<AuditEntry>(...)),
Times.Once);`). Security tests **read the real table** to verify
append-only and partition behaviour at the same time. This costs
~30% test wall time but catches schema drift.

→ **Decision: C — hybrid (Moq spy in Tests.Unit, real DB read in Tests.Security).** Approved 2026-05-17.

### MC-4. Test naming convention

- **A.** `MethodName_Scenario_ExpectedBehaviour` (e.g.,
  `LoginAsync_TenantSuspended_ReturnsInvalidCredentialsAndAuditsFailure`).
- **B.** Spec-style `Should_emit_TenantMismatch_when_user_tenant_does_not_match_subdomain`.

**Recommendation: A.** Match existing `Tests.Unit/Commands/*Tests.cs`
convention (verified in `SetTenantStatusCommandHandlerTests`). Keep
test names *machine-greppable from a requirement ID*: every test
must include the requirement marker in `[Trait("Req", "ARCH-04")]`
attribute so traceability matrix updates are automated.

→ **Decision: A — `MethodName_Scenario_ExpectedBehaviour` + MANDATORY `[Trait("Req", "...")]` on every test method.** Approved 2026-05-17.

### MC-5. Phase split

- **A.** Single Phase — all clusters in one push.
- **B.** Phase A (tenancy + auth fundamentals: ARCH, AUTH-WEB, AUTH-API),
  Phase B (BFP + LICENSE + audit assertions) with intermediate commit.

**Recommendation: B.** First phase yields a working test fixture
+ at least 25 tests, reviewable midway. Second phase adds the rest
without bottling up risk. Each phase ends with its own commit per the
sprint discipline.

→ **Decision: B — Phase A + Phase B with intermediate commit + architect review gate.** Approved 2026-05-17.

### MC-6. Shared test fixtures

- **A.** Per-test class isolation — each test class spins its own
  Testcontainer.
- **B.** Per-collection — `IClassFixture` / `ICollectionFixture` with
  shared container, transactional rollback per test.
- **C.** Per-suite singleton container, dedicated DB schemas per
  test class.

**Recommendation: B.** xUnit `ICollectionFixture<PostgresFixture>` with
each test running in a transaction that rolls back on dispose. This
is the standard pattern; reduces total wall time from ~5 minutes to
~30 seconds. Tests stay isolated through transaction boundaries.

→ **Decision: B — `ICollectionFixture<PostgresFixture>` + transactional rollback per test.** Approved 2026-05-17.

### MC-7. Where do we draw the dual-write boundary in tests?

For tests of `AUTH-WEB-04` / `AUTH-API-07` / `USR-17` (LICENSE-*)
audit emission, do we test against:

- **A.** The real `IConfigurationApiHook` registration
  (`NoOpConfigurationApiHook` in dev) — verifies the call chain.
- **B.** A Moq spy hook to verify exact payloads.

**Recommendation: B** for these tests — assertion is "API call was
made with these arguments", not "the no-op succeeded". Reserve **A**
for Sprint T5 widget lifecycle tests where end-to-end matters.

→ **Decision: B — Moq spy `IConfigurationApiHook` for LICENSE-* tests. Real `NoOpConfigurationApiHook` reserved for Sprint T5 widget tests.** Approved 2026-05-17.

---

## 3. Definition of Done

Each DoD item must be **independently checkable** by a reviewer
without asking the author. The sprint closes only when **every item
is ✅ or has a structured ⚠ note with a follow-up task ID**.

- **DoD-1: Test count.** ≥ **40 passing tests** in
  `tests/CcDashboard.Tests.Security/`, distributed across the
  six clusters (cf. §1). `PlaceholderTests.cs` removed.
- **DoD-2: GQF isolation.** Test class
  `MultiTenancyIsolationTests` verifies: a row written in tenant A
  context is **not** returned to a query in tenant B context — for
  at least three entities: `Users`, `Dashboards`, `PermissionGroups`.
  ≥ 3 tests; covers **ARCH-01**.
- **DoD-3: Cross-tenant entities are NOT filtered.** Same fixture
  class verifies: `Tenants`, `Roles`, `WidgetCatalog`, `RTSGrid_Metric`
  are visible across any `ITenantContext`. ≥ 4 tests; covers **ARCH-05**.
- **DoD-4: Tenant mismatch on login.** `LoginAsync_TenantMismatch_*`
  test: user from tenant A tries to log into tenant B's subdomain →
  rejected with "Invalid credentials"; `Login.Failure` audit event
  with `subtype = TenantMismatch`. Covers **ARCH-04, BFP-03**.
- **DoD-5: Suspended / Deleted tenant blocks login.** Two tests:
  `Suspended` returns "Access to the organisation is temporarily
  suspended"; `Deleted` returns plain "Invalid credentials"
  (no enumeration). Audit `Login.Failure` with appropriate subtypes.
  Covers **ARCH-06, BFP-03, BFP-04**.
- **DoD-6: Refresh-token rotation + reuse detection.** Tests:
  (a) Refresh of valid token issues new token, marks old `Revoked`
  with `ReplacedByTokenId` set;
  (b) Reuse of a `Revoked` token triggers revocation of **all** the
  user's refresh tokens **and** emits `Token.Revoked` audit event.
  Covers **AUTH-API-03, AUTH-API-04**.
- **DoD-7: JTI revocation list.** Test: after `Logout`, the active
  access-token JTI is added to Redis with TTL ≤ remaining token
  lifetime; middleware rejects subsequent requests carrying that JTI.
  Covers **AUTH-API-05**.
- **DoD-8: Brute-force lockout.** Test: 5 consecutive failed logins
  → 6th attempt returns "Invalid credentials" with subtype
  `AccountLocked`; lockout cleared after configured duration
  (use fake `IDateTimeProvider`). Covers **BFP-01, BFP-04**.
- **DoD-9: Rate-limit.** Test: 11 login POSTs from a single IP within
  60s → 11th returns HTTP 429. Covers **BFP-02**. *(May be marked
  as ⚠ if the middleware is hard to test in isolation; create
  follow-up task.)*
- **DoD-10: Uniform error message.** Parametrised test covering all
  five `Login.Failure` subtypes (`UserNotFound`, `WrongPassword`,
  `TenantMismatch`, `TenantSuspended`, `AccountLocked`): user-facing
  error is **byte-for-byte identical** ("Invalid credentials"). Audit
  events differ. Covers **BFP-03 + BFP-04**.
- **DoD-11: LICENSE-SESSION enforcement.** Tests:
  (a) When `tenant_settings.UserConnections = 1` and one session is
  active, second cookie / JWT issue is rejected with
  `Session.RejectedLicenseLimit` audit event (channel = `BlazorCookie`
  in one test, `JwtApi` in another);
  (b) When `UserConnections = 0` (unlimited), no rejection regardless
  of active count. Covers **AUTH-WEB-04, AUTH-API-07**.
- **DoD-12: Test coverage instrument.** A `dotnet test --collect:"XPlat
  Code Coverage"` run produces a Cobertura report and the
  `Tests.Security` coverage on `Infrastructure/Identity` +
  `Web/Middleware` + `Api/Middleware` is ≥ 60% line coverage.
  Failure of this DoD is acceptable if the test count (DoD-1) is met
  and the gap is documented.

---

## 4. Known limitations

- **No tests for Redis backplane** (ARCH-08 prefix verified in
  isolation, not distributed); deferred to a future "scale-out
  readiness" sprint.
- **No tests for `IBlobStorage`** (ARCH-10) — no implementation
  exists yet; will be a separate sprint when blob storage is
  required for audit CSV export (DEF-09).
- **PG-06 cascade-reject UI test** is out of scope here; covered
  by Sprint T4.
- **Email send tests** skipped because the path is stubbed
  (DEF-01 / 02 / 05).

---

## 5. Open questions

- **OQ-T1-1:** Should the test suite run a fresh Postgres container
  per CI build, or share a long-running container across builds?
  Recommended: fresh per build (deterministic, ~20 s startup
  acceptable).
- **OQ-T1-2:** Do we instrument `[Trait("Req", "ARCH-04")]` per
  test now, or write a follow-on tooling task that scans test names
  and produces the trace matrix automatically? Recommended:
  instrument now — five extra characters per test, trivial.
- **OQ-T1-3:** Is the existing `RedisCacheService` testable without
  a real Redis? If not, do we use `ConnectionMultiplexer` against
  a Testcontainer'd Redis, or skip ARCH-08 verification here?
  Recommended: real Redis (Testcontainers Redis is fast).

---

## 6. Implementation notes

### Repository structure for the new tests

```
tests/CcDashboard.Tests.Security/
├── CcDashboard.Tests.Security.csproj   (existing, refresh deps)
├── Fixtures/
│   ├── PostgresFixture.cs              (Testcontainers wrapper, per MC-1)
│   ├── RedisFixture.cs                 (Testcontainers wrapper)
│   ├── IdentityFixture.cs              (real UserManager + SignInManager)
│   └── TenantContextFactory.cs         (build ITenantContext for arbitrary TenantId)
├── MultiTenancy/
│   ├── GlobalQueryFilterTests.cs       (DoD-2)
│   ├── CrossTenantEntitiesTests.cs     (DoD-3)
│   └── TenantMismatchLoginTests.cs     (DoD-4)
├── TenantLifecycle/
│   └── SuspendedAndDeletedTenantTests.cs (DoD-5)
├── ApiAuth/
│   ├── RefreshTokenRotationTests.cs    (DoD-6)
│   └── JtiRevocationTests.cs           (DoD-7)
├── BruteForce/
│   ├── LockoutTests.cs                 (DoD-8)
│   ├── RateLimitTests.cs               (DoD-9)
│   └── UniformErrorTests.cs            (DoD-10)
├── Licensing/
│   └── LicenseSessionTests.cs          (DoD-11)
└── PlaceholderTests.cs                 (DELETED at sprint close)
```

### Approximate effort sizing

- Fixtures + DI plumbing: ~6 h.
- Multi-tenancy cluster (3 test classes): ~6 h.
- Tenant lifecycle cluster: ~3 h.
- API auth cluster (2 test classes): ~6 h.
- Brute-force cluster (3 test classes): ~5 h.
- Licensing cluster: ~3 h.
- CI integration + coverage report: ~3 h.
- **Total: ~32 hours.** Fits in a 5-day sprint at ~6.5 h/day.

### Reference implementations to inspect

- `tests/CcDashboard.Tests.Unit/Commands/SetTenantStatusCommandHandlerTests.cs`
  — the **only existing real test class** for command handlers.
  Use it as the style baseline for naming and arrangement.
- `tests/CcDashboard.Tests.Architecture/ArchitectureTests.cs` —
  example of `[Trait]` usage if we decide to extend (MC-4).
- `src/CcDashboard.Infrastructure/Identity/IdentityAuthService.cs` —
  the central SUT for half of these tests; refresher reading before
  writing.

### Dependencies to add (NuGet)

To `tests/CcDashboard.Tests.Security/CcDashboard.Tests.Security.csproj`:

- `Testcontainers.PostgreSql` (latest 4.x)
- `Testcontainers.Redis` (latest 4.x)
- `Microsoft.AspNetCore.Mvc.Testing` (matches .NET 8)
- `coverlet.collector` (already present? — verify)
- `Bogus` (data generation — optional but speeds up arrangement)

---

## 7. Phase split (per MC-5)

### Phase A — Foundations + Tenancy + Web Auth

- Fixtures (PostgresFixture, RedisFixture, IdentityFixture).
- DoD-2 (GQF), DoD-3 (cross-tenant), DoD-4 (TenantMismatch),
  DoD-5 (Suspended / Deleted).
- DoD-12 instrumented (coverage report wiring).
- **Exit criteria:** ≥ 18 passing tests; coverage report emitted in CI.
- **Commit message:** `test(Sprint T1A): tenancy + web auth foundation —
  GQF isolation, cross-tenant entities, TenantMismatch, suspended-tenant
  login (ARCH-01/04/05/06)`

### Phase B — API Auth + Brute-Force + Licensing + close-out

- DoD-6 (refresh rotation), DoD-7 (JTI revocation), DoD-8..10
  (brute-force cluster), DoD-11 (LICENSE-SESSION).
- Delete `PlaceholderTests.cs`.
- Update `docs/traceability-matrix.md`:
  rows for ARCH-01..06, AUTH-WEB-02..04, AUTH-API-03..05+07,
  BFP-01..04 move from `❌ MISSING` to the new test file paths.
- Write `_gap-analysis.md` per `docs/sprints/_gap-analysis-template.md`.
- **Commit message:** `test(Sprint T1B): API auth + brute force +
  licensing — rotation + reuse detection, JTI revocation,
  lockout / rate limit / uniform error, LICENSE-SESSION
  (AUTH-API-03..07, BFP-01..04, AUTH-WEB-04)`

After Phase B, the running total of test files in `Tests.Security`
should be **9 classes / ≥ 40 tests** and the traceability matrix
should show **~30 fewer `❌ MISSING` rows**.

---

## 8. Hand-off to Claude Code

When the architect signs off on §2 micro-choices (filling in the
"Decision:" lines), the prompt below is what gets pasted into
Claude Code to execute Phase A. Phase B follows the same pattern
once Phase A merges.

```
[Sprint T1 Phase A handover]

Read this file first:
- docs/sprints/T1-security-and-tenant-isolation.md

Architect has filled in §2 micro-choices. Use those decisions as
authoritative (do not reopen). Implement Phase A of §7 only. Follow
DoD-2, DoD-3, DoD-4, DoD-5, DoD-12. Do not touch tests outside
Tests.Security in this phase.

Working agreement:
- Every test method carries [Trait("Req", "ARCH-XX")] (or equivalent
  marker) — per MC-4 decision.
- Tests use the fixture pattern defined in §6 "Repository structure".
- On failure: do NOT modify production code without first reporting
  expected vs actual + root-cause hypothesis (per project memory
  "Diagnostics first, fix later").
- On completion: produce the gap analysis report per
  `docs/sprints/_gap-analysis-template.md` and commit with the
  message in §7 Phase A.
- If Testcontainers is not available locally, abort with a clear
  message; do NOT fall back to In-Memory provider (per MC-1).

Architect will review Phase A before authorising Phase B.
```

---

## 9. Sprint close-out checklist

When all of DoD-1..12 are ✅:

1. Run `_gap-analysis-template.md` and fill it in honestly.
2. Update `docs/traceability-matrix.md` to reflect newly satisfied
   rows.
3. Update `analysis/v1.2-vs-impl-gaps.md` if any new gaps surface
   during testing (likely zero — but keep the discipline).
4. Cross-reference the closed requirements with the corresponding
   ADR (ADR-003 / ADR-006 / ADR-007).
5. Tag this sprint complete in the project's living sprint log.
