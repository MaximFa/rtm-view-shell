using MediatR;

namespace CcDashboard.Application.Queries.Widgets;

/// <summary>
/// Narrow format row returned by both fn_daytrendinteractions and fn_daytrendagentstatus.
/// Column names must match exactly (EF maps by convention).
/// </summary>
public record DayTrendMetricRow(DateTime interval_start, string metric_id, double? value);

/// <summary>
/// Per-interval grouped result. Keys are RTSGrid_Metric.MetricId strings.
/// </summary>
public record DayTrendIntervalData(
    DateTime IntervalStart,
    IReadOnlyDictionary<string, double?> Metrics);

/// <summary>
/// Query result for DayTrend widget.
/// </summary>
public record DayTrendResult(
    IReadOnlyList<DayTrendIntervalData> Intervals,
    bool IsNoQueues = false)
{
    public static DayTrendResult NoQueues() => new(Array.Empty<DayTrendIntervalData>(), true);
    public static DayTrendResult Empty() => new(Array.Empty<DayTrendIntervalData>());
}

/// <summary>
/// CQRS query for DayTrend widget data.
/// </summary>
public record DayTrendQuery(
    int BusinessUnitId,
    int IntervalMinutes,
    bool IncludeAgentMetrics,
    DateOnly? OnDate = null
) : IRequest<DayTrendResult>;
