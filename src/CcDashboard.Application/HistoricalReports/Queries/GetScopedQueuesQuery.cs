using CcDashboard.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Application.HistoricalReports.Queries;

/// <summary>
/// FEAT-REPORT-QUEUE-TREND-COMPARE-01 (coordinator 17:02:51Z): the queues a user may pick for the queue trend chart - the
/// queues of the given Business Units within the user's Permission Group scope, by the same scope service the chart's run
/// uses. Never wider than what the chart itself would read.
/// </summary>
public record GetScopedQueuesQuery(IReadOnlyList<int> BusinessUnitIds) : IRequest<ScopedQueuesResult>;

/// <summary>One pickable queue. DisplayName is null: the queue scope knows the workgroup name only (it is what people read).</summary>
public record ScopedQueue(string Workgroup, string? DisplayName);

/// <summary>Queues sorted by name; at most <see cref="GetScopedQueuesQueryHandler.Limit"/> (= the Workgroups limit of the
/// config), Truncated + TotalCount when there are more, so the cut is never silent.</summary>
public record ScopedQueuesResult(IReadOnlyList<ScopedQueue> Queues, int TotalCount, bool Truncated, bool Denied);

public class GetScopedQueuesQueryHandler(
    IReportWidgetScopeService scopeService,
    ICurrentUserAccessor currentUser,
    ILogger<GetScopedQueuesQueryHandler> logger)
    : IRequestHandler<GetScopedQueuesQuery, ScopedQueuesResult>
{
    /// <summary>Same as the Workgroups limit of the report config (ReportWidgetConfigValidator).</summary>
    public const int Limit = 500;

    private static readonly ScopedQueuesResult Empty = new(Array.Empty<ScopedQueue>(), 0, false, false);

    public async Task<ScopedQueuesResult> Handle(GetScopedQueuesQuery query, CancellationToken ct)
    {
        // Own tenant only - no tenant parameter at all, not even for a Superadmin.
        var tenantId = currentUser.TenantId!.Value;

        // PR234-V4-REPORT-FULLSCOPE-EMPTY-LEAK-01 shape: nothing picked -> nothing listed, and nothing asked.
        if (query.BusinessUnitIds is null || query.BusinessUnitIds.Count == 0)
            return Empty;

        // The same server-side scope as the chart: BU queues intersected with the PG; BUs outside the user's scope add none.
        var config = new ReportWidgetConfig { Scope = new ReportWidgetScope { BusinessUnitIds = query.BusinessUnitIds.Distinct().ToList() } };
        var scope = await scopeService.ResolveQueueScopeAsync(tenantId, config, ct);
        if (scope.Denied)
            return Empty with { Denied = true };

        var all = scope.EffectiveWorkgroups
            .Select(w => new ScopedQueue(w, null))
            .OrderBy(q => q.Workgroup, StringComparer.CurrentCultureIgnoreCase)
            .ThenBy(q => q.Workgroup, StringComparer.Ordinal)
            .ToList();
        if (all.Count == 0)
            return Empty; // a full-scope user with BUs without queues: still nothing, never "everything"

        if (all.Count > Limit)
        {
            logger.LogWarning("GetScopedQueues: {Total} queues in scope for user {UserId}, list cut to {Limit}",
                all.Count, currentUser.UserId, Limit);
            return new ScopedQueuesResult(all.Take(Limit).ToList(), all.Count, true, false);
        }

        return new ScopedQueuesResult(all, all.Count, false, false);
    }
}
