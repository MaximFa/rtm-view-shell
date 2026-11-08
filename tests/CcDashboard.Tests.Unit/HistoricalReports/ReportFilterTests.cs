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
/// PR234-V4-REPORT-VIEW-NO-AGENT-QUEUE-FILTER-01: view-screen filters - agent (login), agent name, queue.
/// Applied on the server BEFORE paging: a match on page 2 is found and TotalCount counts matches (negative half:
/// filtering the page instead of the set misses it). Substring, ignoring case; "%" and "_" are letters; inside the scope.
/// </summary>
public class ReportFilterTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime Day = new(2026, 11, 3);
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly RunReportWidgetQueryHandler _handler;

    // 6 agents; page size 2 -> "zoe" (sorted last by name) is on page 3
    private static readonly (string Id, string? Name)[] Agents =
    {
        ("ann@x", "Ann Cohen"), ("ben@x", "Ben Levi"), ("cat@x", "Cat Mizrahi"),
        ("dan_1@x", "Dan 100%"), ("eve@x", null), ("zoe@x", "Zoe Peretz")
    };

    public ReportFilterTests()
    {
        _user.TenantId.Returns(TenantId);
        _handler = new RunReportWidgetQueryHandler(_repo, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>());
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<AgentReportAxis>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveAgentIds = new HashSet<string>(Agents.Select(a => a.Id)) });
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveWorkgroups = new HashSet<string> { "Sales", "Support", "VIP_1", "VIPX1" } });
        var t = DateTime.SpecifyKind(Day.AddHours(9), DateTimeKind.Utc);
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(
            Agents.Select(a => new HistAgentInterval { TenantId = TenantId, IntervalStart = t, AgentExternalId = a.Id, Handled = 1 }).ToArray());
        // names come from the live rule (AgentNameRule via the repository), not from the history rows
        _repo.GetAgentDisplayNamesAsync(default, default!, default).ReturnsForAnyArgs(
            Agents.Where(a => a.Name != null).ToDictionary(a => a.Id, a => a.Name!));
        _repo.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            new HistQueueInterval { TenantId = TenantId, IntervalStart = t, Workgroup = "Sales", Offered = 1 },
            new HistQueueInterval { TenantId = TenantId, IntervalStart = t, Workgroup = "Support", Offered = 1 },
            new HistQueueInterval { TenantId = TenantId, IntervalStart = t, Workgroup = "VIP_1", Offered = 1 },
            new HistQueueInterval { TenantId = TenantId, IntervalStart = t, Workgroup = "VIPX1", Offered = 1 },
            new HistQueueInterval { TenantId = TenantId, IntervalStart = t, Workgroup = "Secret", Offered = 99 } // outside the scope
        });
    }

    // FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01: AgentPerformance is retired - its rows now come from the agents report (Summary)
    private const string PerfCfg = """{ "scope": { "businessUnitIds": [1] }, "pageSize": 2 }""";
    private const string QueueCfg = """{ "scope": { "businessUnitIds": [1] }, "pageSize": 2 }""";

    // FEAT-REPORT-COLUMN-FUNNEL-FILTERS-01: filters now name their column; these helpers bind the column of the call
    private const string Login = "AgentExternalId", Name = "AgentDisplayName", Queue = "Workgroup";
    private static ReportColumnFilter? T(string? text, string? match = null) => text is null ? null : new("", match, text);
    private static ReportColumnFilter V(params string[] values) => new("", Values: values);
    private static ReportColumnFilter[] On(params (string Column, ReportColumnFilter? F)[] fs) =>
        fs.Where(x => x.F != null).Select(x => x.F! with { Column = x.Column }).ToArray();

    private Task<ReportWidgetResult> Agents_(int page = 1, string? agent = null, string? name = null) =>
        AgentsF(page, T(agent), T(name));

    private Task<ReportWidgetResult> AgentsF(int page = 1, ReportColumnFilter? agent = null, ReportColumnFilter? name = null,
        string? values = null) =>
        _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftAgents, PerfCfg, Day, Day, Page: page,
            Filters: On((Login, agent), (Name, name)), ValuesForColumn: values), CancellationToken.None);

    private Task<ReportWidgetResult> Queues(string? queue) => QueuesF(T(queue));

    private Task<ReportWidgetResult> QueuesF(ReportColumnFilter? queue, string? values = null) =>
        _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, QueueCfg, Day, Day,
            Filters: On((Queue, queue)), ValuesForColumn: values), CancellationToken.None);

    private static IEnumerable<string> Ids(ReportWidgetResult r) => r.AgentSummary!.Rows.Select(x => x.AgentExternalId);

    [Fact]
    public async Task EmptyFilter_IsEverything()
    {
        var r = await Agents_(agent: "  ", name: "");
        r.Error.Should().BeNull();
        r.AgentSummary!.TotalCount.Should().Be(6);
    }

    [Fact]
    public async Task ByName_Substring_IgnoringCase()
    {
        var r = await Agents_(name: "LEVI");
        Ids(r).Should().Equal("ben@x");
        r.AgentSummary!.Rows[0].AgentDisplayName.Should().Be("Ben Levi", "the live rule's name, not the empty history name");
    }

    [Fact]
    public async Task ByLogin_Substring_IgnoringCase()
    {
        Ids(await Agents_(agent: "CAT@")).Should().Equal("cat@x");
    }

    [Fact]
    public async Task BothFilters_MustBothMatch()
    {
        Ids(await Agents_(agent: "@x", name: "zoe")).Should().Equal("zoe@x");
        (await Agents_(agent: "ann", name: "zoe")).AgentSummary!.TotalCount.Should().Be(0, "login of one agent and name of another: no row");
    }

    [Fact]
    public async Task NameFilter_AgentWithoutName_DoesNotMatch()
    {
        var r = await Agents_(name: "e");
        Ids(r).Should().NotContain("eve@x", "eve has no name: the name filter cannot match her login");
        (await Agents_(agent: "eve")).AgentSummary!.TotalCount.Should().Be(1, "negative half: she is found by the login filter");
    }

    [Fact]
    public async Task MatchOnALaterPage_IsFound_AndTotalCountCountsMatches()
    {
        // unfiltered, zoe is on page 3 of 3 (page size 2); filtered, she is the one row of page 1
        (await Agents_(page: 1)).AgentSummary!.Rows.Select(x => x.AgentExternalId).Should().NotContain("zoe@x");
        var r = await Agents_(page: 1, name: "peretz");
        Ids(r).Should().Equal("zoe@x");
        r.AgentSummary!.TotalCount.Should().Be(1);
    }

    [Fact]
    public async Task PercentAndUnderscore_AreLetters()
    {
        Ids(await Agents_(name: "100%")).Should().Equal("dan_1@x");
        Ids(await Agents_(agent: "_1")).Should().Equal("dan_1@x");
        (await Agents_(name: "%")).AgentSummary!.TotalCount.Should().Be(1, "'%' is not a wildcard");
        (await Agents_(agent: "_")).AgentSummary!.TotalCount.Should().Be(1, "'_' is not a wildcard");
    }

    [Fact]
    public async Task QueueFilter_Substring_InsideTheScope()
    {
        (await Queues("sup")).QueueSummary!.Rows.Select(x => x.Workgroup).Should().Equal("Support");
        (await Queues("vip_")).QueueSummary!.Rows.Select(x => x.Workgroup).Should().Equal("VIP_1"); // not VIPX1
        (await Queues("secret")).QueueSummary!.TotalCount.Should().Be(0, "a filter never widens the scope");
        (await Queues(null)).QueueSummary!.TotalCount.Should().Be(4);
    }

    [Theory]
    [InlineData(100, true)]
    [InlineData(101, false)]
    public async Task FilterLength_Limit100(int length, bool ok)
    {
        var r = await Agents_(name: new string('a', length));
        (r.Error == null).Should().Be(ok);
        if (!ok) r.ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        RunReportWidgetQueryHandler.FilterMaxLength.Should().Be(100);
    }

    [Fact]
    public async Task FiltersOnATypeThatHasNoSuchColumn_AreRefused()
    {
        var agentOnQueues = await _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, QueueCfg, Day, Day,
            Filters: On((Login, T("ann")))), CancellationToken.None);
        agentOnQueues.Error.Should().Contain("Unknown filter column");
        (await _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftAgents, PerfCfg, Day, Day, Filters: On((Queue, T("sales")))),
            CancellationToken.None)).Error.Should().Contain("Unknown filter column");
    }

    // ── operators and picked values (the grid filter) ──────────────────────────────────────────────────────────

    [Theory]
    [InlineData("equal", "ben levi", "ben@x")]
    [InlineData("startsWith", "ZOE", "zoe@x")]
    [InlineData("endsWith", "MIZRAHI", "cat@x")]
    [InlineData("contains", "100%", "dan_1@x")]
    public async Task MatchTypes_IgnoringCase(string match, string text, string expected)
    {
        Ids(await AgentsF(name: T(text, match))).Should().Equal(expected);
    }

    [Fact]
    public async Task Equal_IsNotContains()
    {
        (await AgentsF(name: T("Levi", "equal"))).AgentSummary!.TotalCount.Should().Be(0, "'Levi' is only part of 'Ben Levi'");
        (await AgentsF(name: T("Levi", "contains"))).AgentSummary!.TotalCount.Should().Be(1, "negative half: contains finds it");
    }

    [Fact]
    public async Task PickedValues_AnyOfThem_Exact()
    {
        Ids(await AgentsF(agent: V("ann@x", "zoe@x"))).Should().BeEquivalentTo(new[] { "ann@x", "zoe@x" });
        (await AgentsF(agent: V("ANN@X"))).AgentSummary!.TotalCount.Should().Be(0, "a picked value is exact, as the grid's list");
        (await AgentsF(agent: V("ann"))).AgentSummary!.TotalCount.Should().Be(0, "a picked value is not a substring");
        (await QueuesF(V("Sales", "VIP_1"))).QueueSummary!.Rows.Select(x => x.Workgroup).Should().Equal("Sales", "VIP_1");
    }

    [Fact]
    public async Task PickedValueOutsideTheScope_FindsNothing()
    {
        (await QueuesF(V("Secret"))).QueueSummary!.TotalCount.Should().Be(0);
        (await AgentsF(agent: V("x9@x"))).AgentSummary!.TotalCount.Should().Be(0);
    }

    [Fact]
    public async Task TextAndValuesTogether_UnknownMatchType_TooManyValues_AreRefused()
    {
        (await AgentsF(agent: new ReportColumnFilter("", "contains", "ann", new[] { "ann@x" }))).Error.Should().Contain("not both");
        (await AgentsF(agent: T("ann", "regex"))).Error.Should().Contain("operator does not fit");
        (await AgentsF(agent: new ReportColumnFilter("", Values: Enumerable.Range(0, 501).Select(i => $"a{i}").ToArray()))).Error
            .Should().Contain("500");
        (await AgentsF(agent: new ReportColumnFilter("", Values: Enumerable.Range(0, 500).Select(i => $"a{i}").ToArray()))).Error
            .Should().BeNull("negative half: 500 is allowed");
        (await AgentsF(agent: V(new string('a', 101)))).Error.Should().Contain("longer than");
    }

    // ── the checkbox list ───────────────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task ColumnValues_WholeWindow_NotThePage()
    {
        var r = await AgentsF(page: 1, values: Login);   // page size 2
        r.AgentSummary!.Rows.Should().HaveCount(2);
        r.ColumnValues!.Values.Should().HaveCount(6, "the list is over the whole scoped window, not the page");
        r.ColumnValues.Truncated.Should().BeFalse();
        (await AgentsF(page: 1)).ColumnValues.Should().BeNull("negative half: no list unless asked");
    }

    [Fact]
    public async Task ColumnValues_OtherColumnsFilterApplies_OwnDoesNot()
    {
        // list of logins while the login filter picks ann and the name filter says "e"
        var r = await AgentsF(agent: V("ann@x"), name: T("e"), values: Login);
        r.ColumnValues!.Values.Should().BeEquivalentTo(new[] { "ann@x", "ben@x", "zoe@x" },
            "the name filter ('e': Ann Cohen, Ben Levi, Zoe Peretz) applies; the login column's own pick does not");
        Ids(r).Should().Equal("ann@x");
        // names list: no name filter -> every name; the agent without a name has no entry
        (await AgentsF(values: Name)).ColumnValues!.Values.Should()
            .Equal("Ann Cohen", "Ben Levi", "Cat Mizrahi", "Dan 100%", "Zoe Peretz");
    }

    [Fact]
    public async Task ColumnValues_Queues_InsideTheScopeOnly()
    {
        (await QueuesF(V("Sales"), Queue)).ColumnValues!.Values.Should()
            .BeEquivalentTo(new[] { "Sales", "Support", "VIP_1", "VIPX1" }); // "Secret" is outside the scope
        (await AgentsF(values: Queue)).Error.Should().Contain("value list", "no queue column there");
    }

    [Theory]
    [InlineData(1000, 1000, false)]
    [InlineData(1001, 1000, true)]
    public void ColumnValues_Limit1000_TheCutIsFlagged(int distinct, int listed, bool truncated)
    {
        var v = RunReportWidgetQueryHandler.ColumnValuesOf(Login, Enumerable.Range(0, distinct).Select(i => $"a{i:D5}"));
        v.Values.Should().HaveCount(listed);
        v.TotalCount.Should().Be(distinct);
        v.Truncated.Should().Be(truncated);
    }

    private (ExportReportCommandHandler Export, IReportExporter Exporter, List<RunReportWidgetQuery> Sent, ReportScreen Screen) ExportSetup()
    {
        var mediator = Substitute.For<IMediator>();
        var sent = new List<RunReportWidgetQuery>();
        mediator.Send(Arg.Any<RunReportWidgetQuery>(), Arg.Any<CancellationToken>())
            .Returns(ci => { var q = ci.Arg<RunReportWidgetQuery>(); sent.Add(q); return _handler.Handle(q, CancellationToken.None); });
        var screen = new ReportScreen { Id = Guid.NewGuid(), TenantId = TenantId, Name = "S" };
        var screens = Substitute.For<IReportScreenRepository>();
        screens.GetByIdWithWidgetsAsync(screen.Id, Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns(screen);
        var exporter = Substitute.For<IReportExporter>();
        exporter.ExportXlsxAsync(default!, default!, default).ReturnsForAnyArgs(Array.Empty<byte>());
        var export = new ExportReportCommandHandler(screens, exporter, mediator, _user, Substitute.For<IDateTimeProvider>(),
            Substitute.For<ILogger<ExportReportCommandHandler>>());
        return (export, exporter, sent, screen);
    }

    private static ReportWidget W(ReportWidgetType type, string cfg) => new() { Id = Guid.NewGuid(), WidgetType = type, ConfigJson = cfg };

    [Fact]
    public async Task Export_EachWidgetGetsItsOwnFilters_OnlyThoseItsTypeTakes()
    {
        var (export, exporter, sent, screen) = ExportSetup();
        var agents = W(ReportWidgetType.EndOfShiftAgents, PerfCfg);
        var queues = W(ReportWidgetType.EndOfShiftQueues, """{ "scope": { "businessUnitIds": [1] }, "shiftStartHour": 0, "shiftEndHour": 24 }""");
        screen.Widgets.Add(agents);
        screen.Widgets.Add(queues);

        var res = await export.Handle(new ExportReportCommand(screen.Id, Day, Day, Filters: new Dictionary<Guid, IReadOnlyList<ReportColumnFilter>>
        {
            [agents.Id] = On((Login, T("zoe")), (Name, T("peretz"))),
            [queues.Id] = On((Queue, T("sup")))
        }), CancellationToken.None);

        res.Skipped.Should().BeEmpty();
        sent.Single(q => q.WidgetType == ReportWidgetType.EndOfShiftAgents).Filters!.Select(f => (f.Column, f.Text))
            .Should().Equal((Login, "zoe"), (Name, "peretz"));
        sent.Single(q => q.WidgetType == ReportWidgetType.EndOfShiftQueues).Filters!.Select(f => (f.Column, f.Text))
            .Should().Equal((Queue, "sup"));
        await exporter.Received(1).ExportXlsxAsync(Arg.Any<string>(),
            Arg.Is<IReadOnlyList<WidgetExportSheet>>(s => s.Count == 2 && s[0].TotalCount == 1 && s[1].TotalCount == 1), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Export_AFilterOnAColumnTheWidgetHasNot_IsListed_NeverExportedUnfiltered()
    {
        var (export, exporter, _, screen) = ExportSetup();
        var agents = W(ReportWidgetType.EndOfShiftAgents, PerfCfg);
        screen.Widgets.Add(agents);

        var res = await export.Handle(new ExportReportCommand(screen.Id, Day, Day, Filters: new Dictionary<Guid, IReadOnlyList<ReportColumnFilter>>
        {
            [agents.Id] = On((Queue, T("sup")))   // agent rows have no queue column
        }), CancellationToken.None);

        res.Skipped.Should().ContainSingle().Which.ReasonCode.Should().Be(ReportReasonCodes.InvalidConfig);
    }

    [Fact]
    public async Task Export_TwoAgentWidgets_DifferentFilters_EachSheetHasItsOwnRows()
    {
        var (export, exporter, sent, screen) = ExportSetup();
        var first = W(ReportWidgetType.EndOfShiftAgents, PerfCfg);
        var second = W(ReportWidgetType.EndOfShiftAgents, PerfCfg);
        var third = W(ReportWidgetType.EndOfShiftAgents, PerfCfg);   // no entry -> unfiltered
        screen.Widgets.Add(first);
        screen.Widgets.Add(second);
        screen.Widgets.Add(third);

        await export.Handle(new ExportReportCommand(screen.Id, Day, Day, Filters: new Dictionary<Guid, IReadOnlyList<ReportColumnFilter>>
        {
            [first.Id] = On((Name, T("levi"))),
            [second.Id] = On((Login, V("cat@x")))   // picked values travel to the export the same way
        }), CancellationToken.None);

        // negative half: one filter for the whole screen would give the first two sheets the same rows
        await exporter.Received(1).ExportXlsxAsync(Arg.Any<string>(), Arg.Is<IReadOnlyList<WidgetExportSheet>>(s =>
                s.Count == 3 && s[0].TotalCount == 1 && s[1].TotalCount == 1 && s[2].TotalCount == 6
                && !s[0].Rows[0].SequenceEqual(s[1].Rows[0])),
            Arg.Any<CancellationToken>());
        sent.Select(q => q.Filters?.Single()).Select(f => (f?.Column, f?.Text, f?.Values?.Single()))
            .Should().Equal((Name, "levi", null), (Login, null, "cat@x"), (null, null, null));
    }
}
