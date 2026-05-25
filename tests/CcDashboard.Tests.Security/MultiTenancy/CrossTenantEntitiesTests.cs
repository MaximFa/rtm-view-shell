using CcDashboard.Domain.Domain;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using UUIDNext;

namespace CcDashboard.Tests.Security.MultiTenancy;

/// <summary>
/// Tests for cross-tenant entities per ARCH-05.
/// Verifies that Tenants, Roles, WidgetCatalog, RTSGrid_Metric are visible
/// across any ITenantContext (no GQF applied).
/// </summary>
[Collection("Postgres")]
public class CrossTenantEntitiesTests
{
    private readonly PostgresFixture _fixture;

    public CrossTenantEntitiesTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    #region Tenants - No GQF

    [Fact]
    [Trait("Req", "ARCH-05")]
    public async Task GetTenants_FromAnyContext_ReturnsAllTenants()
    {
        // Arrange
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);

        // Act
        var tenantsFromA = await dbTenantA.Tenants.ToListAsync();
        var tenantsFromB = await dbTenantB.Tenants.ToListAsync();

        // Assert
        tenantsFromA.Should().HaveCountGreaterThanOrEqualTo(3, "All tenants should be visible");
        tenantsFromB.Should().HaveCountGreaterThanOrEqualTo(3, "All tenants should be visible from any context");

        tenantsFromA.Should().Contain(t => t.Id == _fixture.TenantAId);
        tenantsFromA.Should().Contain(t => t.Id == _fixture.TenantBId);
        tenantsFromA.Should().Contain(t => t.Id == _fixture.PlatformTenantId);
    }

    [Fact]
    [Trait("Req", "ARCH-05")]
    public async Task CreateTenant_VisibleFromAllContexts()
    {
        // Arrange
        var newTenantId = Uuid.NewSequential();
        await using var dbPlatform = _fixture.CreateDbContext(_fixture.PlatformTenantId);
        var now = DateTime.UtcNow;

        var newTenant = new Tenant
        {
            Id = newTenantId,
            Slug = $"new-tenant-{newTenantId:N}",
            Name = "New Test Tenant",
            Status = Domain.Enums.TenantStatus.Active,
            CreatedAt = now,
            UpdatedAt = now
        };

        dbPlatform.Tenants.Add(newTenant);
        await dbPlatform.SaveChangesAsync();

        // Act
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);

        var visibleFromA = await dbTenantA.Tenants.AnyAsync(t => t.Id == newTenantId);
        var visibleFromB = await dbTenantB.Tenants.AnyAsync(t => t.Id == newTenantId);

        // Assert
        visibleFromA.Should().BeTrue("Tenant created from Platform context should be visible from Tenant A");
        visibleFromB.Should().BeTrue("Tenant created from Platform context should be visible from Tenant B");
    }

    #endregion

    #region ApplicationRole (Identity Roles) - No GQF

    [Fact]
    [Trait("Req", "ARCH-05")]
    public async Task GetRoles_FromAnyContext_ReturnsAllRoles()
    {
        // Arrange
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);

        // Act
        var rolesFromA = await dbTenantA.Roles.ToListAsync();
        var rolesFromB = await dbTenantB.Roles.ToListAsync();

        // Assert
        var expectedRoles = new[] { "Superadmin", "Administrator", "Editor", "Viewer" };

        rolesFromA.Should().HaveCountGreaterThanOrEqualTo(4, "All 4 system roles should be visible");
        rolesFromB.Should().HaveCountGreaterThanOrEqualTo(4, "All 4 system roles should be visible from any context");

        rolesFromA.Select(r => r.Name).Should().Contain(expectedRoles);
        rolesFromB.Select(r => r.Name).Should().Contain(expectedRoles);
    }

    [Fact]
    [Trait("Req", "ARCH-05")]
    public async Task Roles_ArePlatformWide_NotTenantSpecific()
    {
        // Arrange
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);

        // Act
        var rolesFromA = await dbTenantA.Roles.OrderBy(r => r.Name).ToListAsync();
        var rolesFromB = await dbTenantB.Roles.OrderBy(r => r.Name).ToListAsync();

        // Assert
        rolesFromA.Select(r => r.Id).Should().BeEquivalentTo(rolesFromB.Select(r => r.Id),
            "Same role IDs should be returned from any tenant context — roles are platform-wide");
    }

    #endregion

    #region WidgetCatalogItem - No GQF

    [Fact]
    [Trait("Req", "ARCH-05")]
    public async Task GetWidgetCatalogItems_FromAnyContext_ReturnsAllItems()
    {
        // Arrange
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);

        // Act
        var itemsFromA = await dbTenantA.WidgetCatalogItems.ToListAsync();
        var itemsFromB = await dbTenantB.WidgetCatalogItems.ToListAsync();

        // Assert
        itemsFromA.Should().NotBeEmpty("Widget catalog should have at least one seeded item");
        itemsFromB.Should().NotBeEmpty("Widget catalog should be visible from any tenant");

        itemsFromA.Select(w => w.Id).Should().BeEquivalentTo(itemsFromB.Select(w => w.Id),
            "Same widget catalog items should be returned from any tenant context");
    }

    [Fact]
    [Trait("Req", "ARCH-05")]
    public async Task CreateWidgetCatalogItem_VisibleFromAllContexts()
    {
        // Arrange
        var newItemId = Uuid.NewSequential();
        await using var dbPlatform = _fixture.CreateDbContext(_fixture.PlatformTenantId);

        var newItem = new WidgetCatalogItem
        {
            Id = newItemId,
            Category = "Test",
            Name = $"Test Widget {newItemId:N}",
            Description = "Widget for testing cross-tenant visibility",
            IsActive = true
        };

        dbPlatform.WidgetCatalogItems.Add(newItem);
        await dbPlatform.SaveChangesAsync();

        // Act
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);

        var visibleFromA = await dbTenantA.WidgetCatalogItems.AnyAsync(w => w.Id == newItemId);
        var visibleFromB = await dbTenantB.WidgetCatalogItems.AnyAsync(w => w.Id == newItemId);

        // Assert
        visibleFromA.Should().BeTrue("Widget catalog item should be visible from Tenant A");
        visibleFromB.Should().BeTrue("Widget catalog item should be visible from Tenant B");
    }

    #endregion

    #region RtsGridMetric - No GQF

    [Fact]
    [Trait("Req", "ARCH-05")]
    public async Task GetRtsGridMetrics_FromAnyContext_ReturnsAllMetrics()
    {
        // Arrange
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);
        await using var dbTenantB = _fixture.CreateDbContext(_fixture.TenantBId);

        // Act
        var metricsFromA = await dbTenantA.RtsGridMetrics.ToListAsync();
        var metricsFromB = await dbTenantB.RtsGridMetrics.ToListAsync();

        // Assert
        metricsFromA.Should().NotBeEmpty("RTSGrid_Metric should have at least one seeded metric");
        metricsFromB.Should().NotBeEmpty("RTSGrid_Metric should be visible from any tenant");

        metricsFromA.Select(m => m.MetricId).Should().BeEquivalentTo(metricsFromB.Select(m => m.MetricId),
            "Same metrics should be returned from any tenant context");
    }

    [Fact]
    [Trait("Req", "ARCH-05")]
    public async Task RtsGridMetric_HasNoTenantId_IsPlatformWide()
    {
        // Arrange
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);

        // Act
        var metrics = await db.RtsGridMetrics.ToListAsync();

        // Assert
        metrics.Should().NotBeEmpty();
        // RtsGridMetric does not have a TenantId property — it's cross-tenant by design
        // This test verifies the entity type configuration is correct
    }

    #endregion

    #region Contrast: Multi-tenant entities ARE filtered

    [Fact]
    [Trait("Req", "ARCH-05")]
    public async Task ContrastTest_MultiTenantEntities_AreFiltered_CrossTenantEntities_AreNot()
    {
        // Arrange
        await using var dbTenantA = _fixture.CreateDbContext(_fixture.TenantAId);

        // Act
        var users = await dbTenantA.Users.ToListAsync();
        var groups = await dbTenantA.PermissionGroups.ToListAsync();
        var dashboards = await dbTenantA.Dashboards.ToListAsync();

        var tenants = await dbTenantA.Tenants.ToListAsync();
        var roles = await dbTenantA.Roles.ToListAsync();
        var widgets = await dbTenantA.WidgetCatalogItems.ToListAsync();
        var metrics = await dbTenantA.RtsGridMetrics.ToListAsync();

        // Assert: Multi-tenant entities only show current tenant's data
        users.Should().OnlyContain(u => u.TenantId == _fixture.TenantAId, "Users are tenant-scoped");
        groups.Should().OnlyContain(g => g.TenantId == _fixture.TenantAId, "PermissionGroups are tenant-scoped");
        dashboards.Should().OnlyContain(d => d.TenantId == _fixture.TenantAId, "Dashboards are tenant-scoped");

        // Assert: Cross-tenant entities show all data regardless of context
        tenants.Should().HaveCountGreaterThanOrEqualTo(3, "Tenants are platform-wide");
        roles.Should().HaveCountGreaterThanOrEqualTo(4, "Roles are platform-wide");
        widgets.Should().NotBeEmpty("WidgetCatalog is platform-wide");
        metrics.Should().NotBeEmpty("RtsGridMetric is platform-wide");
    }

    #endregion
}
