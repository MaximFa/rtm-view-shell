using CcDashboard.Application.Interfaces;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;
using System.Text.Json;

namespace CcDashboard.Infrastructure.Caching;

public class RedisCacheService(IConnectionMultiplexer redis, ILogger<RedisCacheService> logger) : ICacheService
{
    private IDatabase Db => redis.GetDatabase();

    public async Task<T?> GetAsync<T>(string key, CancellationToken ct = default) where T : class
    {
        try
        {
            var value = await Db.StringGetAsync(key);
            return value.IsNullOrEmpty ? null : JsonSerializer.Deserialize<T>(value!);
        }
        catch (RedisException ex)
        {
            logger.LogWarning(ex, "Redis unavailable — cache miss for key {Key}", key);
            return null;
        }
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan? ttl = null, CancellationToken ct = default) where T : class
    {
        try
        {
            var json = JsonSerializer.Serialize(value);
            await Db.StringSetAsync(key, json, ttl);
        }
        catch (RedisException ex)
        {
            logger.LogWarning(ex, "Redis unavailable — skipped cache set for key {Key}", key);
        }
    }

    public async Task RemoveAsync(string key, CancellationToken ct = default)
    {
        try { await Db.KeyDeleteAsync(key); }
        catch (RedisException ex) { logger.LogWarning(ex, "Redis unavailable — skipped remove for key {Key}", key); }
    }

    public async Task<bool> ExistsAsync(string key, CancellationToken ct = default)
    {
        try { return await Db.KeyExistsAsync(key); }
        catch (RedisException ex)
        {
            logger.LogWarning(ex, "Redis unavailable — ExistsAsync returning false for key {Key}", key);
            return false;
        }
    }
}
