using CcDashboard.Core.Domain;
using CcDashboard.Core.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class UserRepository : Repository<User>, IUserRepository
{
    public UserRepository(AppDbContext context) : base(context) { }

    public async Task<User?> GetByEmailAsync(string email, CancellationToken ct = default)
        => await DbSet.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Email == email, ct);

    public async Task<User?> GetByEmailWithGroupsAsync(string email, CancellationToken ct = default)
        => await DbSet.AsNoTracking()
            .Include(u => u.Groups)
                .ThenInclude(ug => ug.Group)
            .FirstOrDefaultAsync(u => u.Email == email, ct);

    public async Task<User?> GetByIdWithGroupsAsync(Guid id, CancellationToken ct = default)
        => await DbSet.AsNoTracking()
            .Include(u => u.Groups)
                .ThenInclude(ug => ug.Group)
            .FirstOrDefaultAsync(u => u.Id == id, ct);

    public async Task AddToGroupAsync(Guid userId, Guid groupId, CancellationToken ct = default)
    {
        var already = await Context.Set<UserGroup>()
            .AnyAsync(ug => ug.UserId == userId && ug.GroupId == groupId, ct);

        if (!already)
        {
            Context.Set<UserGroup>().Add(new UserGroup { UserId = userId, GroupId = groupId });
            await Context.SaveChangesAsync(ct);
        }
    }

    public async Task RemoveFromGroupAsync(Guid userId, Guid groupId, CancellationToken ct = default)
    {
        var entry = await Context.Set<UserGroup>()
            .FirstOrDefaultAsync(ug => ug.UserId == userId && ug.GroupId == groupId, ct);

        if (entry is not null)
        {
            Context.Set<UserGroup>().Remove(entry);
            await Context.SaveChangesAsync(ct);
        }
    }
}
