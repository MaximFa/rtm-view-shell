using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using MediatR;

namespace CcDashboard.Application.Behaviors;

public class AuditBehavior<TRequest, TResponse>(
    IAuditService auditService,
    ICurrentUserAccessor currentUser)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : IAuditable
{
    public async Task<TResponse> Handle(TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken ct)
    {
        try
        {
            var response = await next();
            await auditService.LogAsync(
                request.AuditEventType,
                AuditEventResult.Success,
                currentUser.TenantId,
                currentUser.UserId,
                currentUser.UserName,
                details: request.AuditDetails,
                ct: ct);
            return response;
        }
        catch
        {
            await auditService.LogAsync(
                request.AuditEventType,
                AuditEventResult.Failure,
                currentUser.TenantId,
                currentUser.UserId,
                currentUser.UserName,
                details: request.AuditDetails,
                ct: ct);
            throw;
        }
    }
}

public interface IAuditable
{
    string AuditEventType { get; }
    object? AuditDetails => null;
}
