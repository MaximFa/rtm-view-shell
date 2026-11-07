using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Domain.Domain.Reports;

namespace CcDashboard.Application.HistoricalReports;

/// <summary>
/// FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01: what a report column holds. One rule for the server (which filter operators a
/// column takes) and for the screen (how a cell is formatted and whether it gets a funnel).
/// Values are always in the column's own unit: DurationMs in milliseconds, DurationSec in seconds, Percent 0-100.
/// </summary>
public enum ReportColumnKind
{
    Text,
    Count,
    DurationMs,
    DurationSec,
    Percent,
    DateTime,
    Date,
    Id
}

/// <summary>One column of a report row. Filterable = the screen shows a funnel and the server accepts a filter on it.</summary>
public record ReportColumn(string Name, ReportColumnKind Kind, bool Filterable);

public static class ReportColumns
{
    // Every field of every row record must be here: an unknown field is a defect, never a silent default.
    // Units measured in code: SumWaitAnswered / SumTalk are sums of RTSData_Interaction.TimeInQueue / TalkTime (seconds,
    // RtsDataEntities.cs); Asa / QueueAht = those sums / Answered (seconds); Sum*Ms and TalkPureMs are milliseconds;
    // AgentAht = ms / 1000 / Handled (seconds).
    private static readonly IReadOnlyDictionary<string, ReportColumnKind> Kinds = new Dictionary<string, ReportColumnKind>
    {
        ["IntervalStart"] = ReportColumnKind.DateTime,
        ["Date"] = ReportColumnKind.Date,
        ["YearMonth"] = ReportColumnKind.Text,
        ["Workgroup"] = ReportColumnKind.Text,
        ["QueueId"] = ReportColumnKind.Id,
        ["AgentExternalId"] = ReportColumnKind.Text,
        ["AgentDisplayName"] = ReportColumnKind.Text,
        ["Offered"] = ReportColumnKind.Count,
        ["Answered"] = ReportColumnKind.Count,
        ["Abandoned"] = ReportColumnKind.Count,
        ["AnsweredInSl"] = ReportColumnKind.Count,
        ["Handled"] = ReportColumnKind.Count,
        ["SumWaitAnswered"] = ReportColumnKind.DurationSec,
        ["SumTalk"] = ReportColumnKind.DurationSec,
        ["Asa"] = ReportColumnKind.DurationSec,
        ["QueueAht"] = ReportColumnKind.DurationSec,
        ["AgentAht"] = ReportColumnKind.DurationSec,
        ["AbandonPct"] = ReportColumnKind.Percent,
        ["SlPct"] = ReportColumnKind.Percent,
        ["OccupancyPct"] = ReportColumnKind.Percent,
        ["HoldPct"] = ReportColumnKind.Percent,
        ["SumAvailableMs"] = ReportColumnKind.DurationMs,
        ["SumOnphoneMs"] = ReportColumnKind.DurationMs,
        ["SumHoldMs"] = ReportColumnKind.DurationMs,
        ["SumPaperworkMs"] = ReportColumnKind.DurationMs,
        ["SumBreakMs"] = ReportColumnKind.DurationMs,
        ["SumTrainingMs"] = ReportColumnKind.DurationMs,
        ["SumUnavailableMs"] = ReportColumnKind.DurationMs,
        ["SumLoggedInMs"] = ReportColumnKind.DurationMs,
        ["TalkPureMs"] = ReportColumnKind.DurationMs,
    };

    /// <summary>The row record of a widget type; null for types without a table (Distribution).</summary>
    public static Type? RowTypeOf(ReportWidgetType type) => type switch
    {
        ReportWidgetType.QueueInterval => typeof(QueueIntervalRow),
        ReportWidgetType.QueueWaitTime => typeof(QueueWaitTimeRow),
        ReportWidgetType.AgentMonthly => typeof(AgentMonthlyRow),
        ReportWidgetType.AgentShiftDetail => typeof(AgentShiftDetailRow),
        ReportWidgetType.EndOfShiftAgents or ReportWidgetType.AgentPerformance => typeof(AgentSummaryRow),
        ReportWidgetType.EndOfShiftQueues => typeof(QueueSummaryRow),
        _ => null
    };

    /// <summary>The columns of a widget type, in the order of the row's fields; empty for Distribution.</summary>
    public static IReadOnlyList<ReportColumn> For(ReportWidgetType type)
    {
        var row = RowTypeOf(type);
        if (row is null) return Array.Empty<ReportColumn>();
        return KindsOf(row)
            .Select(c => c with { Filterable = c.Filterable && !NeverFilled(type, c.Name) })
            .ToList();
    }

    /// <summary>The kind of every public field of a row record; throws on a field without a kind.</summary>
    public static IReadOnlyList<ReportColumn> KindsOf(Type rowType) =>
        rowType.GetProperties().Select(p => Kinds.TryGetValue(p.Name, out var k)
                ? new ReportColumn(p.Name, k, k != ReportColumnKind.Id)
                : throw new InvalidOperationException($"Report column {rowType.Name}.{p.Name} has no kind in ReportColumns"))
            .ToList();

    /// <summary>The column of that name for the type, or null.</summary>
    public static ReportColumn? Find(ReportWidgetType type, string? name) =>
        name is null ? null : For(type).FirstOrDefault(c => c.Name == name);

    // QueueInterval / QueueWaitTime rows are summed over the BU per interval: Workgroup is always null there, so a funnel
    // on it could never find anything (measured in code, RunReportWidgetQueryHandler: "Workgroup: BU-aggregated").
    private static bool NeverFilled(ReportWidgetType type, string column) =>
        column == "Workgroup" && type is ReportWidgetType.QueueInterval or ReportWidgetType.QueueWaitTime;
}
