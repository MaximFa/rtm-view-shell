# Sprint T4: Permission Group authorization semantics

**Status:** **Approved — ready for execution** *(all §2 micro-choices signed off 2026-05-25)*
**Window:** ~3 working days (~20-25 tests; single phase per T1 baseline)
**Owner:** Claude Code (executing per this brief once §2 signed)
**Related sprints:** T1 (security & cross-tenant isolation) — reuses fixtures
**Related TS sections:** §15 (Permission model), §16 (Audit log — PG events), CLAUDE.md PG-01..07
**Related ADRs:** ADR-006 (PG model)

---

## 1. Scope

### Why T4 exists

The permission system has substantial existing CRUD coverage at the
unit-test level (~15 tests in `Tests.Unit/Commands/*PermissionGroup*`
and `Tests.Unit/Queries/GetPermissionGroupsQueryHandlerTests`).
What it lacks is **semantic** and **integration** coverage:

- Does `AuthorizationBehavior` actually reject unauthorized requests, or
  is it currently a permissive log statement? (Inspection of
  `src/CcDashboard.Application/Behaviors/AuthorizationBehavior.cs:51-61`
  shows a TODO — the `RequiredPermission` lookup is not wired. This is
  a likely SF candidate.)
- Does Redis cache invalidation work end-to-end when a PG is edited,
  or only in mock? (PG-07.)
- Does the AccessLevel bitmask compose correctly under union semantics
  when a user has memberships in multiple effective layers?
- Are PG-related audit events actually written? Subtypes correct?
- Does dashboard creation auto-grant Full to the creator's PG? (PG-01.)
- Does an empty CC-resource permission list correctly mean "denied"
  (per PG-03), not "all"? This is the inverse of a common bug shape
  and worth a hard test.

T4 closes these gaps using the fixtures established in T1.

### In scope

| Cluster | Requirements covered |
|---|---|
| **Authorization enforcement** | PG-04 (Application-layer enforcement, not UI-only), `AuthorizationBehavior` `RequiredPermission` lookup |
| **Resource permission semantics** | PG-03 (empty list = denied for queues / agent groups / supergroups / business units) |
| **AccessLevel bitmask** | View=1, Edit=2 (mask 3), Delete=4 (mask 5), Full=7; union semantics |
| **PG lifecycle integrity** | PG-01 (creator auto-Full on dashboard create), PG-06 (cannot delete PG with users — confirms current unit test holds at integration level), PG-07 (Redis cache invalidation on PG edit) |
| **Audit events** | `PermissionGroup.{Created,Updated,Deleted,PermissionChanged}` per CLAUDE.md §16 |
| **Superadmin bypass** | Superadmin bypasses PG checks across all tested code paths |

### Explicitly out of scope

- Menu permission enforcement in Razor components (UI-layer). T4 enforces
  at the Application layer only — UI hiding is cosmetic per PG-04.
- Voluntary `IRequiresPermission` *instantiation* on every command/query
  that currently lacks it. This is a separate audit task (`docs/sprints/T?-permission-marker-audit.md`),
  not T4. T4 verifies that **declared** permissions work; coverage of
  **missing** declarations is left to a follow-up.
- 2FA / SSO interactions with PG (Deferred per DEF-03 / DEF-04).
- Widget catalog permissions (WGT-* — Sprint T5).
- Cross-tenant PG behaviour (covered by T1 ARCH-01).
- Performance / load testing of permission resolution.

---

## 2. Architectural micro-choices (gate — answer before coding)

### MC-1. Database — inherited from T1 MC-1

Testcontainers PostgreSQL 16. **No change.**
→ **Decision: A — inherited from T1.** Approved 2026-05-25.

### MC-2. Identity stack — inherited from T1 MC-2 (adapted)

For T4, most authorization tests run at the MediatR pipeline level —
they need `ICurrentUserAccessor` with a stamped `UserId` / `TenantId` /
`Role` / `PermissionGroupId`, but they do not need a real auth pipeline.
Use a test-only `StubCurrentUserAccessor` configured per-test.

For the one or two end-to-end "send command, hit controller / page,
verify rejection" tests (DoD-3), reuse `WebFixture` from T1 Phase C.

→ **Decision: A — Stub `ICurrentUserAccessor` for pipeline tests; reuse `WebFixture` for end-to-end.** Approved 2026-05-25.

### MC-3. Audit assertion — inherited from T1 MC-3

Hybrid: Moq spy in `Tests.Unit`; real DB read in `Tests.Security`.

→ **Decision: C — inherited from T1.** Approved 2026-05-25.

### MC-4. Test naming + Trait — inherited from T1 MC-4

`MethodName_Scenario_ExpectedBehaviour` + mandatory `[Trait("Req", "PG-XX")]`.

→ **Decision: A — inherited from T1.** Approved 2026-05-25.

### MC-T4-1 (NEW). Permission enforcement implementation site

`AuthorizationBehavior.cs:51-61` currently has a TODO — `RequiredPermission`
lookup is not enforced. T4 *must* either fix this gap as part of the
sprint, or document it as out-of-scope and rely on an external follow-on
task.

- **A.** Fix the TODO as part of T4 — introduce `IPermissionService` in
  Domain interfaces, implement in Infrastructure with Redis cache lookup
  (`{tenantId}:pg_permissions:{pgId}` per CLAUDE.md PG-07), wire into
  `AuthorizationBehavior`. T4 tests cover both the new service and the
  end-to-end enforcement.
- **B.** Leave the TODO; T4 tests only assert what already works (role
  check, tenant context check, Superadmin bypass). Add `RequiredPermission`
  enforcement as a separate follow-on sprint.

**Recommendation: A.** The TODO is a **production security gap** —
any command/query that declares `RequiredPermission` is currently
unprotected at the Application layer. PG-04 explicitly forbids relying
on UI hiding. Leaving the gap unfixed while writing tests around it
would be a documented production vulnerability with no remediation
target. Implementing the fix turns T4 from "test-only" into
"test + production code", but the production code surface is small
(a service interface + implementation + 1 line of behaviour code)
and the security value is high. SF likely surfaces during this work —
document per PD-NNN pattern if it does.

→ **Decision: A — fix the TODO; pre-approve `IPermissionService` interface in Domain + Infrastructure implementation + AuthorizationBehavior wiring.** Approved 2026-05-25.

### MC-T4-2 (NEW). PG-07 cache invalidation testing

- **A.** Real Redis via Testcontainers (`RedisFixture` from T1 inherits).
  Tests verify Redis key is actually written / removed.
- **B.** Moq spy on `ICacheService.RemoveAsync` — fast but only proves
  the call was made, not that Redis state changed.

**Recommendation: A.** PG-07's whole point is that **active sessions
get fresh permissions on next interaction**. If `RemoveAsync` is
called but the key isn't actually purged (wrong key format, prefix
collision per ARCH-08), permissions get stale. A Moq spy can't catch
that. Real Redis costs ~2 seconds of test wall time; T1 already runs it.

→ **Decision: A — real Redis via Testcontainers (reuse T1 `RedisFixture`).** Approved 2026-05-25.

### MC-T4-3 (NEW). AccessLevel bitmask test style

- **A.** `[Theory]` with `MemberData` enumerating all (AccessLevel,
  RequestedAction, ExpectedAllow) combinations. ~30 rows.
- **B.** Individual `[Fact]` methods per scenario — fewer but
  more readable.
- **C.** Property-based via FsCheck — generate random valid masks,
  assert union / intersection invariants.

**Recommendation: A.** This is exactly the pattern T1 SF-003 lesson
called out — enum/bitmask guards must be tested across all values, not
just "interesting" ones. `[Theory]` + `[Trait("Req", "PG-04")]` makes
the traceability matrix line up cleanly. C (FsCheck) is overkill for
a 3-bit mask; B (individual Facts) tempts gaps.

→ **Decision: A — `[Theory]` + `MemberData` enumerating all combinations.** Approved 2026-05-25.

### MC-T4-4 (NEW). Test location

- **A.** New folder `tests/CcDashboard.Tests.Security/Authorization/`
  containing T4's new test classes. Existing unit tests stay where
  they are (`Tests.Unit/Commands/*PermissionGroup*`).
- **B.** Extend existing unit test files in-place with new test methods.

**Recommendation: A.** Existing unit tests are pure handler logic
(NSubstitute mocks, no fixtures). T4 tests are integration (real DB,
real Redis, MediatR pipeline) — they need the `[Collection("Security")]`
machinery from T1. Mixing styles in one file is confusing and slows the
fast unit-test run. Keep them separate.

→ **Decision: A — new folder `tests/CcDashboard.Tests.Security/Authorization/`.** Approved 2026-05-25.

---

## 3. Definition of Done

- **DoD-1: `AuthorizationBehavior` `RequiredPermission` enforcement.**
  (Per MC-T4-1 decision A.) `IPermissionService` interface in Domain;
  Infrastructure implementation reads from Redis with
  `{tenantId}:pg_permissions:{pgId}` key; `AuthorizationBehavior:55-60`
  TODO replaced with real call. Carries `[Trait("Req", "PG-04")]`.
- **DoD-2: Authorization rejection tests.** ≥3 tests verify:
  (a) authenticated user without required permission → `ForbiddenException`;
  (b) authenticated Superadmin → bypasses regardless of declared permission;
  (c) authenticated user with required permission → request proceeds.
- **DoD-3: End-to-end UI rejection (representative).** 1 test via
  `WebFixture`: a route protected by `[Authorize]` + `IRequiresPermission`
  returns 403/redirect when the user lacks the permission. Demonstrates
  PG-04 spans the full stack, not just MediatR. Carries
  `[Trait("Req", "PG-04")]`.
- **DoD-4: PG-03 empty list = denied.** Four parametrised tests (one per
  resource type: queues, agent groups, supergroups, business units):
  user with PG that has an *empty* CC-resource list cannot access *any*
  object of that type via the relevant filtered query. Inverse of
  "empty = all" bug. `[Trait("Req", "PG-03")]`.
- **DoD-5: AccessLevel bitmask semantics.** `[Theory]` covering all
  combinations: View(1), Edit(3=View+Edit), Delete(5=View+Delete),
  Full(7=View+Edit+Delete), plus 0 = no access, plus invalid masks
  (2, 4, 6 — Edit/Delete without View) → defined behaviour (whichever
  contract holds: implicit View, or reject). Audit the actual contract
  in `Dashboard.cs` / `PermissionGroup.cs` and lock it down with tests.
  `[Trait("Req", "PG-04")]`.
- **DoD-6: Union semantics.** If a user's PG has Edit on dashboard A
  via one assignment and View only via another (hypothetical — confirm
  schema permits), the effective permission is Edit (most permissive
  wins). If schema disallows multi-assignment per (PG, Dashboard), this
  DoD becomes "single-assignment is enforced by unique constraint" —
  verify via DB write attempting duplicate. `[Trait("Req", "PG-04")]`.
- **DoD-7: PG-01 creator auto-grant Full.** Integration test: create a
  dashboard via `CreateDashboardCommand` with a creator whose PG is X;
  query `dashboard_permissions` and verify `PermissionGroupId = X`,
  `AccessLevel = 7`. `[Trait("Req", "PG-01")]`.
- **DoD-8: PG-06 cannot delete with users (integration).** Migrate the
  existing unit test to `Tests.Security/Authorization/DeletePgWithUsersTests`
  using real DB (not mock repo): create PG, assign user, attempt delete,
  expect rejection with user count surfaced. `[Trait("Req", "PG-06")]`.
- **DoD-9: PG-07 Redis cache invalidation.** Integration test: write a
  permission resolution result into Redis at key
  `{tenantId}:pg_permissions:{pgId}`; call `UpdatePermissionGroupCommand`;
  assert key is gone from Redis. (Real Redis per MC-T4-2.)
  `[Trait("Req", "PG-07")]`.
- **DoD-10: Audit events written.** 4 tests verify
  `PermissionGroup.{Created,Updated,Deleted,PermissionChanged}` audit
  entries appear in `audit.audit_logs` with correct
  `EventType` / `Details.PermissionGroupId`. Use real DB read pattern
  inherited from T1 MC-3. `[Trait("Req", "AUD-01")]`.
- **DoD-11: Test count.** ≥20 passing tests in
  `tests/CcDashboard.Tests.Security/Authorization/` + any extensions of
  `Tests.Unit/Behaviors/` (new folder for `AuthorizationBehavior` tests
  if MC-T4-1 = A). Zero skipped tests.
- **DoD-12: Coverage.** `dotnet test --collect:"XPlat Code Coverage"`
  shows ≥75% line coverage on
  `src/CcDashboard.Application/Behaviors/AuthorizationBehavior.cs` and
  `src/CcDashboard.Application/Commands/PermissionGroups/*.cs`.
  `Infrastructure` coverage does not regress below T1 baseline (87.88%).
- **DoD-13: Gap analysis filed.** `docs/sprints/T4-gap-analysis.md`
  using the standard template. Update `docs/traceability-matrix.md`
  Permission Groups + Audit sections. Document any new SF / PD
  discovered.

---

## 4. Known limitations

- T4 does **not** audit every existing command / query for missing
  `IRequiresPermission` declarations. A command without the marker today
  is implicitly "any authenticated user can call it" — that's a
  potential gap but out of T4 scope. Backlog candidate.
- Multi-assignment of a (PG, Dashboard) pair is presumed forbidden by
  composite PK; if DoD-6 reveals otherwise, escalate as a finding.
- T4 does not test menu visibility in Razor components (cosmetic per
  PG-04). UI-layer hiding tests are owned by a future UI sprint.
- `RequiredPermission` syntax / vocabulary is whatever the existing
  `IRequiresPermission` interface defines. T4 doesn't redesign it; if
  the existing string-key format is too coarse, propose ADR-013 as a
  follow-up.

---

## 5. Open questions

- **OQ-T4-1:** Does the Permission Group model permit a user to belong
  to multiple PGs, or strictly one? CLAUDE.md §15 says "exactly one";
  schema (`ApplicationUser.PermissionGroupId : Guid?`) confirms.
  Therefore "union semantics" in DoD-6 is across permission *layers*
  within a single PG, not across PGs. Document the resolution in the
  brief once tests confirm.
- **OQ-T4-2:** Is there an existing `IPermissionService` skeleton that
  MC-T4-1 should extend, or does T4 introduce the interface fresh?
  (Grep `src/` for `IPermissionService` before writing.)
- **OQ-T4-3:** What is the contract for AccessLevel = 0 (no permission
  row at all vs row with mask 0)? Determine empirically in DoD-5; if
  ambiguous, escalate.

---

## 6. Implementation notes

### Existing artefacts to inspect first

- `src/CcDashboard.Application/Behaviors/AuthorizationBehavior.cs` —
  the TODO at L51-61 is the key implementation site.
- `src/CcDashboard.Application/Commands/PermissionGroups/UpdatePermissionGroupCommand.cs:88`
  — `cache.RemoveAsync($"{group.TenantId}:pg_permissions:{group.Id}", ct)`
  already implemented; tests verify it works.
- `src/CcDashboard.Domain/Domain/PermissionGroup.cs` and
  `src/CcDashboard.Domain/Domain/DashboardPermission.cs` — the
  AccessLevel semantics live here.
- `tests/CcDashboard.Tests.Unit/Commands/*PermissionGroup*` — existing
  unit tests, NSubstitute-based; DO NOT modify, only extend or
  complement.
- `tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs` +
  `RedisFixture.cs` + `WebFixture.cs` — reuse all from T1.

### Recommended file structure

```
tests/CcDashboard.Tests.Security/Authorization/
├── AuthorizationBehaviorTests.cs       (DoD-2, MC-T4-1)
├── EndToEndAuthorizationTests.cs       (DoD-3, uses WebFixture)
├── EmptyResourceListDenialTests.cs     (DoD-4)
├── AccessLevelBitmaskTests.cs          (DoD-5, DoD-6 — [Theory])
├── DashboardCreatorAutoGrantTests.cs   (DoD-7, integration)
├── DeletePgWithUsersTests.cs           (DoD-8, integration migration)
├── CacheInvalidationTests.cs           (DoD-9)
└── PermissionGroupAuditTests.cs        (DoD-10)
```

If MC-T4-1 = A (production fix):

```
src/CcDashboard.Domain/Interfaces/IPermissionService.cs      (NEW)
src/CcDashboard.Infrastructure/Services/PermissionService.cs (NEW)
src/CcDashboard.Application/Behaviors/AuthorizationBehavior.cs (MODIFIED — replace TODO)
```

### Approximate effort sizing

- IPermissionService design + impl + behaviour wiring (MC-T4-1=A): ~5h.
- AuthorizationBehavior tests (DoD-1, DoD-2): ~3h.
- End-to-end test (DoD-3): ~2h.
- Empty-list denial tests (DoD-4): ~2h.
- AccessLevel bitmask tests (DoD-5, DoD-6): ~3h.
- Lifecycle tests (DoD-7, DoD-8): ~3h.
- Cache invalidation test (DoD-9): ~1.5h.
- Audit event tests (DoD-10): ~2.5h.
- Gap analysis + traceability update (DoD-13): ~1h.
- **Total: ~23h** (≈ 3 working days at ~7-8 h/day).

### Likely production findings (pre-test prediction)

Based on inspection during planning:

1. **`AuthorizationBehavior.RequiredPermission` enforcement gap**
   (line 51-61 TODO) — high confidence this surfaces as SF-005.
   Mitigation: MC-T4-1 = A folds the fix into T4.
2. Whether the `pg_permissions` Redis key format actually matches
   between `UpdatePermissionGroupCommand` (writer) and the future
   `IPermissionService` (reader) — verify alignment up front.

These are not in security-findings.md yet — they'll be filed there
during T4 close-out per the SF-NNN pattern.

---

## 7. Hand-off to Claude Code

When the architect signs the four `TBD` lines in §2 (MC-T4-1..T4-4),
paste the following into Claude Code:

```
[Sprint T4 handover]

Read these files first, in order:
- docs/sprints/T4-pg-authorization-semantics.md
- analysis/process-deviations.md (PD-001 / PD-002 — apply lessons)
- docs/sprints/T1-security-and-tenant-isolation.md (for inherited MC context)
- src/CcDashboard.Application/Behaviors/AuthorizationBehavior.cs (the TODO at L51-61)

Architect has signed §2 micro-choices (date: <fill in>).
Use those decisions as authoritative. Implement DoD-1 through DoD-13.

Working agreement:
- Every new test method carries [Trait("Req", "PG-XX" | "AUD-01" | "PG-04")]
  per the §3 mapping.
- Reuse existing PostgresFixture / RedisFixture / WebFixture from T1.
  Do NOT create new container-spinning fixtures unless absolutely
  required; if needed, justify in the gap analysis.
- Production code changes:
  * If MC-T4-1 = A, the introduction of IPermissionService +
    PermissionService is in-scope and pre-approved. Keep the surface
    minimal: one interface in Domain, one implementation in
    Infrastructure, one line of wiring in AuthorizationBehavior.
  * `public partial class Program {}` in src/CcDashboard.Web/Program.cs
    already exists (Phase C) — do not duplicate or modify it. If a
    new partial-class shim is needed for CcDashboard.Api, that change
    is pre-approved (PD-001 lesson; same standard Microsoft pattern).
  * ANY OTHER production code change — `virtual` modifiers, new
    abstractions, public type expansions outside the IPermissionService
    surface above — requires architect approval. Abort and report
    before proceeding (PD-002 lesson).
- On failure: diagnostics first (expected vs actual + root-cause
  hypothesis) before modifying production code (project memory rule).
- If `AuthorizationBehavior` TODO replacement uncovers a bug in
  existing code paths (likely SF-005), document in
  analysis/security-findings.md before patching. Severity assessment
  required.
- On completion: file docs/sprints/T4-gap-analysis.md, update
  docs/traceability-matrix.md Permission Groups + Audit sections,
  log any SF / PD discovered, commit with message:
  test(Sprint T4): PG authorization semantics — AuthorizationBehavior
  enforcement, empty-list denial, AccessLevel bitmask, PG lifecycle +
  cache invalidation + audit events (PG-01/03/04/06/07, AUD-01)

Architect will review T4 before closing the sprint.
```

---

## 8. Sprint close-out checklist

When DoD-1..13 all ✅:

1. File `docs/sprints/T4-gap-analysis.md` using `_gap-analysis-template.md`.
2. Update `docs/traceability-matrix.md`:
   - Permission Groups (PG-01..07) section: fill from TBD/empty to
     concrete test class names.
   - Audit (AUD-01..08) section: at least AUD-01 row added with
     `PermissionGroupAuditTests`.
3. Update `analysis/security-findings.md` if new SFs surface
   (continuing SF-005, SF-006, ... numbering from SF-004).
4. Update `analysis/process-deviations.md` if any new working-agreement
   deviations occur (continuing PD-003, ... from PD-002).
5. Update `PROJECT_STATUS.md`: T4 marked ✅ Closed; sprint totals
   refreshed; backlog adjusted.
6. Decide next sprint: T2 (no blockers) or B1 #11 (unblock T3 / T5).
