using CcDashboard.Application.Behaviors;
using CcDashboard.Application.HistoricalReports;
using CcDashboard.Application.HistoricalReports.Validators;
using CcDashboard.Application.Reports.DTOs;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Domain.Exceptions;
using MediatR;
using UUIDNext;

namespace CcDashboard.Application.Reports.Commands;

public record SaveReportWidgetsCommand(
    Guid ReportScreenId,
    IReadOnlyList<SaveReportWidgetRequest> Widgets
) : IRequest<IReadOnlyList<ReportWidgetDto>>, ITransactional, IAuditable
{
    public string AuditEventType => "ReportScreen.WidgetsSaved";
    public object? AuditDetails => new { ReportScreenId, WidgetCount = Widgets.Count };
}

public class SaveReportWidgetsCommandHandler(
    IReportScreenRepository repo,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<SaveReportWidgetsCommand, IReadOnlyList<ReportWidgetDto>>
{
    public async Task<IReadOnlyList<ReportWidgetDto>> Handle(SaveReportWidgetsCommand cmd, CancellationToken ct)
    {
        var screen = await repo.GetByIdWithWidgetsAsync(cmd.ReportScreenId, ct)
            ?? throw new NotFoundException(nameof(ReportScreen), cmd.ReportScreenId);

        // Check Edit permission
        var isSuperadmin = currentUser.Role == "Superadmin";
        if (!isSuperadmin)
        {
            var accessLevel = await repo.GetUserAccessLevelAsync(
                screen.Id, currentUser.PermissionGroupId, screen.IsPublic, isSuperadmin, ct);
            if ((accessLevel & 2) == 0) // Edit = 2
                throw new ForbiddenException("Edit permission required");
        }

        var tenantId = screen.TenantId;
        var existingWidgets = screen.Widgets.ToDictionary(w => w.Id);
        var processedIds = new HashSet<Guid>();
        var result = new List<ReportWidgetDto>();

        foreach (var widgetReq in cmd.Widgets)
        {
            // Validate ConfigJson using Ф2.5 validator
            if (!string.IsNullOrEmpty(widgetReq.ConfigJson))
            {
                try
                {
                    var config = ReportWidgetConfig.Parse(widgetReq.ConfigJson);
                    var validator = new ReportWidgetConfigWithTypeValidator();
                    var validationResult = await validator.ValidateAsync((config, widgetReq.WidgetType), ct);
                    if (!validationResult.IsValid)
                    {
                        var errors = string.Join("; ", validationResult.Errors.Select(e => e.ErrorMessage));
                        throw new ValidationException($"Widget ConfigJson invalid: {errors}");
                    }
                }
                catch (System.Text.Json.JsonException ex)
                {
                    throw new ValidationException($"Widget ConfigJson parse error: {ex.Message}");
                }
            }

            if (widgetReq.Id.HasValue && existingWidgets.TryGetValue(widgetReq.Id.Value, out var existing))
            {
                // Update existing widget
                processedIds.Add(existing.Id);
                if (widgetReq.IsDeleted)
                {
                    existing.IsDeleted = true;
                }
                else
                {
                    existing.WidgetType = widgetReq.WidgetType;
                    existing.PositionJson = widgetReq.PositionJson;
                    existing.ConfigJson = widgetReq.ConfigJson;
                    existing.IsDeleted = false;
                    result.Add(new ReportWidgetDto(existing.Id, existing.WidgetType, existing.PositionJson, existing.ConfigJson));
                }
                repo.UpdateWidget(existing);
            }
            else if (!widgetReq.IsDeleted)
            {
                // Create new widget
                var newWidget = new ReportWidget
                {
                    Id = Uuid.NewSequential(),
                    ReportScreenId = screen.Id,
                    TenantId = tenantId,
                    WidgetType = widgetReq.WidgetType,
                    PositionJson = widgetReq.PositionJson,
                    ConfigJson = widgetReq.ConfigJson,
                    IsDeleted = false
                };
                await repo.AddWidgetAsync(newWidget, ct);
                processedIds.Add(newWidget.Id);
                result.Add(new ReportWidgetDto(newWidget.Id, newWidget.WidgetType, newWidget.PositionJson, newWidget.ConfigJson));
            }
        }

        // Soft-delete widgets not in the request
        foreach (var (id, widget) in existingWidgets)
        {
            if (!processedIds.Contains(id) && !widget.IsDeleted)
            {
                widget.IsDeleted = true;
                repo.UpdateWidget(widget);
            }
        }

        // Update screen timestamp
        screen.UpdatedAt = clock.UtcNow;
        screen.UpdatedByUserId = currentUser.UserId!.Value;
        repo.Update(screen);

        return result;
    }
}
