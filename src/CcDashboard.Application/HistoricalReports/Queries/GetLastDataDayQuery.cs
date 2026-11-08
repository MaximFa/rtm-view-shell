using System.Text.Json;
using CcDashboard.Application.HistoricalReports.Validators;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Application.HistoricalReports.Queries;

/// <summary>
/// FEAT-REPORT-DEFAULT-LAST-DATA-DAY-01: the last LOCAL day (site display zone) that has data for this widget, within the
/// user's scope and the widget's own scope - the default date of a report screen. If today has data, it is today.
/// The scope is resolved exactly as the widget run resolves it (IReportWidgetScopeService), so the day can never come from
/// rows the widget itself would not show.
/// </summary>
public record GetLastDataDayQuery(ReportWidgetType WidgetType, string ConfigJson, Guid? TenantId = null) : IRequest<LastDataDayResult>;

/// <summary>
/// Day = null with ErrorCode = null: nothing in scope has data (the screen keeps its own default, today).
/// ErrorCode (ReportReasonCodes): denied, retired, invalid-config (bad config, or a report type the rule does not cover yet).
/// </summary>
public record LastDataDayResult(DateOnly? Day, string? ErrorCode = null);

public class GetLastDataDayQueryHandler(
    IHistoricalReportRepository repo,
    IReportWidgetScopeService scopeService,
    ICurrentUserAccessor currentUser,
    ILogger<GetLastDataDayQueryHandler> logger,
    IDisplayTimeZone? displayZone = null)
    : IRequestHandler<GetLastDataDayQuery, LastDataDayResult>
{
    /// <summary>
    /// The report types the rule covers and the history each reads. The one place to add a type (agents: a ReportDataSet
    /// value + its scope branch below), never a second rule.
    /// </summary>
    internal static readonly IReadOnlyDictionary<ReportWidgetType, ReportDataSet> Sources =
        new Dictionary<ReportWidgetType, ReportDataSet>
        {
            [ReportWidgetType.EndOfShiftQueues] = ReportDataSet.Queues,
            [ReportWidgetType.EndOfShiftAgents] = ReportDataSet.Agents,
            [ReportWidgetType.QueueTrend] = ReportDataSet.Queues,
            [ReportWidgetType.AgentStateTrend] = ReportDataSet.Agents
        };

    private TimeZoneInfo Zone => displayZone?.Zone ?? TimeZoneInfo.Utc;

    public async Task<LastDataDayResult> Handle(GetLastDataDayQuery query, CancellationToken ct)
    {
        // same tenant rule as RunReportWidgetQuery: a non-Superadmin's TenantId is ignored
        var tenantId = currentUser.Role == "Superadmin"
            ? (query.TenantId ?? currentUser.TenantId!.Value)
            : currentUser.TenantId!.Value;

        if (RetiredReports.IsRetired(query.WidgetType))
            return new LastDataDayResult(null, ReportReasonCodes.Retired);
        if (!Sources.TryGetValue(query.WidgetType, out var dataSet))
            return new LastDataDayResult(null, ReportReasonCodes.InvalidConfig);

        ReportWidgetConfig config;
        try
        {
            config = ReportWidgetConfig.Parse(query.ConfigJson);
        }
        catch (JsonException ex)
        {
            logger.LogWarning(ex, "GetLastDataDayQuery: invalid ConfigJson");
            return new LastDataDayResult(null, ReportReasonCodes.InvalidConfig);
        }
        var validation = await new ReportWidgetConfigWithTypeValidator().ValidateAsync((config, query.WidgetType), ct);
        if (!validation.IsValid)
            return new LastDataDayResult(null, ReportReasonCodes.InvalidConfig);

        IReadOnlySet<string> keys;
        switch (dataSet)
        {
            case ReportDataSet.Queues:
            {
                var scope = await scopeService.ResolveQueueScopeAsync(tenantId, config, ct);
                if (scope.Denied)
                    return new LastDataDayResult(null, ReportReasonCodes.Denied);
                // narrowed by the trend chart's picked queues (none on the queues report) - the run's own rule
                keys = CcDashboard.Application.Handlers.RunReportWidgetQueryHandler.NarrowToPicked(scope.EffectiveWorkgroups, config.Workgroups).Effective;
                break;
            }
            case ReportDataSet.Agents:
            {
                // the agents the widget itself would show: its scope narrowed by its picked agents (the run's own rule)
                var scope = await scopeService.ResolveAgentScopeAsync(tenantId, config, AgentReportAxis.Detail, ct);
                if (scope.Denied)
                    return new LastDataDayResult(null, ReportReasonCodes.Denied);
                keys = CcDashboard.Application.Handlers.RunReportWidgetQueryHandler.NarrowToPickedAgents(scope.EffectiveAgentIds, config.AgentIds).Effective;
                break;
            }
            default:
                return new LastDataDayResult(null, ReportReasonCodes.InvalidConfig);
        }

        // nothing in scope - nothing asked (the repository says the same; the guard is kept here too, at the rule)
        if (keys.Count == 0)
            return new LastDataDayResult(null);

        var lastUtc = await repo.GetLastIntervalStartAsync(tenantId, dataSet, keys, ct);
        return lastUtc is null
            ? new LastDataDayResult(null)
            : new LastDataDayResult(DateOnly.FromDateTime(Zone.ToDisplay(lastUtc.Value)));
    }
}
