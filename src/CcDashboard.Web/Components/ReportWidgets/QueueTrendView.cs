using System.Globalization;
using CcDashboard.Application.HistoricalReports.Queries;

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

    /// <summary>How the comparison start is kept in the viewer's settings: ISO, whatever the screen's format.</summary>
    public static string ToStored(DateTime d) => d.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    public static DateTime? FromStored(string? s)
        => DateTime.TryParseExact(s, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d) ? d : null;
}
