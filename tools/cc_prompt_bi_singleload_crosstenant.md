# CC TASK — cross-tenant single-load fix: report GetById* bypassTenantFilter (Superadmin)

> Owner: role-bi (bi-0626). Branch: v3. status: DRAFT — self-§4 PASS (bi) → AWAITS coordinator §4-bless.
> ⛔ ЧП — no-run-without-bless. BUG (shell object-store): a Superadmin sees 019e03e9 reports in the LIST (GetPageAsync has
> IgnoreQueryFilters, fcf5458) but OPENING one (View/Edit/Save/Update/Delete/Clone) GQF-pins the single-load to the SESSION
> tenant → null → "Report not found". SAME GQF-pinning class as the list fix, missed on the single-load.
> FIX = mirror the ESTABLISHED Dashboard pattern (DashboardRepository.GetByIdAsync/GetByIdWithWidgetsAsync take
> `bool bypassTenantFilter`). NOT a new mechanism. Shell side done (threads Report.TenantId). NO push.

## Mandatory reads
.claude/skills/role-bi/role-bi.md (§A ⛔ЧП + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10). Reality wins.

## STEP 0 — INTEGRITY + branch + binding PREAMBLE + claim
```bash
cd "D:\Claude\Projects\RTM View Shell"; git rev-parse --abbrev-ref HEAD   # v3
git rev-parse HEAD ; git status --short   # M: hash-verify vs HEAD; restore truncated via git show HEAD:<f> > <f>
```
CLAIM (file-mode, bi Application + report repo):
- src/CcDashboard.Application/Reports/Interfaces/IReportScreenRepository.cs
- src/CcDashboard.Infrastructure/Persistence/Repositories/ReportScreenRepository.cs
- src/CcDashboard.Application/Reports/Queries/GetReportScreenQuery.cs
- src/CcDashboard.Application/Reports/Commands/UpdateReportScreenCommand.cs
- src/CcDashboard.Application/Reports/Commands/SaveReportWidgetsCommand.cs
- src/CcDashboard.Application/Reports/Commands/DeleteReportScreenCommand.cs
- src/CcDashboard.Application/Reports/Commands/CloneReportScreenCommand.cs
- tests/CcDashboard.Tests.Unit/** + .claude/skills/role-bi/role-bi.md (§B)
BINDING PREAMBLE → .coord/cc/bi.md (status open, directive ref).

## PATTERN TO MIRROR (verbatim from DashboardRepository.cs — the established cross-tenant single-load):
```csharp
public Task<Dashboard?> GetByIdAsync(Guid id, bool bypassTenantFilter = false, CancellationToken ct = default)
{
    var q = bypassTenantFilter
        ? db.Dashboards.IgnoreQueryFilters().Where(d => !d.IsDeleted)   // SA cross-tenant: by globally-unique Id, !IsDeleted re-added
        : db.Dashboards;                                                // non-SA: GQF (TenantId && !IsDeleted)
    return q.Include(d => d.Permissions).FirstOrDefaultAsync(d => d.Id == id, ct);
}
// GetByIdWithWidgetsAsync: same q; widget Include uses .Include(d => d.Widgets.Where(w => !w.IsDeleted)) (IgnoreQueryFilters drops the widget GQF too).
```

## EDIT A — IReportScreenRepository.cs (interface L7-9): add `bool bypassTenantFilter = false` to the 3 single-load sigs
```csharp
Task<ReportScreen?> GetByIdAsync(Guid id, bool bypassTenantFilter = false, CancellationToken ct = default);
Task<ReportScreen?> GetByIdWithWidgetsAsync(Guid id, bool bypassTenantFilter = false, CancellationToken ct = default);
Task<ReportScreen?> GetByIdWithWidgetsAndSchedulesAsync(Guid id, bool bypassTenantFilter = false, CancellationToken ct = default);
```

## EDIT B — ReportScreenRepository.cs (L9-33): the 3 methods mirror the Dashboard pattern
For EACH method, build the base query gated on bypassTenantFilter, then keep the existing Includes + FirstOrDefault(s => s.Id == id):
- `GetByIdAsync`: `var q = bypassTenantFilter ? db.ReportScreens.IgnoreQueryFilters().Where(s => !s.IsDeleted) : db.ReportScreens;` → keep existing Includes (Category/Permissions if any) → `.FirstOrDefaultAsync(s => s.Id == id, ct)`.
- `GetByIdWithWidgetsAsync`: same q; the widget Include MUST become `.Include(s => s.Widgets.Where(w => !w.IsDeleted))` (so IgnoreQueryFilters doesn't pull soft-deleted widgets) + keep other Includes → `.FirstOrDefaultAsync(s => s.Id == id, ct)`.
- `GetByIdWithWidgetsAndSchedulesAsync`: same q; widget Include `.Where(w => !w.IsDeleted)`; schedules Include as today → `.FirstOrDefaultAsync(s => s.Id == id, ct)`.
NOTE: NO TenantId filter in the bypass path — the Id is the globally-unique uuid PK; a Superadmin opens an Id that came from the (selected-tenant-filtered) list. Exactly the Dashboard behaviour. The non-bypass branch keeps today's GQF (own tenant + !IsDeleted). Do NOT touch GetDeleted*/GetByIdForPurge (already IgnoreQueryFilters).

## EDIT C — the 5 report single-load handlers: pass `bypassTenantFilter: isSuperadmin`
In each, compute `var isSuperadmin = currentUser.Role == "Superadmin";` (inject ICurrentUserAccessor if a handler lacks it) and thread it:
- `GetReportScreenQuery.cs` L21: `repo.GetByIdWithWidgetsAsync(request.Id, bypassTenantFilter: isSuperadmin, ct)` (the VIEW path — the actual "Report not found" symptom).
- `UpdateReportScreenCommand.cs` L25: `repo.GetByIdAsync(cmd.Request.Id, bypassTenantFilter: isSuperadmin, ct)`.
- `SaveReportWidgetsCommand.cs` L32: `repo.GetByIdWithWidgetsAsync(cmd.ReportScreenId, bypassTenantFilter: isSuperadmin, ct)`.
- `DeleteReportScreenCommand.cs` L28: `repo.GetByIdWithWidgetsAndSchedulesAsync(cmd.Id, bypassTenantFilter: isSuperadmin, ct)`.
- `CloneReportScreenCommand.cs` L45: `repo.GetByIdWithWidgetsAsync(cmd.SourceId, bypassTenantFilter: isSuperadmin, ct)`.
SECURITY (preserved): non-Superadmin → bypassTenantFilter=false → GQF-tenant-scoped (CANNOT load another tenant's report). Superadmin → loads by Id cross-tenant (full access, bypasses PG). The EXISTING per-handler authz (AccessLevel/report_permissions/Forbidden, PG-01) STILL runs on top — do NOT remove it.

## TESTS (tests/CcDashboard.Tests.Unit/)
- Repo: GetByIdWithWidgetsAsync(id, bypassTenantFilter:true) returns a screen from a DIFFERENT tenant (IgnoreQueryFilters) but still excludes IsDeleted (screen + its widgets); bypassTenantFilter:false returns null for a cross-tenant id (GQF).
- Handler: GetReportScreenQuery as Superadmin → bypass:true passed; as non-Superadmin → bypass:false. (At least the view + one command.)

## ACCEPTANCE (DoD)
1. Build 0. 2. Unit tests GREEN. 3. A Superadmin opens a 019e03e9 report (View/Edit/Save/Update/Delete/Clone) → loads (no "Report not found"). 4. non-Superadmin cannot single-load a cross-tenant report (GQF). 5. Soft-delete still excluded (bypass re-adds !IsDeleted on screen + widgets). 6. report_permissions authz intact. 7. NO migration. 8. NO push.

## STEP 5 — COMMIT + binding RESULT + CAPTURE + re-sync
- §0.3 native CC; object-store-verify edits post-commit.
- commit.lock (retry 5×60s) → `bash tools/pre-commit-check.sh` → git add (claimed) → commit `fix: report single-load cross-tenant — GetById* bypassTenantFilter (Superadmin), mirror Dashboard [bi]` → §0.6 verify → `tools/cc_post_commit.sh bi-0626 <hash>` → §0.7 re-sync.
- BINDING POSTAMBLE → cc/bi.md RESULT (3 repo methods + 5 handlers, build/tests, object-store verify, status done).
- §0.6b CAPTURE → role-bi §B (git add -f), TWO lessons:
  1. `2026-06-26 · cross-tenant report SINGLE-LOAD (GetById*) needs bypassTenantFilter:isSuperadmin (IgnoreQueryFilters + re-add !IsDeleted on screen AND widget Includes) — mirrors DashboardRepository; the list fix (GetPageAsync) alone leaves View/Edit/Delete/Clone GQF-pinned → "Report not found". · SOURCE: DashboardRepository.cs GetByIdWithWidgetsAsync + coordinator 2026-06-26 · status: active`
  2. `2026-06-26 · CONFABULATION: claimed DATA-PROOF seed "ran/LANDED" by reconciling from the committed .sql (commit exists) — but a committed SEED SCRIPT is NOT executed+inserted DATA; operator DB query showed ZERO rows. Verify DB ROWS for a seed/data deliverable, never infer delivery from the seed COMMIT (a code-change commit IS verifiable by diff; a data-seed is NOT). · SOURCE: coordinator 2026-06-26 20:10 + cf2f980 · status: active`

## DO NOT
- Do NOT remove the per-handler authz (AccessLevel/report_permissions/Forbidden).
- Do NOT add a TenantId filter to the bypass path (load by globally-unique Id, mirror Dashboard).
- Do NOT touch GetDeleted*/GetByIdForPurge / GetPageAsync (already handled) / Dashboard repo.
- NO migration / NO push.
