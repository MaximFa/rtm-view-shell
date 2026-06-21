namespace CcDashboard.Domain.Domain.Historical;

/// <summary>
/// Aggregation watermark - tracks how far aggregation has progressed per tenant.
/// Used to ensure A2 RT-purge never deletes un-aggregated data.
/// </summary>
public class HistAggregationWatermark
{
    public Guid TenantId { get; set; }
    public DateTime AggregatedThrough { get; set; }
    public DateTime LastRunAt { get; set; }
}
