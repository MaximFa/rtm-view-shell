using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Application.Handlers;
using CcDashboard.Domain.Domain.Historical;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using Microsoft.Extensions.Logging;
using NSubstitute;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// Tests for RunReportWidgetQuery — the single entry point for report widgets.
/// SF-BI-001: Scope + validation server-side, NON-BYPASSABLE.
/// SF-BI-002: Out-of-scope entries dropped + logged.
/// </summary>
public class RunReportWidgetQueryTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly IReportWidgetScopeService _scopeService = Substitute.For<IReportWidgetScopeService>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly ILogger<RunReportWidgetQueryHandler> _logger = Substitute.For<ILogger<RunReportWidgetQueryHandler>>();
    private readonly RunReportWidgetQueryHandler _handler;

    public RunReportWidgetQueryTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.UserId.Returns(Guid.NewGuid());
        _user.PermissionGroupId.Returns(Guid.NewGuid());
        _handler = new RunReportWidgetQueryHandler(_repo, _scopeService, _user, _logger);
    }

    [Fact]
    public async Task InvalidConfigJson_ReturnsError()
    {
        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.QueueInterval, "{ invalid json }", DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Error.Should().NotBeNullOrEmpty();
        result.WidgetType.Should().Be(ReportWidgetType.QueueInterval);
    }

    [Fact]
    public async Task ValidationFails_ReturnsError()
    {
        var configJson = """
        {
            "scope": { "mode": "invalid", "queueIds": [] },
            "columns": [],
            "pageSize": 999
        }
        """;

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.QueueInterval, configJson, DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Error.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task QueueInterval_Denied_ReturnsDenied()
    {
        var configJson = """
        {
            "scope": { "mode": "bu", "businessUnitIds": [1] },
            "columns": ["Offered"],
            "pageSize": 25
        }
        """;

        _scopeService.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { FullScope = false, EffectiveWorkgroups = new HashSet<string>(), DroppedCount = 0 });

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.QueueInterval, configJson, DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Denied.Should().BeTrue();
        result.QueueInterval.Should().BeNull();
    }

    [Fact]
    public async Task QueueInterval_Superadmin_ReturnsData()
    {
        var configJson = """
        {
            "scope": { "mode": "bu", "businessUnitIds": [1] },
            "columns": ["Offered"],
            "pageSize": 25
        }
        """;

        _scopeService.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult
            {
                FullScope = true,
                EffectiveWorkgroups = new HashSet<string> { "Sales", "Support" }
            });

        var intervals = new List<HistQueueInterval>
        {
            new() { Id = Guid.NewGuid(), TenantId = TenantId, IntervalStart = DateTime.UtcNow.AddHours(-1), Workgroup = "Sales", Offered = 10, Answered = 8, Abandoned = 2, AnsweredInSl = 7, SumWaitAnswered = 120, SumTalk = 300 }
        };
        _repo.GetQueueIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>())
            .Returns(intervals);

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.QueueInterval, configJson, DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Denied.Should().BeFalse();
        result.Error.Should().BeNull();
        result.QueueInterval.Should().NotBeNull();
        result.QueueInterval!.Rows.Should().HaveCount(1);
        result.QueueInterval.Rows[0].Workgroup.Should().Be("Sales");
    }

    [Fact]
    public async Task AgentMonthly_Denied_ReturnsDenied()
    {
        var configJson = """
        {
            "scope": { "mode": "bu", "businessUnitIds": [1], "agentAxis": "detail" },
            "columns": ["SumAvailableMs"],
            "pageSize": 25
        }
        """;

        _scopeService.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), AgentReportAxis.Detail, Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { FullScope = false, EffectiveAgentIds = new HashSet<string>(), DroppedCount = 0 });

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.AgentMonthly, configJson, DateTime.UtcNow.AddDays(-30), DateTime.UtcNow),
            CancellationToken.None);

        result.Denied.Should().BeTrue();
        result.AgentMonthly.Should().BeNull();
    }

    [Fact]
    public async Task AgentMonthly_WithData_GroupsByYearMonth()
    {
        var configJson = """
        {
            "scope": { "mode": "bu", "businessUnitIds": [1], "agentAxis": "detail" },
            "columns": ["SumAvailableMs"],
            "pageSize": 25
        }
        """;

        _scopeService.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), AgentReportAxis.Detail, Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult
            {
                FullScope = true,
                EffectiveAgentIds = new HashSet<string> { "agent1" }
            });

        var intervals = new List<HistAgentInterval>
        {
            new() { Id = Guid.NewGuid(), TenantId = TenantId, IntervalStart = new DateTime(2026, 6, 1, 8, 0, 0, DateTimeKind.Utc), AgentExternalId = "agent1", SumAvailableMs = 100000, SumOnphoneMs = 50000, Handled = 10 },
            new() { Id = Guid.NewGuid(), TenantId = TenantId, IntervalStart = new DateTime(2026, 6, 1, 9, 0, 0, DateTimeKind.Utc), AgentExternalId = "agent1", SumAvailableMs = 100000, SumOnphoneMs = 60000, Handled = 12 }
        };
        _repo.GetAgentIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>())
            .Returns(intervals);

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.AgentMonthly, configJson, new DateTime(2026, 6, 1), new DateTime(2026, 6, 30)),
            CancellationToken.None);

        result.AgentMonthly.Should().NotBeNull();
        result.AgentMonthly!.Rows.Should().HaveCount(1);
        result.AgentMonthly.Rows[0].YearMonth.Should().Be("2026-06");
        result.AgentMonthly.Rows[0].SumAvailableMs.Should().Be(200000);
        result.AgentMonthly.Rows[0].Handled.Should().Be(22);
    }

    [Fact]
    public async Task Distribution_ReturnsDistributionBuckets()
    {
        var configJson = """
        {
            "scope": { "mode": "bu", "businessUnitIds": [1] },
            "columns": ["Distribution"],
            "pageSize": 25
        }
        """;

        _scopeService.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult
            {
                FullScope = true,
                EffectiveWorkgroups = new HashSet<string> { "Sales" }
            });

        var intervals = new List<HistQueueInterval>
        {
            new() { Id = Guid.NewGuid(), TenantId = TenantId, IntervalStart = DateTime.UtcNow.AddHours(-1), Workgroup = "Sales", Offered = 100, Answered = 80, Abandoned = 20, AnsweredInSl = 60, SumWaitAnswered = 1000, SumTalk = 5000 }
        };
        _repo.GetQueueIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>())
            .Returns(intervals);

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.Distribution, configJson, DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Distribution.Should().NotBeNull();
        result.Distribution!.Buckets.Should().HaveCount(3);
        result.Distribution.TotalCount.Should().Be(80);
        result.Distribution.Buckets.Should().Contain(b => b.Label == "Answered in SL" && b.Count == 60);
        result.Distribution.Buckets.Should().Contain(b => b.Label == "Abandoned" && b.Count == 20);
    }

    [Fact]
    public async Task DateRangeInclusive_ToDateAddsDays()
    {
        var configJson = """
        {
            "scope": { "mode": "bu", "businessUnitIds": [1] },
            "columns": ["Offered"],
            "pageSize": 25
        }
        """;

        _scopeService.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult
            {
                FullScope = true,
                EffectiveWorkgroups = new HashSet<string> { "Sales" }
            });

        _repo.GetQueueIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>())
            .Returns(new List<HistQueueInterval>());

        var from = new DateTime(2026, 6, 1);
        var to = new DateTime(2026, 6, 10);

        await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.QueueInterval, configJson, from, to),
            CancellationToken.None);

        await _repo.Received(1).GetQueueIntervalsAsync(
            TenantId,
            from.Date,
            to.Date.AddDays(1),
            Arg.Any<ReportScope>(),
            Arg.Any<IReadOnlySet<string>>(),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task PageSize_FromConfig_AppliedToPagination()
    {
        var configJson = """
        {
            "scope": { "mode": "bu", "businessUnitIds": [1] },
            "columns": ["Offered"],
            "pageSize": 50
        }
        """;

        _scopeService.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult
            {
                FullScope = true,
                EffectiveWorkgroups = new HashSet<string> { "Sales" }
            });

        var intervals = Enumerable.Range(0, 100)
            .Select(i => new HistQueueInterval
            {
                Id = Guid.NewGuid(),
                TenantId = TenantId,
                IntervalStart = DateTime.UtcNow.AddMinutes(-i * 30),
                Workgroup = "Sales",
                Offered = 10
            })
            .ToList();

        _repo.GetQueueIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>())
            .Returns(intervals);

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.QueueInterval, configJson, DateTime.UtcNow.AddDays(-3), DateTime.UtcNow, Page: 1),
            CancellationToken.None);

        result.QueueInterval.Should().NotBeNull();
        result.QueueInterval!.PageSize.Should().Be(50);
        result.QueueInterval.Rows.Should().HaveCount(50);
        result.QueueInterval.TotalCount.Should().Be(100);
    }

    [Fact]
    public async Task AgentWidget_QueuesMode_ValidationFails()
    {
        var queueId = Guid.NewGuid();
        var configJson = $$"""
        {
            "scope": { "mode": "queues", "queueIds": ["{{queueId}}"] },
            "columns": ["SumAvailableMs"],
            "pageSize": 25
        }
        """;

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.AgentMonthly, configJson, DateTime.UtcNow.AddDays(-30), DateTime.UtcNow),
            CancellationToken.None);

        result.Error.Should().NotBeNullOrEmpty();
        result.Error.Should().Contain("Agent widgets do not support");
    }

    [Fact]
    public async Task AgentWidget_BuMode_NoAgentAxis_ValidationFails()
    {
        var configJson = """
        {
            "scope": { "mode": "bu", "businessUnitIds": [1] },
            "columns": ["SumAvailableMs"],
            "pageSize": 25
        }
        """;

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.AgentShiftDetail, configJson, DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Error.Should().NotBeNullOrEmpty();
        result.Error.Should().Contain("AgentAxis");
    }
}
