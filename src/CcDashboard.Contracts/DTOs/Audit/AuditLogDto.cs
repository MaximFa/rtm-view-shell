namespace CcDashboard.Contracts.DTOs.Audit;

public record AuditLogDto(
    Guid Id,
    Guid? TenantId,
    Guid? UserId,
    string UserName,
    string EventType,
    string EventResult,
    string? IpAddress,
    string? Details,
    DateTime CreatedAt);
