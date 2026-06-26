using MediatR;

namespace CcDashboard.Application.HistoricalReports.Queries;

/// <summary>Q5 Queue Wait Time Report: wait time distribution and ASA metrics.</summary>
public record GetQueueWaitTimeReportQuery(
    DateTime From,
    DateTime To,
    IReadOnlyList<string>? Workgroups = null,
    int PageSize = 100,
    int Page = 1
) : IRequest<QueueWaitTimeReportResult>;

public record QueueWaitTimeReportResult(
    IReadOnlyList<QueueWaitTimeRow> Rows,
    int TotalCount,
    int Page,
    int PageSize,
    double? OverallAsa);

public record QueueWaitTimeRow(
    DateTime IntervalStart,
    string? Workgroup,  // BU-aggregated rows carry null
    int Answered,
    long SumWaitAnswered,
    double? Asa,
    int AnsweredInSl,
    double? SlPct);
