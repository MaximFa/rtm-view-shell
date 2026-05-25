using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Security.Authentication;

/// <summary>
/// Tests for cross-tenant write protection (ARCH-01 + PG-04).
/// Verifies that user from tenant A cannot update/delete entities belonging to tenant B.
/// </summary>
[Collection("Postgres")]
public class ConfigWriteProtectionTests(PostgresFixture postgres)
{
    // ── SaveSiteCommand ──────────────────────────────────────────────────────────

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task SaveSiteCommand_UpdateSiteInOtherTenant_ReturnsNotFound()
    {
        // Arrange: Create site in tenant B
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var siteId = $"SITE-B-{Guid.NewGuid():N}";
        beDb.NgcSites.Add(new NgcSite
        {
            SiteId = siteId,
            TenantId = postgres.TenantBId,
            SiteName = "Site in Tenant B"
        });
        await beDb.SaveChangesAsync();

        // User from tenant A tries to update site in tenant B
        var userAccessor = CreateUserAccessor(postgres.TenantAId);
        var repo = CreateSiteRepository(postgres.TenantAId);
        var apiHook = Substitute.For<IConfigurationApiHook>();

        var handler = new SaveSiteCommandHandler(repo, userAccessor, apiHook);
        var command = new SaveSiteCommand(new SaveSiteRequest(
            SiteId: siteId,
            SiteName: "Hijacked Site",
            Description: null,
            TimeZone: null,
            ClearTime: null,
            IsNew: false));

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert: Should fail because site belongs to tenant B
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task DeleteSiteCommand_DeleteSiteInOtherTenant_ReturnsNotFound()
    {
        // Arrange: Create site in tenant B
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var siteId = $"SITE-DEL-{Guid.NewGuid():N}";
        beDb.NgcSites.Add(new NgcSite
        {
            SiteId = siteId,
            TenantId = postgres.TenantBId,
            SiteName = "Site to Delete"
        });
        await beDb.SaveChangesAsync();

        // User from tenant A tries to delete site in tenant B
        var userAccessor = CreateUserAccessor(postgres.TenantAId);
        var repo = CreateSiteRepository(postgres.TenantAId);

        var handler = new DeleteSiteCommandHandler(repo, userAccessor);
        var command = new DeleteSiteCommand(siteId);

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    // ── SaveBusinessUnitCommand ──────────────────────────────────────────────────

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task SaveBusinessUnitCommand_UpdateBuInOtherTenant_ReturnsNotFound()
    {
        // Arrange: Create BU in tenant B
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var bu = new NgcBusinessUnit
        {
            TenantId = postgres.TenantBId,
            BusinessUnitName = "BU in Tenant B",
            CreatedDatetime = DateTime.UtcNow,
            CreatedBy = "test"
        };
        beDb.NgcBusinessUnits.Add(bu);
        await beDb.SaveChangesAsync();
        var buId = bu.BusinessUnitId;

        // User from tenant A tries to update BU in tenant B
        var userAccessor = CreateUserAccessor(postgres.TenantAId);
        var repo = CreateBuRepository(postgres.TenantAId);
        var clock = new TestDateTimeProvider();
        var apiHook = Substitute.For<IConfigurationApiHook>();

        var handler = new SaveBusinessUnitCommandHandler(repo, userAccessor, clock, apiHook);
        var command = new SaveBusinessUnitCommand(new SaveBusinessUnitRequest(
            BusinessUnitId: buId,
            BusinessUnitName: "Hijacked BU",
            Description: null,
            SiteId: null,
            QueueIds: [],
            SupergroupIds: []));

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task DeleteBusinessUnitCommand_DeleteBuInOtherTenant_ReturnsNotFound()
    {
        // Arrange: Create BU in tenant B
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var bu = new NgcBusinessUnit
        {
            TenantId = postgres.TenantBId,
            BusinessUnitName = "BU to Delete",
            CreatedDatetime = DateTime.UtcNow,
            CreatedBy = "test"
        };
        beDb.NgcBusinessUnits.Add(bu);
        await beDb.SaveChangesAsync();
        var buId = bu.BusinessUnitId;

        // User from tenant A tries to delete BU in tenant B
        var userAccessor = CreateUserAccessor(postgres.TenantAId);
        var repo = CreateBuRepository(postgres.TenantAId);

        var handler = new DeleteBusinessUnitCommandHandler(repo, userAccessor);
        var command = new DeleteBusinessUnitCommand(buId);

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    // ── SaveSupergroupCommand ────────────────────────────────────────────────────

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task SaveSupergroupCommand_UpdateSgInOtherTenant_ReturnsNotFound()
    {
        // Arrange: Create supergroup in tenant B
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var sg = new NgcSupergroup
        {
            TenantId = postgres.TenantBId,
            SupergroupName = "SG in Tenant B",
            CreatedDatetime = DateTime.UtcNow,
            CreatedBy = "test"
        };
        beDb.NgcSupergroups.Add(sg);
        await beDb.SaveChangesAsync();
        var sgId = sg.SupergroupId;

        // User from tenant A tries to update supergroup in tenant B
        var userAccessor = CreateUserAccessor(postgres.TenantAId);
        var repo = CreateSgRepository(postgres.TenantAId);
        var clock = new TestDateTimeProvider();
        var apiHook = Substitute.For<IConfigurationApiHook>();

        var handler = new SaveSupergroupCommandHandler(repo, userAccessor, clock, apiHook);
        var command = new SaveSupergroupCommand(new SaveSupergroupRequest(
            SupergroupId: sgId,
            SupergroupName: "Hijacked SG",
            Description: null,
            AgentGroupIds: []));

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task DeleteSupergroupCommand_DeleteSgInOtherTenant_ReturnsNotFound()
    {
        // Arrange: Create supergroup in tenant B
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var sg = new NgcSupergroup
        {
            TenantId = postgres.TenantBId,
            SupergroupName = "SG to Delete",
            CreatedDatetime = DateTime.UtcNow,
            CreatedBy = "test"
        };
        beDb.NgcSupergroups.Add(sg);
        await beDb.SaveChangesAsync();
        var sgId = sg.SupergroupId;

        // User from tenant A tries to delete supergroup in tenant B
        var userAccessor = CreateUserAccessor(postgres.TenantAId);
        var repo = CreateSgRepository(postgres.TenantAId);

        var handler = new DeleteSupergroupCommandHandler(repo, userAccessor);
        var command = new DeleteSupergroupCommand(sgId);

        // Act
        var result = await handler.Handle(command, CancellationToken.None);

        // Assert
        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    // ── Helper methods ───────────────────────────────────────────────────────────

    private static ICurrentUserAccessor CreateUserAccessor(Guid tenantId)
    {
        var accessor = Substitute.For<ICurrentUserAccessor>();
        accessor.TenantId.Returns(tenantId);
        accessor.UserId.Returns(Guid.NewGuid());
        accessor.UserName.Returns("test-user");
        accessor.Role.Returns("Editor");
        accessor.IsAuthenticated.Returns(true);
        return accessor;
    }

    private INgcSiteRepository CreateSiteRepository(Guid tenantId)
    {
        var db = postgres.CreateDbContext(tenantId);
        return new NgcSiteRepository(postgres.CreateBackendEmulationDbContext());
    }

    private INgcBusinessUnitRepository CreateBuRepository(Guid tenantId)
    {
        var db = postgres.CreateDbContext(tenantId);
        return new NgcBusinessUnitRepository(postgres.CreateBackendEmulationDbContext());
    }

    private INgcSupergroupRepository CreateSgRepository(Guid tenantId)
    {
        var db = postgres.CreateDbContext(tenantId);
        return new NgcSupergroupRepository(postgres.CreateBackendEmulationDbContext());
    }
}
