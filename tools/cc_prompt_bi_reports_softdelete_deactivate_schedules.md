# CC task — Soft-deleted reports must NOT keep auto-sending: deactivate schedules on delete (bi) — §4-PASS (coordinator-0624) — CLEARED TO RUN
> Operator invariant (2026-06-25): a soft-deleted report must NO LONGER be auto-distributed if it had a schedule. Today DeleteReportScreenCommand soft-deletes screen+widgets but LEAVES ReportSchedule.IsActive untouched → a Trashed report would keep emailing. Close it. Owner: bi. Executor: native CC. Branch: **v3**. Commit `fix:`. **NO push** (§37). NO migration (fields exist).

## INIT — branch v3 + role + §40 + integrity (§0.2/§0.6/PD-007). §0.3 Python+fsync. Binding PRE+POST -> cc/bi.md. commit.lock 5x60s. cc_post_commit.sh. NO push.

## GROUNDING (object-store v3)
- `ReportSchedule` { Id, ReportScreenId, TenantId, Cadence, Recipients, Format, DateWindow, RollingDays, FixedFrom/To, **IsActive**, LastRunAt, **NextRunAt**, CreatedByUserId, CreatedAt, nav ReportScreen }. `ReportScreen.Schedules` (ICollection<ReportSchedule>).
- `DeleteReportScreenCommandHandler` (Application/Reports/Commands/DeleteReportScreenCommand.cs): loads via `repo.GetByIdWithWidgetsAsync`, sets screen.IsDeleted/DeletedAt/DeletedByUserId + soft-deletes widgets. Does NOT touch Schedules.
- `RestoreReportScreenCommand` exists.

## THE WORK
1. **DeleteReportScreenCommand — deactivate schedules on soft-delete:** load the screen WITH its Schedules (extend the repo load to `.Include(s => s.Schedules)` or add a repo method `GetByIdWithWidgetsAndSchedulesAsync`; do NOT break existing callers). For every `ReportSchedule` of the screen: set `IsActive = false` and `NextRunAt = null` (so any dispatcher that scans NextRunAt also skips it). Keep the rows (audit/history) — deactivate, don't hard-delete. Include deactivated-schedule count in AuditDetails (`new { Id, SchedulesDeactivated = n }`).
2. **RestoreReportScreenCommand — do NOT auto-reactivate:** on restore, leave schedules `IsActive=false` (user must consciously re-enable — avoid surprise resumption of emails after restore). Add a one-line comment + (optional) audit detail `SchedulesLeftInactive`.
3. **Ф7 dispatcher guard (defense-in-depth, when the scheduler is built — note in code/spec NOW):** the schedule-dispatch query MUST join ReportScreen and skip `IsDeleted` screens (the combined GQF TenantId && !IsDeleted already excludes them on a normal query — ensure the dispatcher does NOT IgnoreQueryFilters past that, and also gates on `schedule.IsActive && screen NOT IsDeleted`). If no dispatcher exists yet (Ф7 stub), add a clear `// [REPORT-SCHED-01] dispatcher MUST skip IsDeleted screens + IsActive=false` marker where Ф7 will live, and record the invariant in the Reports backend spec.

## VERIFY/DoD: object-store — DeleteReportScreenCommand loads+deactivates schedules (IsActive=false, NextRunAt=null); Restore leaves them inactive; invariant marker/spec note for the Ф7 dispatcher. Unit test: deleting a screen with an active schedule → schedule.IsActive==false & NextRunAt==null; restore → stays false. Soma /ops/build 0 + unit (or note F-QA-4). NO migration. Commit fix:, NO push. Binding RESULT -> cc/bi.md.
