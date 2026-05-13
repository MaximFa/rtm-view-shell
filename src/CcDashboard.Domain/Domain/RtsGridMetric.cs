namespace CcDashboard.Domain.Domain;

public class RtsGridMetric
{
    public string MetricId { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string DataType { get; set; } = string.Empty;
    public string MetricFunction { get; set; } = string.Empty;
    public string MetricParameter { get; set; } = string.Empty;
    public string? MetricFormat { get; set; }
    public string? DefaultValue { get; set; }
    public string ValueType { get; set; } = "String";  // String, Time, Number
    public string MetricType { get; set; } = "Agent";  // Agent, Data (for filtering in grids)
}
