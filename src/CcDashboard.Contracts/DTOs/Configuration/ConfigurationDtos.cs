namespace CcDashboard.Contracts.DTOs.Configuration;

public record SiteDto(
    string SiteId,
    string? SiteName,
    string? Description,
    string? TimeZone,
    string? ClearTime);

public record BusinessUnitDto(
    int BusinessUnitId,
    string? BusinessUnitName,
    string? Description,
    string? SiteId,
    string? SiteName,
    IReadOnlyList<string> QueueIds,
    IReadOnlyList<int> SupergroupIds);

public record SupergroupDto(
    int SupergroupId,
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
    string? DefaultValue);

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
    bool IsNew);
