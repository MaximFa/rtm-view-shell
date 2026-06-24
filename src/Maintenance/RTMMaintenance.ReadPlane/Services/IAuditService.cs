namespace RTMMaintenance.ReadPlane.Services;

/// <summary>
/// Local structured audit (spec §8).
/// Logs who/what/params/result/time for every API call.
/// Output: C:\RTMView-Ops\output + Serilog.
/// </summary>
public interface IAuditService
{
    void LogApiCall(AuditEntry entry);
    Task LogApiCallAsync(AuditEntry entry, CancellationToken ct = default);
}

public record AuditEntry
{
    public required DateTime Timestamp { get; init; }
    public required string ClientIp { get; init; }
    public string? ClientCertThumbprint { get; init; }
    public required string Endpoint { get; init; }
    public required string Method { get; init; }
    public string? Parameters { get; init; }
    public required string Result { get; init; }
    public int StatusCode { get; init; }
    public TimeSpan Duration { get; init; }
}
