namespace CcDashboard.Domain.Domain.Reports;

/// <summary>
/// Report screen entity — mirrors Dashboard structure (spec F1: separate entity).
/// Combined GQF: TenantId && !IsDeleted.
/// </summary>
public class ReportScreen
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public Guid? CategoryId { get; set; }
    public ReportScreenStatus Status { get; set; } = ReportScreenStatus.Draft;
    public bool IsPublic { get; set; }
    public bool IsDarkMode { get; set; }
    public string? LayoutJson { get; set; }

    public Guid CreatedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }
    public Guid UpdatedByUserId { get; set; }
    public DateTime UpdatedAt { get; set; }

    public bool IsDeleted { get; set; }
    public DateTime? DeletedAt { get; set; }
    public Guid? DeletedByUserId { get; set; }

    public uint RowVersion { get; set; }

    public ReportCategory? Category { get; set; }
    public ICollection<ReportWidget> Widgets { get; set; } = new List<ReportWidget>();
    public ICollection<ReportPermission> Permissions { get; set; } = new List<ReportPermission>();
    public ICollection<ReportSchedule> Schedules { get; set; } = new List<ReportSchedule>();
}
