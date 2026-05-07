using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.Common;
using CcDashboard.Contracts.DTOs.Audit;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Queries.Audit;

public record GetAuditLogsQuery(
    string? EventType = null,
    string? Result = null,
    DateTime? From = null,
    DateTime? To = null,
    int Page = 1,
    int PageSize = 25) : IRequest<PagedResult<AuditLogDto>>;

public class GetAuditLogsQueryHandler(
    IAuditLogRepository repo,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<GetAuditLogsQuery, PagedResult<AuditLogDto>>
{
    public async Task<PagedResult<AuditLogDto>> Handle(GetAuditLogsQuery q, CancellationToken ct)
    {
        var tenantId = currentUser.TenantId;
        var (items, total) = await repo.GetPageAsync(
            tenantId, q.EventType, q.Result, q.From, q.To, q.Page, q.PageSize, ct);

        return new PagedResult<AuditLogDto>(items, total, q.Page, q.PageSize);
    }
}
