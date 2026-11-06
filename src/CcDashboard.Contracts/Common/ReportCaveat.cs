namespace CcDashboard.Contracts.Common;

/// <summary>
/// The known limit of a report's numbers, as a resource key the screen can show.
///
/// PR234-V4-EOS-CAVEAT-NOT-LOCALIZED-01: the server used to send the sentence itself, in English,
/// and the widget printed it - so a Hebrew board carried an English paragraph explaining how
/// status time is bucketed. The server now sends a CODE and the screen owns the sentence, exactly
/// as it owns the skip reasons of the export.
///
/// An unknown code shows NOTHING and is logged. That is the opposite of the export rule on
/// purpose, and the difference is what the two lines mean: a skipped widget is a fact about the
/// user's own data that must never be hidden, while a caveat is an explanatory sentence - showing
/// a raw code like "status-start-bucket" where a sentence belongs tells the reader nothing and
/// looks like a fault in the report. The log is what carries the unknown code to us.
/// </summary>
public static class ReportCaveat
{
    /// <summary>Status time sits in the half-hour in which the status started (hist_agent_intervals).</summary>
    public const string StatusStartBucket = "status-start-bucket";

    /// <summary>The resource key for a caveat code, or null when there is nothing to say.</summary>
    public static string? KeyFor(string? caveatCode) => caveatCode?.Trim().ToLowerInvariant() switch
    {
        StatusStartBucket => "Report_CaveatStatusStartBucket",
        _ => null
    };

    /// <summary>
    /// True when a code arrived that this screen cannot put into words. The caller logs it and
    /// draws no caveat line. Asked as its own question so "nothing to say" and "something arrived
    /// that we do not understand" cannot be confused in the calling code.
    /// </summary>
    public static bool IsUnknown(string? caveatCode)
        => !string.IsNullOrWhiteSpace(caveatCode) && KeyFor(caveatCode) is null;
}
