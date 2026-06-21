using MediatR;

namespace CcDashboard.Application.HistoricalReports.Queries;

/// <summary>Q1 Queue Interval Report: aggregated queue metrics per 30-minute interval.</summary>
public record GetQueueIntervalReportQuery(
    DateTime From,
    DateTime To,
    IReadOnlyList<string>? Workgroups = null,
    int PageSize = 100,
    int Page = 1
) : IRequest<QueueIntervalReportResult>;

public record QueueIntervalReportResult(
    IReadOnlyList<QueueIntervalRow> Rows,
    int TotalCount,
    int Page,
    int PageSize);

public record QueueIntervalRow(
    DateTime IntervalStart,
    string Workgroup,
    Guid? QueueId,
    int Offered,
    int Answered,
    int Abandoned,
    int AnsweredInSl,
    long SumWaitAnswered,
    long SumTalk,
    double? AbandonPct,
    double? SlPct,
    double? Asa,
    double? QueueAht);
