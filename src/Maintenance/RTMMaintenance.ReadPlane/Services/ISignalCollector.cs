using RTMMaintenance.ReadPlane.Contracts;

namespace RTMMaintenance.ReadPlane.Services;

public interface ISignalCollector
{
    Task<CollectResult> CollectAsync(CollectIncidentRequest request, string outputPath, CancellationToken ct = default);
}

public record CollectResult
{
    public required bool Success { get; init; }
    public required string BundlePath { get; init; }
    public string? Error { get; init; }
    public IReadOnlyDictionary<SignalType, SignalResult>? SignalResults { get; init; }
}

public record SignalResult
{
    public required bool Success { get; init; }
    public string? Error { get; init; }
    public int? LineCount { get; init; }
}
