using MediatR;

namespace CcDashboard.Application.HistoricalReports.Queries;

/// <summary>A4 Agent Monthly Report: agent metrics aggregated by month.</summary>
public record GetAgentMonthlyReportQuery(
    DateTime From,
    DateTime To,
    IReadOnlyList<string>? AgentExternalIds = null,
    int PageSize = 100,
    int Page = 1
) : IRequest<AgentMonthlyReportResult>;

public record AgentMonthlyReportResult(
    IReadOnlyList<AgentMonthlyRow> Rows,
    int TotalCount,
    int Page,
    int PageSize);

public record AgentMonthlyRow(
    string YearMonth,
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
    double? HoldPct);
