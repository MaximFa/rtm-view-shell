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
/// FEAT-REPORT-QUEUE-COLUMN-SORT-01 (contract shell 20:36:54Z, coordinator 20:47:34Z): the queues report sorts on the
/// server - after the filters, before the pages (the screen sees one page of many; sorting that page would lie).
/// White-listed columns only; nulls last in both directions; equal values keep the default order (interval, queue);
/// IntervalStart by its UTC start; other report types ignore the sort.
/// </summary>
public class QueueReportSortTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
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

    public QueueReportSortTests()
    {
        _user.TenantId.Returns(TenantId);
        _scope.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveWorkgroups = new HashSet<string> { "alpha", "Beta", "gamma" } });
        _scope.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<AgentReportAxis>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { EffectiveAgentIds = new HashSet<string> { "a1" } });
    }

    private static DateTime U(int d, int h, int m) => new(2026, 11, d, h, m, 0, DateTimeKind.Utc);

    private static HistQueueInterval Q(DateTime t, string wg, int offered, int answered, long wait = 10) => new()
    { TenantId = TenantId, IntervalStart = t, Workgroup = wg, Offered = offered, Answered = answered, SumWaitAnswered = wait };

    // default order (interval, then queue): 06:00 alpha 3 | 06:00 Beta 7 | 06:30 alpha 7 | 06:30 gamma 1 (Asa null) | 07:00 Beta 5
    private void Data() =>
        _repo.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            Q(U(3, 6, 0), "alpha", 3, 3, wait: 30),
            Q(U(3, 6, 0), "Beta", 7, 7, wait: 70),
            Q(U(3, 6, 30), "alpha", 7, 7, wait: 7),
            Q(U(3, 6, 30), "gamma", 1, 0),
            Q(U(3, 7, 0), "Beta", 5, 5, wait: 100),
        });

    private Task<ReportWidgetResult> Run(string? sort, bool desc = false, int pageSize = 100, ReportColumnFilter[]? filters = null,
        bool israel = false, ReportStep step = ReportStep.HalfHour) =>
        new RunReportWidgetQueryHandler(_repo, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>(), israel ? new Israel() : null)
            .Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues,
                $$"""{ "scope": { "businessUnitIds": [1] }, "pageSize": {{pageSize}} }""", Day, Day,
                Filters: filters, Step: step, SortColumn: sort, SortDescending: desc), CancellationToken.None);

    private static IEnumerable<string> Rows(ReportWidgetResult r) =>
        r.QueueSummary!.Rows.Select(x => $"{x.IntervalStart:HH:mm} {x.Workgroup} {x.Offered}");

    [Fact]
    public async Task NoSort_IsTheDefaultOrder()
    {
        Data();
        Rows(await Run(null)).Should().Equal("06:00 alpha 3", "06:00 Beta 7", "06:30 alpha 7", "06:30 gamma 1", "07:00 Beta 5");
    }

    [Fact]
    public async Task ANumberColumn_SortsBothWays_EqualValuesKeepTheDefaultOrder()
    {
        Data();
        Rows(await Run("Offered")).Should().Equal("06:30 gamma 1", "06:00 alpha 3", "07:00 Beta 5", "06:00 Beta 7", "06:30 alpha 7");
        // the two 7s stay "06:00 Beta" before "06:30 alpha" in BOTH directions (stable, default order on ties)
        Rows(await Run("Offered", desc: true)).Should().Equal("06:00 Beta 7", "06:30 alpha 7", "07:00 Beta 5", "06:00 alpha 3", "06:30 gamma 1");
    }

    [Fact]
    public async Task Nulls_AreLast_InBothDirections()
    {
        Data();   // Asa: alpha 06:00 = 10, Beta 06:00 = 10, alpha 06:30 = 1, gamma = null, Beta 07:00 = 20
        (await Run("Asa")).QueueSummary!.Rows.Select(x => x.Asa).Should().Equal(1.0, 10.0, 10.0, 20.0, null);
        (await Run("Asa", desc: true)).QueueSummary!.Rows.Select(x => x.Asa).Should().Equal(20.0, 10.0, 10.0, 1.0, null);
    }

    [Fact]
    public async Task Text_SortsIgnoringCase()
    {
        Data();
        (await Run("Workgroup")).QueueSummary!.Rows.Select(x => x.Workgroup).Should().Equal("alpha", "alpha", "Beta", "Beta", "gamma");
        // negative half: an ordinal sort would put the capital "Beta" first
        new[] { "alpha", "Beta", "gamma" }.OrderBy(x => x, StringComparer.Ordinal).First().Should().Be("Beta");
    }

    [Fact]
    public async Task TheSort_IsAfterTheFiltersAndBeforeThePages()
    {
        Data();
        var r = await Run("Offered", desc: true, pageSize: 2, filters: new[] { new ReportColumnFilter("Offered", "less", Number: 7) });

        r.QueueSummary!.TotalCount.Should().Be(3, "the filter left 3, 5, 1 - the sevens are gone before the sort");
        Rows(r).Should().Equal("07:00 Beta 5", "06:00 alpha 3");
        // negative half: without the sort the first page is the default order of the filtered rows
        Rows(await Run(null, pageSize: 2, filters: new[] { new ReportColumnFilter("Offered", "less", Number: 7) }))
            .Should().Equal("06:00 alpha 3", "06:30 gamma 1");
    }

    [Fact]
    public async Task IntervalStart_SortsByTheUtcStart_TheTwoAutumn0100RowsNeverSwap()
    {
        // 25.10: 01:00 summer (+03) = 24.10 22:00Z, then 01:00 winter (+02) = 24.10 23:00Z
        _repo.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
        {
            Q(new DateTime(2026, 10, 24, 22, 0, 0, DateTimeKind.Utc), "alpha", 1, 1),
            Q(new DateTime(2026, 10, 24, 23, 0, 0, DateTimeKind.Utc), "alpha", 5, 5),
        });
        Task<ReportWidgetResult> R(bool desc) =>
            new RunReportWidgetQueryHandler(_repo, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>(), new Israel())
                .Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, """{ "scope": { "businessUnitIds": [1] } }""",
                    new DateTime(2026, 10, 25), new DateTime(2026, 10, 25), Step: ReportStep.Hour,
                    SortColumn: "IntervalStart", SortDescending: desc), CancellationToken.None);

        var desc = (await R(true)).QueueSummary!.Rows;
        desc.Select(x => x.IntervalStart.ToString("HH:mm")).Should().Equal("01:00", "01:00");
        desc.Select(x => x.Offered).Should().Equal(5, 1);   // negative half: by the shown time they would tie and stay 1, 5
        (await R(false)).QueueSummary!.Rows.Select(x => x.Offered).Should().Equal(1, 5);
    }

    [Theory]
    [InlineData("NoSuchColumn")]
    [InlineData("offered")]          // the white list is exact, as for the filters
    [InlineData("Answered; DROP")]
    public async Task AColumnTheReportDoesNotHave_IsInvalidConfig_AndTheStoreIsNotAsked(string column)
    {
        Data();
        (await Run(column)).ErrorCode.Should().Be(ReportReasonCodes.InvalidConfig);
        await _repo.DidNotReceiveWithAnyArgs().GetQueueIntervalsAsync(default, default, default, default!, default!, default);
    }

    [Fact]
    public async Task OtherReports_IgnoreTheSort()
    {
        _repo.GetAgentIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new[]
            { new HistAgentInterval { TenantId = TenantId, IntervalStart = U(3, 9, 0), AgentExternalId = "a1", Handled = 2 } });
        var r = await new RunReportWidgetQueryHandler(_repo, _scope, _user, Substitute.For<ILogger<RunReportWidgetQueryHandler>>())
            .Handle(new RunReportWidgetQuery(ReportWidgetType.EndOfShiftAgents, """{ "scope": { "businessUnitIds": [1] } }""", Day, Day,
                ShiftStartHour: 8, ShiftEndHour: 16, SortColumn: "NoSuchColumn", SortDescending: true), CancellationToken.None);

        r.Error.Should().BeNull();
        r.AgentSummary!.Rows.Should().ContainSingle();
    }
}
