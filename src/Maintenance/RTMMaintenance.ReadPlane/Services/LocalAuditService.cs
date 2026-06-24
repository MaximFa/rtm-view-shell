using System.Text.Json;
using Microsoft.Extensions.Options;
using RTMMaintenance.ReadPlane.Models;

namespace RTMMaintenance.ReadPlane.Services;

public class LocalAuditService : IAuditService
{
    private readonly string _ledgerPath;
    private readonly ILogger<LocalAuditService> _logger;
    private readonly object _writeLock = new();

    public LocalAuditService(IOptions<JobOptions> options, ILogger<LocalAuditService> logger)
    {
        _ledgerPath = Path.Combine(options.Value.OutputDirectory, "_ledger.txt");
        _logger = logger;

        var dir = Path.GetDirectoryName(_ledgerPath);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            Directory.CreateDirectory(dir);
    }

    public void LogApiCall(AuditEntry entry)
    {
        var line = JsonSerializer.Serialize(entry, new JsonSerializerOptions { WriteIndented = false });
        lock (_writeLock)
        {
            try { File.AppendAllText(_ledgerPath, line + Environment.NewLine); }
            catch (Exception ex) { _logger.LogError(ex, "Failed to write audit entry"); }
        }
        _logger.LogInformation("API: {Method} {Endpoint} -> {StatusCode}", entry.Method, entry.Endpoint, entry.StatusCode);
    }

    public async Task LogApiCallAsync(AuditEntry entry, CancellationToken ct = default)
    {
        var line = JsonSerializer.Serialize(entry, new JsonSerializerOptions { WriteIndented = false });
        try { await File.AppendAllTextAsync(_ledgerPath, line + Environment.NewLine, ct); }
        catch (Exception ex) { _logger.LogError(ex, "Failed to write audit entry"); }
    }
}
