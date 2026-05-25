# Sprint T1 Phase C: Golden-path auth tests via WebApplicationFactory

**Status:** **Approved — ready for execution** *(all §2 micro-choices signed off 2026-05-25)*
**Window:** ~2 working days (small, single-phase)
**Owner:** Claude Code (executing per this brief once §2 signed)
**Related sprints:** T1 Phase A (commit `ca0ccd9`), T1 Phase B (commit `b846f1b`)
**Related TS sections:** §5.1 (AUTH-WEB-01..03), §5.2 (AUTH-API-01..06), LICENSE-SESSION (ADR-012)

---

## 1. Scope

### Why Phase C exists

Phase A and Phase B together delivered 61 passing tests and produced
4 SF-grade production fixes. However, 8 tests in those two phases
were marked `Skip` because they exercise the **successful login
golden path** — and successful login uses `IdentityAuthService.CompleteSignInAsync`,
which calls `HttpContext.Response.Cookies.Append` and needs a real
ASP.NET Core pipeline (not the bare `UserManager`/`SignInManager`
plumbing that the Phase A / B fixtures use).

The skips are documented in `docs/sprints/T1-gap-analysis-phase-b.md`
§"Skipped tests" — none of them changes the security posture of the
release (negative paths and guard logic are fully covered), but they
leave T1 in a "closed with carry-over" state. Phase C closes the
carry-over.

### In scope

Stand up a `WebApplicationFactory<Program>` based fixture in
`tests/CcDashboard.Tests.Security/Fixtures/` and use it to make all
8 currently-skipped tests pass:

| Inherited from | Test class · test method | Requirement |
|---|---|---|
| Phase A | `TenantMismatchLoginTests.PasswordSignInAsync_CorrectTenant_ReturnsSuccess` | ARCH-04 (positive path) |
| Phase A | `SuspendedAndDeletedTenantTests.PasswordSignInAsync_ActiveTenant_SucceedsWithCorrectCredentials` | ARCH-06 (positive path) |
| Phase A | `SuspendedAndDeletedTenantTests.TenantStatus_Transition_AffectsLoginBehavior` | ARCH-06 (state transition) |
| Phase B | `LicenseSessionTests.PasswordSignInAsync_NoLimit_AllowsMultipleConnections` | LICENSE-SESSION (unlimited) |
| Phase B | `LicenseSessionTests.PasswordSignInAsync_WithinLimit_AllowsLogin` | LICENSE-SESSION (under cap) |
| Phase B | `LicenseSessionTests.PasswordSignInAsync_SameIp_AllowsUnlimitedConnections` | LICENSE-SESSION (IP exception) |
| Phase B | `LicenseSessionTests.PasswordSignInAsync_ExpiredSession_NotCounted` | LICENSE-SESSION (expiry) |
| Phase B | `LicenseSessionTests.PasswordSignInAsync_RevokedSession_NotCounted` | LICENSE-SESSION (revocation) |

In addition, write **one new test** that verifies the claims
materialised on a successful login (`TenantId`, `Role`,
`PermissionGroupId`) match the user's DB values — this is the
positive-path coverage for AUTH-WEB-02 that was missing entirely.

### Explicitly out of scope

- Re-doing any negative-path test from Phase A/B (those are passing — leave alone).
- 2FA flows (Deferred per DEF-03).
- SSO callback flow (Deferred per DEF-04).
- API-side JWT issuance golden path through `Api/Program.cs` — that is
  a candidate for **Sprint T3** when the API surface gets WAF coverage.
  This sprint is **Blazor / cookie golden path only**.
- UI integration through SignalR / Blazor circuit — out of scope; we
  test the auth pipeline, not the Razor renderer.

---

## 2. Architectural micro-choices (gate — answer before coding)

Each item inherits from T1 baseline unless explicitly redefined. Phase C
introduces three new MCs specific to WebApplicationFactory; the rest
carry forward.

### MC-1. Database — inherited from T1 MC-1

Testcontainers PostgreSQL 16. **No change.**

→ **Decision: A — inherited from T1.** Approved 2026-05-25.

### MC-2. Identity stack — inherited from T1 MC-2

Real `UserManager` / `SignInManager` via `WebApplicationFactory.Services`.
No mocking of Identity in Phase C — the whole point is to exercise the
real pipeline.

→ **Decision: A — inherited from T1.** Approved 2026-05-25.

### MC-3. Audit assertion — inherited from T1 MC-3

Real DB read against `audit.audit_logs`. Same fixture pattern.

→ **Decision: C — inherited from T1.** Approved 2026-05-25.

### MC-4. Test naming + Trait — inherited from T1 MC-4

`MethodName_Scenario_ExpectedBehaviour` + mandatory `[Trait("Req", "...")]`.

→ **Decision: A — inherited from T1.** Approved 2026-05-25.

### MC-C1 (NEW). WebApplicationFactory variant

- **A.** Standard `WebApplicationFactory<Program>` from
  `Microsoft.AspNetCore.Mvc.Testing` (already in T1 csproj per §6).
- **B.** Custom-rolled `TestServer` with hand-built service collection.
- **C.** `WebApplicationFactory<Program>` with `ConfigureWebHost`
  overriding only the data-layer registrations (point Postgres /
  Redis at Testcontainer endpoints).

**Recommendation: C.** Standard `WebApplicationFactory` keeps the
real `Program.cs` composition (so middleware order, options binding,
auth handlers are *not* re-implemented in the test), but
`ConfigureWebHost` swaps `IDbContextFactory` / `IConnectionMultiplexer`
to point at fixtures. Custom `TestServer` is more work and easier to
get wrong; bare WAF without overrides hits a dev Postgres which is
non-deterministic.

→ **Decision: C — per recommendation.** Approved 2026-05-25.

### MC-C2 (NEW). Cookie handling in HttpClient

- **A.** Per-test `HttpClient` with a fresh `CookieContainer` each time.
- **B.** Per-test-class `HttpClient` shared, cookies cleared in
  `IDisposable.Dispose`.
- **C.** Per-test `HttpClient` from `WebApplicationFactory.CreateClient`
  with `HandleCookies = true` (the default) — relies on framework's
  built-in `HttpClientHandler` cookie persistence.

**Recommendation: C.** This is what `Microsoft.AspNetCore.Mvc.Testing`
defaults to. We just need to ensure each test gets its own client
via `_factory.CreateClient()`, not a shared one. Simpler, less code,
matches the framework intent.

→ **Decision: C — per recommendation.** Approved 2026-05-25.

### MC-C3 (NEW). HTTPS / certificate validation in the test pipeline

- **A.** Disable HTTPS in test host — call `UseUrls("http://localhost:0")`
  and serve plain HTTP. Cookie `Secure` flag becomes meaningless in
  tests; we accept the gap for these 8 tests.
- **B.** Use the dev certificate generated by `dotnet dev-certs https`
  and force HTTPS in the WAF host.
- **C.** Override `CookieAuthenticationOptions` in the test
  `ConfigureWebHost` to set `Cookie.SecurePolicy = SecurePolicy.None`
  for the duration of the test (HTTP works, cookie still gets set).

**Recommendation: C.** Cleanest. We don't lose test coverage of the
cookie attributes we care about (`HttpOnly`, `SameSite`); we just
relax the `Secure` enforcement so the cookie can be set on HTTP.
Production composition is untouched. Document this in the fixture
class's XML doc so nobody reading later assumes prod runs on HTTP.

→ **Decision: C — per recommendation.** Approved 2026-05-25.

### MC-C4 (NEW). Reuse vs duplicate fixtures from Phase A/B

- **A.** New `WebFixture` class lives alongside the existing
  `PostgresFixture` / `RedisFixture` / `IdentityFixture`. Tests
  that need WAF inherit from `WebFixture`; tests that don't keep
  the old fixture references.
- **B.** Replace `IdentityFixture` with `WebFixture` everywhere
  (consolidate to one pipeline).

**Recommendation: A.** Phase A / B tests are passing and proven;
replacing their fixture is risk for zero gain. New fixture composes
the existing Postgres / Redis containers so we don't run two of each.

→ **Decision: A — per recommendation.** Approved 2026-05-25.

---

## 3. Definition of Done

- **DoD-13: `WebFixture` lands and is reused.** New file
  `tests/CcDashboard.Tests.Security/Fixtures/WebFixture.cs` builds
  on the existing `PostgresFixture` and `RedisFixture` (one
  Testcontainer each, shared via `ICollectionFixture`). A smoke
  test (`WebFixtureSmokeTests.HealthCheck_Endpoint_Returns200`)
  verifies the pipeline starts.
- **DoD-14: Phase A inherited skips now pass.** All three tests
  listed in §1 inherited from Phase A run green. `[Skip]` attribute
  removed from each.
- **DoD-15: Phase B inherited skips now pass.** All five
  `LicenseSessionTests.*` tests listed in §1 inherited from Phase B
  run green. `[Skip]` attribute removed from each.
- **DoD-16: AUTH-WEB-02 positive-path test exists.** New test
  `IdentityAuthServiceTests.CompleteSignInAsync_ValidUser_MaterialisesClaimsCorrectly`
  verifies that on successful login the principal carries
  `TenantId`, `Role`, `PermissionGroupId`, `PreferredLocale` claims
  matching the DB row. Carries `[Trait("Req", "AUTH-WEB-02")]`.
- **DoD-17: Zero remaining `[Skip]` in `Tests.Security`.** After
  Phase C closes, `grep -r "Skip" tests/CcDashboard.Tests.Security`
  returns no test-method-level skips. Any skip that remains must be
  paired with an explicit follow-up task ID in the brief annexe.
- **DoD-18: Coverage holds.** `dotnet test --collect:"XPlat Code
  Coverage"` shows ≥ 80% line coverage on
  `CcDashboard.Infrastructure` (target was 60% in T1; Phase B
  delivered 86.88%, so the bar effectively moves up — regressions
  are unacceptable).
- **DoD-19: Phase C gap analysis filed.** Per
  `docs/sprints/_gap-analysis-template.md`, save as
  `docs/sprints/T1-gap-analysis-phase-c.md` with the DoD table,
  test counts (expect total `Tests.Security` to land at **69
  passing / 0 skipped**), and the close-out decision tick.

---

## 4. Known limitations

- The API surface (`CcDashboard.Api/Program.cs`) is **not** brought
  under WAF in this phase. T3 (multi-tenancy integration) is the
  natural home for API WAF tests since it needs to exercise the
  middleware-resolved `ITenantContext` for HTTP requests anyway.
- Phase C does not address SignalR golden-path; that lands in T5
  alongside the widget framework.
- We are not introducing a TLS-terminating proxy in the test host.
  `Secure` cookie attribute is **not** asserted as part of DoD-16
  (it cannot be set under HTTP); we rely on `Tests.Architecture`
  rules to enforce that production composition sets it. Follow-up
  candidate for `Tests.Architecture`: scan `CookieAuthenticationOptions`
  registrations and verify `Secure = Always`.

---

## 5. Open questions

- **OQ-C1:** Does `WebApplicationFactory<Program>` resolve the
  generic-host `Program` correctly in our setup (the `Program` class
  is the default top-level statements style — should be fine, but
  worth verifying in the smoke test).
- **OQ-C2:** Do we expose a deterministic anti-forgery token endpoint
  for cookie-auth POSTs in tests, or disable anti-forgery in the test
  pipeline? Recommended: keep anti-forgery on; fetch token from a GET
  before each POST (one helper method on the fixture).
- **OQ-C3:** `LicenseSessionTests.*_SameIp_AllowsUnlimitedConnections`
  needs control over the request `RemoteIpAddress`. WAF resolves
  `127.0.0.1` for the loopback client. Recommended: override
  `IHttpContextAccessor.HttpContext.Connection.RemoteIpAddress` in a
  test middleware registered via `ConfigureWebHost`.

---

## 6. Implementation notes

### Files to add or change

```
tests/CcDashboard.Tests.Security/
├── Fixtures/
│   └── WebFixture.cs                (NEW — composes Postgres+Redis containers, hosts WAF)
├── Smoke/
│   └── WebFixtureSmokeTests.cs      (NEW — DoD-13)
├── MultiTenancy/
│   └── TenantMismatchLoginTests.cs  (MODIFIED — remove [Skip] from CorrectTenant_ReturnsSuccess)
├── TenantLifecycle/
│   └── SuspendedAndDeletedTenantTests.cs  (MODIFIED — remove [Skip] from 2 tests)
├── Licensing/
│   └── LicenseSessionTests.cs       (MODIFIED — remove [Skip] from 5 tests)
└── Identity/
    └── IdentityAuthServiceTests.cs  (NEW — DoD-16 claims-materialisation test)
```

### Approximate effort sizing

- `WebFixture` + smoke test: ~3 h.
- Unskipping + adjusting Phase A inherited tests to use WAF: ~3 h.
- Unskipping + adjusting Phase B inherited tests to use WAF: ~4 h.
- AUTH-WEB-02 claims test: ~1 h.
- Gap analysis + traceability matrix update: ~1 h.
- **Total: ~12 hours / ~2 working days.**

---

## 7. Hand-off to Claude Code

When the architect signs §2 (MC-C1..C4 — the four `TBD` lines), paste
the following into Claude Code:

```
[Sprint T1 Phase C handover]

Read these files first, in order:
- docs/sprints/T1-phase-c.md
- docs/sprints/T1-security-and-tenant-isolation.md (for inherited MC context)
- docs/sprints/T1-gap-analysis-phase-b.md (for the 8 skipped tests this phase unblocks)

Architect has filled in §2 micro-choices MC-C1..C4. Use those decisions
as authoritative. Implement DoD-13 through DoD-19, in that order. Do
NOT modify tests outside Tests.Security in this phase.

Working agreement:
- Every new test method carries [Trait("Req", "ARCH-XX" | "AUTH-WEB-02" |
  "LICENSE-SESSION")] per the §1 mapping table.
- New tests use the WebFixture pattern from §6. Phase A/B tests
  switched from IdentityFixture to WebFixture must keep their
  existing trait values.
- On failure: do NOT modify production code without first reporting
  expected vs actual + root-cause hypothesis (per project memory
  "Diagnostics first, fix later"). Phase A and Phase B each
  uncovered production bugs (SF-001..004); Phase C may surface
  more — if so, treat each as a numbered SF and document in
  `analysis/security-findings.md` before patching.
- If `WebApplicationFactory<Program>` cannot resolve `Program` in
  this project's top-level-statements layout, abort with a clear
  error — do NOT add a `public partial class Program {}` declaration
  in src/ without architect approval (that change crosses into
  production code).
- On completion: file `docs/sprints/T1-gap-analysis-phase-c.md`
  using the standard template, update `docs/traceability-matrix.md`
  to remove all "Phase C — WAF" placeholders, commit with message:
  `test(Sprint T1C): golden-path auth via WebApplicationFactory —
  TenantMismatch / Suspended-Deleted / LICENSE-SESSION success
  paths (AUTH-WEB-02, ARCH-04, ARCH-06, LICENSE-SESSION)`.

Architect will review Phase C before closing T1 as a whole sprint.
```

---

## 8. Sprint close-out checklist

When all of DoD-13..19 are ✅:

1. File `docs/sprints/T1-gap-analysis-phase-c.md`.
2. Update `docs/traceability-matrix.md`: remove all "Phase C — WAF"
   placeholders; replace with concrete test class names.
3. Update `analysis/security-findings.md` if new SFs were found
   (continue SF-005, SF-006, ... numbering from SF-004).
4. Update `PROJECT_STATUS.md`: mark T1 as **fully closed** (Phases
   A + B + C all green), update SF count, update last session line.
5. Decide next sprint: T2 / T4 (parallel, no blockers) or B1 #11
   to unblock T3 / T5.
