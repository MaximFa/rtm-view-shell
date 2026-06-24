using System.Text.Json;
using System.Text.Json.Serialization;

namespace CcDashboard.Web.Components.ReportWidgets;

/// <summary>
/// Configuration record for report widgets, matching bi LOCKED §2.
/// Parsed from ReportWidget.ConfigJson.
/// </summary>
public record ReportWidgetConfig
{
    [JsonPropertyName("title")]
    public string? Title { get; init; }

    [JsonPropertyName("scope")]
    public ReportScope? Scope { get; init; }

    [JsonPropertyName("columns")]
    public List<string>? Columns { get; init; }

    [JsonPropertyName("thresholds")]
    public Dictionary<string, object>? Thresholds { get; init; }

    [JsonPropertyName("interval")]
    public int? Interval { get; init; } // 30 or 60

    [JsonPropertyName("pageSize")]
    public int? PageSize { get; init; }

    [JsonPropertyName("metric")]
    public string? Metric { get; init; }

    [JsonPropertyName("appearance")]
    public AppearanceConfig? Appearance { get; init; }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public static ReportWidgetConfig? Parse(string? json)
    {
        if (string.IsNullOrWhiteSpace(json))
            return null;

        try
        {
            return JsonSerializer.Deserialize<ReportWidgetConfig>(json, JsonOptions);
        }
        catch
        {
            return null;
        }
    }

    public string ToJson()
    {
        return JsonSerializer.Serialize(this, JsonOptions);
    }
}

/// <summary>
/// Report scope definition: queues or business units.
/// </summary>
public record ReportScope
{
    [JsonPropertyName("mode")]
    public string? Mode { get; init; } // "queues" | "bu"

    [JsonPropertyName("queueIds")]
    public List<int>? QueueIds { get; init; }

    [JsonPropertyName("businessUnitIds")]
    public List<int>? BusinessUnitIds { get; init; }

    [JsonPropertyName("agentAxis")]
    public string? AgentAxis { get; init; } // "detail" | "cumulative"
}

/// <summary>
/// Appearance configuration for report widgets.
/// </summary>
public record AppearanceConfig
{
    [JsonPropertyName("tableFontSize")]
    public string? TableFontSize { get; init; }

    [JsonPropertyName("headerFontSize")]
    public string? HeaderFontSize { get; init; }

    [JsonPropertyName("lightBackground")]
    public string? LightBackground { get; init; }

    [JsonPropertyName("lightTextColor")]
    public string? LightTextColor { get; init; }

    [JsonPropertyName("darkBackground")]
    public string? DarkBackground { get; init; }

    [JsonPropertyName("darkTextColor")]
    public string? DarkTextColor { get; init; }
}
