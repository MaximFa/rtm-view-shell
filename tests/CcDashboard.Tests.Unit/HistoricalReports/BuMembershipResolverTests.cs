using CcDashboard.Application.HistoricalReports;
using CcDashboard.Domain.Domain;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// Tests for BuMembershipResolver per spec §4.
/// Covers: queue resolution, agent DETAIL union, agent CUMULATIVE ∪_SG(∩_AG),
/// PG-intersection (SF-BI-001), external-ID keying.
/// Updated 2026-07-02: uses IDbContextFactory.
/// </summary>
public class BuMembershipResolverTests : IAsyncLifetime
{
    private BackendEmulationDbContext _db = null!;
    private TestDbContextFactory _factory = null!;
    private BuMembershipResolver _resolver = null!;

    private static readonly Guid TenantId = Guid.Parse("11111111-1111-1111-1111-111111111111");
    private const int BuId = 100;
    private const int Sg1Id = 200;
    private const int Sg2Id = 201;

    public async Task InitializeAsync()
    {
        var opts = new DbContextOptionsBuilder<BackendEmulationDbContext>()
            .UseInMemoryDatabase($"BuMembershipTest_{Guid.NewGuid()}")
            .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning))
            .Options;

        _db = new BackendEmulationDbContext(opts);
        _factory = new TestDbContextFactory(opts);
        _resolver = new BuMembershipResolver(_factory, NullLogger<BuMembershipResolver>.Instance);

        await SeedTestDataAsync();
    }

    public async Task DisposeAsync()
    {
        await _db.DisposeAsync();
    }

    private async Task SeedTestDataAsync()
    {
        // BU -> 3 queues (Q1, Q2, Q3) via ClassificationId='ALL'
        _db.NgcBusinessUnitQueueClassifications.AddRange(
            new NgcBusinessUnitQueueClassification { BusinessUnitId = BuId, QueueId = "Q1", TenantId = TenantId, ClassificationId = "ALL" },
            new NgcBusinessUnitQueueClassification { BusinessUnitId = BuId, QueueId = "Q2", TenantId = TenantId, ClassificationId = "ALL" },
            new NgcBusinessUnitQueueClassification { BusinessUnitId = BuId, QueueId = "Q3", TenantId = TenantId, ClassificationId = "ALL" },
            // Queue with different ClassificationId — should be excluded
            new NgcBusinessUnitQueueClassification { BusinessUnitId = BuId, QueueId = "Q4", TenantId = TenantId, ClassificationId = "SALES" }
        );

        // BU -> 2 Supergroups
        _db.NgcBusinessUnitSupergroups.AddRange(
            new NgcBusinessUnitSupergroup { BusinessUnitId = BuId, SupergroupId = Sg1Id, TenantId = TenantId },
            new NgcBusinessUnitSupergroup { BusinessUnitId = BuId, SupergroupId = Sg2Id, TenantId = TenantId }
        );

        // SG1 -> 1 AgentGroup (Conv-1: one AG per SG)
        // AG "AG1" with agents: A1, A2
        _db.NgcSupergroupAgentgroups.Add(
            new NgcSupergroupAgentgroup { Id = 1, SupergroupId = Sg1Id, AgentgroupId = "AG1", TenantId = TenantId }
        );
        _db.NgcUserAgentgroups.AddRange(
            new NgcUserAgentgroup { Id = 1, AgentgroupId = "AG1", UserId = "A1", TenantId = TenantId },
            new NgcUserAgentgroup { Id = 2, AgentgroupId = "AG1", UserId = "A2", TenantId = TenantId }
        );

        // SG2 -> 2 AgentGroups (Conv-2: multi-AG per SG, intersection semantics)
        // AG "AG2" with agents: A3, A4, A5
        // AG "AG3" with agents: A4, A5, A6
        // Intersection of AG2 and AG3 = {A4, A5}
        _db.NgcSupergroupAgentgroups.AddRange(
            new NgcSupergroupAgentgroup { Id = 2, SupergroupId = Sg2Id, AgentgroupId = "AG2", TenantId = TenantId },
            new NgcSupergroupAgentgroup { Id = 3, SupergroupId = Sg2Id, AgentgroupId = "AG3", TenantId = TenantId }
        );
        _db.NgcUserAgentgroups.AddRange(
            new NgcUserAgentgroup { Id = 3, AgentgroupId = "AG2", UserId = "A3", TenantId = TenantId },
            new NgcUserAgentgroup { Id = 4, AgentgroupId = "AG2", UserId = "A4", TenantId = TenantId },
            new NgcUserAgentgroup { Id = 5, AgentgroupId = "AG2", UserId = "A5", TenantId = TenantId },
            new NgcUserAgentgroup { Id = 6, AgentgroupId = "AG3", UserId = "A4", TenantId = TenantId },
            new NgcUserAgentgroup { Id = 7, AgentgroupId = "AG3", UserId = "A5", TenantId = TenantId },
            new NgcUserAgentgroup { Id = 8, AgentgroupId = "AG3", UserId = "A6", TenantId = TenantId }
        );

        await _db.SaveChangesAsync();
    }

    /// <summary>
    /// Test helper: IDbContextFactory that returns contexts sharing the same InMemory database.
    /// </summary>
    private class TestDbContextFactory : IDbContextFactory<BackendEmulationDbContext>
    {
        private readonly DbContextOptions<BackendEmulationDbContext> _options;

        public TestDbContextFactory(DbContextOptions<BackendEmulationDbContext> options)
        {
            _options = options;
        }

        public BackendEmulationDbContext CreateDbContext() => new(_options);
    }

    #region Queue Resolution Tests

    [Fact]
    public async Task ResolveQueues_BuWithQueues_ReturnsWorkgroupsWithClassificationAll()
    {
        // Superadmin scope = full
        var pgScope = ReportScope.Full();

        var result = await _resolver.ResolveQueuesAsync(TenantId, new[] { BuId }, pgScope);

        // Q1, Q2, Q3 have ClassificationId='ALL'; Q4 has 'SALES' and should be excluded
        Assert.Equal(3, result.Count);
        Assert.Contains("Q1", result);
        Assert.Contains("Q2", result);
        Assert.Contains("Q3", result);
        Assert.DoesNotContain("Q4", result);
    }

    [Fact]
    public async Task ResolveQueues_PgIntersection_NarrowsResult()
    {
        // PG allows only Q1 and Q2
        var pgScope = new ReportScope
        {
            FullScope = false,
            AllowedWorkgroups = new HashSet<string> { "Q1", "Q2" }
        };

        var result = await _resolver.ResolveQueuesAsync(TenantId, new[] { BuId }, pgScope);

        Assert.Equal(2, result.Count);
        Assert.Contains("Q1", result);
        Assert.Contains("Q2", result);
        Assert.DoesNotContain("Q3", result);
    }

    [Fact]
    public async Task ResolveQueues_EmptyPg_ReturnsDeny()
    {
        // Empty PG = DENY per PG-03
        var pgScope = new ReportScope
        {
            FullScope = false,
            AllowedWorkgroups = new HashSet<string>()
        };

        var result = await _resolver.ResolveQueuesAsync(TenantId, new[] { BuId }, pgScope);

        Assert.Empty(result);
    }

    [Fact]
    public async Task ResolveQueues_NoBusProvided_ReturnsEmpty()
    {
        var pgScope = ReportScope.Full();

        var result = await _resolver.ResolveQueuesAsync(TenantId, Array.Empty<int>(), pgScope);

        Assert.Empty(result);
    }

    #endregion

    #region Agent DETAIL Tests (Union)

    [Fact]
    public async Task ResolveAgents_Detail_UnionAllAgentsAcrossAllAgs()
    {
        // Detail = union of all agents: A1, A2 (SG1) + A3, A4, A5, A6 (SG2 via AG2+AG3)
        var pgScope = ReportScope.Full();

        var result = await _resolver.ResolveAgentsAsync(TenantId, new[] { BuId }, AgentReportAxis.Detail, pgScope);

        // All unique agents: A1, A2, A3, A4, A5, A6
        Assert.Equal(6, result.Count);
        Assert.Contains("A1", result);
        Assert.Contains("A2", result);
        Assert.Contains("A3", result);
        Assert.Contains("A4", result);
        Assert.Contains("A5", result);
        Assert.Contains("A6", result);
    }

    [Fact]
    public async Task ResolveAgents_Detail_AgentInSomeAgsIncluded()
    {
        // A3 is in AG2 only (not AG3) but should still be in DETAIL (union)
        var pgScope = ReportScope.Full();

        var result = await _resolver.ResolveAgentsAsync(TenantId, new[] { BuId }, AgentReportAxis.Detail, pgScope);

        Assert.Contains("A3", result);
        Assert.Contains("A6", result); // A6 is in AG3 only
    }

    #endregion

    #region Agent CUMULATIVE Tests (∪_SG(∩_AG))

    [Fact]
    public async Task ResolveAgents_Cumulative_Conv1_SingleAgPerSg_NoIntersectionNeeded()
    {
        // SG1 has 1 AG (AG1) -> ∩ of one set = the set itself
        // SG1 contributes: A1, A2
        // Need to test just SG1 to isolate Conv-1
        // Create a separate BU with only SG1
        _db.NgcBusinessUnitSupergroups.Add(
            new NgcBusinessUnitSupergroup { BusinessUnitId = 999, SupergroupId = Sg1Id, TenantId = TenantId }
        );
        await _db.SaveChangesAsync();

        var pgScope = ReportScope.Full();
        var result = await _resolver.ResolveAgentsAsync(TenantId, new[] { 999 }, AgentReportAxis.Cumulative, pgScope);

        Assert.Equal(2, result.Count);
        Assert.Contains("A1", result);
        Assert.Contains("A2", result);
    }

    [Fact]
    public async Task ResolveAgents_Cumulative_Conv2_MultiAgPerSg_IntersectionApplied()
    {
        // SG2 has 2 AGs (AG2: A3,A4,A5 and AG3: A4,A5,A6)
        // ∩(AG2, AG3) = {A4, A5}
        // A3 is EXCLUDED (in AG2 only), A6 is EXCLUDED (in AG3 only)
        // Create a separate BU with only SG2
        _db.NgcBusinessUnitSupergroups.Add(
            new NgcBusinessUnitSupergroup { BusinessUnitId = 998, SupergroupId = Sg2Id, TenantId = TenantId }
        );
        await _db.SaveChangesAsync();

        var pgScope = ReportScope.Full();
        var result = await _resolver.ResolveAgentsAsync(TenantId, new[] { 998 }, AgentReportAxis.Cumulative, pgScope);

        Assert.Equal(2, result.Count);
        Assert.Contains("A4", result);
        Assert.Contains("A5", result);
        Assert.DoesNotContain("A3", result); // Not in both AGs
        Assert.DoesNotContain("A6", result); // Not in both AGs
    }

    [Fact]
    public async Task ResolveAgents_Cumulative_MultipleSgs_UnionOfIntersections()
    {
        // BU 100 has both SG1 and SG2
        // SG1 contributes: A1, A2 (∩ of one AG)
        // SG2 contributes: A4, A5 (∩ of AG2 and AG3)
        // Union: {A1, A2, A4, A5}
        var pgScope = ReportScope.Full();

        var result = await _resolver.ResolveAgentsAsync(TenantId, new[] { BuId }, AgentReportAxis.Cumulative, pgScope);

        Assert.Equal(4, result.Count);
        Assert.Contains("A1", result);
        Assert.Contains("A2", result);
        Assert.Contains("A4", result);
        Assert.Contains("A5", result);
        Assert.DoesNotContain("A3", result); // Excluded by SG2 intersection
        Assert.DoesNotContain("A6", result); // Excluded by SG2 intersection
    }

    #endregion

    #region PG-Intersection Tests (SF-BI-001)

    [Fact]
    public async Task ResolveAgents_PgIntersection_NarrowsDetailResult()
    {
        // PG allows only A1, A4, A5
        var pgScope = new ReportScope
        {
            FullScope = false,
            AllowedAgentExternalIds = new HashSet<string> { "A1", "A4", "A5" }
        };

        var result = await _resolver.ResolveAgentsAsync(TenantId, new[] { BuId }, AgentReportAxis.Detail, pgScope);

        Assert.Equal(3, result.Count);
        Assert.Contains("A1", result);
        Assert.Contains("A4", result);
        Assert.Contains("A5", result);
        Assert.DoesNotContain("A2", result); // Not in PG
        Assert.DoesNotContain("A3", result); // Not in PG
        Assert.DoesNotContain("A6", result); // Not in PG
    }

    [Fact]
    public async Task ResolveAgents_EmptyPg_ReturnsDeny()
    {
        var pgScope = new ReportScope
        {
            FullScope = false,
            AllowedAgentExternalIds = new HashSet<string>()
        };

        var result = await _resolver.ResolveAgentsAsync(TenantId, new[] { BuId }, AgentReportAxis.Detail, pgScope);

        Assert.Empty(result);
    }

    [Fact]
    public async Task ResolveAgents_Superadmin_FullScope_NoNarrowing()
    {
        var pgScope = ReportScope.Full();

        var result = await _resolver.ResolveAgentsAsync(TenantId, new[] { BuId }, AgentReportAxis.Detail, pgScope);

        // All 6 agents included
        Assert.Equal(6, result.Count);
    }

    #endregion

    #region Edge Cases

    [Fact]
    public async Task ResolveAgents_NoBusProvided_ReturnsEmpty()
    {
        var pgScope = ReportScope.Full();

        var result = await _resolver.ResolveAgentsAsync(TenantId, Array.Empty<int>(), AgentReportAxis.Detail, pgScope);

        Assert.Empty(result);
    }

    [Fact]
    public async Task ResolveAgents_BuWithNoSupergroups_ReturnsEmpty()
    {
        // BU 777 has no supergroup assignments
        var pgScope = ReportScope.Full();

        var result = await _resolver.ResolveAgentsAsync(TenantId, new[] { 777 }, AgentReportAxis.Detail, pgScope);

        Assert.Empty(result);
    }

    #endregion
}
