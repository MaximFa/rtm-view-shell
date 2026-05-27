namespace CcDashboard.Domain.Domain;

/// <summary>
/// Shell-owned catalogue of historical (RTSData_*) metric definitions.
/// Used by Chart/Analytics widgets. Not related to RTSGrid_Metric (CC platform, read-only).
/// MetricId convention: {domain}.{metric_name} — e.g. "interaction.incoming_calls"
/// </summary>
public class HistoryMetric
{
    public string MetricId { get; set; } = string.Empty; // PK — e.g. "interaction.incoming_calls"
    public string Description { get; set; } = string.Empty;
    public string DataType { get; set; } = string.Empty; // "int" | "decimal" | "bigint"
    public string MetricFunction { get; set; } = string.Empty; // "COUNT_FILTER" | "AVG_FIELD" | etc.
    public string MetricParameter { get; set; } = string.Empty;
    public string MetricFormat { get; set; } = string.Empty; // "0" | "mm:ss" | "hh:mm:ss"
    public string DefaultValue { get; set; } = "0";
    public string ValueType { get; set; } = string.Empty; // "Number" | "Time" | "TimeMs"
    public string MetricType { get; set; } = string.Empty; // "Interaction" | "AgentStatus" | "AgentStatusLog"
}
