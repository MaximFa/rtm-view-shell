using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Queries.Widgets;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using NSubstitute;
using UUIDNext;

namespace CcDashboard.Tests.Security.Widgets;

/// <summary>
/// Tests for Widget Catalogue access control and cross-tenant visibility (WGT-01..03).
/// </summary>
[Collection("Postgres")]
public class WidgetCatalogTests(PostgresFixture postgres)
{
    // ── WGT-01: Widget catalogue is cross-tenant (no GQF) ────────────────────────

    [Fact]
    [Trait("Req", "WGT-01")]
    public async Task WidgetCatalogItem_SeededOnce_VisibleFromAnyTenant()
    {
        // Arrange: Seed a widget catalog item (no TenantId)
        await using var dbPlatform = postgres.CreateDbContext(postgres.PlatformTenantId);
        var itemId = Uuid.NewSequential();
        dbPlatform.WidgetCatalogItems.Add(new WidgetCatalogItem
        {
            Id = itemId,
            Category = "Test",
            Name = "Cross-Tenant Widget",
            Description = "Visible to all",
            IsActive = true
        });
        await dbPlatform.SaveChangesAsync();

        // Act: Query from tenant A context
        await using var dbA = postgres.CreateDbContext(postgres.TenantAId);
        var fromA = await dbA.WidgetCatalogItems.FirstOrDefaultAsync(w => w.Id == itemId);

        // Act: Query from tenant B context
        await using var dbB = postgres.CreateDbContext(postgres.TenantBId);
        var fromB = await dbB.WidgetCatalogItems.FirstOrDefaultAsync(w => w.Id == itemId);

        // Assert: Both tenants see the same item
        fromA.Should().NotBeNull();
        fromB.Should().NotBeNull();
        fromA!.Name.Should().Be("Cross-Tenant Widget");
        fromB!.Name.Should().Be("Cross-Tenant Widget");
    }

    [Fact]
    [Trait("Req", "WGT-01")]
    public async Task WidgetCatalogItem_NoTenantId_NoGqfApplied()
    {
        // Arrange: Seed multiple items from different contexts
        await using var dbA = postgres.CreateDbContext(postgres.TenantAId);
        var itemA = new WidgetCatalogItem
        {
            Id = Uuid.NewSequential(),
            Category = "Agents",
            Name = "Seeded From A",
            IsActive = true
        };
        dbA.WidgetCatalogItems.Add(itemA);
        await dbA.SaveChangesAsync();

        await using var dbB = postgres.CreateDbContext(postgres.TenantBId);
        var itemB = new WidgetCatalogItem
        {
            Id = Uuid.NewSequential(),
            Category = "Queues",
            Name = "Seeded From B",
            IsActive = true
        };
        dbB.WidgetCatalogItems.Add(itemB);
        await dbB.SaveChangesAsync();

        // Act: Count all items from each tenant context
        await using var dbCheck = postgres.CreateDbContext(postgres.TenantAId);
        var allItems = await dbCheck.WidgetCatalogItems.ToListAsync();

        // Assert: Both items are visible (no tenant filtering)
        allItems.Should().Contain(i => i.Name == "Seeded From A");
        allItems.Should().Contain(i => i.Name == "Seeded From B");
    }

    [Fact]
    [Trait("Req", "WGT-01")]
    public async Task WidgetCatalogItem_PlatformWide_AllCategoriesVisible()
    {
        // Arrange: Seed items in different categories
        await using var db = postgres.CreateDbContext(postgres.PlatformTenantId);
        var categories = new[] { "Agents-T5", "Queues-T5", "General-T5" };
        foreach (var cat in categories)
        {
            db.WidgetCatalogItems.Add(new WidgetCatalogItem
            {
                Id = Uuid.NewSequential(),
                Category = cat,
                Name = $"Widget in {cat}",
                IsActive = true
            });
        }
        await db.SaveChangesAsync();

        // Act: Query from tenant A
        await using var dbA = postgres.CreateDbContext(postgres.TenantAId);
        var visibleCategories = await dbA.WidgetCatalogItems
            .Where(w => w.Category.EndsWith("-T5"))
            .Select(w => w.Category)
            .Distinct()
            .ToListAsync();

        // Assert: All categories visible
        visibleCategories.Should().BeEquivalentTo(categories);
    }

    // ── WGT-02/03: Access control ────────────────────────────────────────────────

    [Fact]
    [Trait("Req", "WGT-02")]
    public async Task GetWidgetCatalog_EditorRole_SeesActiveItemsOnly()
    {
        // Arrange
        var userAccessor = CreateUserAccessor("Editor", postgres.TenantAId);
        var repo = CreateWidgetCatalogRepository();

        // Seed active and inactive items
        await using var db = postgres.CreateDbContext(postgres.PlatformTenantId);
        var activeId = Uuid.NewSequential();
        var inactiveId = Uuid.NewSequential();
        db.WidgetCatalogItems.AddRange(
            new WidgetCatalogItem { Id = activeId, Category = "WGT02-Test", Name = "Active Widget", IsActive = true },
            new WidgetCatalogItem { Id = inactiveId, Category = "WGT02-Test", Name = "Inactive Widget", IsActive = false }
        );
        await db.SaveChangesAsync();

        var handler = new GetWidgetCatalogQueryHandler(repo, userAccessor);

        // Act
        var result = await handler.Handle(new GetWidgetCatalogQuery(IncludeInactive: false), CancellationToken.None);

        // Assert: Only active items returned
        var allItems = result.SelectMany(c => c.Items).ToList();
        allItems.Should().Contain(i => i.Name == "Active Widget");
        allItems.Should().NotContain(i => i.Name == "Inactive Widget");
    }

    [Fact]
    [Trait("Req", "WGT-03")]
    public async Task GetWidgetCatalog_SuperadminWithIncludeInactive_SeesAllItems()
    {
        // Arrange
        var userAccessor = CreateUserAccessor("Superadmin", postgres.PlatformTenantId);
        var repo = CreateWidgetCatalogRepository();

        // Seed active and inactive items
        await using var db = postgres.CreateDbContext(postgres.PlatformTenantId);
        var activeId = Uuid.NewSequential();
        var inactiveId = Uuid.NewSequential();
        db.WidgetCatalogItems.AddRange(
            new WidgetCatalogItem { Id = activeId, Category = "WGT03-Test", Name = "SA-Active", IsActive = true },
            new WidgetCatalogItem { Id = inactiveId, Category = "WGT03-Test", Name = "SA-Inactive", IsActive = false }
        );
        await db.SaveChangesAsync();

        var handler = new GetWidgetCatalogQueryHandler(repo, userAccessor);

        // Act
        var result = await handler.Handle(new GetWidgetCatalogQuery(IncludeInactive: true), CancellationToken.None);

        // Assert: Both active and inactive items returned
        var wgt03Items = result
            .Where(c => c.Category == "WGT03-Test")
            .SelectMany(c => c.Items)
            .ToList();
        wgt03Items.Should().Contain(i => i.Name == "SA-Active");
        wgt03Items.Should().Contain(i => i.Name == "SA-Inactive");
    }

    [Fact]
    [Trait("Req", "WGT-03")]
    public async Task GetWidgetCatalog_NonSuperadminWithIncludeInactive_StillFiltersInactive()
    {
        // Arrange: Non-Superadmin trying to see inactive items
        var userAccessor = CreateUserAccessor("Administrator", postgres.TenantAId);
        var repo = CreateWidgetCatalogRepository();

        // Seed inactive item
        await using var db = postgres.CreateDbContext(postgres.PlatformTenantId);
        var inactiveId = Uuid.NewSequential();
        db.WidgetCatalogItems.Add(new WidgetCatalogItem
        {
            Id = inactiveId,
            Category = "WGT03-NonSA",
            Name = "Hidden-From-Admin",
            IsActive = false
        });
        await db.SaveChangesAsync();

        var handler = new GetWidgetCatalogQueryHandler(repo, userAccessor);

        // Act: Request with IncludeInactive=true (should be ignored for non-Superadmin)
        var result = await handler.Handle(new GetWidgetCatalogQuery(IncludeInactive: true), CancellationToken.None);

        // Assert: Inactive item NOT returned
        var allItems = result.SelectMany(c => c.Items).ToList();
        allItems.Should().NotContain(i => i.Name == "Hidden-From-Admin");
    }

    // ── Helper methods ───────────────────────────────────────────────────────────

    private static ICurrentUserAccessor CreateUserAccessor(string role, Guid tenantId)
    {
        var accessor = Substitute.For<ICurrentUserAccessor>();
        accessor.TenantId.Returns(tenantId);
        accessor.UserId.Returns(Guid.NewGuid());
        accessor.UserName.Returns("test-user");
        accessor.Role.Returns(role);
        accessor.IsAuthenticated.Returns(true);
        return accessor;
    }

    private IWidgetCatalogRepository CreateWidgetCatalogRepository()
    {
        var db = postgres.CreateDbContext(postgres.PlatformTenantId);
        return new TestWidgetCatalogRepository(db);
    }

    private class TestWidgetCatalogRepository(CcDashboard.Infrastructure.Persistence.AppDbContext db) : IWidgetCatalogRepository
    {
        public async Task<IReadOnlyList<WidgetCatalogItem>> GetAllAsync(CancellationToken ct = default)
            => await db.WidgetCatalogItems.AsNoTracking().ToListAsync(ct);

        public async Task<IReadOnlyList<WidgetCatalogItem>> GetAllActiveAsync(CancellationToken ct = default)
            => await db.WidgetCatalogItems.AsNoTracking().Where(i => i.IsActive).ToListAsync(ct);

        public async Task<WidgetCatalogItem?> GetByIdAsync(Guid id, CancellationToken ct = default)
            => await db.WidgetCatalogItems.FirstOrDefaultAsync(i => i.Id == id, ct);

        public Task AddAsync(WidgetCatalogItem item, CancellationToken ct = default)
        {
            db.WidgetCatalogItems.Add(item);
            return db.SaveChangesAsync(ct);
        }

        public void Update(WidgetCatalogItem item)
        {
            db.WidgetCatalogItems.Update(item);
        }
    }
}
