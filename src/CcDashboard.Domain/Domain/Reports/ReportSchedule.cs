namespace CcDashboard.Domain.Domain.Reports;

/// <summary>
/// Report schedule entity — for scheduled email distribution.
/// </summary>
/// <remarks>
/// [REPORT-SCHED-01] Dispatcher invariant (Ф7):
/// The schedule-dispatch query MUST skip schedules where:
/// - schedule.IsActive = false, OR
/// - screen.IsDeleted = true (join ReportScreen, respect combined GQF TenantId + !IsDeleted)
/// This ensures soft-deleted reports never auto-send emails.
/// Dispatcher MUST NOT use IgnoreQueryFilters without also checking screen.IsDeleted.
/// </remarks>
public class ReportSchedule
{
    public Guid Id { get; set; }
    public Guid ReportScreenId { get; set; }
    public Guid TenantId { get; set; }
    public string Cadence { get; set; } = string.Empty;
    public string? Recipients { get; set; }
    public ReportExportFormat Format { get; set; } = ReportExportFormat.Xlsx;
    public ReportDateWindow DateWindow { get; set; } = ReportDateWindow.RollingDays;
    public int? RollingDays { get; set; }
    public DateTime? FixedFrom { get; set; }
    public DateTime? FixedTo { get; set; }
    public bool IsActive { get; set; }
    public DateTime? LastRunAt { get; set; }
    public DateTime? NextRunAt { get; set; }
    public Guid CreatedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }

    public ReportScreen? ReportScreen { get; set; }
}
