namespace CcDashboard.Contracts.Common;

/// <summary>
/// A duration that keeps running on the screen.
///
/// The engine does not send the duration: it sends the moment it started, as "+dd/MM/yyyy HH:mm:ss"
/// (RTM/Union.cs:1125). A widget strips the "+", keeps the start as a timer anchor, and the cell
/// shows how much time has passed since. Sorting, funnel filters and saved filter rules used to
/// compare the STORED string instead — a timestamp — so such a column sorted lexically, by day of
/// month: 05/11 ranked above 17/10. Parsing that string as a number yields nothing at all, so with
/// the type taken from the catalogue it would not sort either.
///
/// Hence this one place: comparisons use the same elapsed time the cell displays. <paramref
/// name="now"/> is passed in rather than read from the clock so the behaviour can be measured
/// without a flickering test.
/// </summary>
public static class RunningDuration
{
    /// <summary>Elapsed seconds of a running duration at <paramref name="now"/>; never negative.</summary>
    public static int ElapsedSeconds(int baseSecs, DateTime startedAt, DateTime now)
    {
        var elapsed = (int)(now - startedAt).TotalSeconds;
        var total = baseSecs + elapsed;
        return total < 0 ? 0 : total;
    }

    /// <summary>
    /// The displayed and compared form: "mm:ss", or "h:mm:ss" past an hour. One formatter, because
    /// the compared text is parsed back into seconds downstream — two spellings would disagree.
    /// </summary>
    public static string Format(int totalSecs)
    {
        if (totalSecs < 0) totalSecs = 0;
        var h = totalSecs / 3600;
        var m = (totalSecs % 3600) / 60;
        var s = totalSecs % 60;
        return h > 0 ? $"{h}:{m:D2}:{s:D2}" : $"{m:D2}:{s:D2}";
    }

    /// <summary>Value a running-duration cell shows, and the value its column is compared by.</summary>
    public static string Comparable(int baseSecs, DateTime startedAt, DateTime now)
        => Format(ElapsedSeconds(baseSecs, startedAt, now));
}
