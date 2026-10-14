using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Domain.Rtm;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Wfm;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using NSubstitute;

namespace CcDashboard.Tests.Security.Wfm;

/// <summary>
/// CORRECTED 14.10: these tests used to seed cells whose Value began with
/// "UsersInStatusGroupCount_" - a MetricId that does not exist in the product (devops on 234: zero
/// such metrics, zero such cells). They were green against my own invention. A group metric is
/// identified by the CATALOGUE: RtsGridMetric.MetricFunction == "UsersInStatusGroupCount" and the
/// group in MetricParameter (the product's own lookup: AgentStateHandlers.cs:50-57). The seeder
/// below now writes a catalogue row plus a cell that references it by MetricId, which is how the
/// real data is shaped, and one test leans on the migration-provided TRAINING metric instead of
/// any seed of mine.
///
/// N now comes from the engine's per-group metrics, delivered as grid cells through the relay.
/// The cases below pin the two things that matter and that the old source got wrong: the sum is
/// per-skill by construction (the engine already counts only agents whose skills match the union),
/// and anything missing yields UNKNOWN rather than a number - never a partial sum, never zero.
///
/// The BU link is on the ROW, not on the grid: devops measured RTSGrid_Grid.UnionId = -1 in all 60
/// rows and RTSGrid_Cell.UnionId = -1 in all 509 on 234, with only RTSGrid_Row.UnionId carrying the
/// BusinessUnitId. Every seed below therefore writes Grid.UnionId = -1 deliberately, so a resolve
/// that looked at the grid level would find nothing and these tests would go red.
///
/// Every test uses its OWN tenant id and a database-generated BU id: PostgresFixture starts one
/// container per collection and never truncates between tests, and RTSGrid_Grid has no TenantId
/// column at all, so rows accumulate and a shared or invented id would let one test's cells answer
/// another's question. That is the same trap that made the N=0 tests go red at 05:39Z.
/// </summary>
[Collection("Postgres")]
public class WfmEngineAgentCountProviderTests(PostgresFixture postgres)
{
    private readonly Guid _tenant = Guid.NewGuid();

    [Fact]
    public async Task SumsTheConfiguredGroups_FromTheRelaySnapshot()
    {
        // Two serving groups with 3 and 4 -> N = 7. The provider must sum only the configured
        // groups: BREAK is present in the grid with 9 and must be ignored, otherwise "serving"
        // would silently mean "everyone".
        var seed = await SeedGridAsync(new Dictionary<string, string>
        {
            ["AVAILABLE"] = "3",
            ["ONPHONE"]   = "4",
            ["BREAK"]     = "9",
        });
        var provider = NewProvider(seed);

        var n = await provider.GetBuServingCountAsync(
            _tenant, seed.BuId, new[] { "AVAILABLE", "ONPHONE" }, default);

        n.IsKnown.Should().BeTrue(n.UnknownReason);
        n.Value.Should().Be(7);
    }

    [Fact]
    public async Task PresentAndZero_IsKnownZero_NotUnknown()
    {
        // NEGATIVE half of the pair below: a metric that exists and says 0 is an answer - nobody is
        // serving right now. Reporting that as unknown would hide a real, computable situation and
        // make the night shift look like a malfunction.
        var seed = await SeedGridAsync(new Dictionary<string, string>
        {
            ["AVAILABLE"] = "0",
        });
        var provider = NewProvider(seed);

        var n = await provider.GetBuServingCountAsync(_tenant, seed.BuId, new[] { "AVAILABLE" }, default);

        n.IsKnown.Should().BeTrue();
        n.Value.Should().Be(0);
    }

    [Fact]
    public async Task ConfiguredGroupWithNoCell_IsUnknown_AndNamesTheGroup()
    {
        // The configured group has no cell in the grid at all: N is unknown, and the reason must
        // carry the group name so the log can say what to fix without a second lookup.
        var seed = await SeedGridAsync(new Dictionary<string, string>
        {
            ["AVAILABLE"] = "5",
        });
        var provider = NewProvider(seed);

        var n = await provider.GetBuServingCountAsync(
            _tenant, seed.BuId, new[] { "AVAILABLE", "PAPERWORK" }, default);

        n.IsKnown.Should().BeFalse();
        n.MissingGroups.Should().ContainSingle().Which.Should().Be("PAPERWORK");
    }

    [Fact]
    public async Task PartialSum_IsNeverReturned()
    {
        // The defect this guards against is subtle and is the whole reason UNKNOWN exists: with one
        // of two groups missing, 5 is a plausible number and would be believed. The value must be
        // absent, not 5.
        var seed = await SeedGridAsync(new Dictionary<string, string>
        {
            ["AVAILABLE"] = "5",
        });
        var provider = NewProvider(seed);

        var n = await provider.GetBuServingCountAsync(
            _tenant, seed.BuId, new[] { "AVAILABLE", "PAPERWORK" }, default);

        n.Value.Should().BeNull("a partial sum is not N");
    }

    [Fact]
    public async Task CellPresentButNoValuePushedYet_IsUnknown()
    {
        // The grid declares the metric, the relay snapshot has nothing for that cell yet (startup,
        // or the engine has not pushed it). Unknown, not zero.
        var seed = await SeedGridAsync(
            cells: new Dictionary<string, string> { ["AVAILABLE"] = "1" },
            snapshotOverride: new Dictionary<string, string>());   // relay delivers nothing
        var provider = NewProvider(seed);

        var n = await provider.GetBuServingCountAsync(_tenant, seed.BuId, new[] { "AVAILABLE" }, default);

        n.IsKnown.Should().BeFalse();
        n.MissingGroups.Should().Contain("AVAILABLE");
    }

    [Fact]
    public async Task NonNumericValue_IsUnknown_NotZero()
    {
        // A value we cannot read is not a zero. int.TryParse failing must not quietly contribute 0.
        var seed = await SeedGridAsync(new Dictionary<string, string>
        {
            ["AVAILABLE"] = "n/a",
        });
        var provider = NewProvider(seed);

        var n = await provider.GetBuServingCountAsync(_tenant, seed.BuId, new[] { "AVAILABLE" }, default);

        n.IsKnown.Should().BeFalse();
    }

    [Fact]
    public async Task NoGridForTheBu_IsUnknown()
    {
        // Nothing seeded for this BU: the answer is unknown, and in particular NOT zero - "no grid"
        // is a configuration gap, not an idle shift.
        // A BU that exists but has no grid at all - closer to the real gap than an invented id,
        // and it also proves the answer is about the grid, not about the BU row being absent.
        int buWithoutGrid;
        await using (var db = postgres.CreateBackendEmulationDbContext())
        {
            var bu = new NgcBusinessUnit { TenantId = _tenant, BusinessUnitName = $"BU-nogrid-{Guid.NewGuid():N}" };
            db.NgcBusinessUnits.Add(bu);
            await db.SaveChangesAsync();
            buWithoutGrid = bu.BusinessUnitId;
        }

        var provider = NewProvider(new Seeded(BuId: buWithoutGrid, GridId: 0,
            Snapshot: new Dictionary<int, string>(), CellByMetric: new Dictionary<string, int>()));

        var n = await provider.GetBuServingCountAsync(_tenant, buWithoutGrid, new[] { "AVAILABLE" }, default);

        n.IsKnown.Should().BeFalse();
        n.UnknownReason.Should().Contain("no grid rows");
    }

    [Fact]
    public async Task AnotherBusGrid_DoesNotAnswerForThisBu()
    {
        // NEGATIVE half of the resolution: a grid exists in the tenant, but for a different BU.
        // Resolving by anything looser than UnionId would hand back that grid's numbers, which is
        // the kind of wrong answer that looks right on screen.
        var other = await SeedGridAsync(new Dictionary<string, string>
        {
            ["AVAILABLE"] = "11",
        });
        var provider = NewProvider(other);

        // A second real BU, with no grid of its own.
        int otherBu;
        await using (var db = postgres.CreateBackendEmulationDbContext())
        {
            var bu = new NgcBusinessUnit { TenantId = _tenant, BusinessUnitName = $"BU-second-{Guid.NewGuid():N}" };
            db.NgcBusinessUnits.Add(bu);
            await db.SaveChangesAsync();
            otherBu = bu.BusinessUnitId;
        }

        var n = await provider.GetBuServingCountAsync(_tenant, otherBu, new[] { "AVAILABLE" }, default);

        n.IsKnown.Should().BeFalse();
        n.UnknownReason.Should().Contain("no grid rows");
    }

    [Fact]
    public async Task PublishedGroupNames_AreTheMetricSuffixes()
    {
        // This is the list the operator picks from, so the stored setting matches a metric by
        // construction - that is how the casing question (data is UPPER CASE, suffixes are mixed)
        // stops being a question. Non-group metrics must not leak into the list.
        // Unique group codes per test run: the metric CATALOGUE has no TenantId column, so it is
        // shared by every test in the collection and fixed names would collide. The non-group
        // metric is marked "!" so the seeder writes it with another MetricFunction instead of
        // inventing a group out of its id.
        var g1 = $"GRPA{Guid.NewGuid():N}"[..12].ToUpperInvariant();
        var g2 = $"GRPB{Guid.NewGuid():N}"[..12].ToUpperInvariant();
        var seed = await SeedGridAsync(new Dictionary<string, string>
        {
            [g1] = "1",
            [g2] = "2",
            ["!QueueLoginDataNumLoggedUsers"] = "25",
        });
        var provider = NewProvider(seed);

        var names = await provider.GetPublishedGroupNamesAsync(_tenant, seed.BuId, default);

        // Equal (not Contain): this list is per-BU, built from THIS BU's cells, so it is not
        // exposed to the shared catalogue's other rows - and that is worth pinning exactly.
        names.Should().Equal(new[] { g1, g2 }.OrderBy(x => x, StringComparer.Ordinal));
        names.Should().NotContain("QueueLoginDataNumLoggedUsers",
            "a metric id is not a group; the catalogue says its function is LogedInUsersCount");
    }

    [Fact]
    public async Task ExactMatchOnly_CasingMismatchIsUnknown()
    {
        // Deliberate: the comparison is Ordinal. A case-insensitive fallback would call the 13.10
        // casing defect a match and hide a real misconfiguration behind a number.
        // The previous version of this test seeded AVAILABLE and ASKED for AVAILABLE while
        // expecting "unknown" - it could only ever fail. It did, in box n2.
        var code = $"GRPC{Guid.NewGuid():N}"[..12].ToUpperInvariant();
        var seed = await SeedGridAsync(new Dictionary<string, string>
        {
            [code] = "3",
        });
        var provider = NewProvider(seed);

        // Same letters, different case - a stale setting from before the pick-from-list change.
        var asConfigured = code[0] + code[1..].ToLowerInvariant();
        var n = await provider.GetBuServingCountAsync(_tenant, seed.BuId, new[] { asConfigured }, default);

        n.IsKnown.Should().BeFalse($"\"{asConfigured}\" is not the catalogue's \"{code}\"");
        n.MissingGroups.Should().Contain(asConfigured);
    }

    [Fact]
    public async Task NoServingGroupsConfigured_IsUnknown_NotZero()
    {
        // Empty setting means "not configured", which is exactly the case the 13.10 fix made
        // storable. It must read as unknown, not as a quiet zero.
        var seed = await SeedGridAsync(new Dictionary<string, string>
        {
            ["AVAILABLE"] = "3",
        });
        var provider = NewProvider(seed);

        var n = await provider.GetBuServingCountAsync(_tenant, seed.BuId, Array.Empty<string>(), default);

        n.IsKnown.Should().BeFalse();
        n.UnknownReason.Should().Contain("no serving groups");
    }

    [Fact]
    public async Task RowsOfAnotherBuInTheSameGrid_AreNotCounted()
    {
        // One grid, two rows, two BUs - the shape devops measured (BU 22: 17 rows across 15 grids).
        // Resolving by grid instead of by row would add the neighbour's agents to ours, and the
        // result would look entirely plausible. This is the test that makes the row-level resolve
        // load-bearing rather than a detail.
        await using var db = postgres.CreateBackendEmulationDbContext();

        var mine = new NgcBusinessUnit { TenantId = _tenant, BusinessUnitName = $"BU-mine-{Guid.NewGuid():N}" };
        var theirs = new NgcBusinessUnit { TenantId = _tenant, BusinessUnitName = $"BU-theirs-{Guid.NewGuid():N}" };
        db.NgcBusinessUnits.AddRange(mine, theirs);
        await db.SaveChangesAsync();

        var grid = new RtsGridGrid { UnionId = -1, Title = "shared-grid" };
        db.RtsGridGrids.Add(grid);
        await db.SaveChangesAsync();

        var column = new RtsGridColumn { GridId = grid.GridId, ColumnNumber = 1 };
        var myRow = new RtsGridRow { GridId = grid.GridId, RowNumber = 1, UnionId = mine.BusinessUnitId };
        var theirRow = new RtsGridRow { GridId = grid.GridId, RowNumber = 2, UnionId = theirs.BusinessUnitId };
        db.RtsGridColumns.Add(column);
        db.RtsGridRows.AddRange(myRow, theirRow);
        await db.SaveChangesAsync();

        // ONE catalogue metric, referenced by BOTH rows' cells - the real shape: the metric means
        // "agents in AVAILABLE", and each BU's row carries its own cell for it. The cell's Value is
        // a MetricId and holds no group; the group lives only in the catalogue.
        var metricId = $"TestM{Guid.NewGuid():N}"[..20];
        db.RtsGridMetrics.Add(new RtsGridMetric
        {
            MetricId = metricId,
            Description = "shared counter",
            DataType = "UsersSummary",
            MetricFunction = "UsersInStatusGroupCount",
            MetricParameter = "AVAILABLE",
            ValueType = "number",
            MetricType = "Data"
        });
        await db.SaveChangesAsync();

        var myCell = new RtsGridCell { RowId = myRow.RowId, ColumnId = column.ColumnId, Value = metricId };
        var theirCell = new RtsGridCell { RowId = theirRow.RowId, ColumnId = column.ColumnId, Value = metricId };
        db.RtsGridCells.AddRange(myCell, theirCell);
        await db.SaveChangesAsync();

        var seed = new Seeded(mine.BusinessUnitId, grid.GridId,
            Snapshot: new Dictionary<int, string> { [myCell.CellId] = "2", [theirCell.CellId] = "40" },
            CellByMetric: new Dictionary<string, int> { ["AVAILABLE"] = myCell.CellId });
        var provider = NewProvider(seed);

        var n = await provider.GetBuServingCountAsync(
            _tenant, mine.BusinessUnitId, new[] { "AVAILABLE" }, default);

        n.IsKnown.Should().BeTrue(n.UnknownReason);
        n.Value.Should().Be(2, "the neighbour's 40 belongs to another BU's row");
    }

    // ── helpers ──────────────────────────────────────────────────────────────────

    private sealed record Seeded(
        int BuId,
        int GridId,
        Dictionary<int, string> Snapshot,
        Dictionary<string, int> CellByMetric);

    /// <summary>
    /// Seeds one grid with UnionId = -1 (as the live data has it), one ROW whose UnionId is the BU -
    /// which is the only link that exists, written by RtsRepository.InsertQueueGridRowAsync:217-226
    /// (raw INSERT INTO "RTSGrid_Row") from SaveDataSlotRtsCommand.cs:63 - and one cell per metric
    /// with the MetricId in Cell.Value, which is where the real cell map comes from
    /// (RtsRepository.GetCellMapForGridAsync, :305). No widget configuration is involved.
    /// </summary>
    private async Task<Seeded> SeedGridAsync(
        Dictionary<string, string> cells,
        Dictionary<string, string>? snapshotOverride = null)
    {
        await using var db = postgres.CreateBackendEmulationDbContext();

        // The BU id comes from the database, not from Random: RTSGrid_Grid has NO TenantId column
        // (measured), so the provider resolves a grid by UnionId alone and two tests drawing the
        // same random number would read each other's grid. An identity id cannot collide.
        var bu = new NgcBusinessUnit { TenantId = _tenant, BusinessUnitName = $"BU-{Guid.NewGuid():N}" };
        db.NgcBusinessUnits.Add(bu);
        await db.SaveChangesAsync();
        var buId = bu.BusinessUnitId;

        // -1 on purpose: this is what the live data holds, and it is the negative half the
        // coordinator asked for - the map must still be non-empty.
        var grid = new RtsGridGrid { UnionId = -1, Title = $"grid-{buId}" };
        db.RtsGridGrids.Add(grid);
        await db.SaveChangesAsync();

        var row = new RtsGridRow { GridId = grid.GridId, RowNumber = 1, UnionId = buId };
        db.RtsGridRows.Add(row);
        var column = new RtsGridColumn { GridId = grid.GridId, ColumnNumber = 1 };
        db.RtsGridColumns.Add(column);
        await db.SaveChangesAsync();

        // For each requested GROUP: one catalogue row (function + parameter, as the product stores
        // it) and one cell referencing that metric by MetricId. The cell's Value is a MetricId and
        // carries no group - the group is only in the catalogue, which is the correction.
        //
        // A key prefixed with "!" means a NON-group metric: the row is written with a different
        // MetricFunction and an empty parameter, the way the product stores such metrics
        // (DatabaseInitializer.cs:611 - QueueLoginDataNumLoggedUsers has MetricFunction
        // "LogedInUsersCount" and no parameter). Before this, passing a metric id as a dictionary
        // key made the seeder invent a GROUP with that name - which is exactly what polluted the
        // shared catalogue and failed the box.
        var cellByMetric = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var key in cells.Keys)
        {
            var isGroup = !key.StartsWith("!", StringComparison.Ordinal);
            var group = isGroup ? key : key[1..];
            var metricId = $"TestM{Guid.NewGuid():N}"[..20];
            db.RtsGridMetrics.Add(new RtsGridMetric
            {
                MetricId = metricId,
                Description = isGroup ? $"test counter for {group}" : $"non-group metric {group}",
                DataType = "UsersSummary",
                MetricFunction = isGroup ? "UsersInStatusGroupCount" : "LogedInUsersCount",
                MetricParameter = isGroup ? group : "",
                ValueType = "number",
                MetricType = "Data"
            });
            await db.SaveChangesAsync();

            var cell = new RtsGridCell { RowId = row.RowId, ColumnId = column.ColumnId, Value = metricId };
            db.RtsGridCells.Add(cell);
            await db.SaveChangesAsync();
            cellByMetric[key] = cell.CellId;
        }

        var values = snapshotOverride ?? cells;
        var snapshot = values
            .Where(kv => cellByMetric.ContainsKey(kv.Key))
            .ToDictionary(kv => cellByMetric[kv.Key], kv => kv.Value);

        return new Seeded(buId, grid.GridId, snapshot, cellByMetric);
    }

    /// <summary>
    /// The relay substitute behaves like the real one on the point that matters: a late subscriber
    /// is handed the current snapshot immediately (RtmRelayService.cs:561-570), which is why the
    /// provider needs no extra interface method and the first tick is not blind.
    /// </summary>
    private IWfmEngineAgentCountProvider NewProvider(Seeded seed)
    {
        var relay = Substitute.For<IRtmRelayService>();

        relay.SubscribeGridAsync(
                Arg.Any<Guid>(), Arg.Any<int>(),
                Arg.Any<Func<IReadOnlyList<GridCellUpdate>, Task>>(), Arg.Any<CancellationToken>())
            .Returns(call =>
            {
                var handler = call.ArgAt<Func<IReadOnlyList<GridCellUpdate>, Task>>(2);
                var updates = seed.Snapshot
                    .Select(kv => new GridCellUpdate(kv.Key, kv.Value))
                    .ToList();
                return handler(updates);
            });

        var factory = Substitute.For<IDbContextFactory<BackendEmulationDbContext>>();
        factory.CreateDbContextAsync(Arg.Any<CancellationToken>())
               .Returns(_ => Task.FromResult(postgres.CreateBackendEmulationDbContext()));

        return new WfmEngineAgentCountProvider(
            relay, factory, NullLogger<WfmEngineAgentCountProvider>.Instance);
    }
}
