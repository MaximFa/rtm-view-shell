namespace CcDashboard.Domain.Domain.Historical;

/// <summary>
/// Pre-aggregated queue statistics for 30-minute intervals.
/// Stored in hist_queue_intervals partitioned table (RANGE by IntervalStart).
/// </summary>
public class HistQueueInterval
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public DateTime IntervalStart { get; set; }
    public string Workgroup { get; set; } = string.Empty;
    public Guid? QueueId { get; set; }
    public int Offered { get; set; }
    public int Answered { get; set; }
    public int Abandoned { get; set; }
    public int AnsweredInSl { get; set; }
    public long SumWaitAnswered { get; set; }
    public long SumTalk { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
