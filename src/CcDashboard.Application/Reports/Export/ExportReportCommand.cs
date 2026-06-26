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
    Guid? TenantId = null
) : IRequest<ReportExportResult>, IAuditable
{
    public string AuditEventType => "ReportScreen.Exported";
    public object? AuditDetails => new { ReportId, From, To };
}

public record ReportExportResult(byte[] Content, string FileName, string ContentType);

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

        foreach (var widget in screen.Widgets.Where(w => !w.IsDeleted))
        {
            var query = new RunReportWidgetQuery(
                widget.WidgetType,
                widget.ConfigJson ?? "{}",
                cmd.From,
                cmd.To,
                Page: 1,
                TenantId: cmd.TenantId,
                AllRows: true);

            var result = await mediator.Send(query, ct);

            if (result.Denied || result.Error != null)
            {
                logger.LogWarning("Export: widget {WidgetId} skipped (denied={Denied}, error={Error})",
                    widget.Id, result.Denied, result.Error);
                continue;
            }

            var sheet = BuildSheet(widget, result);
            if (sheet != null)
                sheets.Add(sheet);
        }

        var content = await exporter.ExportXlsxAsync(screen.Name, sheets, ct);

        var sanitizedName = SanitizeFileName(screen.Name);
        var fileName = $"{sanitizedName}_{cmd.From:yyyyMMdd}-{cmd.To:yyyyMMdd}_{clock.UtcNow:yyyyMMddHHmmss}.xlsx";
        var contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

        return new ReportExportResult(content, fileName, contentType);
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
