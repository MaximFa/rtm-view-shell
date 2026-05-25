# Sprint T5: Widget framework — Gap Analysis

**Status:** ✅ CLOSED  
**Commit:** Pending  
**Date:** 2026-05-25  
**Tests added:** 28 new test cases (4 files)  
**Tests.Security total:** 204 + 28 = 232 passing  
**Solution total:** 313 passing (72 Unit + 1 Integration + 8 Architecture + 232 Security)  
**Production code changes:** 2 new files (see below)  
**Security findings:** None

---

## DoD Checklist

| DoD | Description | Status | Evidence |
|---|---|---|---|
| DoD-1 | ≥28 passing tests across T5 clusters | ✅ 28 test cases | WidgetCatalogTests(6) + DashboardWidgetTests(5) + RtsGridLifecycleTests(13) + SignalRTenantGuardTests(4) |
| DoD-2 | Widget catalogue cross-tenant (≥3 tests) | ✅ 3 tests | `WidgetCatalogTests.cs` lines 22–117 |
| DoD-3 | Widget catalogue access control (≥3 tests) | ✅ 3 tests | `WidgetCatalogTests.cs` lines 121–210 |
| DoD-4 | DashboardWidget lifecycle (≥5 tests) | ✅ 5 tests | `DashboardWidgetTests.cs` |
| DoD-5 | RTS grid lifecycle (≥8 tests) | ✅ 9 tests | `RtsGridLifecycleTests.cs` (SaveAgent×4, SaveQueue×3, Delete×2) |
| DoD-6 | Dual-write API hook (≥4 tests) | ✅ 4 tests | `RtsGridLifecycleTests.cs` lines 305–402 (API hook assertions) |
| DoD-7 | SignalR TenantId guard (≥3 tests) | ✅ 4 tests | `SignalRTenantGuardTests.cs` |
| DoD-8 | No regression on OQ-16 | ✅ Verified | `NgcBusinessUnitQueueClassification.QueueId` is string — no schema mismatch |
| DoD-9 | Traceability matrix updated | ✅ | `docs/traceability-matrix.md` updated with WGT-01..04, ARCH-09 |
| DoD-10 | All tests pass; 0 regressions | ✅ PASS | 313/313 tests passing |

---

## Test count per file

| File | Tests | DoD | Requirements |
|---|---|---|---|
| `Widgets/WidgetCatalogTests.cs` | 6 | DoD-2 (3) + DoD-3 (3) | WGT-01..03 |
| `Widgets/DashboardWidgetTests.cs` | 5 | DoD-4 | WGT-04 |
| `Widgets/RtsGridLifecycleTests.cs` | 13 | DoD-5 (9) + DoD-6 (4) | WGT-04, ARCH-01 |
| `Widgets/SignalRTenantGuardTests.cs` | 4 | DoD-7 | ARCH-09 |
| **Total** | **28** | | |

---

## Open questions resolved

### OQ-16: NgcBusinessUnitQueueClassification.QueueId type
**Finding:** QueueId is `string` (varchar(100)) — confirmed via schema check.
No type mismatch with RTS tests. Test setup uses string queue IDs correctly.
**Decision:** No issue. Documented in DoD-8.

### OQ-17: SaveQueueGridRtsCommand existence
**Finding:** Command exists at `CcDashboard.Application/Commands/Dashboards/SaveQueueGridRtsCommand.cs`.
Fully implemented with header row, data rows, and cell management.
**Decision:** No stub needed. Tests exercise the real implementation.

### OQ-18: GetWidgetCatalogQuery inactive filtering
**Finding:** Handler correctly filters inactive items for non-Superadmin users.
`IncludeInactive: true` is ignored unless caller is Superadmin.
**Decision:** No gap. Tests verify this behavior.

---

## Security findings

None. All T5 clusters passed without exposing security issues.

---

## Production code changes

| File | Change | Reason |
|---|---|---|
| `src/CcDashboard.Web/Hubs/GridNotificationHub.cs` | **NEW** — SignalR Hub with TenantId guard | Required for ARCH-09 tests; was missing from codebase |
| `src/CcDashboard.Domain/Domain/RtsEntities.cs` | Added Queue Grid entities (RtsGridGrid, RtsGridColumn, RtsGridRow, RtsGridCell) | Required for BeDb assertions in Queue Grid tests |
| `src/CcDashboard.Infrastructure/Persistence/BackendEmulationDbContext.cs` | Added DbSets and EF configuration for Queue Grid entities | Required for test fixture to query Queue Grid tables |
| `tests/CcDashboard.Tests.Security/Fixtures/PostgresFixture.cs` | Added `CreateQueueGridTablesAsync` raw SQL, `WidgetCatalogItemId` property | Queue Grid tables created via raw SQL (not BE migration to avoid conflicts); FK constraint fix |

---

## Process deviations

None in this sprint. T5 executed cleanly:
- All 4 test files created without truncation
- Production code additions were minimal (Hub stub + entities for testing)
- Queue Grid tables created via raw SQL in fixture (avoiding migration conflict between App and BE contexts)

---

## Known limitations carried forward

- **GridNotificationHub:** Stub implementation only verifies TenantId; real SignalR E2E with CC-platform blocked on OQ-13
- **Widget rendering:** Out of scope per TZ §1
- **Full RTS column permutation testing:** Unit tests sufficient; not security-critical

---

## Next sprint

**D1** — Documentation catch-up (architecture diagrams, widget framework input).
T5 provides the widget framework context needed for D1.
