using CcDashboard.Contracts.DTOs.Configuration;

namespace CcDashboard.Application.Services.Metrics;

/// <summary>
/// Filter criteria for the metric wizard.
/// </summary>
public record MetricFilterCriteria(
    string? MetricType,      // "Agent" | "Data" | null (all)
    string? Category,        // Queue | AgentGroup | Agent | null (all)
    string? Family,          // e.g. "queue.pct.answered_threshold_inc" | null (all)
    string? Channel,         // calls | callbacks | chats | digital | null (all)
    int? ThresholdSec,       // 30 | 60 | 120 | 360 | null (all)
    string? Search           // free-text search | null
);

/// <summary>
/// Pure, UI-free filter logic for metric catalogue. Fully unit-testable.
/// </summary>
public static class MetricCatalogFilter
{
    private static readonly HashSet<string> ExcludedStatuses = new(StringComparer.OrdinalIgnoreCase)
    {
        "duplicate",
        "deprecated"
    };

    /// <summary>
    /// Returns the display label for a metric: DisplayName ?? Description ?? MetricId.
    /// </summary>
    public static string Label(RtsGridMetricDto m)
    {
        if (!string.IsNullOrWhiteSpace(m.DisplayName))
            return m.DisplayName;
        if (!string.IsNullOrWhiteSpace(m.Description))
            return m.Description;
        return m.MetricId;
    }

    /// <summary>
    /// Applies filter criteria to a metric list.
    /// Always excludes CatalogStatus in {"duplicate", "deprecated"}.
    /// </summary>
    public static IReadOnlyList<RtsGridMetricDto> Apply(
        IReadOnlyList<RtsGridMetricDto> all,
        MetricFilterCriteria c)
    {
        var result = all.AsEnumerable();

        // Always exclude duplicate/deprecated
        result = result.Where(m => !IsExcludedStatus(m.CatalogStatus));

        // MetricType pre-filter (Agent | Data)
        if (!string.IsNullOrEmpty(c.MetricType))
            result = result.Where(m => string.Equals(m.MetricType, c.MetricType, StringComparison.OrdinalIgnoreCase));

        // Category filter
        if (!string.IsNullOrEmpty(c.Category))
            result = result.Where(m => string.Equals(m.CatalogCategory, c.Category, StringComparison.OrdinalIgnoreCase));

        // Family filter
        if (!string.IsNullOrEmpty(c.Family))
            result = result.Where(m => string.Equals(m.Family, c.Family, StringComparison.OrdinalIgnoreCase));

        // Channel filter
        if (!string.IsNullOrEmpty(c.Channel))
            result = result.Where(m => string.Equals(m.Channel, c.Channel, StringComparison.OrdinalIgnoreCase));

        // ThresholdSec filter
        if (c.ThresholdSec.HasValue)
            result = result.Where(m => m.ThresholdSec == c.ThresholdSec.Value);

        // Search (case-insensitive over Label + ShortDescription + StandardKpi + Family)
        if (!string.IsNullOrWhiteSpace(c.Search))
        {
            var search = c.Search.Trim();
            result = result.Where(m => MatchesSearch(m, search));
        }

        return result.ToList();
    }

    /// <summary>
    /// Returns distinct families present in the given pool, sorted alphabetically.
    /// </summary>
    public static IReadOnlyList<string> Families(IReadOnlyList<RtsGridMetricDto> pool)
    {
        return pool
            .Select(m => m.Family)
            .Where(f => !string.IsNullOrEmpty(f))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(f => f, StringComparer.OrdinalIgnoreCase)
            .ToList()!;
    }

    /// <summary>
    /// Returns distinct channels present in the given pool (non-null only), sorted alphabetically.
    /// </summary>
    public static IReadOnlyList<string> Channels(IReadOnlyList<RtsGridMetricDto> pool)
    {
        return pool
            .Select(m => m.Channel)
            .Where(ch => !string.IsNullOrEmpty(ch))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(ch => ch, StringComparer.OrdinalIgnoreCase)
            .ToList()!;
    }

    /// <summary>
    /// Returns distinct threshold values present in the given pool (non-null only), sorted ascending.
    /// </summary>
    public static IReadOnlyList<int> Thresholds(IReadOnlyList<RtsGridMetricDto> pool)
    {
        return pool
            .Where(m => m.ThresholdSec.HasValue)
            .Select(m => m.ThresholdSec!.Value)
            .Distinct()
            .OrderBy(t => t)
            .ToList();
    }

    /// <summary>
    /// Returns true if the metric is a defect candidate (still selectable, but with warning).
    /// </summary>
    public static bool IsDefect(RtsGridMetricDto m)
        => string.Equals(m.CatalogStatus, "defect-candidate", StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Returns distinct categories present in the given pool, sorted alphabetically.
    /// </summary>
    public static IReadOnlyList<string> Categories(IReadOnlyList<RtsGridMetricDto> pool)
    {
        return pool
            .Select(m => m.CatalogCategory)
            .Where(cat => !string.IsNullOrEmpty(cat))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(cat => cat, StringComparer.OrdinalIgnoreCase)
            .ToList()!;
    }

    private static bool IsExcludedStatus(string? status)
        => !string.IsNullOrEmpty(status) && ExcludedStatuses.Contains(status);

    private static bool MatchesSearch(RtsGridMetricDto m, string search)
    {
        // Search over Label + ShortDescription + StandardKpi + Family
        if (Label(m).Contains(search, StringComparison.OrdinalIgnoreCase))
            return true;
        if (!string.IsNullOrEmpty(m.ShortDescription) && m.ShortDescription.Contains(search, StringComparison.OrdinalIgnoreCase))
            return true;
        if (!string.IsNullOrEmpty(m.StandardKpi) && m.StandardKpi.Contains(search, StringComparison.OrdinalIgnoreCase))
            return true;
        if (!string.IsNullOrEmpty(m.Family) && m.Family.Contains(search, StringComparison.OrdinalIgnoreCase))
            return true;
        return false;
    }
}
