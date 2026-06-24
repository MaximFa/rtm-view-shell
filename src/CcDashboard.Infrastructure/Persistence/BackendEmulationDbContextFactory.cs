using CcDashboard.Application.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence;

/// <summary>
/// Infrastructure implementation of IBackendEmulationDbContextFactory (ADR-009).
/// Wraps EF Core's IDbContextFactory to return IBackendEmulationDbContext.
/// </summary>
public class BackendEmulationDbContextFactory(
    IDbContextFactory<BackendEmulationDbContext> inner)
    : IBackendEmulationDbContextFactory
{
    public async Task<IBackendEmulationDbContext> CreateDbContextAsync(CancellationToken cancellationToken = default)
    {
        return await inner.CreateDbContextAsync(cancellationToken);
    }
}
