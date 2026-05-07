using CcDashboard.Core.Domain;

namespace CcDashboard.Core.Interfaces;

public interface IUserRepository : IRepository<User>
{
    Task<User?> GetByEmailAsync(string email, CancellationToken ct = default);
    Task<User?> GetByEmailWithGroupsAsync(string email, CancellationToken ct = default);
    Task<User?> GetByIdWithGroupsAsync(Guid id, CancellationToken ct = default);
    Task AddToGroupAsync(Guid userId, Guid groupId, CancellationToken ct = default);
    Task RemoveFromGroupAsync(Guid userId, Guid groupId, CancellationToken ct = default);
}
