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
/// CORRECTED 14.10. The first version of these tests seeded cells whose Value began with
/// "UsersInStatusGroupCount_" and passed - against a name that does not exist in the product
/// (devops on 234: 0 such metrics, 0 such cells in the whole database). They were testing my model,
/// not the product. `UsersInStatusGroupCount` is the value of RtsGridMetric.MetricFunction and the
/// group is RtsGridMetric.MetricParameter; the lookup the product already uses is
/// AgentStateHandlers.cs:50-57.
///
/// Hence the first test below deliberately seeds NOTHING: it asserts against the catalogue the
/// MIGRATIONS bring (20260528100000_AddTrainingRtsGridMetric inserts QueueLoginDataNumTrainingUsers
/// / TRAINING). A test that seeds its own rows can only confirm whatever format the author
/// imagined, which is exactly how the previous version stayed green on a fiction.
///
/// Scope note: RtsGridMetric has no TenantId column, so the catalogue is shared and the query
/// cannot filter it per tenant. The gate guards WHO MAY ASK; the per-BU question is the provider's.
///
/// CONSEQUENCE for these tests, learned from box n2 (Security 342/346): because the catalogue is
/// shared by the whole collection, NO test here may assert on the WHOLE list. Rows seeded by
/// neighbouring tests are legitimately present, so assertions are about THIS test's own unique
/// group codes only - Contain / NotContain, never Equal or OnlyContain. My previous version
/// asserted "every value is upper case" and "the list is exactly these" and went red on other
/// tests' rows, which is a defect of the test, not of the query.
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
    public async Task ReturnsGroupsFromTheRealCatalogue_WithoutSeedingAnything()
    {
        // NOTHING is seeded here on purpose. The only rows involved are the ones the product's own
        // migrations insert, so this test can fail if the lookup is wrong - which the seeded version
        // could not. TRAINING comes from 20260528100000_AddTrainingRtsGridMetric.
        var result = await CreateHandler(_tenant)
            .Handle(new GetWfmServingGroupCandidatesQuery(), default);

        result.Should().Contain("TRAINING");

        // NEGATIVE half: the name I invented must appear nowhere, in any shape. This one IS safe to
        // assert over the whole list - no test seeds such a value any more, and if one ever does,
        // that is precisely what should fail.
        result.Should().NotContain(g => g.Contains("UsersInStatusGroupCount", StringComparison.Ordinal));
    }

    [Fact]
    public async Task NonGroupMetrics_AreNotOffered()
    {
        // Only UsersInStatusGroupCount_* are serving groups. A connected-agents metric in the same
        // row must not appear as a pickable "group", or the operator would configure N out of a
        // metric that is not a group count at all.
        // Unique code per run: the catalogue is shared, so a fixed name would be another test's row.
        var group = $"GRPX{Guid.NewGuid():N}"[..12].ToUpperInvariant();
        var nonGroupId = await SeedCatalogueAsync(group);
        var otherFunctionId = await SeedCatalogueAsync(null);   // same shape, different function

        var result = await CreateHandler(_tenant)
            .Handle(new GetWfmServingGroupCandidatesQuery(), default);

        result.Should().Contain(group);
        // The metric written with another MetricFunction must not be offered. Asserting on ITS id,
        // not on the whole list, keeps the check independent of what neighbours seeded.
        result.Should().NotContain(otherFunctionId);
        result.Should().NotContain(nonGroupId, "a MetricId is never a group code");
    }

    [Fact]
    public async Task ReturnsVerbatim_CasingIsNotNormalised()
    {
        // The whole point of picking from this list: the stored value must equal the metric suffix
        // byte for byte, because the provider compares with StringComparer.Ordinal. Normalising
        // here would reintroduce the 13.10 casing defect from the other end.
        var mixed = $"OnPhone{Guid.NewGuid():N}"[..14];
        await SeedCatalogueAsync(mixed);

        var result = await CreateHandler(_tenant)
            .Handle(new GetWfmServingGroupCandidatesQuery(), default);

        result.Should().Contain(mixed, "the parameter is returned verbatim");
        result.Should().NotContain(mixed.ToUpperInvariant(),
            "nothing up-cases it on the way out - the comparison downstream is Ordinal");
    }

    [Fact]
    [Trait("Req", "ARCH-01")]
    public async Task NonSuperadmin_AskingForAnotherTenant_IsRefused()
    {
        // The settings page attribute guards a UI route, not this query: AuthorizationBehavior
        // fires only for IRequiresPermission / IRequiresTenantContext, which no request in the
        // solution implements. The refusal has to live in the handler.

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
        var theirs = $"THEIR{Guid.NewGuid():N}"[..11].ToUpperInvariant();
        await SeedCatalogueAsync(theirs);

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
    public async Task TheCatalogueIsShared_SoTheListDoesNotDependOnTheTenant()
    {
        // This replaces a test I wrote before reading the schema: it expected an empty list for a
        // fresh tenant, which would now FAIL - and failing is the honest outcome, because
        // RtsGridMetric has no TenantId column and the catalogue is one for the whole platform.
        // Pinning the real property instead of my assumption: two different tenants get the same
        // answer. The per-tenant question ("does this BU actually publish that group?") belongs to
        // IWfmEngineAgentCountProvider.GetPublishedGroupNamesAsync.
        var mine = await CreateHandler(_tenant)
            .Handle(new GetWfmServingGroupCandidatesQuery(), default);
        var theirs = await CreateHandler(_otherTenant)
            .Handle(new GetWfmServingGroupCandidatesQuery(), default);

        mine.Should().BeEquivalentTo(theirs);
        mine.Should().Contain("TRAINING", "the migrations alone put TRAINING in the catalogue");
    }

    // ── helpers ──────────────────────────────────────────────────────────────────

    /// <summary>
    /// Adds one row to the metric CATALOGUE, the way the product's own migrations and seeder do
    /// (DatabaseInitializer.cs:607-613, 20260528100000_AddTrainingRtsGridMetric): the group is
    /// MetricParameter and the function is UsersInStatusGroupCount. Passing null for the group
    /// writes a metric with a DIFFERENT function, used as the negative case.
    /// No grids, rows or cells are needed: the candidate list is a catalogue question. Which of
    /// these groups has live cells on a BU's rows is the provider's question, not this query's.
    /// </summary>
    private async Task<string> SeedCatalogueAsync(string? group)
    {
        await using var db = postgres.CreateBackendEmulationDbContext();

        var id = $"TestMetric{Guid.NewGuid():N}"[..24];
        db.RtsGridMetrics.Add(new RtsGridMetric
        {
            MetricId = id,
            Description = "test",
            DataType = "UsersSummary",
            MetricFunction = group is null ? "QueueCallsWaiting" : "UsersInStatusGroupCount",
            MetricParameter = group ?? "",
            ValueType = "number",
            MetricType = "Data"
        });

        await db.SaveChangesAsync();
        return id;
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
