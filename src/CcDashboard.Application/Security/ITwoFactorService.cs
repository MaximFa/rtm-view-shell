namespace CcDashboard.Application.Security;

public interface ITwoFactorService
{
    Task SendCodeAsync(Guid userId, string email, CancellationToken ct = default);
    Task<bool> VerifyCodeAsync(Guid userId, string code, CancellationToken ct = default);
}
