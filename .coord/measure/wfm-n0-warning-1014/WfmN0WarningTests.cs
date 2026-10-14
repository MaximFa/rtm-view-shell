using CcDashboard.Domain.Domain;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Wfm;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using NSubstitute;

namespace CcDashboard.Tests.Security.Wfm;

/// <summary>
/// N=0 with a non-empty roster has two causes and only one needs a human: the configured serving
/// group names are absent from the TENANT's data (misconfiguration), or they are present and nobody
/// is in them right now (an idle shift). The old branch warned on both, which at 21 queues x 120
/// ticks is roughly 2500 Warning lines an hour saying nothing is wrong.
///
/// The comparison is against the tenant's values on purpose. Over the same agentList the count query
/// already answers the question - a non-empty intersection there means count >= 1 - so a test taken
/// over agentList is vacuous inside this branch. That is what the second test below pins.
/// </summary>
[Collection("Postgres")]
public class WfmN0WarningTests(PostgresFixture postgres)
{
    // Each test gets its OWN tenant id, and that is the fix for the two reds of 05:39Z.
    // PostgresFixture starts one container per collection and never truncates between tests
    // (InitializeAsync/DisposeAsync only create and drop the container), so rows accumulate.
    // GetServingAgentCountsAsync loops over EVERY queue of the tenant and logs per queue, so with
    // a shared tenant one test sees log lines produced by another test's leftover queues - which is
    // exactly what "HealthyTick_LogsNothingAtAll" caught, and why the Warning assertions were
    // unreliable. BackendEmulationDbContext has no query filters and no FK to a tenants table
    // (measured: HasQueryFilter 0 occurrences; no HasOne on a tenant), so an arbitrary Guid is a
    // valid, fully isolated tenant here.
    private readonly Guid _tenant = Guid.NewGuid();
    private readonly Guid _foreignTenant = Guid.NewGuid();

    [Fact]
    public async Task ConfiguredNameAbsentFromTenantData_WarnsWithBothSides()
    {
        // Configured "Available" against a tenant whose data holds only "AVAILABLE": the count query
        // compares with = ANY(...), which is exact, so N = 0. No configured name exists anywhere in
        // the tenant -> misconfiguration, and the log must say so with both sides.
        var seed = await SeedAsync(agentGroups: new[] { "AVAILABLE" });
        var logger = new CollectingLogger<WfmInputQueryService>();
        var svc = new WfmInputQueryService(Factory(), logger);

        var counts = await svc.GetServingAgentCountsAsync(
            _tenant, new[] { "Available" }, default);

        counts[seed.QueueId].Should().Be(0);

        var warning = logger.Entries.Should().ContainSingle(e => e.Level == LogLevel.Warning).Subject;
        warning.Message.Should().Contain("Available");   // configured side
        warning.Message.Should().Contain("AVAILABLE");   // tenant side
        warning.Message.Should().Contain(seed.QueueId);
    }

    [Fact]
    public async Task ConfiguredNamePresentElsewhereInTenant_DoesNotWarn()
    {
        // The case the old shape could not express, and the reason point 1 was withdrawn: the roster
        // agent is in BREAK, so N = 0, but "AVAILABLE" does exist in this tenant's data (another user,
        // earlier in the shift). Nothing is misconfigured - this is a quiet shift and must stay quiet.
        // NEGATIVE half: a fix that always warns passes the first test and fails this one.
        var seed = await SeedAsync(
            agentGroups: new[] { "BREAK" },
            otherUserOfSameTenantGroups: new[] { "AVAILABLE" });   // same tenant, NOT on this roster
        var logger = new CollectingLogger<WfmInputQueryService>();
        var svc = new WfmInputQueryService(Factory(), logger);

        var counts = await svc.GetServingAgentCountsAsync(
            _tenant, new[] { "AVAILABLE" }, default);

        counts[seed.QueueId].Should().Be(0);
        logger.Entries.Should().NotContain(e => e.Level == LogLevel.Warning);
    }

    [Fact]
    public async Task AnotherTenantsGroups_DoNotSilenceTheWarning()
    {
        // Guards the TenantId gate in the new query. A DIFFERENT tenant holds "AVAILABLE"; this
        // test's tenant does not. The call must still warn - otherwise a neighbour's data would
        // mute the alarm, and the query would be wrong in the one direction nobody notices.
        await SeedAsync(agentGroups: new[] { "BREAK" });
        await SeedForeignTenantStatusAsync("AVAILABLE");
        var logger = new CollectingLogger<WfmInputQueryService>();
        var svc = new WfmInputQueryService(Factory(), logger);

        await svc.GetServingAgentCountsAsync(
            _tenant, new[] { "AVAILABLE" }, default);

        logger.Entries.Should().Contain(e => e.Level == LogLevel.Warning);
    }

    [Fact]
    public async Task EmptyRoster_DoesNotWarn()
    {
        // Other half of the outer condition: with no agents resolved there is nothing to
        // misconfigure, and the branch must not blame the setting.
        var seed = await SeedAsync(agentGroups: Array.Empty<string>(), withAgent: false);
        var logger = new CollectingLogger<WfmInputQueryService>();
        var svc = new WfmInputQueryService(Factory(), logger);

        var counts = await svc.GetServingAgentCountsAsync(
            _tenant, new[] { "AVAILABLE" }, default);

        counts[seed.QueueId].Should().Be(0);
        logger.Entries.Should().NotContain(e => e.Level == LogLevel.Warning);
    }

    [Fact]
    public async Task HealthyTick_LogsNothingAtAll()
    {
        // The branch is lazy by design: on a tick where somebody is serving, the tenant-wide DISTINCT
        // must never run and nothing is logged - not even Debug. Without this test the new query
        // could quietly become per-tick work on every healthy tick.
        var seed = await SeedAsync(agentGroups: new[] { "AVAILABLE" });
        var logger = new CollectingLogger<WfmInputQueryService>();
        var svc = new WfmInputQueryService(Factory(), logger);

        var counts = await svc.GetServingAgentCountsAsync(
            _tenant, new[] { "AVAILABLE" }, default);

        counts[seed.QueueId].Should().Be(1);
        // The tenant is this test's own, so "nothing at all" is a statement about this tenant only.
        counts.Should().HaveCount(1, "the tenant must hold exactly this test's queue");
        logger.Entries.Should().BeEmpty();
    }

    // ── helpers ──────────────────────────────────────────────────────────────────

    private IDbContextFactory<BackendEmulationDbContext> Factory()
    {
        var factory = Substitute.For<IDbContextFactory<BackendEmulationDbContext>>();
        factory.CreateDbContextAsync(Arg.Any<CancellationToken>())
               .Returns(_ => Task.FromResult(postgres.CreateBackendEmulationDbContext()));
        return factory;
    }

    private record Seeded(string QueueId, string UserId);

    /// <summary>
    /// Seeds the §36a chain the service walks - BU -> Queue("ALL") and BU -> SG -> AG -> user - then
    /// one RTSData_UserStatus row per group in <paramref name="agentGroups"/> for that user, and
    /// optionally rows for a SECOND user of the same tenant who is not on this roster.
    /// Ids are database-generated (UseIdentityAlwaysColumn), so they are read back, not assigned.
    /// </summary>
    private async Task<Seeded> SeedAsync(
        string[] agentGroups,
        bool withAgent = true,
        string[]? otherUserOfSameTenantGroups = null)
    {
        var tenant = _tenant;
        var suffix = Guid.NewGuid().ToString("N")[..8];
        var queueId = $"Q-{suffix}";
        var agId = $"AG-{suffix}";
        var userId = $"U-{suffix}";

        await using var db = postgres.CreateBackendEmulationDbContext();

        var bu = new NgcBusinessUnit { TenantId = tenant, BusinessUnitName = $"BU-{suffix}" };
        var sg = new NgcSupergroup { TenantId = tenant, SupergroupName = $"SG-{suffix}" };
        db.NgcBusinessUnits.Add(bu);
        db.NgcSupergroups.Add(sg);
        await db.SaveChangesAsync();

        db.NgcBusinessUnitQueueClassifications.Add(new NgcBusinessUnitQueueClassification
        {
            TenantId = tenant, BusinessUnitId = bu.BusinessUnitId,
            QueueId = queueId, ClassificationId = "ALL"
        });
        db.NgcBusinessUnitSupergroups.Add(new NgcBusinessUnitSupergroup
        {
            TenantId = tenant, BusinessUnitId = bu.BusinessUnitId, SupergroupId = sg.SupergroupId
        });
        db.NgcSupergroupAgentgroups.Add(new NgcSupergroupAgentgroup
        {
            TenantId = tenant, SupergroupId = sg.SupergroupId, AgentgroupId = agId
        });

        if (withAgent)
        {
            db.NgcUserAgentgroups.Add(new NgcUserAgentgroup
            {
                TenantId = tenant, AgentgroupId = agId, UserId = userId
            });

            foreach (var group in agentGroups)
                db.RtsDataUserStatuses.Add(NewStatus(tenant, userId, group));
        }

        if (otherUserOfSameTenantGroups is not null)
        {
            var otherUser = $"U-OTHER-{suffix}";
            foreach (var group in otherUserOfSameTenantGroups)
                db.RtsDataUserStatuses.Add(NewStatus(tenant, otherUser, group));
        }

        await db.SaveChangesAsync();
        return new Seeded(queueId, userId);
    }

    /// <summary>Rows for a DIFFERENT tenant id, to prove the TenantId gate on the new query.</summary>
    private async Task SeedForeignTenantStatusAsync(string group)
    {
        await using var db = postgres.CreateBackendEmulationDbContext();
        db.RtsDataUserStatuses.Add(
            NewStatus(_foreignTenant, $"U-B-{Guid.NewGuid():N}", group));
        await db.SaveChangesAsync();
    }

    private static RtsDataUserStatus NewStatus(Guid tenantId, string userId, string group) => new()
    {
        TenantId = tenantId,
        UserId = userId,
        StatusId = $"S-{group}",
        ServerId = "SRV1",
        OnDate = DateTime.UtcNow.ToString("dd/MM/yyyy"),
        StatusGroup = group
    };

    /// <summary>Collects entries so a test can assert on level AND on the rendered text.</summary>
    private sealed class CollectingLogger<T> : ILogger<T>
    {
        public record Entry(LogLevel Level, string Message);

        public List<Entry> Entries { get; } = new();

        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(
            LogLevel logLevel, EventId eventId, TState state, Exception? exception,
            Func<TState, Exception?, string> formatter)
            => Entries.Add(new Entry(logLevel, formatter(state, exception)));
    }
}
