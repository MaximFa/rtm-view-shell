# CC task — Ф5a.2 BACKEND: GetDeletedReportScreensQuery (Trash list) (bi) — §4-PASS (coordinator-0624) — CLEARED TO RUN (RUN FIRST)
> Operator parity (2026-06-25): Reports list needs a Reports/Trash tab like dashboards. Trash content needs a deleted-screens query. Mirror GetDeletedDashboardsQuery 1:1. Owner: bi. Executor: native CC. Branch: **v3** (tip 5c46daf). Commit `feat:`. **NO push** (§37). NO migration (ReportScreen already has IsDeleted/DeletedAt/DeletedByUserId).

## INIT — branch v3 + role + §40 + integrity (§0.2/§0.6/PD-007). §0.3 Python+fsync. Binding PRE+POST -> .coord/cc/bi.md. commit.lock 5x60s. cc_post_commit.sh. NO push.

## THE MODEL TO MIRROR (object-store v3)
`src/CcDashboard.Application/Queries/Dashboards/GetDeletedDashboardsQuery.cs`:
- `record GetDeletedDashboardsQuery(string? Search, int Page=1, int PageSize=25) : IRequest<PagedResult<DeletedDashboardDto>>`
- `record DeletedDashboardDto(...)` (Id, Name, DeletedAt, DeletedByName, …) ; handler uses IgnoreQueryFilters + Where(e=>e.IsDeleted && e.TenantId==ctx) + paged + DeletedByName join (denormalise via IUserRepository.GetDisplayNamesAsync, same pattern as GetDeletedDashboards).

## THE WORK (mirror, reports namespace)
- NEW `src/CcDashboard.Application/Reports/Queries/GetDeletedReportScreensQuery.cs`:
  `record GetDeletedReportScreensQuery(string? Search, int Page=1, int PageSize=25) : IRequest<PagedResult<DeletedReportScreenDto>>` + Handler.
- NEW DTO `DeletedReportScreenDto(Guid Id, string Name, DateTime DeletedAt, string? DeletedByName)` (put in Application/Reports/DTOs/ReportScreenDtos.cs alongside the others, OR a new file — match where DeletedDashboardDto lives relative to its query).
- Handler: `IReportScreenRepository` (or AppDbContext) `IgnoreQueryFilters().Where(r=>r.TenantId==tenant && r.IsDeleted)`; optional Search on Name (trgm/ILIKE like dashboards); order by DeletedAt desc; paged (PagedResult); resolve DeletedByName via the same display-names path dashboards use. PG-scope: mirror GetDeletedDashboards (Superadmin all / admin-tenant). AsNoTracking. NO IsSystem assumptions (parked Ф8).
- Reuse RestoreReportScreenCommand (already exists) for the restore action — NO change needed; shell will call it.
- Unit test mirroring GetDeletedDashboards tests (deleted-only, tenant-scoped, paged).

## VERIFY/DoD: object-store query+DTO+handler+test present; mirrors GetDeletedDashboards; NO migration; Soma /ops/build 0 + unit (if F-QA-4 fixed else note). PUBLISH the exact signature (query + DeletedReportScreenDto fields) in cc/bi.md RESULT → shell binds the Trash tab to it. Commit feat:, NO push.
