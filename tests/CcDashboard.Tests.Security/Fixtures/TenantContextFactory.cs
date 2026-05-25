using CcDashboard.Domain.Interfaces;

namespace CcDashboard.Tests.Security.Fixtures;

/// <summary>
/// Factory for creating ITenantContext instances in tests.
/// Allows quick switching between tenant contexts for isolation tests.
/// </summary>
public static class TenantContextFactory
{
    /// <summary>
    /// Creates a tenant context for the specified tenant ID.
    /// </summary>
    public static ITenantContext Create(Guid tenantId) => new TestTenantContext(tenantId);

    /// <summary>
    /// Creates a mutable tenant context that can be changed during a test.
    /// </summary>
    public static MutableTenantContext CreateMutable(Guid initialTenantId) => new(initialTenantId);
}

/// <summary>
/// Mutable tenant context for tests that need to switch tenant mid-test.
/// </summary>
public class MutableTenantContext(Guid tenantId, string tenantSlug = "test") : ITenantContext
{
    private Guid _tenantId = tenantId;
    private string _tenantSlug = tenantSlug;

    public Guid TenantId => _tenantId;
    public string TenantSlug => _tenantSlug;
    public bool IsResolved => true;

    public void Set(Guid tenantId, string tenantSlug)
    {
        _tenantId = tenantId;
        _tenantSlug = tenantSlug;
    }
}
