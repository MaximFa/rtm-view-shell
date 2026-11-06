namespace CcDashboard.Contracts.Common;

/// <summary>
/// Which columns the agent summary table shows, once the report's mode has its say.
///
/// The rule (coordinator, 2026-11-04) is about the MODE, not about the server's standard set:
/// in "by date" every agent appears once per local date, so the date is shown ALWAYS - chosen or
/// not. Without it the same agent repeats with different numbers and nothing tells the rows apart,
/// which reads as broken data rather than as a report. And in "summary" there is one row per agent
/// for the whole period, where Date is null: a date column there would be a row of dashes
/// pretending to be data, so it is dropped even if it was picked.
///
/// This is a rule about what the operator sees, so it lives outside the widget, where a test can
/// reach it: a .razor component's own members are not visible to tests and there is no bUnit here.
/// My first version of it was weaker - it only added the date when the SERVER's standard set
/// lacked it - and that would have been defeated by a user who picked the columns themselves.
/// </summary>
public static class AgentSummaryColumns
{
    /// <summary>The column name that carries the per-date axis.</summary>
    public const string DateColumn = "Date";

    /// <summary>
    /// The columns to draw: the date first and exactly once in by-date mode, and never in summary
    /// mode. The order of the other columns is preserved - the table must look the same after a
    /// reopen, and the chosen order is the one the server returned.
    /// </summary>
    public static IReadOnlyList<string> ForMode(IReadOnlyList<string>? columns, bool byDate)
    {
        var rest = (columns ?? Array.Empty<string>())
            .Where(c => !string.Equals(c, DateColumn, StringComparison.Ordinal))
            .ToList();

        if (!byDate)
            return rest;

        var withDate = new List<string>(rest.Count + 1) { DateColumn };
        withDate.AddRange(rest);
        return withDate;
    }
}
