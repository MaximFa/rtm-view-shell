using CcDashboard.Domain.Interfaces;

namespace CcDashboard.Infrastructure.Services;

public class TenantContext : ITenantContext
{
    private Guid _tenantId;
    private string _tenantSlug = string.Empty;

    public Guid TenantId => IsResolved ? _tenantId : throw new InvalidOperationException("Tenant not resolved.");
    public string TenantSlug => _tenantSlug;
    public bool IsResolved { get; private set; }

    public void Set(Guid tenantId, string tenantSlug)
    {
        _tenantId = tenantId;
        _tenantSlug = tenantSlug;
        IsResolved = true;
    }
}
