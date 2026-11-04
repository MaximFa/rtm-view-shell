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

    /// <summary>
    /// End-of-shift reports only: the shift hours in site wall clock, on the date picked on the page.
    /// The DATE is not stored here - operator, 2026-11-04: "from the screen, like the other reports".
    /// A date saved in a widget would be stale by the next morning and the dashboard would keep
    /// showing yesterday's shift until somebody opened the settings.
    /// The server contract (RunReportWidgetQueryHandler.ValidateShift): start 0-23, end 1-24,
    /// end strictly greater than start, no shift across midnight.
    /// </summary>
    [JsonPropertyName("shiftStartHour")]
    public int? ShiftStartHour { get; init; }

    /// <summary>End-of-shift reports only: see <see cref="ShiftStartHour"/>. 1-24, where 24 is midnight.</summary>
    [JsonPropertyName("shiftEndHour")]
    public int? ShiftEndHour { get; init; }

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
/// Report scope definition: business units only.
/// BU-to-queues resolution is server-side via NGC_BusinessUnitQueueClassification.
/// </summary>
public record ReportScope
{
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

    [JsonPropertyName("lightTableBackground")]
    public string? LightTableBackground { get; init; }

    [JsonPropertyName("darkTableBackground")]
    public string? DarkTableBackground { get; init; }
}
