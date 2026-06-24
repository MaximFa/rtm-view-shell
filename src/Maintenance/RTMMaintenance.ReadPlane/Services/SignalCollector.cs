using Microsoft.Extensions.Options;
using RTMMaintenance.ReadPlane.Contracts;
using RTMMaintenance.ReadPlane.Models;

namespace RTMMaintenance.ReadPlane.Services;

/// <summary>
/// Signal collector. TODO: implement actual collectors per SF-MS-001 privilege set.
/// </summary>
public class SignalCollector : ISignalCollector
{
    private readonly ISecretScrubber _scrubber;
    private readonly JobOptions _options;
    private readonly ILogger<SignalCollector> _logger;

    public SignalCollector(ISecretScrubber scrubber, IOptions<JobOptions> options, ILogger<SignalCollector> logger)
    {
        _scrubber = scrubber;
        _options = options.Value;
        _logger = logger;
    }

    public Task<CollectResult> CollectAsync(CollectIncidentRequest request, string outputPath, CancellationToken ct = default)
    {
        var bundleDir = Path.Combine(outputPath, $"incident_{DateTime.UtcNow:yyyyMMdd_HHmmss}");
        Directory.CreateDirectory(bundleDir);
        _logger.LogInformation("Collecting signals {Signals} to {BundleDir}", request.Signals, bundleDir);

        var results = new Dictionary<SignalType, SignalResult>();
        foreach (var signal in request.Signals)
            results[signal] = new SignalResult { Success = true, LineCount = 0 }; // TODO: implement

        return Task.FromResult(new CollectResult
        {
            Success = true,
            BundlePath = bundleDir,
            SignalResults = results
        });
    }
}
