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
/// FEAT-REPORT-EOS-CONFIGURABLE-01 (contract 09:05:19Z): the end-of-shift queues report covers whole local days From..To,
/// grouped by a Step (Day / Hour / HalfHour, default Day); it takes no shift hours. A local day is 23 / 24 / 25 hours long;
/// the repeated hour of the autumn change gives two "01:00" rows in time order (variant (a)).
/// </summary>
public class EndOfShiftQueuesStepTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private const string Cfg = """{ "scope": { "businessUnitIds": [1] }, "pageSize": 100 }""";

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

    public EndOfShiftQueuesStepTests()
    {
        _user.TenantId.Returns(TenantId);
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveWorkgroups = new HashSet<string> { "Sales", "Support" } });
    }

    private RunReportWidgetQueryHandler Handler(bool israel = false) =>
        new(_repo, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>(), israel ? new Israel() : null);

    private static DateTime U(int y, int mo, int d, int h, int mi) => new(y, mo, d, h, mi, 0, DateTimeKind.Utc);

    private static HistQueueInterval Q(DateTime t, string wg = "Sales", int offered = 1) => new()
    { TenantId = TenantId, IntervalStart = t, Workgroup = wg, Offered = offered, Answered = offered };

    private void Buckets(IEnumerable<HistQueueInterval> rows) =>
        _repo.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(rows.ToList());

    /// <summary>Every half-hour bucket from <paramref name="fromUtc"/> (incl.) to <paramref name="toUtc"/> (excl.), Offered 1.</summary>
    private static IEnumerable<HistQueueInterval> Every30(DateTime fromUtc, DateTime toUtc)
    {
        for (var t = fromUtc; t < toUtc; t = t.AddMinutes(30)) yield return Q(t);
    }

    private Task<ReportWidgetResult> Run(ReportStep? step, DateTime from, DateTime? to = null, bool israel = false, string cfg = Cfg) =>
        Handler(israel).Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, cfg, from, to ?? from, Step: step), CancellationToken.None);

    // ---- grouping by step (UTC zone) ----

    private void ThreeBuckets() => Buckets(new[]
    {
        Q(U(2026, 11, 3, 6, 0), offered: 1), Q(U(2026, 11, 3, 6, 30), offered: 5), Q(U(2026, 11, 3, 7, 0), offered: 10),
        Q(U(2026, 11, 3, 6, 0), "Support", 3),
    });

    [Fact]
    public async Task HalfHour_OneRowPerBucketAndQueue()
    {
        ThreeBuckets();
        var r = await Run(ReportStep.HalfHour, new DateTime(2026, 11, 3));

        r.Error.Should().BeNull();
        r.Step.Should().Be(ReportStep.HalfHour);
        r.QueueSummary!.Rows.Select(x => $"{x.IntervalStart:HH:mm} {x.Workgroup} {x.Offered}")
            .Should().Equal("06:00 Sales 1", "06:00 Support 3", "06:30 Sales 5", "07:00 Sales 10");
    }

    [Fact]
    public async Task Hour_SumsTheTwoHalfHoursOfTheHour()
    {
        ThreeBuckets();
        var r = await Run(ReportStep.Hour, new DateTime(2026, 11, 3));

        r.QueueSummary!.Rows.Select(x => $"{x.IntervalStart:HH:mm} {x.Workgroup} {x.Offered}")
            .Should().Equal("06:00 Sales 6", "06:00 Support 3", "07:00 Sales 10");
    }

    [Fact]
    public async Task NoStep_IsDay_OneRowPerQueue()
    {
        ThreeBuckets();
        var r = await Run(null, new DateTime(2026, 11, 3));

        r.Step.Should().Be(ReportStep.Day);
        r.QueueSummary!.Rows.Select(x => $"{x.IntervalStart:yyyy-MM-dd HH:mm} {x.Workgroup} {x.Offered}")
            .Should().Equal("2026-11-03 00:00 Sales 16", "2026-11-03 00:00 Support 3");
    }

    [Fact]
    public async Task Day_OverSeveralDays_OneRowPerDayAndQueue_AndReadsTheWholeRange()
    {
        Buckets(new[] { Q(U(2026, 11, 3, 23, 30)), Q(U(2026, 11, 4, 0, 0)), Q(U(2026, 11, 5, 12, 0)) });
        var r = await Run(ReportStep.Day, new DateTime(2026, 11, 3), new DateTime(2026, 11, 5));

        r.QueueSummary!.Rows.Select(x => $"{x.IntervalStart:MM-dd} {x.Offered}").Should().Equal("11-03 1", "11-04 1", "11-05 1");
        await _repo.Received(1).GetQueueIntervalsAsync(TenantId, U(2026, 11, 3, 0, 0), U(2026, 11, 6, 0, 0),
            Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    // ---- DST in the site zone (Israel 2026: spring 27.03 02:00 -> 03:00, autumn 25.10 02:00 -> 01:00) ----

    [Fact]
    public async Task Spring_DayHas23Hours()
    {
        // local 27.03 00:00 (+02) = 26.03 22:00Z .. local 28.03 00:00 (+03) = 27.03 21:00Z: 23 h = 46 buckets
        Buckets(Every30(U(2026, 3, 26, 22, 0), U(2026, 3, 27, 21, 0)));

        var day = await Run(ReportStep.Day, new DateTime(2026, 3, 27), israel: true);
        day.QueueSummary!.Rows.Should().ContainSingle().Which.Offered.Should().Be(46, "23 hours, not 24 (48)");
        await _repo.Received().GetQueueIntervalsAsync(TenantId, U(2026, 3, 26, 22, 0), U(2026, 3, 27, 21, 0),
            Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());

        var hour = await Run(ReportStep.Hour, new DateTime(2026, 3, 27), israel: true);
        var shown = hour.QueueSummary!.Rows.Select(x => x.IntervalStart.ToString("HH:mm")).ToList();
        shown.Should().HaveCount(23).And.NotContain("02:00").And.OnlyHaveUniqueItems();
        hour.QueueSummary.Rows.Should().OnlyContain(x => x.Offered == 2);
    }

    [Fact]
    public async Task Autumn_DayHas25Hours_TheRepeatedHourIsTwoRowsInTimeOrder()
    {
        // local 25.10 00:00 (+03) = 24.10 21:00Z .. local 26.10 00:00 (+02) = 25.10 22:00Z: 25 h = 50 buckets
        Buckets(Every30(U(2026, 10, 24, 21, 0), U(2026, 10, 25, 22, 0)));

        var day = await Run(ReportStep.Day, new DateTime(2026, 10, 25), israel: true);
        day.QueueSummary!.Rows.Should().ContainSingle().Which.Offered.Should().Be(50, "25 hours, not 24 (48)");

        var hour = await Run(ReportStep.Hour, new DateTime(2026, 10, 25), israel: true);
        var shown = hour.QueueSummary!.Rows.Select(x => x.IntervalStart.ToString("HH:mm")).ToList();
        shown.Should().HaveCount(25);
        shown.Take(4).Should().Equal("00:00", "01:00", "01:00", "02:00");
        hour.QueueSummary.Rows.Should().OnlyContain(x => x.Offered == 2, "each 01:00 is one real hour, never both mixed (4)");

        var half = await Run(ReportStep.HalfHour, new DateTime(2026, 10, 25), israel: true);
        half.QueueSummary!.Rows.Select(x => x.IntervalStart.ToString("HH:mm")).Take(6)
            .Should().Equal("00:00", "00:30", "01:00", "01:30", "01:00", "01:30");
    }

    // ---- Month / Year (operator 12:31, contract 10:32:55Z, accepted 10:38:32Z) ----

    [Fact]
    public async Task Month_IsTheSumOfItsDays()
    {
        Buckets(new[] { Q(U(2026, 10, 31, 12, 0)), Q(U(2026, 11, 1, 12, 0)), Q(U(2026, 11, 2, 12, 0)) });

        var month = await Run(ReportStep.Month, new DateTime(2026, 10, 31), new DateTime(2026, 11, 2));
        month.QueueSummary!.Rows.Select(x => $"{x.IntervalStart:yyyy-MM-dd HH:mm} {x.Offered}")
            .Should().Equal("2026-10-01 00:00 1", "2026-11-01 00:00 2");

        var day = await Run(ReportStep.Day, new DateTime(2026, 10, 31), new DateTime(2026, 11, 2));
        day.QueueSummary!.Rows.Should().HaveCount(3, "negative half: by day the same data is three rows");
    }

    [Fact]
    public async Task Month_InTheSiteZone_TheWholeAutumnChangeDayAndTheLastLocalHalfHourStayInOctober()
    {
        // 25.10 (25 h) and 31.10 23:30 local (+02) = 31.10 21:30Z; 31.10 22:00Z is already 01.11 00:00 local
        Buckets(Every30(U(2026, 10, 24, 21, 0), U(2026, 10, 25, 22, 0))
            .Append(Q(U(2026, 10, 31, 21, 30))).Append(Q(U(2026, 10, 31, 22, 0))));

        var r = await Run(ReportStep.Month, new DateTime(2026, 10, 1), new DateTime(2026, 11, 30), israel: true);
        r.QueueSummary!.Rows.Select(x => $"{x.IntervalStart:MM.yyyy} {x.Offered}").Should().Equal("10.2026 51", "11.2026 1");
    }

    [Fact]
    public async Task Year_IsTheLocalYear_NotTheUtcYear()
    {
        // 01.01.2026 00:30 local (+02) = 31.12.2025 22:30Z: in UTC both buckets would be 2025
        Buckets(new[] { Q(U(2025, 12, 31, 10, 0)), Q(U(2025, 12, 31, 22, 30)) });

        var r = await Run(ReportStep.Year, new DateTime(2025, 12, 31), new DateTime(2026, 1, 1), israel: true);
        r.QueueSummary!.Rows.Select(x => $"{x.IntervalStart:yyyy-MM-dd} {x.Offered}").Should().Equal("2025-01-01 1", "2026-01-01 1");
        r.Step.Should().Be(ReportStep.Year);
    }

    [Fact]
    public async Task PeriodCuttingTheMonth_IsFlagged_AWholeMonthIsNot()
    {
        ThreeBuckets();
        var cut = await Run(ReportStep.Month, new DateTime(2026, 11, 3), new DateTime(2026, 11, 7), israel: true);
        cut.QueueSummary!.Rows.Should().OnlyContain(x => x.IntervalStart == new DateTime(2026, 11, 1), "the label does not move with the period");
        (cut.PartialFirst, cut.PartialLast).Should().Be((true, true));

        var whole = await Run(ReportStep.Month, new DateTime(2026, 11, 1), new DateTime(2026, 11, 30), israel: true);
        (whole.PartialFirst, whole.PartialLast).Should().Be((false, false), "negative half");

        var day = await Run(ReportStep.Day, new DateTime(2026, 11, 3), new DateTime(2026, 11, 7), israel: true);
        (day.PartialFirst, day.PartialLast).Should().Be((false, false), "days are never cut");
    }

    [Fact]
    public async Task PeriodCuttingTheYear_FlagsOnlyTheCutEnd()
    {
        ThreeBuckets();
        var r = await Run(ReportStep.Year, new DateTime(2026, 1, 1), new DateTime(2026, 11, 7), israel: true);
        (r.PartialFirst, r.PartialLast).Should().Be((false, true));
    }

    // ---- default step from the editor (operator 13:25, coordinator 11:25:39Z): own choice -> DefaultStep -> Day ----

    private const string HourDefault = """{ "scope": { "businessUnitIds": [1] }, "defaultStep": "hour", "pageSize": 100 }""";

    [Fact]
    public async Task NoStepOnTheQuery_TakesTheWidgetsDefaultStep()
    {
        ThreeBuckets();
        var r = await Run(null, new DateTime(2026, 11, 3), cfg: HourDefault);

        r.Step.Should().Be(ReportStep.Hour);
        r.QueueSummary!.Rows.Should().HaveCount(3, "by hour; the Day fallback would give 2 rows");
    }

    [Fact]
    public async Task TheViewersOwnStep_WinsOverTheDefault()
    {
        ThreeBuckets();
        var r = await Run(ReportStep.HalfHour, new DateTime(2026, 11, 3), cfg: HourDefault);

        r.Step.Should().Be(ReportStep.HalfHour);
        r.QueueSummary!.Rows.Should().HaveCount(4);
    }

    [Theory]
    [InlineData("""{ "scope": { "businessUnitIds": [1] }, "defaultStep": "week" }""")]
    [InlineData("""{ "scope": { "businessUnitIds": [1] }, "defaultStep": 99 }""")]
    public async Task AnUnknownDefaultStep_IsInvalidConfig(string cfg)
    {
        var r = await Run(null, new DateTime(2026, 11, 3), cfg: cfg);
        r.ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        await _repo.DidNotReceiveWithAnyArgs().GetQueueIntervalsAsync(default, default, default, default!, default!, default);
    }

    [Fact]
    public async Task ADefaultStepOnAnotherReport_IsInvalidConfig()
    {
        var r = await Handler().Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftAgents,
            """{ "scope": { "businessUnitIds": [1] }, "defaultStep": "hour", "shiftStartHour": 8, "shiftEndHour": 16 }""",
            new DateTime(2026, 11, 3), new DateTime(2026, 11, 3)), CancellationToken.None);

        r.ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
    }

    // ---- PR234-V4-EOS-QUEUES-SAVED-COLUMNS-NO-INTERVAL-01: IntervalStart is always a column of this report ----

    [Fact]
    public async Task ASavedColumnListWithoutIntervalStart_GetsItFirst_TheRestInItsOrder()
    {
        ThreeBuckets();
        var r = await Run(null, new DateTime(2026, 11, 3),
            cfg: """{ "scope": { "businessUnitIds": [1] }, "columns": ["Offered", "Workgroup"] }""");

        r.Error.Should().BeNull();
        r.EffectiveColumns.Should().Equal("IntervalStart", "Offered", "Workgroup");
    }

    [Fact]
    public async Task ASavedColumnListWithIntervalStart_IsKeptAsIs_NotDoubled()
    {
        ThreeBuckets();
        var r = await Run(null, new DateTime(2026, 11, 3),
            cfg: """{ "scope": { "businessUnitIds": [1] }, "columns": ["Workgroup", "IntervalStart", "Offered"] }""");

        r.EffectiveColumns.Should().Equal("Workgroup", "IntervalStart", "Offered");
    }

    [Fact]
    public void NEGATIVE_anotherReportsSavedColumns_AreNotTouched()
    {
        var cfg = ReportWidgetConfig.Parse("""{ "scope": { "businessUnitIds": [1] }, "columns": ["Handled"] }""");
        cfg.GetEffectiveColumns(ReportWidgetType.EndOfShiftAgents).Should().Equal("Handled");
        cfg.GetEffectiveColumns(ReportWidgetType.EndOfShiftQueues).Should().Equal("IntervalStart", "Handled");
    }

    // ---- what is refused / ignored ----

    [Fact]
    public async Task Step_OnAnotherReport_IsInvalidConfig()
    {
        var r = await Handler().Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftAgents, Cfg, new DateTime(2026, 11, 3),
            new DateTime(2026, 11, 3), ShiftStartHour: 8, ShiftEndHour: 16, Step: ReportStep.Hour), CancellationToken.None);

        r.ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        await _repo.DidNotReceiveWithAnyArgs().GetAgentIntervalsAsync(default, default, default, default!, default!, default);
    }

    [Fact]
    public async Task UnknownStep_IsInvalidConfig()
    {
        var r = await Run((ReportStep)99, new DateTime(2026, 11, 3));
        r.ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        await _repo.DidNotReceiveWithAnyArgs().GetQueueIntervalsAsync(default, default, default, default!, default!, default);
    }

    [Fact]
    public async Task ShiftHoursOnTheQuery_AreInvalidConfig()
    {
        var r = await Handler().Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, Cfg, new DateTime(2026, 11, 3),
            new DateTime(2026, 11, 3), ShiftStartHour: 8, ShiftEndHour: 16), CancellationToken.None);

        r.ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        await _repo.DidNotReceiveWithAnyArgs().GetQueueIntervalsAsync(default, default, default, default!, default!, default);
    }

    [Fact]
    public async Task ShiftHoursSavedInAnOldConfig_AreIgnored_TheWholeDayIsRead()
    {
        ThreeBuckets();
        var r = await Run(null, new DateTime(2026, 11, 3),
            cfg: """{ "scope": { "businessUnitIds": [1] }, "shiftStartHour": 8, "shiftEndHour": 16 }""");

        r.Error.Should().BeNull();
        await _repo.Received(1).GetQueueIntervalsAsync(TenantId, U(2026, 11, 3, 0, 0), U(2026, 11, 4, 0, 0),
            Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }
}
