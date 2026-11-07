using CcDashboard.Application.Handlers;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Historical;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using Microsoft.Extensions.Logging;
using NSubstitute;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// PR234-V4-REPORT-FILTER-EMPTY-RESULT-STUCK-01: when a filter leaves no rows, the screen keeps the table header with
/// its funnels - the only way back out of the filter. The header is drawn from the ANSWER's EffectiveColumns, so the
/// server must send them with zero rows too. Measured here for the queue report and an agent report; the handler sets
/// EffectiveColumns at every return of a table result regardless of the row count (RunReportWidgetQueryHandler).
/// </summary>
public class EmptyFilteredResultKeepsColumnsTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly DateTime Day = new(2026, 11, 3);
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly RunReportWidgetQueryHandler _handler;

    private static DateTime At(int h) => new(2026, 11, 3, h, 0, 0, DateTimeKind.Utc);

    public EmptyFilteredResultKeepsColumnsTests()
    {
        _user.TenantId.Returns(TenantId);
        _handler = new RunReportWidgetQueryHandler(_repo, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>());
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveWorkgroups = new HashSet<string> { "Sales" } });
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<AgentReportAxis>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveAgentIds = new HashSet<string> { "a1" } });
        _repo.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            new HistQueueInterval { TenantId = TenantId, IntervalStart = At(9), Workgroup = "Sales", Offered = 5, Answered = 5, AnsweredInSl = 5, SumWaitAnswered = 10 }
        });
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            new HistAgentInterval { TenantId = TenantId, IntervalStart = At(9), AgentExternalId = "a1", Handled = 3, SumOnphoneMs = 60_000, SumAvailableMs = 1000 }
        });
    }

    private const string QCfg = """{ "scope": { "businessUnitIds": [1] }, "pageSize": 100 }""";
    private const string PerfCfg = """{ "scope": { "businessUnitIds": [1] }, "mode": "ByDate", "pageSize": 100 }""";

    private Task<ReportWidgetResult> Queues(params ReportColumnFilter[] f) =>
        _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, QCfg, Day, Day, Filters: f), CancellationToken.None);

    private Task<ReportWidgetResult> Perf(params ReportColumnFilter[] f) =>
        _handler.Handle(new RunReportWidgetQuery(ReportWidgetType.AgentPerformance, PerfCfg, Day, Day, Filters: f), CancellationToken.None);

    private static readonly ReportColumnFilter NothingQueues = new("Offered", "greater", Number: 1_000_000);
    private static readonly ReportColumnFilter NothingAgents = new("Handled", "greater", Number: 1_000_000);

    [Fact]
    public async Task QueueReport_FilteredToNothing_StillSendsItsColumns()
    {
        var all = await Queues();
        all.QueueSummary!.Rows.Should().NotBeEmpty("without the filter there are rows - so the filter is what empties it");

        var none = await Queues(NothingQueues);
        none.Error.Should().BeNull();
        none.QueueSummary!.Rows.Should().BeEmpty();
        none.EffectiveColumns.Should().NotBeNullOrEmpty("the screen draws the header - and its funnels - from these");
        none.EffectiveColumns.Should().Equal(all.EffectiveColumns!, "the same columns with and without rows");
    }

    [Fact]
    public async Task AgentReport_FilteredToNothing_StillSendsItsColumns()
    {
        var all = await Perf();
        all.AgentSummary!.Rows.Should().NotBeEmpty("without the filter there are rows - so the filter is what empties it");

        var none = await Perf(NothingAgents);
        none.Error.Should().BeNull();
        none.AgentSummary!.Rows.Should().BeEmpty();
        none.EffectiveColumns.Should().NotBeNullOrEmpty("the screen draws the header - and its funnels - from these");
        none.EffectiveColumns.Should().Equal(all.EffectiveColumns!, "the same columns with and without rows");
    }
}
