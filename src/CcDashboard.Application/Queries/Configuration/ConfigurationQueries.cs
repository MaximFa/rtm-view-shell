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
        var tenantId = user.Role == "Superadmin" ? q.TenantId : (q.TenantId ?? user.TenantId!.Value);
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
