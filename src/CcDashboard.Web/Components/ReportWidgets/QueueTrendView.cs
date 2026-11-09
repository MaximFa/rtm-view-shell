using System.Globalization;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Domain.Domain.Reports;

namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>
/// The screen's rules for Queue Trend (FEAT-REPORT-QUEUE-TREND-COMPARE-01), in one place the view, the editor and the tests
/// read: which metrics exist (the server's list), which colour each has, which are shown, and where the comparison ends.
/// </summary>
public static class QueueTrendView
{
    /// <summary>The metrics, in the server's order (ReportWidgetConfig.QueueTrendMetrics - the Count / Percent / Duration
    /// columns of the queues row). One list for the editor's defaults and the viewer's window.</summary>
    public static IReadOnlyList<string> Metrics { get; } =
        CcDashboard.Application.HistoricalReports.ReportWidgetConfig.QueueTrendMetrics.Select(c => c.Name).ToList();

    /// <summary>What the chart shows when neither the viewer nor the editor chose: calls offered, answered, average wait.</summary>
    public static IReadOnlyList<string> FallbackMetrics { get; } = new[] { "Offered", "Answered", "Asa" };

    // The colour belongs to the METRIC, not to its place in a list (shell 2026-11-08 16:23Z): a metric that is unticked
    // or reordered must not make the others change colour. The comparison uses the same colour, dashed.
    private static readonly IReadOnlyDictionary<string, string> Colors = new Dictionary<string, string>(StringComparer.Ordinal)
    {
        ["Offered"] = "#3b82f6",
        ["Answered"] = "#22c55e",
        ["Abandoned"] = "#ef4444",
        ["AnsweredInSl"] = "#14b8a6",
        ["SumWaitAnswered"] = "#a16207",
        ["SumTalk"] = "#64748b",
        ["AbandonPct"] = "#ec4899",
        ["SlPct"] = "#a78bfa",
        ["Asa"] = "#f59e0b",
        ["QueueAht"] = "#0ea5e9",
    };

    public static string Color(string metric) => Colors.TryGetValue(metric, out var c) ? c : "#6c757d";

    // ---- the two trend charts (FEAT-REPORT-AGENT-STATE-TREND-01): one screen, the type picks the metrics ----------------

    /// <summary>The report types drawn by the trend screen (QueueTrendReportWidget): one body, no second copy.</summary>
    public static bool IsTrend(ReportWidgetType type) => type is ReportWidgetType.QueueTrend or ReportWidgetType.AgentStateTrend;

    /// <summary>The metrics of a trend type, in the server's order (ReportWidgetConfig.TrendMetrics - one list).</summary>
    public static IReadOnlyList<string> MetricsOf(ReportWidgetType type) =>
        CcDashboard.Application.HistoricalReports.ReportWidgetConfig.TrendMetrics(type).Select(c => c.Name).ToList();

    /// <summary>What Agent State Trend shows when nobody chose: every group - the six lines are the whole of the login time.</summary>
    public static IReadOnlyList<string> FallbackOf(ReportWidgetType type) =>
        type == ReportWidgetType.AgentStateTrend ? MetricsOf(type) : FallbackMetrics;

    // Agent State Trend: ASD's own default group colours (ScreenEditorPage AsdGroupFallbackColors), so the real-time
    // board and the report agree; ASD's colours can be changed per widget, these are its defaults.
    private static readonly IReadOnlyDictionary<string, string> AgentStateColors = new Dictionary<string, string>(StringComparer.Ordinal)
    {
        ["Available"] = "#22c55e",
        ["Onphone"] = "#3b82f6",
        ["Break"] = "#f59e0b",
        ["Paperwork"] = "#8b5cf6",
        ["Training"] = "#06b6d4",
        ["Other"] = "#6b7280",
    };

    public static string ColorOf(ReportWidgetType type, string metric) =>
        type == ReportWidgetType.AgentStateTrend
            ? (AgentStateColors.TryGetValue(metric, out var c) ? c : "#6c757d")
            : Color(metric);

    /// <summary>The resource key of a metric's name. Agent State Trend uses ASD's own group names (one name per group on
    /// both screens); Queue Trend the column labels of Queue Report.</summary>
    public static string LabelKeyOf(ReportWidgetType type, string metric) => type == ReportWidgetType.AgentStateTrend
        ? "Widget_ASD_Segment_" + (metric == "Onphone" ? "OnPhone" : metric)
        : ReportColumnLabels.KeyFor(metric) ?? metric;

    /// <summary>The metrics in force for a type: the viewer's own -> the editor's default -> the type's fallback.</summary>
    public static IReadOnlyList<string> EffectiveOf(ReportWidgetType type, IReadOnlyCollection<string>? personal, IReadOnlyCollection<string>? configDefault)
    {
        var all = MetricsOf(type);
        var fallback = FallbackOf(type);
        var pick = personal is { Count: > 0 } ? personal : configDefault is { Count: > 0 } ? configDefault : fallback;
        var known = all.Where(pick.Contains).ToList();
        return known.Count > 0 ? known : fallback.ToList();
    }

    /// <summary>The metrics in force: the viewer's own -> the editor's default -> the fallback; only known names, in the
    /// server's order.</summary>
    public static IReadOnlyList<string> Effective(IReadOnlyCollection<string>? personal, IReadOnlyCollection<string>? configDefault)
    {
        var pick = personal is { Count: > 0 } ? personal : configDefault is { Count: > 0 } ? configDefault : FallbackMetrics;
        var known = Metrics.Where(pick.Contains).ToList();
        return known.Count > 0 ? known : FallbackMetrics.ToList();
    }

    /// <summary>
    /// The comparison's last day, as the server computes it (contract 16:11Z, operator 18:08): the comparison is as many
    /// days long as the report's From..To. Shown under the date field; the server is the one that applies it.
    /// </summary>
    public static DateTime CompareTo(DateTime compareFrom, DateTime from, DateTime to)
        => compareFrom.Date.AddDays((to.Date - from.Date).Days);

    /// <summary>The number of days of the report's period (both ends counted).</summary>
    public static int Days(DateTime from, DateTime to) => (to.Date - from.Date).Days + 1;

    /// <summary>The chart types, as DayTrend offers them and the shared chart module draws them (line / bar / area / step).
    /// </summary>
    public static IReadOnlyList<string> ChartTypes { get; } = new[] { "line", "bar", "area", "step" };

    /// <summary>
    /// The chart type in force (FEAT-REPORT-QUEUE-TREND-CHART-TYPE-01, operator 2026-11-08 20:47): with a comparison - lines
    /// only, whatever was chosen (the choices are kept, not erased); without - the viewer's own -> the editor's default ->
    /// line. Unknown names count as not chosen.
    /// </summary>
    public static string ChartType(string? personal, string? configDefault, bool comparing)
        => comparing ? "line" : Known(personal) ?? Known(configDefault) ?? "line";

    private static string? Known(string? type) => type is not null && ChartTypes.Contains(type) ? type : null;

    /// <summary>The resource key of a chart type's name - DayTrend's own names, one name per type.</summary>
    public static string ChartTypeKey(string type) => type switch
    {
        "bar" => "DayTrend_ChartBar",
        "area" => "DayTrend_ChartArea",
        "step" => "DayTrend_ChartStep",
        _ => "DayTrend_ChartLine",
    };

    /// <summary>
    /// The part of the axis worth drawing (FEAT-REPORT-TREND-TRIM-ZERO-EDGES-01, operator 2026-11-09 14:07: "the charts must start
    /// with non-zero values and end with them"): from the first interval where ANY shown series - main or comparison, by index -
    /// is non-zero, to the last such. Zeros INSIDE stay (operator 2026-11-08 23:21). Null when every shown value is zero or
    /// missing: the screen says "no data" instead of an empty axis. One rule for both trends.
    /// </summary>
    public static (int First, int Last)? NonZeroRange(IEnumerable<IReadOnlyList<double?>> shown)
    {
        int first = int.MaxValue, last = -1;
        foreach (var series in shown)
            for (var i = 0; i < series.Count; i++)
                if (series[i] is { } v && v != 0)
                {
                    if (i < first) first = i;
                    if (i > last) last = i;
                }
        return last < 0 ? null : (first, last);
    }

    /// <summary>The same indices cut from any list of the chart - labels, values, comparison - so the axes stay aligned.</summary>
    public static T[] Cut<T>(IReadOnlyList<T> items, (int First, int Last) range)
        => items.Skip(range.First).Take(range.Last - range.First + 1).ToArray();

    /// <summary>How the comparison start is kept in the viewer's settings: ISO, whatever the screen's format.</summary>
    public static string ToStored(DateTime d) => d.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    public static DateTime? FromStored(string? s)
        => DateTime.TryParseExact(s, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d) ? d : null;
}
