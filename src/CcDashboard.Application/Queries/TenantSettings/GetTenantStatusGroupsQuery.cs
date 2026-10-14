using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Application.Queries.TenantSettings;

/// <summary>
/// Actual StatusGroup values present in this tenant's RTSData_UserStatus.
/// Source of truth for the WFM "serving state groups" setting: the operator picks from this list
/// instead of typing, so the comparison in WfmInputQueryService (exact, `= ANY`, two places —
/// :244 for queues and :286 for the BU aggregate) cannot miss.
/// Values arrive from the platform in UPPER CASE (see RtsDataUserStatus.StatusGroup remark:
/// AVAILABLE, ONPHONE, BREAK, PAPERWORK, TRAINING) — returned verbatim, never prettified.
/// An empty list is a valid answer, not an error: the caller shows "no state groups reported".
/// NO window: the setting is configuration, not a report. See the handler remark for the price.
/// </summary>
public record GetTenantStatusGroupsQuery(Guid? TenantId = null)
    : IRequest<IReadOnlyList<string>>;

public class GetTenantStatusGroupsQueryHandler(
    IBackendEmulationDbContextFactory beDbFactory,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetTenantStatusGroupsQuery, IReadOnlyList<string>>
{
    public async Task<IReadOnlyList<string>> Handle(
        GetTenantStatusGroupsQuery query, CancellationToken ct)
    {
        // ── Tenant gate, in the handler and not only in the page ────────────────────
        // AuthorizationBehavior enforces nothing here: its checks fire only for requests
        // implementing IRequiresPermission / IRequiresTenantContext, and NO request in the
        // solution implements either (measured: the two interfaces appear only in
        // Behaviors/AuthorizationBehavior.cs itself). The sole guard today is the page attribute
        // [Authorize(Roles = "Superadmin")] on TenantsPage.razor:4 — that protects a UI route,
        // not this query, so any other caller could pass an arbitrary TenantId.
        // Hence the same rule the project already uses for cross-tenant writes
        // (CreateDashboardCommand.cs:28): an explicit TenantId is honoured for Superadmin only.
        var isSuperadmin = currentUser.Role == "Superadmin";

        Guid tenantId;
        if (query.TenantId.HasValue && query.TenantId.Value != currentUser.TenantId)
        {
            if (!isSuperadmin)
                throw new ForbiddenException(
                    "Only a Superadmin may request status groups of another tenant.");

            tenantId = query.TenantId.Value;
        }
        else
        {
            // No tenant context at all (e.g. Superadmin who has not picked a tenant):
            // refuse explicitly instead of dereferencing a null and throwing NullReference.
            tenantId = query.TenantId
                ?? currentUser.TenantId
                ?? throw new ForbiddenException("Tenant context required.");
        }

        await using var beDb = await beDbFactory.CreateDbContextAsync(ct);

        // Raw SQL on purpose: IBackendEmulationDbContext exposes only RtsGridMetrics and
        // NgcBusinessUnitQueueClassifications as DbSets (plus Database for raw SQL).
        // RtsDataUserStatuses is NOT on the interface, and widening a shared abstraction for one
        // read-only list would change the contract for every handler depending on it.
        // Same table, column and tenant gate the WFM input service itself uses.
        //
        // Deliberately UNWINDOWED.
        // Chosen: every StatusGroup the tenant has ever reported.
        //   price — a group retired long ago stays selectable (operator sees one stale entry).
        // Rejected: last N days.
        //   price — a rare but live group (night shift, seasonal queue) silently disappears from
        //   the list exactly when someone needs to select it, and the setting becomes unexpressible.
        // A stale extra entry is visible and harmless; a missing live entry is invisible and blocking.
        const string sql = @"
            SELECT DISTINCT us.""StatusGroup"" AS ""Value""
            FROM public.""RTSData_UserStatus"" us
            WHERE us.""TenantId"" = @tenant
              AND us.""StatusGroup"" IS NOT NULL
              AND us.""StatusGroup"" <> ''
            ORDER BY 1";

        return await beDb.Database
            .SqlQueryRaw<string>(sql, new Npgsql.NpgsqlParameter("@tenant", tenantId))
            .ToListAsync(ct);
    }
}
