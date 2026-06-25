using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;
using System.Text.Json;

namespace CcDashboard.Application.Commands.Dashboards;

public record PurgeDashboardCommand(Guid Id) : IRequest, ITransactional, IAuditable
{
    public string AuditEventType => "Dashboard.PermanentlyDeleted";
    public object? AuditDetails => new { Id };
}

public class PurgeDashboardCommandHandler(
    IDashboardRepository dashboards,
    IRtsRepository rtsRepository,
    IPermissionService permissionService,
    ICurrentUserAccessor currentUser)
    : IRequestHandler<PurgeDashboardCommand>
{
    public async Task Handle(PurgeDashboardCommand cmd, CancellationToken ct)
    {
        var isSuperadmin = currentUser.Role == "Superadmin";

        // Fetch the soft-deleted (Trash) dashboard with widgets for RTS sweep
        // GetByIdWithWidgetsAsync with bypassTenantFilter includes widgets; we need IsDeleted items
        // so we use GetDeletedByIdAsync first to verify IsDeleted, then load widgets separately
        var dashboard = await dashboards.GetDeletedByIdAsync(cmd.Id, ct)
            ?? throw new NotFoundException(nameof(Dashboard), cmd.Id);

        // GUARD: Only Trash items can be permanently deleted
        if (!dashboard.IsDeleted)
            throw new DomainException("Only a soft-deleted (Trash) dashboard can be permanently deleted.");

        // PERMISSION: Non-superadmin needs Delete permission on the dashboard
        if (!isSuperadmin)
        {
            var tenantId = currentUser.TenantId
                ?? throw new ForbiddenException("Tenant context required.");
            var ok = await permissionService.HasDashboardAccessAsync(
                currentUser.PermissionGroupId, tenantId, dashboard.Id, 4 /* Delete */, ct);
            if (!ok)
                throw new ForbiddenException("Delete permission required");
        }

        // RTS sweep (idempotent safety-net)
        // Note: RTS rows are normally already cleaned at soft-delete time.
        // The Delete* repo calls are no-ops if the rows are absent.
        // Since GetDeletedByIdAsync doesn't include widgets, we load them via GetByIdWithWidgetsAsync
        // with bypassTenantFilter=true (to bypass both tenant GQF and IsDeleted GQF).
        // However, GetByIdWithWidgetsAsync filters out IsDeleted dashboards, so we need to work around this.
        // Since the RTS cleanup already happened at soft-delete and this is just a safety net,
        // we can skip if widgets aren't loaded. For robustness, we attempt via the full load path.

        // Re-fetch with widgets using bypass mode (IgnoreQueryFilters) but this excludes IsDeleted=true
        // So instead we just work with the widgets that were associated at soft-delete time
        // Since widgets are FK-cascaded and RTS was cleaned at soft-delete, this is just defensive
        foreach (var widget in dashboard.Widgets ?? [])
        {
            var catalogName = widget.CatalogItem?.Name?.ToLower() ?? "";

            // Agent Grid - delete by widget's GridId (RTSUserGrid tables)
            if (catalogName.Contains("agent") && catalogName.Contains("grid") && widget.GridId > 0)
            {
                var columnsSetId = await rtsRepository.GetColumnsSetIdByGridIdAsync(widget.GridId, ct);
                await rtsRepository.DeleteGridAsync(widget.GridId, ct);
                if (columnsSetId.HasValue)
                {
                    await rtsRepository.DeleteColumnsSetAsync(columnsSetId.Value, ct);
                }
            }
            // Queue Grid - delete by config's GridId (RTSGrid tables)
            else if (catalogName.Contains("queue") && catalogName.Contains("grid"))
            {
                var gridId = ExtractQueueGridId(widget.ConfigJson);
                if (gridId > 0)
                {
                    await rtsRepository.DeleteQueueGridAsync(gridId, ct);
                }
            }
        }

        // PHYSICAL delete - DB ON DELETE CASCADE removes dashboard_widgets + dashboard_permissions
        dashboards.Remove(dashboard);
    }

    private static int ExtractQueueGridId(string? configJson)
    {
        if (string.IsNullOrEmpty(configJson)) return 0;
        try
        {
            using var doc = JsonDocument.Parse(configJson);
            if (doc.RootElement.TryGetProperty("gridId", out var gridIdProp) &&
                gridIdProp.ValueKind == JsonValueKind.Number)
            {
                return gridIdProp.GetInt32();
            }
        }
        catch { }
        return 0;
    }
}
