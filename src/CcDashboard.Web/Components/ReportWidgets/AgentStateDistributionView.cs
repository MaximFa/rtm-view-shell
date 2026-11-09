using System.Globalization;

namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>
/// The screen's rules for Agent State Distribution (FEAT-REPORT-AGENT-STATE-DISTRIBUTION-01): which period is asked for,
/// and how the donut writes its numbers. The shares themselves are the SERVER's (AgentStateShares - one rule with Agent
/// State Trend); the groups, their names and colours are Agent State Trend's (QueueTrendView ...Of(AgentStateTrend)).
/// </summary>
public static class AgentStateDistributionView
{
    /// <summary>The viewer's own period, kept in the widget's one settings row (ISO, like the trend's comparison start).</summary>
    public const string FromKey = "reportOwnFrom";
    public const string ToKey = "reportOwnTo";

    /// <summary>
    /// The period asked for (operator 2026-11-09 06:41: "if set - by it, if not - by the report's interval"). ONE place for
    /// the rule - the server is sent plain From/To (coordinator 04:43:29Z). Own = both ends set and in order.
    /// </summary>
    public static (DateTime From, DateTime To, bool Own) Period(DateTime? ownFrom, DateTime? ownTo, DateTime pageFrom, DateTime pageTo)
        => ownFrom is { } f && ownTo is { } t && f.Date <= t.Date ? (f.Date, t.Date, true) : (pageFrom, pageTo, false);

    /// <summary>What the window may apply: both ends empty (the report's period) or both set and in order.</summary>
    public static bool CanApply(DateTime? ownFrom, DateTime? ownTo)
        => (ownFrom is null && ownTo is null) || (ownFrom is { } f && ownTo is { } t && f.Date <= t.Date);

    /// <summary>A segment of the ring: a negative "Other" (durations past the login time, logged by the server) is no arc -
    /// the legend still shows the true value.</summary>
    public static long Segment(long ms) => Math.Max(0, ms);

    /// <summary>The share as the legend writes it: one decimal, or a dash when the server has none.</summary>
    public static string Share(double? share)
        => share is { } s ? s.ToString("0.0", CultureInfo.InvariantCulture) + "%" : "—";

    /// <summary>A group's time in the legend: h:mm:ss from an hour, else m:ss (hours are not wrapped at 24).</summary>
    public static string Duration(long ms)
    {
        var t = (long)Math.Round(Math.Max(0, ms) / 1000.0);
        var h = t / 3600; var m = t % 3600 / 60; var s = t % 60;
        return h > 0
            ? string.Create(CultureInfo.InvariantCulture, $"{h}:{m:00}:{s:00}")
            : string.Create(CultureInfo.InvariantCulture, $"{m}:{s:00}");
    }

    public static string ToStored(DateTime d) => QueueTrendView.ToStored(d);
    public static DateTime? FromStored(string? s) => QueueTrendView.FromStored(s);
}
