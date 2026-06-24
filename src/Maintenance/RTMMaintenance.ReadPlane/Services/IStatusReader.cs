namespace RTMMaintenance.ReadPlane.Services;

public interface IStatusReader
{
    Task<ServiceStatusResponse> GetStatusAsync(CancellationToken ct = default);
}

public record ServiceStatusResponse
{
    public required string ServiceVersion { get; init; }
    public required DateTime ServiceUptime { get; init; }
    public required bool ShellHealthy { get; init; }
    public string? ShellVersion { get; init; }
    public required bool RtmHealthy { get; init; }
    public string? RtmVersion { get; init; }
    public required bool RedisHealthy { get; init; }
    public string? RedisInfo { get; init; }
    public required bool PostgresHealthy { get; init; }
}
