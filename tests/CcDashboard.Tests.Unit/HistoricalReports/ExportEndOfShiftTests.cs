using CcDashboard.Application.Handlers;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Application.Reports.Export;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Historical;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Reports.Export;
using ClosedXML.Excel;
using FluentAssertions;
using MediatR;
using Microsoft.Extensions.Logging;
using NSubstitute;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// PR234-V4-EOS-WIDGETS-NO-SHIFT-HOURS-01 (export): the page sends no shift hours, so the export must run each
/// end-of-shift widget with the hours of its OWN config and the screen's date; a widget that cannot run is listed,
/// never silently dropped. The real widget handler and the real xlsx writer are used; only the stores are substituted.
/// </summary>
public class ExportEndOfShiftTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime From = new(2026, 11, 2), To = new(2026, 11, 8); // the page's default week
    private readonly IHistoricalReportRepository _hist = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly IReportScreenRepository _screens = Substitute.For<IReportScreenRepository>();
    private readonly IMediator _mediator = Substitute.For<IMediator>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly List<RunReportWidgetQuery> _sent = new();
    private readonly ExportReportCommandHandler _export;
    private readonly ILogger<ExportReportCommandHandler> _exportLog = Substitute.For<ILogger<ExportReportCommandHandler>>();
    private readonly ReportScreen _screen = new() { Id = Guid.NewGuid(), TenantId = TenantId, Name = "Shift" };

    public ExportEndOfShiftTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.Role.Returns("Admin");
        var widgets = new RunReportWidgetQueryHandler(_hist, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>());
        _mediator.Send(Arg.Any<RunReportWidgetQuery>(), Arg.Any<CancellationToken>())
            .Returns(ci => { var q = ci.Arg<RunReportWidgetQuery>(); _sent.Add(q); return widgets.Handle(q, CancellationToken.None); });

        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<AgentReportAxis>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveAgentIds = new HashSet<string> { "a1" } });
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveWorkgroups = new HashSet<string> { "Sales" } });
        var t = DateTime.SpecifyKind(From.AddHours(9), DateTimeKind.Utc);
        _hist.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
            { new HistAgentInterval { TenantId = TenantId, IntervalStart = t, AgentExternalId = "a1", AgentDisplayName = "A1", Handled = 4 } });
        _hist.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
            { new HistQueueInterval { TenantId = TenantId, IntervalStart = t, Workgroup = "Sales", Offered = 5, Answered = 5 } });

        _screens.GetByIdWithWidgetsAsync(_screen.Id, Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns(_screen);
        var clock = Substitute.For<IDateTimeProvider>();
        clock.UtcNow.Returns(new DateTime(2026, 11, 4, 6, 0, 0, DateTimeKind.Utc));
        _export = new ExportReportCommandHandler(_screens, new ClosedXmlReportExporter(Substitute.For<ILogger<ClosedXmlReportExporter>>()),
            _mediator, _user, clock, _exportLog);
    }

    private void Widget(ReportWidgetType type, string config) =>
        _screen.Widgets.Add(new ReportWidget { Id = Guid.NewGuid(), TenantId = TenantId, WidgetType = type, ConfigJson = config });

    private static string Cfg(int? start, int? end) =>
        "{ \"scope\": { \"businessUnitIds\": [1] }" + (start is null ? "" : $", \"shiftStartHour\": {start}, \"shiftEndHour\": {end}") + " }";

    private static List<string> SheetNames(byte[] xlsx)
    {
        using var wb = XlsxDiagnostics.Open(xlsx);
        return wb.Worksheets.Select(w => w.Name).ToList();
    }

    [Fact]
    public async Task EveryEndOfShiftWidget_TakesTheScreensPeriod_HoursLeftInConfigsAreIgnored()
    {
        // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: the agents report no longer covers one date with shift hours
        Widget(ReportWidgetType.EndOfShiftAgents, Cfg(8, 16));
        Widget(ReportWidgetType.EndOfShiftAgents, Cfg(16, 23)); // same default title on purpose
        Widget(ReportWidgetType.EndOfShiftQueues, Cfg(6, 14));

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);

        res.Skipped.Should().BeEmpty();
        SheetNames(res.Content).Should().HaveCount(3).And.OnlyHaveUniqueItems();
        _sent.Should().HaveCount(3).And.OnlyContain(q => q.From == From && q.To == To && q.ShiftStartHour == null && q.ShiftEndHour == null);
        await _hist.Received(2).GetAgentIntervalsAsync(TenantId, From, To.AddDays(1), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
        // negative half: the old shift windows are never read
        await _hist.DidNotReceive().GetAgentIntervalsAsync(TenantId, From.AddHours(8), Arg.Any<DateTime>(), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
        await _hist.Received(1).GetQueueIntervalsAsync(TenantId, From, To.AddDays(1), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task EndOfShiftWidgets_EachRunWithTheirOwnStepAndModeFromTheScreen_NoEntryMeansTheDefault()
    {
        // export = screen; the step (both reports) and the row mode (agents) chosen on the screen travel per widget
        Widget(ReportWidgetType.EndOfShiftQueues, """{ "title": "Hourly", "scope": { "businessUnitIds": [1] } }""");
        Widget(ReportWidgetType.EndOfShiftQueues, """{ "title": "Daily", "scope": { "businessUnitIds": [1] } }""");
        Widget(ReportWidgetType.EndOfShiftAgents, """{ "title": "Agents", "scope": { "businessUnitIds": [1] } }""");
        var hourly = _screen.Widgets.Single(w => w.ConfigJson!.Contains("Hourly")).Id;
        var daily = _screen.Widgets.Single(w => w.ConfigJson!.Contains("Daily")).Id;
        var agents = _screen.Widgets.Single(w => w.WidgetType == ReportWidgetType.EndOfShiftAgents).Id;

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, From, To,
            Steps: new Dictionary<Guid, ReportStep> { [hourly] = ReportStep.Hour, [agents] = ReportStep.HalfHour },
            Modes: new Dictionary<Guid, ReportRowMode> { [agents] = ReportRowMode.ByStep, [daily] = ReportRowMode.ByStep }), CancellationToken.None);

        res.Skipped.Should().BeEmpty("a row mode addressed to a queues widget is not passed to it, so it is not refused");
        _sent.Single(q => q.ConfigJson.Contains("Hourly")).Step.Should().Be(ReportStep.Hour);
        _sent.Single(q => q.ConfigJson.Contains("Daily")).Should().Match<RunReportWidgetQuery>(q => q.Step == null && q.RowMode == null,
            "no step entry = the widget's default; a queues widget takes no row mode");
        _sent.Single(q => q.WidgetType == ReportWidgetType.EndOfShiftAgents).Should().Match<RunReportWidgetQuery>(q =>
            q.Step == ReportStep.HalfHour && q.RowMode == ReportRowMode.ByStep);
    }

    [Fact]
    public async Task AgentReport_TheFileWritesTheIntervalLikeTheScreen_AndNamesTheSheetAgentReport()
    {
        // ByStep by day: the interval cell is ReportIntervalLabel's "dd/MM/yyyy"; untitled sheet = "Agent Report"
        Widget(ReportWidgetType.EndOfShiftAgents, """{ "scope": { "businessUnitIds": [1] }, "defaultRowMode": "byStep", "defaultStep": "day" }""");

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);

        SheetNames(res.Content).Should().Equal("Agent Report");
        using (var wb = XlsxDiagnostics.Open(res.Content))
        {
            wb.Worksheet("Agent Report").Cell(1, 1).GetString().Should().Be("IntervalStart");
            wb.Worksheet("Agent Report").Cell(2, 1).GetString().Should().Be("02/11/2026");
        }

        // negative half: in Summary there is no interval column at all
        _screen.Widgets.Single().ConfigJson = """{ "scope": { "businessUnitIds": [1] } }""";
        var summary = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);
        using (var wb = XlsxDiagnostics.Open(summary.Content))
            wb.Worksheet("Agent Report").Cell(1, 1).GetString().Should().NotBe("IntervalStart");
    }

    [Fact]
    public async Task RetiredWidget_IsListedAsRetired_TheOthersAreExported()
    {
        Widget(ReportWidgetType.Distribution, Cfg(null, null));
        Widget(ReportWidgetType.EndOfShiftQueues, Cfg(null, null));

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);

        res.Skipped.Select(x => x.ReasonCode).Should().Equal(ReportReasonCodes.Retired);
        SheetNames(res.Content).Should().HaveCount(2).And.Contain("Not exported");
        ExportReportCommandHandler.SheetText(ReportReasonCodes.Retired).Should().Be("This report type has been retired");
    }

    [Fact]
    public async Task MonthStep_TheFileWritesTheIntervalLikeTheScreen_NoBracketsEvenWhenThePeriodCutsTheMonth()
    {
        // coordinator 11:22:59Z: file = screen, one label rule (ReportIntervalLabel); operator 2026-11-07 18:51: no cut-edge
        // mark in brackets. The period 02.11-08.11 cuts November - the cell is still just the month (MM/yyyy, 22:32).
        Widget(ReportWidgetType.EndOfShiftQueues, """{ "title": "Q", "scope": { "businessUnitIds": [1] }, "defaultStep": "month" }""");

        var cut = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);
        using (var wb = XlsxDiagnostics.Open(cut.Content))
        {
            wb.Worksheet("Q").Cell(1, 1).GetString().Should().Be("IntervalStart");
            wb.Worksheet("Q").Cell(2, 1).GetString().Should().Be(ReportIntervalLabel.Start(new DateTime(2026, 11, 1), ReportStep.Month))
                .And.Be("11/2026").And.NotContain("(");
        }

        // negative half: the cell follows the step the server used - by day the same file writes a date, not "11.2026"
        _screen.Widgets.Single().ConfigJson = """{ "title": "Q", "scope": { "businessUnitIds": [1] }, "defaultStep": "day" }""";
        var byDay = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);
        using (var wb = XlsxDiagnostics.Open(byDay.Content))
            wb.Worksheet("Q").Cell(2, 1).GetString().Should().Be(ReportIntervalLabel.Start(new DateTime(2026, 11, 2), ReportStep.Day))
                .And.NotBe("11/2026");
    }

    [Fact]
    public async Task AWidgetWithoutATitle_NamesItsSheetByTheTypesEnglishName_NotTheEnumName()
    {
        Widget(ReportWidgetType.EndOfShiftQueues, Cfg(null, null));
        Widget(ReportWidgetType.EndOfShiftQueues, """{ "title": "Sales queues", "scope": { "businessUnitIds": [1] } }""");

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);

        SheetNames(res.Content).Should().Equal("Queue Report", "Sales queues");
        SheetNames(res.Content).Should().NotContain("EndOfShiftQueues");
    }

    // FEAT-REPORT-QUEUE-DATE-FORMAT-01 (operator 2026-11-07 22:32): the file writes the interval start of the queue report
    // by step - year yyyy, month MM/yyyy, day dd/MM/yyyy, hour and half-hour dd/MM/yyyy HH:mm - as the screen does.
    // The expected strings are literal here (not ReportIntervalLabel.Start), so a wrong rule cannot agree with itself.
    [Theory]
    [InlineData("year", "2026")]
    [InlineData("month", "11/2026")]
    [InlineData("day", "02/11/2026")]
    [InlineData("hour", "02/11/2026 09:00")]
    [InlineData("halfHour", "02/11/2026 09:00")]
    public async Task QueueReport_TheFileWritesTheIntervalStartInTheStepsFormat(string step, string expected)
    {
        Widget(ReportWidgetType.EndOfShiftQueues, $$"""{ "title": "Q", "scope": { "businessUnitIds": [1] }, "defaultStep": "{{step}}" }""");

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);

        using var wb = XlsxDiagnostics.Open(res.Content);
        var cell = wb.Worksheet("Q").Cell(2, 1).GetString();
        cell.Should().Be(expected);
        // negative half: none of the old shapes ("11.2026", "2026-11-02 09:00", a culture date with dots) survives
        cell.Should().NotContain(".").And.NotContain("-");
    }

    [Fact]
    public async Task TheQueueTrendChart_IsListedAsNotExportable_NotRun_TheFileIsStillBuilt()
    {
        // FEAT-REPORT-QUEUE-TREND-COMPARE-01 (operator 2026-11-08 18:22): a chart is not exported - listed, never silently lost
        Widget(ReportWidgetType.QueueTrend, """{ "title": "Trend", "scope": { "businessUnitIds": [1] } }""");
        Widget(ReportWidgetType.EndOfShiftQueues, Cfg(null, null));

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);

        res.Skipped.Should().ContainSingle().Which.Should().Match<SkippedWidget>(x => x.Title == "Trend" && x.ReasonCode == ReportReasonCodes.NotExportable);
        _sent.Should().NotContain(q => q.WidgetType == ReportWidgetType.QueueTrend, "the chart is not run for the file");
        SheetNames(res.Content).Should().Equal("Queue Report", "Not exported");
        ExportReportCommandHandler.SheetText(ReportReasonCodes.NotExportable).Should().Be("A chart is not exported");
    }

    [Fact]
    public async Task ARetiredAgentsWidget_IsListedByItsEnglishName_TheAgentReportIsExported()
    {
        // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: an agents widget without hours is no longer skipped (no hours any more);
        // a retired agents report is listed with its sentence, under its English name (coordinator 15:05:51Z)
        Widget(ReportWidgetType.EndOfShiftAgents, Cfg(null, null));
        Widget(ReportWidgetType.AgentMonthly, Cfg(null, null));

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);

        var skip = res.Skipped.Should().ContainSingle().Which;
        skip.ReasonCode.Should().Be(ReportReasonCodes.Retired);
        SheetNames(res.Content).Should().Equal("Agent Report", "Not exported");
        using var wb = XlsxDiagnostics.Open(res.Content);
        wb.Worksheet("Not exported").Cell(2, 1).GetString().Should().Be("Agent Monthly", "the type's English name, not the enum name");
        wb.Worksheet("Not exported").Cell(2, 2).GetString().Should().Be(ExportReportCommandHandler.SheetText(ReportReasonCodes.Retired));
    }

    [Fact]
    public async Task Denied_And_NoData_And_InvalidConfig_EachGetTheirOwnCode()
    {
        Widget(ReportWidgetType.EndOfShiftAgents, Cfg(8, 16));                  // denied: agent scope empty below
        Widget(ReportWidgetType.EndOfShiftQueues, Cfg(6, 14));                  // no data: store returns nothing below
        Widget(ReportWidgetType.EndOfShiftQueues, "{ \"scope\": { \"businessUnitIds\": [] }, \"shiftStartHour\": 6, \"shiftEndHour\": 14 }"); // invalid config
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<AgentReportAxis>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult());
        _hist.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(Array.Empty<HistQueueInterval>());

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);

        res.Skipped.Select(s => s.ReasonCode).Should().Equal(ReportReasonCodes.Denied, ReportReasonCodes.NoData, ReportReasonCodes.InvalidConfig);
        res.Skipped.Should().OnlyContain(s => ReportReasonCodes.All.Contains(s.ReasonCode));
    }

    [Fact]
    public void TheShiftHoursCode_IsGone_NoReportTakesShiftHours()
    {
        // coordinator 06:49:47Z: a code no run can produce is dead code - not in the list, no sentence of its own
        ReportReasonCodes.All.Should().NotContain("shift-hours");
        ExportReportCommandHandler.SheetText("shift-hours").Should().Be(ExportReportCommandHandler.SheetText(ReportReasonCodes.Unrecognised));
        typeof(ReportReasonCodes).GetField("ShiftHours").Should().BeNull("the constant itself is removed, not only unlisted");
        // negative half: a code that is in the list does have its own sentence
        ExportReportCommandHandler.SheetText(ReportReasonCodes.Retired).Should().NotBe(ExportReportCommandHandler.SheetText(ReportReasonCodes.Unrecognised));
    }

    [Fact]
    public void EveryCode_HasItsOwnSheetText_AndAnErrorWithoutCodeCannotBeBuilt()
    {
        foreach (var code in ReportReasonCodes.All)
            ExportReportCommandHandler.SheetText(code).Should().NotBeNullOrEmpty()
                .And.NotBe(ExportReportCommandHandler.SheetText(ReportReasonCodes.Unrecognised), $"'{code}' has a sentence of its own");
        var noCode = () => ReportWidgetResult.CreateError(ReportWidgetType.QueueInterval, "", "x");
        noCode.Should().Throw<ArgumentException>("an error without a code cannot be built");
    }

    [Fact]
    public async Task NegativeHalf_AllWidgetsRun_NoNotExportedSheet()
    {
        Widget(ReportWidgetType.EndOfShiftQueues, Cfg(6, 14));
        var res = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);
        res.Skipped.Should().BeEmpty();
        SheetNames(res.Content).Should().NotContain("Not exported");
    }

    [Fact]
    public async Task QueryHours_AreRefused_ForTheAgentsWidget()
    {
        // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: no report takes shift hours; an old caller sending them gets invalid-config
        var widgets = new RunReportWidgetQueryHandler(_hist, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>());
        var r = await widgets.Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftAgents, Cfg(8, 16), From, From,
            ShiftStartHour: 10, ShiftEndHour: 12), CancellationToken.None);
        r.ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        await _hist.DidNotReceiveWithAnyArgs().GetAgentIntervalsAsync(default, default, default, default!, default!, default);
    }

    [Fact]
    public async Task TheAgentsWidget_IgnoresConfigHours()
    {
        var widgets = new RunReportWidgetQueryHandler(_hist, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>());
        var r = await widgets.Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftAgents,
            "{ \"scope\": { \"businessUnitIds\": [1] }, \"shiftStartHour\": 8, \"shiftEndHour\": 16 }", From, To), CancellationToken.None);
        r.Error.Should().BeNull();
        await _hist.Received(1).GetAgentIntervalsAsync(TenantId, From, To.AddDays(1), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

}

public class ExportNeverLosesTheFileTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IReportScreenRepository _screens = Substitute.For<IReportScreenRepository>();
    private readonly IMediator _mediator = Substitute.For<IMediator>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly ILogger<ExportReportCommandHandler> _log = Substitute.For<ILogger<ExportReportCommandHandler>>();
    private readonly ReportScreen _screen = new() { Id = Guid.NewGuid(), TenantId = TenantId, Name = "S" };
    private readonly ExportReportCommandHandler _export;
    private readonly ReportWidget _bad, _good;

    public ExportNeverLosesTheFileTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.Role.Returns("Admin");
        _screens.GetByIdWithWidgetsAsync(_screen.Id, Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns(_screen);
        _bad = new ReportWidget { Id = Guid.NewGuid(), WidgetType = ReportWidgetType.QueueInterval, ConfigJson = "{ \"title\": \"Bad\", \"scope\": { \"businessUnitIds\": [1] } }" };
        _good = new ReportWidget { Id = Guid.NewGuid(), WidgetType = ReportWidgetType.EndOfShiftQueues, ConfigJson = "{ \"title\": \"Good\", \"scope\": { \"businessUnitIds\": [1] } }" };
        _screen.Widgets.Add(_bad);
        _screen.Widgets.Add(_good);
        var clock = Substitute.For<IDateTimeProvider>();
        clock.UtcNow.Returns(new DateTime(2026, 11, 4, 8, 0, 0, DateTimeKind.Utc));
        _export = new ExportReportCommandHandler(_screens, new ClosedXmlReportExporter(Substitute.For<ILogger<ClosedXmlReportExporter>>()),
            _mediator, _user, clock, _log);
    }

    private static readonly ReportWidgetResult GoodResult = new()
    {
        WidgetType = ReportWidgetType.EndOfShiftQueues,
        EffectiveColumns = new[] { "Workgroup", "Offered" },
        QueueSummary = new QueueSummaryReportResult(
            new[] { new QueueSummaryRow(new DateTime(2026, 11, 3), "Sales", null, 5, 5, 0, 5, 0, 0, 0, 100, 0, 0) }, 1, 1, 1)
    };

    private void Bad(Func<NSubstitute.Core.CallInfo, Task<ReportWidgetResult>> bad) =>
        _mediator.Send(Arg.Any<RunReportWidgetQuery>(), Arg.Any<CancellationToken>())
            .Returns(ci => ci.Arg<RunReportWidgetQuery>().WidgetType == ReportWidgetType.QueueInterval ? bad(ci) : Task.FromResult(GoodResult));

    private bool Logged(LogLevel level) => _log.ReceivedCalls().Any(c => c.GetMethodInfo().Name == "Log" && Equals(c.GetArguments()[0], level));

    private static (List<string> Sheets, string Reason) Read(byte[] xlsx)
    {
        using var wb = XlsxDiagnostics.Open(xlsx);
        return (wb.Worksheets.Select(w => w.Name).ToList(), wb.Worksheet("Not exported").Cell(2, 2).GetString());
    }

    [Theory]
    [InlineData("from-the-future")]
    [InlineData(null)]
    public async Task UnrecognisedCode_FileIsBuilt_GeneralSentence_Logged(string? code)
    {
        Bad(_ => Task.FromResult(new ReportWidgetResult { WidgetType = ReportWidgetType.QueueInterval, Error = "boom", ErrorCode = code }));

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, new DateTime(2026, 11, 3), new DateTime(2026, 11, 3)), CancellationToken.None);

        var (sheets, reason) = Read(res.Content);
        sheets.Should().Equal("Good", "Not exported");                    // the good widget is still in the file
        reason.Should().Be(ExportReportCommandHandler.SheetText(ReportReasonCodes.Unrecognised));
        res.Skipped.Should().ContainSingle().Which.ReasonCode.Should().Be(ReportReasonCodes.Unrecognised);
        Logged(LogLevel.Warning).Should().BeTrue();
    }

    [Fact]
    public async Task KnownCode_GetsItsOwnSentence_NotTheGeneralOne()
    {
        // negative half of the test above: a known code is not swallowed into "not recognised"
        Bad(_ => Task.FromResult(ReportWidgetResult.CreateError(ReportWidgetType.QueueInterval, ReportReasonCodes.InvalidConfig, "boom")));
        var res = await _export.Handle(new ExportReportCommand(_screen.Id, new DateTime(2026, 11, 3), new DateTime(2026, 11, 3)), CancellationToken.None);
        Read(res.Content).Reason.Should().Be(ExportReportCommandHandler.SheetText(ReportReasonCodes.InvalidConfig));
    }

    [Fact]
    public async Task WidgetRunThrows_FileIsBuilt_WidgetListed_ErrorLogged()
    {
        Bad(_ => throw new InvalidOperationException("store down"));

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, new DateTime(2026, 11, 3), new DateTime(2026, 11, 3)), CancellationToken.None);

        Read(res.Content).Sheets.Should().Equal("Good", "Not exported");
        res.Skipped.Should().ContainSingle().Which.Title.Should().Be("Bad");
        Logged(LogLevel.Error).Should().BeTrue();
    }
}

public class SheetNameTests
{
    [Fact]
    public void SameTitleTwice_GetsDistinctNames_Within31()
    {
        using var wb = new XLWorkbook();
        var first = ClosedXmlReportExporter.UniqueSheetName("EndOfShiftAgents", 1, wb);
        wb.Worksheets.Add(first);
        var second = ClosedXmlReportExporter.UniqueSheetName("EndOfShiftAgents", 2, wb);
        first.Should().Be("EndOfShiftAgents");             // negative half: a free name is kept as is
        second.Should().NotBe(first).And.Be("EndOfShiftAgents (2)");
        var longName = new string('x', 31);
        wb.Worksheets.Add(longName);
        ClosedXmlReportExporter.UniqueSheetName(longName.ToUpperInvariant(), 3, wb).Length.Should().BeLessThanOrEqualTo(31);
    }
}

public class XlsxDiagnosticsTests
{
    [Fact]
    public void DuplicateRelsDefault_IsReported_WithTheContentTypes_AndTheBytesKept()
    {
        // build a valid book, then duplicate the Default "rels" entry - the shape of the 21:34 failure
        byte[] good;
        using (var wb = new XLWorkbook())
        {
            wb.Worksheets.Add("S");
            using var ms = new MemoryStream();
            wb.SaveAs(ms);
            good = ms.ToArray();
        }
        XlsxDiagnostics.Open(good).Dispose(); // negative half: an untouched book opens

        byte[] bad;
        using (var ms = new MemoryStream())
        {
            ms.Write(good);
            using (var zip = new System.IO.Compression.ZipArchive(ms, System.IO.Compression.ZipArchiveMode.Update, leaveOpen: true))
            {
                var entry = zip.GetEntry("[Content_Types].xml")!;
                string xml;
                using (var r = new StreamReader(entry.Open())) xml = r.ReadToEnd();
                var rels = System.Text.RegularExpressions.Regex.Match(xml, "<Default [^>]*Extension=\"rels\"[^>]*/>").Value;
                rels.Should().NotBeEmpty("the book has a Default rels entry to duplicate");
                entry.Delete();
                using var w = new StreamWriter(zip.CreateEntry("[Content_Types].xml").Open());
                w.Write(xml.Replace(rels, rels + rels));
            }
            bad = ms.ToArray();
        }

        var act = () => XlsxDiagnostics.Open(bad);
        var ex = act.Should().Throw<InvalidOperationException>().Which;
        ex.Message.Should().Contain("saved to").And.Contain("Extension=\"rels\"");
        var path = System.Text.RegularExpressions.Regex.Match(ex.Message, @"saved to (.+?\.xlsx);").Groups[1].Value;
        File.Exists(path).Should().BeTrue();
        File.ReadAllBytes(path).Should().Equal(bad);
        File.Delete(path);
    }
}

/// <summary>
/// PR234-TEST-EXPORT-XLSX-DUPLICATE-RELS-FLAKE-01 (diagnostics only, no behaviour change): when the produced xlsx cannot be
/// read, keep the evidence. The bytes go to &lt;test bin&gt;/flake-xlsx/&lt;utc&gt;_&lt;guid&gt;.xlsx and the exception message
/// carries the file path and the full text of [Content_Types].xml, so the test log alone shows what was duplicated.
/// </summary>
internal static class XlsxDiagnostics
{
    public static XLWorkbook Open(byte[] xlsx)
    {
        try
        {
            return new XLWorkbook(new MemoryStream(xlsx));
        }
        catch (Exception ex)
        {
            var dir = Path.Combine(AppContext.BaseDirectory, "flake-xlsx");
            Directory.CreateDirectory(dir);
            var path = Path.Combine(dir, $"{DateTime.UtcNow:yyyyMMdd_HHmmss_fff}_{Guid.NewGuid():N}.xlsx");
            File.WriteAllBytes(path, xlsx);
            string contentTypes;
            try
            {
                using var zip = new System.IO.Compression.ZipArchive(new MemoryStream(xlsx), System.IO.Compression.ZipArchiveMode.Read);
                var entry = zip.GetEntry("[Content_Types].xml");
                using var reader = new StreamReader(entry!.Open());
                contentTypes = reader.ReadToEnd();
            }
            catch (Exception zipEx)
            {
                contentTypes = "<could not read [Content_Types].xml: " + zipEx.Message + ">";
            }
            throw new InvalidOperationException(
                $"xlsx could not be read ({ex.GetType().Name}: {ex.Message}); bytes={xlsx.Length}; saved to {path}; " +
                $"[Content_Types].xml = {contentTypes}", ex);
        }
    }
}
