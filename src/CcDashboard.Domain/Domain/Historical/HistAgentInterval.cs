namespace CcDashboard.Domain.Domain.Historical;

/// <summary>
/// Pre-aggregated agent status durations for 30-minute intervals.
/// Stored in hist_agent_intervals partitioned table (RANGE by IntervalStart).
/// </summary>
public class HistAgentInterval
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public DateTime IntervalStart { get; set; }
    public string AgentExternalId { get; set; } = string.Empty;
    public string? AgentDisplayName { get; set; }
    public long SumAvailableMs { get; set; }
    public long SumOnphoneMs { get; set; }
    public long SumHoldMs { get; set; }
    public long SumPaperworkMs { get; set; }
    public long SumBreakMs { get; set; }
    public long SumTrainingMs { get; set; }
    public long SumUnavailableMs { get; set; }
    public long SumLoggedInMs { get; set; }
    public int Handled { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
