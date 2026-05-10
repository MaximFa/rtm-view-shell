using CcDashboard.Application.Behaviors;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Dashboards;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using MediatR;
using UUIDNext;

namespace CcDashboard.Application.Commands.Dashboards;

// Create
public record CreateDashboardCategoryCommand(CreateDashboardCategoryRequest Request) : IRequest<DashboardCategoryDto>, ITransactional, IAuditable
{
    public string AuditEventType => "DashboardCategory.Created";
    public object? AuditDetails => new { Name = Request.Name };
}

public class CreateDashboardCategoryCommandHandler(
    IDashboardCategoryRepository categories,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<CreateDashboardCategoryCommand, DashboardCategoryDto>
{
    public async Task<DashboardCategoryDto> Handle(CreateDashboardCategoryCommand cmd, CancellationToken ct)
    {
        var now = clock.UtcNow;
        var userId = currentUser.UserId!.Value;
        var tenantId = currentUser.TenantId!.Value;

        if (await categories.ExistsWithNameAsync(tenantId, cmd.Request.Name, null, ct))
            throw new DomainException("Category with this name already exists.");

        var category = new DashboardCategory
        {
            Id = Uuid.NewSequential(),
            TenantId = tenantId,
            Name = cmd.Request.Name.Trim(),
            Description = cmd.Request.Description?.Trim(),
            CreatedByUserId = userId,
            UpdatedByUserId = userId,
            CreatedAt = now,
            UpdatedAt = now,
        };

        await categories.AddAsync(category, ct);

        return new DashboardCategoryDto(
            category.Id, category.TenantId, null, category.Name, category.Description,
            0, category.CreatedAt, category.UpdatedAt);
    }
}

// Update
public record UpdateDashboardCategoryCommand(UpdateDashboardCategoryRequest Request) : IRequest<DashboardCategoryDto>, ITransactional, IAuditable
{
    public string AuditEventType => "DashboardCategory.Updated";
    public object? AuditDetails => new { Id = Request.Id, Name = Request.Name };
}

public class UpdateDashboardCategoryCommandHandler(
    IDashboardCategoryRepository categories,
    ICurrentUserAccessor currentUser,
    IDateTimeProvider clock)
    : IRequestHandler<UpdateDashboardCategoryCommand, DashboardCategoryDto>
{
    public async Task<DashboardCategoryDto> Handle(UpdateDashboardCategoryCommand cmd, CancellationToken ct)
    {
        var category = await categories.GetByIdAsync(cmd.Request.Id, ct)
            ?? throw new NotFoundException(nameof(DashboardCategory), cmd.Request.Id);

        if (await categories.ExistsWithNameAsync(category.TenantId, cmd.Request.Name, category.Id, ct))
            throw new DomainException("Category with this name already exists.");

        category.Name = cmd.Request.Name.Trim();
        category.Description = cmd.Request.Description?.Trim();
        category.UpdatedAt = clock.UtcNow;
        category.UpdatedByUserId = currentUser.UserId!.Value;

        categories.Update(category);

        var dashboardCount = await categories.GetDashboardCountAsync(category.Id, ct);

        return new DashboardCategoryDto(
            category.Id, category.TenantId, null, category.Name, category.Description,
            dashboardCount, category.CreatedAt, category.UpdatedAt);
    }
}

// Delete
public record DeleteDashboardCategoryCommand(Guid Id) : IRequest, ITransactional, IAuditable
{
    public string AuditEventType => "DashboardCategory.Deleted";
    public object? AuditDetails => new { Id };
}

public class DeleteDashboardCategoryCommandHandler(
    IDashboardCategoryRepository categories)
    : IRequestHandler<DeleteDashboardCategoryCommand>
{
    public async Task Handle(DeleteDashboardCategoryCommand cmd, CancellationToken ct)
    {
        var category = await categories.GetByIdAsync(cmd.Id, ct)
            ?? throw new NotFoundException(nameof(DashboardCategory), cmd.Id);

        var dashboardCount = await categories.GetDashboardCountAsync(category.Id, ct);
        if (dashboardCount > 0)
            throw new DomainException($"Cannot delete category: {dashboardCount} dashboards are using it.");

        categories.Remove(category);
    }
}
