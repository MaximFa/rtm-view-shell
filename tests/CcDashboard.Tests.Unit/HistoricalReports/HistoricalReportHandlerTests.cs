using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Domain.Domain.Historical;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Handlers;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.HistoricalReports;

public class HistoricalReportHandlerTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportScopeResolver _scopeResolver = Substitute.For<IReportScopeResolver>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();

    public HistoricalReportHandlerTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.Role.Returns("Superadmin");
        _scopeResolver.ResolveQueueScopeAsync(Arg.Any<CancellationToken>())
            .Returns(ReportScope.Full());
        _scopeResolver.ResolveAgentScopeAsync(Arg.Any<CancellationToken>())
            .Returns(ReportScope.Full());
    }

    [Fact]
    public async Task GetQueueIntervalReport_ComputesNullIfGuards()
    {
        var intervals = new List<HistQueueInterval>
        {
            new()
            {
                Id = Guid.NewGuid(),
                TenantId = TenantId,
                IntervalStart = new DateTime(2026, 6, 21, 10, 0, 0, DateTimeKind.Utc),
                Workgroup = "Sales",
                Offered = 0,
                Answered = 0,
                Abandoned = 0,
                AnsweredInSl = 0,
                SumWaitAnswered = 0,
                SumTalk = 0
            },
            new()
            {
                Id = Guid.NewGuid(),
                TenantId = TenantId,
                IntervalStart = new DateTime(2026, 6, 21, 10, 30, 0, DateTimeKind.Utc),
                Workgroup = "Sales",
                Offered = 10,
                Answered = 8,
                Abandoned = 2,
                AnsweredInSl = 6,
                SumWaitAnswered = 80,
                SumTalk = 480
            }
        };

        _repo.GetQueueIntervalsAsync(
                TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
                Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(),
                Arg.Any<CancellationToken>())
            .Returns(intervals);

        var handler = new GetQueueIntervalReportQueryHandler(_repo, _scopeResolver, _user);
        var result = await handler.Handle(
            new GetQueueIntervalReportQuery(DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Rows.Should().HaveCount(2);

        var zeroRow = result.Rows.First(r => r.Offered == 0);
        zeroRow.AbandonPct.Should().BeNull();
        zeroRow.SlPct.Should().BeNull();
        zeroRow.Asa.Should().BeNull();
        zeroRow.QueueAht.Should().BeNull();

        var dataRow = result.Rows.First(r => r.Offered == 10);
        dataRow.AbandonPct.Should().BeApproximately(20.0, 0.01);
        dataRow.SlPct.Should().BeApproximately(75.0, 0.01);
        dataRow.Asa.Should().BeApproximately(10.0, 0.01);
        dataRow.QueueAht.Should().BeApproximately(60.0, 0.01);
    }

    [Fact]
    public async Task GetAgentMonthlyReport_AggregatesByMonth()
    {
        var intervals = new List<HistAgentInterval>
        {
            new()
            {
                Id = Guid.NewGuid(),
                TenantId = TenantId,
                IntervalStart = new DateTime(2026, 6, 1, 10, 0, 0, DateTimeKind.Utc),
                AgentExternalId = "agent1",
                SumOnphoneMs = 1800000,
                SumPaperworkMs = 600000,
                SumAvailableMs = 1200000,
                Handled = 5
            },
            new()
            {
                Id = Guid.NewGuid(),
                TenantId = TenantId,
                IntervalStart = new DateTime(2026, 6, 15, 10, 0, 0, DateTimeKind.Utc),
                AgentExternalId = "agent1",
                SumOnphoneMs = 1800000,
                SumPaperworkMs = 600000,
                SumAvailableMs = 1200000,
                Handled = 5
            }
        };

        _repo.GetAgentIntervalsAsync(
                TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
                Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(),
                Arg.Any<CancellationToken>())
            .Returns(intervals);

        var handler = new GetAgentMonthlyReportQueryHandler(_repo, _scopeResolver, _user);
        var result = await handler.Handle(
            new GetAgentMonthlyReportQuery(new DateTime(2026, 6, 1), new DateTime(2026, 7, 1)),
            CancellationToken.None);

        result.Rows.Should().HaveCount(1);
        result.Rows[0].YearMonth.Should().Be("2026-06");
        result.Rows[0].Handled.Should().Be(10);
        result.Rows[0].SumOnphoneMs.Should().Be(3600000);
    }

    [Fact]
    public async Task GetAgentShiftDetail_CalculatesTalkPureMs()
    {
        var interval = new HistAgentInterval
        {
            Id = Guid.NewGuid(),
            TenantId = TenantId,
            IntervalStart = new DateTime(2026, 6, 21, 10, 0, 0, DateTimeKind.Utc),
            AgentExternalId = "agent1",
            SumOnphoneMs = 1800000,
            SumHoldMs = 300000,
            SumPaperworkMs = 600000,
            SumAvailableMs = 1200000,
            Handled = 5
        };

        _repo.GetAgentIntervalsAsync(
                TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
                Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(),
                Arg.Any<CancellationToken>())
            .Returns(new List<HistAgentInterval> { interval });

        var handler = new GetAgentShiftDetailReportQueryHandler(_repo, _scopeResolver, _user);
        var result = await handler.Handle(
            new GetAgentShiftDetailReportQuery(DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Rows.Should().HaveCount(1);
        result.Rows[0].TalkPureMs.Should().Be(1500000);
    }

    [Fact]
    public async Task GetQueueWaitTimeReport_CalculatesOverallAsa()
    {
        var intervals = new List<HistQueueInterval>
        {
            new()
            {
                Id = Guid.NewGuid(),
                TenantId = TenantId,
                IntervalStart = new DateTime(2026, 6, 21, 10, 0, 0, DateTimeKind.Utc),
                Workgroup = "Sales",
                Answered = 10,
                SumWaitAnswered = 100,
                AnsweredInSl = 8
            },
            new()
            {
                Id = Guid.NewGuid(),
                TenantId = TenantId,
                IntervalStart = new DateTime(2026, 6, 21, 10, 30, 0, DateTimeKind.Utc),
                Workgroup = "Sales",
                Answered = 10,
                SumWaitAnswered = 200,
                AnsweredInSl = 6
            }
        };

        _repo.GetQueueIntervalsAsync(
                TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(),
                Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(),
                Arg.Any<CancellationToken>())
            .Returns(intervals);

        var handler = new GetQueueWaitTimeReportQueryHandler(_repo, _scopeResolver, _user);
        var result = await handler.Handle(
            new GetQueueWaitTimeReportQuery(DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.OverallAsa.Should().BeApproximately(15.0, 0.01);
    }

    [Fact]
    public async Task MultiTenantIsolation_QueriesCorrectTenant()
    {
        _user.TenantId.Returns(TenantId);

        var handler = new GetQueueIntervalReportQueryHandler(_repo, _scopeResolver, _user);
        await handler.Handle(
            new GetQueueIntervalReportQuery(DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        await _repo.Received(1).GetQueueIntervalsAsync(
            Arg.Is<Guid>(t => t == TenantId),
            Arg.Any<DateTime>(),
            Arg.Any<DateTime>(),
            Arg.Any<ReportScope>(),
            Arg.Any<IReadOnlySet<string>>(),
            Arg.Any<CancellationToken>());
    }
}
