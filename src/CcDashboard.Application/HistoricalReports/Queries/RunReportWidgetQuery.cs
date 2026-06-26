using CcDashboard.Domain.Domain.Reports;
using MediatR;

namespace CcDashboard.Application.HistoricalReports.Queries;

/// <summary>
/// Single entry point for running a report widget.
/// SF-BI-001: Scope + validation happen SERVER-SIDE inside this handler — frontend CANNOT bypass.
/// </summary>
public record RunReportWidgetQuery(
    ReportWidgetType WidgetType,
    string ConfigJson,
    DateTime From,
    DateTime To,
    int Page = 1,
    Guid? TenantId = null
) : IRequest<ReportWidgetResult>;

/// <summary>
/// Tagged union result: exactly one of the typed results is populated based on WidgetType.
/// Frontend discriminates on WidgetType to access the correct result.
/// </summary>
public record ReportWidgetResult
{
    /// <summary>The widget type that was executed.</summary>
    public required ReportWidgetType WidgetType { get; init; }

    /// <summary>True if access was denied (empty PG for non-Superadmin).</summary>
    public bool Denied { get; init; }

    /// <summary>Error message if validation or scope resolution failed.</summary>
    public string? Error { get; init; }

    /// <summary>
    /// Effective columns to render: config.Columns if specified, else DefaultColumns for the widget type.
    /// Frontend uses this to know which columns to display when config had no explicit selection.
    /// </summary>
    public IReadOnlyList<string>? EffectiveColumns { get; init; }

    /// <summary>QueueInterval result (populated when WidgetType = QueueInterval).</summary>
    public QueueIntervalReportResult? QueueInterval { get; init; }

    /// <summary>QueueWaitTime result (populated when WidgetType = QueueWaitTime).</summary>
    public QueueWaitTimeReportResult? QueueWaitTime { get; init; }

    /// <summary>AgentMonthly result (populated when WidgetType = AgentMonthly).</summary>
    public AgentMonthlyReportResult? AgentMonthly { get; init; }

    /// <summary>AgentShiftDetail result (populated when WidgetType = AgentShiftDetail).</summary>
    public AgentShiftDetailReportResult? AgentShiftDetail { get; init; }

    /// <summary>Distribution result (populated when WidgetType = Distribution).</summary>
    public DistributionReportResult? Distribution { get; init; }

    /// <summary>Create a denied result.</summary>
    public static ReportWidgetResult CreateDenied(ReportWidgetType type) => new()
    {
        WidgetType = type,
        Denied = true
    };

    /// <summary>Create an error result.</summary>
    public static ReportWidgetResult CreateError(ReportWidgetType type, string error) => new()
    {
        WidgetType = type,
        Error = error
    };
}

/// <summary>
/// Distribution report result: wait time distribution buckets derived from QueueInterval/QueueWaitTime data.
/// </summary>
public record DistributionReportResult(
    IReadOnlyList<DistributionBucket> Buckets,
    int TotalCount,
    double? OverallAsa);

/// <summary>A bucket in the wait time distribution.</summary>
public record DistributionBucket(
    string Label,
    int LowerBoundSec,
    int? UpperBoundSec,
    int Count,
    double Percentage);
