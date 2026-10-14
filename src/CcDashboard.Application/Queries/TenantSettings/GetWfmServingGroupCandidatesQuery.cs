using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Application.Queries.TenantSettings;

/// <summary>
/// The serving-group names the platform actually publishes: the MetricParameter values of the
/// metrics whose MetricFunction is UsersInStatusGroupCount.
///
/// CORRECTED 14.10. The first version of this query looked for MetricIds beginning with
/// "UsersInStatusGroupCount_" and returned ZERO on 234 - devops measured 0 such metrics and 0 such
/// cells in the whole database, because that name does not exist in the product. It is the value of
/// MetricFunction, not a MetricId; the group lives in MetricParameter. Real ids are ordinary names:
/// QueueLoginDataNumAvailableUsers/AVAILABLE, QueueNumOnCallAgents/ONPHONE,
/// QueueLoginDataNumBreakUsers/BREAK, QueueLoginDataNumPaperworkUsers/PAPERWORK,
/// QueueLoginDataNumTrainingUsers/TRAINING (db/baseline.sql:54,129,164,166,167).
/// The product already had the correct lookup and this query now mirrors it:
/// AgentStateHandlers.cs:50-57.
///
/// This is the list the operator picks from, and it removes the casing question for good: both the
/// parameter and the live StatusGroup values are the platform's upper-case codes, so a stored
/// setting equals a parameter exactly.
///
/// SCOPE, stated because it is not obvious: RtsGridMetric has NO TenantId column (measured - the
/// entity has none and the catalogue is shared), so the catalogue cannot be filtered by tenant.
/// The tenant gate below therefore guards WHO MAY ASK, not what is returned; the answer is the
/// platform's metric catalogue, identical for every tenant. The per-tenant question - which of
/// these groups actually has cells on this BU's rows - is answered by
/// IWfmEngineAgentCountProvider.GetPublishedGroupNamesAsync, not here.
/// </summary>
public record GetWfmServingGroupCandidatesQuery(Guid? TenantId = null)
    : IRequest<IReadOnlyList<string>>;

public class GetWfmServingGroupCandidatesQueryHandler(
    IBackendEmulationDbContextFactory beFactory,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetWfmServingGroupCandidatesQuery, IReadOnlyList<string>>
{
    private const string GroupMetricFunction = "UsersInStatusGroupCount";

    public async Task<IReadOnlyList<string>> Handle(
        GetWfmServingGroupCandidatesQuery query, CancellationToken ct)
    {
        // Same gate as the other tenant-settings queries: AuthorizationBehavior checks nothing in
        // practice (IRequiresPermission / IRequiresTenantContext are implemented by no request), and
        // the page attribute guards a UI route, not a query. Kept even though the catalogue is
        // shared - a query that takes a tenant id must not be callable for an arbitrary one.
        var isSuperadmin = currentUser.Role == "Superadmin";

        if (query.TenantId.HasValue && query.TenantId.Value != currentUser.TenantId)
        {
            if (!isSuperadmin)
                throw new ForbiddenException(
                    "Only a Superadmin may request serving-group candidates for another tenant.");
        }
        else if (query.TenantId is null && currentUser.TenantId is null)
        {
            throw new ForbiddenException("Tenant context required.");
        }

        await using var beDb = await beFactory.CreateDbContextAsync(ct);

        const string sql = @"
            SELECT DISTINCT m.""MetricParameter"" AS ""Value""
            FROM public.""RTSGrid_Metric"" m
            WHERE m.""MetricFunction"" = @fn
              AND m.""MetricParameter"" IS NOT NULL
              AND m.""MetricParameter"" <> ''
            ORDER BY 1";

        return await beDb.Database
            .SqlQueryRaw<string>(sql, new Npgsql.NpgsqlParameter("@fn", GroupMetricFunction))
            .ToListAsync(ct);
    }
}
