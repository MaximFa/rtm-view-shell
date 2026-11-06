using CcDashboard.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Application.HistoricalReports.Queries;

/// <summary>
/// FEAT-REPORT-AGENT-PERF-01: the agents a user may pick in the agent performance report - the agents of the given
/// Business Units, within the user's Permission Group scope. Never wider than what the report itself would show.
/// </summary>
public record GetScopedAgentsQuery(IReadOnlyList<int> BusinessUnitIds) : IRequest<ScopedAgentsResult>;

/// <summary>One pickable agent. DisplayName falls back to the id when no name is known.</summary>
public record ScopedAgent(string AgentId, string DisplayName);

/// <summary>
/// Agents sorted by name. At most <see cref="GetScopedAgentsQueryHandler.Limit"/> (the report accepts that many ids);
/// Truncated + TotalCount tell the screen there are more, so the cut is never silent.
/// </summary>
public record ScopedAgentsResult(IReadOnlyList<ScopedAgent> Agents, int TotalCount, bool Truncated, bool Denied);

public class GetScopedAgentsQueryHandler(
    IReportWidgetScopeService scopeService,
    IHistoricalReportRepository repo,
    ICurrentUserAccessor currentUser,
    ILogger<GetScopedAgentsQueryHandler> logger)
    : IRequestHandler<GetScopedAgentsQuery, ScopedAgentsResult>
{
    /// <summary>Same as the AgentIds limit of the report config (ReportWidgetConfigValidator).</summary>
    public const int Limit = 500;

    private static readonly ScopedAgentsResult Empty = new(Array.Empty<ScopedAgent>(), 0, false, false);

    public async Task<ScopedAgentsResult> Handle(GetScopedAgentsQuery query, CancellationToken ct)
    {
        // Own tenant only - no tenant parameter at all, not even for a Superadmin.
        var tenantId = currentUser.TenantId!.Value;

        // PR234-V4-REPORT-FULLSCOPE-EMPTY-LEAK-01 shape: nothing picked -> nothing listed, and nothing asked.
        if (query.BusinessUnitIds is null || query.BusinessUnitIds.Count == 0)
            return Empty;

        // The same server-side scope as the report: BU agents (detail axis) intersected with the PG; BUs outside the
        // user's scope contribute no agents and are not an error.
        var config = new ReportWidgetConfig { Scope = new ReportWidgetScope { BusinessUnitIds = query.BusinessUnitIds.Distinct().ToList() } };
        var scope = await scopeService.ResolveAgentScopeAsync(tenantId, config, AgentReportAxis.Detail, ct);
        if (scope.Denied)
            return Empty with { Denied = true };

        var ids = new HashSet<string>(scope.EffectiveAgentIds);
        if (ids.Count == 0)
            return Empty; // a full-scope user with BUs without agents: still nothing, never "everyone"

        var names = await repo.GetAgentDisplayNamesAsync(tenantId, ids, ct);
        var all = ids
            .Select(id => new ScopedAgent(id, names.TryGetValue(id, out var n) && !string.IsNullOrWhiteSpace(n) ? n : id))
            .OrderBy(a => a.DisplayName, StringComparer.CurrentCultureIgnoreCase)
            .ThenBy(a => a.AgentId, StringComparer.Ordinal)
            .ToList();

        if (all.Count > Limit)
        {
            logger.LogWarning("GetScopedAgents: {Total} agents in scope for user {UserId}, list cut to {Limit}",
                all.Count, currentUser.UserId, Limit);
            return new ScopedAgentsResult(all.Take(Limit).ToList(), all.Count, true, false);
        }

        return new ScopedAgentsResult(all, all.Count, false, false);
    }
}
