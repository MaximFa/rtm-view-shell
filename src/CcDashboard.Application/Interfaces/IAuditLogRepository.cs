using CcDashboard.Contracts.DTOs.Audit;

namespace CcDashboard.Application.Interfaces;

public interface IAuditLogRepository
{
    Task<(IReadOnlyList<AuditLogDto> Items, int Total)> GetPageAsync(
        Guid? tenantId,
        string? eventType,
        string? result,
        DateTime? from,
        DateTime? to,
        int page,
        int pageSize,
        CancellationToken ct = default);

    Task<IReadOnlyList<string>> GetDistinctEventTypesAsync(Guid? tenantId, CancellationToken ct = default);
}
