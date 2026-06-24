namespace CcDashboard.Domain.Domain.Reports;

/// <summary>
/// Report widget entity — mirrors DashboardWidget (NO GridId; reports query hist_*, not RTM SignalR).
/// Combined GQF: TenantId && !IsDeleted.
/// </summary>
public class ReportWidget
{
    public Guid Id { get; set; }
    public Guid ReportScreenId { get; set; }
    public Guid TenantId { get; set; }
    public ReportWidgetType WidgetType { get; set; }
    public string? PositionJson { get; set; }
    public string? ConfigJson { get; set; }
    public bool IsDeleted { get; set; }

    public ReportScreen? ReportScreen { get; set; }
}
