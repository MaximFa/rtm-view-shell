using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using System.Globalization;

namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>
/// The funnel filters a report widget currently has on screen, and the window that is open.
///
/// One object instead of seven copies of the same six fields: every table report now carries
/// funnels, and the last time this state was written out by hand it was written three times and
/// already differed between them. Screen state only - a filter is never saved to the widget's
/// configuration (operator's rule, 2026-11-07): a stored filter would open tomorrow's shift
/// already narrowed, and whoever opened it would read an empty table as "there was no work".
/// </summary>
public sealed class ReportFilterState
{
    private readonly Dictionary<string, ReportColumnFilter> _applied = new(StringComparer.Ordinal);

    /// <summary>The column whose window is open, or null.</summary>
    public string? OpenColumn { get; private set; }

    /// <summary>The checkbox values offered for the open column.</summary>
    public IReadOnlyList<string> Values { get; private set; } = Array.Empty<string>();

    public int ValuesTotal { get; private set; }
    public bool ValuesTruncated { get; private set; }
    public bool ValuesLoading { get; private set; }

    public bool Any => _applied.Count > 0;

    public ReportColumnFilter? For(string column) => _applied.GetValueOrDefault(column);

    /// <summary>The filters as the query takes them; null when nothing is filtered.</summary>
    public IReadOnlyList<ReportColumnFilter>? ForQuery()
        => _applied.Count == 0 ? null : _applied.Values.ToList();

    /// <summary>Open a column's window (or close it if it is the open one). Returns true when it opened.</summary>
    public bool Toggle(string column)
    {
        if (OpenColumn == column)
        {
            OpenColumn = null;
            return false;
        }

        OpenColumn = column;
        Values = Array.Empty<string>();
        ValuesTotal = 0;
        ValuesTruncated = false;
        return true;
    }

    public void Close() => OpenColumn = null;

    public void BeginLoadingValues() => ValuesLoading = true;

    public void EndLoadingValues() => ValuesLoading = false;

    public void SetValues(ReportColumnValues values)
    {
        Values = values.Values;
        ValuesTotal = values.TotalCount;
        ValuesTruncated = values.Truncated;
    }

    /// <summary>
    /// Store what the window returned, or drop the column's filter when the window came back
    /// empty. An empty filter is removed rather than stored as "a filter that matches everything":
    /// the funnel's own look says whether a column is filtered, and a filter that filters nothing
    /// would light it up for no reason.
    /// </summary>
    public void Apply(string column, ReportColumnFilter? filter)
    {
        if (filter is null) _applied.Remove(column);
        else _applied[column] = filter;
        OpenColumn = null;
    }

    public void Clear(string column)
    {
        _applied.Remove(column);
        OpenColumn = null;
    }

    public void ClearAll()
    {
        _applied.Clear();
        OpenColumn = null;
    }

    /// <summary>
    /// Turn what a person typed into a filter in the COLUMN'S OWN unit, or null when they left the
    /// window empty.
    ///
    /// The unit matters more than it looks: a duration column stores milliseconds or seconds, and
    /// the window takes "h:mm:ss" because that is what the cell shows. Sending the typed number
    /// straight through would filter by a thousandth of what the person meant - the same mistake,
    /// in the opposite direction, as the total that was printed through the wrong formatter.
    /// </summary>
    public static ReportColumnFilter? Build(string column, ReportColumnKind kind, ColumnFilterDraft draft)
    {
        if (draft.Values.Count > 0)
            return new ReportColumnFilter(column, Values: draft.Values);

        return kind switch
        {
            ReportColumnKind.Text or ReportColumnKind.Id =>
                string.IsNullOrWhiteSpace(draft.Text)
                    ? null
                    : new ReportColumnFilter(column, draft.Op, draft.Text.Trim()),

            ReportColumnKind.DateTime or ReportColumnKind.Date =>
                draft.Time is null && draft.TimeTo is null
                    ? null
                    : new ReportColumnFilter(column, draft.Op, Time: draft.Time, TimeTo: draft.TimeTo),

            _ => BuildNumber(column, kind, draft)
        };
    }

    private static ReportColumnFilter? BuildNumber(string column, ReportColumnKind kind, ColumnFilterDraft draft)
    {
        var from = ToColumnUnit(kind, draft.Number);
        var to = ToColumnUnit(kind, draft.NumberTo);
        if (from is null && to is null) return null;
        return new ReportColumnFilter(column, draft.Op, Number: from, NumberTo: to);
    }

    /// <summary>A number as the person reads it -> the unit the column is stored in.</summary>
    private static double? ToColumnUnit(ReportColumnKind kind, double? typed)
        => typed is null ? null : kind == ReportColumnKind.DurationMs ? typed * 1000.0 : typed;

    /// <summary>
    /// "h:mm:ss", "mm:ss" or plain seconds -> seconds. Returns null when it is not a time at all,
    /// so the window can refuse rather than filter by a number nobody typed.
    /// </summary>
    public static double? ParseDuration(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;

        var parts = text.Split(':', StringSplitOptions.TrimEntries);
        if (parts.Length > 3) return null;

        double total = 0;
        foreach (var part in parts)
        {
            if (!double.TryParse(part, NumberStyles.Any, CultureInfo.InvariantCulture, out var value)) return null;
            total = total * 60 + value;
        }
        return total;
    }

    /// <summary>A plain number as typed, or null when the text is not a number.</summary>
    public static double? ParseNumber(string? text)
        => double.TryParse(text, NumberStyles.Any, CultureInfo.CurrentCulture, out var value)
            || double.TryParse(text, NumberStyles.Any, CultureInfo.InvariantCulture, out value)
            ? value
            : null;
}

/// <summary>What the filter window hands back: everything it could have collected, in people's units.</summary>
public record ColumnFilterDraft(
    string Op,
    string Text,
    IReadOnlyList<string> Values,
    double? Number = null,
    double? NumberTo = null,
    DateTime? Time = null,
    DateTime? TimeTo = null);
