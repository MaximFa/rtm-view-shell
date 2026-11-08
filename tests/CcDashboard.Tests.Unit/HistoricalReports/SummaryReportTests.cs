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

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// FEAT-REPORT-EOS-AGENTS-01 / FEAT-REPORT-EOS-QUEUES-01; FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01 (no shift hours, row mode).
/// Every rule has its negative half: the same input one step to the other side of the rule gives the other answer.
/// </summary>
public class SummaryReportTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly ILogger<RunReportWidgetQueryHandler> _logger = Substitute.For<ILogger<RunReportWidgetQueryHandler>>();
    private readonly RunReportWidgetQueryHandler _handler;
    private static readonly DateTime Day = new(2026, 11, 3); // Israel winter, +02:00

    private const string AgentsCfg = """{ "scope": { "businessUnitIds": [1] }, "pageSize": 100 }""";
    private const string QueuesCfg = """{ "scope": { "businessUnitIds": [1] }, "pageSize": 100 }""";

    private static TimeZoneInfo Israel()
    {
        foreach (var id in new[] { "Israel Standard Time", "Asia/Jerusalem" })
        {
            try { return TimeZoneInfo.FindSystemTimeZoneById(id); } catch (TimeZoneNotFoundException) { }
        }
        throw new InvalidOperationException("no Israel time zone on this machine");
    }

    public SummaryReportTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.UserId.Returns(Guid.NewGuid());
        _user.PermissionGroupId.Returns(Guid.NewGuid());
        var zone = Substitute.For<IDisplayTimeZone>();
        zone.Zone.Returns(Israel());
        _handler = new RunReportWidgetQueryHandler(_repo, _scope, _user, _logger, zone);
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default)
            .ReturnsForAnyArgs(Array.Empty<HistAgentInterval>());
        _repo.GetQueueIntervalsAsync(default, default, default, default!, default!, default)
            .ReturnsForAnyArgs(Array.Empty<HistQueueInterval>());
    }

    private void AgentScope(bool full, params string[] ids) =>
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), AgentReportAxis.Detail, Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { FullScope = full, EffectiveAgentIds = new HashSet<string>(ids) });

    private void QueueScope(params string[] wgs) =>
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { FullScope = false, EffectiveWorkgroups = new HashSet<string>(wgs) });

    private static HistAgentInterval A(string id, DateTime utcStart, long onphoneMs, int handled = 1) => new()
    {
        Id = Guid.NewGuid(), TenantId = TenantId, IntervalStart = DateTime.SpecifyKind(utcStart, DateTimeKind.Utc),
        AgentExternalId = id, AgentDisplayName = id.ToUpperInvariant(), SumOnphoneMs = onphoneMs, SumAvailableMs = 1000,
        SumLoggedInMs = 1800000, Handled = handled
    };

    // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: both end-of-shift reports take whole local days From..To, no shift hours
    private Task<ReportWidgetResult> Eos(ReportWidgetType t, string cfg, DateTime? to = null, ReportRowMode? mode = null, ReportStep? step = null) =>
        _handler.Handle(new RunReportWidgetQuery(t, cfg, Day, to ?? Day, Step: step, RowMode: mode), CancellationToken.None);

    // ── no shift hours any more ──────────────────────────────────────────────────────────────────

    [Theory]
    [InlineData(ReportWidgetType.EndOfShiftAgents)]
    [InlineData(ReportWidgetType.EndOfShiftQueues)]
    public async Task ShiftHoursOnTheQuery_AreRefused_OnBothEndOfShiftReports(ReportWidgetType type)
    {
        AgentScope(true, "a1");
        QueueScope("Sales");
        var r = await _handler.Handle(new RunReportWidgetQuery(type, AgentsCfg, Day, Day, ShiftStartHour: 8, ShiftEndHour: 16), CancellationToken.None);
        r.ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        await _repo.DidNotReceiveWithAnyArgs().GetAgentIntervalsAsync(default, default, default, default!, default!, default);
        await _repo.DidNotReceiveWithAnyArgs().GetQueueIntervalsAsync(default, default, default, default!, default!, default);
        // negative half: the same query without hours runs
        (await _handler.Handle(new RunReportWidgetQuery(type, AgentsCfg, Day, Day), CancellationToken.None)).Error.Should().BeNull();
    }

    // ── window ───────────────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task Agents_Window_IsTheWholeLocalDays_FromTo_HoursSavedInTheConfigAreIgnored()
    {
        AgentScope(true, "a1");
        await Eos(ReportWidgetType.EndOfShiftAgents,
            """{ "scope": { "businessUnitIds": [1] }, "shiftStartHour": 8, "shiftEndHour": 16 }""", Day.AddDays(1));
        // 03.11 00:00 local (+02:00) = 02.11 22:00Z .. 05.11 00:00 local = 04.11 22:00Z; not the old 06:00Z-14:00Z shift
        await _repo.Received(1).GetAgentIntervalsAsync(TenantId,
            new DateTime(2026, 11, 2, 22, 0, 0), new DateTime(2026, 11, 4, 22, 0, 0),
            Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
        await _repo.DidNotReceive().GetAgentIntervalsAsync(TenantId,
            Arg.Is<DateTime>(d => d == new DateTime(2026, 11, 3, 6, 0, 0)), Arg.Any<DateTime>(),
            Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    // ── scope ────────────────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task AgentFilter_NarrowsScope_NeverWidens()
    {
        AgentScope(false, "a1", "a2");
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            A("a1", Day.AddHours(1), 60000), A("x9", Day.AddHours(1), 60000) // x9: outside the PG, slipped through the store
        });
        var cfg = """{ "scope": { "businessUnitIds": [1] }, "agentIds": ["a1", "x9"] }""";
        var r = await _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftAgents, cfg, Day, Day), CancellationToken.None);

        r.AgentSummary!.Rows.Select(x => x.AgentExternalId).Should().Equal("a1");
        await _repo.Received(1).GetAgentIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
            Arg.Is<ReportScope>(s => !s.FullScope), Arg.Is<IReadOnlySet<string>>(s => s.SetEquals(new[] { "a1" })), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task EmptyEffectiveSet_DoesNotQuery_EvenForFullScope()
    {
        var cfg = """{ "scope": { "businessUnitIds": [1] }, "agentIds": ["zz"] }""";
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), AgentReportAxis.Detail, Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { FullScope = true, EffectiveAgentIds = new HashSet<string> { "a1" } });

        var r = await _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftAgents, cfg, Day, Day), CancellationToken.None);

        r.AgentSummary!.Rows.Should().BeEmpty();
        // a full-scope query with an empty set would return every agent of the tenant
        await _repo.DidNotReceiveWithAnyArgs().GetAgentIntervalsAsync(default, default, default, default!, default!, default);
    }

    // ── row mode (FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01) ────────────────────────────────────────

    [Fact]
    public async Task ByStepDay_OneRowPerLocalDate_Summary_OneRowPerAgent_WithoutAStep()
    {
        AgentScope(true, "a1");
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            A("a1", new DateTime(2026, 11, 3, 10, 0, 0), 60000),
            A("a1", new DateTime(2026, 11, 3, 22, 30, 0), 120000) // 04.11 00:30 local: next local date, same UTC date
        });
        var byStep = await Eos(ReportWidgetType.EndOfShiftAgents, AgentsCfg, Day.AddDays(1), ReportRowMode.ByStep, ReportStep.Day);
        var summary = await Eos(ReportWidgetType.EndOfShiftAgents, AgentsCfg, Day.AddDays(1), ReportRowMode.Summary, ReportStep.Day);

        byStep.AgentSummary!.Rows.Select(r => r.IntervalStart).Should().Equal(new DateTime(2026, 11, 3), new DateTime(2026, 11, 4));
        (byStep.RowMode, byStep.Step).Should().Be((ReportRowMode.ByStep, ReportStep.Day));
        summary.AgentSummary!.Rows.Should().ContainSingle().Which.SumOnphoneMs.Should().Be(180000);
        summary.AgentSummary.Rows[0].IntervalStart.Should().BeNull();
        summary.AgentSummary.Rows[0].AgentAht.Should().Be(90.0);
        (summary.RowMode, summary.Step).Should().Be((ReportRowMode.Summary, (ReportStep?)null), "in Summary the step does not apply");
    }

    [Fact]
    public async Task RowMode_OnTheQueuesReport_OrUnknown_IsInvalidConfig()
    {
        QueueScope("Sales");
        AgentScope(true, "a1");
        (await Eos(ReportWidgetType.EndOfShiftQueues, QueuesCfg, mode: ReportRowMode.ByStep)).ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        (await Eos(ReportWidgetType.EndOfShiftAgents, AgentsCfg, mode: (ReportRowMode)7)).ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        (await Eos(ReportWidgetType.EndOfShiftAgents, AgentsCfg, mode: ReportRowMode.ByStep)).Error.Should().BeNull("negative half");
    }

    // ── freshness ────────────────────────────────────────────────────────────────────────────────

    [Theory]
    [InlineData(21, true)]
    [InlineData(22, false)]
    [InlineData(23, false)]
    public async Task Incomplete_WhenWindowEndsAfterWatermark(int watermarkHourUtc, bool incomplete)
    {
        AgentScope(true, "a1");
        var through = new DateTime(2026, 11, 3, watermarkHourUtc, 0, 0, DateTimeKind.Utc);
        _repo.GetWatermarkAsync(TenantId, Arg.Any<CancellationToken>())
            .Returns(new HistAggregationWatermark { TenantId = TenantId, AggregatedThrough = through });

        var r = await Eos(ReportWidgetType.EndOfShiftAgents, AgentsCfg); // the whole local 03.11 ends 03.11 22:00Z
        r.Incomplete.Should().Be(incomplete);
        r.DataThroughUtc.Should().Be(through);
        r.CaveatCode.Should().Be(ReportCaveatCodes.StatusStartBucket);
    }

    [Fact]
    public async Task Incomplete_WhenNothingAggregated()
    {
        AgentScope(true, "a1");
        _repo.GetWatermarkAsync(TenantId, Arg.Any<CancellationToken>()).Returns((HistAggregationWatermark?)null);
        (await Eos(ReportWidgetType.EndOfShiftAgents, AgentsCfg)).Incomplete.Should().BeTrue();
    }

    // ── queues ───────────────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task Queues_OneRowPerQueue_InScopeOnly_DerivedFromSums()
    {
        QueueScope("Sales", "Support");
        _repo.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            new HistQueueInterval { TenantId = TenantId, IntervalStart = new DateTime(2026, 11, 3, 6, 0, 0), Workgroup = "Sales", Offered = 10, Answered = 8, Abandoned = 2, AnsweredInSl = 6, SumWaitAnswered = 80, SumTalk = 800 },
            new HistQueueInterval { TenantId = TenantId, IntervalStart = new DateTime(2026, 11, 3, 6, 30, 0), Workgroup = "Sales", Offered = 10, Answered = 2, Abandoned = 8, AnsweredInSl = 2, SumWaitAnswered = 20, SumTalk = 200 },
            new HistQueueInterval { TenantId = TenantId, IntervalStart = new DateTime(2026, 11, 3, 6, 0, 0), Workgroup = "Secret", Offered = 99 }
        });

        // FEAT-REPORT-EOS-CONFIGURABLE-01: the queues report takes whole days (no shift hours); Day step = one row per queue
        var r = await _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, QueuesCfg, Day, Day), CancellationToken.None);

        var sales = r.QueueSummary!.Rows.Should().ContainSingle().Which;
        sales.Workgroup.Should().Be("Sales");
        sales.Offered.Should().Be(20);
        sales.AbandonPct.Should().Be(50.0);   // from sums: 10/20, not the mean of 20% and 80% that happens to match...
        sales.SlPct.Should().Be(80.0);        // ...8/10 from sums; the mean of the interval percentages would be 87.5
        sales.Asa.Should().Be(10.0);
        r.CaveatCode.Should().BeNull("negative half: queue numbers have no status-start limit");
    }

    // ── saved config: the screen save path (SaveReportWidgetsCommand) and export both go through Parse + the type validator ──

    [Fact]
    public async Task SavedConfig_RoundTrips_ThroughTheSameParseAndValidator()
    {
        var json = """{ "scope": { "businessUnitIds": [3] }, "columns": ["AgentDisplayName", "Handled"], "defaultRowMode": "byStep", "defaultStep": "hour", "agentIds": ["a1", "a2"] }""";
        var cfg = ReportWidgetConfig.Parse(json);
        cfg.DefaultRowMode.Should().Be(ReportRowMode.ByStep);
        cfg.DefaultStep.Should().Be(ReportStep.Hour);
        cfg.AgentIds.Should().Equal("a1", "a2");
        cfg.Columns.Should().Equal("AgentDisplayName", "Handled");

        var validator = new CcDashboard.Application.HistoricalReports.Validators.ReportWidgetConfigWithTypeValidator();
        (await validator.ValidateAsync((cfg, ReportWidgetType.EndOfShiftAgents))).IsValid.Should().BeTrue();
        // negative half: a default row mode on the queues report, or an unknown one, is refused on save, not only at run time
        (await validator.ValidateAsync((cfg, ReportWidgetType.EndOfShiftQueues))).IsValid.Should().BeFalse();
        var unknown = ReportWidgetConfig.Parse(json.Replace("\"byStep\"", "7"));
        (await validator.ValidateAsync((unknown, ReportWidgetType.EndOfShiftAgents))).IsValid.Should().BeFalse();
    }

    // ── columns ──────────────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task Columns_MustBeFieldsOfTheRow()
    {
        AgentScope(true, "a1");
        var bad = """{ "scope": { "businessUnitIds": [1] }, "columns": ["Handled", "LongestWait"] }""";
        var good = """{ "scope": { "businessUnitIds": [1] }, "columns": ["Handled", "AgentAht"] }""";
        (await Eos(ReportWidgetType.EndOfShiftAgents, bad)).Error.Should().Contain("LongestWait");
        var ok = await Eos(ReportWidgetType.EndOfShiftAgents, good);
        ok.Error.Should().BeNull();
        ok.EffectiveColumns.Should().Equal("Handled", "AgentAht");
        ReportWidgetConfig.AllowedColumns(ReportWidgetType.EndOfShiftQueues).Should().Contain("Workgroup").And.NotContain("Label");
    }
}
