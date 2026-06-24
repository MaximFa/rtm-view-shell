using CcDashboard.Domain.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;

namespace CcDashboard.Application.Interfaces;

/// <summary>
/// Application-level abstraction over BackendEmulationDbContext (ADR-009, ARCH-11).
/// Handlers in Application depend on this interface, not the concrete Infrastructure context.
/// Exposes DbSet properties for backend-owned tables that handlers query.
/// </summary>
public interface IBackendEmulationDbContext : IAsyncDisposable
{
    // RTS Grid metrics (cross-tenant) — used by GetAgentStateDefinitions for MetricId lookup
    DbSet<RtsGridMetric> RtsGridMetrics { get; }

    // NGC junction tables — used by DayTrendQueryHandler for queue resolution
    DbSet<NgcBusinessUnitQueueClassification> NgcBusinessUnitQueueClassifications { get; }

    // For raw SQL (DayTrend stored functions)
    DatabaseFacade Database { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
