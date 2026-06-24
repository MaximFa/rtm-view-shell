using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Handlers;

/// <summary>
/// SF-BI-001: All handlers use ReportScopeResolver to enforce PG-based filtering.
/// Non-superadmin users can ONLY see data they have PG access to.
/// </summary>
public class GetQueueIntervalReportQueryHandler(
    IHistoricalReportRepository repo,
    IReportScopeResolver scopeResolver,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetQueueIntervalReportQuery, QueueIntervalReportResult>
{
    public async Task<QueueIntervalReportResult> Handle(
        GetQueueIntervalReportQuery query, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;
        var scope = await scopeResolver.ResolveQueueScopeAsync(ct);
        var effectiveWorkgroups = scope.IntersectWorkgroups(query.Workgroups);

        if (!scope.FullScope && effectiveWorkgroups.Count == 0)
            return new QueueIntervalReportResult([], 0, query.Page, query.PageSize);

        var intervals = await repo.GetQueueIntervalsAsync(
            tenantId, query.From, query.To, scope, effectiveWorkgroups, ct);

        var rows = intervals.Select(i => new QueueIntervalRow(
            i.IntervalStart,
            i.Workgroup,
            i.QueueId,
            i.Offered,
            i.Answered,
            i.Abandoned,
            i.AnsweredInSl,
            i.SumWaitAnswered,
            i.SumTalk,
            i.Offered == 0 ? null : i.Abandoned * 100.0 / i.Offered,
            i.Answered == 0 ? null : i.AnsweredInSl * 100.0 / i.Answered,
            i.Answered == 0 ? null : (double)i.SumWaitAnswered / i.Answered,
            i.Answered == 0 ? null : (double)i.SumTalk / i.Answered
        )).ToList();

        var totalCount = rows.Count;
        var pagedRows = rows
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToList();

        return new QueueIntervalReportResult(pagedRows, totalCount, query.Page, query.PageSize);
    }
}

public class GetQueueWaitTimeReportQueryHandler(
    IHistoricalReportRepository repo,
    IReportScopeResolver scopeResolver,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetQueueWaitTimeReportQuery, QueueWaitTimeReportResult>
{
    public async Task<QueueWaitTimeReportResult> Handle(
        GetQueueWaitTimeReportQuery query, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;
        var scope = await scopeResolver.ResolveQueueScopeAsync(ct);
        var effectiveWorkgroups = scope.IntersectWorkgroups(query.Workgroups);

        if (!scope.FullScope && effectiveWorkgroups.Count == 0)
            return new QueueWaitTimeReportResult([], 0, query.Page, query.PageSize, null);

        var intervals = await repo.GetQueueIntervalsAsync(
            tenantId, query.From, query.To, scope, effectiveWorkgroups, ct);

        var rows = intervals.Select(i => new QueueWaitTimeRow(
            i.IntervalStart,
            i.Workgroup,
            i.Answered,
            i.SumWaitAnswered,
            i.Answered == 0 ? null : (double)i.SumWaitAnswered / i.Answered,
            i.AnsweredInSl,
            i.Answered == 0 ? null : i.AnsweredInSl * 100.0 / i.Answered
        )).ToList();

        var totalAnswered = intervals.Sum(x => x.Answered);
        var totalWait = intervals.Sum(x => x.SumWaitAnswered);
        var overallAsa = totalAnswered == 0 ? null : (double?)totalWait / totalAnswered;

        var totalCount = rows.Count;
        var pagedRows = rows
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToList();

        return new QueueWaitTimeReportResult(pagedRows, totalCount, query.Page, query.PageSize, overallAsa);
    }
}

public class GetAgentMonthlyReportQueryHandler(
    IHistoricalReportRepository repo,
    IReportScopeResolver scopeResolver,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetAgentMonthlyReportQuery, AgentMonthlyReportResult>
{
    public async Task<AgentMonthlyReportResult> Handle(
        GetAgentMonthlyReportQuery query, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;
        var scope = await scopeResolver.ResolveAgentScopeAsync(ct);
        var effectiveAgents = scope.IntersectAgents(query.AgentExternalIds);

        if (!scope.FullScope && effectiveAgents.Count == 0)
            return new AgentMonthlyReportResult([], 0, query.Page, query.PageSize);

        var intervals = await repo.GetAgentIntervalsAsync(
            tenantId, query.From, query.To, scope, effectiveAgents, ct);

        var rows = intervals
            .GroupBy(x => new { YearMonth = x.IntervalStart.ToString("yyyy-MM"), x.AgentExternalId })
            .Select(g =>
            {
                var sumAvailable = g.Sum(x => x.SumAvailableMs);
                var sumOnphone = g.Sum(x => x.SumOnphoneMs);
                var sumHold = g.Sum(x => x.SumHoldMs);
                var sumPaperwork = g.Sum(x => x.SumPaperworkMs);
                var sumBreak = g.Sum(x => x.SumBreakMs);
                var sumTraining = g.Sum(x => x.SumTrainingMs);
                var sumLoggedIn = g.Sum(x => x.SumLoggedInMs);
                var handled = g.Sum(x => x.Handled);
                var displayName = g.First().AgentDisplayName;

                var occupancyDenom = sumAvailable + sumOnphone + sumPaperwork;
                double? occupancyPct = occupancyDenom == 0 ? null : (sumOnphone + sumPaperwork) * 100.0 / occupancyDenom;
                double? agentAht = handled == 0 ? null : (sumOnphone + sumPaperwork) / 1000.0 / handled;
                double? holdPct = sumOnphone == 0 ? null : sumHold * 100.0 / sumOnphone;

                return new AgentMonthlyRow(
                    g.Key.YearMonth,
                    g.Key.AgentExternalId,
                    displayName,
                    sumAvailable,
                    sumOnphone,
                    sumHold,
                    sumPaperwork,
                    sumBreak,
                    sumTraining,
                    sumLoggedIn,
                    handled,
                    occupancyPct,
                    agentAht,
                    holdPct);
            })
            .OrderBy(x => x.YearMonth)
            .ThenBy(x => x.AgentExternalId)
            .ToList();

        var totalCount = rows.Count;
        var pagedRows = rows
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToList();

        return new AgentMonthlyReportResult(pagedRows, totalCount, query.Page, query.PageSize);
    }
}

public class GetAgentShiftDetailReportQueryHandler(
    IHistoricalReportRepository repo,
    IReportScopeResolver scopeResolver,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetAgentShiftDetailReportQuery, AgentShiftDetailReportResult>
{
    public async Task<AgentShiftDetailReportResult> Handle(
        GetAgentShiftDetailReportQuery query, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId!.Value;
        var scope = await scopeResolver.ResolveAgentScopeAsync(ct);
        var effectiveAgents = scope.IntersectAgents(query.AgentExternalIds);

        if (!scope.FullScope && effectiveAgents.Count == 0)
            return new AgentShiftDetailReportResult([], 0, query.Page, query.PageSize);

        var intervals = await repo.GetAgentIntervalsAsync(
            tenantId, query.From, query.To, scope, effectiveAgents, ct);

        var rows = intervals.Select(i =>
        {
            var occupancyDenom = i.SumAvailableMs + i.SumOnphoneMs + i.SumPaperworkMs;
            return new AgentShiftDetailRow(
                i.IntervalStart,
                i.AgentExternalId,
                i.AgentDisplayName,
                i.SumAvailableMs,
                i.SumOnphoneMs,
                i.SumHoldMs,
                i.SumPaperworkMs,
                i.SumBreakMs,
                i.SumTrainingMs,
                i.SumLoggedInMs,
                i.Handled,
                occupancyDenom == 0 ? null : (i.SumOnphoneMs + i.SumPaperworkMs) * 100.0 / occupancyDenom,
                i.Handled == 0 ? null : (i.SumOnphoneMs + i.SumPaperworkMs) / 1000.0 / i.Handled,
                i.SumOnphoneMs == 0 ? null : i.SumHoldMs * 100.0 / i.SumOnphoneMs,
                i.SumOnphoneMs - i.SumHoldMs);
        }).ToList();

        var totalCount = rows.Count;
        var pagedRows = rows
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToList();

        return new AgentShiftDetailReportResult(pagedRows, totalCount, query.Page, query.PageSize);
    }
}
