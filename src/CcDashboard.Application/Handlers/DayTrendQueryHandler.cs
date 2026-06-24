using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Queries.Widgets;
using CcDashboard.Domain.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Npgsql;
using NpgsqlTypes;

namespace CcDashboard.Application.Handlers;

public sealed class DayTrendQueryHandler(
    IBackendEmulationDbContextFactory beDbFactory,
    ITenantContext tenantContext,
    ILogger<DayTrendQueryHandler> logger)
    : IRequestHandler<DayTrendQuery, DayTrendResult>
{
    public async Task<DayTrendResult> Handle(DayTrendQuery query, CancellationToken ct)
    {
        if (!tenantContext.IsResolved)
            return DayTrendResult.Empty();

        var tenantId = tenantContext.TenantId;

        // Create isolated DbContext to avoid "command already in progress" when widgets init concurrently
        await using var beDb = await beDbFactory.CreateDbContextAsync(ct);

        // Resolve queues for the BU via NgcBusinessUnitQueueClassification
        var queues = await beDb.NgcBusinessUnitQueueClassifications
            .Where(q => q.BusinessUnitId == query.BusinessUnitId && q.TenantId == tenantId)
            .Select(q => q.QueueId)
            .ToListAsync(ct);

        if (queues.Count == 0)
        {
            logger.LogWarning("DayTrend: No queues found for BU {BuId}, tenant {TenantId}", query.BusinessUnitId, tenantId);
            return DayTrendResult.NoQueues();
        }

        var onDate = (query.OnDate ?? DateOnly.FromDateTime(DateTime.UtcNow))
            .ToString("dd/MM/yyyy");
        var queueArray = queues.ToArray();
        var interval = query.IntervalMinutes;

        logger.LogInformation("DayTrend: BU={BuId}, Date={Date}, Queues=[{Queues}], Interval={Interval}",
            query.BusinessUnitId, onDate, string.Join(",", queueArray), interval);

        // Build parameters for PostgreSQL function call
        var pTenant = new NpgsqlParameter("p_tenant", NpgsqlDbType.Uuid) { Value = tenantId };
        var pDate = new NpgsqlParameter("p_date", NpgsqlDbType.Varchar) { Value = onDate };
        var pQueues = new NpgsqlParameter("p_queues", NpgsqlDbType.Array | NpgsqlDbType.Text) { Value = queueArray };
        var pInterval = new NpgsqlParameter("p_interval", NpgsqlDbType.Integer) { Value = interval };

        // Run interaction metrics query
        var interactionRows = await beDb.Database
            .SqlQueryRaw<DayTrendMetricRow>(
                "SELECT * FROM fn_daytrendinteractions(@p_tenant, @p_date, @p_queues, @p_interval)",
                pTenant, pDate, pQueues, pInterval)
            .ToListAsync(ct);

        logger.LogInformation("DayTrend: Got {Count} interaction rows", interactionRows.Count);

        // Run agent status metrics query (only if needed)
        // Agent scope is via BU membership (NGC_UserAgentgroup, P1/P2), not via queues
        List<DayTrendMetricRow> agentRows;
        if (query.IncludeAgentMetrics)
        {
            var pTenant2 = new NpgsqlParameter("p_tenant", NpgsqlDbType.Uuid) { Value = tenantId };
            var pDate2 = new NpgsqlParameter("p_date", NpgsqlDbType.Varchar) { Value = onDate };
            var pBusinessUnitId = new NpgsqlParameter("p_businessunitid", NpgsqlDbType.Integer) { Value = query.BusinessUnitId };
            var pInterval2 = new NpgsqlParameter("p_interval", NpgsqlDbType.Integer) { Value = interval };

            agentRows = await beDb.Database
                .SqlQueryRaw<DayTrendMetricRow>(
                    "SELECT * FROM fn_daytrendagentstatus(@p_tenant, @p_date, @p_businessunitid, @p_interval)",
                    pTenant2, pDate2, pBusinessUnitId, pInterval2)
                .ToListAsync(ct);
        }
        else
        {
            agentRows = new List<DayTrendMetricRow>();
        }

        // Merge and pivot to per-interval dictionaries
        var intervals = interactionRows
            .Concat(agentRows)
            .GroupBy(r => r.interval_start)
            .Select(g => new DayTrendIntervalData(
                g.Key,
                g.ToDictionary(r => r.metric_id, r => r.value)))
            .OrderBy(x => x.IntervalStart)
            .ToList();

        return new DayTrendResult(intervals);
    }
}
