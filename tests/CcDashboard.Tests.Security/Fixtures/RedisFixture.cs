using StackExchange.Redis;
using Testcontainers.Redis;

namespace CcDashboard.Tests.Security.Fixtures;

/// <summary>
/// xUnit collection fixture that manages a shared Redis Testcontainer.
/// Required for JTI revocation (AUTH-API-05) and rate limiting (BFP-02) tests.
/// </summary>
public class RedisFixture : IAsyncLifetime
{
    private readonly RedisContainer _container;

    public string ConnectionString { get; private set; } = null!;
    public IConnectionMultiplexer Connection { get; private set; } = null!;

    public RedisFixture()
    {
        _container = new RedisBuilder()
            .WithImage("redis:7-alpine")
            .Build();
    }

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        ConnectionString = _container.GetConnectionString();
        // allowAdmin=true required for FLUSHALL in tests
        Connection = await ConnectionMultiplexer.ConnectAsync($"{ConnectionString},allowAdmin=true");
    }

    public async Task DisposeAsync()
    {
        Connection.Dispose();
        await _container.DisposeAsync();
    }

    public IDatabase GetDatabase() => Connection.GetDatabase();

    public async Task FlushAllAsync()
    {
        var server = Connection.GetServer(Connection.GetEndPoints()[0]);
        await server.FlushAllDatabasesAsync();
    }
}
