using CcDashboard.Application.Queries.Configuration;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Queries;

public class ConfigurationQueriesSuperadminFallbackTests
{
    private static readonly Guid UserTenantId = Guid.NewGuid();
    private static readonly Guid OtherTenantId = Guid.NewGuid();

    // ── GetQueuesQueryHandler ─────────────────────────────────────────────────

    [Fact]
    public async Task GetQueues_Superadmin_NoTenantId_UsesCurrent()
    {
        var repo = Substitute.For<INgcQueueRepository>();
        var user = Substitute.For<ICurrentUserAccessor>();
        user.Role.Returns("Superadmin");
        user.TenantId.Returns(UserTenantId);
        repo.GetAllByTenantAsync(UserTenantId, Arg.Any<CancellationToken>())
            .Returns(new List<NgcQueue> { new() { ExternalId = "Q1", Name = "Sales", TenantId = UserTenantId } });

        var handler = new GetQueuesQueryHandler(repo, user);
        var result = await handler.Handle(new GetQueuesQuery(), CancellationToken.None);

        await repo.Received(1).GetAllByTenantAsync(UserTenantId, Arg.Any<CancellationToken>());
        result.Should().ContainSingle().Which.QueueId.Should().Be("Q1");
    }

    [Fact]
    public async Task GetQueues_Superadmin_ExplicitTenantId_HonoursIt()
    {
        var repo = Substitute.For<INgcQueueRepository>();
        var user = Substitute.For<ICurrentUserAccessor>();
        user.Role.Returns("Superadmin");
        user.TenantId.Returns(UserTenantId);
        repo.GetAllByTenantAsync(OtherTenantId, Arg.Any<CancellationToken>())
            .Returns(new List<NgcQueue> { new() { ExternalId = "Q2", Name = "Support", TenantId = OtherTenantId } });

        var handler = new GetQueuesQueryHandler(repo, user);
        var result = await handler.Handle(new GetQueuesQuery(OtherTenantId), CancellationToken.None);

        await repo.Received(1).GetAllByTenantAsync(OtherTenantId, Arg.Any<CancellationToken>());
        result.Should().ContainSingle().Which.QueueId.Should().Be("Q2");
    }

    [Fact]
    public async Task GetQueues_NonSuperadmin_NoTenantId_UsesCurrent()
    {
        var repo = Substitute.For<INgcQueueRepository>();
        var user = Substitute.For<ICurrentUserAccessor>();
        user.Role.Returns("Administrator");
        user.TenantId.Returns(UserTenantId);
        repo.GetAllByTenantAsync(UserTenantId, Arg.Any<CancellationToken>())
            .Returns(new List<NgcQueue> { new() { ExternalId = "Q1", Name = "Sales", TenantId = UserTenantId } });

        var handler = new GetQueuesQueryHandler(repo, user);
        var result = await handler.Handle(new GetQueuesQuery(), CancellationToken.None);

        await repo.Received(1).GetAllByTenantAsync(UserTenantId, Arg.Any<CancellationToken>());
        result.Should().HaveCount(1);
    }

    // ── GetSitesQueryHandler ──────────────────────────────────────────────────

    [Fact]
    public async Task GetSites_Superadmin_NoTenantId_UsesCurrent()
    {
        var repo = Substitute.For<INgcSiteRepository>();
        var user = Substitute.For<ICurrentUserAccessor>();
        user.Role.Returns("Superadmin");
        user.TenantId.Returns(UserTenantId);
        repo.GetAllByTenantAsync(UserTenantId, Arg.Any<CancellationToken>())
            .Returns(new List<NgcSite> { new() { SiteId = "IL", SiteName = "Israel", TenantId = UserTenantId } });

        var handler = new GetSitesQueryHandler(repo, user);
        var result = await handler.Handle(new GetSitesQuery(), CancellationToken.None);

        await repo.Received(1).GetAllByTenantAsync(UserTenantId, Arg.Any<CancellationToken>());
        result.Should().ContainSingle().Which.SiteId.Should().Be("IL");
    }

    [Fact]
    public async Task GetSites_Superadmin_ExplicitTenantId_HonoursIt()
    {
        var repo = Substitute.For<INgcSiteRepository>();
        var user = Substitute.For<ICurrentUserAccessor>();
        user.Role.Returns("Superadmin");
        user.TenantId.Returns(UserTenantId);
        repo.GetAllByTenantAsync(OtherTenantId, Arg.Any<CancellationToken>())
            .Returns(new List<NgcSite> { new() { SiteId = "US", SiteName = "USA", TenantId = OtherTenantId } });

        var handler = new GetSitesQueryHandler(repo, user);
        var result = await handler.Handle(new GetSitesQuery(OtherTenantId), CancellationToken.None);

        await repo.Received(1).GetAllByTenantAsync(OtherTenantId, Arg.Any<CancellationToken>());
        result.Should().ContainSingle().Which.SiteId.Should().Be("US");
    }

    // ── GetSupergroupsQueryHandler ────────────────────────────────────────────

    [Fact]
    public async Task GetSupergroups_Superadmin_NoTenantId_UsesCurrent()
    {
        var repo = Substitute.For<INgcSupergroupRepository>();
        var user = Substitute.For<ICurrentUserAccessor>();
        user.Role.Returns("Superadmin");
        user.TenantId.Returns(UserTenantId);
        repo.GetAllByTenantAsync(UserTenantId, Arg.Any<CancellationToken>())
            .Returns(new List<NgcSupergroup> { new() { SupergroupId = 1, SupergroupName = "SG1", TenantId = UserTenantId } });

        var handler = new GetSupergroupsQueryHandler(repo, user);
        var result = await handler.Handle(new GetSupergroupsQuery(), CancellationToken.None);

        await repo.Received(1).GetAllByTenantAsync(UserTenantId, Arg.Any<CancellationToken>());
        result.Should().ContainSingle().Which.SupergroupId.Should().Be(1);
    }

    [Fact]
    public async Task GetSupergroups_Superadmin_ExplicitTenantId_HonoursIt()
    {
        var repo = Substitute.For<INgcSupergroupRepository>();
        var user = Substitute.For<ICurrentUserAccessor>();
        user.Role.Returns("Superadmin");
        user.TenantId.Returns(UserTenantId);
        repo.GetAllByTenantAsync(OtherTenantId, Arg.Any<CancellationToken>())
            .Returns(new List<NgcSupergroup> { new() { SupergroupId = 2, SupergroupName = "SG2", TenantId = OtherTenantId } });

        var handler = new GetSupergroupsQueryHandler(repo, user);
        var result = await handler.Handle(new GetSupergroupsQuery(OtherTenantId), CancellationToken.None);

        await repo.Received(1).GetAllByTenantAsync(OtherTenantId, Arg.Any<CancellationToken>());
        result.Should().ContainSingle().Which.SupergroupId.Should().Be(2);
    }

    // ── GetAgentGroupsQueryHandler ────────────────────────────────────────────

    [Fact]
    public async Task GetAgentGroups_Superadmin_NoTenantId_UsesCurrent()
    {
        var repo = Substitute.For<INgcAgentGroupRepository>();
        var user = Substitute.For<ICurrentUserAccessor>();
        user.Role.Returns("Superadmin");
        user.TenantId.Returns(UserTenantId);
        repo.GetAllByTenantAsync(UserTenantId, Arg.Any<CancellationToken>())
            .Returns(new List<NgcAgentGroup> { new() { ExternalId = "AG1", Name = "Agents", TenantId = UserTenantId } });

        var handler = new GetAgentGroupsQueryHandler(repo, user);
        var result = await handler.Handle(new GetAgentGroupsQuery(), CancellationToken.None);

        await repo.Received(1).GetAllByTenantAsync(UserTenantId, Arg.Any<CancellationToken>());
        result.Should().ContainSingle().Which.AgentGroupId.Should().Be("AG1");
    }

    [Fact]
    public async Task GetAgentGroups_Superadmin_ExplicitTenantId_HonoursIt()
    {
        var repo = Substitute.For<INgcAgentGroupRepository>();
        var user = Substitute.For<ICurrentUserAccessor>();
        user.Role.Returns("Superadmin");
        user.TenantId.Returns(UserTenantId);
        repo.GetAllByTenantAsync(OtherTenantId, Arg.Any<CancellationToken>())
            .Returns(new List<NgcAgentGroup> { new() { ExternalId = "AG2", Name = "Support", TenantId = OtherTenantId } });

        var handler = new GetAgentGroupsQueryHandler(repo, user);
        var result = await handler.Handle(new GetAgentGroupsQuery(OtherTenantId), CancellationToken.None);

        await repo.Received(1).GetAllByTenantAsync(OtherTenantId, Arg.Any<CancellationToken>());
        result.Should().ContainSingle().Which.AgentGroupId.Should().Be("AG2");
    }
}
