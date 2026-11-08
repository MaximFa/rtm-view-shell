using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Domain.Domain.Reports;
using MediatR;

namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>
/// FEAT-REPORT-DEFAULT-LAST-DATA-DAY-01 (operator "yes", 2026-11-07 11:05): the day a report screen
/// opens on is the last day that has data, not a today that may be empty - an empty first view
/// reads as "there was no work". Today stays when today has data (the server returns it then).
///
/// One place for both screens that show reports - the viewer and the editor's preview. Written
/// once in each page, the two copies would disagree the first time one of them was touched.
///
/// Asked per widget, because the day depends on each widget's own scope; the screen takes the
/// LATEST of them, so no widget opens past its own data while another has newer rows. Only the
/// types the server's rule covers are asked - today the end-of-shift queues report; for any other
/// type the rule answers invalid-config, which means "no rule yet", not a fault of the screen.
/// </summary>
public static class ReportDefaultDay
{
    /// <summary>The report types the server's last-data-day rule covers today.</summary>
    public static readonly IReadOnlySet<ReportWidgetType> Covered = new HashSet<ReportWidgetType>
    {
        ReportWidgetType.EndOfShiftQueues,
        // Agent Report (coordinator 2026-11-08T06:27:37Z, p.6: part of the same configuration): ReportDataSet.Agents on the server.
        ReportWidgetType.EndOfShiftAgents,
        // Queue Trend: ReportDataSet.Queues on the server, narrowed by the widget's queues (backend 16:34:21Z).
        ReportWidgetType.QueueTrend
    };

    /// <summary>
    /// The latest last-data-day over the covered widgets, or null when none has data or none is
    /// covered - the caller then keeps the site's today. A widget whose question fails is logged
    /// and skipped: no default is not a reason to refuse the screen.
    /// </summary>
    public static async Task<DateTime?> LatestAsync(
        IMediator mediator,
        IEnumerable<(Guid Id, ReportWidgetType Type, string? ConfigJson)> widgets,
        Guid? tenantId,
        ILogger logger,
        CancellationToken ct)
    {
        DateOnly? latest = null;
        foreach (var (id, type, configJson) in widgets)
        {
            if (!Covered.Contains(type)) continue;
            try
            {
                var res = await mediator.Send(new GetLastDataDayQuery(type, configJson ?? "{}", tenantId), ct);
                if (res.Day is { } day)
                {
                    if (latest is null || day > latest) latest = day;
                }
                else if (res.ErrorCode is not null)
                {
                    logger.LogInformation("Last data day for widget {WidgetId}: {ErrorCode}", id, res.ErrorCode);
                }
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogWarning(ex, "Last data day for widget {WidgetId} could not be read", id);
            }
        }
        return latest?.ToDateTime(TimeOnly.MinValue);
    }
}
