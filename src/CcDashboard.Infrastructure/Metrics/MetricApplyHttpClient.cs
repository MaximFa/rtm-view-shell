using System.Net.Http.Json;
using System.Text.Json;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Metrics;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CcDashboard.Infrastructure.Metrics;

/// <summary>
/// Configuration options for the metrics apply-endpoint (contract §3/§5).
/// Bind from appsettings.json section "MetricsApply".
/// </summary>
public sealed class MetricsApplyOptions
{
    public const string Section = "MetricsApply";
    
    /// <summary>Base URL of the apply-service (e.g. http://127.0.0.1:5050). PENDING: devops port decision.</summary>
    public string BaseUrl { get; set; } = "http://127.0.0.1:5050";
    
    /// <summary>Service token for Authorization header (CODE-05: from config, not source).</summary>
    public string Token { get; set; } = "";
}

/// <summary>
/// Typed HttpClient to the devops apply-endpoint (contract §5/§6).
/// POST /apply-metrics with Authorization: Bearer {token}.
/// On non-200 / transport error -> returns ApplyMetricsResponse{ Success=false, Error=... } (never throws to UI raw).
/// </summary>
public sealed class MetricApplyHttpClient : IMetricApplyClient
{
    private readonly HttpClient _http;
    private readonly IOptionsMonitor<MetricsApplyOptions> _options;
    private readonly ILogger<MetricApplyHttpClient> _logger;
    
    private static readonly JsonSerializerOptions _jsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true
    };

    public MetricApplyHttpClient(
        HttpClient http,
        IOptionsMonitor<MetricsApplyOptions> options,
        ILogger<MetricApplyHttpClient> logger)
    {
        _http = http;
        _options = options;
        _logger = logger;
    }

    public async Task<ApplyMetricsResponse> ApplyAsync(ApplyMetricsRequest request, CancellationToken ct = default)
    {
        var opts = _options.CurrentValue;
        var url = opts.BaseUrl.TrimEnd('/') + "/apply-metrics";
        
        if (string.IsNullOrWhiteSpace(opts.Token))
        {
            _logger.LogError("MetricApplyHttpClient: service token not configured (MetricsApply:Token). Cannot call apply-endpoint.");
            return new ApplyMetricsResponse 
            { 
                Success = false, 
                Error = "Apply-service token not configured. Contact administrator." 
            };
        }

        try
        {
            using var httpReq = new HttpRequestMessage(HttpMethod.Post, url);
            httpReq.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", opts.Token);
            httpReq.Content = JsonContent.Create(request, options: _jsonOpts);

            _logger.LogInformation(
                "MetricApplyHttpClient: calling apply-endpoint for {Count} metrics, triggeredBy={UserId}",
                request.MetricIds.Count, request.TriggeredBy);

            using var response = await _http.SendAsync(httpReq, ct);
            
            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(ct);
                _logger.LogWarning(
                    "MetricApplyHttpClient: apply-endpoint returned {StatusCode}: {Body}",
                    (int)response.StatusCode, body);
                return new ApplyMetricsResponse 
                { 
                    Success = false, 
                    Error = $"Apply-endpoint returned {(int)response.StatusCode}: {body}" 
                };
            }

            var result = await response.Content.ReadFromJsonAsync<ApplyMetricsResponse>(_jsonOpts, ct);
            return result ?? new ApplyMetricsResponse { Success = false, Error = "Empty response from apply-endpoint" };
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "MetricApplyHttpClient: transport error calling apply-endpoint");
            return new ApplyMetricsResponse 
            { 
                Success = false, 
                Error = $"Cannot reach apply-endpoint: {ex.Message}" 
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "MetricApplyHttpClient: unexpected error calling apply-endpoint");
            return new ApplyMetricsResponse 
            { 
                Success = false, 
                Error = $"Unexpected error: {ex.Message}" 
            };
        }
    }
}
