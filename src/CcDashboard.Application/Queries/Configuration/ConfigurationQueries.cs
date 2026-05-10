using System.Text.Json;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.Configuration;

// ── NGC Sites ────────────────────────────────────────────────────────────────

public record GetSitesQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<SiteDto>>;

public class GetSitesQueryHandler(INgcSiteRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<GetSitesQuery, IReadOnlyList<SiteDto>>
{
    public async Task<IReadOnlyList<SiteDto>> Handle(GetSitesQuery q, CancellationToken ct)
    {
        var tenantId = user.Role == "Superadmin" ? q.TenantId : (q.TenantId ?? user.TenantId!.Value);
        var items = await repo.GetAllByTenantAsync(tenantId, ct);
        return items.Select(s => new SiteDto(s.SiteId, s.SiteName, s.Description, s.TimeZone, s.ClearTime)).ToList();
    }
}

// ── NGC Business Units ───────────────────────────────────────────────────────

public record GetBusinessUnitsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<BusinessUnitDto>>;

public class GetBusinessUnitsQueryHandler(INgcBusinessUnitRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<GetBusinessUnitsQuery, IReadOnlyList<BusinessUnitDto>>
{
    public async Task<IReadOnlyList<BusinessUnitDto>> Handle(GetBusinessUnitsQuery q, CancellationToken ct)
    {
        // Always use provided TenantId; fall back to user's tenant only if not provided
        Guid? tenantId = q.TenantId.HasValue ? q.TenantId.Value : user.TenantId;
        var items = await repo.GetAllByTenantAsync(tenantId, ct);
        return items.Select(bu => new BusinessUnitDto(
            bu.BusinessUnitId,
            bu.BusinessUnitName,
            bu.Description,
            bu.SiteId,
            bu.Site?.SiteName,
            bu.QueueAssignments.Select(q => q.QueueId).ToList(),
            bu.SupergroupAssignments.Select(s => s.SupergroupId).ToList())).ToList();
    }
}

// ── NGC Business Units for Current User's Permission Group ──────────────────

public record GetMyBusinessUnitsQuery : IRequest<IReadOnlyList<BusinessUnitDto>>;

public class GetMyBusinessUnitsQueryHandler(
    INgcBusinessUnitRepository repo,
    IPermissionGroupRepository pgRepo,
    ICurrentUserAccessor user)
    : IRequestHandler<GetMyBusinessUnitsQuery, IReadOnlyList<BusinessUnitDto>>
{
    public async Task<IReadOnlyList<BusinessUnitDto>> Handle(GetMyBusinessUnitsQuery _, CancellationToken ct)
    {
        // Superadmin/Admin see all business units
        if (user.Role is "Superadmin" or "Administrator")
        {
            var allItems = await repo.GetAllByTenantAsync(user.TenantId, ct);
            return allItems.Select(bu => new BusinessUnitDto(
                bu.BusinessUnitId,
                bu.BusinessUnitName,
                bu.Description,
                bu.SiteId,
                bu.Site?.SiteName,
                bu.QueueAssignments.Select(q => q.QueueId).ToList(),
                bu.SupergroupAssignments.Select(s => s.SupergroupId).ToList())).ToList();
        }

        // Get user's permission group with allowed business units
        if (user.PermissionGroupId is null)
            return [];

        var pg = await pgRepo.GetByIdAsync(user.PermissionGroupId.Value, ct);
        if (pg is null)
            return [];

        var allowedBuIds = pg.AllowedBusinessUnits.Select(b => b.BusinessUnitId).ToHashSet();
        if (allowedBuIds.Count == 0)
            return [];

        var items = await repo.GetAllByTenantAsync(user.TenantId, ct);
        return items
            .Where(bu => allowedBuIds.Contains(bu.BusinessUnitId))
            .Select(bu => new BusinessUnitDto(
                bu.BusinessUnitId,
                bu.BusinessUnitName,
                bu.Description,
                bu.SiteId,
                bu.Site?.SiteName,
                bu.QueueAssignments.Select(q => q.QueueId).ToList(),
                bu.SupergroupAssignments.Select(s => s.SupergroupId).ToList()))
            .ToList();
    }
}

// ── NGC Supergroups ──────────────────────────────────────────────────────────

public record GetSupergroupsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<SupergroupDto>>;

public class GetSupergroupsQueryHandler(INgcSupergroupRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<GetSupergroupsQuery, IReadOnlyList<SupergroupDto>>
{
    public async Task<IReadOnlyList<SupergroupDto>> Handle(GetSupergroupsQuery q, CancellationToken ct)
    {
        var tenantId = user.Role == "Superadmin" ? q.TenantId : (q.TenantId ?? user.TenantId!.Value);
        var items = await repo.GetAllByTenantAsync(tenantId, ct);
        return items.Select(sg => new SupergroupDto(
            sg.SupergroupId,
            sg.SupergroupName,
            sg.Description,
            sg.AgentGroupAssignments.Select(a => a.AgentgroupId ?? "").Where(id => !string.IsNullOrEmpty(id)).ToList())).ToList();
    }
}

// ── Metrics ──────────────────────────────────────────────────────────────────

public record GetRtsGridMetricsQuery : IRequest<IReadOnlyList<RtsGridMetricDto>>;

public class GetRtsGridMetricsQueryHandler(IRtsGridMetricRepository repo)
    : IRequestHandler<GetRtsGridMetricsQuery, IReadOnlyList<RtsGridMetricDto>>
{
    public async Task<IReadOnlyList<RtsGridMetricDto>> Handle(GetRtsGridMetricsQuery _, CancellationToken ct)
    {
        var items = await repo.GetAllAsync(ct);
        return items.Select(m => new RtsGridMetricDto(m.MetricId, m.Description, m.DataType,
            m.MetricFunction, m.MetricParameter, m.MetricFormat, m.DefaultValue)).ToList();
    }
}

// ── Queues (ngc_queues reference table) ──────────────────────────────────────

public record GetQueuesQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<QueueDto>>;

public class GetQueuesQueryHandler(INgcQueueRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<GetQueuesQuery, IReadOnlyList<QueueDto>>
{
    public async Task<IReadOnlyList<QueueDto>> Handle(GetQueuesQuery q, CancellationToken ct)
    {
        var tenantId = user.Role == "Superadmin" ? q.TenantId : (q.TenantId ?? user.TenantId!.Value);
        var items = await repo.GetAllByTenantAsync(tenantId, ct);
        return items.Select(x => new QueueDto(x.ExternalId, x.Name)).ToList();
    }
}

// ── Agent Groups (ngc_AgentGroups reference table) ───────────────────────────

public record GetAgentGroupsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<AgentGroupDto>>;

public class GetAgentGroupsQueryHandler(INgcAgentGroupRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<GetAgentGroupsQuery, IReadOnlyList<AgentGroupDto>>
{
    public async Task<IReadOnlyList<AgentGroupDto>> Handle(GetAgentGroupsQuery q, CancellationToken ct)
    {
        var tenantId = user.Role == "Superadmin" ? q.TenantId : (q.TenantId ?? user.TenantId!.Value);
        var items = await repo.GetAllByTenantAsync(tenantId, ct);
        return items.Select(x => new AgentGroupDto(x.ExternalId, x.Name)).ToList();
    }
}

// ── Usage checks for deletion ────────────────────────────────────────────────

public record GetWidgetsUsingBusinessUnitQuery(int BusinessUnitId) : IRequest<List<string>>;

public class GetWidgetsUsingBusinessUnitQueryHandler(IDashboardRepository dashboards, ICurrentUserAccessor user)
    : IRequestHandler<GetWidgetsUsingBusinessUnitQuery, List<string>>
{
    public async Task<List<string>> Handle(GetWidgetsUsingBusinessUnitQuery q, CancellationToken ct)
    {
        var buIdStr = q.BusinessUnitId.ToString();
        var (items, _) = await dashboards.GetPageAsync(
            tenantId: null, search: null, status: null, categoryId: null, createdBy: null, isPublic: null,
            userId: user.UserId!.Value, pgId: user.PermissionGroupId,
            isSuperadmin: user.Role == "Superadmin", isSuperadminOrAdmin: user.Role is "Superadmin" or "Administrator",
            page: 1, pageSize: 1000, ct);

        var result = new List<string>();
        foreach (var d in items)
        {
            foreach (var w in d.Widgets)
            {
                if (!string.IsNullOrEmpty(w.ConfigJson) && w.ConfigJson.Contains($"\"{buIdStr}\""))
                {
                    var widgetName = ExtractWidgetName(w.ConfigJson);
                    var catalogName = w.CatalogItem?.Name ?? "Widget";
                    var displayName = string.IsNullOrEmpty(widgetName)
                        ? catalogName
                        : $"{widgetName} ({catalogName})";
                    result.Add($"{d.Name} → {displayName}");
                }
            }
        }
        return result;
    }

    private static string? ExtractWidgetName(string? configJson)
    {
        if (string.IsNullOrEmpty(configJson)) return null;
        try
        {
            using var doc = JsonDocument.Parse(configJson);
            if (doc.RootElement.TryGetProperty("DisplayName", out var nameProp))
                return nameProp.GetString();
        }
        catch { }
        return null;
    }
}

public record GetBusinessUnitsUsingSiteQuery(string SiteId) : IRequest<List<string>>;

public class GetBusinessUnitsUsingSiteQueryHandler(INgcBusinessUnitRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<GetBusinessUnitsUsingSiteQuery, List<string>>
{
    public async Task<List<string>> Handle(GetBusinessUnitsUsingSiteQuery q, CancellationToken ct)
    {
        var tenantId = user.Role == "Superadmin" ? null : user.TenantId;
        var items = await repo.GetAllByTenantAsync(tenantId, ct);
        return items
            .Where(bu => bu.SiteId == q.SiteId)
            .Select(bu => bu.BusinessUnitName ?? bu.BusinessUnitId.ToString())
            .ToList();
    }
}

public record GetBusinessUnitsUsingSupergroupQuery(int SupergroupId) : IRequest<List<string>>;

public class GetBusinessUnitsUsingSupergroupQueryHandler(INgcBusinessUnitRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<GetBusinessUnitsUsingSupergroupQuery, List<string>>
{
    public async Task<List<string>> Handle(GetBusinessUnitsUsingSupergroupQuery q, CancellationToken ct)
    {
        var tenantId = user.Role == "Superadmin" ? null : user.TenantId;
        var items = await repo.GetAllByTenantAsync(tenantId, ct);
        return items
            .Where(bu => bu.SupergroupAssignments.Any(s => s.SupergroupId == q.SupergroupId))
            .Select(bu => bu.BusinessUnitName ?? bu.BusinessUnitId.ToString())
            .ToList();
    }
}
