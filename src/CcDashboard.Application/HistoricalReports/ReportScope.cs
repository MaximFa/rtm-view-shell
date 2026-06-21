namespace CcDashboard.Application.HistoricalReports;

/// <summary>
/// Encapsulates the security scope for historical reports.
/// Built by ReportScopeResolver based on current user's role and PG.
/// </summary>
public record ReportScope
{
    /// <summary>True only for Superadmin - full tenant access with no queue/agent restriction.</summary>
    public bool FullScope { get; init; }

    /// <summary>Allowed queue workgroups (NGC_Queues.ExternalId). Empty = DENY if !FullScope.</summary>
    public IReadOnlySet<string> AllowedWorkgroups { get; init; } = new HashSet<string>();

    /// <summary>Allowed agent external IDs. Empty = DENY if !FullScope.</summary>
    public IReadOnlySet<string> AllowedAgentExternalIds { get; init; } = new HashSet<string>();

    /// <summary>Creates a full-scope (Superadmin) scope.</summary>
    public static ReportScope Full() => new() { FullScope = true };

    /// <summary>Creates an empty/denied scope.</summary>
    public static ReportScope Empty() => new() { FullScope = false };

    /// <summary>Intersects client-requested filter with allowed scope. Out-of-scope entries are dropped.</summary>
    public IReadOnlySet<string> IntersectWorkgroups(IReadOnlyList<string>? clientRequested)
    {
        if (FullScope)
            return clientRequested is { Count: > 0 }
                ? new HashSet<string>(clientRequested)
                : new HashSet<string>();

        if (clientRequested is null or { Count: 0 })
            return AllowedWorkgroups;

        return new HashSet<string>(clientRequested.Where(AllowedWorkgroups.Contains));
    }

    /// <summary>Intersects client-requested filter with allowed scope. Out-of-scope entries are dropped.</summary>
    public IReadOnlySet<string> IntersectAgents(IReadOnlyList<string>? clientRequested)
    {
        if (FullScope)
            return clientRequested is { Count: > 0 }
                ? new HashSet<string>(clientRequested)
                : new HashSet<string>();

        if (clientRequested is null or { Count: 0 })
            return AllowedAgentExternalIds;

        return new HashSet<string>(clientRequested.Where(AllowedAgentExternalIds.Contains));
    }
}
