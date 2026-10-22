using CcDashboard.Application.Handlers;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain.Historical;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;
using Xunit;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// BL-234-INTERACTION-TIME-AHEAD-01: after the engine fix the history holds TRUE UTC. A call at 13:00 Israel summer time
/// is the 10:00Z bucket. People must still read 13:00. Negative half in every test: "new write + old read" (no display
/// zone, i.e. the UTC value shown as is) gives 10:00 / the wrong day / the wrong month.
/// </summary>
public class DisplayTimeTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportScopeResolver _scope = Substitute.For<IReportScopeResolver>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();

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

    public DisplayTimeTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.Role.Returns("Superadmin");
        _scope.ResolveQueueScopeAsync(Arg.Any<CancellationToken>()).Returns(ReportScope.Full());
        _scope.ResolveAgentScopeAsync(Arg.Any<CancellationToken>()).Returns(ReportScope.Full());
    }

    private void QueueRowAt(DateTime utc) =>
        _repo.GetQueueIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>())
             .Returns(new List<HistQueueInterval> { new() { Id = Guid.NewGuid(), TenantId = TenantId, IntervalStart = utc, Workgroup = "Sales", Offered = 1, Answered = 1 } });

    [Fact]
    public async Task QueueInterval_CallAt13LocalSummer_IsShownAt13_NotAt10()
    {
        QueueRowAt(new DateTime(2026, 7, 15, 10, 0, 0, DateTimeKind.Utc)); // 13:00 Israel summer time (+03:00)
        var q = new GetQueueIntervalReportQuery(new DateTime(2026, 7, 15), new DateTime(2026, 7, 16));

        var shown = (await new GetQueueIntervalReportQueryHandler(_repo, _scope, _user, new Israel()).Handle(q, default)).Rows[0].IntervalStart;
        shown.ToString("HH:mm").Should().Be("13:00");

        var oldRead = (await new GetQueueIntervalReportQueryHandler(_repo, _scope, _user).Handle(q, default)).Rows[0].IntervalStart;
        oldRead.ToString("HH:mm").Should().Be("10:00", "negative half: new UTC write shown without conversion lands 3 h early");
    }

    [Fact]
    public async Task QueueInterval_Winter_UsesPlus2_BecauseTheZoneFollowsDst()
    {
        QueueRowAt(new DateTime(2026, 1, 15, 11, 0, 0, DateTimeKind.Utc)); // 13:00 Israel winter time (+02:00)
        var q = new GetQueueIntervalReportQuery(new DateTime(2026, 1, 15), new DateTime(2026, 1, 16));
        var shown = (await new GetQueueIntervalReportQueryHandler(_repo, _scope, _user, new Israel()).Handle(q, default)).Rows[0].IntervalStart;
        shown.ToString("HH:mm").Should().Be("13:00", "a fixed +03:00 (or the site's fixed +02:00 in summer) would be an hour off");
    }

    [Fact]
    public async Task PickedDays_AreLocalDays_ConvertedToUtcBounds()
    {
        QueueRowAt(new DateTime(2026, 7, 15, 10, 0, 0, DateTimeKind.Utc));
        var q = new GetQueueIntervalReportQuery(new DateTime(2026, 7, 15), new DateTime(2026, 7, 16));
        await new GetQueueIntervalReportQueryHandler(_repo, _scope, _user, new Israel()).Handle(q, default);

        // 15 Jul 00:00 Israel summer = 14 Jul 21:00Z. The old code asked from 15 Jul 00:00Z and lost 00:00-03:00 local.
        await _repo.Received(1).GetQueueIntervalsAsync(TenantId,
            new DateTime(2026, 7, 14, 21, 0, 0, DateTimeKind.Utc), new DateTime(2026, 7, 15, 21, 0, 0, DateTimeKind.Utc),
            Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task AgentMonthly_LateNightOnTheLastDay_CountsInTheLocalMonth()
    {
        // 31 Jul 22:30Z = 1 Aug 01:30 Israel: belongs to August for the people reading the report.
        _repo.GetAgentIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>())
             .Returns(new List<HistAgentInterval> { new() { Id = Guid.NewGuid(), TenantId = TenantId, IntervalStart = new DateTime(2026, 7, 31, 22, 30, 0, DateTimeKind.Utc), AgentExternalId = "a1" } });
        var q = new GetAgentMonthlyReportQuery(new DateTime(2026, 7, 1), new DateTime(2026, 8, 31));

        (await new GetAgentMonthlyReportQueryHandler(_repo, _scope, _user, new Israel()).Handle(q, default)).Rows[0].YearMonth.Should().Be("2026-08");
        (await new GetAgentMonthlyReportQueryHandler(_repo, _scope, _user).Handle(q, default)).Rows[0].YearMonth.Should().Be("2026-07", "negative half: UTC month");
    }

    [Fact]
    public void Helpers_RoundTrip_AndTodayIsTheLocalDay()
    {
        var z = new Israel().Zone;
        var utc = new DateTime(2026, 7, 15, 10, 0, 0, DateTimeKind.Utc);
        z.ToDisplay(utc).Should().Be(new DateTime(2026, 7, 15, 13, 0, 0));
        z.WallToUtc(z.ToDisplay(utc)).Should().Be(utc);
        // 22:30Z on 17 Oct is already 18 Oct in Israel (DayTrend default day).
        z.Today(new DateTime(2026, 10, 17, 22, 30, 0, DateTimeKind.Utc)).Should().Be(new DateOnly(2026, 10, 18));
        DateOnly.FromDateTime(new DateTime(2026, 10, 17, 22, 30, 0, DateTimeKind.Utc)).Should().Be(new DateOnly(2026, 10, 17), "negative half: the old default day was the UTC day");
    }
}
