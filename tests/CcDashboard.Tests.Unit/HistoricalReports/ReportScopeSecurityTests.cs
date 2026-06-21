using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Domain.Domain.Historical;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Handlers;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// SF-BI-001 Security tests: PG-based scope enforcement for historical reports.
/// </summary>
public class ReportScopeSecurityTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportScopeResolver _scopeResolver = Substitute.For<IReportScopeResolver>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();

    public ReportScopeSecurityTests()
    {
        _user.TenantId.Returns(TenantId);
    }

    [Fact]
    public async Task NonSuperadmin_NullClientList_LimitsToAllowedQueues()
    {
        _user.Role.Returns("Editor");
        var allowedWorkgroups = new HashSet<string> { "Sales", "Support" };
        var scope = new ReportScope { FullScope = false, AllowedWorkgroups = allowedWorkgroups };
        _scopeResolver.ResolveQueueScopeAsync(Arg.Any<CancellationToken>()).Returns(scope);

        var salesData = new HistQueueInterval
        {
            Id = Guid.NewGuid(), TenantId = TenantId,
            IntervalStart = DateTime.UtcNow.AddHours(-1), Workgroup = "Sales", Offered = 10, Answered = 8
        };
        _repo.GetQueueIntervalsAsync(
                TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
                Arg.Any<ReportScope>(),
                Arg.Is<IReadOnlySet<string>>(w => w.Contains("Sales") && w.Contains("Support")),
                Arg.Any<CancellationToken>())
            .Returns(new List<HistQueueInterval> { salesData });

        var handler = new GetQueueIntervalReportQueryHandler(_repo, _scopeResolver, _user);
        var result = await handler.Handle(
            new GetQueueIntervalReportQuery(DateTime.UtcNow.AddDays(-1), DateTime.UtcNow, Workgroups: null),
            CancellationToken.None);

        result.Rows.Should().HaveCount(1);
        result.Rows[0].Workgroup.Should().Be("Sales");
    }

    [Fact]
    public async Task NonSuperadmin_ClientListWithOutOfPGEntry_EntryExcluded()
    {
        _user.Role.Returns("Editor");
        var allowedWorkgroups = new HashSet<string> { "Sales" };
        var scope = new ReportScope { FullScope = false, AllowedWorkgroups = allowedWorkgroups };
        _scopeResolver.ResolveQueueScopeAsync(Arg.Any<CancellationToken>()).Returns(scope);

        var clientRequested = new[] { "Sales", "VIP", "Billing" };
        var effectiveFilter = scope.IntersectWorkgroups(clientRequested);

        effectiveFilter.Should().HaveCount(1);
        effectiveFilter.Should().Contain("Sales");
        effectiveFilter.Should().NotContain("VIP");
        effectiveFilter.Should().NotContain("Billing");
    }

    [Fact]
    public async Task NonSuperadmin_EmptyPGQueues_ReturnsEmptyResult()
    {
        _user.Role.Returns("Editor");
        var scope = ReportScope.Empty();
        _scopeResolver.ResolveQueueScopeAsync(Arg.Any<CancellationToken>()).Returns(scope);

        var handler = new GetQueueIntervalReportQueryHandler(_repo, _scopeResolver, _user);
        var result = await handler.Handle(
            new GetQueueIntervalReportQuery(DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Rows.Should().BeEmpty();
        result.TotalCount.Should().Be(0);
        await _repo.DidNotReceive().GetQueueIntervalsAsync(
            Arg.Any<Guid>(), Arg.Any<DateTime>(), Arg.Any<DateTime>(),
            Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Superadmin_NullClientList_ReturnsFullTenantScope()
    {
        _user.Role.Returns("Superadmin");
        var scope = ReportScope.Full();
        _scopeResolver.ResolveQueueScopeAsync(Arg.Any<CancellationToken>()).Returns(scope);

        var allQueues = new List<HistQueueInterval>
        {
            new() { Id = Guid.NewGuid(), TenantId = TenantId, IntervalStart = DateTime.UtcNow.AddHours(-1), Workgroup = "Sales" },
            new() { Id = Guid.NewGuid(), TenantId = TenantId, IntervalStart = DateTime.UtcNow.AddHours(-1), Workgroup = "VIP" },
            new() { Id = Guid.NewGuid(), TenantId = TenantId, IntervalStart = DateTime.UtcNow.AddHours(-1), Workgroup = "Billing" }
        };
        _repo.GetQueueIntervalsAsync(
                TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
                Arg.Is<ReportScope>(s => s.FullScope),
                Arg.Any<IReadOnlySet<string>>(),
                Arg.Any<CancellationToken>())
            .Returns(allQueues);

        var handler = new GetQueueIntervalReportQueryHandler(_repo, _scopeResolver, _user);
        var result = await handler.Handle(
            new GetQueueIntervalReportQuery(DateTime.UtcNow.AddDays(-1), DateTime.UtcNow, Workgroups: null),
            CancellationToken.None);

        result.Rows.Should().HaveCount(3);
    }

    [Fact]
    public async Task NonSuperadmin_EmptyPGAgents_ReturnsEmptyResult()
    {
        _user.Role.Returns("Editor");
        var scope = ReportScope.Empty();
        _scopeResolver.ResolveAgentScopeAsync(Arg.Any<CancellationToken>()).Returns(scope);

        var handler = new GetAgentMonthlyReportQueryHandler(_repo, _scopeResolver, _user);
        var result = await handler.Handle(
            new GetAgentMonthlyReportQuery(DateTime.UtcNow.AddDays(-30), DateTime.UtcNow),
            CancellationToken.None);

        result.Rows.Should().BeEmpty();
        await _repo.DidNotReceive().GetAgentIntervalsAsync(
            Arg.Any<Guid>(), Arg.Any<DateTime>(), Arg.Any<DateTime>(),
            Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public void DateRangeCap_RejectsOverCap()
    {
        var validator = new Application.HistoricalReports.Validators.GetQueueIntervalReportQueryValidator();
        var query = new GetQueueIntervalReportQuery(
            DateTime.UtcNow.AddDays(-100),
            DateTime.UtcNow);

        var result = validator.Validate(query);

        result.IsValid.Should().BeFalse();
        result.Errors.Should().Contain(e => e.ErrorMessage.Contains("92 days"));
    }

    [Fact]
    public void ReportScope_IntersectWorkgroups_DropsOutOfScope()
    {
        var scope = new ReportScope
        {
            FullScope = false,
            AllowedWorkgroups = new HashSet<string> { "Q1", "Q2" }
        };

        var clientRequested = new[] { "Q1", "Q3", "Q4" };
        var effective = scope.IntersectWorkgroups(clientRequested);

        effective.Should().HaveCount(1);
        effective.Should().Contain("Q1");
        effective.Should().NotContain("Q3");
    }

    [Fact]
    public void ReportScope_IntersectAgents_DropsOutOfScope()
    {
        var scope = new ReportScope
        {
            FullScope = false,
            AllowedAgentExternalIds = new HashSet<string> { "agent1", "agent2" }
        };

        var clientRequested = new[] { "agent1", "agent3" };
        var effective = scope.IntersectAgents(clientRequested);

        effective.Should().HaveCount(1);
        effective.Should().Contain("agent1");
        effective.Should().NotContain("agent3");
    }

    [Fact]
    public void ReportScope_FullScope_NullClientList_ReturnsEmptySet()
    {
        var scope = ReportScope.Full();
        var effective = scope.IntersectWorkgroups(null);
        effective.Should().BeEmpty();
    }

    [Fact]
    public void ReportScope_FullScope_WithClientList_ReturnsClientList()
    {
        var scope = ReportScope.Full();
        var clientRequested = new[] { "Q1", "Q2", "Q3" };
        var effective = scope.IntersectWorkgroups(clientRequested);

        effective.Should().HaveCount(3);
        effective.Should().Contain("Q1");
        effective.Should().Contain("Q2");
        effective.Should().Contain("Q3");
    }
}
