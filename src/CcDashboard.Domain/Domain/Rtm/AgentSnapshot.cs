namespace CcDashboard.Domain.Domain.Rtm;

/// <summary>Immutable snapshot of one agent's metric fields at a point in time.</summary>
public sealed record AgentSnapshot(
    string AgentLoginName,
    IReadOnlyDictionary<string, CellValue> Fields,
    DateTime ReceivedAt);
