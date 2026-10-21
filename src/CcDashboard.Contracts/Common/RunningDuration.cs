using System.Globalization;

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

    /// <summary>Seconds a moment may run ahead of the clock before it is treated as wrong.</summary>
    public const int FutureToleranceSeconds = 5;

    /// <summary>
    /// The engine's "+dd/MM/yyyy HH:mm:ss" payload is the MOMENT a duration started, not its length
    /// (RTM/UserManager.cs:1329,1351,1361,1400,1404,1420,1430,1443,1460,1634,1650 and
    /// RTM/Union.cs:1095,1124 - fifteen such places, every one built from DateTime.Now). Splitting it
    /// on ':' makes "18/10/2026 17" the hours part, which parses as nothing, so the old reader
    /// returned 0 and every running timer restarted from zero whenever the page was reloaded.
    ///
    /// ASSUMPTION - ONE HOST: the moment carries no zone, it is the engine machine's local wall
    /// clock. Measured 2026-10-20 (acceptance report 234_20261020_073118): RTMService (pid 10380) and
    /// RTMViewShell (pid 8432) run on the same machine "RTM", so Shell's local clock is that same
    /// scale and SpecifyKind(Local).ToUniversalTime() is exact. If Shell ever moves to another host
    /// or another zone, this is the line that breaks, and the error is whole hours.
    /// </summary>
    /// <returns>true and the moment as UTC; false when the text is not such a moment.</returns>
    public static bool TryParseEngineInstant(string? text, out DateTime utc)
    {
        utc = default;
        if (string.IsNullOrWhiteSpace(text)) return false;
        var body = text![0] == '+' ? text[1..] : text;
        if (!DateTime.TryParseExact(body, "dd/MM/yyyy HH:mm:ss",
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var local))
            return false;
        utc = DateTime.SpecifyKind(local, DateTimeKind.Local).ToUniversalTime();
        return true;
    }

    /// <summary>A moment later than now is not a start: clocks disagree or the payload is wrong.</summary>
    public static bool IsFutureInstant(DateTime utc, DateTime now)
        => utc > now.AddSeconds(FutureToleranceSeconds);
}
