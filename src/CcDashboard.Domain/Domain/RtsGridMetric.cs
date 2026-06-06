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

    // Catalogue — editorial
    public string? DisplayName { get; set; }
    public string? ShortDescription { get; set; }
    public string? LongDescription { get; set; }
    public string? Comparison { get; set; }
    public string? StandardKpi { get; set; }
    public string? StandardRef { get; set; }

    // Catalogue — taxonomy (stored, not derived)
    public string? CatalogCategory { get; set; }   // Queue | AgentGroup | Agent
    public string? Family { get; set; }             // e.g. queue.pct.answered_threshold_inc
    public string? Channel { get; set; }            // calls | callbacks | calls_callbacks | chats | digital
    public int? ThresholdSec { get; set; }          // 30 | 60 | 120 | 360

    // Catalogue — lifecycle
    public string? CatalogStatus { get; set; }      // active | duplicate | deprecated | defect-candidate
    public string? CatalogNotes { get; set; }       // Superadmin-only (display gated in D3b)
}
