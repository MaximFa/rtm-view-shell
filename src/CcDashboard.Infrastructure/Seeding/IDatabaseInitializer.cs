namespace CcDashboard.Infrastructure.Seeding;

/// <summary>
/// Abstraction for idempotent database migration and seed on startup [DATA-07].
/// Introduced to allow test doubles without inheriting from the concrete class (PD-002).
/// </summary>
public interface IDatabaseInitializer
{
    /// <summary>
    /// Apply EF migrations (App + Audit) only — no seed, no hosted services.
    /// Used by `Web.exe migrate` for canonical fresh-install ordering (DEPLOY-14):
    /// migrate runs BEFORE schema.sql, so backend tables don't exist yet.
    /// </summary>
    Task MigrateOnlyAsync(CancellationToken ct = default);

    Task InitializeAsync(CancellationToken ct = default);
}
