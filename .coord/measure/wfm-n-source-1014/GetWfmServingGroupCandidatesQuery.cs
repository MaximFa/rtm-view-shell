using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Application.Queries.TenantSettings;

/// <summary>
/// The serving-group names the engine actually publishes for a tenant: the distinct suffixes of
/// UsersInStatusGroupCount_* across the tenant's grid cells.
///
/// This is the list the operator picks from, which is the point: a stored setting then matches a
/// metric id by construction and the comparison downstream stays exact. The names currently stored
/// come from RTSData_UserStatus and are UPPER CASE, so they will NOT appear in this list - the
/// settings page shows them as "not found in data" and the operator re-picks once.
///
/// Measured facts this query rests on:
///   - the BU link lives on RTSGrid_Row.UnionId, not on the grid or the cell (devops, 234, 14.10:
///     Grid.UnionId = -1 in all 60 rows, Cell.UnionId = -1 in all 509);
///   - RTSGrid_Row has NO TenantId column, so the tenant gate can only be applied through
///     NGC_BusinessUnit.TenantId - which is why the join below goes BU -> rows -> cells and not
///     straight to the cells.
/// </summary>
public record GetWfmServingGroupCandidatesQuery(Guid? TenantId = null)
    : IRequest<IReadOnlyList<string>>;

public class GetWfmServingGroupCandidatesQueryHandler(
    IBackendEmulationDbContextFactory beFactory,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetWfmServingGroupCandidatesQuery, IReadOnlyList<string>>
{
    private const string GroupMetricPrefix = "UsersInStatusGroupCount_";

    public async Task<IReadOnlyList<string>> Handle(
        GetWfmServingGroupCandidatesQuery query, CancellationToken ct)
    {
        // Same gate as GetTenantStatusGroupsQuery, for the same reason: AuthorizationBehavior
        // checks nothing in practice (IRequiresPermission / IRequiresTenantContext are implemented
        // by no request in the solution), and the page attribute guards a UI route, not a query.
        var isSuperadmin = currentUser.Role == "Superadmin";

        Guid tenantId;
        if (query.TenantId.HasValue && query.TenantId.Value != currentUser.TenantId)
        {
            if (!isSuperadmin)
                throw new ForbiddenException(
                    "Only a Superadmin may request serving-group candidates of another tenant.");

            tenantId = query.TenantId.Value;
        }
        else
        {
            tenantId = query.TenantId
                ?? currentUser.TenantId
                ?? throw new ForbiddenException("Tenant context required.");
        }

        await using var beDb = await beFactory.CreateDbContextAsync(ct);

        // BU -> row -> cell. The tenant gate sits on the BU, the only table in this chain that
        // carries TenantId; parameterised, no string building.
        const string sql = @"
            SELECT DISTINCT c.""Value"" AS ""Value""
            FROM public.""NGC_BusinessUnit"" bu
            JOIN public.""RTSGrid_Row"" r  ON r.""UnionId"" = bu.""BusinessUnitId""
            JOIN public.""RTSGrid_Cell"" c ON c.""RowId""   = r.""RowId""
            WHERE bu.""TenantId"" = @tenant
              AND c.""Value"" IS NOT NULL
              AND c.""Value"" LIKE @prefix || '%'
            ORDER BY 1";

        var metricIds = await beDb.Database
            .SqlQueryRaw<string>(sql,
                new Npgsql.NpgsqlParameter("@tenant", tenantId),
                new Npgsql.NpgsqlParameter("@prefix", GroupMetricPrefix))
            .ToListAsync(ct);

        // The suffix is cut in C#, not in SQL: substring arithmetic in the query would silently
        // depend on the prefix length staying what it is today.
        return metricIds
            .Select(m => m[GroupMetricPrefix.Length..])
            .Where(suffix => suffix.Length > 0)
            .Distinct(StringComparer.Ordinal)
            .OrderBy(suffix => suffix, StringComparer.Ordinal)
            .ToList();
    }
}
