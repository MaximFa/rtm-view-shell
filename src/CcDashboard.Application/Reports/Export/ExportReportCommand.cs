using CcDashboard.Application.Behaviors;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;
using System.Reflection;
using System.Text.RegularExpressions;

namespace CcDashboard.Application.Reports.Export;

public record ExportReportCommand(
    Guid ReportId,
    DateTime From,
    DateTime To,
    Guid? TenantId = null,
    // PR234-V4-REPORT-VIEW-NO-AGENT-QUEUE-FILTER-01: each widget's own view filters (a filter lives in its widget, over that
    // widget's columns), keyed by WidgetId, so the file equals the screen even when two widgets are filtered differently.
    // A widget without an entry is exported unfiltered; a filter its type has no column for is not passed on.
    IReadOnlyDictionary<Guid, WidgetViewFilter>? Filters = null
) : IRequest<ReportExportResult>, IAuditable
{
    public string AuditEventType => "ReportScreen.Exported";
    public object? AuditDetails => new { ReportId, From, To, Filters };
}

/// <summary>One widget's view filters: Agent = login column, AgentName = name column, Queue = queue column.</summary>
public record WidgetViewFilter(ReportColumnFilter? AgentFilter = null, ReportColumnFilter? AgentNameFilter = null, ReportColumnFilter? QueueFilter = null);

/// <summary>
/// The file plus every widget that did not become a data sheet, with the reason. The same list is the last sheet of the
/// file ("Not exported"), so a missing widget is never silent - neither in the app nor in the file someone forwards.
/// </summary>
public record ReportExportResult(byte[] Content, string FileName, string ContentType)
{
    public IReadOnlyList<SkippedWidget> Skipped { get; init; } = Array.Empty<SkippedWidget>();
}

/// <summary>ReasonCode (<see cref="ReportReasonCodes"/>) is what the screen shows; Reason is for the log only.</summary>
public record SkippedWidget(Guid WidgetId, string Title, string ReasonCode, string Reason);

public class ExportReportCommandHandler(
    IReportScreenRepository repo,
    IReportExporter exporter,
    IMediator mediator,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock,
    ILogger<ExportReportCommandHandler> logger)
    : IRequestHandler<ExportReportCommand, ReportExportResult>
{
    public async Task<ReportExportResult> Handle(ExportReportCommand cmd, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";
        var tenantId = isSuperadmin
            ? (cmd.TenantId ?? currentUser.TenantId!.Value)
            : currentUser.TenantId!.Value;

        var screen = await repo.GetByIdWithWidgetsAsync(cmd.ReportId, bypassTenantFilter: isSuperadmin, ct)
            ?? throw new NotFoundException(nameof(ReportScreen), cmd.ReportId);

        var sheets = new List<WidgetExportSheet>();
        var skipped = new List<SkippedWidget>();

        foreach (var widget in screen.Widgets.Where(w => !w.IsDeleted))
        {
            // PR234-V4-EOS-WIDGETS-NO-SHIFT-HOURS-01: an end-of-shift widget covers one date - the screen's first day - and
            // its own shift hours, which the run takes from the widget config (no hours on the query).
            var endOfShift = widget.WidgetType is ReportWidgetType.EndOfShiftAgents or ReportWidgetType.EndOfShiftQueues;
            var agentType = widget.WidgetType is ReportWidgetType.EndOfShiftAgents or ReportWidgetType.AgentPerformance;
            WidgetViewFilter? filter = null;
            cmd.Filters?.TryGetValue(widget.Id, out filter);
            var query = new RunReportWidgetQuery(
                widget.WidgetType,
                widget.ConfigJson ?? "{}",
                endOfShift ? cmd.From.Date : cmd.From,
                endOfShift ? cmd.From.Date : cmd.To,
                Page: 1,
                TenantId: cmd.TenantId,
                AllRows: true,
                AgentFilter: agentType ? filter?.AgentFilter : null,
                AgentNameFilter: agentType ? filter?.AgentNameFilter : null,
                QueueFilter: widget.WidgetType is ReportWidgetType.EndOfShiftQueues ? filter?.QueueFilter : null);

            var title = GetWidgetTitle(widget);
            ReportWidgetResult result;
            try
            {
                result = await mediator.Send(query, ct);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                // One widget that throws must not cost the user the whole file: it is listed, the rest is exported.
                logger.LogError(ex, "Export: widget {WidgetId} ({Type}) threw; listed as not exported", widget.Id, widget.WidgetType);
                skipped.Add(new SkippedWidget(widget.Id, title, ReportReasonCodes.Unrecognised, ex.GetType().Name + ": " + ex.Message));
                continue;
            }

            if (result.Denied || result.Error != null)
            {
                logger.LogWarning("Export: widget {WidgetId} skipped (denied={Denied}, error={Error})",
                    widget.Id, result.Denied, result.Error);
                var code = result.Denied ? ReportReasonCodes.Denied : result.ErrorCode;
                if (code is null || !ReportReasonCodes.All.Contains(code))
                {
                    // An error the screen cannot translate is still listed (general sentence), and the log names it.
                    logger.LogWarning("Export: widget {WidgetId} failed with unrecognised reason code '{Code}'", widget.Id, code);
                    code = ReportReasonCodes.Unrecognised;
                }
                skipped.Add(new SkippedWidget(widget.Id, title, code, result.Denied ? "No access" : result.Error ?? ""));
                continue;
            }

            var sheet = BuildSheet(widget, result);
            if (sheet != null)
                sheets.Add(sheet);
            else
                skipped.Add(new SkippedWidget(widget.Id, title, ReportReasonCodes.NoData, "No data for the selected period"));
        }

        if (skipped.Count > 0)
            sheets.Add(new WidgetExportSheet(
                "Not exported",
                new[] { "Widget", "Reason" },
                skipped.Select(s => new object?[] { s.Title, SheetText(s.ReasonCode) }).ToList(),
                skipped.Count));

        var content = await exporter.ExportXlsxAsync(screen.Name, sheets, ct);

        var sanitizedName = SanitizeFileName(screen.Name);
        var fileName = $"{sanitizedName}_{cmd.From:yyyyMMdd}-{cmd.To:yyyyMMdd}_{clock.UtcNow:yyyyMMddHHmmss}.xlsx";
        var contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

        return new ReportExportResult(content, fileName, contentType) { Skipped = skipped };
    }

    private static WidgetExportSheet? BuildSheet(ReportWidget widget, ReportWidgetResult result)
    {
        var title = GetWidgetTitle(widget);
        var columns = result.EffectiveColumns ?? Array.Empty<string>();

        var (rows, totalCount) = result.WidgetType switch
        {
            ReportWidgetType.QueueInterval when result.QueueInterval != null =>
                (ProjectRows(result.QueueInterval.Rows, columns), result.QueueInterval.TotalCount),
            ReportWidgetType.QueueWaitTime when result.QueueWaitTime != null =>
                (ProjectRows(result.QueueWaitTime.Rows, columns), result.QueueWaitTime.TotalCount),
            ReportWidgetType.AgentMonthly when result.AgentMonthly != null =>
                (ProjectRows(result.AgentMonthly.Rows, columns), result.AgentMonthly.TotalCount),
            ReportWidgetType.AgentShiftDetail when result.AgentShiftDetail != null =>
                (ProjectRows(result.AgentShiftDetail.Rows, columns), result.AgentShiftDetail.TotalCount),
            ReportWidgetType.EndOfShiftAgents or ReportWidgetType.AgentPerformance when result.AgentSummary != null =>
                (ProjectRows(result.AgentSummary.Rows, columns), result.AgentSummary.TotalCount),
            ReportWidgetType.EndOfShiftQueues when result.QueueSummary != null =>
                (ProjectRows(result.QueueSummary.Rows, columns), result.QueueSummary.TotalCount),
            ReportWidgetType.Distribution when result.Distribution != null =>
                (ProjectDistributionRows(result.Distribution.Buckets), result.Distribution.TotalCount),
            _ => (new List<object?[]>(), 0)
        };

        if (rows.Count == 0)
            return null;

        var effectiveColumns = result.WidgetType == ReportWidgetType.Distribution
            ? new[] { "Label", "Count", "Percentage" }
            : columns.ToArray();

        return new WidgetExportSheet(title, effectiveColumns, rows, totalCount);
    }

    // The file carries a fixed sentence per code, never the validation text (which is for the log).
    public static string SheetText(string code) => code switch
    {
        ReportReasonCodes.Denied => "No access to this widget's data",
        ReportReasonCodes.NoData => "No data for the selected period",
        ReportReasonCodes.ShiftHours => "Shift hours are not set or not valid for this widget",
        ReportReasonCodes.InvalidConfig => "The widget settings are not valid",
        _ => "Not exported - reason not recognised"
    };

    private static string GetWidgetTitle(ReportWidget widget)
    {
        if (!string.IsNullOrEmpty(widget.ConfigJson))
        {
            try
            {
                var config = ReportWidgetConfig.Parse(widget.ConfigJson);
                if (!string.IsNullOrEmpty(config.Title))
                    return config.Title;
            }
            catch { }
        }

        return widget.WidgetType.ToString();
    }

    private static List<object?[]> ProjectRows<T>(IReadOnlyList<T> rows, IReadOnlyList<string> columns) where T : class
    {
        if (rows.Count == 0 || columns.Count == 0)
            return new List<object?[]>();

        var type = typeof(T);
        var propCache = columns
            .Select(c => type.GetProperty(c, BindingFlags.Public | BindingFlags.Instance | BindingFlags.IgnoreCase))
            .ToArray();

        var result = new List<object?[]>(rows.Count);
        foreach (var row in rows)
        {
            var values = new object?[columns.Count];
            for (var i = 0; i < propCache.Length; i++)
            {
                values[i] = propCache[i]?.GetValue(row);
            }
            result.Add(values);
        }

        return result;
    }

    private static List<object?[]> ProjectDistributionRows(IReadOnlyList<DistributionBucket> buckets)
    {
        return buckets
            .Select(b => new object?[] { b.Label, b.Count, b.Percentage })
            .ToList();
    }

    private static string SanitizeFileName(string name)
    {
        var invalid = new Regex(@"[<>:""/\\|?*]");
        var sanitized = invalid.Replace(name, "_");
        return sanitized.Length > 50 ? sanitized[..50] : sanitized;
    }
}
