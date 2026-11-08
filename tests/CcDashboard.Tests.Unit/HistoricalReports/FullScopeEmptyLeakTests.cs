using CcDashboard.Application.Handlers;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Domain.Domain.Historical;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using Microsoft.Extensions.Logging;
using NSubstitute;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// PR234-V4-REPORT-FULLSCOPE-EMPTY-LEAK-01: a Superadmin (FullScope) whose picked BUs resolve to no agents/queues got the
/// whole tenant, because the repository reads an empty set under FullScope as "no filter".
/// For every widget type: empty effective set -> 0 rows and no query; non-empty -> only its own rows, even if the store
/// returns more (negative half: the foreign row is what the old code passed through).
/// </summary>
public class FullScopeEmptyLeakTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly RunReportWidgetQueryHandler _handler;
    private static readonly DateTime Day = new(2026, 11, 3);

    public FullScopeEmptyLeakTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.Role.Returns("Superadmin");
        _handler = new RunReportWidgetQueryHandler(_repo, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>());

        var t = DateTime.SpecifyKind(Day.AddHours(10), DateTimeKind.Utc);
        _repo.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            new HistQueueInterval { TenantId = TenantId, IntervalStart = t, Workgroup = "Own", Offered = 3, Answered = 2, Abandoned = 1, AnsweredInSl = 1 },
            new HistQueueInterval { TenantId = TenantId, IntervalStart = t, Workgroup = "Foreign", Offered = 100, Answered = 90, Abandoned = 10, AnsweredInSl = 50 }
        });
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            new HistAgentInterval { TenantId = TenantId, IntervalStart = t, AgentExternalId = "own", Handled = 1 },
            new HistAgentInterval { TenantId = TenantId, IntervalStart = t, AgentExternalId = "foreign", Handled = 50 }
        });
    }

    private const string Cfg = """{ "scope": { "businessUnitIds": [7], "agentAxis": "Detail" }, "pageSize": 100 }""";

    private static bool IsAgentType(ReportWidgetType t) => t is ReportWidgetType.EndOfShiftAgents;

    private void Scope(bool empty)
    {
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { FullScope = true, EffectiveWorkgroups = empty ? new HashSet<string>() : new HashSet<string> { "Own" } });
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<AgentReportAxis>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { FullScope = true, EffectiveAgentIds = empty ? new HashSet<string>() : new HashSet<string> { "own" } });
    }

    // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: both end-of-shift reports take dates, not shift hours
    private Task<ReportWidgetResult> Run(ReportWidgetType t) =>
        _handler.Handle(new RunReportWidgetQuery(t, Cfg, Day, Day), CancellationToken.None);

    /// <summary>The volume the result carries: rows, or calls for the BU-aggregated queue types.</summary>
    private static int Volume(ReportWidgetResult r) => r.WidgetType switch
    {
        ReportWidgetType.EndOfShiftAgents => r.AgentSummary!.Rows.Sum(x => x.Handled),
        ReportWidgetType.EndOfShiftQueues => r.QueueSummary!.Rows.Sum(x => x.Offered),
        _ => throw new ArgumentOutOfRangeException()
    };

    // own data: queue Offered 3; agent Handled 1. The foreign rows would add 100 / 50.
    // (QueueInterval, QueueWaitTime, Distribution, AgentMonthly, AgentShiftDetail, AgentPerformance are retired: they answer
    // "retired" before any scope or store call.)
    private static int OwnVolume(ReportWidgetType t) => t switch
    {
        _ when IsAgentType(t) => 1,
        _ => 3
    };

    [Theory]
    [InlineData(ReportWidgetType.EndOfShiftAgents)]
    [InlineData(ReportWidgetType.EndOfShiftQueues)]
    public async Task EmptyEffectiveSet_NoRows_NoQuery(ReportWidgetType type)
    {
        Scope(empty: true);
        var r = await Run(type);

        r.Error.Should().BeNull();
        r.Denied.Should().BeFalse();
        Volume(r).Should().Be(0);
        await _repo.DidNotReceiveWithAnyArgs().GetQueueIntervalsAsync(default, default, default, default!, default!, default);
        await _repo.DidNotReceiveWithAnyArgs().GetAgentIntervalsAsync(default, default, default, default!, default!, default);
    }

    [Theory]
    [InlineData(ReportWidgetType.EndOfShiftAgents)]
    [InlineData(ReportWidgetType.EndOfShiftQueues)]
    public async Task NonEmptySet_OwnRowsOnly_NeverFullScopeToTheStore(ReportWidgetType type)
    {
        Scope(empty: false);
        var r = await Run(type);

        r.Error.Should().BeNull();
        Volume(r).Should().Be(OwnVolume(type));
        if (IsAgentType(type))
            await _repo.Received(1).GetAgentIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
                Arg.Is<ReportScope>(s => !s.FullScope), Arg.Is<IReadOnlySet<string>>(s => s.SetEquals(new[] { "own" })), Arg.Any<CancellationToken>());
        else
            await _repo.Received(1).GetQueueIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
                Arg.Is<ReportScope>(s => !s.FullScope), Arg.Is<IReadOnlySet<string>>(s => s.SetEquals(new[] { "Own" })), Arg.Any<CancellationToken>());
    }
}
