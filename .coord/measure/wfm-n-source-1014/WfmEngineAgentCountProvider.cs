using System.Collections.Concurrent;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain.Rtm;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Wfm;

/// <summary>
/// N for WFM, taken from the engine's own metrics instead of from RTSData_UserStatus.
///
/// Why: metrics-1014 measured that the database holds no CURRENT agent state - RTSData_UserStatus
/// accumulates rows per date and the log only writes a status once it has ended - which is how N
/// came out 38 against 25 logged-in agents. The engine, by contrast, keeps live per-group counts
/// and already publishes them as grid cells named UsersInStatusGroupCount_&lt;Group&gt;; that is what
/// the ASD widget draws.
///
/// Those counts are per-skill by construction, which is what the operator asked for ("agents by
/// skill"): the engine puts an agent into a union only when the agent's activated skills contain
/// every user group the union requires (RTM/RTM/UserManager.cs:572, ContainsAllItems), and the
/// per-group metric counts exactly that union's users (RTM/RTM/Union.cs:859-865). Nothing here has
/// to re-derive a roster, and the §36a BU-&gt;SG-&gt;AG-&gt;user walk is not used for N any more.
///
/// SINGLETON. Two independent reasons:
///   1. it holds subscriptions that must outlive a tick - WfmRealtimeLoop opens a new scope every
///      30 s (WfmRealtimeLoop.cs:74), so anything Scoped loses its state and its handlers;
///   2. the relay is itself a singleton holding one hub connection per (tenant, grid), and
///      subscribing/unsubscribing per tick would churn those connections and fight the ref-count
///      in RtmRelayService.GridState.
/// </summary>
public interface IWfmEngineAgentCountProvider
{
    /// <summary>
    /// N for one BU: the sum of the current per-group counts over <paramref name="servingGroups"/>.
    /// Returns null for UNKNOWN - no grid for the BU, a configured group with no cell, or a cell
    /// with no value yet. Null is not 0: zero means "nobody is serving", null means "we do not
    /// know", and the Erlang step must not compute on a guess.
    /// </summary>
    Task<WfmAgentCount> GetBuServingCountAsync(
        Guid tenantId, int businessUnitId, IReadOnlyList<string> servingGroups, CancellationToken ct = default);

    /// <summary>
    /// The group names the engine actually publishes for this BU, read from the metric suffixes of
    /// its grid. This is the list the operator picks from, so a saved setting matches a metric by
    /// construction and the casing question disappears.
    /// </summary>
    Task<IReadOnlyList<string>> GetPublishedGroupNamesAsync(
        Guid tenantId, int businessUnitId, CancellationToken ct = default);
}

/// <summary>
/// N, or the reason it is unknown. A record rather than int? so the caller can log WHICH group was
/// missing without a second lookup - "N unknown" alone sends the reader back to the database.
/// </summary>
public sealed record WfmAgentCount(int? Value, string? UnknownReason, IReadOnlyList<string> MissingGroups)
{
    public static WfmAgentCount Known(int value) => new(value, null, Array.Empty<string>());

    public static WfmAgentCount Unknown(string reason, IReadOnlyList<string>? missing = null) =>
        new(null, reason, missing ?? Array.Empty<string>());

    public bool IsKnown => Value.HasValue;
}

public sealed class WfmEngineAgentCountProvider(
    IRtmRelayService relay,
    IDbContextFactory<BackendEmulationDbContext> beFactory,
    ILogger<WfmEngineAgentCountProvider> logger) : IWfmEngineAgentCountProvider
{
    private const string GroupMetricPrefix = "UsersInStatusGroupCount_";

    /// <summary>Latest cell values per (tenant, grid): MetricId -> raw string from the engine.</summary>
    private readonly ConcurrentDictionary<(Guid TenantId, int GridId), ConcurrentDictionary<string, string>> _values = new();

    /// <summary>CellId -> MetricId per grid, and the subscription that keeps _values fresh.</summary>
    private readonly ConcurrentDictionary<(Guid TenantId, int GridId), GridSubscription> _subscriptions = new();

    /// <summary>BU -> GridId. RTSGrid_Grid.UnionId IS the BusinessUnitId (SaveAgentGridRtsCommand.cs:97,
    /// RtsRepository.cs:66), so this needs no widget configuration and works with no ASD on screen.</summary>
    private readonly ConcurrentDictionary<(Guid TenantId, int BuId), int?> _gridByBu = new();

    public async Task<WfmAgentCount> GetBuServingCountAsync(
        Guid tenantId, int businessUnitId, IReadOnlyList<string> servingGroups, CancellationToken ct = default)
    {
        if (servingGroups.Count == 0)
            return WfmAgentCount.Unknown("no serving groups configured");

        var gridId = await ResolveGridAsync(tenantId, businessUnitId, ct);
        if (gridId is null)
            return WfmAgentCount.Unknown($"no grid for BU {businessUnitId}");

        var sub = await EnsureSubscribedAsync(tenantId, gridId.Value, ct);
        var values = _values.GetOrAdd((tenantId, gridId.Value), _ => new ConcurrentDictionary<string, string>());

        var total = 0;
        var missing = new List<string>();

        foreach (var group in servingGroups)
        {
            var metricId = GroupMetricPrefix + group;

            // Exact match, on purpose. The operator picks the group from the published suffixes
            // (GetPublishedGroupNamesAsync), so a mismatch here is a real configuration error and
            // must not be smoothed over by a case-insensitive compare.
            if (!sub.MetricIds.Contains(metricId))
            {
                missing.Add(group);
                continue;
            }

            if (!values.TryGetValue(metricId, out var raw))
            {
                // The cell exists but the engine has not pushed a value yet.
                missing.Add(group);
                continue;
            }

            if (!int.TryParse(raw, out var parsed))
            {
                // A non-numeric value is not a zero: it is a value we failed to read.
                missing.Add(group);
                continue;
            }

            total += parsed;
        }

        if (missing.Count > 0)
        {
            // A partial sum is NOT N. Two groups out of three configured do not make an answer,
            // and returning the partial number would be a plausible wrong figure - the worst kind.
            return WfmAgentCount.Unknown(
                $"{missing.Count} of {servingGroups.Count} serving groups have no current value",
                missing);
        }

        return WfmAgentCount.Known(total);
    }

    public async Task<IReadOnlyList<string>> GetPublishedGroupNamesAsync(
        Guid tenantId, int businessUnitId, CancellationToken ct = default)
    {
        var gridId = await ResolveGridAsync(tenantId, businessUnitId, ct);
        if (gridId is null)
            return Array.Empty<string>();

        var sub = await EnsureSubscribedAsync(tenantId, gridId.Value, ct);

        return sub.MetricIds
            .Where(m => m.StartsWith(GroupMetricPrefix, StringComparison.Ordinal))
            .Select(m => m[GroupMetricPrefix.Length..])
            .Where(s => s.Length > 0)
            .Distinct(StringComparer.Ordinal)
            .OrderBy(s => s, StringComparer.Ordinal)
            .ToList();
    }

    // ── internals ────────────────────────────────────────────────────────────────

    private async Task<int?> ResolveGridAsync(Guid tenantId, int buId, CancellationToken ct)
    {
        if (_gridByBu.TryGetValue((tenantId, buId), out var cached))
            return cached;

        await using var ctx = await beFactory.CreateDbContextAsync(ct);

        // One grid per union by construction; if several exist, the lowest id is taken and the
        // ambiguity is logged rather than silently resolved - a wrong grid would produce a
        // plausible N for the wrong BU.
        var ids = await ctx.RtsGridGrids
            .AsNoTracking()
            .Where(g => g.UnionId == buId)
            .Select(g => g.GridId)
            .OrderBy(id => id)
            .ToListAsync(ct);

        if (ids.Count == 0)
        {
            // Fallback by ROW union. Both carry the BU: the save path sets UnionId on the grid
            // (RtsRepository.cs:66) and on the row ("Row (RowNumber=1, UnionId=BusinessUnitId)",
            // SaveDataSlotRtsCommand.cs:59). A grid saved by an older path may have it only on the
            // row, and resolving by one field alone would report "no grid" for a BU that has one.
            ids = await ctx.RtsGridRows
                .AsNoTracking()
                .Where(r => r.UnionId == buId)
                .Select(r => r.GridId)
                .Distinct()
                .OrderBy(id => id)
                .ToListAsync(ct);

            if (ids.Count > 0)
                logger.LogInformation(
                    "WfmEngineAgentCountProvider: BU {BuId} resolved to grid {GridId} by ROW union, "
                  + "not by grid union - the grid row carries the BU but the grid itself does not.",
                    buId, ids[0]);
        }

        if (ids.Count > 1)
        {
            logger.LogWarning(
                "WfmEngineAgentCountProvider: BU {BuId} maps to {Count} grids [{Ids}]; using {Chosen}. "
              + "N is computed from one grid, so this is a configuration ambiguity worth fixing.",
                buId, ids.Count, string.Join(", ", ids), ids[0]);
        }

        int? resolved = ids.Count > 0 ? ids[0] : null;
        _gridByBu[(tenantId, buId)] = resolved;
        return resolved;
    }

    private async Task<GridSubscription> EnsureSubscribedAsync(Guid tenantId, int gridId, CancellationToken ct)
    {
        if (_subscriptions.TryGetValue((tenantId, gridId), out var existing))
            return existing;

        await using var ctx = await beFactory.CreateDbContextAsync(ct);

        // CellId -> MetricId comes from the cell rows themselves, not from any widget config:
        // RTSGrid_Cell.Value holds the MetricId (RtsRepository.GetCellMapForGridAsync, :305).
        var cellMap = await (
            from c in ctx.RtsGridCells.AsNoTracking()
            join r in ctx.RtsGridRows.AsNoTracking() on c.RowId equals r.RowId
            where r.GridId == gridId && c.Value != null && c.Value != ""
            select new { c.CellId, c.Value })
            .ToListAsync(ct);

        var byCell = cellMap.ToDictionary(x => x.CellId, x => x.Value!);
        var metricIds = new HashSet<string>(byCell.Values, StringComparer.Ordinal);

        var values = _values.GetOrAdd((tenantId, gridId), _ => new ConcurrentDictionary<string, string>());

        Func<IReadOnlyList<GridCellUpdate>, Task> handler = updates =>
        {
            foreach (var cell in updates)
            {
                // GridCellUpdate.Value is non-nullable (Domain/Domain/Rtm/GridCellUpdate.cs:4),
                // so there is nothing to null-check here.
                if (byCell.TryGetValue(cell.CellId, out var metricId))
                    values[metricId] = cell.Value;
            }
            return Task.CompletedTask;
        };

        var sub = new GridSubscription(metricIds, handler);

        // First writer wins: a concurrent tick for the same grid must not open a second subscription.
        if (!_subscriptions.TryAdd((tenantId, gridId), sub))
            return _subscriptions[(tenantId, gridId)];

        // Subscribing is also how we GET the current values: the relay delivers its whole snapshot
        // to a late subscriber immediately (RtmRelayService.cs:561-570), so the first tick after
        // startup is not blind - it does not have to wait for the engine's next push.
        await relay.SubscribeGridAsync(tenantId, gridId, handler, ct);

        logger.LogInformation(
            "WfmEngineAgentCountProvider: subscribed to grid {GridId} for tenant {TenantId}, {MetricCount} metrics, "
          + "{GroupCount} of them per-group counts",
            gridId, tenantId, metricIds.Count,
            metricIds.Count(m => m.StartsWith(GroupMetricPrefix, StringComparison.Ordinal)));

        return sub;
    }

    private sealed record GridSubscription(
        HashSet<string> MetricIds,
        Func<IReadOnlyList<GridCellUpdate>, Task> Handler);
}
