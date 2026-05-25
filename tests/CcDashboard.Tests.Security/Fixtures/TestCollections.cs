namespace CcDashboard.Tests.Security.Fixtures;

/// <summary>
/// xUnit collection definitions for shared fixtures.
/// Note: PostgresCollection is defined in PostgresFixture.cs.
/// </summary>
[CollectionDefinition("Redis")]
public class RedisCollection : ICollectionFixture<RedisFixture>
{
}

[CollectionDefinition("PostgresAndRedis")]
public class PostgresAndRedisCollection : ICollectionFixture<PostgresFixture>, ICollectionFixture<RedisFixture>
{
}
