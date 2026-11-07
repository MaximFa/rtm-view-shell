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
/// Updated 2026-07-02: BU-ONLY scope (Mode/QueueIds removed).
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
            new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, "{ invalid json }", DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Error.Should().NotBeNullOrEmpty();
        result.WidgetType.Should().Be(ReportWidgetType.EndOfShiftQueues);
    }

    [Fact]
    public async Task ValidationFails_EmptyBuIds_ReturnsError()
    {
        var configJson = """
        {
            "scope": { "businessUnitIds": [] },
            "columns": [],
            "pageSize": 25
        }
        """;

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, configJson, DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Error.Should().NotBeNullOrEmpty();
        result.Error.Should().Contain("BusinessUnitIds");
    }

    [Fact]
    public async Task QueueSummary_Denied_ReturnsDenied()
    {
        var configJson = """
        {
            "scope": { "businessUnitIds": [1] },
            "columns": ["Offered"],
            "pageSize": 25
        }
        """;

        _scopeService.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { FullScope = false, EffectiveWorkgroups = new HashSet<string>(), DroppedCount = 0 });

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, configJson, DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Denied.Should().BeTrue();
        result.QueueSummary.Should().BeNull();
    }

    [Fact]
    public async Task QueueSummary_Superadmin_ReturnsData()
    {
        var configJson = """
        {
            "scope": { "businessUnitIds": [1] },
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
            new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, configJson, DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Denied.Should().BeFalse();
        result.Error.Should().BeNull();
        result.QueueSummary.Should().NotBeNull();
        result.QueueSummary!.Rows.Should().HaveCount(1);
        result.QueueSummary.Rows[0].Offered.Should().Be(10);
    }

    [Fact]
    public async Task AgentMonthly_Denied_ReturnsDenied()
    {
        var configJson = """
        {
            "scope": { "businessUnitIds": [1], "agentAxis": "detail" },
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
            "scope": { "businessUnitIds": [1], "agentAxis": "detail" },
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

    // FEAT-REPORT-EOS-CONFIGURABLE-01: the three retired queue reports answer "retired" and touch no store
    [Theory]
    [InlineData(ReportWidgetType.QueueInterval)]
    [InlineData(ReportWidgetType.QueueWaitTime)]
    [InlineData(ReportWidgetType.Distribution)]
    public async Task RetiredTypes_AnswerRetired_WithoutTouchingTheStore(ReportWidgetType widgetType)
    {
        var result = await _handler.Handle(
            new RunReportWidgetQuery(widgetType, """{ "scope": { "businessUnitIds": [1] } }""", DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.ErrorCode.Should().Be(ReportReasonCodes.Retired);
        result.Denied.Should().BeFalse();
        await _scopeService.DidNotReceiveWithAnyArgs().ResolveQueueScopeAsync(default, default!, default);
        await _repo.DidNotReceiveWithAnyArgs().GetQueueIntervalsAsync(default, default, default, default!, default!, default);
    }

    [Fact]
    public async Task EndOfShiftQueues_IsNotRetired()
    {
        // negative half of the theory above
        _scopeService.ResolveQueueScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { FullScope = true, EffectiveWorkgroups = new HashSet<string> { "Sales" } });
        _repo.GetQueueIntervalsAsync(default, default, default, default!, default!, default).ReturnsForAnyArgs(new List<HistQueueInterval>());
        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, """{ "scope": { "businessUnitIds": [1] } }""", DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);
        result.ErrorCode.Should().BeNull();
        result.QueueSummary.Should().NotBeNull();
    }

    [Fact]
    public async Task DateRangeInclusive_ToDateAddsDays()
    {
        var configJson = """
        {
            "scope": { "businessUnitIds": [1] },
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
            new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, configJson, from, to),
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
            "scope": { "businessUnitIds": [1] },
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
            new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, configJson, DateTime.UtcNow.AddDays(-3), DateTime.UtcNow, Page: 1),
            CancellationToken.None);

        result.QueueSummary.Should().NotBeNull();
        result.QueueSummary!.PageSize.Should().Be(50);
    }

    [Fact]
    public async Task AgentWidget_NoBuIds_ValidationFails()
    {
        // BU-ONLY scope: agent widgets require BusinessUnitIds
        var configJson = """
        {
            "scope": { "businessUnitIds": [], "agentAxis": "detail" },
            "columns": ["SumAvailableMs"],
            "pageSize": 25
        }
        """;

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.AgentMonthly, configJson, DateTime.UtcNow.AddDays(-30), DateTime.UtcNow),
            CancellationToken.None);

        result.Error.Should().NotBeNullOrEmpty();
        result.Error.Should().Contain("BusinessUnitIds");
    }

    [Fact]
    public async Task AgentWidget_BuScope_NoAgentAxis_ValidationFails()
    {
        var configJson = """
        {
            "scope": { "businessUnitIds": [1] },
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

    #region Columns optional v1 tests

    [Fact]
    public async Task ScopeOnlyConfig_NoColumns_ReturnsDefaultColumns()
    {
        // v1: Columns optional — server supplies DefaultColumns for the widget type
        var configJson = """
        {
            "scope": { "businessUnitIds": [1] },
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
            .Returns(new List<HistQueueInterval>
            {
                new() { Id = Guid.NewGuid(), TenantId = TenantId, IntervalStart = DateTime.UtcNow, Workgroup = "Sales", Offered = 10 }
            });

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, configJson, DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        result.Error.Should().BeNull();
        result.Denied.Should().BeFalse();
        result.EffectiveColumns.Should().NotBeNull();
        result.EffectiveColumns.Should().BeEquivalentTo(ReportWidgetConfig.DefaultColumns(ReportWidgetType.EndOfShiftQueues));
    }

    [Fact]
    public async Task ExplicitColumns_PreservedInResult()
    {
        var configJson = """
        {
            "scope": { "businessUnitIds": [1] },
            "columns": ["Offered", "Answered"],
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

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.EndOfShiftQueues, configJson, DateTime.UtcNow.AddDays(-1), DateTime.UtcNow),
            CancellationToken.None);

        // the picked columns keep their order; PR234-V4-EOS-QUEUES-SAVED-COLUMNS-NO-INTERVAL-01 puts the interval start first
        result.EffectiveColumns.Should().Equal("IntervalStart", "Offered", "Answered");
    }

    [Fact]
    public async Task AgentMonthly_NoColumns_UsesDefaultColumns()
    {
        var configJson = """
        {
            "scope": { "businessUnitIds": [1], "agentAxis": "detail" },
            "pageSize": 25
        }
        """;

        _scopeService.ResolveAgentScopeAsync(TenantId, Arg.Any<ReportWidgetConfig>(), AgentReportAxis.Detail, Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult
            {
                FullScope = true,
                EffectiveAgentIds = new HashSet<string> { "agent1" }
            });

        _repo.GetAgentIntervalsAsync(TenantId, Arg.Any<DateTime>(), Arg.Any<DateTime>(), Arg.Any<ReportScope>(), Arg.Any<IReadOnlySet<string>>(), Arg.Any<CancellationToken>())
            .Returns(new List<HistAgentInterval>());

        var result = await _handler.Handle(
            new RunReportWidgetQuery(ReportWidgetType.AgentMonthly, configJson, DateTime.UtcNow.AddDays(-30), DateTime.UtcNow),
            CancellationToken.None);

        result.Error.Should().BeNull();
        result.EffectiveColumns.Should().BeEquivalentTo(ReportWidgetConfig.DefaultColumns(ReportWidgetType.AgentMonthly));
    }

    #endregion
}
