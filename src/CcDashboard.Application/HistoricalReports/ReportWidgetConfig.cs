using System.Text.Json;
using System.Text.Json.Serialization;
using CcDashboard.Application.HistoricalReports.Queries;
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

    /// <summary>Columns to display. OPTIONAL in v1 — if null/empty, server uses DefaultColumns per WidgetType.</summary>
    public IReadOnlyList<string>? Columns { get; init; }

    /// <summary>Threshold configuration (opaque, passed through).</summary>
    public JsonElement? Thresholds { get; init; }

    /// <summary>Interval granularity (30|60) — QueueInterval only.</summary>
    public int? Interval { get; init; }

    /// <summary>Page size for pagination (25|50|100), default 25.</summary>
    public int PageSize { get; init; } = 25;

    /// <summary>Metric key for Distribution widget.</summary>
    public string? Metric { get; init; }

    /// <summary>AgentPerformance only: Summary (one row per agent) or ByDate (one row per agent per local date). Required there.</summary>
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public AgentPerformanceMode? Mode { get; init; }

    /// <summary>
    /// AgentPerformance only: agent external ids to show. Narrows the scope, never widens it: ids outside the user's
    /// PG/BU scope are dropped (SF-BI-002). Null/empty = every agent in scope.
    /// </summary>
    public IReadOnlyList<string>? AgentIds { get; init; }

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

    /// <summary>
    /// Get the effective columns: config.Columns if non-empty, else DefaultColumns for the widget type.
    /// v1: Columns picker is stub-disabled; server provides standard set when config has no columns.
    /// </summary>
    public IReadOnlyList<string> GetEffectiveColumns(ReportWidgetType widgetType)
    {
        if (Columns is { Count: > 0 })
            return Columns;
        return DefaultColumns(widgetType);
    }

    /// <summary>
    /// Default/standard columns per widget type — derived from row DTO fields.
    /// Used when ConfigJson.Columns is null/empty (v1 behavior).
    /// </summary>
    public static IReadOnlyList<string> DefaultColumns(ReportWidgetType widgetType) => widgetType switch
    {
        ReportWidgetType.QueueInterval => new[]
        {
            "IntervalStart", "Offered", "Answered", "Abandoned",
            "AnsweredInSl", "AbandonPct", "SlPct", "Asa", "QueueAht"
        },
        ReportWidgetType.QueueWaitTime => new[]
        {
            "IntervalStart", "Answered", "Asa", "AnsweredInSl", "SlPct"
        },
        ReportWidgetType.AgentMonthly => new[]
        {
            "YearMonth", "AgentExternalId", "AgentDisplayName", "SumAvailableMs", "SumOnphoneMs",
            "Handled", "OccupancyPct", "AgentAht"
        },
        ReportWidgetType.AgentShiftDetail => new[]
        {
            "IntervalStart", "AgentExternalId", "AgentDisplayName", "SumAvailableMs", "SumOnphoneMs",
            "Handled", "OccupancyPct", "AgentAht", "TalkPureMs"
        },
        ReportWidgetType.Distribution => new[]
        {
            "Label", "Count", "Percentage"
        },
        ReportWidgetType.EndOfShiftAgents or ReportWidgetType.AgentPerformance => new[]
        {
            "AgentExternalId", "AgentDisplayName", "SumLoggedInMs", "SumAvailableMs", "SumOnphoneMs",
            "Handled", "OccupancyPct", "AgentAht"
        },
        ReportWidgetType.EndOfShiftQueues => new[]
        {
            "Workgroup", "Offered", "Answered", "Abandoned", "AbandonPct", "SlPct", "Asa", "QueueAht"
        },
        _ => Array.Empty<string>()
    };

    /// <summary>
    /// FEAT-REPORT-*: the columns a user may pick for a widget type = the public fields of its row (column picker source).
    /// Null for types without a row record (Distribution).
    /// </summary>
    public static IReadOnlyList<string>? AllowedColumns(ReportWidgetType widgetType)
    {
        var rowType = widgetType switch
        {
            ReportWidgetType.QueueInterval => typeof(QueueIntervalRow),
            ReportWidgetType.QueueWaitTime => typeof(QueueWaitTimeRow),
            ReportWidgetType.AgentMonthly => typeof(AgentMonthlyRow),
            ReportWidgetType.AgentShiftDetail => typeof(AgentShiftDetailRow),
            ReportWidgetType.EndOfShiftAgents or ReportWidgetType.AgentPerformance => typeof(AgentSummaryRow),
            ReportWidgetType.EndOfShiftQueues => typeof(QueueSummaryRow),
            _ => null
        };
        return rowType?.GetProperties().Select(p => p.Name).ToArray();
    }
}

/// <summary>Scope configuration: BU-only (operator decision 2026-06-26).</summary>
public record ReportWidgetScope
{
    /// <summary>Business Unit IDs (NGC_BusinessUnit.BusinessUnitId int) — REQUIRED (scope is BU-only).</summary>
    public IReadOnlyList<int>? BusinessUnitIds { get; init; }

    /// <summary>Agent axis ("detail"|"cumulative") — required for agent widget types.</summary>
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public AgentReportAxis? AgentAxis { get; init; }
}
