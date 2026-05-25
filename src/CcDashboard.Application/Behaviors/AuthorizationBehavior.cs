using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Application.Behaviors;

/// <summary>
/// MediatR behavior that enforces authorization at the command/query level [CODE-03].
/// Commands/Queries can implement IRequiresPermission to declare required permissions.
/// </summary>
public class AuthorizationBehavior<TRequest, TResponse>(
    ICurrentUserAccessor currentUser,
    IPermissionService permissionService,
    ILogger<AuthorizationBehavior<TRequest, TResponse>> logger)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken ct)
    {
        // If request declares required permissions, enforce them
        if (request is IRequiresPermission permReq)
        {
            var userId = currentUser.UserId;
            var role = currentUser.Role;

            if (userId is null)
            {
                logger.LogWarning(
                    "Authorization failed: no authenticated user for {RequestType}",
                    typeof(TRequest).Name);
                throw new ForbiddenException("Authentication required.");
            }

            // Superadmin bypasses all permission checks
            if (role == "Superadmin")
                return await next();

            // Check if user's role is in allowed roles
            if (permReq.AllowedRoles.Length > 0 && !permReq.AllowedRoles.Contains(role))
            {
                logger.LogWarning(
                    "Authorization failed: user {UserId} with role {Role} attempted {RequestType} requiring roles [{AllowedRoles}]",
                    userId, role, typeof(TRequest).Name, string.Join(", ", permReq.AllowedRoles));
                throw new ForbiddenException($"This action requires one of the following roles: {string.Join(", ", permReq.AllowedRoles)}");
            }

            // Check specific permission key if declared [PG-04]
            if (!string.IsNullOrEmpty(permReq.RequiredPermission))
            {
                var tenantId = currentUser.TenantId
                    ?? throw new ForbiddenException("Tenant context required for permission check.");

                var hasPermission = await permissionService.HasPermissionAsync(
                    currentUser.PermissionGroupId, tenantId, permReq.RequiredPermission, ct);

                if (!hasPermission)
                {
                    logger.LogWarning(
                        "Authorization failed: user {UserId} in PG {PgId} lacks permission {Permission} for {RequestType}",
                        userId, currentUser.PermissionGroupId, permReq.RequiredPermission, typeof(TRequest).Name);
                    throw new ForbiddenException($"Permission denied: {permReq.RequiredPermission}");
                }

                logger.LogDebug(
                    "Permission check passed for {Permission} on {RequestType}",
                    permReq.RequiredPermission, typeof(TRequest).Name);
            }
        }

        // If request requires specific tenant context
        if (request is IRequiresTenantContext)
        {
            if (currentUser.TenantId is null)
            {
                logger.LogWarning(
                    "Authorization failed: no tenant context for {RequestType}",
                    typeof(TRequest).Name);
                throw new ForbiddenException("Tenant context required.");
            }
        }

        return await next();
    }
}

/// <summary>
/// Marker interface for requests that require specific permissions.
/// </summary>
public interface IRequiresPermission
{
    /// <summary>
    /// Roles allowed to execute this request. Empty = all authenticated users.
    /// Superadmin always bypasses this check.
    /// </summary>
    string[] AllowedRoles => [];

    /// <summary>
    /// Specific permission key required (e.g., "menu.users", "dashboard.edit").
    /// Empty = no specific permission required beyond role check.
    /// </summary>
    string? RequiredPermission => null;
}

/// <summary>
/// Marker interface for requests that require tenant context to be resolved.
/// </summary>
public interface IRequiresTenantContext;
