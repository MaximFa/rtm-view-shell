namespace CcDashboard.Domain.Interfaces;

public interface ITenantContext
{
    Guid TenantId { get; }
    string TenantSlug { get; }
    bool IsResolved { get; }
    void Set(Guid tenantId, string tenantSlug);
}
