using System.Text.Json;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Application.HistoricalReports.Validators;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using FluentValidation;
using MediatR;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Application.Handlers;

/// <summary>
/// Single entry point for report widgets.
/// SF-BI-001: All scope resolution + validation happens HERE, server-side, NON-BYPASSABLE.
/// </summary>
public class RunReportWidgetQueryHandler(
    IHistoricalReportRepository repo,
    IReportWidgetScopeService scopeService,
    ICurrentUserAccessor currentUser,
    ILogger<RunReportWidgetQueryHandler> logger)
    : IRequestHandler<RunReportWidgetQuery, ReportWidgetResult>
{
    private static readonly HashSet<ReportWidgetType> AgentWidgetTypes = new()
    {
        ReportWidgetType.AgentMonthly,
        ReportWidgetType.AgentShiftDetail
    };

    public async Task<ReportWidgetResult> Handle(RunReportWidgetQuery query, CancellationToken ct)
    {
        // Superadmin-gated tenant resolution: non-Superadmin's TenantId param IGNORED (own tenant only)
        var tenantId = currentUser.Role == "Superadmin"
            ? (query.TenantId ?? currentUser.TenantId!.Value)
            : currentUser.TenantId!.Value;

        ReportWidgetConfig config;
        try
        {
            config = ReportWidgetConfig.Parse(query.ConfigJson);
        }
        catch (JsonException ex)
        {
            logger.LogWarning(ex, "RunReportWidgetQuery: invalid ConfigJson");
            return ReportWidgetResult.CreateError(query.WidgetType, "Invalid ConfigJson: " + ex.Message);
        }

        var validator = new ReportWidgetConfigWithTypeValidator();
        var validationResult = await validator.ValidateAsync((config, query.WidgetType), ct);
        if (!validationResult.IsValid)
        {
            var errors = string.Join("; ", validationResult.Errors.Select(e => e.ErrorMessage));
            logger.LogWarning("RunReportWidgetQuery: validation failed: {Errors}", errors);
            return ReportWidgetResult.CreateError(query.WidgetType, errors);
        }

        var from = DateTime.SpecifyKind(query.From.Date, DateTimeKind.Utc);
        var toExclusive = DateTime.SpecifyKind(query.To.Date.AddDays(1), DateTimeKind.Utc);

        // Compute effective columns: config.Columns if non-empty, else DefaultColumns per WidgetType
        var effectiveColumns = config.GetEffectiveColumns(query.WidgetType);

        return query.WidgetType switch
        {
            ReportWidgetType.QueueInterval => await RunQueueIntervalAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, ct),
            ReportWidgetType.QueueWaitTime => await RunQueueWaitTimeAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, ct),
            ReportWidgetType.AgentMonthly => await RunAgentMonthlyAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, ct),
            ReportWidgetType.AgentShiftDetail => await RunAgentShiftDetailAsync(tenantId, config, effectiveColumns, from, toExclusive, query.Page, ct),
            ReportWidgetType.Distribution => await RunDistributionAsync(tenantId, config, effectiveColumns, from, toExclusive, ct),
            _ => ReportWidgetResult.CreateError(query.WidgetType, $"Unknown widget type: {query.WidgetType}")
        };
    }

    private async Task<ReportWidgetResult> RunQueueIntervalAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns, DateTime from, DateTime toExclusive, int page, CancellationToken ct)
    {
        var scopeResult = await scopeService.ResolveQueueScopeAsync(tenantId, config, ct);

        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(ReportWidgetType.QueueInterval);

        var intervals = await repo.GetQueueIntervalsAsync(
            tenantId, from, toExclusive,
            scopeResult.FullScope ? ReportScope.Full() : new ReportScope { AllowedWorkgroups = scopeResult.EffectiveWorkgroups },
            scopeResult.EffectiveWorkgroups, ct);

        // BU-AGGREGATED: GROUP BY IntervalStart only, SUM components, recompute metrics from sums
        var rows = intervals
            .GroupBy(i => i.IntervalStart)
            .Select(g =>
            {
                var offered      = g.Sum(i => i.Offered);
                var answered     = g.Sum(i => i.Answered);
                var abandoned    = g.Sum(i => i.Abandoned);
                var answeredInSl = g.Sum(i => i.AnsweredInSl);
                var sumWait      = g.Sum(i => i.SumWaitAnswered);
                var sumTalk      = g.Sum(i => i.SumTalk);
                return new QueueIntervalRow(
                    g.Key,
                    null,                       // Workgroup: BU-aggregated, no single queue
                    null,                       // QueueId: aggregated
                    offered, answered, abandoned, answeredInSl, sumWait, sumTalk,
                    offered  == 0 ? null : abandoned * 100.0 / offered,        // AbandonPct from SUMS
                    answered == 0 ? null : answeredInSl * 100.0 / answered,    // SlPct
                    answered == 0 ? null : (double)sumWait / answered,         // Asa
                    answered == 0 ? null : (double)sumTalk / answered);        // QueueAht
            })
            .OrderBy(r => r.IntervalStart)
            .ToList();

        var pageSize = config.PageSize;
        var totalCount = rows.Count;
        var pagedRows = rows.Skip((page - 1) * pageSize).Take(pageSize).ToList();

        return new ReportWidgetResult
        {
            WidgetType = ReportWidgetType.QueueInterval,
            EffectiveColumns = effectiveColumns,
            QueueInterval = new QueueIntervalReportResult(pagedRows, totalCount, page, pageSize)
        };
    }

    private async Task<ReportWidgetResult> RunQueueWaitTimeAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns, DateTime from, DateTime toExclusive, int page, CancellationToken ct)
    {
        var scopeResult = await scopeService.ResolveQueueScopeAsync(tenantId, config, ct);

        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(ReportWidgetType.QueueWaitTime);

        var intervals = await repo.GetQueueIntervalsAsync(
            tenantId, from, toExclusive,
            scopeResult.FullScope ? ReportScope.Full() : new ReportScope { AllowedWorkgroups = scopeResult.EffectiveWorkgroups },
            scopeResult.EffectiveWorkgroups, ct);

        // BU-AGGREGATED: GROUP BY IntervalStart only, SUM components, recompute metrics from sums
        var rows = intervals
            .GroupBy(i => i.IntervalStart)
            .Select(g =>
            {
                var answered     = g.Sum(i => i.Answered);
                var sumWait      = g.Sum(i => i.SumWaitAnswered);
                var answeredInSl = g.Sum(i => i.AnsweredInSl);
                return new QueueWaitTimeRow(
                    g.Key, null, answered, sumWait,
                    answered == 0 ? null : (double)sumWait / answered,        // Asa
                    answeredInSl,
                    answered == 0 ? null : answeredInSl * 100.0 / answered);  // SlPct
            })
            .OrderBy(r => r.IntervalStart)
            .ToList();

        var totalAnswered = rows.Sum(r => r.Answered);
        var totalWait = rows.Sum(r => r.SumWaitAnswered);
        var overallAsa = totalAnswered == 0 ? null : (double?)totalWait / totalAnswered;

        var pageSize = config.PageSize;
        var totalCount = rows.Count;
        var pagedRows = rows.Skip((page - 1) * pageSize).Take(pageSize).ToList();

        return new ReportWidgetResult
        {
            WidgetType = ReportWidgetType.QueueWaitTime,
            EffectiveColumns = effectiveColumns,
            QueueWaitTime = new QueueWaitTimeReportResult(pagedRows, totalCount, page, pageSize, overallAsa)
        };
    }

    private async Task<ReportWidgetResult> RunAgentMonthlyAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns, DateTime from, DateTime toExclusive, int page, CancellationToken ct)
    {
        var axis = config.Scope.AgentAxis ?? AgentReportAxis.Detail;
        var scopeResult = await scopeService.ResolveAgentScopeAsync(tenantId, config, axis, ct);

        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(ReportWidgetType.AgentMonthly);

        var intervals = await repo.GetAgentIntervalsAsync(
            tenantId, from, toExclusive,
            scopeResult.FullScope ? ReportScope.Full() : new ReportScope { AllowedAgentExternalIds = scopeResult.EffectiveAgentIds },
            scopeResult.EffectiveAgentIds, ct);

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

        var pageSize = config.PageSize;
        var totalCount = rows.Count;
        var pagedRows = rows.Skip((page - 1) * pageSize).Take(pageSize).ToList();

        return new ReportWidgetResult
        {
            WidgetType = ReportWidgetType.AgentMonthly,
            EffectiveColumns = effectiveColumns,
            AgentMonthly = new AgentMonthlyReportResult(pagedRows, totalCount, page, pageSize)
        };
    }

    private async Task<ReportWidgetResult> RunAgentShiftDetailAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns, DateTime from, DateTime toExclusive, int page, CancellationToken ct)
    {
        var axis = config.Scope.AgentAxis ?? AgentReportAxis.Detail;
        var scopeResult = await scopeService.ResolveAgentScopeAsync(tenantId, config, axis, ct);

        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(ReportWidgetType.AgentShiftDetail);

        var intervals = await repo.GetAgentIntervalsAsync(
            tenantId, from, toExclusive,
            scopeResult.FullScope ? ReportScope.Full() : new ReportScope { AllowedAgentExternalIds = scopeResult.EffectiveAgentIds },
            scopeResult.EffectiveAgentIds, ct);

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

        var pageSize = config.PageSize;
        var totalCount = rows.Count;
        var pagedRows = rows.Skip((page - 1) * pageSize).Take(pageSize).ToList();

        return new ReportWidgetResult
        {
            WidgetType = ReportWidgetType.AgentShiftDetail,
            EffectiveColumns = effectiveColumns,
            AgentShiftDetail = new AgentShiftDetailReportResult(pagedRows, totalCount, page, pageSize)
        };
    }

    private async Task<ReportWidgetResult> RunDistributionAsync(
        Guid tenantId, ReportWidgetConfig config, IReadOnlyList<string> effectiveColumns, DateTime from, DateTime toExclusive, CancellationToken ct)
    {
        var scopeResult = await scopeService.ResolveQueueScopeAsync(tenantId, config, ct);

        if (scopeResult.Denied)
            return ReportWidgetResult.CreateDenied(ReportWidgetType.Distribution);

        var intervals = await repo.GetQueueIntervalsAsync(
            tenantId, from, toExclusive,
            scopeResult.FullScope ? ReportScope.Full() : new ReportScope { AllowedWorkgroups = scopeResult.EffectiveWorkgroups },
            scopeResult.EffectiveWorkgroups, ct);

        var totalAnswered = intervals.Sum(x => x.Answered);
        var totalWait = intervals.Sum(x => x.SumWaitAnswered);
        var overallAsa = totalAnswered == 0 ? null : (double?)totalWait / totalAnswered;

        var buckets = BuildDistributionBuckets(intervals, config.Metric);

        return new ReportWidgetResult
        {
            WidgetType = ReportWidgetType.Distribution,
            EffectiveColumns = effectiveColumns,
            Distribution = new DistributionReportResult(buckets, totalAnswered, overallAsa)
        };
    }

    private static List<DistributionBucket> BuildDistributionBuckets(
        IReadOnlyList<Domain.Domain.Historical.HistQueueInterval> intervals, string? metric)
    {
        var answeredInSl = intervals.Sum(x => x.AnsweredInSl);
        var answered = intervals.Sum(x => x.Answered);
        var abandoned = intervals.Sum(x => x.Abandoned);
        var total = answered + abandoned;

        if (total == 0)
            return new List<DistributionBucket>();

        return new List<DistributionBucket>
        {
            new("Answered in SL", 0, null, answeredInSl, total == 0 ? 0 : answeredInSl * 100.0 / total),
            new("Answered out of SL", 0, null, answered - answeredInSl, total == 0 ? 0 : (answered - answeredInSl) * 100.0 / total),
            new("Abandoned", 0, null, abandoned, total == 0 ? 0 : abandoned * 100.0 / total)
        };
    }
}
