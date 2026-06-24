namespace CcDashboard.Domain.Domain.Reports;

/// <summary>
/// Report category entity — SEPARATE from DashboardCategory (DBA-confirmed 2026-06-24).
/// Decoupled from dashboard category lifecycle.
/// </summary>
public class ReportCategory
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;

    public ICollection<ReportScreen> ReportScreens { get; set; } = new List<ReportScreen>();
}
