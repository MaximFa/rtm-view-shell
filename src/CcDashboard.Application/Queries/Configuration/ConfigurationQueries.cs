using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.Configuration;

// ── Sites ────────────────────────────────────────────────────────────────────

public record GetSitesQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<SiteDto>>;

public class GetSitesQueryHandler(ISiteRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<GetSitesQuery, IReadOnlyList<SiteDto>>
{
    public async Task<IReadOnlyList<SiteDto>> Handle(GetSitesQuery q, CancellationToken ct)
    {
        var tenantId = user.Role == "Superadmin" ? q.TenantId : (q.TenantId ?? user.TenantId!.Value);
        var items = await repo.GetAllByTenantAsync(tenantId, ct);
        return items.Select(s => new SiteDto(s.SiteId, s.SiteName, s.Description, s.TimeZone, s.ClearTime)).ToList();
    }
}

// ── Business Units ───────────────────────────────────────────────────────────

public record GetBusinessUnitsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<BusinessUnitDto>>;

public class GetBusinessUnitsQueryHandler(IBusinessUnitRepository repo, ICurrentUserAccessor user)
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

// ── Queues (read-only reference) ─────────────────────────────────────────────

public record GetQueuesQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<QueueDto>>;

public class GetQueuesQueryHandler(IQueueRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<GetQueuesQuery, IReadOnlyList<QueueDto>>
{
    public async Task<IReadOnlyList<QueueDto>> Handle(GetQueuesQuery q, CancellationToken ct)
    {
        var tenantId = user.Role == "Superadmin" ? q.TenantId : (q.TenantId ?? user.TenantId!.Value);
        var items = await repo.GetAllByTenantAsync(tenantId, ct);
        return items.Select(q => new QueueDto(q.QueueId, q.Name ?? q.QueueId)).ToList();
    }
}

// ── Supergroups ──────────────────────────────────────────────────────────────

public record GetSupergroupsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<SupergroupDto>>;

public class GetSupergroupsQueryHandler(ISupergroupRepository repo, ICurrentUserAccessor user)
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
            sg.AgentGroupAssignments.Select(a => a.AgentGroupId).ToList())).ToList();
    }
}

// ── Agent Groups (read-only reference) ──────────────────────────────────────

public record GetAgentGroupsQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<AgentGroupDto>>;

public class GetAgentGroupsQueryHandler(IAgentGroupRepository repo, ICurrentUserAccessor user)
    : IRequestHandler<GetAgentGroupsQuery, IReadOnlyList<AgentGroupDto>>
{
    public async Task<IReadOnlyList<AgentGroupDto>> Handle(GetAgentGroupsQuery q, CancellationToken ct)
    {
        var tenantId = user.Role == "Superadmin" ? q.TenantId : (q.TenantId ?? user.TenantId!.Value);
        var items = await repo.GetAllByTenantAsync(tenantId, ct);
        return items.Select(ag => new AgentGroupDto(ag.AgentGroupId, ag.Name ?? ag.AgentGroupId)).ToList();
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
