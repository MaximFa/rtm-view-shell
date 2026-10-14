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
/// The candidate list feeds the serving-groups setting, so leaking another tenant's suffixes would
/// leak their platform configuration - the same reason GetTenantStatusGroupsQuery is gated.
///
/// The tenant gate here is structural, not incidental: RTSGrid_Row has NO TenantId column and
/// neither does RTSGrid_Grid (measured), so the only way to scope the query is through
/// NGC_BusinessUnit.TenantId. Drop that join condition and the query happily returns a neighbour's
/// metric suffixes, which is what the cross-tenant test below pins.
///
/// Each test seeds its own BU ids from the database: PostgresFixture starts one container per
/// collection and never truncates between tests, and the grid tables carry no tenant column, so
/// rows accumulate across tests. That is the lesson of the 338/340 run.
/// </summary>
[Collection("Postgres")]
public class GetWfmServingGroupCandidatesQueryHandlerTests(PostgresFixture postgres)
{
    // Own tenant ids per test instance, not the fixture's shared TenantAId/TenantBId: xUnit builds
    // a new instance per test, so these are unique, and the grid tables have no tenant column to
    // isolate on. Using the shared ids would let one test's cells appear in another's list - the
    // 338/340 lesson, applied before it bites rather than after.
    private readonly Guid _tenant = Guid.NewGuid();
    private readonly Guid _otherTenant = Guid.NewGuid();

    [Fact]
    public async Task ReturnsSuffixes_OfOwnTenantOnly()
    {
        // Two tenants, each with its own BU, rows and cells. The caller belongs to A and must see
        // only A's suffix. NEGATIVE half in the same test: B's suffix must be absent - without the
        // NGC_BusinessUnit.TenantId condition it would be present, and the list would look fine.
        var mine = $"Mine{Guid.NewGuid():N}"[..12];
        var theirs = $"Theirs{Guid.NewGuid():N}"[..12];

        await SeedAsync(_tenant, $"UsersInStatusGroupCount_{mine}");
        await SeedAsync(_otherTenant, $"UsersInStatusGroupCount_{theirs}");

        var result = await CreateHandler(_tenant)
            .Handle(new GetWfmServingGroupCandidatesQuery(), default);

        result.Should().Contain(mine);
        result.Should().NotContain(theirs);
    }

    [Fact]
    public async Task NonGroupMetrics_AreNotOffered()
    {
        // Only UsersInStatusGroupCount_* are serving groups. A connected-agents metric in the same
        // row must not appear as a pickable "group", or the operator would configure N out of a
        // metric that is not a group count at all.
        var group = $"Grp{Guid.NewGuid():N}"[..10];
        await SeedAsync(_tenant, $"UsersInStatusGroupCount_{group}", "QueueLoginDataNumLoggedUsers");

        var result = await CreateHandler(_tenant)
            .Handle(new GetWfmServingGroupCandidatesQuery(), default);

        result.Should().Contain(group);
        result.Should().NotContain("QueueLoginDataNumLoggedUsers");
    }

    [Fact]
    public async Task ReturnsVerbatim_CasingIsNotNormalised()
    {
        // The whole point of picking from this list: the stored value must equal the metric suffix
        // byte for byte, because the provider compares with StringComparer.Ordinal. Normalising
        // here would reintroduce the 13.10 casing defect from the other end.
        var mixed = $"OnPhone{Guid.NewGuid():N}"[..14];
        await SeedAsync(_tenant, $"UsersInStatusGroupCount_{mixed}");

        var result = await CreateHandler(_tenant)
            .Handle(new GetWfmServingGroupCandidatesQuery(), default);

        result.Should().Contain(mixed);
        result.Should().NotContain(mixed.ToUpperInvariant());
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task NonSuperadmin_AskingForAnotherTenant_IsRefused()
    {
        // The settings page attribute guards a UI route, not this query: AuthorizationBehavior
        // fires only for IRequiresPermission / IRequiresTenantContext, which no request in the
        // solution implements. The refusal has to live in the handler.
        await SeedAsync(_otherTenant, "UsersInStatusGroupCount_Available");

        var act = () => CreateHandler(_tenant, role: "Editor")
            .Handle(new GetWfmServingGroupCandidatesQuery(_otherTenant), default);

        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task Superadmin_AskingForAnotherTenant_IsAllowed()
    {
        // POSITIVE half of the gate: a handler that refused everyone would pass the test above and
        // break the only legitimate cross-tenant caller.
        var theirs = $"Their{Guid.NewGuid():N}"[..11];
        await SeedAsync(_otherTenant, $"UsersInStatusGroupCount_{theirs}");

        var result = await CreateHandler(_tenant, role: "Superadmin")
            .Handle(new GetWfmServingGroupCandidatesQuery(_otherTenant), default);

        result.Should().Contain(theirs);
    }

    [Fact]
    public async Task NoTenantContextAndNoExplicitId_IsRefused_NotNullReference()
    {
        // A Superadmin who has not picked a tenant has TenantId == null. `currentUser.TenantId!.Value`
        // would throw NullReference; an explicit refusal is required. ForbiddenException is not a
        // NullReferenceException, so this single assertion carries both halves.
        var act = () => CreateHandler(tenantId: null, role: "Superadmin")
            .Handle(new GetWfmServingGroupCandidatesQuery(), default);

        await act.Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task TenantWithNoGridRows_GetsEmptyList_NotAnError()
    {
        // "Nothing published yet" is a legitimate answer for a fresh tenant, and the settings page
        // must be able to render it. An exception here would make the page unopenable.
        // _tenant is untouched in this test - nothing seeded for it at all.
        var result = await CreateHandler(_tenant)
            .Handle(new GetWfmServingGroupCandidatesQuery(), default);

        result.Should().BeEmpty();
    }

    // ── helpers ──────────────────────────────────────────────────────────────────

    /// <summary>
    /// Seeds BU -> row -> cells for one tenant. Grid.UnionId stays -1, as the live data has it
    /// (devops on 234: -1 in all 60 grid rows); the BU link lives on RTSGrid_Row.UnionId, written by
    /// RtsRepository.InsertQueueGridRowAsync:217-226. BU ids come from the database, since the grid
    /// tables carry no tenant column and an invented id could collide with another test's.
    /// </summary>
    private async Task SeedAsync(Guid tenantId, params string[] metricIds)
    {
        await using var db = postgres.CreateBackendEmulationDbContext();

        var bu = new NgcBusinessUnit { TenantId = tenantId, BusinessUnitName = $"BU-{Guid.NewGuid():N}" };
        db.NgcBusinessUnits.Add(bu);
        await db.SaveChangesAsync();

        var grid = new RtsGridGrid { UnionId = -1, Title = $"grid-{bu.BusinessUnitId}" };
        db.RtsGridGrids.Add(grid);
        await db.SaveChangesAsync();

        var column = new RtsGridColumn { GridId = grid.GridId, ColumnNumber = 1 };
        var row = new RtsGridRow { GridId = grid.GridId, RowNumber = 1, UnionId = bu.BusinessUnitId };
        db.RtsGridColumns.Add(column);
        db.RtsGridRows.Add(row);
        await db.SaveChangesAsync();

        foreach (var metricId in metricIds)
            db.RtsGridCells.Add(new RtsGridCell
            {
                RowId = row.RowId, ColumnId = column.ColumnId, Value = metricId
            });

        await db.SaveChangesAsync();
    }

    private GetWfmServingGroupCandidatesQueryHandler CreateHandler(Guid? tenantId, string role = "Editor")
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

        return new GetWfmServingGroupCandidatesQueryHandler(factory, accessor);
    }
}
