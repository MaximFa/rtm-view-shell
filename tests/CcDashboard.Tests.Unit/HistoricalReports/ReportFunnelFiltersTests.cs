using CcDashboard.Application.Handlers;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Application.Reports.Export;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Historical;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using MediatR;
using Microsoft.Extensions.Logging;
using NSubstitute;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01: number and time funnels on any table report (contract 07:23:21Z).
/// greater = strictly above, less = strictly below, between = both bounds included; a null cell matches no number filter;
/// applied to the final rows before paging; the operator must fit the column kind (ReportColumns).
/// </summary>
public class ReportFunnelFiltersTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime Day = new(2026, 11, 3);
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly RunReportWidgetQueryHandler _handler;

    private static DateTime At(int h, int m) => new(2026, 11, 3, h, m, 0, DateTimeKind.Utc);

    public ReportFunnelFiltersTests()
    {
        _user.TenantId.Returns(TenantId);
        _handler = new RunReportWidgetQueryHandler(_repo, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>());
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveWorkgroups = new HashSet<string> { "Sales" } });
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<AgentReportAxis>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveAgentIds = new HashSet<string> { "a1", "a2", "a3" } });
        // four intervals: Offered 1 / 5 / 10 / 20; the last has no answered call, so its Asa and SlPct are null
        _repo.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            Q(At(6, 0), offered: 1, answered: 1, inSl: 1, wait: 10),
            Q(At(6, 30), offered: 5, answered: 4, inSl: 2, wait: 40),
            Q(At(7, 0), offered: 10, answered: 10, inSl: 5, wait: 100),
            Q(At(7, 30), offered: 20, answered: 0, inSl: 0, wait: 0),
        });
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            A("a1", At(9, 0), handled: 2, onphoneMs: 60_000),
            A("a2", At(9, 0), handled: 8, onphoneMs: 600_000),
            A("a3", new DateTime(2026, 11, 4, 9, 0, 0, DateTimeKind.Utc), handled: 5, onphoneMs: 0),
        });
    }

    private static HistQueueInterval Q(DateTime t, int offered, int answered, int inSl, long wait) => new()
    { TenantId = TenantId, IntervalStart = t, Workgroup = "Sales", Offered = offered, Answered = answered, AnsweredInSl = inSl, SumWaitAnswered = wait };

    private static HistAgentInterval A(string id, DateTime t, int handled, long onphoneMs) => new()
    { TenantId = TenantId, IntervalStart = t, AgentExternalId = id, Handled = handled, SumOnphoneMs = onphoneMs, SumAvailableMs = 1000 };

    private const string QCfg = """{ "scope": { "businessUnitIds": [1] }, "pageSize": 100 }""";
    private const string PerfCfg = """{ "scope": { "businessUnitIds": [1] }, "mode": "ByDate", "pageSize": 100 }""";
    private const string MonthCfg = """{ "scope": { "businessUnitIds": [1], "agentAxis": "Detail" }, "pageSize": 100 }""";

    private static ReportColumnFilter N(string col, string op, double from, double? to = null) => new(col, op, Number: from, NumberTo: to);
    private static ReportColumnFilter Tm(string col, string op, DateTime from, DateTime? to = null) => new(col, op, Time: from, TimeTo: to);

    private Task<ReportWidgetResult> Intervals(int pageSize = 100, params ReportColumnFilter[] f) =>
        _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.QueueInterval,
            QCfg.Replace("\"pageSize\": 100", $"\"pageSize\": {pageSize}"), Day, Day, Filters: f), CancellationToken.None);

    private static IEnumerable<int> Offered(ReportWidgetResult r) => r.QueueInterval!.Rows.Select(x => x.Offered);

    [Fact]
    public async Task Greater_IsStrict_Less_IsStrict()
    {
        Offered(await Intervals(f: N("Offered", "greater", 5))).Should().Equal(10, 20);
        Offered(await Intervals(f: N("Offered", "less", 5))).Should().Equal(1);
    }

    [Fact]
    public async Task Between_IncludesBothBounds()
    {
        Offered(await Intervals(f: N("Offered", "between", 5, 10))).Should().Equal(5, 10);
        Offered(await Intervals(f: N("Offered", "between", 6, 9))).Should().BeEmpty("negative half: neither bound inside");
    }

    [Fact]
    public async Task NullCell_MatchesNoNumberFilter()
    {
        // the 07:30 interval has no answered call: Asa is null, not 0
        Offered(await Intervals(f: N("Asa", "less", 1_000_000))).Should().Equal(1, 5, 10);
        Offered(await Intervals(f: N("Asa", "greater", -1))).Should().Equal(1, 5, 10);
    }

    [Fact]
    public async Task DurationSeconds_And_Percent_InTheirOwnUnit()
    {
        Offered(await Intervals(f: N("SumWaitAnswered", "between", 40, 100))).Should().Equal(5, 10);   // seconds
        Offered(await Intervals(f: N("SlPct", "greater", 50))).Should().Equal(1);                     // 100% only; 50% is not > 50
        Offered(await Intervals(f: N("SlPct", "between", 50, 50))).Should().Equal(5, 10);             // 2/4 and 5/10
    }

    [Fact]
    public async Task DateTime_Greater_And_Between()
    {
        Offered(await Intervals(f: Tm("IntervalStart", "greater", At(6, 30)))).Should().Equal(10, 20);
        Offered(await Intervals(f: Tm("IntervalStart", "between", At(6, 30), At(7, 0)))).Should().Equal(5, 10);
    }

    [Fact]
    public async Task Date_OnTheByDateRows()
    {
        var r = await _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.AgentPerformance, PerfCfg, Day, Day.AddDays(1),
            Filters: new[] { Tm("Date", "greater", Day) }), CancellationToken.None);
        r.AgentSummary!.Rows.Select(x => x.AgentExternalId).Should().Equal("a3");
    }

    [Fact]
    public async Task Filters_AreBeforePaging_AndTotalCountCountsMatches()
    {
        var r = await Intervals(1, N("Offered", "greater", 5));
        r.QueueInterval!.TotalCount.Should().Be(2);
        Offered(r).Should().Equal(10);
        (await Intervals(1)).QueueInterval!.TotalCount.Should().Be(4, "negative half: unfiltered");
    }

    [Fact]
    public async Task FiltersOnSeveralColumns_AllMustPass()
    {
        Offered(await Intervals(f: new[] { N("Offered", "greater", 1), N("SlPct", "less", 100) })).Should().Equal(5, 10);
    }

    [Fact]
    public async Task DerivedColumn_OnGroupedRows_AgentMonthly()
    {
        // AgentAht = onphone ms / 1000 / handled: a1 30 s, a2 75 s, a3 0 s - filtered on the MONTH row, not on intervals
        var r = await _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.AgentMonthly, MonthCfg, Day, Day.AddDays(1),
            Filters: new[] { N("AgentAht", "greater", 30) }), CancellationToken.None);
        r.AgentMonthly!.Rows.Select(x => x.AgentExternalId).Should().Equal("a2");
    }

    [Fact]
    public async Task ValueList_OfATextColumn_TakesTheOtherColumnsNumberFilter()
    {
        var r = await _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.AgentMonthly, MonthCfg, Day, Day.AddDays(1),
            Filters: new[] { N("Handled", "greater", 4), new ReportColumnFilter("AgentExternalId", Values: new[] { "a2" }) },
            ValuesForColumn: "AgentExternalId"), CancellationToken.None);
        r.ColumnValues!.Values.Should().Equal(new[] { "a2", "a3" }, "Handled > 4 applies; the login column's own pick does not");
        r.AgentMonthly!.Rows.Select(x => x.AgentExternalId).Should().Equal("a2");
    }

    [Theory]
    [InlineData(ReportWidgetType.QueueInterval, "Offered", "contains", "operator does not fit")]       // text op on a number
    [InlineData(ReportWidgetType.EndOfShiftQueues, "Workgroup", "greater", "operator does not fit")]  // number op on text
    [InlineData(ReportWidgetType.QueueInterval, "Workgroup", "contains", "takes no filter")]          // always empty there
    [InlineData(ReportWidgetType.EndOfShiftQueues, "QueueId", "greater", "takes no filter")]          // id
    [InlineData(ReportWidgetType.QueueInterval, "NoSuchColumn", "greater", "Unknown filter column")]
    [InlineData(ReportWidgetType.Distribution, "Label", "contains", "takes no column filters")]
    public async Task IncompatibleOrUnknown_IsRefused(ReportWidgetType type, string column, string op, string message)
    {
        var f = op is "greater" ? new ReportColumnFilter(column, op, Number: 1) : new ReportColumnFilter(column, op, Text: "x");
        var r = await _handler.Handle(new RunReportWidgetQuery(type, QCfg, Day, Day,
            ShiftStartHour: type == ReportWidgetType.EndOfShiftQueues ? 0 : null, ShiftEndHour: type == ReportWidgetType.EndOfShiftQueues ? 24 : null,
            Filters: new[] { f }), CancellationToken.None);
        r.Error.Should().Contain(message);
        r.ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
    }

    [Fact]
    public async Task BadBounds_AreRefused()
    {
        (await Intervals(f: new ReportColumnFilter("Offered", "between", Number: 5))).Error.Should().Contain("bound missing");
        (await Intervals(f: N("Offered", "between", 10, 5))).Error.Should().Contain("lower bound above");
        (await Intervals(f: N("Offered", "greater", double.NaN))).Error.Should().Contain("finite");
        (await Intervals(f: new ReportColumnFilter("Offered", "greater", Time: Day))).Error.Should().Contain("takes a number");
        (await Intervals(f: new ReportColumnFilter("IntervalStart", "greater", Number: 1))).Error.Should().Contain("takes a time");
        (await Intervals(f: new[] { N("Offered", "greater", 1), N("Offered", "less", 9) })).Error.Should().Contain("twice");
        (await Intervals(f: N("Offered", "between", 5, 5))).Error.Should().BeNull("negative half: equal bounds are a valid range");
    }

    [Fact]
    public async Task ValueList_OnlyForAFilterableTextColumn()
    {
        (await _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.QueueInterval, QCfg, Day, Day, ValuesForColumn: "Offered"),
            CancellationToken.None)).Error.Should().Contain("value list");
        (await _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.QueueInterval, QCfg, Day, Day, ValuesForColumn: "Workgroup"),
            CancellationToken.None)).Error.Should().Contain("value list", "Workgroup is always empty in this report");
    }

    [Fact]
    public async Task Export_NumberFilter_FileEqualsScreen()
    {
        var mediator = Substitute.For<IMediator>();
        mediator.Send(Arg.Any<RunReportWidgetQuery>(), Arg.Any<CancellationToken>())
            .Returns(ci => _handler.Handle(ci.Arg<RunReportWidgetQuery>(), CancellationToken.None));
        var screen = new ReportScreen { Id = Guid.NewGuid(), TenantId = TenantId, Name = "S" };
        var w = new ReportWidget { Id = Guid.NewGuid(), WidgetType = ReportWidgetType.QueueInterval, ConfigJson = QCfg };
        screen.Widgets.Add(w);
        var screens = Substitute.For<IReportScreenRepository>();
        screens.GetByIdWithWidgetsAsync(screen.Id, Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns(screen);
        var exporter = Substitute.For<IReportExporter>();
        exporter.ExportXlsxAsync(default!, default!, default).ReturnsForAnyArgs(Array.Empty<byte>());
        var export = new ExportReportCommandHandler(screens, exporter, mediator, _user, Substitute.For<IDateTimeProvider>(),
            Substitute.For<ILogger<ExportReportCommandHandler>>());
        var filters = new[] { N("Offered", "between", 5, 20) };

        var screenRows = (await Intervals(f: filters)).QueueInterval!.TotalCount;
        await export.Handle(new ExportReportCommand(screen.Id, Day, Day,
            Filters: new Dictionary<Guid, IReadOnlyList<ReportColumnFilter>> { [w.Id] = filters }), CancellationToken.None);

        screenRows.Should().Be(3);
        await exporter.Received(1).ExportXlsxAsync(Arg.Any<string>(),
            Arg.Is<IReadOnlyList<WidgetExportSheet>>(s => s.Count == 1 && s[0].TotalCount == 3), Arg.Any<CancellationToken>());
    }
}
