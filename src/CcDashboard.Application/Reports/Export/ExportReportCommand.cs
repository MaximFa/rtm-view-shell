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
    // FEAT-REPORT-EOS-CONFIGURABLE-01: each end-of-shift widget's interval step, keyed by WidgetId (absent = the widget's
    // DefaultStep, else Day).
    IReadOnlyDictionary<Guid, ReportStep>? Steps = null,
    // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: each end-of-shift agents widget's row mode, keyed by WidgetId (absent = the
    // widget's DefaultRowMode, else Summary).
    IReadOnlyDictionary<Guid, ReportRowMode>? Modes = null
) : IRequest<ReportExportResult>, IAuditable
{
    public string AuditEventType => "ReportScreen.Exported";
    public object? AuditDetails => new { ReportId, From, To, Filters, Steps, Modes };
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
            // FEAT-REPORT-QUEUE-TREND-COMPARE-01 (operator 2026-11-08 18:22, «пока не выгружаем»): a chart is listed, not run
            if (CcDashboard.Application.Handlers.RunReportWidgetQueryHandler.IsChart(widget.WidgetType))
            {
                skipped.Add(new SkippedWidget(widget.Id, GetWidgetTitle(widget), ReportReasonCodes.NotExportable, "A chart is not exported"));
                continue;
            }

            // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: every report covers the screen's From..To; the step and the row mode the
            // screen shows travel per widget (a type that does not take them gets none, so it is not refused for them)
            ReportStep? step = null;
            if (CcDashboard.Application.Handlers.RunReportWidgetQueryHandler.TakesStep(widget.WidgetType) && cmd.Steps != null && cmd.Steps.TryGetValue(widget.Id, out var s))
                step = s;
            ReportRowMode? mode = null;
            if (widget.WidgetType is ReportWidgetType.EndOfShiftAgents && cmd.Modes != null && cmd.Modes.TryGetValue(widget.Id, out var m))
                mode = m;
            IReadOnlyList<ReportColumnFilter>? filters = null;
            cmd.Filters?.TryGetValue(widget.Id, out filters);
            var query = new RunReportWidgetQuery(
                widget.WidgetType,
                widget.ConfigJson ?? "{}",
                cmd.From,
                cmd.To,
                Page: 1,
                TenantId: cmd.TenantId,
                AllRows: true,
                Filters: filters,
                Step: step,
                RowMode: mode);

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
            // retired types (AgentMonthly, AgentShiftDetail, AgentPerformance, the old queue reports) never get here
            ReportWidgetType.EndOfShiftAgents when result.AgentSummary != null =>
                (ProjectRows(result.AgentSummary.Rows, columns), result.AgentSummary.TotalCount),
            ReportWidgetType.EndOfShiftQueues when result.QueueSummary != null =>
                (ProjectRows(result.QueueSummary.Rows, columns), result.QueueSummary.TotalCount),
            _ => (new List<object?[]>(), 0)
        };

        if (rows.Count == 0)
            return null;

        // FEAT-REPORT-EOS-CONFIGURABLE-01 (coordinator 11:22:59Z): file = screen - the start of an interval is written by
        // the one label rule the screen uses (ReportIntervalLabel, by the step the server used).
        // FEAT-REPORT-INTERVAL-LABEL-NO-EDGE-MARK-01 (operator 2026-11-07 18:51): no cut-edge mark in brackets, on the
        // screen or in the file; PartialFirst / PartialLast stay in the answer.
        if (result.WidgetType is ReportWidgetType.EndOfShiftQueues or ReportWidgetType.EndOfShiftAgents && result.Step is { } step)
        {
            var at = columns.ToList().FindIndex(c => string.Equals(c, nameof(QueueSummaryRow.IntervalStart), StringComparison.OrdinalIgnoreCase));
            if (at >= 0)
                foreach (var row in rows)
                    if (row[at] is DateTime start)
                        row[at] = ReportIntervalLabel.Cell(start, step);
        }

        // retired types (QueueInterval, QueueWaitTime, Distribution) never get here: their run returns ErrorCode retired
        var effectiveColumns = columns.ToArray();

        return new WidgetExportSheet(title, effectiveColumns, rows, totalCount);
    }

    // The file carries a fixed sentence per code, never the validation text (which is for the log).
    public static string SheetText(string code) => code switch
    {
        ReportReasonCodes.Denied => "No access to this widget's data",
        ReportReasonCodes.NoData => "No data for the selected period",
        ReportReasonCodes.InvalidConfig => "The widget settings are not valid",
        ReportReasonCodes.Retired => "This report type has been retired",
        ReportReasonCodes.NotExportable => "A chart is not exported",
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
