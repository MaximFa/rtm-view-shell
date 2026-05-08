using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Contracts.DTOs.Audit;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.Audit;

public record GetDistinctAuditEventTypesQuery(Guid? TenantId = null) : IRequest<IReadOnlyList<string>>;

public class GetDistinctAuditEventTypesQueryHandler(
    IAuditLogRepository repo,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetDistinctAuditEventTypesQuery, IReadOnlyList<string>>
{
    public async Task<IReadOnlyList<string>> Handle(GetDistinctAuditEventTypesQuery q, CancellationToken ct)
    {
        Guid? tenantId;
        if (q.TenantId.HasValue)
            tenantId = q.TenantId;
        else if (currentUser.Role == "Superadmin")
            tenantId = null;
        else
            tenantId = currentUser.TenantId;

        return await repo.GetDistinctEventTypesAsync(tenantId, ct);
    }
}

public record GetAuditLogsQuery(
    string? EventType = null,
    string? Result = null,
    DateTime? From = null,
    DateTime? To = null,
    int Page = 1,
    int PageSize = 25,
    Guid? TenantId = null) : IRequest<PagedResult<AuditLogDto>>;

public class GetAuditLogsQueryHandler(
    IAuditLogRepository repo,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetAuditLogsQuery, PagedResult<AuditLogDto>>
{
    public async Task<PagedResult<AuditLogDto>> Handle(GetAuditLogsQuery q, CancellationToken ct)
    {
        Guid? tenantId;
        if (q.TenantId.HasValue)
            tenantId = q.TenantId;                  // Superadmin picked a specific tenant
        else if (currentUser.Role == "Superadmin")
            tenantId = null;                         // Superadmin "All tenants" — no filter
        else
            tenantId = currentUser.TenantId;         // Administrator sees only own tenant

        var (items, total) = await repo.GetPageAsync(
            tenantId, q.EventType, q.Result, q.From, q.To, q.Page, q.PageSize, ct);

        return new PagedResult<AuditLogDto>(items, total, q.Page, q.PageSize);
    }
}
