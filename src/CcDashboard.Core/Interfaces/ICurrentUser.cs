namespace CcDashboard.Core.Interfaces;

public interface ICurrentUser
{
    Guid UserId { get; }
    string Email { get; }
    bool IsAuthenticated { get; }
    bool IsAdmin { get; }
    IReadOnlyList<Guid> GroupIds { get; }
}
