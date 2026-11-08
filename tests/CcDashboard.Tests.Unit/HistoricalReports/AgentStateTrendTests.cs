using CcDashboard.Application.Handlers;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain.Historical;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using Microsoft.Extensions.Logging;
using NSubstitute;
using Xunit;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// FEAT-REPORT-AGENT-STATE-TREND-01 (operator 2026-11-08 21:54-22:04, contract 20:02:22Z, accepted 20:05:25Z): the share of
/// the agents' logged-in time per status group, by step, with a comparison period - by the same trend rule as Queue Trend.
/// Six lines as in ASD: Available, Onphone (Hold inside), Paperwork (+ Unavailable), Break, Training, Other (= the rest).
/// Sums over the agents first, then the share. Every rule with its negative half.
/// </summary>
public class AgentStateTrendTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly ILogger<RunReportWidgetQueryHandler> _log = Substitute.For<ILogger<RunReportWidgetQueryHandler>>();
    private const string Cfg = """{ "scope": { "businessUnitIds": [1] } }""";
    private static readonly DateTime Day = new(2026, 11, 3);

    public AgentStateTrendTests()
    {
        _user.TenantId.Returns(TenantId);
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<AgentReportAxis>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveAgentIds = new HashSet<string> { "a1", "a2" } });
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(Array.Empty<HistAgentInterval>());
    }

    private static DateTime U(int d, int h, int m) => new(2026, 11, d, h, m, 0, DateTimeKind.Utc);

    // minutes, for reading: logged-in 60 = available 10 + onphone 20 (hold 5 inside) + paperwork 6 + unavailable 4 + break 8
    // + training 2 + the rest 10 (unmapped statuses)
    private static HistAgentInterval A(DateTime t, string id = "a1", int scale = 1) => new()
    {
        TenantId = TenantId, IntervalStart = t, AgentExternalId = id,
        SumLoggedInMs = 60 * 60000L * scale, SumAvailableMs = 10 * 60000L * scale, SumOnphoneMs = 20 * 60000L * scale,
        SumHoldMs = 5 * 60000L * scale, SumPaperworkMs = 6 * 60000L * scale, SumUnavailableMs = 4 * 60000L * scale,
        SumBreakMs = 8 * 60000L * scale, SumTrainingMs = 2 * 60000L * scale
    };

    private Task<ReportWidgetResult> Run(ReportStep? step, DateTime? from = null, DateTime? to = null, DateTime? compare = null, string cfg = Cfg) =>
        new RunReportWidgetQueryHandler(_repo, _scope, _user, _log)
            .Handle(new RunReportWidgetQuery(ReportWidgetType.AgentStateTrend, cfg, from ?? Day, to ?? from ?? Day, Step: step, CompareFrom: compare),
                CancellationToken.None);

    private static IReadOnlyList<double?> V(ReportWidgetResult r, string metric) => r.AgentStateTrend!.Series.Single(s => s.Metric == metric).Values;

    [Fact]
    public void TheLines_AreTheSixGroupsOfAsd_AllPercent()
    {
        ReportWidgetConfig.AgentStateTrendMetrics.Select(m => m.Name).Should().Equal("Available", "Onphone", "Paperwork", "Break", "Training", "Other");
        ReportWidgetConfig.AgentStateTrendMetrics.Should().OnlyContain(m => m.Kind == ReportColumnKind.Percent);
        ReportWidgetConfig.AgentStateTrendMetrics.Select(m => m.Name).Should().NotContain(new[] { "Hold", "Unavailable" }, "they are inside Onphone / Paperwork");
    }

    [Fact]
    public async Task TheShares_HoldInsideOnphone_UnavailableInPaperwork_OtherTheRest()
    {
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[] { A(U(3, 6, 0)) });
        var r = await Run(ReportStep.Hour);

        r.Error.Should().BeNull();
        double? At6(string m) => V(r, m)[6];
        At6("Available").Should().BeApproximately(100.0 * 10 / 60, 1e-9);
        At6("Onphone").Should().BeApproximately(100.0 * 20 / 60, 1e-9, "Hold is already inside SumOnphoneMs - adding it would give 25 min");
        At6("Paperwork").Should().BeApproximately(100.0 * 10 / 60, 1e-9, "paperwork 6 + unavailable 4");
        At6("Break").Should().BeApproximately(100.0 * 8 / 60, 1e-9);
        At6("Training").Should().BeApproximately(100.0 * 2 / 60, 1e-9);
        At6("Other").Should().BeApproximately(100.0 * 10 / 60, 1e-9, "the unmapped statuses (operator 22:04)");
        r.AgentStateTrend!.Series.Should().HaveCount(6);
        r.CaveatCode.Should().Be(ReportCaveatCodes.StatusStartBucket);
    }

    [Fact]
    public async Task TheSixShares_AddUpTo100_InEveryIntervalWithALogin()
    {
        // two agents, three intervals, different sizes: the property holds per interval (the strax of 20:05:25Z)
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
            { A(U(3, 6, 0)), A(U(3, 6, 0), "a2", 3), A(U(3, 9, 30), "a2", 2), A(U(3, 15, 0)) });
        var r = await Run(ReportStep.HalfHour);

        var withLogin = Enumerable.Range(0, r.AgentStateTrend!.Points.Count).Where(i => V(r, "Available")[i] is not null).ToList();
        withLogin.Should().HaveCount(3);
        foreach (var i in withLogin)
            ReportWidgetConfig.AgentStateTrendMetrics.Sum(m => V(r, m.Name)[i]!.Value).Should().BeApproximately(100.0, 1e-9);
        // negative half: Paperwork without Unavailable would not add up (Unavailable > 0 here)
        var noUnavailable = 100.0 * (10 + 20 + 6 + 8 + 2 + 10) / 60;
        noUnavailable.Should().NotBeApproximately(100.0, 1e-9);
    }

    [Fact]
    public async Task SumsOverTheAgentsFirst_ThenTheShare_NotTheMeanOfShares()
    {
        var small = new HistAgentInterval { TenantId = TenantId, IntervalStart = U(3, 6, 0), AgentExternalId = "a1", SumLoggedInMs = 60_000, SumAvailableMs = 60_000 };      // 100 %
        var big = new HistAgentInterval { TenantId = TenantId, IntervalStart = U(3, 6, 0), AgentExternalId = "a2", SumLoggedInMs = 540_000, SumAvailableMs = 0 };          // 0 %
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[] { small, big });

        V(await Run(ReportStep.Hour), "Available")[6].Should().BeApproximately(10.0, 1e-9, "60 s of 600 s - the mean of 100 % and 0 % would be 50 %");
    }

    [Fact]
    public async Task AnIntervalWithoutLogin_IsNullForAllSix_NotZero()
    {
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[] { A(U(3, 6, 0)) });
        var r = await Run(ReportStep.Hour);
        r.AgentStateTrend!.Series.Should().OnlyContain(s => s.Values[3] == null, "a gap on the chart, not a false 0 %");
        r.AgentStateTrend.Series.Should().OnlyContain(s => s.Values[6] != null, "negative half: the hour with data has values");
    }

    [Fact]
    public async Task ANegativeOther_IsShownAsItIs_AndCountedInTheLog()
    {
        // a broken source: the groups exceed the login (a negative duration somewhere)
        var broken = new HistAgentInterval { TenantId = TenantId, IntervalStart = U(3, 6, 0), AgentExternalId = "a1", SumLoggedInMs = 60_000, SumAvailableMs = 90_000 };
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[] { broken });

        V(await Run(ReportStep.Hour), "Other")[6].Should().BeApproximately(-50.0, 1e-9, "never hidden as 0");
        _log.ReceivedCalls().Should().Contain(c => c.GetMethodInfo().Name == "Log" && c.GetArguments()[0]!.Equals(LogLevel.Warning)
            && c.GetArguments()[2]!.ToString()!.Contains("negative Other"));
    }

    [Fact]
    public async Task AHealthyInterval_LogsNothingAboutOther()
    {
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[] { A(U(3, 6, 0)) });
        await Run(ReportStep.Hour);
        _log.ReceivedCalls().Should().NotContain(c => c.GetMethodInfo().Name == "Log" && c.GetArguments()[2]!.ToString()!.Contains("negative Other"));
    }

    [Fact]
    public async Task TheComparison_IsTheSameRuleAsQueueTrend()
    {
        _repo.GetAgentIntervalsAsync(TenantId, U(10, 0, 0), U(12, 0, 0), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>())
            .Returns(new[] { A(U(11, 6, 0)) });
        var r = await Run(ReportStep.Day, Day, Day.AddDays(1), compare: new DateTime(2026, 11, 10));

        r.AgentStateTrend!.ComparePoints.Should().Equal(new DateTime(2026, 11, 10), new DateTime(2026, 11, 11));
        var avail = r.AgentStateTrend.Series.Single(s => s.Metric == "Available");
        avail.Values.Should().OnlyContain(v => v == null).And.HaveCount(2, "no login in the main period");
        avail.CompareValues![0].Should().BeNull();
        avail.CompareValues[1].Should().BeApproximately(100.0 * 10 / 60, 1e-9);
    }

    [Fact]
    public async Task PickedAgents_NarrowTheScope_NeverWiden()
    {
        await Run(ReportStep.Day, cfg: """{ "scope": { "businessUnitIds": [1] }, "agentIds": ["a2", "x9"] }""");
        await _repo.Received(1).GetAgentIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
            Arg.Is<ReportScope>(s => !s.FullScope), Arg.Is<IReadOnlySet<string>>(s => s.SetEquals(new[] { "a2" })), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task SortFiltersAndRowMode_OnTheChart_AreInvalidConfig_TheLimitIsShared()
    {
        var h = new RunReportWidgetQueryHandler(_repo, _scope, _user, _log);
        (await h.Handle(new RunReportWidgetQuery(ReportWidgetType.AgentStateTrend, Cfg, Day, Day, SortColumn: "Available"), CancellationToken.None))
            .ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        (await h.Handle(new RunReportWidgetQuery(ReportWidgetType.AgentStateTrend, Cfg, Day, Day, RowMode: ReportRowMode.ByStep), CancellationToken.None))
            .ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        (await Run(ReportStep.HalfHour, Day, Day.AddDays(41))).ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig, "2016 > 2000");
        await _repo.DidNotReceiveWithAnyArgs().GetAgentIntervalsAsync(default, default, default, default!, default!, default);
    }

    [Theory]
    [InlineData(ReportWidgetType.AgentStateTrend, """{ "scope": { "businessUnitIds": [1] }, "defaultMetrics": ["Available", "Other"], "defaultStep": "hour", "agentIds": ["a1"] }""", true)]
    [InlineData(ReportWidgetType.AgentStateTrend, """{ "scope": { "businessUnitIds": [1] }, "defaultMetrics": ["Offered"] }""", false)]
    [InlineData(ReportWidgetType.QueueTrend, """{ "scope": { "businessUnitIds": [1] }, "defaultMetrics": ["Available"] }""", false)]
    [InlineData(ReportWidgetType.AgentStateTrend, """{ "scope": { "businessUnitIds": [1] }, "workgroups": ["Sales"] }""", false)]
    [InlineData(ReportWidgetType.AgentStateTrend, """{ "scope": { "businessUnitIds": [1] }, "columns": ["Available"] }""", false)]
    public async Task TheChartsSettings_AreCheckedOnSave(ReportWidgetType type, string json, bool valid)
    {
        var validator = new CcDashboard.Application.HistoricalReports.Validators.ReportWidgetConfigWithTypeValidator();
        (await validator.ValidateAsync((ReportWidgetConfig.Parse(json), type))).IsValid.Should().Be(valid);
    }
}
