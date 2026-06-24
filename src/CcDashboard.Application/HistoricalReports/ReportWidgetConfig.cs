using System.Text.Json;
using System.Text.Json.Serialization;
using CcDashboard.Domain.Domain.Reports;

namespace CcDashboard.Application.HistoricalReports;

/// <summary>
/// ConfigJson parse result for report widgets.
/// §2 LOCKED: Mode/Scope/Columns structure per Reports-Backend-v1-Spec.
/// </summary>
public record ReportWidgetConfig
{
    /// <summary>Widget display title (opaque, not validated beyond length).</summary>
    public string? Title { get; init; }

    /// <summary>Scope configuration: mode + filter IDs.</summary>
    public required ReportWidgetScope Scope { get; init; }

    /// <summary>Columns to display (non-empty required).</summary>
    public required IReadOnlyList<string> Columns { get; init; }

    /// <summary>Threshold configuration (opaque, passed through).</summary>
    public JsonElement? Thresholds { get; init; }

    /// <summary>Interval granularity (30|60) — QueueInterval only.</summary>
    public int? Interval { get; init; }

    /// <summary>Page size for pagination (25|50|100), default 25.</summary>
    public int PageSize { get; init; } = 25;

    /// <summary>Metric key for Distribution widget.</summary>
    public string? Metric { get; init; }

    /// <summary>Appearance settings (opaque, IGNORED server-side).</summary>
    public JsonElement? Appearance { get; init; }

    /// <summary>
    /// Parse ConfigJson string to ReportWidgetConfig.
    /// Throws JsonException on malformed JSON.
    /// </summary>
    public static ReportWidgetConfig Parse(string configJson)
    {
        var options = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) }
        };
        return JsonSerializer.Deserialize<ReportWidgetConfig>(configJson, options)
               ?? throw new JsonException("ConfigJson deserialized to null");
    }
}

/// <summary>Scope configuration: mode determines which filter IDs are used.</summary>
public record ReportWidgetScope
{
    /// <summary>"queues" or "bu" — determines filter interpretation.</summary>
    public required string Mode { get; init; }

    /// <summary>Queue IDs (Shell's NgcQueue.Id uuid) when Mode="queues".</summary>
    public IReadOnlyList<Guid>? QueueIds { get; init; }

    /// <summary>Business Unit IDs (NGC_BusinessUnit.BusinessUnitId int) when Mode="bu".</summary>
    public IReadOnlyList<int>? BusinessUnitIds { get; init; }

    /// <summary>Agent axis ("detail"|"cumulative") — required for agent widget types when Mode="bu".</summary>
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public AgentReportAxis? AgentAxis { get; init; }
}
