namespace CcDashboard.Domain.Domain.Reports;

/// <summary>
/// Report permission entity — mirrors DashboardPermission.
/// AccessLevel bitmask: View=1, Edit=2, Delete=4, Full=7.
/// </summary>
public class ReportPermission
{
    public Guid PermissionGroupId { get; set; }
    public Guid ReportScreenId { get; set; }
    public Guid TenantId { get; set; }
    public int AccessLevel { get; set; }

    public PermissionGroup? PermissionGroup { get; set; }
    public ReportScreen? ReportScreen { get; set; }
}
