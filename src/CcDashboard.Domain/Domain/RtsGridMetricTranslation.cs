namespace CcDashboard.Domain.Domain;

public class RtsGridMetricTranslation
{
    public string MetricId { get; set; } = string.Empty;   // FK -> RTSGrid_Metric
    public string Locale { get; set; } = string.Empty;     // BCP-47, e.g. "ru-RU", "he-IL"
    public string? DisplayName { get; set; }
    public string? ShortDescription { get; set; }
    public string? LongDescription { get; set; }
    public string? Comparison { get; set; }
}