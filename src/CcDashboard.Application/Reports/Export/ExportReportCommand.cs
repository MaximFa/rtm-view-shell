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
    // FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01: each widget's own funnel filters (a filter lives in its widget, over that
    // widget's columns), keyed by WidgetId, so the file equals the screen even when two widgets are filtered differently.
    // A widget without an entry is exported unfiltered; a filter on a column the type does not have is refused by the run
    // (the widget is then listed in Skipped with invalid-config, never silently exported unfiltered).
    IReadOnlyDictionary<Guid, IReadOnlyList<ReportColumnFilter>>? Filters = null,
    // FEAT-REPORT-EOS-CONFIGURABLE-01: each end-of-shift queues widget's interval step, keyed by WidgetId (absent = Day).
    IReadOnlyDictionary<Guid, ReportStep>? Steps = null
) : IRequest<ReportExportResult>, IAuditable
{
    public string AuditEventType => "ReportScreen.Exported";
    public object? AuditDetails => new { ReportId, From, To, Filters, Steps };
}



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
            // only the end-of-shift AGENTS report is one date with shift hours; the queues report takes From..To and a step
            var endOfShift = widget.WidgetType is ReportWidgetType.EndOfShiftAgents;
            ReportStep? step = null;
            if (widget.WidgetType is ReportWidgetType.EndOfShiftQueues && cmd.Steps != null && cmd.Steps.TryGetValue(widget.Id, out var s))
                step = s;
            IReadOnlyList<ReportColumnFilter>? filters = null;
            cmd.Filters?.TryGetValue(widget.Id, out filters);
            var query = new RunReportWidgetQuery(
                widget.WidgetType,
                widget.ConfigJson ?? "{}",
                endOfShift ? cmd.From.Date : cmd.From,
                endOfShift ? cmd.From.Date : cmd.To,
                Page: 1,
                TenantId: cmd.TenantId,
                AllRows: true,
                Filters: filters,
                Step: step);

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

            var sheet = BuildSheet(widget, result, query.From, query.To);
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

    private static WidgetExportSheet? BuildSheet(ReportWidget widget, ReportWidgetResult result, DateTime from, DateTime to)
    {
        var title = GetWidgetTitle(widget);
        var columns = result.EffectiveColumns ?? Array.Empty<string>();

        var (rows, totalCount) = result.WidgetType switch
        {
            ReportWidgetType.AgentMonthly when result.AgentMonthly != null =>
                (ProjectRows(result.AgentMonthly.Rows, columns), result.AgentMonthly.TotalCount),
            ReportWidgetType.AgentShiftDetail when result.AgentShiftDetail != null =>
                (ProjectRows(result.AgentShiftDetail.Rows, columns), result.AgentShiftDetail.TotalCount),
            ReportWidgetType.EndOfShiftAgents or ReportWidgetType.AgentPerformance when result.AgentSummary != null =>
                (ProjectRows(result.AgentSummary.Rows, columns), result.AgentSummary.TotalCount),
            ReportWidgetType.EndOfShiftQueues when result.QueueSummary != null =>
                (ProjectRows(result.QueueSummary.Rows, columns), result.QueueSummary.TotalCount),
            _ => (new List<object?[]>(), 0)
        };

        if (rows.Count == 0)
            return null;

        // FEAT-REPORT-EOS-CONFIGURABLE-01 (coordinator 11:22:59Z): file = screen - the start of an interval is written by
        // the one label rule the screen uses (ReportIntervalLabel: by the step the server used, with the cut-edge mark),
        // with the period of the same query. The mark sentences are the en-US ones, like every other text of the file.
        if (result.WidgetType == ReportWidgetType.EndOfShiftQueues && result.Step is { } step)
        {
            var at = columns.ToList().FindIndex(c => string.Equals(c, nameof(QueueSummaryRow.IntervalStart), StringComparison.OrdinalIgnoreCase));
            if (at >= 0)
                foreach (var row in rows)
                    if (row[at] is DateTime start)
                        row[at] = ReportIntervalLabel.Cell(start, step, result.PartialFirst, result.PartialLast, from, to,
                            IntervalFromText, IntervalToText, IntervalFromToText);
        }

        // retired types (QueueInterval, QueueWaitTime, Distribution) never get here: their run returns ErrorCode retired
        var effectiveColumns = columns.ToArray();

        return new WidgetExportSheet(title, effectiveColumns, rows, totalCount);
    }

    // the en-US values of Report_IntervalFrom / _To / _FromTo (Web SharedResources), as the rest of the file is English
    public const string IntervalFromText = "(from {0})";
    public const string IntervalToText = "(to {0})";
    public const string IntervalFromToText = "(from {0} to {1})";

    // The file carries a fixed sentence per code, never the validation text (which is for the log).
    public static string SheetText(string code) => code switch
    {
        ReportReasonCodes.Denied => "No access to this widget's data",
        ReportReasonCodes.NoData => "No data for the selected period",
        ReportReasonCodes.ShiftHours => "Shift hours are not set or not valid for this widget",
        ReportReasonCodes.InvalidConfig => "The widget settings are not valid",
        ReportReasonCodes.Retired => "This report type has been retired",
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

        // PR234 (coordinator 15:05:51Z): the type's English human name, not the enum name
        return ReportTypeNames.English(widget.WidgetType);
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


    private static string SanitizeFileName(string name)
    {
        var invalid = new Regex(@"[<>:""/\\|?*]");
        var sanitized = invalid.Replace(name, "_");
        return sanitized.Length > 50 ? sanitized[..50] : sanitized;
    }
}
