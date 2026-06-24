using CcDashboard.Application.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence;

/// <summary>
/// Infrastructure implementation of IAppDbContextFactory (ADR-009 R2).
/// Wraps EF Core's IDbContextFactory to return IAppDbContext.
/// Note: Named AppDbContextAbstractionFactory to avoid conflict with the
/// EF Core design-time factory (DesignTimeDbContextFactory.cs::AppDbContextFactory).
/// </summary>
public class AppDbContextAbstractionFactory(
    IDbContextFactory<AppDbContext> inner)
    : IAppDbContextFactory
{
    public async Task<IAppDbContext> CreateDbContextAsync(CancellationToken cancellationToken = default)
    {
        return await inner.CreateDbContextAsync(cancellationToken);
    }
}
