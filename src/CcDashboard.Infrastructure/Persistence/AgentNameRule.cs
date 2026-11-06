using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence;

/// <summary>
/// PR234-V4-EOS-AGENTS-EMPTY-COLUMNS-01 / FEAT-REPORT-AGENT-PERF-01: the one rule for an agent's display name.
/// Source: RTSData_UserStatus.DisplayName. Measured on 234 (agentname-1105, PROBE2-4): every agent has a name there,
/// but 58 of 68 alternate it with their login (DisplayName = UserId, strictly), even on the same day from one server;
/// 2 agents were renamed between days.
/// Rule: the newest (by UpdateTime) DisplayName that is not empty and not equal to the UserId.
/// Rejected: "any row" (gives the login), "the most frequent" (gives a renamed agent's old name),
/// "plain newest" (gave the login to 5 of 68 agents on 06.11).
/// An agent with no such row is absent from the result; the caller shows the id.
/// </summary>
public static class AgentNameRule
{
    public static async Task<Dictionary<string, string>> NewestRealNamesAsync(
        BackendEmulationDbContext be, Guid tenantId, IReadOnlyCollection<string> agentIds, CancellationToken ct)
    {
        if (agentIds.Count == 0)
            return new Dictionary<string, string>();

        var ids = agentIds.Distinct().ToList();
        var rows = await be.RtsDataUserStatuses
            .AsNoTracking()
            .Where(s => s.TenantId == tenantId
                     && ids.Contains(s.UserId)
                     && s.DisplayName != null && s.DisplayName != ""
                     && s.DisplayName != s.UserId
                     && s.UpdateTime != null)
            .GroupBy(s => s.UserId)
            .Select(g => new
            {
                Id = g.Key,
                Name = g.OrderByDescending(s => s.UpdateTime).Select(s => s.DisplayName).First()
            })
            .ToListAsync(ct);

        return rows.Where(r => !string.IsNullOrWhiteSpace(r.Name)).ToDictionary(r => r.Id, r => r.Name!.Trim());
    }
}
