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
/// FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01 (operator 2026-11-08 07:54, contract 06:08:14Z, accepted 06:27:37Z): the agents
/// report takes the same configuration as the queues report - From..To, a step with a default, plus a row mode: Summary
/// (one row per agent for the period, no step) or ByStep (one row per interval and agent). Rule for both: the viewer's own
/// choice -> the widget's default -> Day / Summary.
/// </summary>
public class AgentReportConfigurableTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private const string Cfg = """{ "scope": { "businessUnitIds": [1] }, "pageSize": 200 }""";

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

    public AgentReportConfigurableTests()
    {
        _user.TenantId.Returns(TenantId);
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<AgentReportAxis>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveAgentIds = new HashSet<string> { "a1", "a2" } });
    }

    private static DateTime U(int y, int mo, int d, int h, int mi) => new(y, mo, d, h, mi, 0, DateTimeKind.Utc);

    private static HistAgentInterval A(DateTime t, string id = "a1", int handled = 1) => new()
    { TenantId = TenantId, IntervalStart = t, AgentExternalId = id, AgentDisplayName = id, Handled = handled, SumAvailableMs = 1000 };

    private void Buckets(IEnumerable<HistAgentInterval> rows) =>
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(rows.ToList());

    private static IEnumerable<HistAgentInterval> Every30(DateTime fromUtc, DateTime toUtc)
    {
        for (var t = fromUtc; t < toUtc; t = t.AddMinutes(30)) yield return A(t);
    }

    private Task<ReportWidgetResult> Run(ReportRowMode? mode, ReportStep? step, DateTime from, DateTime? to = null,
        bool israel = false, string cfg = Cfg) =>
        new RunReportWidgetQueryHandler(_repo, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>(), israel ? new Israel() : null)
            .Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftAgents, cfg, from, to ?? from, Step: step, RowMode: mode), CancellationToken.None);

    private void ThreeBuckets() => Buckets(new[]
    {
        A(U(2026, 11, 3, 6, 0), handled: 1), A(U(2026, 11, 3, 6, 30), handled: 5), A(U(2026, 11, 3, 7, 0), handled: 10),
        A(U(2026, 11, 3, 6, 0), "a2", 3),
    });

    private static IEnumerable<string> Rows(ReportWidgetResult r) =>
        r.AgentSummary!.Rows.Select(x => $"{x.IntervalStart:HH:mm} {x.AgentExternalId} {x.Handled}");

    // ---- steps, by step ----

    [Fact]
    public async Task ByStep_HalfHourHourDay_GroupLikeTheQueuesReport()
    {
        ThreeBuckets();
        Rows(await Run(ReportRowMode.ByStep, ReportStep.HalfHour, new DateTime(2026, 11, 3)))
            .Should().Equal("06:00 a1 1", "06:00 a2 3", "06:30 a1 5", "07:00 a1 10");
        Rows(await Run(ReportRowMode.ByStep, ReportStep.Hour, new DateTime(2026, 11, 3)))
            .Should().Equal("06:00 a1 6", "06:00 a2 3", "07:00 a1 10");
        Rows(await Run(ReportRowMode.ByStep, ReportStep.Day, new DateTime(2026, 11, 3)))
            .Should().Equal("00:00 a1 16", "00:00 a2 3");
    }

    [Fact]
    public async Task ByStep_MonthAndYear_AreTheLocalMonthAndYear()
    {
        // 31.10 23:30 local (+02) = 21:30Z stays in October; 01.01.2026 00:30 local = 31.12.2025 22:30Z is 2026
        Buckets(new[] { A(U(2026, 10, 31, 21, 30)), A(U(2026, 10, 31, 22, 0)), A(U(2025, 12, 31, 22, 30)) });

        var month = await Run(ReportRowMode.ByStep, ReportStep.Month, new DateTime(2025, 12, 1), new DateTime(2026, 11, 30), israel: true);
        month.AgentSummary!.Rows.Select(x => $"{x.IntervalStart:MM.yyyy} {x.Handled}").Should().Equal("01.2026 1", "10.2026 1", "11.2026 1");

        var year = await Run(ReportRowMode.ByStep, ReportStep.Year, new DateTime(2025, 12, 1), new DateTime(2026, 11, 30), israel: true);
        year.AgentSummary!.Rows.Select(x => $"{x.IntervalStart:yyyy} {x.Handled}").Should().Equal(new[] { "2026 3" }, "negative half: in UTC one bucket would be 2025");
    }

    [Fact]
    public async Task ByStep_Autumn_TheRepeatedHourIsTwoRowsInTimeOrder_Spring_23Hours()
    {
        Buckets(Every30(U(2026, 10, 24, 21, 0), U(2026, 10, 25, 22, 0)));   // local 25.10, 25 h = 50 buckets
        var autumn = await Run(ReportRowMode.ByStep, ReportStep.Hour, new DateTime(2026, 10, 25), israel: true);
        var shown = autumn.AgentSummary!.Rows.Select(x => x.IntervalStart!.Value.ToString("HH:mm")).ToList();
        shown.Should().HaveCount(25);
        shown.Take(4).Should().Equal("00:00", "01:00", "01:00", "02:00");
        autumn.AgentSummary.Rows.Should().OnlyContain(x => x.Handled == 2);

        Buckets(Every30(U(2026, 3, 26, 22, 0), U(2026, 3, 27, 21, 0)));     // local 27.03, 23 h = 46 buckets
        var spring = await Run(ReportRowMode.ByStep, ReportStep.Day, new DateTime(2026, 3, 27), israel: true);
        spring.AgentSummary!.Rows.Should().ContainSingle().Which.Handled.Should().Be(46, "23 hours, not 24 (48)");
    }

    // ---- summary ----

    [Fact]
    public async Task Summary_OneRowPerAgent_TheStepDoesNotApply()
    {
        ThreeBuckets();
        var r = await Run(ReportRowMode.Summary, ReportStep.HalfHour, new DateTime(2026, 11, 3));

        Rows(r).Should().Equal(" a1 16", " a2 3");
        r.Step.Should().BeNull("a step sent with Summary is not applied");
        r.RowMode.Should().Be(ReportRowMode.Summary);
        (r.PartialFirst, r.PartialLast).Should().Be((false, false));
    }

    // ---- the one rule: own choice -> default -> Summary / Day ----

    private const string ByStepHourDefault = """{ "scope": { "businessUnitIds": [1] }, "defaultRowMode": "byStep", "defaultStep": "hour", "pageSize": 200 }""";

    [Fact]
    public async Task NothingAnywhere_IsSummary()
    {
        ThreeBuckets();
        var r = await Run(null, null, new DateTime(2026, 11, 3));
        r.RowMode.Should().Be(ReportRowMode.Summary);
        r.AgentSummary!.Rows.Should().HaveCount(2);
    }

    [Fact]
    public async Task NoChoiceOnTheQuery_TakesTheWidgetsDefaults()
    {
        ThreeBuckets();
        var r = await Run(null, null, new DateTime(2026, 11, 3), cfg: ByStepHourDefault);
        (r.RowMode, r.Step).Should().Be((ReportRowMode.ByStep, ReportStep.Hour));
        r.AgentSummary!.Rows.Should().HaveCount(3, "by hour; Summary would give 2, by day 2");
    }

    [Fact]
    public async Task TheViewersOwnChoice_WinsOverTheDefaults()
    {
        ThreeBuckets();
        var summary = await Run(ReportRowMode.Summary, null, new DateTime(2026, 11, 3), cfg: ByStepHourDefault);
        summary.RowMode.Should().Be(ReportRowMode.Summary);
        summary.AgentSummary!.Rows.Should().HaveCount(2);

        var half = await Run(null, ReportStep.HalfHour, new DateTime(2026, 11, 3), cfg: ByStepHourDefault);
        (half.RowMode, half.Step).Should().Be((ReportRowMode.ByStep, ReportStep.HalfHour));
        half.AgentSummary!.Rows.Should().HaveCount(4);
    }

    [Fact]
    public async Task ByStepWithoutAnyStep_IsByDay()
    {
        ThreeBuckets();
        var r = await Run(ReportRowMode.ByStep, null, new DateTime(2026, 11, 3));
        r.Step.Should().Be(ReportStep.Day);
        r.AgentSummary!.Rows.Should().HaveCount(2);
    }

    // ---- columns ----

    [Fact]
    public async Task Columns_ByStep_IntervalStartFirst_Summary_WithoutIt_EvenWhenPicked()
    {
        ThreeBuckets();
        const string picked = """{ "scope": { "businessUnitIds": [1] }, "columns": ["Handled", "IntervalStart", "AgentExternalId"] }""";
        (await Run(ReportRowMode.ByStep, ReportStep.Day, new DateTime(2026, 11, 3), cfg: picked)).EffectiveColumns
            .Should().Equal("IntervalStart", "Handled", "AgentExternalId");
        (await Run(ReportRowMode.Summary, null, new DateTime(2026, 11, 3), cfg: picked)).EffectiveColumns
            .Should().Equal("Handled", "AgentExternalId");
    }

    [Fact]
    public async Task ASavedDateColumn_ReadsAsIntervalStart()
    {
        ThreeBuckets();
        const string saved = """{ "scope": { "businessUnitIds": [1] }, "columns": ["Date", "Handled"] }""";
        var r = await Run(ReportRowMode.ByStep, ReportStep.Day, new DateTime(2026, 11, 3), cfg: saved);
        r.Error.Should().BeNull("the retired field name is accepted, not refused as an unknown column");
        r.EffectiveColumns.Should().Equal("IntervalStart", "Handled");
        // negative half: an unknown name is still refused, and the alias belongs to the agents report only
        (await Run(null, null, new DateTime(2026, 11, 3), cfg: """{ "scope": { "businessUnitIds": [1] }, "columns": ["Datum"] }"""))
            .ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        ReportWidgetConfig.LegacyColumnAliases(ReportWidgetType.EndOfShiftQueues).Should().BeEmpty();
    }

    // ---- edges ----

    [Fact]
    public async Task PeriodCuttingTheMonth_IsFlagged_ForTheAgentsToo()
    {
        ThreeBuckets();
        var cut = await Run(ReportRowMode.ByStep, ReportStep.Month, new DateTime(2026, 11, 3), new DateTime(2026, 11, 7), israel: true);
        (cut.PartialFirst, cut.PartialLast).Should().Be((true, true));
        var whole = await Run(ReportRowMode.ByStep, ReportStep.Month, new DateTime(2026, 11, 1), new DateTime(2026, 11, 30), israel: true);
        (whole.PartialFirst, whole.PartialLast).Should().Be((false, false), "negative half");
    }
}
