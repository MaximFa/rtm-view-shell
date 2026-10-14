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
/// THE BU LINK IS ON THE ROW, NOT ON THE GRID. Measured by devops on 234 (14.10):
/// RTSGrid_Grid.UnionId is -1 in all 60 rows and RTSGrid_Cell.UnionId is -1 in all 509; only
/// RTSGrid_Row.UnionId carries the BusinessUnitId. The write path agrees: RTSGrid_Row is inserted
/// with UnionId = BusinessUnitId (RtsRepository.InsertQueueGridRowAsync, :217-226, raw INSERT INTO
/// "RTSGrid_Row"), called from SaveDataSlotRtsCommand.cs:63.
/// My earlier claim that the grid level carries it too was wrong: the code I read
/// (SaveAgentGridRtsCommand.cs:95, RtsRepository.UpdateGridAsync:66) writes RtsUserGridGrid - the
/// RTSUserGrid_Grid table - which is a DIFFERENT entity from RtsGridGrid/RTSGrid_Grid. Claim
/// withdrawn; the row is the only resolve path here.
///
/// One BU therefore spans MANY grids: devops measured BU 22 as 17 rows across 15 grids. The
/// provider subscribes to every grid that holds one of the BU's rows, and reads only the cells of
/// those rows - never the whole grid, whose other rows belong to other BUs.
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
    private const string GroupMetricFunction = "UsersInStatusGroupCount";

    /// <summary>
    /// Latest value per (tenant, CellId). Keyed on CellId rather than MetricId because one BU spans
    /// several grids and the same MetricId appears in each of them - keying on the metric would let
    /// one grid's value overwrite another's, which is exactly how a BU could end up with another
    /// BU's number.
    /// </summary>
    private readonly ConcurrentDictionary<(Guid TenantId, int CellId), string> _values = new();

    /// <summary>One subscription per (tenant, grid), shared by every BU with rows in that grid.</summary>
    private readonly ConcurrentDictionary<(Guid TenantId, int GridId), bool> _subscribed = new();

    /// <summary>
    /// BU -> the grids and cells that belong to it, resolved through RTSGrid_Row.UnionId. No widget
    /// configuration is involved, so this works with no ASD on screen - the condition the
    /// coordinator set.
    /// </summary>
    private readonly ConcurrentDictionary<(Guid TenantId, int BuId), BuCellMap> _cellsByBu = new();

    /// <summary>
    /// Cells of one BU: which grids to subscribe to, and which cells carry which GROUP.
    /// The group comes from the metric catalogue (MetricParameter), not from the cell's text.
    /// </summary>
    private sealed record BuCellMap(
        IReadOnlyList<int> GridIds,
        Dictionary<int, string> MetricByCell,
        Dictionary<string, List<int>> CellsByGroup);

    public async Task<WfmAgentCount> GetBuServingCountAsync(
        Guid tenantId, int businessUnitId, IReadOnlyList<string> servingGroups, CancellationToken ct = default)
    {
        if (servingGroups.Count == 0)
            return WfmAgentCount.Unknown("no serving groups configured");

        var map = await ResolveBuCellsAsync(tenantId, businessUnitId, ct);
        if (map.MetricByCell.Count == 0)
            return WfmAgentCount.Unknown($"no grid rows for BU {businessUnitId}");

        await EnsureSubscribedAsync(tenantId, map, ct);

        var total = 0;
        var missing = new List<string>();

        foreach (var group in servingGroups)
        {
            // The configured group is matched against MetricParameter from the catalogue, exactly.
            // Both sides are the platform's own upper-case codes (AVAILABLE, ONPHONE, PAPERWORK...),
            // so there is no casing question left to paper over: the operator picks the group from
            // GetPublishedGroupNamesAsync, which returns those same parameters.
            if (!map.CellsByGroup.TryGetValue(group, out var cells) || cells.Count == 0)
            {
                missing.Add(group);
                continue;
            }

            // One BU can hold the same metric in several grids. Taking the max rather than the sum:
            // each cell reports the SAME engine counter for the same union, so summing would
            // multiply one group's agents by the number of grids showing it. Max over identical
            // values is that value; if the values disagree, one grid is stale and the larger number
            // is the fresher push - and the disagreement is logged rather than averaged away.
            int? best = null;
            var seen = new List<int>();
            foreach (var cellId in cells)
            {
                if (!_values.TryGetValue((tenantId, cellId), out var raw))
                    continue;
                if (!int.TryParse(raw, out var parsed))
                    continue;      // a value we cannot read is not a zero
                seen.Add(parsed);
                best = best is null ? parsed : Math.Max(best.Value, parsed);
            }

            if (best is null)
            {
                // Cells exist but no value has arrived for any of them yet.
                missing.Add(group);
                continue;
            }

            if (seen.Distinct().Count() > 1)
            {
                logger.LogWarning(
                    "WfmEngineAgentCountProvider: BU {BuId} group {Group} reports differing values across grids [{Values}]; "
                  + "using {Chosen}. One of those grids is stale.",
                    businessUnitId, group, string.Join(", ", seen), best.Value);
            }

            total += best.Value;
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
        var map = await ResolveBuCellsAsync(tenantId, businessUnitId, ct);

        // The group names are MetricParameter values from the catalogue - the platform's own codes.
        // Nothing is parsed out of a MetricId here, because a MetricId carries no group.
        return map.CellsByGroup.Keys
            .OrderBy(g => g, StringComparer.Ordinal)
            .ToList();
    }

    // ── internals ────────────────────────────────────────────────────────────────

    private async Task<BuCellMap> ResolveBuCellsAsync(Guid tenantId, int buId, CancellationToken ct)
    {
        if (_cellsByBu.TryGetValue((tenantId, buId), out var cached))
            return cached;

        await using var ctx = await beFactory.CreateDbContextAsync(ct);

        // BU -> rows -> cells. The MetricId lives in Cell.Value, which is where the real cell map
        // comes from too (RtsRepository.GetCellMapForGridAsync, :305). Rows of OTHER BUs in the
        // same grid are excluded by the UnionId filter - that is the whole reason this is keyed on
        // the row and not on the grid.
        // Three-way join: the BU's rows give the cells, the cell's Value is a MetricId, and the
        // CATALOGUE says which of those metrics are per-group counters and for which group.
        // Joining the catalogue is the whole correction: without it there is no way to tell a group
        // counter from any other metric, and no way to learn the group's name.
        var rows = await (
            from c in ctx.RtsGridCells.AsNoTracking()
            join r in ctx.RtsGridRows.AsNoTracking() on c.RowId equals r.RowId
            join m in ctx.RtsGridMetrics.AsNoTracking() on c.Value equals m.MetricId
            where r.UnionId == buId
                  && m.MetricFunction == GroupMetricFunction
                  && m.MetricParameter != null && m.MetricParameter != ""
            select new { r.GridId, c.CellId, MetricId = c.Value!, Group = m.MetricParameter })
            .ToListAsync(ct);

        var map = new BuCellMap(
            GridIds: rows.Select(x => x.GridId).Distinct().OrderBy(id => id).ToList(),
            MetricByCell: rows.GroupBy(x => x.CellId).ToDictionary(g => g.Key, g => g.First().MetricId),
            CellsByGroup: rows
                .GroupBy(x => x.Group, StringComparer.Ordinal)
                .ToDictionary(g => g.Key, g => g.Select(x => x.CellId).Distinct().ToList(), StringComparer.Ordinal));

        if (map.GridIds.Count > 1)
        {
            // Normal, not an anomaly: one BU legitimately has rows in several grids. Logged at
            // Debug so the shape is visible once without adding to the noise the gate just removed.
            logger.LogDebug(
                "WfmEngineAgentCountProvider: BU {BuId} has cells in {GridCount} grids [{Ids}], {CellCount} cells",
                buId, map.GridIds.Count, string.Join(", ", map.GridIds), map.MetricByCell.Count);
        }

        _cellsByBu[(tenantId, buId)] = map;
        return map;
    }

    private async Task EnsureSubscribedAsync(Guid tenantId, BuCellMap map, CancellationToken ct)
    {
        foreach (var gridId in map.GridIds)
        {
            // First writer wins: a concurrent tick must not open a second subscription for the same
            // grid, and several BUs share a grid, so this is reached repeatedly by design.
            if (!_subscribed.TryAdd((tenantId, gridId), true))
                continue;

            Task Handler(IReadOnlyList<GridCellUpdate> updates)
            {
                foreach (var cell in updates)
                {
                    // Stored by CellId for every cell of the grid, not only this BU's: another BU
                    // sharing the grid reads the same stream, and filtering here would make the
                    // first BU to subscribe decide what the others can see.
                    // GridCellUpdate.Value is non-nullable (Domain/Domain/Rtm/GridCellUpdate.cs:4).
                    _values[(tenantId, cell.CellId)] = cell.Value;
                }
                return Task.CompletedTask;
            }

            // Subscribing is also how we GET the current values: the relay delivers its whole
            // snapshot to a late subscriber immediately (RtmRelayService.cs:561-570), so the first
            // tick after startup is not blind - it does not wait for the engine's next push.
            await relay.SubscribeGridAsync(tenantId, gridId, Handler, ct);

            logger.LogInformation(
                "WfmEngineAgentCountProvider: subscribed to grid {GridId} for tenant {TenantId}",
                gridId, tenantId);
        }
    }
}
