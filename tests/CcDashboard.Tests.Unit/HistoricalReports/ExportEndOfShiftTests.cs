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
        using var wb = new XLWorkbook(new MemoryStream(xlsx));
        return wb.Worksheets.Select(w => w.Name).ToList();
    }

    [Fact]
    public async Task TwoEndOfShiftWidgets_DifferentHours_BothSheets_EachWithItsOwnHours()
    {
        Widget(ReportWidgetType.EndOfShiftAgents, Cfg(8, 16));
        Widget(ReportWidgetType.EndOfShiftAgents, Cfg(16, 23)); // same default title on purpose
        Widget(ReportWidgetType.EndOfShiftQueues, Cfg(6, 14));

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);

        res.Skipped.Should().BeEmpty();
        SheetNames(res.Content).Should().HaveCount(3).And.OnlyHaveUniqueItems();
        _sent.Select(q => (q.From, q.To)).Should().AllBeEquivalentTo((From, From), "an end-of-shift run covers the screen's first date only");
        // the hours reach the run from each widget's own config; the 2nd agents widget is not run with the 1st's hours
        await _hist.Received(1).GetAgentIntervalsAsync(TenantId, From.AddHours(8), From.AddHours(16), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
        await _hist.Received(1).GetAgentIntervalsAsync(TenantId, From.AddHours(16), From.AddHours(23), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
        await _hist.Received(1).GetQueueIntervalsAsync(TenantId, From.AddHours(6), From.AddHours(14), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task WidgetWithoutHours_IsListedWithTheReason_NotDropped()
    {
        Widget(ReportWidgetType.EndOfShiftAgents, Cfg(8, 16));
        Widget(ReportWidgetType.EndOfShiftQueues, Cfg(null, null));

        var res = await _export.Handle(new ExportReportCommand(_screen.Id, From, To), CancellationToken.None);

        var skip = res.Skipped.Should().ContainSingle().Which;
        skip.ReasonCode.Should().Be(ReportReasonCodes.ShiftHours);
        skip.Reason.Should().Contain("Shift start and end hours are required"); // log text kept for the log
        var names = SheetNames(res.Content);
        names.Should().HaveCount(2).And.Contain("Not exported");
        using var wb = new XLWorkbook(new MemoryStream(res.Content));
        wb.Worksheet("Not exported").Cell(2, 1).GetString().Should().Be("EndOfShiftQueues");
        // the file shows the fixed sentence of the code, not the validation text
        wb.Worksheet("Not exported").Cell(2, 2).GetString().Should().Be(ExportReportCommandHandler.SheetText(ReportReasonCodes.ShiftHours))
            .And.NotContain("required");
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
    public async Task QueryHours_StillWin_OverConfig_ForTheLiveWidget()
    {
        // the on-screen widget sends its hours on the query: they are used as sent, the config fallback is only for export
        var widgets = new RunReportWidgetQueryHandler(_hist, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>());
        await widgets.Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftAgents, Cfg(8, 16), From, From,
            ShiftStartHour: 10, ShiftEndHour: 12), CancellationToken.None);
        await _hist.Received(1).GetAgentIntervalsAsync(TenantId, From.AddHours(10), From.AddHours(12), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task OtherTypes_IgnoreConfigHours()
    {
        var widgets = new RunReportWidgetQueryHandler(_hist, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>());
        var r = await widgets.Handle(new RunReportWidgetQuery(ReportWidgetType.AgentPerformance,
            "{ \"scope\": { \"businessUnitIds\": [1] }, \"mode\": \"Summary\", \"shiftStartHour\": 8, \"shiftEndHour\": 16 }", From, To), CancellationToken.None);
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
            new[] { new QueueSummaryRow("Sales", null, 5, 5, 0, 5, 0, 0, 0, 100, 0, 0) }, 1, 1, 1)
    };

    private void Bad(Func<NSubstitute.Core.CallInfo, Task<ReportWidgetResult>> bad) =>
        _mediator.Send(Arg.Any<RunReportWidgetQuery>(), Arg.Any<CancellationToken>())
            .Returns(ci => ci.Arg<RunReportWidgetQuery>().WidgetType == ReportWidgetType.QueueInterval ? bad(ci) : Task.FromResult(GoodResult));

    private bool Logged(LogLevel level) => _log.ReceivedCalls().Any(c => c.GetMethodInfo().Name == "Log" && Equals(c.GetArguments()[0], level));

    private static (List<string> Sheets, string Reason) Read(byte[] xlsx)
    {
        using var wb = new XLWorkbook(new MemoryStream(xlsx));
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
