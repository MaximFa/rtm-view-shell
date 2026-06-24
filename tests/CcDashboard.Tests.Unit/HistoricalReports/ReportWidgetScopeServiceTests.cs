using CcDashboard.Application.HistoricalReports;
using CcDashboard.Domain.Domain;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Services;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using NSubstitute;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// Tests for ReportWidgetScopeService — scope chain resolution.
/// SF-BI-001: Server-side, NON-BYPASSABLE.
/// SF-BI-002: Out-of-scope entries dropped + logged.
/// </summary>
public class ReportWidgetScopeServiceTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IReportScopeResolver _scopeResolver = Substitute.For<IReportScopeResolver>();
    private readonly IBuMembershipResolver _buResolver = Substitute.For<IBuMembershipResolver>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly ILogger<ReportWidgetScopeService> _logger = Substitute.For<ILogger<ReportWidgetScopeService>>();

    public ReportWidgetScopeServiceTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.UserId.Returns(Guid.NewGuid());
        _user.PermissionGroupId.Returns(Guid.NewGuid());
    }

    [Fact]
    public async Task Superadmin_ReturnsFullScope()
    {
        var scope = ReportScope.Full();
        _scopeResolver.ResolveQueueScopeAsync(Arg.Any<CancellationToken>()).Returns(scope);

        var requested = new HashSet<string> { "Q1", "Q2", "Q3" };
        _buResolver.ResolveQueuesAsync(TenantId, Arg.Any<IReadOnlyList<int>>(), Arg.Any<ReportScope>(), Arg.Any<CancellationToken>())
            .Returns(requested);

        var options = new DbContextOptionsBuilder<BackendEmulationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        using var beDb = new BackendEmulationDbContext(options);

        var service = new ReportWidgetScopeService(_scopeResolver, _buResolver, beDb, _user, _logger);

        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope { Mode = "bu", BusinessUnitIds = new[] { 1 } },
            Columns = new[] { "Offered" },
            PageSize = 25
        };

        var result = await service.ResolveQueueScopeAsync(TenantId, config);

        result.FullScope.Should().BeTrue();
        result.EffectiveWorkgroups.Should().HaveCount(3);
        result.DroppedCount.Should().Be(0);
    }

    [Fact]
    public async Task NonSuperadmin_EmptyPG_ReturnsDenied()
    {
        var scope = ReportScope.Empty();
        _scopeResolver.ResolveQueueScopeAsync(Arg.Any<CancellationToken>()).Returns(scope);

        var options = new DbContextOptionsBuilder<BackendEmulationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        using var beDb = new BackendEmulationDbContext(options);

        var service = new ReportWidgetScopeService(_scopeResolver, _buResolver, beDb, _user, _logger);

        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope { Mode = "bu", BusinessUnitIds = new[] { 1 } },
            Columns = new[] { "Offered" },
            PageSize = 25
        };

        var result = await service.ResolveQueueScopeAsync(TenantId, config);

        result.FullScope.Should().BeFalse();
        result.Denied.Should().BeTrue();
    }

    [Fact]
    public async Task NonSuperadmin_OutOfScopeDropped_LogsCount()
    {
        var allowedWorkgroups = new HashSet<string> { "Q1", "Q2" };
        var scope = new ReportScope
        {
            FullScope = false,
            AllowedWorkgroups = allowedWorkgroups
        };
        _scopeResolver.ResolveQueueScopeAsync(Arg.Any<CancellationToken>()).Returns(scope);

        var requested = new HashSet<string> { "Q1", "Q2", "Q3", "Q4", "Q5" };
        _buResolver.ResolveQueuesAsync(TenantId, Arg.Any<IReadOnlyList<int>>(), Arg.Any<ReportScope>(), Arg.Any<CancellationToken>())
            .Returns(requested);

        var options = new DbContextOptionsBuilder<BackendEmulationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        using var beDb = new BackendEmulationDbContext(options);

        var service = new ReportWidgetScopeService(_scopeResolver, _buResolver, beDb, _user, _logger);

        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope { Mode = "bu", BusinessUnitIds = new[] { 1 } },
            Columns = new[] { "Offered" },
            PageSize = 25
        };

        var result = await service.ResolveQueueScopeAsync(TenantId, config);

        result.FullScope.Should().BeFalse();
        result.EffectiveWorkgroups.Should().HaveCount(2);
        result.EffectiveWorkgroups.Should().Contain("Q1");
        result.EffectiveWorkgroups.Should().Contain("Q2");
        result.DroppedCount.Should().Be(3);

        _logger.Received().Log(
            LogLevel.Warning,
            Arg.Any<EventId>(),
            Arg.Is<object>(o => o.ToString()!.Contains("SF-BI-002")),
            Arg.Any<Exception>(),
            Arg.Any<Func<object, Exception?, string>>());
    }

    [Fact]
    public async Task AgentScope_EmptyPG_ReturnsDenied()
    {
        var scope = ReportScope.Empty();
        _scopeResolver.ResolveAgentScopeAsync(Arg.Any<CancellationToken>()).Returns(scope);

        var options = new DbContextOptionsBuilder<BackendEmulationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        using var beDb = new BackendEmulationDbContext(options);

        var service = new ReportWidgetScopeService(_scopeResolver, _buResolver, beDb, _user, _logger);

        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                Mode = "bu",
                BusinessUnitIds = new[] { 1 },
                AgentAxis = AgentReportAxis.Detail
            },
            Columns = new[] { "SumAvailableMs" },
            PageSize = 25
        };

        var result = await service.ResolveAgentScopeAsync(TenantId, config, AgentReportAxis.Detail);

        result.Denied.Should().BeTrue();
    }

    [Fact]
    public async Task AgentScope_SuperAdmin_ReturnsAll()
    {
        var scope = ReportScope.Full();
        _scopeResolver.ResolveAgentScopeAsync(Arg.Any<CancellationToken>()).Returns(scope);

        var requested = new HashSet<string> { "agent1", "agent2", "agent3" };
        _buResolver.ResolveAgentsAsync(TenantId, Arg.Any<IReadOnlyList<int>>(), AgentReportAxis.Detail, Arg.Any<ReportScope>(), Arg.Any<CancellationToken>())
            .Returns(requested);

        var options = new DbContextOptionsBuilder<BackendEmulationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        using var beDb = new BackendEmulationDbContext(options);

        var service = new ReportWidgetScopeService(_scopeResolver, _buResolver, beDb, _user, _logger);

        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                Mode = "bu",
                BusinessUnitIds = new[] { 1 },
                AgentAxis = AgentReportAxis.Detail
            },
            Columns = new[] { "SumAvailableMs" },
            PageSize = 25
        };

        var result = await service.ResolveAgentScopeAsync(TenantId, config, AgentReportAxis.Detail);

        result.FullScope.Should().BeTrue();
        result.EffectiveAgentIds.Should().HaveCount(3);
    }

    [Fact]
    public async Task QueuesModeResolve_UsesQueueIds()
    {
        var allowedWorkgroups = new HashSet<string> { "Sales", "Support", "Billing" };
        var scope = new ReportScope
        {
            FullScope = false,
            AllowedWorkgroups = allowedWorkgroups
        };
        _scopeResolver.ResolveQueueScopeAsync(Arg.Any<CancellationToken>()).Returns(scope);

        var queueId1 = Guid.NewGuid();
        var queueId2 = Guid.NewGuid();
        var queueId3 = Guid.NewGuid();

        var options = new DbContextOptionsBuilder<BackendEmulationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        using var beDb = new BackendEmulationDbContext(options);
        beDb.NgcQueues.AddRange(
            new CcDashboard.Domain.Domain.NgcQueue { Id = queueId1, TenantId = TenantId, Name = "Sales Queue", ExternalId = "Sales" },
            new CcDashboard.Domain.Domain.NgcQueue { Id = queueId2, TenantId = TenantId, Name = "Support Queue", ExternalId = "Support" },
            new CcDashboard.Domain.Domain.NgcQueue { Id = queueId3, TenantId = TenantId, Name = "VIP Queue", ExternalId = "VIP" }
        );
        await beDb.SaveChangesAsync();

        var service = new ReportWidgetScopeService(_scopeResolver, _buResolver, beDb, _user, _logger);

        var config = new ReportWidgetConfig
        {
            Scope = new ReportWidgetScope
            {
                Mode = "queues",
                QueueIds = new[] { queueId1, queueId2, queueId3 }
            },
            Columns = new[] { "Offered" },
            PageSize = 25
        };

        var result = await service.ResolveQueueScopeAsync(TenantId, config);

        result.EffectiveWorkgroups.Should().Contain("Sales");
        result.EffectiveWorkgroups.Should().Contain("Support");
        result.EffectiveWorkgroups.Should().NotContain("VIP");
        result.DroppedCount.Should().Be(1);
    }
}
