# CC task — BUG FIX: RestoreReportScreenCommand fails NotFound on soft-deleted reports (bi) — §4-PASS (coordinator-0624) — CLEARED TO RUN
> Found in C visual walkthrough (2026-06-25): clicking Restore in the Reports Trash → error "ReportScreen with key '...' was not found." Owner: bi. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37). NO migration.

## ROOT CAUSE (object-store verified)
`RestoreReportScreenCommandHandler` loads via `repo.GetByIdWithWidgetsAndSchedulesAsync(cmd.Id)` (ReportScreenRepository.cs:26) which does NOT call `IgnoreQueryFilters()`. ReportScreen's combined GQF = `TenantId == ctx && !IsDeleted` → a soft-deleted screen is filtered out → `FirstOrDefaultAsync` returns null → `NotFoundException`. The Trash LIST works because `GetDeletedPageAsync` (:98) uses `IgnoreQueryFilters()`; `GetByIdForPurgeAsync` (:170) also does — Restore is the only deleted-path loader missing it.

## THE WORK (mirror the working Purge loader)
1. Add a dedicated deleted-loader to `IReportScreenRepository` + `ReportScreenRepository`:
   `Task<ReportScreen?> GetDeletedByIdWithSchedulesAsync(Guid id, Guid tenantId, CancellationToken ct = default)` →
   `db.ReportScreens.IgnoreQueryFilters().Include(Category).Include(Widgets).Include(Permissions).Include(Schedules).FirstOrDefaultAsync(s => s.Id == id && s.TenantId == tenantId && s.IsDeleted, ct)`.
   (Mirror GetByIdForPurgeAsync's IgnoreQueryFilters + explicit TenantId guard — do NOT broaden the existing GetByIdWithWidgetsAndSchedulesAsync, which is correct for non-deleted Update paths.)
2. `RestoreReportScreenCommandHandler`: replace the `GetByIdWithWidgetsAndSchedulesAsync(cmd.Id)` call with `GetDeletedByIdWithSchedulesAsync(cmd.Id, <tenantId>)` (use the same TenantId source the repo/ctx uses elsewhere; Superadmin cross-tenant — confirm how Purge resolves tenant and mirror it). Keep the `!IsDeleted` guard (now defensive) + the restore logic + REPORT-SCHED-02 (schedules stay inactive).
3. Confirm Widgets restore loop still works (the loader now Includes Widgets of the deleted screen).

## VERIFY/DoD: object-store — new loader has IgnoreQueryFilters+TenantId+IsDeleted; Restore handler uses it; unit test: soft-delete a screen → Restore → IsDeleted=false (no NotFound) + schedules stay inactive. Soma /ops/build 0 + /ops/test?suite=unit (safe now). NO migration. Commit fix:, NO push. Binding RESULT -> cc/bi.md.
