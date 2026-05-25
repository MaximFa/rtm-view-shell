# Sprint T6: User Management + Audit Trail

**Status:** **Approved — ready for execution** *(all §2 micro-choices signed 2026-05-25)*
**Phases:** A (User Management) · B (Audit Trail)
**Estimate:** ~4 h Phase A (~32 tests) + ~3 h Phase B (~22 tests) = ~7 h total
**Unblocked by:** T5 (widget framework), D1 (docs), #13 (IDatabaseInitializer)
**Unblocks:** 2FA/SSO testing (A — deferred to just before widget development)
**Related TS:** §19 (User management USR-01..14), §16 (Audit AUD-01..08), §15 (Permission model)

---

## 1. Scope

### Why T6 exists

T1–T5 covered auth flows, multi-tenancy, licensing, permission-group semantics, and widget
framework. T6 closes two remaining functional clusters that have **no test coverage** today:

- **User Management (USR-01..14):** create / update / deactivate / delete users with full
  role + tenant isolation constraints; forced password change; admin reset; force-logout;
  pagination + filter API; cross-tenant isolation guard.
- **Audit Trail (AUD-02..08):** INSERT-only guarantee for `audit.audit_logs`; role-aware
  scoping of `GetAuditLogsQuery`; IP extraction from `X-Forwarded-For`; `User.*` audit
  events for every user-management operation; CSV export boundary.

Audit events for user operations are tested in Phase B as integration assertions against
`AuditDbContext` — the same approach used in `PermissionGroupAuditTests` (T4).

### Pre-existing production gaps (found during brief preparation — fix as part of T6)

| Gap ID | File | Issue | Requirement |
|---|---|---|---|
| **GAP-T6-01** | `UserManagementService.UpdateAsync` | Emits only `User.Updated`; does **not** emit `User.RoleChanged` when `Role` changes or `User.PermissionGroupChanged` when `PermissionGroupId` changes | USR-07, §16 |
| **GAP-T6-02** | `UserManagementService.UpdateAsync` / `DeleteAsync` | Looks up user by `userId` with no tenant ownership check — cross-tenant mutation possible if `userId` leaks across tenants | USR-05, ARCH-01 |
| **GAP-T6-03** | `UserManagementService.UpdateAsync` | No guard for "Admin cannot change own role" (USR-08) | USR-08 |

These three production fixes must be committed **before** the tests that assert them.

### In scope — Phase A (User Management)

| Cluster | Requirements |
|---|---|
| Create user | USR-01 (roles that can create), USR-02 (required fields), USR-03 (temp password + MustChangePasswordAt), USR-04 (email uniqueness within tenant), USR-05 (Admin cannot create Superadmin or cross-tenant) |
| Update user | USR-06 (editable fields), USR-07 (Role/PG change → audit event), USR-08 (Admin cannot change own role) |
| Deactivation / force-logout | USR-09 (deactivation → SecurityStamp rotated → sessions invalidated) |
| Password reset | USR-11 (admin-initiated token, TTL 24 h, email sent), USR-12 (self-service reset → uniform response regardless of email existence) |
| List / filter | USR-13 (server-side pagination, sort, filter by role/PG/status/search), USR-14 (Admin sees own tenant only; Superadmin sees all) |

### In scope — Phase B (Audit Trail)

| Cluster | Requirements |
|---|---|
| Write isolation | AUD-01 (audit write survives business TX rollback — separate `AuditDbContext`) |
| INSERT-only constraint | AUD-02 (no UPDATE/DELETE via app_role — DB-level enforcement test) |
| Retention | AUD-03 (retention config read from `TenantSettings.AuditRetentionDays`; `System.AuditPurged` event fired) |
| IP extraction | AUD-04 (`X-Forwarded-For` via `ForwardedHeadersOptions` → stored in `audit_logs.IpAddress`) |
| User.* audit events | AUD-05 (verify `User.Created`, `User.Updated`, `User.RoleChanged`, `User.PermissionGroupChanged`, `User.Deactivated`, `User.Activated`, `User.Deleted`, `User.RoleChanged` in audit_logs after each user management operation) |
| Audit log query | AUD-06 (role-aware scoping: Admin sees own tenant; Superadmin sees all; tenant filter param) |
| CSV export boundary | AUD-08 (≤50 000 records → return data; >50 000 → async job stub / 202 Accepted) |

### Explicitly out of scope

- 2FA and SSO testing (deferred — done just before widget development)
- `i18n` / localisation tests (deferred, no known security risk)
- Widget rendering, drag-and-drop layout (out of scope for the whole shell)
- Audit log monthly partition management (background service, out of scope for T6)
- Full `AUD-07` Dashboard audit events (Dashboard.Created/Updated/Deleted already covered
  implicitly by T5 DashboardWidget tests; dedicated Dashboard audit T7 if needed)

---

## 2. Architectural micro-choices (gate — signed 2026-05-25)

All T1 baseline choices inherited: Testcontainers PostgreSQL, real ASP.NET Core Identity
for integration tests, `[Trait("Req","...")]` markers, shared fixtures.

### MC-T6-1. User management test level: service-level or HTTP-level?

- **A. Service-level integration** (inject `IUserManagementService` with `PostgresFixture`
  DbContext, real `UserManager<ApplicationUser>`): tests the enforcement logic directly;
  fast; same pattern as T3/T4 `PermissionGroupRepository` tests. Cannot test HTTP middleware
  (CSP headers, rate limiting) — but those are covered by T1.
- **B. HTTP-level** (WebApplicationFactory with real endpoints): tests the full stack
  including routing and serialisation; slower; harder to assert audit events.
- **Recommendation: A** — USR-01..14 are about service/domain constraints (tenant
  isolation, role guards, pagination), not HTTP transport. HTTP endpoints are thin
  controllers. WebFixture already used for security-header tests (T1).

`Decision: A — service-level integration (PostgresFixture + UserManager + IUserManagementService)`

### MC-T6-2. GAP fixes: in same PR as tests or separate commit?

- **A. Same PR** (fix production code first in the commit, then add tests that assert the
  fix): atomic; tests document the fix; reviewers see cause and effect together.
- **B. Separate PR** (production fix first, tests in follow-up): cleaner blame history;
  unnecessary overhead for a small sprint.
- **Recommendation: A** — GAP-T6-01..03 are ≤20 lines of production code total; fix +
  test in the same commit per DoD-1.

`Decision: A — fixes + tests in same commit`

### MC-T6-3. Audit INSERT-only constraint (AUD-02): DB permission test or assertion test?

- **A. DB permission test** (connect as `app_role` and attempt `UPDATE` / `DELETE` on
  `audit.audit_logs` via raw SQL; assert `PostgresException` / "permission denied"):
  proves the DB-level `REVOKE` is actually in place (migration must include the REVOKE).
- **B. Application assertion test** (verify `AuditService.LogAsync` only calls INSERT via
  `SaveChangesAsync`; no `Update`/`Delete` entry points exist in `AuditDbContext`): tests
  the application boundary, not the DB permission.
- **Recommendation: A** — the spec says "enforce with REVOKE UPDATE, DELETE" which is a
  DB fact. Tests should verify the enforcement exists. Requires: (1) check migration has
  `REVOKE` statement, (2) integration test connecting as `app_role` attempting UPDATE.

`Decision: A — DB permission test + migration REVOKE verification`

### MC-T6-4. IP extraction (AUD-04): unit test on middleware or integration test?

- **A. Integration test** (WebApplicationFactory with custom `X-Forwarded-For` header;
  send request to a protected endpoint; assert `audit_logs.IpAddress` = forwarded IP):
  end-to-end proof that `ForwardedHeadersOptions` + `UseForwardedHeaders` is wired.
- **B. Unit test** (mock `HttpContext.Connection.RemoteIpAddress` + `X-Forwarded-For`
  header; call middleware method directly): faster, but misses the `AddForwardedHeaders`
  wiring in `Program.cs`.
- **Recommendation: A** — AUD-04 is specifically about the wiring (middleware order,
  trusted proxy config). An integration test is the only way to prove it works end-to-end.
  Use `WebFixture` + custom request header.

`Decision: A — WebApplicationFactory integration test with X-Forwarded-For header`

### MC-T6-5. CSV export (AUD-08): full data generation or boundary unit test?

- **A. Boundary unit test** (mock `IAuditLogRepository.CountAsync` to return 50 001;
  assert the query handler returns HTTP 202 Accepted / async job token; no actual 50k rows):
  tests the branching logic without slow data generation.
- **B. Integration test with real data** (insert 50 001 rows into `audit_logs` via
  `AuditDbContext`; call export endpoint; assert 202): proves the COUNT query works but
  adds significant test setup time.
- **Recommendation: A** — the security-relevant assertion is the branching logic
  (≤50k → data, >50k → 202). Inserting 50k rows is expensive and tests a DB truism.
  Use B only for the ≤50k happy path (insert a small set, assert CSV rows match).

`Decision: A — boundary unit test for >50k branch; small integration test for ≤50k happy path`

### MC-T6-6. Test file location: Tests.Security or new Tests.Integration project?

- **A. Tests.Security** (consistent with T1–T5; user management is fundamentally about
  authorization + isolation + audit, all security concerns): keeps the T6 cohesive with
  the existing programme; uses `[Collection("Postgres")]` for DB-backed tests.
- **B. New Tests.Integration** project: better separation of concerns long-term; but
  adds setup overhead and breaks the T1–T5 convention mid-programme.
- **Recommendation: A** — stay consistent with T1–T5 through T6; refactor into separate
  projects in a future housekeeping sprint.

`Decision: A — Tests.Security, [Collection("Postgres")] for integration tests`

---

## 3. Definition of Done

### Phase A — User Management

- **DoD-A1: GAP fixes landed.** GAP-T6-01 (`User.RoleChanged` / `User.PermissionGroupChanged`
  events in `UpdateAsync`), GAP-T6-02 (tenant ownership check in `UpdateAsync`/`DeleteAsync`),
  GAP-T6-03 (self-role-change guard for Admin) are fixed in production code before any
  tests run. `dotnet build` passes.

- **DoD-A2: Create user — success path.** ≥ 3 integration tests: (a) Administrator
  creates user in own tenant → user exists in DB, `MustChangePasswordAt` is set, audit
  `User.Created` written; (b) Superadmin creates user in any tenant; (c) Viewer/Editor role
  cannot invoke `CreateAsync` (returns permission error). Covers **USR-01, USR-02, USR-03**.

- **DoD-A3: Create user — uniqueness.** ≥ 2 tests: (a) duplicate email within same tenant
  → error; (b) same email in different tenant → succeeds (email unique per tenant, not
  globally). Covers **USR-04**.

- **DoD-A4: Admin cross-tenant / Superadmin creation guard.** ≥ 2 tests: (a) Admin
  attempting to create Superadmin → rejected; (b) Admin attempting to create user in a
  different `tenantId` → rejected with tenant mismatch error. Covers **USR-05**.

- **DoD-A5: Update user — audit events.** ≥ 4 tests: (a) update non-role fields → only
  `User.Updated` written; (b) update with role change → `User.Updated` + `User.RoleChanged`
  (old role + new role in Details); (c) update with PG change → `User.Updated` +
  `User.PermissionGroupChanged`; (d) Admin attempting to change own role → rejected.
  Covers **USR-06, USR-07, USR-08** + **GAP-T6-01, GAP-T6-03**.

- **DoD-A6: Cross-tenant mutation guard.** ≥ 2 tests: (a) `UpdateAsync` with userId
  belonging to a different tenant → `NotFoundException` / rejected, no changes, no audit
  event; (b) `DeleteAsync` with cross-tenant userId → same result. Covers **GAP-T6-02**.

- **DoD-A7: Deactivation + force-logout.** ≥ 3 tests: (a) `SetActiveAsync(false)` →
  `IsActive = false` in DB, `SecurityStamp` changed, `User.Deactivated` audit; (b)
  `SetActiveAsync(true)` → `User.Activated` audit; (c) `ForceLogoutAsync` → `SecurityStamp`
  changed. Covers **USR-09**.

- **DoD-A8: Password reset flows.** ≥ 3 tests: (a) `AdminResetPasswordAsync` → token
  generated, email `SendAsync` called (mock `IEmailSender`), succeeds; (b)
  `RequestPasswordResetAsync` with known email → email sent; (c) `RequestPasswordResetAsync`
  with unknown email → **no exception, no error returned** (uniform response, BFP-03).
  Covers **USR-11, USR-12**.

- **DoD-A9: User list pagination + filter + tenant scoping.** ≥ 4 tests: (a) page 1 of 2
  returns correct subset; (b) filter by `IsActive=false` returns only inactive users; (c)
  filter by `Role` returns only matching role; (d) Superadmin with `TenantId=null` sees
  users across all tenants; Admin with no TenantId param sees only own tenant. Covers
  **USR-13, USR-14**.

- **DoD-A10: Phase A test count.** ≥ **32 passing tests** in
  `tests/CcDashboard.Tests.Security/UserManagement/`. All pass; 0 build warnings.

### Phase B — Audit Trail

- **DoD-B1: INSERT-only enforcement.** ≥ 2 tests: (a) application-level: `AuditDbContext`
  has no `Update`/`Delete` pathways exposed (assert via architecture test or EF
  `ChangeTracker` inspection); (b) DB-level: migration includes `REVOKE UPDATE, DELETE ON
  audit.audit_logs FROM app_role` — verify SQL script contains the REVOKE statement
  (grep migration output). Covers **AUD-02**.

- **DoD-B2: Audit write isolation (AUD-01).** ≥ 1 integration test: simulate a business
  transaction that writes a user, writes an audit event, then throws — assert business TX
  rolled back (user not in DB) but audit log row **persists** in `AuditDbContext`
  (separate connection). Covers **AUD-01**.

- **DoD-B3: IP extraction from X-Forwarded-For.** ≥ 2 integration tests using
  `WebApplicationFactory`: (a) request with `X-Forwarded-For: 203.0.113.5` header →
  `audit_logs.IpAddress = '203.0.113.5'` after a login attempt; (b) request without header
  → IP is the direct connection address (not null). Covers **AUD-04**.

- **DoD-B4: User.* audit events — complete coverage.** ≥ 6 integration tests against
  `AuditDbContext` asserting rows exist with correct `EventType` after each operation:
  `User.Created`, `User.Updated`, `User.RoleChanged`, `User.PermissionGroupChanged`,
  `User.Deactivated`, `User.Activated`. (GAP-T6-01 fix required for 3 of these.)
  Covers **AUD-05**.

- **DoD-B5: Audit log query — role-aware scoping.** ≥ 3 tests: (a) `GetAuditLogsQuery`
  with Admin token → returns only own-tenant logs (no other-tenant rows); (b) Superadmin
  with no filter → returns all-tenant logs; (c) Superadmin with explicit `TenantId` filter
  → returns only that tenant's logs. Covers **AUD-06**.

- **DoD-B6: CSV export boundary.** ≥ 2 tests: (a) ≤50 000 records → handler returns data
  directly (or structured `PagedResult`); (b) repository count > 50 000 → handler returns
  indicator for async job (e.g. `null` result + `isAsyncRequired=true` flag, or `202`
  response from API endpoint). If export endpoint/query does not yet exist → add stub as
  part of T6 and test the stub. Covers **AUD-08**.

- **DoD-B7: Retention config read.** ≥ 1 unit test: `TenantSettings.AuditRetentionDays`
  is read by the background service / retention handler; assert default is 365; assert
  tenant-override is respected. Covers **AUD-03**.

- **DoD-B8: Phase B test count.** ≥ **22 passing tests** in
  `tests/CcDashboard.Tests.Security/Audit/`. All pass; 0 build warnings.

### Combined close-out

- **DoD-C1: No regressions.** `dotnet test CcDashboard.sln` — all prior tests (T1–T5,
  313 + new T6 tests) pass; 0 build errors; 0 new warnings.

- **DoD-C2: Traceability matrix updated.** `docs/traceability-matrix.md` rows for
  USR-01..14 and AUD-01..08 populated.

- **DoD-C3: Security findings logged.** Any new SF found during T6 implementation
  documented in `docs/security-findings.md` as SF-NNN entries.

- **DoD-C4: PROJECT_STATUS updated.** Test counts, commit hashes, T6 status → Closed.

---

## 4. Known limitations

- **2FA session invalidation (USR-09):** `SecurityStamp` rotation terminates Blazor
  circuits only when `ValidateInterval` elapses (default 30 s in Identity). T6 does not
  test the Blazor circuit lifecycle — that requires a live browser or Playwright. The
  `UpdateSecurityStampAsync` call is tested; circuit termination is by design untested
  in this sprint.
- **Email delivery (USR-03, USR-11, USR-12):** `IEmailSender` is mocked — actual SMTP
  delivery is not tested. By design; SMTP integration is an ops concern.
- **AUD-03 partition drop:** The actual PostgreSQL partition management background service
  is not tested in T6 (requires time-travel or a partition with past month). DoD-B7 tests
  only the config-read path.
- **AUD-08 async job:** If a full async export job implementation does not exist yet, T6
  adds only the stub (DoD-B6). Full async job (file generation + email notification) is
  deferred to a future sprint.

---

## 5. Open questions

- **OQ-T6-01:** Does `app_role` exist in the PostgreSQL setup? The `REVOKE UPDATE, DELETE`
  statement in AUD-02 assumes a named `app_role`. Check migrations and
  `INSTALL.md` before writing DoD-B1. — *Status: Open*
- **OQ-T6-02:** `GetAuditLogsQuery` currently filters by `EventResult.ToString()` using
  string comparison. Confirm `AuditEventResult` enum serialises to `"Success"/"Failure"` —
  read `AuditEventResult.cs` before writing DoD-B5 filter tests. — *Status: Open*
- **OQ-T6-03:** Is there an existing CSV export endpoint / query for audit logs? If not,
  T6 must add the stub before testing it. Read `CcDashboard.Api/Controllers/` and
  `Application/Queries/Audit/` before DoD-B6. — *Status: Open*
- **OQ-T6-04:** `UpdateUserRequest` contains `Role` field — but does the Application layer
  enforce that role values are limited to the fixed set (`Superadmin/Administrator/Editor/
  Viewer`)? If not, add `FluentValidation` rule as part of GAP-T6-01 fix. — *Status: Open*

---

## 6. Key files to read before writing any code

```
src/CcDashboard.Infrastructure/Identity/UserManagementService.cs   ← GAP fixes here
src/CcDashboard.Application/Queries/Users/GetUsersQuery.cs
src/CcDashboard.Application/Queries/Audit/GetAuditLogsQuery.cs
src/CcDashboard.Infrastructure/Audit/AuditService.cs
src/CcDashboard.Infrastructure/Audit/AuditDbContext.cs
src/CcDashboard.Infrastructure/Persistence/Repositories/AuditLogRepository.cs
src/CcDashboard.Domain/Enums/AuditEventResult.cs                   ← OQ-T6-02
src/CcDashboard.Api/Controllers/                                    ← OQ-T6-03
tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs
tests/CcDashboard.Tests.Security/Authorization/PermissionGroupAuditTests.cs  ← pattern
docs/sprints/T6-user-audit.md                                       ← this file
```

---

## 7. Claude Code hand-off prompt

```
Read: docs/sprints/T6-user-audit.md

§2 micro-choices are all signed:
- MC-T6-1 = A (service-level integration with PostgresFixture + UserManager)
- MC-T6-2 = A (GAP fixes + tests in same commit)
- MC-T6-3 = A (DB permission test: verify REVOKE in migration SQL + pg permission test)
- MC-T6-4 = A (WebApplicationFactory integration test with X-Forwarded-For header)
- MC-T6-5 = A (boundary unit test for >50k; small integration for ≤50k happy path)
- MC-T6-6 = A (Tests.Security, [Collection("Postgres")] for integration tests)

Implement Sprint T6 per the brief. DoD-A1..A10 are Phase A acceptance criteria;
DoD-B1..B8 are Phase B criteria; DoD-C1..C4 are combined close-out.

**Start with Phase A:**
1. Write gap analysis (docs/sprints/T6-gap-analysis-phase-a.md) by reading the
   three GAP files listed in §1 — document current state vs. required state.
2. Apply production fixes for GAP-T6-01, GAP-T6-02, GAP-T6-03 in
   src/CcDashboard.Infrastructure/Identity/UserManagementService.cs.
3. Write tests in tests/CcDashboard.Tests.Security/UserManagement/.
4. Run dotnet test — confirm ≥32 new passing tests, 0 regressions.
5. Commit Phase A (fixes + tests together).

**Then Phase B:**
1. Write gap analysis (docs/sprints/T6-gap-analysis-phase-b.md) for audit gaps.
2. Resolve OQ-T6-01..04 by reading the files listed in §6.
3. Write tests in tests/CcDashboard.Tests.Security/Audit/.
4. Run dotnet test — confirm ≥22 new passing tests, 0 regressions.
5. Commit Phase B.

**Working agreement (inherited from T1–T5):**
- Write gap analysis FIRST, before any code (documents current vs. required state)
- All new test methods carry [Trait("Req","<REQ-ID>")] matching the DoD
- Use Python atomic writes for all file edits (§0.3 of CLAUDE.md)
- Verify tail -3 + wc -l after every file write (§0.3 of CLAUDE.md — NO EXCEPTIONS)
- On completion: update docs/traceability-matrix.md (DoD-C2) and
  PROJECT_STATUS.md (test counts, commit hashes)
- Commit all production code changes and test files together
- Run dotnet test CcDashboard.sln and confirm 0 failures before reporting done
- Report: gap-analysis paths, commit hashes, test counts per file, DoD status table
```
