using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using Microsoft.Extensions.Logging;
using NSubstitute;
using Xunit;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// FEAT-REPORT-QUEUE-TREND-COMPARE-01 queue picker (coordinator 17:02:51Z): the queues of the picked BUs inside the user's
/// scope, by the chart's own scope service. Each rule with both halves: no BU -> nothing, nothing asked; a BU outside the
/// user's scope shows no queue; the 500 cut is flagged, not silent; own tenant only.
/// </summary>
public class GetScopedQueuesQueryTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly GetScopedQueuesQueryHandler _handler;

    public GetScopedQueuesQueryTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.UserId.Returns(Guid.NewGuid());
        _handler = new GetScopedQueuesQueryHandler(_scope, _user, Substitute.For<ILogger<GetScopedQueuesQueryHandler>>());
        // BU 1 is the user's: Sales, Support; BU 9 is someone else's: the scope service gives nothing for it
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Is<ReportWidgetConfig>(c => c.Scope.BusinessUnitIds!.Contains(1)), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveWorkgroups = new HashSet<string> { "Support", "sales" } });
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Is<ReportWidgetConfig>(c => !c.Scope.BusinessUnitIds!.Contains(1)), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { FullScope = true, EffectiveWorkgroups = new HashSet<string>() });
    }

    private Task<ScopedQueuesResult> Run(params int[] bu) => _handler.Handle(new GetScopedQueuesQuery(bu), CancellationToken.None);

    [Fact]
    public async Task OwnBusinessUnit_ListsItsQueues_ByName()
    {
        var r = await Run(1);
        r.Queues.Select(q => q.Workgroup).Should().Equal("sales", "Support");
        (r.TotalCount, r.Truncated, r.Denied).Should().Be((2, false, false));
    }

    [Fact]
    public async Task AForeignBusinessUnit_ShowsNoQueue()
    {
        var r = await Run(9);
        r.Queues.Should().BeEmpty("the scope service gives nothing for a BU outside the user's scope - never 'everything'");
        r.Denied.Should().BeFalse();
        // negative half: the same call with the own BU lists queues
        (await Run(9, 1)).Queues.Should().HaveCount(2);
    }

    [Fact]
    public async Task NoBusinessUnits_Empty_NothingAsked()
    {
        (await Run()).Queues.Should().BeEmpty();
        await _scope.DidNotReceiveWithAnyArgs().ResolveQueueScopeAsync(default, default!, default);
    }

    [Fact]
    public async Task Denied_IsDenied()
    {
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>()).Returns(new ReportWidgetScopeResult());
        (await Run(1)).Denied.Should().BeTrue();
    }

    [Fact]
    public async Task MoreThanTheLimit_IsCut_AndSaysSo()
    {
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveWorkgroups = Enumerable.Range(0, 501).Select(i => $"Q{i:D3}").ToHashSet() });
        var r = await Run(1);
        (r.Queues.Count, r.TotalCount, r.Truncated).Should().Be((500, 501, true));
        GetScopedQueuesQueryHandler.Limit.Should().Be(500);
    }
}
