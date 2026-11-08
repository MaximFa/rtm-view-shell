using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using Microsoft.Extensions.Logging;
using NSubstitute;
using Xunit;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// FEAT-REPORT-DEFAULT-LAST-DATA-DAY-01: the default date of a report screen = the last LOCAL day with data in the
/// widget's scope (EOS queues: hist_queue_intervals). Scope as the widget run resolves it; nothing in scope - nothing asked.
/// </summary>
public class LastDataDayTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private const string Cfg = """{ "scope": { "businessUnitIds": [1] } }""";
    private static readonly HashSet<string> Own = new() { "Sales", "Support" };

    private sealed class Israel : IDisplayTimeZone
    {
        public TimeZoneInfo Zone { get; } = Resolve();
        private static TimeZoneInfo Resolve()
        {
            foreach (var id in new[] { "Israel Standard Time", "Asia/Jerusalem" })
            {
                try { return TimeZoneInfo.FindSystemTimeZoneById(id); } catch (TimeZoneNotFoundException) { }
            }
            throw new InvalidOperationException("no Israel time zone on this machine");
        }
    }

    public LastDataDayTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.Role.Returns("Admin");
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveWorkgroups = Own });
    }

    private GetLastDataDayQueryHandler Handler(bool israel = true) =>
        new(_repo, _scope, _user, Substitute.For<ILogger<GetLastDataDayQueryHandler>>(), israel ? new Israel() : null);

    private void LastAt(DateTime? utc) =>
        _repo.GetLastIntervalStartAsync(default, default, default!, default).ReturnsForAnyArgs(utc);

    private Task<LastDataDayResult> Run(ReportWidgetType type = ReportWidgetType.EndOfShiftQueues, string cfg = Cfg, bool israel = true, Guid? tenant = null) =>
        Handler(israel).Handle(new GetLastDataDayQuery(type, cfg, tenant), CancellationToken.None);

    private Task NoStoreCall() => _repo.DidNotReceiveWithAnyArgs().GetLastIntervalStartAsync(default, default, default!, default);

    [Fact]
    public async Task LastBucket_IsTheLocalDay_AskedForTheWidgetScope()
    {
        // as on 234 (devops 10:08:47Z): the last interval 06.11 13:30 (+02) = 11:30Z -> 06.11
        LastAt(new DateTime(2026, 11, 6, 11, 30, 0, DateTimeKind.Utc));
        var r = await Run();

        r.Should().Be(new LastDataDayResult(new DateOnly(2026, 11, 6)));
        await _repo.Received(1).GetLastIntervalStartAsync(TenantId, ReportDataSet.Queues,
            Arg.Is<IReadOnlySet<string>>(s => s.SetEquals(Own)), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task ABucketAfterLocalMidnight_IsTheNextDay_InTheSiteZone_NotInUtc()
    {
        LastAt(new DateTime(2026, 11, 6, 22, 30, 0, DateTimeKind.Utc));   // 07.11 00:30 (+02)
        (await Run()).Day.Should().Be(new DateOnly(2026, 11, 7));
        (await Run(israel: false)).Day.Should().Be(new DateOnly(2026, 11, 6), "negative half: without the zone the UTC date is read");
    }

    [Fact]
    public async Task NoRowInScope_IsNoDay_WithoutAReason()
    {
        LastAt(null);
        (await Run()).Should().Be(new LastDataDayResult(null));
    }

    [Fact]
    public async Task EmptyScope_IsNoDay_AndTheStoreIsNotAsked()
    {
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { FullScope = true, EffectiveWorkgroups = new HashSet<string>() });
        LastAt(new DateTime(2026, 11, 6, 11, 30, 0, DateTimeKind.Utc));

        (await Run()).Should().Be(new LastDataDayResult(null));
        await NoStoreCall();
    }

    [Fact]
    public async Task Denied_IsDenied_AndTheStoreIsNotAsked()
    {
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult());   // no full scope, nothing effective, nothing dropped = denied

        (await Run()).Should().Be(new LastDataDayResult(null, ReportReasonCodes.Denied));
        await NoStoreCall();
    }

    [Theory]
    [InlineData(ReportWidgetType.Distribution, ReportReasonCodes.Retired)]
    [InlineData(ReportWidgetType.AgentMonthly, ReportReasonCodes.Retired)]
    [InlineData(ReportWidgetType.EndOfShiftQueues + 100, ReportReasonCodes.InvalidConfig)]   // a type the rule does not know
    public async Task TypesTheRuleDoesNotCover_SaySo_AndTheStoreIsNotAsked(ReportWidgetType type, string code)
    {
        (await Run(type)).Should().Be(new LastDataDayResult(null, code));
        await NoStoreCall();
    }

    [Fact]
    public async Task BrokenConfig_IsInvalidConfig()
    {
        (await Run(cfg: "{ not json")).Should().Be(new LastDataDayResult(null, ReportReasonCodes.InvalidConfig));
        await NoStoreCall();
    }

    [Fact]
    public async Task ATenantOnTheQuery_IsIgnoredForANonSuperadmin()
    {
        LastAt(new DateTime(2026, 11, 6, 11, 30, 0, DateTimeKind.Utc));
        await Run(tenant: Guid.NewGuid());
        await _repo.Received(1).GetLastIntervalStartAsync(TenantId, ReportDataSet.Queues, Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    // ---- FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01 (coordinator 06:27:37Z): the agents report joins the same rule ----

    private void AgentScope(params string[] ids) =>
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), AgentReportAxis.Detail, Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveAgentIds = new HashSet<string>(ids) });

    [Fact]
    public async Task Agents_LastBucket_IsTheLocalDay_AskedForTheAgentsTheWidgetShows()
    {
        AgentScope("a1", "a2", "a3");
        LastAt(new DateTime(2026, 11, 6, 22, 30, 0, DateTimeKind.Utc));   // 07.11 00:30 (+02)
        var r = await Run(ReportWidgetType.EndOfShiftAgents, """{ "scope": { "businessUnitIds": [1] }, "agentIds": ["a2", "x9"] }""");

        r.Should().Be(new LastDataDayResult(new DateOnly(2026, 11, 7)));
        // the widget's picked agents narrow the scope (x9 is outside it) - the run's own rule, not a second one
        await _repo.Received(1).GetLastIntervalStartAsync(TenantId, ReportDataSet.Agents,
            Arg.Is<IReadOnlySet<string>>(k => k.SetEquals(new[] { "a2" })), Arg.Any<CancellationToken>());
        await _repo.DidNotReceive().GetLastIntervalStartAsync(TenantId, ReportDataSet.Queues, Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Agents_PickedOnlyOutsideTheScope_IsNoDay_AndTheStoreIsNotAsked()
    {
        AgentScope("a1");
        var r = await Run(ReportWidgetType.EndOfShiftAgents, """{ "scope": { "businessUnitIds": [1] }, "agentIds": ["x9"] }""");
        r.Should().Be(new LastDataDayResult(null));
        await NoStoreCall();
    }

    [Fact]
    public async Task Agents_Denied_IsDenied()
    {
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), AgentReportAxis.Detail, Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult());
        (await Run(ReportWidgetType.EndOfShiftAgents)).Should().Be(new LastDataDayResult(null, ReportReasonCodes.Denied));
        await NoStoreCall();
    }
}
