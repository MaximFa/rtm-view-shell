namespace CcDashboard.Application.Reports.Export;

/// <summary>
/// Abstraction for report export (Infrastructure implements with ClosedXML).
/// </summary>
public interface IReportExporter
{
    Task<byte[]> ExportXlsxAsync(
        string reportName,
        IReadOnlyList<WidgetExportSheet> sheets,
        CancellationToken ct = default);
}

/// <summary>
/// One sheet per widget in the export.
/// </summary>
public record WidgetExportSheet(
    string Title,
    IReadOnlyList<string> Columns,
    IReadOnlyList<object?[]> Rows,
    int TotalCount);
