using CcDashboard.Application.Interfaces;
using CcDashboard.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Infrastructure.Persistence.Repositories;

public class UserRepository(AppDbContext db, UserManager<ApplicationUser> userManager) : IUserRepository
{
    public async Task<ApplicationUserSnapshot?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == id, ct);
        if (user == null) return null;
        var role = (await userManager.GetRolesAsync(user)).FirstOrDefault();
        return ToSnapshot(user, role);
    }

    public async Task<ApplicationUserSnapshot?> GetByEmailAsync(Guid tenantId, string email, CancellationToken ct = default)
    {
        var normalized = email.ToUpperInvariant();
        var user = await db.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.TenantId == tenantId && u.NormalizedEmail == normalized, ct);
        if (user == null) return null;
        var role = (await userManager.GetRolesAsync(user)).FirstOrDefault();
        return ToSnapshot(user, role);
    }

    public async Task<ApplicationUserSnapshot?> GetByUserNameAsync(Guid tenantId, string userName, CancellationToken ct = default)
    {
        var normalized = userName.ToUpperInvariant();
        var user = await db.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.TenantId == tenantId && u.NormalizedUserName == normalized, ct);
        if (user == null) return null;
        var role = (await userManager.GetRolesAsync(user)).FirstOrDefault();
        return ToSnapshot(user, role);
    }

    public Task<bool> ExistsAsync(Guid tenantId, string email, CancellationToken ct = default)
    {
        var normalized = email.ToUpperInvariant();
        return db.Users.AnyAsync(u => u.TenantId == tenantId && u.NormalizedEmail == normalized, ct);
    }

    public async Task<IReadOnlyList<ApplicationUserSnapshot>> GetPageAsync(
        Guid? tenantId, string? search, string? role, Guid? pgId, bool? isActive,
        int page, int pageSize, string sortBy, bool desc, CancellationToken ct = default)
    {
        var q = db.Users.AsNoTracking().IgnoreQueryFilters()
            .Where(u => tenantId == null || u.TenantId == tenantId);
        if (!string.IsNullOrWhiteSpace(search))
            q = q.Where(u => EF.Functions.ILike(u.Email!, $"%{search}%") || EF.Functions.ILike(u.UserName!, $"%{search}%"));
        if (isActive.HasValue)
            q = q.Where(u => u.IsActive == isActive.Value);
        if (pgId.HasValue)
            q = q.Where(u => u.PermissionGroupId == pgId.Value);

        var users = await q.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        var snapshots = new List<ApplicationUserSnapshot>();
        foreach (var u in users)
        {
            var r = (await userManager.GetRolesAsync(u)).FirstOrDefault();
            snapshots.Add(ToSnapshot(u, r));
        }
        return snapshots;
    }

    public Task<int> CountAsync(Guid? tenantId, string? search, string? role, Guid? pgId, bool? isActive, CancellationToken ct = default)
    {
        var q = db.Users.AsNoTracking().IgnoreQueryFilters()
            .Where(u => tenantId == null || u.TenantId == tenantId);
        if (!string.IsNullOrWhiteSpace(search))
            q = q.Where(u => EF.Functions.ILike(u.Email!, $"%{search}%") || EF.Functions.ILike(u.UserName!, $"%{search}%"));
        if (isActive.HasValue)
            q = q.Where(u => u.IsActive == isActive.Value);
        if (pgId.HasValue)
            q = q.Where(u => u.PermissionGroupId == pgId.Value);
        return q.CountAsync(ct);
    }

    private static ApplicationUserSnapshot ToSnapshot(ApplicationUser u, string? role) => new(
        u.Id, u.TenantId, u.UserName ?? string.Empty, u.Email ?? string.Empty,
        u.FirstName, u.LastName, role, u.PermissionGroupId, u.IsActive, u.Is2faEnabled,
        u.LastLoginAt, u.PreferredLocale, u.MustChangePasswordAt, u.LockoutEnabled
            ? DateTime.MinValue  // placeholder; real createdAt would need additional column
            : DateTime.MinValue,
        u.PasswordHash, u.AccessFailedCount, u.LockoutEnd, u.LockoutEnabled);
}
