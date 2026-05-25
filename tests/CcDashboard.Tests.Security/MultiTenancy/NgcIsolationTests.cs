using CcDashboard.Domain.Domain;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Tests.Security.MultiTenancy;

/// <summary>
/// Tests for NGC entity isolation via Global Query Filters (ARCH-01).
/// Uses BeDb (BackendEmulationDbContext) for seeding, AppDbContext for GQF assertion.
/// </summary>
[Collection("Postgres")]
public class NgcIsolationTests(PostgresFixture postgres)
{
    // ── DoD-2: NGC entity GQF isolation ──────────────────────────────────────

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task NgcSite_SeededInTenantA_NotVisibleInTenantB()
    {
        // Arrange: Seed via BeDb (no GQF)
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var siteA = new NgcSite { SiteId = $"SITE-A-{Guid.NewGuid():N}", TenantId = postgres.TenantAId, SiteName = "Site A" };
        var siteB = new NgcSite { SiteId = $"SITE-B-{Guid.NewGuid():N}", TenantId = postgres.TenantBId, SiteName = "Site B" };
        beDb.NgcSites.AddRange(siteA, siteB);
        await beDb.SaveChangesAsync();

        // Act: Query via AppDbContext with tenant A context
        await using var dbA = postgres.CreateDbContext(postgres.TenantAId);
        var sitesA = await dbA.NgcSites.ToListAsync();

        // Assert: Only site A visible
        sitesA.Should().ContainSingle(s => s.SiteId == siteA.SiteId);
        sitesA.Should().NotContain(s => s.SiteId == siteB.SiteId);
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task NgcBusinessUnit_SeededInTenantA_NotVisibleInTenantB()
    {
        // Arrange
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var buA = new NgcBusinessUnit { TenantId = postgres.TenantAId, BusinessUnitName = "BU-A" };
        var buB = new NgcBusinessUnit { TenantId = postgres.TenantBId, BusinessUnitName = "BU-B" };
        beDb.NgcBusinessUnits.AddRange(buA, buB);
        await beDb.SaveChangesAsync();

        // Act
        await using var dbB = postgres.CreateDbContext(postgres.TenantBId);
        var unitsB = await dbB.NgcBusinessUnits.ToListAsync();

        // Assert: Only BU-B visible in tenant B context
        unitsB.Should().Contain(u => u.BusinessUnitName == "BU-B");
        unitsB.Should().NotContain(u => u.BusinessUnitName == "BU-A");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task NgcSupergroup_SeededInTenantA_NotVisibleInTenantB()
    {
        // Arrange
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var sgA = new NgcSupergroup { TenantId = postgres.TenantAId, SupergroupName = "SG-A" };
        var sgB = new NgcSupergroup { TenantId = postgres.TenantBId, SupergroupName = "SG-B" };
        beDb.NgcSupergroups.AddRange(sgA, sgB);
        await beDb.SaveChangesAsync();

        // Act
        await using var dbB = postgres.CreateDbContext(postgres.TenantBId);
        var groupsB = await dbB.NgcSupergroups.ToListAsync();

        // Assert
        groupsB.Should().Contain(g => g.SupergroupName == "SG-B");
        groupsB.Should().NotContain(g => g.SupergroupName == "SG-A");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task NgcQueue_SeededInTenantA_NotVisibleInTenantB()
    {
        // Arrange
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var queueA = new NgcQueue { Id = Guid.NewGuid(), TenantId = postgres.TenantAId, ExternalId = "Q-A", Name = "Queue A", IsActive = true };
        var queueB = new NgcQueue { Id = Guid.NewGuid(), TenantId = postgres.TenantBId, ExternalId = "Q-B", Name = "Queue B", IsActive = true };
        beDb.NgcQueues.AddRange(queueA, queueB);
        await beDb.SaveChangesAsync();

        // Act
        await using var dbA = postgres.CreateDbContext(postgres.TenantAId);
        var queuesA = await dbA.NgcQueues.ToListAsync();

        // Assert
        queuesA.Should().Contain(q => q.Name == "Queue A");
        queuesA.Should().NotContain(q => q.Name == "Queue B");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task NgcAgentGroup_SeededInTenantA_NotVisibleInTenantB()
    {
        // Arrange
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var agA = new NgcAgentGroup { Id = Guid.NewGuid(), TenantId = postgres.TenantAId, ExternalId = "AG-A", Name = "AgentGroup A", IsActive = true };
        var agB = new NgcAgentGroup { Id = Guid.NewGuid(), TenantId = postgres.TenantBId, ExternalId = "AG-B", Name = "AgentGroup B", IsActive = true };
        beDb.NgcAgentGroups.AddRange(agA, agB);
        await beDb.SaveChangesAsync();

        // Act
        await using var dbB = postgres.CreateDbContext(postgres.TenantBId);
        var groupsB = await dbB.NgcAgentGroups.ToListAsync();

        // Assert
        groupsB.Should().Contain(g => g.Name == "AgentGroup B");
        groupsB.Should().NotContain(g => g.Name == "AgentGroup A");
    }

    // ── DoD-3: NGC junction table GQF isolation ──────────────────────────────

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task NgcSupergroupAgentgroup_SeededInTenantA_NotVisibleInTenantB()
    {
        // Arrange: Create supergroup first
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var sg = new NgcSupergroup { TenantId = postgres.TenantAId, SupergroupName = "SG-Junction-Test" };
        beDb.NgcSupergroups.Add(sg);
        await beDb.SaveChangesAsync();

        var junctionA = new NgcSupergroupAgentgroup
        {
            SupergroupId = sg.SupergroupId,
            AgentgroupId = "AG-JUNCTION-A",
            TenantId = postgres.TenantAId
        };
        var junctionB = new NgcSupergroupAgentgroup
        {
            SupergroupId = sg.SupergroupId,
            AgentgroupId = "AG-JUNCTION-B",
            TenantId = postgres.TenantBId
        };
        beDb.NgcSupergroupAgentgroups.AddRange(junctionA, junctionB);
        await beDb.SaveChangesAsync();

        // Act
        await using var dbA = postgres.CreateDbContext(postgres.TenantAId);
        var junctionsA = await dbA.NgcSupergroupAgentgroups.ToListAsync();

        // Assert: Only junction A visible
        junctionsA.Should().Contain(j => j.AgentgroupId == "AG-JUNCTION-A");
        junctionsA.Should().NotContain(j => j.AgentgroupId == "AG-JUNCTION-B");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task NgcBusinessUnitQueueClassification_SeededInTenantA_NotVisibleInTenantB()
    {
        // Arrange: Create business unit first
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var bu = new NgcBusinessUnit { TenantId = postgres.TenantAId, BusinessUnitName = "BU-Queue-Test" };
        beDb.NgcBusinessUnits.Add(bu);
        await beDb.SaveChangesAsync();

        var classA = new NgcBusinessUnitQueueClassification
        {
            BusinessUnitId = bu.BusinessUnitId,
            QueueId = "QUEUE-CLASS-A",
            TenantId = postgres.TenantAId
        };
        var classB = new NgcBusinessUnitQueueClassification
        {
            BusinessUnitId = bu.BusinessUnitId,
            QueueId = "QUEUE-CLASS-B",
            TenantId = postgres.TenantBId
        };
        beDb.NgcBusinessUnitQueueClassifications.AddRange(classA, classB);
        await beDb.SaveChangesAsync();

        // Act
        await using var dbB = postgres.CreateDbContext(postgres.TenantBId);
        var classificationsB = await dbB.NgcBusinessUnitQueueClassifications.ToListAsync();

        // Assert: Only classification B visible
        classificationsB.Should().Contain(c => c.QueueId == "QUEUE-CLASS-B");
        classificationsB.Should().NotContain(c => c.QueueId == "QUEUE-CLASS-A");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task NgcBusinessUnitSupergroup_SeededInTenantA_NotVisibleInTenantB()
    {
        // Arrange: Create separate BU/SG pairs for each tenant (PK is BU_ID+SG_ID)
        int buIdA, sgIdA, buIdB, sgIdB;
        await using (var beDb = postgres.CreateBackendEmulationDbContext())
        {
            var buA = new NgcBusinessUnit { TenantId = postgres.TenantAId, BusinessUnitName = "BU-SG-Test-A" };
            var sgA = new NgcSupergroup { TenantId = postgres.TenantAId, SupergroupName = "SG-BU-Test-A" };
            var buB = new NgcBusinessUnit { TenantId = postgres.TenantBId, BusinessUnitName = "BU-SG-Test-B" };
            var sgB = new NgcSupergroup { TenantId = postgres.TenantBId, SupergroupName = "SG-BU-Test-B" };
            beDb.NgcBusinessUnits.AddRange(buA, buB);
            beDb.NgcSupergroups.AddRange(sgA, sgB);
            await beDb.SaveChangesAsync();
            buIdA = buA.BusinessUnitId;
            sgIdA = sgA.SupergroupId;
            buIdB = buB.BusinessUnitId;
            sgIdB = sgB.SupergroupId;
        }

        // Seed junction records in a fresh context
        await using (var beDb2 = postgres.CreateBackendEmulationDbContext())
        {
            var linkA = new NgcBusinessUnitSupergroup
            {
                BusinessUnitId = buIdA,
                SupergroupId = sgIdA,
                TenantId = postgres.TenantAId
            };
            var linkB = new NgcBusinessUnitSupergroup
            {
                BusinessUnitId = buIdB,
                SupergroupId = sgIdB,
                TenantId = postgres.TenantBId
            };
            beDb2.NgcBusinessUnitSupergroups.AddRange(linkA, linkB);
            await beDb2.SaveChangesAsync();
        }

        // Act
        await using var dbA = postgres.CreateDbContext(postgres.TenantAId);
        var linksA = await dbA.NgcBusinessUnitSupergroups.ToListAsync();

        // Assert: Only link A visible
        linksA.Should().Contain(l => l.TenantId == postgres.TenantAId);
        linksA.Should().NotContain(l => l.TenantId == postgres.TenantBId);
    }
}
