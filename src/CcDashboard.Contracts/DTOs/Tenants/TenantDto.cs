using CcDashboard.Domain.Enums;

namespace CcDashboard.Contracts.DTOs.Tenants;

public record TenantDto(
    Guid Id,
    string Slug,
    string Name,
    TenantStatus Status,
    DateTime CreatedAt,
    DateTime UpdatedAt);

public record CreateTenantRequest(string Slug, string Name);
