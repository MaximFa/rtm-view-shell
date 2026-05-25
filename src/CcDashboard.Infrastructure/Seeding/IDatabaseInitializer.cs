namespace CcDashboard.Infrastructure.Seeding;

/// <summary>
/// Abstraction for idempotent database migration and seed on startup [DATA-07].
/// Introduced to allow test doubles without inheriting from the concrete class (PD-002).
/// </summary>
public interface IDatabaseInitializer
{
    Task InitializeAsync(CancellationToken ct = default);
}
