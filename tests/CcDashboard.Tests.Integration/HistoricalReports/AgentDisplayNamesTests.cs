using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Persistence.Repositories;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using NSubstitute;
using Testcontainers.PostgreSql;

namespace CcDashboard.Tests.Integration.HistoricalReports;

/// <summary>
/// FEAT-REPORT-AGENT-PERF-01: GetAgentDisplayNamesAsync on real PostgreSQL - the per-agent "newest non-empty name"
/// query is translated by EF/Npgsql, which no unit test can check.
/// Table shape copied from migration 20260621080000_AddHistoricalReportsTables (without partitioning).
/// Control (negative half): order the names oldest-first in the repository -> NewestNonEmptyName goes red.
/// </summary>
public class AgentDisplayNamesFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder("postgres:16-alpine")
        .WithDatabase("hist_names_test").WithUsername("test").WithPassword("test").Build();

    public static readonly Guid Tenant = Guid.NewGuid();
    public static readonly Guid OtherTenant = Guid.NewGuid();
    public string ConnectionString { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        ConnectionString = _container.GetConnectionString();
        await using var conn = new Npgsql.NpgsqlConnection(ConnectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = """
            CREATE TABLE public.hist_agent_intervals (
                "Id" uuid NOT NULL,
                "TenantId" uuid NOT NULL,
                "IntervalStart" timestamptz NOT NULL,
                "AgentExternalId" varchar(100) NOT NULL,
                "AgentDisplayName" varchar(200) NULL,
                "SumAvailableMs" bigint NOT NULL DEFAULT 0,
                "SumOnphoneMs" bigint NOT NULL DEFAULT 0,
                "SumHoldMs" bigint NOT NULL DEFAULT 0,
                "SumPaperworkMs" bigint NOT NULL DEFAULT 0,
                "SumBreakMs" bigint NOT NULL DEFAULT 0,
                "SumTrainingMs" bigint NOT NULL DEFAULT 0,
                "SumUnavailableMs" bigint NOT NULL DEFAULT 0,
                "SumLoggedInMs" bigint NOT NULL DEFAULT 0,
                "Handled" int NOT NULL DEFAULT 0,
                "CreatedAt" timestamptz NOT NULL DEFAULT now(),
                "UpdatedAt" timestamptz NOT NULL DEFAULT now(),
                PRIMARY KEY ("Id", "IntervalStart"));
            INSERT INTO public.hist_agent_intervals ("Id","TenantId","IntervalStart","AgentExternalId","AgentDisplayName") VALUES
              -- a1: renamed; the newest rows have no name -> the newest NON-EMPTY name wins ("New")
              (gen_random_uuid(), @t, '2026-11-01 10:00Z', 'a1', 'Old'),
              (gen_random_uuid(), @t, '2026-11-02 11:00Z', 'a1', 'New'),
              (gen_random_uuid(), @t, '2026-11-03 12:00Z', 'a1', NULL),
              (gen_random_uuid(), @t, '2026-11-03 13:00Z', 'a1', ''),
              -- a2: one name
              (gen_random_uuid(), @t, '2026-11-01 10:00Z', 'a2', 'Bob'),
              -- a3: never a name
              (gen_random_uuid(), @t, '2026-11-01 10:00Z', 'a3', NULL),
              (gen_random_uuid(), @t, '2026-11-02 10:00Z', 'a3', ''),
              -- a4: has a name but is not asked for
              (gen_random_uuid(), @t, '2026-11-01 10:00Z', 'a4', 'Nobody asked'),
              -- the same id in another tenant, newer than everything above
              (gen_random_uuid(), @o, '2026-11-04 09:00Z', 'a1', 'Foreign');
            """;
        cmd.Parameters.AddWithValue("t", Tenant);
        cmd.Parameters.AddWithValue("o", OtherTenant);
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DisposeAsync() => await _container.DisposeAsync();

    public HistoricalReportRepository Repository()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>().UseNpgsql(ConnectionString).Options;
        var tenant = Substitute.For<ITenantContext>();
        tenant.TenantId.Returns(Tenant);
        return new HistoricalReportRepository(new AppDbContext(options, tenant), new Factory(options, tenant));
    }

    private sealed class Factory(DbContextOptions<AppDbContext> options, ITenantContext tenant) : IDbContextFactory<AppDbContext>
    {
        public AppDbContext CreateDbContext() => new(options, tenant);
    }
}

public class AgentDisplayNamesTests(AgentDisplayNamesFixture fx) : IClassFixture<AgentDisplayNamesFixture>
{
    private Task<IReadOnlyDictionary<string, string>> Names(params string[] ids) =>
        fx.Repository().GetAgentDisplayNamesAsync(AgentDisplayNamesFixture.Tenant, new HashSet<string>(ids), CancellationToken.None);

    [Fact]
    public async Task NewestNonEmptyName_PerAgent()
    {
        var names = await Names("a1", "a2");
        names["a1"].Should().Be("New", "the newer rows have no name; 'Old' is older");
        names["a2"].Should().Be("Bob");
    }

    [Fact]
    public async Task AgentWithOnlyEmptyNames_IsAbsent()
    {
        var names = await Names("a1", "a3");
        names.Should().ContainKey("a1").And.NotContainKey("a3");
    }

    [Fact]
    public async Task OtherTenant_SameId_IsNotMixedIn()
    {
        (await Names("a1"))["a1"].Should().NotBe("Foreign");
        var other = await fx.Repository().GetAgentDisplayNamesAsync(AgentDisplayNamesFixture.OtherTenant, new HashSet<string> { "a1" }, CancellationToken.None);
        other["a1"].Should().Be("Foreign", "negative half: the row is there, only for its own tenant");
    }

    [Fact]
    public async Task OnlyAskedIds_AreReturned()
    {
        var names = await Names("a2");
        names.Keys.Should().Equal("a2");
    }

    [Fact]
    public async Task EmptySet_Empty()
    {
        (await Names()).Should().BeEmpty();
    }
}
