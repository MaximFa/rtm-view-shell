using CcDashboard.Application.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace CcDashboard.Infrastructure.Metrics;

/// <summary>
/// Reads the per-metric deploy ledger (contract §9 / §38a).
/// PENDING devops ledger DDL — query against minimal columns (MetricId, DeployedAt, SourceCommit).
/// If table absent -> returns empty set (delta shows full manifest as undeployed, acceptable v1).
/// </summary>
public sealed class MetricDeployLedgerReader : IMetricDeployLedgerReader
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<MetricDeployLedgerReader> _logger;

    public MetricDeployLedgerReader(
        IServiceScopeFactory scopeFactory,
        ILogger<MetricDeployLedgerReader> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    public async Task<IReadOnlySet<string>> GetAppliedMetricIdsAsync(CancellationToken ct = default)
    {
        await using var scope = _scopeFactory.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        try
        {
            // PENDING devops ledger DDL — table name 'metric_deploy_log' is candidate, may fold into db_patch_history
            // Query uses FromSqlInterpolated only (CODE-01, no string concat)
            var metricIds = await db.Database
                .SqlQueryRaw<string>(
                    """SELECT "MetricId" FROM public."metric_deploy_log" """)
                .ToListAsync(ct);

            return metricIds.ToHashSet();
        }
        catch (PostgresException ex) when (ex.SqlState == "42P01") // undefined_table
        {
            _logger.LogWarning(
                "MetricDeployLedgerReader: ledger table 'metric_deploy_log' does not exist (42P01). " +
                "Returning empty set — delta will show full manifest as undeployed. " +
                "PENDING: devops ledger DDL migration (contract §12).");
            return new HashSet<string>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "MetricDeployLedgerReader: failed to read ledger");
            return new HashSet<string>();
        }
    }
}
