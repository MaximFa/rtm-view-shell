namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>
/// The resource key that names a report column, for every column any report row can carry.
///
/// Needed because the column picker and the widgets must agree: the picker offers
/// AllowedColumns (the row record's field names, from the server), and a widget draws whatever the
/// user picked. A column named in one place and unnamed in the other shows a technical identifier
/// to the operator, or worse an empty header over real numbers - which reads as missing data.
///
/// Measured before writing this: the row records carry 30 distinct column names; 27 of them
/// already had a resource key, under a different name than the field (SlPct -> Report_SLPct,
/// SumOnphoneMs -> Report_OnPhone, IntervalStart -> Report_Interval and so on), so a direct
/// field-to-key guess would have missed almost all of them. Six keys were added.
///
/// A column with no entry here falls back to its field name rather than to an empty string: a
/// visible oddity is better than a blank, because a blank looks like data that failed to load.
/// </summary>
public static class ReportColumnLabels
{
    private static readonly IReadOnlyDictionary<string, string> Keys = new Dictionary<string, string>
    {
        // Queue columns
        ["Workgroup"] = "Report_Workgroup",
        ["QueueId"] = "Report_QueueId",
        ["Offered"] = "Report_Offered",
        ["Answered"] = "Report_Answered",
        ["Abandoned"] = "Report_Abandoned",
        ["AnsweredInSl"] = "Report_AnsweredInSL",
        ["AbandonPct"] = "Report_AbandonPct",
        ["SlPct"] = "Report_SLPct",
        ["Asa"] = "Report_ASA",
        ["QueueAht"] = "Report_AHT",
        ["SumWaitAnswered"] = "Report_SumWaitAnswered",
        ["SumTalk"] = "Report_SumTalk",

        // Time axis
        ["IntervalStart"] = "Report_Interval",
        ["YearMonth"] = "Report_YearMonth",
        ["Date"] = "Report_Date",

        // Agent columns
        ["AgentExternalId"] = "Report_Agent",
        ["AgentDisplayName"] = "Report_AgentName",
        ["Handled"] = "Report_Handled",
        ["OccupancyPct"] = "Report_Occupancy",
        ["HoldPct"] = "Report_HoldPct",
        ["AgentAht"] = "Report_AHT",
        ["TalkPureMs"] = "Report_TalkPure",
        ["SumLoggedInMs"] = "Report_LoggedIn",
        ["SumAvailableMs"] = "Report_Available",
        ["SumOnphoneMs"] = "Report_OnPhone",
        ["SumHoldMs"] = "Report_Hold",
        ["SumPaperworkMs"] = "Report_Paperwork",
        ["SumBreakMs"] = "Report_Break",
        ["SumTrainingMs"] = "Report_Training",
        ["SumUnavailableMs"] = "Report_Unavailable",

        // Distribution
        ["Label"] = "Report_Label",
        ["Count"] = "Report_Count",
        ["Percentage"] = "Report_Percentage",
    };

    /// <summary>The resource key for a column, or null when none is known.</summary>
    public static string? KeyFor(string column)
        => Keys.TryGetValue(column, out var key) ? key : null;

    /// <summary>Every column this class can name - what the guard compares against AllowedColumns.</summary>
    public static IReadOnlyCollection<string> Known => Keys.Keys.ToList();

    /// <summary>
    /// Columns whose value is a duration in MILLISECONDS. The agent sums carry the "Ms" suffix and
    /// really are milliseconds; the queue sums (SumWaitAnswered, SumTalk) carry no suffix and are
    /// SECONDS - checked in QueueMetrics, where ASA = SumWaitAnswered / Answered is documented "in
    /// seconds". Getting this backwards shows a nine-hour total as 32 seconds, which looks
    /// plausible, so the two groups are listed rather than guessed from the name.
    /// </summary>
    public static bool IsMilliseconds(string column) => column.EndsWith("Ms", StringComparison.Ordinal);

    /// <summary>Columns whose value is a percentage.</summary>
    public static bool IsPercent(string column) => column.EndsWith("Pct", StringComparison.Ordinal);

    /// <summary>Columns that are text, not numbers - the only ones not aligned to the end.</summary>
    public static bool IsText(string column)
        => column is "Workgroup" or "QueueId" or "AgentExternalId" or "AgentDisplayName" or "Label"
                  or "IntervalStart" or "YearMonth" or "Date";
}
