using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Persistence.Repositories;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using NSubstitute;
using Testcontainers.PostgreSql;

namespace CcDashboard.Tests.Integration.HistoricalReports;

/// <summary>
/// PR234-V4-EOS-AGENTS-EMPTY-COLUMNS-01 / FEAT-REPORT-AGENT-PERF-01: the agent name rule (AgentNameRule) on real
/// PostgreSQL, through the repository the picker uses. Source: RTSData_UserStatus (DDL copied from db/schema.sql).
/// The rule: newest (UpdateTime) DisplayName that is neither empty nor the login (DisplayName = UserId).
/// Control (negative half): drop the "not the login" filter -> NameAndLoginMixed goes red (the newest row is the login);
/// compare without Trim -> PaddedLogin_And_BlankName_AreNoName goes red.
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
            CREATE TABLE public."RTSData_UserStatus" (
                "TenantId" uuid,
                "UserId" character varying(100) NOT NULL,
                "StatusId" character varying(100) NOT NULL,
                "ServerId" character varying(50) NOT NULL,
                "OnDate" character varying(50) NOT NULL,
                "StatusName" character varying(100),
                "StatusGroup" character varying(100),
                "TotalDuration" integer,
                "MaxDuraction" integer,
                "TotalCount" integer,
                "UpdateTime" timestamp with time zone,
                "DisplayName" character varying(100),
                "TimeZone" character varying(64));
            INSERT INTO public."RTSData_UserStatus" ("TenantId","UserId","StatusId","ServerId","OnDate","UpdateTime","DisplayName") VALUES
              -- a1@x: name and login alternate on one day from one server; the NEWEST row is the login (as for 5 of 68 on 234)
              (@t, 'a1@x', 'Available', 'S1', '05/11/2026', '2026-11-05 08:00Z', 'Dana Levi'),
              (@t, 'a1@x', 'OnPhone',   'S1', '05/11/2026', '2026-11-05 09:00Z', 'a1@x'),
              -- a2@x: only the login ever -> no real name, absent (the screen shows the id)
              (@t, 'a2@x', 'Available', 'S1', '05/11/2026', '2026-11-05 08:00Z', 'a2@x'),
              (@t, 'a2@x', 'Break',     'S1', '05/11/2026', '2026-11-05 09:00Z', ''),
              -- a5@x: the login padded with spaces is still the login; a blank-after-trim value is no name -> absent
              -- the padded login is the NEWEST row, so comparing before trimming would pick it
              (@t, 'a5@x', 'Break',     'S1', '05/11/2026', '2026-11-05 08:00Z', '   '),
              (@t, 'a5@x', 'Available', 'S1', '05/11/2026', '2026-11-05 09:00Z', ' a5@x '),
              -- a3@x: renamed between days -> the new name
              (@t, 'a3@x', 'Available', 'S1', '04/11/2026', '2026-11-04 08:00Z', 'Old Name'),
              (@t, 'a3@x', 'Available', 'S1', '05/11/2026', '2026-11-05 08:00Z', 'New Name'),
              -- a4@x: has a name but is not asked for
              (@t, 'a4@x', 'Available', 'S1', '05/11/2026', '2026-11-05 08:00Z', 'Nobody Asked'),
              -- a1@x in another tenant, with a newer real name
              (@o, 'a1@x', 'Available', 'S9', '06/11/2026', '2026-11-06 08:00Z', 'Foreign');
            """;
        cmd.Parameters.AddWithValue("t", Tenant);
        cmd.Parameters.AddWithValue("o", OtherTenant);
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DisposeAsync() => await _container.DisposeAsync();

    public HistoricalReportRepository Repository()
    {
        var app = new DbContextOptionsBuilder<AppDbContext>().UseNpgsql(ConnectionString).Options;
        var be = new DbContextOptionsBuilder<BackendEmulationDbContext>().UseNpgsql(ConnectionString).Options;
        var tenant = Substitute.For<ITenantContext>();
        tenant.TenantId.Returns(Tenant);
        return new HistoricalReportRepository(new AppDbContext(app, tenant), new AppFactory(app, tenant), new BeFactory(be));
    }

    private sealed class AppFactory(DbContextOptions<AppDbContext> options, ITenantContext tenant) : IDbContextFactory<AppDbContext>
    {
        public AppDbContext CreateDbContext() => new(options, tenant);
    }

    private sealed class BeFactory(DbContextOptions<BackendEmulationDbContext> options) : IDbContextFactory<BackendEmulationDbContext>
    {
        public BackendEmulationDbContext CreateDbContext() => new(options);
    }
}

public class AgentDisplayNamesTests(AgentDisplayNamesFixture fx) : IClassFixture<AgentDisplayNamesFixture>
{
    private Task<IReadOnlyDictionary<string, string>> Names(Guid tenant, params string[] ids) =>
        fx.Repository().GetAgentDisplayNamesAsync(tenant, new HashSet<string>(ids), CancellationToken.None);

    private Task<IReadOnlyDictionary<string, string>> Names(params string[] ids) => Names(AgentDisplayNamesFixture.Tenant, ids);

    [Fact]
    public async Task NameAndLoginMixed_TheNameWins_EvenWhenTheLoginIsNewer()
    {
        (await Names("a1@x"))["a1@x"].Should().Be("Dana Levi");
    }

    [Fact]
    public async Task OnlyTheLogin_IsAbsent_SoTheScreenShowsTheId()
    {
        var names = await Names("a1@x", "a2@x");
        names.Should().ContainKey("a1@x").And.NotContainKey("a2@x");
    }

    [Fact]
    public async Task PaddedLogin_And_BlankName_AreNoName()
    {
        // negative half: comparing before trimming lets " a5@x " through and it comes out as the "name" "a5@x"
        var names = await Names("a1@x", "a5@x");
        names.Should().ContainKey("a1@x").And.NotContainKey("a5@x");
    }

    [Fact]
    public async Task Renamed_TheNewName()
    {
        (await Names("a3@x"))["a3@x"].Should().Be("New Name");
    }

    [Fact]
    public async Task OtherTenant_SameId_IsNotMixedIn()
    {
        (await Names("a1@x"))["a1@x"].Should().NotBe("Foreign");
        (await Names(AgentDisplayNamesFixture.OtherTenant, "a1@x"))["a1@x"].Should().Be("Foreign",
            "negative half: the row is there, only for its own tenant");
    }

    [Fact]
    public async Task OnlyAskedIds_AreReturned()
    {
        (await Names("a3@x")).Keys.Should().Equal("a3@x");
    }

    [Fact]
    public async Task EmptySet_Empty()
    {
        (await Names()).Should().BeEmpty();
    }
}
