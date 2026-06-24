namespace CcDashboard.Application.Interfaces;

/// <summary>
/// Application-level factory abstraction for IAppDbContext (ADR-009, ARCH-11 R2).
/// Wraps IDbContextFactory&lt;AppDbContext&gt; from Infrastructure.
/// Used by handlers that need isolated context instances (e.g., concurrent widget queries).
/// </summary>
public interface IAppDbContextFactory
{
    /// <summary>
    /// Creates a new isolated IAppDbContext instance.
    /// Caller is responsible for disposal (async using).
    /// </summary>
    Task<IAppDbContext> CreateDbContextAsync(CancellationToken cancellationToken = default);
}
