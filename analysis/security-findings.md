# Security findings — RTM View Shell

Record of security-relevant bugs found during the v1.3 test-coverage
programme. Each finding has: detection context, severity assessment,
root cause, resolution commit, and impact-window estimate.

These findings justify the test investment and feed into future
audit reports.

---

## SF-001 — `ApplicationUser` missing Global Query Filter (GQF)

**Detected:** Sprint T1 Phase A (commit `ca0ccd9`, 2026-05-25)
**Severity:** 🔴 **Critical**
**Requirement violated:** ARCH-01 (Multi-tenancy isolation)

### Context

T1 Phase A test `GlobalQueryFilterTests.AppDbContext_QueryingUsers_FiltersToCurrentTenant`
attempted to verify that a user from TenantA is NOT visible when
`ITenantContext` is set to TenantB. The test failed — TenantA's user
was returned.

### Root cause

`AppDbContext.OnModelCreating` did not register the GQF for
`ApplicationUser`. Other multi-tenant entities (Dashboards,
PermissionGroups, etc.) had it; the Identity user was an outlier
because Identity entities are often configured separately.

### Impact (had this gone to production)

Any query against `identity.users` via `AppDbContext` would have
returned **users from all tenants** regardless of `ITenantContext`.
Cross-tenant data leak in any code path doing user lookups
(admin UI, user list, ad-hoc maintenance queries).

The Login flow itself was NOT vulnerable because the bug also
masked a separate logic issue (SF-002) — the auth service had
its own `TenantId` filter in the lookup. The vulnerability was
in everything *else* that read users.

### Resolution

Fixed in `src/CcDashboard.Infrastructure/Persistence/AppDbContext.cs:68-75`:

```csharp
modelBuilder.Entity<ApplicationUser>(e =>
{
    e.HasQueryFilter(x => x.TenantId == tenantContext.TenantId);
    // ... other configuration
});
```

Commit: `ca0ccd9`.

### Lesson / pattern

The `Tests.Architecture` project should enforce: every multi-tenant
entity has GQF registered. A reflection-based test scanning
`AppDbContext.Model.GetEntityTypes()` and checking
`IsMultiTenant attribute → HasQueryFilter` would catch this class
of regression. Track as follow-up task.

---

## SF-002 — TenantMismatch detection silently failed

**Detected:** Sprint T1 Phase A (commit `ca0ccd9`, 2026-05-25)
**Severity:** 🟠 **High** (security + observability)
**Requirements violated:** ARCH-04 (login tenant-match check), BFP-04 (audit subtype)

### Context

T1 Phase A test `TenantMismatchLoginTests.UserFromOtherTenant_AttemptingLoginInCurrentTenant_ReturnsInvalidCredentials_WithTenantMismatchSubtype`
expected user from TenantA logging into TenantB subdomain →
`Login.Failure` with subtype `TenantMismatch`. Test observed
`UserNotFound` subtype instead.

### Root cause

`IdentityAuthService.PasswordSignInAsync` (the login entry point)
performed user lookup with `WHERE Email = X AND TenantId = ctx.TenantId`.
Cross-tenant users could **never** be found by the query, so the
TenantMismatch branch was unreachable.

### Impact (had this gone to production)

- **Functional:** none directly (cross-tenant login still rejected — but
  with the wrong reason).
- **Audit / forensics:** failure reason in audit logs would always
  be `UserNotFound`, never `TenantMismatch`. Incident response
  could not distinguish "credential stuffing of unknown emails"
  from "directed attack on cross-tenant boundaries". Both forensic
  surfaces ARCH-04 promises were absent.
- **Compliance:** BFP-04 enumerates 5 failure subtypes including
  `TenantMismatch`; the system did not actually emit it. An auditor
  walking the audit log would have flagged this as broken control.

### Resolution

Fixed in `src/CcDashboard.Infrastructure/Identity/IdentityAuthService.cs:31-36`:
removed `TenantId` from the WHERE clause; perform `TenantId` match
as a separate check after the user is found, emitting
`Login.Failure` with `subtype = TenantMismatch` if they differ.

Commit: `ca0ccd9`.

### Lesson / pattern

Audit-log subtype assertions in tests catch this class of bug —
"feature appears to work, but emits wrong telemetry". For every
`Login.Failure` subtype in TS BFP-04, T1 has a test verifying the
emitted subtype matches the scenario.

---

## SF-003 — Deleted tenant did not block login

**Detected:** Sprint T1 Phase A (commit `ca0ccd9`, 2026-05-25)
**Severity:** 🟠 **High** (data-lifecycle integrity)
**Requirement violated:** ARCH-06 (Tenant lifecycle blocking semantics)

### Context

T1 Phase A test `SuspendedAndDeletedTenantTests.PasswordSignInAsync_TenantStatusDeleted_ReturnsInvalidCredentials`
expected: tenant with `Status = Deleted` blocks all login attempts
of its users. Test failed — login succeeded for an active user
in a `Deleted` tenant.

### Root cause

`IdentityAuthService.PasswordSignInAsync` checked only
`TenantStatus.Suspended`; the `Deleted` branch was missing entirely.
Per ARCH-06, both Suspended **and** Deleted must block login (the
30-day GDPR-deletion window keeps the tenant row alive but users
should not authenticate).

### Impact (had this gone to production)

A tenant marked `Deleted` (e.g., after contract termination,
during the 30-day data-export window) could still log in their
users. This would have:

- Allowed access to data scheduled for deletion (GDPR contract violation).
- Allowed continued data writes within a tenant marked for termination.
- Created audit anomalies (`Login.Success` events for `Deleted`
  tenants — confusing for incident response).

### Resolution

Fixed in `src/CcDashboard.Infrastructure/Identity/IdentityAuthService.cs:76-82`:
added explicit check for `TenantStatus.Deleted` returning
`InvalidCredentials` with appropriate audit subtype.

Commit: `ca0ccd9`.

### Lesson / pattern

Lifecycle-state guards must be tested for every state value in the
enum (not just the "interesting" one). Enum-driven parametrised
tests (xUnit `[Theory]` over `TenantStatus`) catch coverage gaps
on multi-state guards.

---

## SF-004 — JTI revocation crashes on zero/negative TTL

**Detected:** Sprint T1 Phase B (2026-05-25)
**Severity:** 🟡 **Medium** (reliability)
**Requirement violated:** AUTH-API-05 (JTI revocation)

### Context

T1 Phase B test `JtiRevocationTests.RevokeJtiAsync_ZeroOrNegativeRemaining_DoesNotAddKey`
expected that calling `RevokeJtiAsync` with `remaining = TimeSpan.Zero` would
silently skip the operation (already-expired tokens don't need revocation).
Test failed with `RedisServerException: ERR invalid expire time in 'setex' command`.

### Root cause

`TokenService.RevokeJtiAsync` passed the TTL directly to Redis `StringSetAsync`
without checking if it was zero or negative. Redis rejects `SETEX` with TTL <= 0.

### Impact (had this gone to production)

When force-logging-out a user whose access token had already expired,
the logout operation would throw an exception instead of completing cleanly.
This could leave the user in an inconsistent state — UI shows logout but
if other tokens existed, they might remain active.

### Resolution

Fixed in `src/CcDashboard.Infrastructure/Security/TokenService.cs`:
```csharp
public async Task RevokeJtiAsync(...)
{
    if (remaining <= TimeSpan.Zero)
        return;  // Skip — token already expired
    await _cache.StringSetAsync(...);
}
```

### Lesson / pattern

Defensive checks on time-based parameters before passing to external services.
Redis, Postgres, and other systems have varying tolerance for edge-case inputs.

---

## SF-005 — AuthorizationBehavior.RequiredPermission not enforced

**Detected:** Sprint T4 (2026-05-25)
**Severity:** 🔴 **Critical** (authorization bypass)
**Requirements violated:** PG-04 (Application-layer permission enforcement), CODE-03 (two-level authorization)

### Context

T4 sprint planning inspection of `AuthorizationBehavior.cs:51-61` revealed
a TODO comment where `RequiredPermission` lookup was intended but never
implemented. The code logs a debug message but does not actually check
whether the user has the declared permission.

```csharp
// TODO: Implement permission service lookup when permission caching is ready
// var hasPermission = await permissionService.HasPermissionAsync(
//     currentUser.PermissionGroupId, permReq.RequiredPermission, ct);
// if (!hasPermission) throw new ForbiddenException(...);

logger.LogDebug(
    "Permission check for {Permission} on {RequestType} (enforcement pending permission service)",
    permReq.RequiredPermission, typeof(TRequest).Name);
```

### Root cause

The `IPermissionService` abstraction was never created. The TODO was
left during initial development with the intention of implementing it
"when permission caching is ready". Redis caching infrastructure was
built (`ICacheService`, `RedisCacheService`), but no one circled back
to wire it into authorization.

### Impact (had this gone to production)

Any command or query that declares `IRequiresPermission.RequiredPermission`
would have its permission check **silently skipped**. The role check
(`AllowedRoles`) still works, but fine-grained permission keys
(e.g., `menu.users`, `dashboard.edit`, CC-resource filtering) would
be completely unenforced at the Application layer.

Per PG-04: "CC-resource filtering is enforced in Application Layer
(`AuthorizationBehavior`), **not** only in UI. Hiding a menu item is
cosmetic only — API calls must also be rejected." This requirement
was violated.

**Mitigating factor:** At the time of detection, no command/query
in the codebase actually declares a `RequiredPermission` value (all
use the default `null`). The gap was latent — it would have become
exploitable the moment any developer added a permission-protected
command assuming the TODO was implemented.

### Resolution

Fixed in Sprint T4 by:
1. Creating `IPermissionService` interface in `Domain/Interfaces/`
2. Implementing `PermissionService` in `Infrastructure/Services/`
   with Redis cache lookup (`{tenantId}:pg_permissions:{pgId}`)
3. Replacing the TODO in `AuthorizationBehavior.cs:51-61` with
   actual permission enforcement

Commit: T4 (2026-05-25)

### Lesson / pattern

TODOs in security-critical paths must be tracked in a backlog with
severity and ownership. A TODO in an authorization pipeline is a
production vulnerability with a deferred fix date. Code review
should flag any `// TODO:` in authentication/authorization code as
a blocking issue.

---

## Summary table

| ID | Severity | Affected requirement | Detected by | Fix commit |
|---|---|---|---|---|
| SF-001 | 🔴 Critical | ARCH-01 | T1 Phase A `GlobalQueryFilterTests` | `ca0ccd9` |
| SF-002 | 🟠 High | ARCH-04, BFP-04 | T1 Phase A `TenantMismatchLoginTests` | `ca0ccd9` |
| SF-003 | 🟠 High | ARCH-06 | T1 Phase A `SuspendedAndDeletedTenantTests` | `ca0ccd9` |
| SF-004 | 🟡 Medium | AUTH-API-05 | T1 Phase B `JtiRevocationTests` | `b846f1b` |
| SF-005 | 🔴 Critical | PG-04, CODE-03 | T4 sprint planning inspection | T4 (2026-05-25) |

All findings detected within the first test-coverage sprint of the
v1.3 programme. Expected pattern: each subsequent sprint (T2..T5)
will surface additional gaps as test coverage extends into new code
paths.

## ROI of T1 (Phase A + Phase B + Phase C — sprint fully closed)

- **Investment:** ~50 hours of focused test development across the
  three phases (Phase A ~20h, Phase B ~15h, Phase C ~12h plus
  ~3h architect close-out per phase).
- **Returns:** 4 production bugs identified and fixed before
  release — 1 Critical (cross-tenant data leak), 2 High (audit
  subtype, GDPR-blocking guard), 1 Medium (logout reliability).
  **79 passing tests, zero skips**, 87.88% line coverage on
  `CcDashboard.Infrastructure`. Plus 2 process deviations
  documented (PD-001 / PD-002) feeding back into future sprint
  hand-off prompts.
- **Future cost avoided:** at minimum one cross-tenant data
  incident (SF-001 alone) plus compliance audit non-conformities
  (SF-002, SF-003) plus support load on inconsistent-logout cases
  (SF-004). All four would have required incident response and/or
  customer notification work far more expensive than prevention.
- **Phase C specifically:** zero new SFs surfaced. This validates
  that Phase A and Phase B's negative-path tests already covered
  the riskiest branches; golden-path coverage was needed for
  audit completeness and AUTH-WEB-02 claims-materialisation
  regression safety, not for finding bugs. Expected pattern for
  closing sprints: lower SF discovery rate as coverage saturates
  the in-scope code paths.

This is the explicit business case for completing Sprints T2..T5.

## ROI of T4 (PG Authorization Semantics)

- **Investment:** ~4 hours of focused authorization test development
- **Returns:** 1 Critical security finding (SF-005) fixed — permission
  enforcement TODO in AuthorizationBehavior was completely unenforced.
  **46 authorization tests** now covering:
  - AuthorizationBehavior role + permission enforcement (7 tests)
  - E2E UI rejection via WebFixture (4 tests)
  - PG-03 empty CC-resource = denied (7 tests)
  - PG-04 AccessLevel bitmask semantics (5 tests)
  - PG-04 single-assignment union semantics (5 tests)
  - PG-01 creator auto-grant (4 tests)
  - PG-06 cannot delete PG with users (5 tests)
  - PG-07 Redis cache invalidation (5 tests)
  - AUD-01 audit events for PG lifecycle (4 tests)
- **Total `Tests.Security` count after T4:** 126+ passing
- **Future cost avoided:** SF-005 would have allowed any command
  declaring `RequiredPermission` to bypass Application-layer
  authorization entirely. The first developer to add a
  permission-protected command would have had a false sense of
  security while the permission was silently skipped.
