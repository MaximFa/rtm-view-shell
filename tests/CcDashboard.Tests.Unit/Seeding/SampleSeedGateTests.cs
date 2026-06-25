using CcDashboard.Domain.Domain;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Seeding;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Tests.Unit.Seeding;

public class SampleSeedGateTests : IDisposable
{
    private readonly BackendEmulationDbContext _db;
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid OtherTenantId = Guid.NewGuid();

    public SampleSeedGateTests()
    {
        var options = new DbContextOptionsBuilder<BackendEmulationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _db = new BackendEmulationDbContext(options);
    }

    public void Dispose()
    {
        _db.Dispose();
        GC.SuppressFinalize(this);
    }

    [Fact]
    public async Task ShouldSeed_FlagFalse_EmptyDb_ReturnsFalse()
    {
        // Primary gate: flag off -> never seed sample
        var result = await SampleSeedGate.ShouldSeedAsync(false, _db, TenantId, CancellationToken.None);
        result.Should().BeFalse("flag is off — primary gate blocks seed");
    }

    [Fact]
    public async Task ShouldSeed_FlagTrue_EmptyDb_ReturnsTrue()
    {
        // Normal dev scenario: flag on + no data -> seed
        var result = await SampleSeedGate.ShouldSeedAsync(true, _db, TenantId, CancellationToken.None);
        result.Should().BeTrue("flag is on and no CC data exists for tenant");
    }

    [Fact]
    public async Task ShouldSeed_FlagTrue_HasNgcQueue_ReturnsFalse()
    {
        // Data-presence belt: real queue exists -> skip
        _db.NgcQueues.Add(new NgcQueue { Id = Guid.NewGuid(), TenantId = TenantId, ExternalId = "Q001", Name = "Sales" });
        await _db.SaveChangesAsync();

        var result = await SampleSeedGate.ShouldSeedAsync(true, _db, TenantId, CancellationToken.None);
        result.Should().BeFalse("real CC data (NgcQueue) exists for tenant — belt blocks seed");
    }

    [Fact]
    public async Task ShouldSeed_FlagTrue_HasNgcSite_NotSite001_ReturnsFalse()
    {
        // SITE001 probe removal guard: any site for tenant blocks seed, not just "SITE001"
        _db.NgcSites.Add(new NgcSite { SiteId = "IL", TenantId = TenantId, SiteName = "Israel Site" });
        await _db.SaveChangesAsync();

        var result = await SampleSeedGate.ShouldSeedAsync(true, _db, TenantId, CancellationToken.None);
        result.Should().BeFalse("real CC data (NgcSite with non-SITE001 id) exists for tenant — belt blocks seed");
    }

    [Fact]
    public async Task ShouldSeed_FlagFalse_HasData_ReturnsFalse()
    {
        // Flag off overrides everything
        _db.NgcQueues.Add(new NgcQueue { Id = Guid.NewGuid(), TenantId = TenantId, ExternalId = "Q001", Name = "Sales" });
        await _db.SaveChangesAsync();

        var result = await SampleSeedGate.ShouldSeedAsync(false, _db, TenantId, CancellationToken.None);
        result.Should().BeFalse("flag is off — primary gate blocks seed regardless of data presence");
    }

    [Fact]
    public async Task ShouldSeed_FlagTrue_DataForDifferentTenant_ReturnsTrue()
    {
        // Per-tenant check: data for DIFFERENT tenant does NOT block seed for OUR tenant
        // (FORK2=2.4b: prod data re-stamped to OUR tenant, so a foreign-tenant row must NOT block)
        _db.NgcQueues.Add(new NgcQueue { Id = Guid.NewGuid(), TenantId = OtherTenantId, ExternalId = "Q001", Name = "Sales" });
        _db.NgcSites.Add(new NgcSite { SiteId = "IL", TenantId = OtherTenantId, SiteName = "Israel Site" });
        _db.NgcBusinessUnits.Add(new NgcBusinessUnit { TenantId = OtherTenantId, BusinessUnitName = "Sales Dept" });
        await _db.SaveChangesAsync();

        var result = await SampleSeedGate.ShouldSeedAsync(true, _db, TenantId, CancellationToken.None);
        result.Should().BeTrue("CC data exists for a different tenant, not the target tenant — seed should proceed");
    }
}
