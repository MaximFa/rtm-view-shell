# Sprint T2: Licensing enforcement + force-logout + JWT key configuration

**Status:** **Approved — ready for execution** *(§2 micro-choices signed off 2026-05-25)*
**Window:** ~3 working days (~20-25 tests; single phase per T1 baseline)
**Owner:** Claude Code (executing per this brief once §2 signed)
**Related sprints:** T1 Phase B (LICENSE-SESSION already tested), T1 Phase C (WebFixture); T4 (PG authorization)
**Related TS sections:** §5.2 (AUTH-API-06), §5.3 (AUTH-WEB-03), licensing surface in `TenantSettings`
**Related ADRs:** ADR-003 (per-tenant licensing) — referenced from `decisions/_index.md`; full ADR file pending Backlog D1

---

## 1. Scope

### Why T2 exists

Three independent code paths share a "license / lifecycle" theme and
currently have **zero security-layer tests**:

1. **LICENSE-USER** — `TenantSettings.PurchasedLicences` is enforced in
   `UserManagementService.CreateAsync` (`[LIC-01]` marker). The
   enforcement code exists; it correctly rejects when `userCount >=
   PurchasedLicences`. But the rejection does **not** emit an audit
   event (grep for `License.RejectedUserLimit` returns 0 hits).
   Latent gap candidate.
2. **AUTH-WEB-03 force-logout** — `UpdateSecurityStampAsync` is called
   in `DeactivateAsync` and `ForceLogoutAsync` (`[USR-09]` marker).
   No test verifies that the security stamp change actually
   invalidates existing cookies.
3. **AUTH-API-06 JWT key configuration** — `JwtBearer` package wired,
   `TokenService.cs` exists. No test verifies signing algorithm
   (must be RS256 per TS), key size (must be ≥2048 RSA), or key
   accessibility (signing key must be the same that JwtBearer
   validates against).

T2 closes the test gap for all three and surfaces any latent SF
along the way.

### In scope

| Cluster | Requirements covered |
|---|---|
| **LICENSE-USER enforcement** | `[LIC-01]` (PurchasedLicences limit on user creation), per-tenant isolation of the count, audit event emission on rejection |
| **Force-logout** | AUTH-WEB-03 (SecurityStamp invalidation invalidates active cookie sessions), `[USR-09]` |
| **JWT key configuration** | AUTH-API-06 (RS256 algorithm enforced, RSA key size ≥2048, signing/validation key alignment) |
| **License audit events** | Whatever audit events should fire on user-create rejection — file as SF if missing |

### Explicitly out of scope

- LICENSE-SESSION (already covered by T1 Phase B + Phase C — 1 rejection
  + 5 golden-path tests).
- RSA key rotation flow (key swap with `kid` chains) — TS mentions
  rotation every 12 months but no rotation impl exists; **out of scope
  for T2**, file as separate backlog if architect decides.
- Vault / Azure Key Vault integration — no impl exists, deferred.
- Per-tenant feature flags / edition tiers (no such surface in code).
- SSO interaction with licensing (SSO is deferred per DEF-04).
- License purchase / payment flow — not in shell scope (commercial-side).

---

## 2. Architectural micro-choices (gate — answer before coding)

### MC-1. Database — inherited from T1 MC-1

Testcontainers PostgreSQL 16. **No change.**
→ **Decision: A — inherited from T1.** Approved 2026-05-25.

### MC-2. Identity stack — inherited from T1 MC-2

Real `UserManager` / `SignInManager` + `WebFixture` for AUTH-WEB-03
golden-path. Stub `ICurrentUserAccessor` for unit-level LICENSE-USER
tests where calling `UserManagementService.CreateAsync` directly is
cleaner than going through HTTP.
→ **Decision: A — inherited from T1.** Approved 2026-05-25.

### MC-3. Audit assertion — inherited from T1 MC-3

Hybrid: Moq spy in Tests.Unit; real DB read in Tests.Security.
→ **Decision: C — inherited from T1.** Approved 2026-05-25.

### MC-4. Test naming + Trait — inherited from T1 MC-4

`MethodName_Scenario_ExpectedBehaviour` + mandatory `[Trait("Req", "...")]`.
→ **Decision: A — inherited from T1.** Approved 2026-05-25.

### MC-T2-1 (NEW). LICENSE-USER audit gap — fix in T2 or defer?

`UserManagementService.CreateAsync` rejects when over limit but emits
no audit. By analogy with `Session.RejectedLicenseLimit` (LICENSE-SESSION),
the expected event is `User.RejectedLicenseLimit` or
`License.RejectedUserLimit` (naming TBD).

- **A.** Fix in T2 — add audit emission to the rejection branch
  (1-2 line production change). T2 tests then assert the event fires.
- **B.** Test current behaviour only (rejection works, no audit yet).
  File the missing audit as SF and a separate backlog item.

**Recommendation: A.** The fix is trivial (analogous to existing
LICENSE-SESSION rejection in `IdentityAuthService`) and the
operational value is concrete — without the audit event, ops/billing
teams cannot see "this tenant repeatedly hit their license cap"
in audit logs, which is a known commercial signal. Mirror the
LICENSE-SESSION pattern.

→ **Decision: A — per recommendation.** Approved 2026-05-25.

### MC-T2-2 (NEW). AUTH-WEB-03 invalidation test approach

To verify that `UpdateSecurityStampAsync` actually invalidates a
cookie:

- **A.** Two-request test: (1) login → receive cookie → request
  authenticated page (200 OK). (2) call `ForceLogoutAsync` for that
  user. (3) re-request the page with the same cookie → expect
  redirect to login. Requires `WebFixture`.
- **B.** Unit-level test on `SecurityStampValidator` configuration
  (validate that `ValidationInterval = TimeSpan.Zero` so stamp
  re-checked every request, per ASP.NET Core default behaviour).

**Recommendation: A.** B verifies *configuration*, A verifies
*behaviour*. Configuration tests don't catch regressions from
"someone overrode the interval to 5 minutes thinking it was a
perf optimisation." Real two-request test via `WebFixture`
exercises the full Identity pipeline.

→ **Decision: A — per recommendation.** Approved 2026-05-25.

### MC-T2-3 (NEW). JWT key validation tests — surface

`TokenService` issues tokens; `JwtBearerOptions` validates them.
Both must use the same RSA key. Tests can attack three angles:

- **A.** Inspect `TokenService` and `JwtBearerOptions` registrations
  via DI introspection (`IOptions<JwtBearerOptions>`) — assert
  algorithm = RS256, key type = RSA, key size ≥2048, same `kid`.
- **B.** Round-trip: issue token via `TokenService` → validate via
  `JwtBearerHandler` (mock the HTTP request, run middleware).
  Verifies real wire-level integration.
- **C.** Both — DI introspection for algorithm/size + round-trip for
  end-to-end integrity.

**Recommendation: C.** A alone misses runtime config drift between
issuer and validator; B alone misses static config errors (e.g.,
algorithm field correct but key is RSA-1024). Together they cover
both surfaces.

→ **Decision: C — per recommendation (both DI introspection + round-trip).** Approved 2026-05-25.

### MC-T2-4 (NEW). Concurrent user-creation race against PurchasedLicences

Suppose `PurchasedLicences = 10` and `userCount = 9`. Two concurrent
`CreateAsync` calls might both pass the check and both succeed,
leaving `userCount = 11`. This is a TOCTOU bug class.

- **A.** Write a test that reproduces it; if it fires, file as SF;
  fix via PostgreSQL `SELECT ... FOR UPDATE` on
  `tenant_settings` row or via unique-constraint trick.
- **B.** Acknowledge in scope but don't test (race window is narrow
  in practice; backlog).

**Recommendation: A.** Race tests are sprint-T1-pattern (enum
parametrised tests for guards). Reading the current
`UserManagementService.CreateAsync` — no transaction, no row lock
on `TenantSettings` — strongly suggests this race exists.
High-leverage SF candidate.

→ **Decision: A — per recommendation.** Approved 2026-05-25.

---

## 3. Definition of Done

- **DoD-1: LICENSE-USER rejection works.** Integration test:
  `PurchasedLicences = 3`, 3 users exist → 4th `CreateAsync`
  returns failure with the licence-limit error. Trait `[LIC-01]`.
- **DoD-2: LICENSE-USER respects 0 = unlimited.** Test:
  `PurchasedLicences = 0`, 1000 users created sequentially → all
  succeed. Trait `[LIC-01]`.
- **DoD-3: LICENSE-USER respects tenant boundary.** Test: tenant A
  has `PurchasedLicences = 1`; tenant B has 100 users; creating user
  for tenant A succeeds (count of tenant B's users does not bleed in).
  Trait `[LIC-01]` + `[ARCH-01]`.
- **DoD-4: License rejection emits audit event** (per MC-T2-1=A).
  Test: rejected creation produces an audit entry with appropriate
  event type (name finalised during impl — `User.RejectedLicenseLimit`
  or similar). Trait `[LIC-01]` + `[AUD-01]`.
- **DoD-5: Race condition tested** (per MC-T2-4=A). Test:
  `PurchasedLicences = 10`, 9 users exist, run 5 concurrent
  `CreateAsync` calls → exactly 1 of the 5 succeeds (limit lands at 10).
  If this fails today → file as SF-006 race-condition bug, fix as
  part of T2 (transactional row lock recommended).
- **DoD-6: AUTH-WEB-03 force-logout invalidates cookie.** Two-request
  WebFixture test per MC-T2-2=A. Trait `[AUTH-WEB-03]` + `[USR-09]`.
- **DoD-7: AUTH-WEB-03 deactivation invalidates cookie.** Same
  pattern, but trigger = `DeactivateAsync` (not `ForceLogoutAsync`).
  Verifies that deactivation propagates the security stamp change.
  Trait `[AUTH-WEB-03]`.
- **DoD-8: JWT algorithm = RS256.** DI-level inspection of
  `JwtBearerOptions.TokenValidationParameters` + `TokenService`
  signing parameters. Algorithm name string must be `RS256`. Trait
  `[AUTH-API-06]`.
- **DoD-9: JWT signing key size ≥ 2048 bits.** Inspection of the
  loaded `RsaSecurityKey` (or equivalent) — `.KeySize >= 2048`.
  Trait `[AUTH-API-06]`.
- **DoD-10: JWT round-trip integrity.** Issue token via `TokenService`
  → validate via `JwtBearerHandler` (or equivalent test helper) → all
  claims survive, signature validates. Trait `[AUTH-API-06]` +
  `[AUTH-API-02]`.
- **DoD-11: Test count.** ≥ 20 passing tests in
  `tests/CcDashboard.Tests.Security/Licensing/` + `Authentication/`
  (new subfolders or extend existing). **Zero failing, zero skipped.**
  Re-run twice consecutively to verify no shared-state flakiness
  (PD-003 lesson).
- **DoD-12: Coverage maintained.** Infrastructure ≥ 87% (T1+T4
  baseline). Application-side coverage on `UserManagementService`
  and `TokenService` ≥ 70%.
- **DoD-13: Gap analysis filed FIRST.** Before any other close-out
  edit, write `docs/sprints/T2-gap-analysis.md` using
  `_gap-analysis-template.md` (PD-004 lesson). Then update
  traceability matrix, security-findings, process-deviations,
  PROJECT_STATUS in that order.

---

## 4. Known limitations

- T2 does not implement RSA key rotation (kid chains, JWKS refresh).
  If T2 tests reveal rotation hooks already wired (unlikely), test
  them; otherwise leave as backlog.
- License limit enforcement on *update* (e.g., reactivating a
  deactivated user when over limit) is not covered — only creation.
  Backlog if discovered as live gap.
- Federated SSO licensing interaction skipped.
- Performance under TOCTOU race is the SF angle; no benchmarking.

---

## 5. Open questions

- **OQ-T2-1:** Event name for `User.RejectedLicenseLimit` vs
  `License.RejectedUserLimit` — pick whichever matches
  `Session.RejectedLicenseLimit` naming convention; verify by grep
  before writing the audit emission line.
- **OQ-T2-2:** Are there commands that auto-create users (e.g., SSO
  JIT provisioning per SSO-03)? If yes, they also need the licence
  check — verify with `grep -rn "AddAsync.*Users\|Users.Add" src/`.
  Out of scope to fix in T2 but flag if found.
- **OQ-T2-3:** Is `TenantSettings.PurchasedLicences` editable via
  any admin UI / API? If yes, what audit event fires? (Edge: admin
  reduces limit below current user count — what happens to existing
  users? Read-only? Locked? Out of scope to fix but flag if obvious.)

---

## 6. Implementation notes

### Existing artefacts to inspect first

- `src/CcDashboard.Infrastructure/Identity/UserManagementService.cs:30-40`
  — the `[LIC-01]` enforcement block. Also study `ForceLogoutAsync`
  and `DeactivateAsync` for SecurityStamp usage.
- `src/CcDashboard.Domain/Domain/TenantSettings.cs:17-18` — the two
  licensing columns.
- `src/CcDashboard.Infrastructure/Security/TokenService.cs` — JWT
  issuance; check signing key load.
- `src/CcDashboard.Api/Program.cs` — JwtBearer registration; check
  algorithm + validation parameters.
- `tests/CcDashboard.Tests.Security/Licensing/LicenseSessionTests.cs`
  — pattern reference for how LICENSE-SESSION rejection is asserted
  (mirror for LICENSE-USER).
- T1 fixtures: `PostgresFixture`, `RedisFixture`, `WebFixture`,
  `IdentityFixture`. Reuse all.

### Recommended file structure

```
tests/CcDashboard.Tests.Security/Licensing/
├── LicenseUserEnforcementTests.cs       (DoD-1, 2, 3)
├── LicenseUserAuditTests.cs             (DoD-4)
└── LicenseUserConcurrencyTests.cs       (DoD-5)

tests/CcDashboard.Tests.Security/Authentication/
├── ForceLogoutTests.cs                  (DoD-6, 7)
└── JwtKeyConfigurationTests.cs          (DoD-8, 9, 10)
```

Production code changes anticipated (all pre-approved per the §7
hand-off, scoped narrowly):
- `UserManagementService.cs` — add audit emission on rejection
  (≤5 lines). Per MC-T2-1.
- `UserManagementService.cs` OR a dedicated repository method —
  transactional locking on `TenantSettings` row for race fix.
  Per MC-T2-4 *if* the race test fires.

### Approximate effort sizing

- LICENSE-USER tests (DoD-1..4): ~5h.
- Race condition reproduction + fix if needed (DoD-5): ~3-4h.
- Force-logout tests (DoD-6, 7): ~3h.
- JWT key tests (DoD-8..10): ~4h.
- Test isolation verification + coverage: ~2h.
- Gap analysis + traceability + close-out docs: ~2h.
- **Total: ~20h** (≈ 2.5-3 working days).

### Likely production findings (pre-test prediction)

1. **Missing audit event on LICENSE-USER rejection** — high confidence,
   pre-verified via grep. Will be filed as SF when MC-T2-1 = A is
   confirmed (the missing audit IS the finding; the fix lands with
   the tests).
2. **TOCTOU race on PurchasedLicences** — medium-high confidence.
   No transaction visible around the check-then-insert in current
   code. Possible SF-006.
3. **JWT signing key not actually RS256 / 2048-bit** — low-medium
   confidence. If config drifted or dev cert used in prod, this
   would be a Critical SF. Likely fine but worth confirming.

---

## 7. Hand-off to Claude Code

When the architect signs the four `TBD` lines in §2, paste the
following into Claude Code:

```
[Sprint T2 handover]

Read these files first, in order:
- docs/sprints/T2-licensing-enforcement.md
- analysis/process-deviations.md (PD-001..004 — apply lessons)
- analysis/security-findings.md (SF-001..005 — context)
- src/CcDashboard.Infrastructure/Identity/UserManagementService.cs (LIC-01 block; SecurityStamp usage)
- src/CcDashboard.Infrastructure/Security/TokenService.cs

Architect has signed §2 micro-choices (date: <fill in>).
Use those decisions as authoritative. Implement DoD-1 through DoD-13.

Working agreement:
- Every new test method carries [Trait("Req", "LIC-01" | "AUTH-WEB-03" | "USR-09" | "AUTH-API-06" | "AUD-01" | "ARCH-01")] per the §3 mapping.
- Reuse existing PostgresFixture / RedisFixture / WebFixture / IdentityFixture from T1. Use WebFixture.ClearLoginRateLimitState() in any test that calls LoginAsync (PD-003 lesson — already wired in fixture; just verify it's called).
- Production code changes:
  * Per MC-T2-1=A (if signed): adding the missing audit event to UserManagementService.CreateAsync rejection branch is pre-approved (≤5 lines, mirrors LICENSE-SESSION pattern in IdentityAuthService).
  * Per MC-T2-4=A (if signed AND race fires): transactional fix for the PurchasedLicences race condition is pre-approved. Use PostgreSQL row-level locking on tenant_settings (SELECT ... FOR UPDATE within IUnitOfWork transaction). Document the choice in the gap analysis.
  * `public partial class Program {}` already exists in src/CcDashboard.Web/Program.cs (Phase C); pre-approved if needed in CcDashboard.Api too (PD-001 lesson — same standard Microsoft pattern).
  * ANY OTHER production code change — new abstractions, virtual modifiers, public type expansions beyond the two surfaces above — requires architect approval. Abort and report before proceeding (PD-002 lesson).
- On failure: diagnostics first (expected vs actual + root-cause hypothesis) before modifying production code (project memory rule).
- If a new SF surfaces (predicted: missing audit on rejection = SF-006; possibly race condition = SF-007), document in analysis/security-findings.md BEFORE patching. Severity assessment required.

CLOSE-OUT ORDER (PD-004 lesson):
1. FIRST write docs/sprints/T2-gap-analysis.md using docs/sprints/_gap-analysis-template.md. Include DoD verification table, test counts, any SF/PD found.
2. THEN update docs/traceability-matrix.md — fill rows for LIC-01, AUTH-WEB-03, USR-09, AUTH-API-06 (algorithm + key size).
3. THEN update analysis/security-findings.md (SF-006 / SF-007 if applicable, ROI section refreshed).
4. THEN update analysis/process-deviations.md if any new deviation arose.
5. FINALLY update PROJECT_STATUS.md — T2 row → closed; cumulative test counts refreshed.

VERIFICATION before commit:
- Run FULL Tests.Security suite (not isolated subset). Expected: ~166-170 / 0 / 0 (146 baseline + T2 additions).
- Re-run a second time in the same process. Same result. (PD-003 lesson — flaky state catches.)

Commit message:
  test(Sprint T2): licensing + force-logout + JWT key configuration — LICENSE-USER enforcement with audit, AUTH-WEB-03 SecurityStamp invalidation, AUTH-API-06 RS256/2048 verification (LIC-01, AUTH-WEB-03, USR-09, AUTH-API-06)

Architect will review T2 before closing the sprint.
```

---

## 8. Sprint close-out checklist

(Mirrors §7 close-out order; restated for clarity.)

1. **FIRST artefact** (PD-004 lesson): `docs/sprints/T2-gap-analysis.md`.
2. Update `docs/traceability-matrix.md`: LIC-01 row, AUTH-WEB-03 row,
   USR-09 row, AUTH-API-06 algorithm + key size rows.
3. Update `analysis/security-findings.md` with any new SF (SF-006 /
   SF-007 likely candidates from the pre-test prediction list).
4. Update `analysis/process-deviations.md` if any deviation occurred.
5. Update `PROJECT_STATUS.md`: T2 row → ✅ Closed; cumulative totals
   refreshed.
6. Decide next: T3 (blocked by B1 #11), T5 (Phase A independent),
   or B1 #11 itself.
