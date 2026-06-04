using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;

namespace CcDashboard.Infrastructure.Services;

public class UnitOfWork(AppDbContext db) : IUnitOfWork
{
    public async Task<int> SaveChangesAsync(CancellationToken ct = default)
    {
        // Only save AppDbContext here.
        // BackendEmulationDbContext (RTSGrid, NGC tables) is saved directly
        // by each repository (RtsRepository, NgcRepositories) after every operation.
        // Including it here caused concurrent SaveChangesAsync on the same instance.
        return await db.SaveChangesAsync(ct);
    }
}
