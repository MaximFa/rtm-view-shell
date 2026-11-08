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
/// FEAT-REPORT-QUEUE-TREND-COMPARE-01 (operator 2026-11-07 18:10, 2026-11-08 16:41 / 18:08 / 18:22; contract backend 16:1xZ):
/// the queue trend chart - the intervals of the main period by step (the queues report's StepKey, site time), one value per
/// metric per interval summed over the widget's queues, derived values from the sums; a comparison period from CompareFrom
/// with the main period's length, paired by index. Every rule with its negative half.
/// </summary>
public class QueueTrendTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private const string Cfg = """{ "scope": { "businessUnitIds": [1] } }""";
    private static readonly DateTime Day = new(2026, 11, 3);

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

    public QueueTrendTests()
    {
        _user.TenantId.Returns(TenantId);
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveWorkgroups = new HashSet<string> { "Sales", "Support" } });
        _repo.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(Array.Empty<HistQueueInterval>());
    }

    private static DateTime U(int y, int mo, int d, int h, int mi) => new(y, mo, d, h, mi, 0, DateTimeKind.Utc);

    private static HistQueueInterval Q(DateTime t, string wg, int offered, int answered, long wait) => new()
    { TenantId = TenantId, IntervalStart = t, Workgroup = wg, Offered = offered, Answered = answered, SumWaitAnswered = wait };

    // 06:00 Sales 1 offered / 1 answered / wait 10; 06:00 Support 3 / 3 / 90; 07:00 Sales 10 / 5 / 50
    private void Data() =>
        _repo.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            Q(U(2026, 11, 3, 6, 0), "Sales", 1, 1, 10),
            Q(U(2026, 11, 3, 6, 0), "Support", 3, 3, 90),
            Q(U(2026, 11, 3, 7, 0), "Sales", 10, 5, 50),
        });

    private Task<ReportWidgetResult> Run(ReportStep? step, DateTime? from = null, DateTime? to = null, DateTime? compare = null,
        bool israel = false, string cfg = Cfg) =>
        new RunReportWidgetQueryHandler(_repo, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>(), israel ? new Israel() : null)
            .Handle(new RunReportWidgetQuery(ReportWidgetType.QueueTrend, cfg, from ?? Day, to ?? from ?? Day, Step: step, CompareFrom: compare),
                CancellationToken.None);

    private static QueueTrendSeries S(ReportWidgetResult r, string metric) => r.QueueTrend!.Series.Single(s => s.Metric == metric);

    // ---- metrics ----

    [Fact]
    public void TheMetrics_AreTheQueueRowsCountPercentAndDurationColumns_InTheirOrder()
    {
        ReportWidgetConfig.QueueTrendMetrics.Select(m => m.Name).Should().Equal(
            "Offered", "Answered", "Abandoned", "AnsweredInSl", "SumWaitAnswered", "SumTalk", "AbandonPct", "SlPct", "Asa", "QueueAht");
        // negative half: the text, id and time columns of the row are not metrics
        ReportWidgetConfig.QueueTrendMetrics.Select(m => m.Name).Should().NotContain(new[] { "Workgroup", "QueueId", "IntervalStart" });
    }

    // ---- the grid and the sums ----

    [Fact]
    public async Task ByHour_OnePointPerHourOfTheDay_SummedOverTheQueues_DerivedFromTheSums()
    {
        Data();
        var r = await Run(ReportStep.Hour);

        r.Error.Should().BeNull();
        r.QueueTrend!.Points.Should().HaveCount(24, "the grid comes from the period, not from the data");
        r.QueueTrend.Points[6].Should().Be(new DateTime(2026, 11, 3, 6, 0, 0));
        S(r, "Offered").Values[6].Should().Be(4, "Sales 1 + Support 3");
        S(r, "Offered").Values[7].Should().Be(10);
        // ASA from the sums: (10 + 90) / (1 + 3) = 25 - the mean of the two queues' ASA (10 and 30) would be 20
        S(r, "Asa").Values[6].Should().Be(25);
        // an hour without data: counts 0, derived values null (a gap on the chart, not a false 0 %)
        S(r, "Offered").Values[3].Should().Be(0);
        S(r, "Asa").Values[3].Should().BeNull();
        S(r, "Asa").Kind.Should().Be(ReportColumnKind.DurationSec);
        r.QueueTrend.ComparePoints.Should().BeNull();
        S(r, "Offered").CompareValues.Should().BeNull("negative half: without a comparison date there is no comparison series");
        await _repo.Received(1).GetQueueIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
            Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    [Theory]
    [InlineData(ReportStep.HalfHour, 48)]
    [InlineData(ReportStep.Hour, 24)]
    [InlineData(ReportStep.Day, 1)]
    [InlineData(ReportStep.Month, 1)]
    [InlineData(ReportStep.Year, 1)]
    public async Task TheGrid_HasOnePointPerIntervalOfTheStep(ReportStep step, int points)
    {
        (await Run(step)).QueueTrend!.Points.Should().HaveCount(points);
    }

    [Fact]
    public async Task NoStep_IsTheWidgetsDefault_ThenDay()
    {
        (await Run(null)).QueueTrend!.Step.Should().Be(ReportStep.Day);
        (await Run(null, cfg: """{ "scope": { "businessUnitIds": [1] }, "defaultStep": "hour" }""")).QueueTrend!.Points.Should().HaveCount(24);
    }

    [Fact]
    public async Task Autumn_TheRepeatedHourIsTwoPoints_Spring_23()
    {
        var autumn = (await Run(ReportStep.Hour, new DateTime(2026, 10, 25), israel: true)).QueueTrend!.Points;
        autumn.Should().HaveCount(25);
        autumn.Take(4).Select(p => p.ToString("HH:mm")).Should().Equal("00:00", "01:00", "01:00", "02:00");
        (await Run(ReportStep.Hour, new DateTime(2026, 3, 27), israel: true)).QueueTrend!.Points.Should().HaveCount(23);
    }

    // ---- the comparison ----

    [Fact]
    public async Task TheComparison_StartsAtCompareFrom_AndIsAsLongAsTheMainPeriod_PairedByIndex()
    {
        _repo.GetQueueIntervalsAsync(TenantId, U(2026, 11, 3, 0, 0), U(2026, 11, 5, 0, 0), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>())
            .Returns(new[] { Q(U(2026, 11, 3, 6, 0), "Sales", 2, 2, 20) });
        _repo.GetQueueIntervalsAsync(TenantId, U(2026, 11, 10, 0, 0), U(2026, 11, 12, 0, 0), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>())
            .Returns(new[] { Q(U(2026, 11, 11, 6, 0), "Sales", 7, 7, 70) });

        var r = await Run(ReportStep.Day, Day, Day.AddDays(1), compare: new DateTime(2026, 11, 10));

        r.QueueTrend!.Points.Should().Equal(new DateTime(2026, 11, 3), new DateTime(2026, 11, 4));
        r.QueueTrend.ComparePoints.Should().Equal(new DateTime(2026, 11, 10), new DateTime(2026, 11, 11));
        S(r, "Offered").Values.Should().Equal(2, 0);
        S(r, "Offered").CompareValues.Should().Equal(0, 7);
        (r.QueueTrend.CompareFrom, r.QueueTrend.CompareTo).Should().Be((new DateTime(2026, 11, 10), new DateTime(2026, 11, 11)));
        // negative half: the comparison end is computed, not asked - nothing past 11.11 was read
        await _repo.DidNotReceive().GetQueueIntervalsAsync(TenantId, Arg.Any<DateTime>(), U(2026, 11, 13, 0, 0),
            Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task AShorterComparison_IsPaddedWithNull_ALongerOne_IsCutToTheMainGrid()
    {
        // main 25.10 (25 hours) vs comparison 01.11 (24): the 25th comparison value is null
        var shorter = await Run(ReportStep.Hour, new DateTime(2026, 10, 25), compare: new DateTime(2026, 11, 1), israel: true);
        S(shorter, "Offered").Values.Should().HaveCount(25);
        S(shorter, "Offered").CompareValues.Should().HaveCount(25);
        S(shorter, "Offered").CompareValues![24].Should().BeNull();
        S(shorter, "Offered").CompareValues![23].Should().Be(0, "negative half: a real comparison interval without data is 0, not null");
        shorter.QueueTrend!.ComparePoints.Should().HaveCount(24);

        // main 01.11 (24) vs comparison 25.10 (25): the comparison's 25th hour is dropped
        var longer = await Run(ReportStep.Hour, new DateTime(2026, 11, 1), compare: new DateTime(2026, 10, 25), israel: true);
        S(longer, "Offered").CompareValues.Should().HaveCount(24);
        longer.QueueTrend!.ComparePoints.Should().HaveCount(24);
    }

    // ---- the queues ----

    [Fact]
    public async Task PickedQueues_NarrowTheScope_NeverWiden()
    {
        Data();
        var r = await Run(ReportStep.Hour, cfg: """{ "scope": { "businessUnitIds": [1] }, "workgroups": ["Sales", "Foreign"] }""");

        await _repo.Received(1).GetQueueIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
            Arg.Is<ReportScope>(s => !s.FullScope), Arg.Is<IReadOnlySet<string>>(s => s.SetEquals(new[] { "Sales" })), Arg.Any<CancellationToken>());
        S(r, "Offered").Values[6].Should().Be(1, "Support is not picked; the store's Support row is dropped");
    }

    // ---- refusals ----

    [Fact]
    public async Task TooManyIntervals_IsInvalidConfig_AndTheStoreIsNotAsked()
    {
        // 42 days by half an hour = 2016 > 2000
        var r = await Run(ReportStep.HalfHour, Day, Day.AddDays(41));
        r.ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        await _repo.DidNotReceiveWithAnyArgs().GetQueueIntervalsAsync(default, default, default, default!, default!, default);
        // negative half: 41 days (1968) runs
        (await Run(ReportStep.HalfHour, Day, Day.AddDays(40))).Error.Should().BeNull();
    }

    [Fact]
    public async Task ACompareDate_OnAnotherReport_IsInvalidConfig()
    {
        var r = await new RunReportWidgetQueryHandler(_repo, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>())
            .Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, Cfg, Day, Day, CompareFrom: Day.AddDays(7)), CancellationToken.None);
        r.ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        (await Run(ReportStep.Day, compare: Day.AddDays(7))).Error.Should().BeNull("negative half: on the chart it runs");
    }

    [Fact]
    public async Task SortAndFilters_OnTheChart_AreInvalidConfig()
    {
        var handler = new RunReportWidgetQueryHandler(_repo, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>());
        (await handler.Handle(new RunReportWidgetQuery(ReportWidgetType.QueueTrend, Cfg, Day, Day, SortColumn: "Offered"), CancellationToken.None))
            .ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        (await handler.Handle(new RunReportWidgetQuery(ReportWidgetType.QueueTrend, Cfg, Day, Day,
            Filters: new[] { new ReportColumnFilter("Offered", "greater", Number: 1) }), CancellationToken.None))
            .ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        await _repo.DidNotReceiveWithAnyArgs().GetQueueIntervalsAsync(default, default, default, default!, default!, default);
    }

    [Theory]
    [InlineData(ReportWidgetType.QueueTrend, """{ "scope": { "businessUnitIds": [1] }, "columns": ["Offered"] }""", false)]
    [InlineData(ReportWidgetType.QueueTrend, """{ "scope": { "businessUnitIds": [1] }, "defaultMetrics": ["Offered", "Workgroup"] }""", false)]
    [InlineData(ReportWidgetType.EndOfShiftQueues, """{ "scope": { "businessUnitIds": [1] }, "workgroups": ["Sales"] }""", false)]
    [InlineData(ReportWidgetType.EndOfShiftQueues, """{ "scope": { "businessUnitIds": [1] }, "defaultMetrics": ["Offered"] }""", false)]
    [InlineData(ReportWidgetType.QueueTrend, """{ "scope": { "businessUnitIds": [1] }, "defaultMetrics": ["Offered", "Asa"], "workgroups": ["Sales"], "defaultStep": "hour" }""", true)]
    public async Task TheChartsSettings_AreCheckedOnSave(ReportWidgetType type, string json, bool valid)
    {
        var validator = new CcDashboard.Application.HistoricalReports.Validators.ReportWidgetConfigWithTypeValidator();
        (await validator.ValidateAsync((ReportWidgetConfig.Parse(json), type))).IsValid.Should().Be(valid);
    }
}
