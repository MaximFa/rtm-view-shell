using CcDashboard.Application.Reports.Export;
using ClosedXML.Excel;
using Microsoft.Extensions.Logging;
using System.Text.RegularExpressions;

namespace CcDashboard.Infrastructure.Reports.Export;

public class ClosedXmlReportExporter(ILogger<ClosedXmlReportExporter> logger) : IReportExporter
{
    private const int ExportRowCap = 50000;

    public Task<byte[]> ExportXlsxAsync(
        string reportName,
        IReadOnlyList<WidgetExportSheet> sheets,
        CancellationToken ct = default)
    {
        using var workbook = new XLWorkbook();
        var sheetIndex = 1;

        foreach (var sheet in sheets)
        {
            var sheetName = SanitizeSheetName(sheet.Title, sheetIndex);
            var worksheet = workbook.Worksheets.Add(sheetName);

            WriteHeaders(worksheet, sheet.Columns);
            var rowsWritten = WriteDataRows(worksheet, sheet.Rows, sheet.TotalCount);

            if (sheet.TotalCount > ExportRowCap)
            {
                logger.LogWarning(
                    "Export: sheet '{SheetName}' truncated to {Cap} rows (total: {Total})",
                    sheetName, ExportRowCap, sheet.TotalCount);
                WriteTruncationNote(worksheet, sheet.Columns.Count, rowsWritten, sheet.TotalCount);
            }

            worksheet.Columns().AdjustToContents(1, 100);
            sheetIndex++;
        }

        using var ms = new MemoryStream();
        workbook.SaveAs(ms);
        return Task.FromResult(ms.ToArray());
    }

    private static void WriteHeaders(IXLWorksheet ws, IReadOnlyList<string> columns)
    {
        for (var i = 0; i < columns.Count; i++)
        {
            var cell = ws.Cell(1, i + 1);
            cell.Value = columns[i];
            cell.Style.Font.Bold = true;
            cell.Style.Fill.BackgroundColor = XLColor.LightGray;
        }
    }

    private static int WriteDataRows(IXLWorksheet ws, IReadOnlyList<object?[]> rows, int totalCount)
    {
        var rowsToWrite = Math.Min(rows.Count, ExportRowCap);

        for (var rowIdx = 0; rowIdx < rowsToWrite; rowIdx++)
        {
            var rowData = rows[rowIdx];
            for (var colIdx = 0; colIdx < rowData.Length; colIdx++)
            {
                var cell = ws.Cell(rowIdx + 2, colIdx + 1);
                SetCellValue(cell, rowData[colIdx]);
            }
        }

        return rowsToWrite;
    }

    private static void SetCellValue(IXLCell cell, object? value)
    {
        switch (value)
        {
            case null:
                cell.Value = Blank.Value;
                break;
            case DateTime dt:
                cell.Value = dt;
                cell.Style.NumberFormat.Format = "yyyy-MM-dd HH:mm";
                break;
            case int i:
                cell.Value = i;
                break;
            case long l:
                cell.Value = l;
                break;
            case double d:
                cell.Value = d;
                if (Math.Abs(d) < 1000)
                    cell.Style.NumberFormat.Format = "#,##0.00";
                break;
            case decimal dec:
                cell.Value = (double)dec;
                break;
            case string s:
                cell.Value = s;
                break;
            default:
                cell.Value = value.ToString();
                break;
        }
    }

    private static void WriteTruncationNote(IXLWorksheet ws, int colCount, int rowsWritten, int totalCount)
    {
        var noteRow = rowsWritten + 3;
        var noteCell = ws.Cell(noteRow, 1);
        noteCell.Value = $"Truncated: showing {rowsWritten:N0} of {totalCount:N0} rows";
        noteCell.Style.Font.Bold = true;
        noteCell.Style.Font.FontColor = XLColor.Red;
        ws.Range(noteRow, 1, noteRow, Math.Max(colCount, 3)).Merge();
    }

    private static string SanitizeSheetName(string title, int index)
    {
        var invalidChars = new Regex(@"[\[\]:\\/?*]");
        var sanitized = invalidChars.Replace(title, "_");

        if (sanitized.Length > 31)
            sanitized = sanitized[..28] + $"_{index}";

        if (string.IsNullOrWhiteSpace(sanitized))
            sanitized = $"Sheet{index}";

        return sanitized;
    }
}
