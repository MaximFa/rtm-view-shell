namespace CcDashboard.Application.Interfaces;

/// <summary>
/// Application-level factory abstraction for IBackendEmulationDbContext (ADR-009, ARCH-11).
/// Wraps IDbContextFactory&lt;BackendEmulationDbContext&gt; from Infrastructure.
/// Used by handlers that need isolated context instances (e.g., concurrent widget queries).
/// </summary>
public interface IBackendEmulationDbContextFactory
{
    /// <summary>
    /// Creates a new isolated IBackendEmulationDbContext instance.
    /// Caller is responsible for disposal (async using).
    /// </summary>
    Task<IBackendEmulationDbContext> CreateDbContextAsync(CancellationToken cancellationToken = default);
}
