namespace CcDashboard.Application.Interfaces;

/// <summary>
/// Read-only catalogue of RTSGrid metric value types for widgets (PR234-V4-ALL-COLUMNS-TEXT-AFTER-EFFCD27-01).
/// Safe for any number of concurrent calls from one or many Blazor circuits: it never shares a DbContext
/// with the caller. A successful read may be cached for the process lifetime (the catalogue does not change
/// while screens run). A failed read THROWS - it never returns an empty dictionary, because empty is
/// indistinguishable from "no metrics".
/// </summary>
public interface IMetricCatalogue
{
    /// <summary>
    /// MetricId (case-insensitive) -> raw ValueType exactly as stored in RTSGrid_Metric
    /// (widgets normalise it via MetricValueType.Normalize).
    /// </summary>
    Task<IReadOnlyDictionary<string, string>> GetValueTypesAsync(CancellationToken ct);
}
