using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using Microsoft.Extensions.Logging;
using NSubstitute;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// FEAT-REPORT-AGENT-PERF-01 agent picker. Security points, each with both halves:
/// empty BU set / BU without agents -> empty and no store query (the shape of PR234-V4-REPORT-FULLSCOPE-EMPTY-LEAK-01);
/// only scoped agents even if the store knows more; own tenant only; the 500 cut is flagged, not silent.
/// </summary>
public class GetScopedAgentsQueryTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private readonly IReportWidgetScopeService _scope = Substitute.For<IReportWidgetScopeService>();
    private readonly IHistoricalReportRepository _repo = Substitute.For<IHistoricalReportRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly ILogger<GetScopedAgentsQueryHandler> _log = Substitute.For<ILogger<GetScopedAgentsQueryHandler>>();
    private readonly GetScopedAgentsQueryHandler _handler;

    public GetScopedAgentsQueryTests()
    {
        _user.TenantId.Returns(TenantId);
        _user.UserId.Returns(Guid.NewGuid());
        _handler = new GetScopedAgentsQueryHandler(_scope, _repo, _user, _log);
        _repo.GetAgentDisplayNamesAsync(default, default!, default)
            .ReturnsForAnyArgs(new Dictionary<string, string>());
    }

    private void Effective(bool full, params string[] ids) =>
        _scope.ResolveAgentScopeAsync(Arg.Any<Guid>(), Arg.Any<ReportWidgetConfig>(), Arg.Any<AgentReportAxis>(), Arg.Any<CancellationToken>())
            .Returns(new ReportWidgetScopeResult { FullScope = full, EffectiveAgentIds = new HashSet<string>(ids) });

    private Task<ScopedAgentsResult> Run(params int[] bu) => _handler.Handle(new GetScopedAgentsQuery(bu), CancellationToken.None);

    [Fact]
    public async Task NoBusinessUnits_Empty_NothingAsked()
    {
        Effective(true, "a1");
        var r = await Run();
        r.Agents.Should().BeEmpty();
        await _scope.DidNotReceiveWithAnyArgs().ResolveAgentScopeAsync(default, default!, default, default);
        await _repo.DidNotReceiveWithAnyArgs().GetAgentDisplayNamesAsync(default, default!, default);

        (await Run(1)).Agents.Should().ContainSingle("negative half: a picked BU is resolved");
    }

    [Fact]
    public async Task BusinessUnitWithoutAgents_FullScope_Empty_NoStoreQuery()
    {
        Effective(true); // Superadmin, BU resolves to no agents
        var r = await Run(7);
        r.Agents.Should().BeEmpty();
        r.TotalCount.Should().Be(0);
        await _repo.DidNotReceiveWithAnyArgs().GetAgentDisplayNamesAsync(default, default!, default);
    }

    [Fact]
    public async Task OnlyScopedAgents_EvenIfTheStoreKnowsMore_SortedByName()
    {
        Effective(false, "a1", "a2");
        _repo.GetAgentDisplayNamesAsync(default, default!, default).ReturnsForAnyArgs(
            new Dictionary<string, string> { ["a1"] = "Zed", ["a2"] = "Amy", ["x9"] = "Foreign" });

        var r = await Run(1, 99); // 99: a BU outside the user's scope - contributes nothing, is not an error

        r.Agents.Select(a => (a.AgentId, a.DisplayName)).Should().Equal(("a2", "Amy"), ("a1", "Zed"));
        await _repo.Received(1).GetAgentDisplayNamesAsync(TenantId,
            Arg.Is<IReadOnlySet<string>>(s => s.SetEquals(new[] { "a1", "a2" })), Arg.Any<CancellationToken>());
        await _scope.Received(1).ResolveAgentScopeAsync(TenantId,
            Arg.Is<ReportWidgetConfig>(c => c.Scope.BusinessUnitIds!.SequenceEqual(new[] { 1, 99 })), AgentReportAxis.Detail, Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Denied_IsDenied_NoStoreQuery()
    {
        Effective(false); // non-Superadmin with an empty PG
        var r = await Run(1);
        r.Denied.Should().BeTrue();
        r.Agents.Should().BeEmpty();
        await _repo.DidNotReceiveWithAnyArgs().GetAgentDisplayNamesAsync(default, default!, default);
    }

    [Fact]
    public async Task UnknownName_FallsBackToTheId()
    {
        Effective(false, "a1");
        (await Run(1)).Agents.Should().ContainSingle().Which.DisplayName.Should().Be("a1");
    }

    [Theory]
    [InlineData(500, 500, false)]
    [InlineData(501, 500, true)]
    public async Task Limit500_TheCutIsFlagged(int inScope, int listed, bool truncated)
    {
        Effective(false, Enumerable.Range(0, inScope).Select(i => $"a{i:D4}").ToArray());
        var r = await Run(1);
        r.Agents.Should().HaveCount(listed);
        r.TotalCount.Should().Be(inScope);
        r.Truncated.Should().Be(truncated);
        _log.ReceivedCalls().Any(c => c.GetMethodInfo().Name == "Log" && Equals(c.GetArguments()[0], LogLevel.Warning))
            .Should().Be(truncated);
        GetScopedAgentsQueryHandler.Limit.Should().Be(500);
    }
}
