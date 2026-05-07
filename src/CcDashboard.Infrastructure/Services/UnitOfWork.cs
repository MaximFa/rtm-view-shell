using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;

namespace CcDashboard.Infrastructure.Services;

public class UnitOfWork(AppDbContext db) : IUnitOfWork
{
    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
