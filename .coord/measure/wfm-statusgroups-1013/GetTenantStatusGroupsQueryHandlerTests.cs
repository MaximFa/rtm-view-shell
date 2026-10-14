using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Queries.TenantSettings;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Security.Authorization;

/// <summary>
/// GetTenantStatusGroupsQuery — the source list for the WFM serving-groups setting.
/// The tenant gate is the point of these tests: the list feeds a settings dropdown, so leaking
/// another tenant's group names would leak their platform configuration.
/// </summary>
[Collection("Postgres")]
public class GetTenantStatusGroupsQueryHandlerTests(PostgresFixture postgres)
{
    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task ReturnsOnlyOwnTenantGroups_AndNotTheOtherTenants()
    {
        // Arrange — two tenants, disjoint group sets, so a leak is visible by name
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var mine  = $"MINE-{Guid.NewGuid():N}".ToUpperInvariant();
        var yours = $"YOURS-{Guid.NewGuid():N}".ToUpperInvariant();
        beDb.RtsDataUserStatuses.Add(NewStatus(postgres.TenantAId, mine));
        beDb.RtsDataUserStatuses.Add(NewStatus(postgres.TenantBId, yours));
        await beDb.SaveChangesAsync();

        var handler = CreateHandler(postgres.TenantAId);

        // Act
        var result = await handler.Handle(new GetTenantStatusGroupsQuery(), default);

        // Assert — POSITIVE half: own value present (if absent, the instrument finds nothing at all
        // and its "no leak" verdict would be worthless)
        result.Should().Contain(mine);
        // NEGATIVE half: the other tenant's value must NOT be there
        result.Should().NotContain(yours);
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task ExplicitOtherTenantId_DoesNotReturnCallersOwnGroups()
    {
        // Guards the overload: passing someone else's TenantId must not mix the two sets.
        // Role is Superadmin because the handler now refuses an explicit foreign TenantId to
        // anyone else; the refusal itself is covered by NonSuperadmin_AskingForAnotherTenant.
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var mine  = $"MINE2-{Guid.NewGuid():N}".ToUpperInvariant();
        var yours = $"YOURS2-{Guid.NewGuid():N}".ToUpperInvariant();
        beDb.RtsDataUserStatuses.Add(NewStatus(postgres.TenantAId, mine));
        beDb.RtsDataUserStatuses.Add(NewStatus(postgres.TenantBId, yours));
        await beDb.SaveChangesAsync();

        var handler = CreateHandler(postgres.TenantAId, role: "Superadmin");

        var result = await handler.Handle(
            new GetTenantStatusGroupsQuery(postgres.TenantBId), default);

        result.Should().Contain(yours);      // positive: the requested tenant's own value
        result.Should().NotContain(mine);    // negative: caller's value must not bleed in
    }

    [Fact]
    public async Task ReturnsValuesVerbatim_UpperCaseIsNotNormalised()
    {
        // The whole point of the pick-from-list decision: the operator must receive the string
        // exactly as the platform stores it, because the WFM comparison is character-for-character.
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var raw = "ONPHONE";
        beDb.RtsDataUserStatuses.Add(NewStatus(postgres.TenantAId, raw));
        await beDb.SaveChangesAsync();

        var result = await CreateHandler(postgres.TenantAId)
            .Handle(new GetTenantStatusGroupsQuery(), default);

        result.Should().Contain("ONPHONE");
        result.Should().NotContain("On Phone");   // negative: no prettifying on the way out
    }

    [Fact]
    public async Task EmptyAndNullGroups_AreExcluded_AndNoThrow()
    {
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var good = $"GOOD-{Guid.NewGuid():N}".ToUpperInvariant();
        beDb.RtsDataUserStatuses.Add(NewStatus(postgres.TenantAId, good));
        beDb.RtsDataUserStatuses.Add(NewStatus(postgres.TenantAId, null));
        beDb.RtsDataUserStatuses.Add(NewStatus(postgres.TenantAId, ""));
        await beDb.SaveChangesAsync();

        var result = await CreateHandler(postgres.TenantAId)
            .Handle(new GetTenantStatusGroupsQuery(), default);

        result.Should().Contain(good);
        result.Should().NotContainNulls();
        result.Should().NotContain(string.Empty);
    }

    [Fact]
    public async Task DuplicatesCollapse_AndOrderIsStable()
    {
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var g = $"DUP-{Guid.NewGuid():N}".ToUpperInvariant();
        beDb.RtsDataUserStatuses.Add(NewStatus(postgres.TenantAId, g));
        beDb.RtsDataUserStatuses.Add(NewStatus(postgres.TenantAId, g));
        await beDb.SaveChangesAsync();

        var result = await CreateHandler(postgres.TenantAId)
            .Handle(new GetTenantStatusGroupsQuery(), default);

        result.Count(x => x == g).Should().Be(1);
        result.Should().BeInAscendingOrder();
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task NonSuperadmin_AskingForAnotherTenant_IsRefused()
    {
        // The page attribute [Authorize(Roles="Superadmin")] guards a UI route, not this query:
        // AuthorizationBehavior fires only for IRequiresPermission / IRequiresTenantContext, and
        // no request in the solution implements either. So the refusal must live in the handler.
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var yours = $"YOURS3-{Guid.NewGuid():N}".ToUpperInvariant();
        beDb.RtsDataUserStatuses.Add(NewStatus(postgres.TenantBId, yours));
        await beDb.SaveChangesAsync();

        var handler = CreateHandler(postgres.TenantAId, role: "Editor");

        var act = () => handler.Handle(
            new GetTenantStatusGroupsQuery(postgres.TenantBId), default);

        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task Superadmin_AskingForAnotherTenant_IsAllowed()
    {
        // POSITIVE half of the same gate: without it, a handler that refuses everyone would pass
        // the test above while breaking the only legitimate cross-tenant caller.
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        var yours = $"YOURS4-{Guid.NewGuid():N}".ToUpperInvariant();
        beDb.RtsDataUserStatuses.Add(NewStatus(postgres.TenantBId, yours));
        await beDb.SaveChangesAsync();

        var handler = CreateHandler(postgres.TenantAId, role: "Superadmin");

        var result = await handler.Handle(
            new GetTenantStatusGroupsQuery(postgres.TenantBId), default);

        result.Should().Contain(yours);
    }

    [Fact]
    public async Task NoTenantContextAndNoExplicitId_IsRefused_NotNullReference()
    {
        // Superadmin who has not picked a tenant: currentUser.TenantId is null.
        // `currentUser.TenantId!.Value` would throw NullReference — an explicit refusal is required.
        var handler = CreateHandler(tenantId: null, role: "Superadmin");

        var act = () => handler.Handle(new GetTenantStatusGroupsQuery(), default);

        // ForbiddenException is not a NullReferenceException, so this single assertion carries
        // both halves: it fails if nothing is thrown AND if the NRE is thrown instead.
        await act.Should().ThrowAsync<ForbiddenException>();
    }

    // ── helpers ──────────────────────────────────────────────────────────────────

    private static RtsDataUserStatus NewStatus(Guid tenantId, string? group) => new()
    {
        TenantId = tenantId,
        UserId = $"U-{Guid.NewGuid():N}",
        StatusId = "S1",
        ServerId = "SRV1",
        OnDate = DateTime.UtcNow.ToString("dd/MM/yyyy"),
        StatusGroup = group
    };

    // PostgresFixture exposes CreateBackendEmulationDbContext() but NO factory and NO user
    // accessor helper (measured: Fixtures/PostgresFixture.cs:359-409). Both are built here:
    // the factory is a substitute that hands out a fresh fixture context per call, matching
    // IBackendEmulationDbContextFactory's contract (caller disposes).
    private GetTenantStatusGroupsQueryHandler CreateHandler(Guid? tenantId, string role = "Editor")
    {
        var factory = Substitute.For<IBackendEmulationDbContextFactory>();
        factory.CreateDbContextAsync(Arg.Any<CancellationToken>())
               .Returns(_ => Task.FromResult<IBackendEmulationDbContext>(
                   postgres.CreateBackendEmulationDbContext()));

        var accessor = Substitute.For<ICurrentUserAccessor>();
        accessor.TenantId.Returns(tenantId);
        accessor.UserId.Returns(Guid.NewGuid());
        accessor.UserName.Returns("test-user");
        accessor.Role.Returns(role);
        accessor.IsAuthenticated.Returns(true);

        return new GetTenantStatusGroupsQueryHandler(factory, accessor);
    }
}
