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
            _mediator, _user, clock, Substitute.For<ILogger<ExportReportCommandHandler>>());
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

        res.Skipped.Should().ContainSingle().Which.Reason.Should().Contain("Shift start and end hours are required");
        var names = SheetNames(res.Content);
        names.Should().HaveCount(2).And.Contain("Not exported");
        using var wb = new XLWorkbook(new MemoryStream(res.Content));
        wb.Worksheet("Not exported").Cell(2, 1).GetString().Should().Be("EndOfShiftQueues");
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
