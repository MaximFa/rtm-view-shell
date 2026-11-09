using CcDashboard.Application.Handlers;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Domain.Domain.Historical;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using Microsoft.Extensions.Logging;
using NSubstitute;
using Xunit;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// FEAT-REPORT-AGENT-STATE-DISTRIBUTION-01 (operator 2026-11-09 06:41, contract 04:42:41Z, coordinator 04:43:29Z): the six
/// groups of the agent state trend for the whole period as one donut - the same rule (AgentStateMs), the same scope; the
/// period is the From..To the screen sends (its own or the page's). Every rule with its negative half.
/// </summary>
public class AgentStateDistributionTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly ILogger<RunReportWidgetQueryHandler> _log = Substitute.For<ILogger<RunReportWidgetQueryHandler>>();
    private const string Cfg = """{ "scope": { "businessUnitIds": [1] } }""";
    private static readonly DateTime Day = new(2026, 11, 3);

    public AgentStateDistributionTests()
    {
        _user.TenantId.Returns(TenantId);
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<AgentReportAxis>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveAgentIds = new HashSet<string> { "a1", "a2" } });
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(Array.Empty<HistAgentInterval>());
    }

    private static DateTime U(int d, int h) => new(2026, 11, d, h, 0, 0, DateTimeKind.Utc);

    // minutes: login 60 = available 10 + onphone 20 (hold 5 inside) + paperwork 6 + unavailable 4 + break 8 + training 2 + rest 10
    private static HistAgentInterval A(DateTime t, string id = "a1", int scale = 1) => new()
    {
        TenantId = TenantId, IntervalStart = t, AgentExternalId = id,
        SumLoggedInMs = 60 * 60000L * scale, SumAvailableMs = 10 * 60000L * scale, SumOnphoneMs = 20 * 60000L * scale,
        SumHoldMs = 5 * 60000L * scale, SumPaperworkMs = 6 * 60000L * scale, SumUnavailableMs = 4 * 60000L * scale,
        SumBreakMs = 8 * 60000L * scale, SumTrainingMs = 2 * 60000L * scale
    };

    private Task<ReportWidgetResult> Run(DateTime? from = null, DateTime? to = null, string cfg = Cfg) =>
        new RunReportWidgetQueryHandler(_repo, _scope, _user, _log)
            .Handle(new RunReportWidgetQuery(ReportWidgetType.AgentStateDistribution, cfg, from ?? Day, to ?? from ?? Day), CancellationToken.None);

    private void Data(params HistAgentInterval[] rows) =>
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(rows);

    [Fact]
    public async Task TheSixGroups_ForThePeriod_InMsAndShare_AddingUpToTheLogin()
    {
        Data(A(U(3, 6)), A(U(3, 9), "a2", 3));   // 60 + 180 min of login
        var d = (await Run()).AgentStateDistribution!;

        d.LoggedInMs.Should().Be(240 * 60000L);
        d.AgentCount.Should().Be(2);
        d.Groups.Select(g => g.Metric).Should().Equal("Available", "Onphone", "Paperwork", "Break", "Training", "Other");
        d.Groups.Single(g => g.Metric == "Onphone").Ms.Should().Be(80 * 60000L, "Hold is inside Onphone - not added (it would be 100 min)");
        d.Groups.Single(g => g.Metric == "Paperwork").Ms.Should().Be(40 * 60000L, "paperwork 24 + unavailable 16");
        d.Groups.Single(g => g.Metric == "Other").Ms.Should().Be(40 * 60000L);
        d.Groups.Sum(g => g.Ms).Should().Be(d.LoggedInMs, "the six add up to the login, so the donut's own percent is the share");
        d.Groups.Single(g => g.Metric == "Available").Share.Should().BeApproximately(100.0 * 40 / 240, 1e-9);
        (d.From, d.To).Should().Be((Day, Day));
    }

    [Fact]
    public async Task TheDonut_IsTheTrendsOwnRule_SummedOverThePeriod()
    {
        // one rule: the donut's shares equal the trend's shares of the same rows taken as one bucket
        var tiny = new HistAgentInterval { TenantId = TenantId, IntervalStart = U(4, 13), AgentExternalId = "a2", SumLoggedInMs = 60_000, SumAvailableMs = 60_000 };
        var rows = new[] { A(U(3, 6)), A(U(3, 9), "a2", 3), A(U(4, 12), "a1", 2), tiny };
        Data(rows);
        var donut = (await Run(Day, Day.AddDays(1))).AgentStateDistribution!;
        var trendRule = RunReportWidgetQueryHandler.AgentStateShares(rows);
        foreach (var g in donut.Groups)
            g.Share.Should().BeApproximately(trendRule[g.Metric]!.Value, 1e-9, g.Metric);
        // negative half: the mean of per-row shares differs here (the 1-minute row is 100 % available) - the donut is not it
        var mean = rows.Average(r => RunReportWidgetQueryHandler.AgentStateShares(new[] { r })["Available"]!.Value);
        mean.Should().NotBeApproximately(donut.Groups[0].Share!.Value, 1e-6);
    }

    [Fact]
    public async Task NoLoginInThePeriod_IsNullShares_AndZeroAgents_NotAnEmptyRingOfZeros()
    {
        var d = (await Run()).AgentStateDistribution!;
        d.LoggedInMs.Should().Be(0);
        d.AgentCount.Should().Be(0);
        d.Groups.Should().OnlyContain(g => g.Share == null && g.Ms == 0);
        Data(A(U(3, 6)));
        (await Run()).AgentStateDistribution!.Groups.Should().OnlyContain(g => g.Share != null, "negative half: with a login there are shares");
    }

    [Fact]
    public async Task ThePeriod_IsTheOneTheScreenSends()
    {
        await Run(new DateTime(2026, 11, 1), new DateTime(2026, 11, 7));
        await _repo.Received(1).GetAgentIntervalsAsync(TenantId, U(1, 0), U(8, 0), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task PickedAgents_NarrowTheScope_AndAnAgentWithoutLogin_IsNotCounted()
    {
        // a1 has a row but no login time in the period: it is not a connected agent of the donut's centre
        Data(A(U(3, 6), "a2"), new HistAgentInterval { TenantId = TenantId, IntervalStart = U(3, 7), AgentExternalId = "a1" });
        var d = (await Run(cfg: """{ "scope": { "businessUnitIds": [1] }, "agentIds": ["a2", "a1", "x9"] }""")).AgentStateDistribution!;
        d.AgentCount.Should().Be(1, "negative half: counting rows' agents would give 2");
        await _repo.Received(1).GetAgentIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
            Arg.Is<ReportScope>(s => !s.FullScope), Arg.Is<IReadOnlySet<string>>(s => s.SetEquals(new[] { "a2", "a1" })), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task ANegativeOther_IsGivenAsItIs_AndLogged()
    {
        Data(new HistAgentInterval { TenantId = TenantId, IntervalStart = U(3, 6), AgentExternalId = "a1", SumLoggedInMs = 60_000, SumAvailableMs = 90_000 });
        (await Run()).AgentStateDistribution!.Groups.Single(g => g.Metric == "Other").Ms.Should().Be(-30_000);
        _log.ReceivedCalls().Should().Contain(c => c.GetMethodInfo().Name == "Log" && c.GetArguments()[2]!.ToString()!.Contains("negative Other"));
    }

    [Fact]
    public async Task StepCompareSortAndRowMode_AreInvalidConfig_TheStoreIsNotAsked()
    {
        var h = new RunReportWidgetQueryHandler(_repo, _scope, _user, _log);
        foreach (var q in new[]
        {
            new RunReportWidgetQuery(ReportWidgetType.AgentStateDistribution, Cfg, Day, Day, Step: ReportStep.Hour),
            new RunReportWidgetQuery(ReportWidgetType.AgentStateDistribution, Cfg, Day, Day, CompareFrom: Day.AddDays(7)),
            new RunReportWidgetQuery(ReportWidgetType.AgentStateDistribution, Cfg, Day, Day, SortColumn: "Available"),
            new RunReportWidgetQuery(ReportWidgetType.AgentStateDistribution, Cfg, Day, Day, RowMode: ReportRowMode.ByStep),
        })
            (await h.Handle(q, CancellationToken.None)).ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        await _repo.DidNotReceiveWithAnyArgs().GetAgentIntervalsAsync(default, default, default, default!, default!, default);
        (await Run()).Error.Should().BeNull("negative half: the plain query runs");
    }

    [Theory]
    [InlineData("""{ "scope": { "businessUnitIds": [1] }, "agentIds": ["a1"] }""", true)]
    [InlineData("""{ "scope": { "businessUnitIds": [1] }, "defaultStep": "hour" }""", false)]
    [InlineData("""{ "scope": { "businessUnitIds": [1] }, "defaultMetrics": ["Available"] }""", false)]
    [InlineData("""{ "scope": { "businessUnitIds": [1] }, "workgroups": ["Sales"] }""", false)]
    [InlineData("""{ "scope": { "businessUnitIds": [1] }, "columns": ["Available"] }""", false)]
    public async Task TheDonutsSettings_AreCheckedOnSave(string json, bool valid)
    {
        var validator = new CcDashboard.Application.HistoricalReports.Validators.ReportWidgetConfigWithTypeValidator();
        (await validator.ValidateAsync((ReportWidgetConfig.Parse(json), ReportWidgetType.AgentStateDistribution))).IsValid.Should().Be(valid);
    }
}
