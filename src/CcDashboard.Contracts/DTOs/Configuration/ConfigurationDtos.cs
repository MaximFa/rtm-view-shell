namespace CcDashboard.Contracts.DTOs.Configuration;

public record SiteDto(
    string SiteId,
    Guid TenantId,
    string? SiteName,
    string? Description,
    string? TimeZone,
    string? ClearTime);

public record BusinessUnitDto(
    int BusinessUnitId,
    Guid TenantId,
    string? BusinessUnitName,
    string? Description,
    string? SiteId,
    string? SiteName,
    IReadOnlyList<string> QueueIds,
    IReadOnlyList<int> SupergroupIds);

public record SupergroupDto(
    int SupergroupId,
    Guid TenantId,
    string? SupergroupName,
    string? Description,
    IReadOnlyList<string> AgentGroupIds);

public record QueueDto(string QueueId, string? Name);
public record AgentGroupDto(string AgentGroupId, string? Name);

public record RtsGridMetricDto(
    string MetricId,
    string? Description,
    string DataType,
    string MetricFunction,
    string MetricParameter,
    string? MetricFormat,
    string? DefaultValue,
    string ValueType,   // String, Time, Number
    string MetricType,  // Agent, Data
    string? DisplayName,
    string? ShortDescription,
    string? LongDescription,
    string? Comparison,
    string? StandardKpi,
    string? StandardRef,
    string? CatalogCategory,
    string? Family,
    string? Channel,
    int? ThresholdSec,
    string? CatalogStatus,
    string? CatalogNotes);

// ── Request records ──────────────────────────────────────────────────────────

public record SaveSiteRequest(
    string SiteId,
    string? SiteName,
    string? Description,
    string? TimeZone,
    string? ClearTime,
    bool IsNew);

public record SaveBusinessUnitRequest(
    int? BusinessUnitId,   // null = create
    string? BusinessUnitName,
    string? Description,
    string? SiteId,
    IReadOnlyList<string> QueueIds,
    IReadOnlyList<int> SupergroupIds);

public record SaveSupergroupRequest(
    int? SupergroupId,     // null = create
    string? SupergroupName,
    string? Description,
    IReadOnlyList<string> AgentGroupIds);

public record SaveRtsGridMetricRequest(
    string MetricId,
    string? Description,
    string DataType,
    string MetricFunction,
    string MetricParameter,
    string? MetricFormat,
    string? DefaultValue,
    string ValueType,   // String, Time, Number
    string MetricType,  // Agent, Data
    string? DisplayName,
    string? ShortDescription,
    string? LongDescription,
    string? Comparison,
    string? StandardKpi,
    string? StandardRef,
    string? CatalogCategory,
    string? Family,
    string? Channel,
    int? ThresholdSec,
    string? CatalogStatus,
    string? CatalogNotes,
    bool IsNew);
