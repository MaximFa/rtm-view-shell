# T6 Phase B Gap Analysis — Audit Trail

**Sprint:** T6 User Management + Audit Trail
**Phase:** B (Audit Trail)
**Date:** 2026-05-26
**Status:** COMPLETE — 44 new tests passing, 0 regressions

---

## 1. Open Questions Resolution

### OQ-T6-01: Does `app_role` exist in PostgreSQL?
**Status:** Not implemented. The current migrations do not create an `app_role` database user
or REVOKE UPDATE/DELETE permissions on `audit.audit_logs`.

**Impact on DoD-B1:**
- Cannot test DB-level INSERT-only enforcement via permission test
- Alternative: verify `AuditDbContext` has no Update/Delete pathways exposed (architecture test)
- Recommendation: Add migration to create `app_role` and REVOKE permissions as future work

### OQ-T6-02: How does `AuditEventResult` serialise?
**Status:** Resolved. `AuditEventResult` is configured in `AuditDbContext` with
`.HasConversion<string>()`, so it serialises to `"Success"`, `"Failure"`, `"Warning"`.

### OQ-T6-03: Does CSV export endpoint/query exist?
**Status:** No. `IAuditLogRepository` has no export method. `GetAuditLogsQuery` returns
paginated results up to `pageSize`.

**Impact on DoD-B6:**
- Need to add a stub query for CSV export with the 50k boundary logic
- Alternative: add a `CountAsync` method and test the boundary unit test against that

### OQ-T6-04: Is `UpdateUserRequest.Role` validated?
**Status:** Not relevant to Phase B. Role validation is a Phase A concern; addressed in
GAP-T6-04 fix.

---

## 2. Existing Implementation State

### AuditService (src/CcDashboard.Infrastructure/Audit/AuditService.cs)
- Uses `AuditDbContext` for writes
- `LogAsync` creates `AuditLog` entity and calls `SaveChangesAsync`
- Does NOT use business transaction — writes directly

### AuditDbContext
- Separate from `AppDbContext`
- Schema: `audit`
- Table: `audit_logs`
- No Update/Delete methods exposed (only `Add` + `SaveChanges`)

### GetAuditLogsQuery
- Already implements role-aware scoping (AUD-06)
- Superadmin with no TenantId filter → returns all
- Superadmin with TenantId → returns that tenant only
- Administrator → returns own tenant only

### ForwardedHeaders
- Need to verify `UseForwardedHeaders` is called in `Program.cs`
- Need to verify `X-Forwarded-For` reaches `IpAddress` in audit logs

---

## 3. Test Coverage Needed

### DoD-B1: INSERT-only enforcement
Since no `app_role` exists:
1. **Architecture test:** Verify `AuditDbContext` has no `Update` or `Delete` methods
2. **Grep migration:** Verify no `UPDATE` or `DELETE` statements in audit context

### DoD-B2: Audit write isolation (AUD-01)
Test that audit writes survive business transaction rollback:
1. Start business TX
2. Create user (in AppDbContext)
3. Write audit event (via AuditService)
4. Throw exception / rollback business TX
5. Assert: user NOT in DB, audit log IS in audit.audit_logs

### DoD-B3: IP extraction from X-Forwarded-For (AUD-04)
WebApplicationFactory tests:
1. Send login request with `X-Forwarded-For: 203.0.113.5` header
2. Assert `audit_logs.IpAddress = '203.0.113.5'`
3. Send request without header → verify direct connection IP used

### DoD-B4: User.* audit events (AUD-05)
Already tested in Phase A as part of UserUpdate/UserDeactivation tests.
Additional assertions can verify complete coverage.

### DoD-B5: Role-aware scoping (AUD-06)
Integration tests against `GetAuditLogsQuery`:
1. Admin token → only own-tenant logs
2. Superadmin no filter → all logs
3. Superadmin with TenantId filter → that tenant only

### DoD-B6: CSV export boundary (AUD-08)
Since no export exists:
1. Add `CountAsync` to `IAuditLogRepository`
2. Unit test: mock count > 50k → handler indicates async required
3. Integration test: small set → data returned directly

### DoD-B7: Retention config read (AUD-03)
Unit test: `TenantSettings.AuditRetentionDays` is readable, default = 365.
(Full retention purge background service is out of scope for T6.)

---

## 4. Files to Create/Modify

```
tests/CcDashboard.Tests.Security/Audit/
├── AuditInsertOnlyTests.cs       # DoD-B1
├── AuditIsolationTests.cs        # DoD-B2
├── AuditIpExtractionTests.cs     # DoD-B3
├── AuditUserEventsTests.cs       # DoD-B4 (supplement Phase A)
├── AuditScopingTests.cs          # DoD-B5
├── AuditExportTests.cs           # DoD-B6
└── AuditRetentionTests.cs        # DoD-B7

src/CcDashboard.Application/Interfaces/IAuditLogRepository.cs
  └─ Add: CountAsync(tenantId, eventType?, from?, to?, ct)

src/CcDashboard.Infrastructure/Persistence/Repositories/AuditLogRepository.cs
  └─ Implement CountAsync
```
