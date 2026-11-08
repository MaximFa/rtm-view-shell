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
    /// AgentPerformance only: "summary" (one row per agent for the period) or "byDate" (one row per
    /// agent per local date). REQUIRED there - the server's validator refuses the widget without it
    /// ("Mode (summary|byDate) required"), so an unset mode is the same class of defect the shift
    /// hours were: a widget that can only draw a refusal.
    ///
    /// Held as a string, not as the server's enum: this record is serialised with a camelCase
    /// property policy and NO enum converter, so an enum here would go out as a number and the
    /// server would not recognise it. The two accepted values live in
    /// <see cref="AgentPerformanceModes"/> and are checked against the server enum by a guard.
    /// </summary>
    [JsonPropertyName("mode")]
    public string? Mode { get; init; }

    /// <summary>
    /// AgentPerformance only: agent external ids to show; null or empty = every agent in scope.
    /// The server narrows this to the user's scope and never widens it, dropping foreign ids
    /// silently - so the screen must never offer an agent outside the scope in the first place.
    /// </summary>
    [JsonPropertyName("agentIds")]
    public List<string>? AgentIds { get; init; }

    /// <summary>Queue Trend only (FEAT-REPORT-QUEUE-TREND-COMPARE-01): the picked queues; null/empty = every queue in scope.</summary>
    [JsonPropertyName("workgroups")]
    public List<string>? Workgroups { get; init; }

    /// <summary>Queue Trend only: the metrics the chart shows by default (editor); the viewer's own pick lives on the screen.</summary>
    [JsonPropertyName("defaultMetrics")]
    public List<string>? DefaultMetrics { get; init; }

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

    /// <summary>
    /// Queue Report and Agent Report: the step the widget opens with, set in the editor (operator
    /// 2026-11-07 13:25). A viewer's own choice overrides it; ReportWidgetSteps holds the order.
    /// Held as the camelCase NAME ("month"), for the same reason as <see cref="Mode"/>: this record
    /// has no enum converter, so an enum here would go out as a number. Null = Day.
    /// </summary>
    [JsonPropertyName("defaultStep")]
    public string? DefaultStep { get; init; }

    /// <summary>
    /// Agent Report only (FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01): the row mode the widget opens with - "summary" (one
    /// row per agent for the period) or "byStep". A viewer's own choice overrides it; ReportRowModes holds the order.
    /// The camelCase NAME, as DefaultStep. Null = summary.
    /// </summary>
    [JsonPropertyName("defaultRowMode")]
    public string? DefaultRowMode { get; init; }

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

/// <summary>
/// The two values the server accepts for AgentPerformance.Mode, as they travel in JSON.
///
/// They are camelCase names of AgentPerformanceMode (Application.HistoricalReports.Queries): the
/// server parses ConfigJson with a camelCase string-enum converter. Kept as constants so a typo
/// cannot reach the server as "an unknown mode", and pinned to the enum by an architecture guard -
/// if a third mode is added, the guard goes red rather than the dialog quietly offering two of three.
/// </summary>
public static class AgentPerformanceModes
{
    public const string Summary = "summary";
    public const string ByDate = "byDate";
}
