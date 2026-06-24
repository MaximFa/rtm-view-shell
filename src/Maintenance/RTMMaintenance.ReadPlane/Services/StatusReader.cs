using System.Reflection;

namespace RTMMaintenance.ReadPlane.Services;

public class StatusReader : IStatusReader
{
    private readonly ILogger<StatusReader> _logger;
    private readonly IConfiguration _configuration;
    private static readonly DateTime StartTime = DateTime.UtcNow;

    public StatusReader(ILogger<StatusReader> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    public async Task<ServiceStatusResponse> GetStatusAsync(CancellationToken ct = default)
    {
        var version = Assembly.GetExecutingAssembly().GetName().Version?.ToString() ?? "0.0.0";
        var shellHealth = await CheckShellHealthAsync(ct);

        return new ServiceStatusResponse
        {
            ServiceVersion = version,
            ServiceUptime = StartTime,
            ShellHealthy = shellHealth,
            ShellVersion = null,
            RtmHealthy = false,   // TODO: implement
            RtmVersion = null,
            RedisHealthy = false, // TODO: implement
            RedisInfo = null,
            PostgresHealthy = false // TODO: implement
        };
    }

    private async Task<bool> CheckShellHealthAsync(CancellationToken ct)
    {
        var url = _configuration.GetValue<string>("Services:ShellHealthUrl");
        if (string.IsNullOrEmpty(url)) return false;
        try
        {
            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
            var response = await http.GetAsync(url, ct);
            return response.IsSuccessStatusCode;
        }
        catch { return false; }
    }
}
