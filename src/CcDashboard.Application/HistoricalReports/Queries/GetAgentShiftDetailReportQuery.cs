using MediatR;

namespace CcDashboard.Application.HistoricalReports.Queries;

/// <summary>A5 Agent Shift Detail Report: agent metrics at interval granularity.</summary>
public record GetAgentShiftDetailReportQuery(
    DateTime From,
    DateTime To,
    IReadOnlyList<string>? AgentExternalIds = null,
    int PageSize = 100,
    int Page = 1
) : IRequest<AgentShiftDetailReportResult>;

public record AgentShiftDetailReportResult(
    IReadOnlyList<AgentShiftDetailRow> Rows,
    int TotalCount,
    int Page,
    int PageSize);

public record AgentShiftDetailRow(
    DateTime IntervalStart,
    string AgentExternalId,
    string? AgentDisplayName,
    long SumAvailableMs,
    long SumOnphoneMs,
    long SumHoldMs,
    long SumPaperworkMs,
    long SumBreakMs,
    long SumTrainingMs,
    long SumLoggedInMs,
    int Handled,
    double? OccupancyPct,
    double? AgentAht,
    double? HoldPct,
    long TalkPureMs);
