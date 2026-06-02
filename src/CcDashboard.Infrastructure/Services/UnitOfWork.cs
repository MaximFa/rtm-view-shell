using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;

namespace CcDashboard.Infrastructure.Services;

public class UnitOfWork(AppDbContext db, BackendEmulationDbContext beDb) : IUnitOfWork
{
    public async Task<int> SaveChangesAsync(CancellationToken ct = default)
    {
        var result = await db.SaveChangesAsync(ct);
        await beDb.SaveChangesAsync(ct);  // Save NGC repositories (Site, BU, Supergroup etc.)
        return result;
    }
}
