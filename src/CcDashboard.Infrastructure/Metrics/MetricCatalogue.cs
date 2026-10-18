using CcDashboard.Application.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Metrics;

/// <summary>
/// IMetricCatalogue over RTSGrid_Metric (PR234-V4-ALL-COLUMNS-TEXT-AFTER-EFFCD27-01).
///
/// Why: widgets of one screen load in parallel inside one Blazor circuit. Reading the catalogue through the
/// circuit-scoped BackendEmulationDbContext (GetRtsGridMetricsQuery -> RtsGridMetricRepository) made the
/// second concurrent call fail with NpgsqlOperationInProgressException "A command is already in progress".
///
/// How: registered as a SINGLETON; every database read uses its OWN short-lived context from
/// IDbContextFactory, so it never shares a connection with a caller. Concurrent callers are collapsed into
/// one read (single flight) and a successful result is reused for <see cref="CacheTtl"/>. The TTL is short on
/// purpose: metrics can be edited/deployed from the admin UI while screens run, so the cache must not keep a
/// stale catalogue until the next restart.
///
/// Failure: the read exception PROPAGATES to every waiting caller and nothing is cached, so the next call
/// tries again. An empty dictionary is returned only when the table really is empty.
/// </summary>
public sealed class MetricCatalogue(
    IDbContextFactory<BackendEmulationDbContext> dbFactory,
    ILogger<MetricCatalogue> logger,
    TimeProvider? clock = null) : IMetricCatalogue
{
    public static readonly TimeSpan CacheTtl = TimeSpan.FromSeconds(60);

    private readonly TimeProvider _clock = clock ?? TimeProvider.System;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private volatile Snapshot? _snapshot;

    private sealed record Snapshot(IReadOnlyDictionary<string, string> Types, DateTimeOffset LoadedAt);

    public async Task<IReadOnlyDictionary<string, string>> GetValueTypesAsync(CancellationToken ct)
    {
        var current = _snapshot;
        if (current is not null && !IsExpired(current)) return current.Types;

        await _gate.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            current = _snapshot; // another caller may have loaded it while we waited
            if (current is not null && !IsExpired(current)) return current.Types;

            var types = await LoadAsync(ct).ConfigureAwait(false); // throws on failure; nothing cached
            _snapshot = new Snapshot(types, _clock.GetUtcNow());
            return types;
        }
        finally
        {
            _gate.Release();
        }
    }

    private bool IsExpired(Snapshot s) => _clock.GetUtcNow() - s.LoadedAt >= CacheTtl;

    private async Task<IReadOnlyDictionary<string, string>> LoadAsync(CancellationToken ct)
    {
        await using var db = await dbFactory.CreateDbContextAsync(ct).ConfigureAwait(false);
        var rows = await db.RtsGridMetrics.AsNoTracking()
            .OrderBy(m => m.MetricId)
            .Select(m => new { m.MetricId, m.ValueType })
            .ToListAsync(ct).ConfigureAwait(false);

        var map = new Dictionary<string, string>(rows.Count, StringComparer.OrdinalIgnoreCase);
        foreach (var r in rows)
        {
            // MetricId is the primary key, so exact duplicates cannot occur; ids differing only by case can.
            // Keep the first in ordinal order (deterministic) and say so, instead of failing the whole screen.
            if (!map.TryAdd(r.MetricId, r.ValueType))
                logger.LogWarning("Metric catalogue: MetricId {MetricId} differs from {Kept} only by case; keeping {Kept}",
                    r.MetricId, map.Keys.First(k => string.Equals(k, r.MetricId, StringComparison.OrdinalIgnoreCase)));
        }
        return map;
    }
}
