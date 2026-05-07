namespace CcDashboard.Application.Interfaces;

public interface ITokenService
{
    Task<TokenPair> CreateTokenPairAsync(Guid userId, Guid tenantId, string role, Guid? pgId, string ipAddress, string userAgent, CancellationToken ct = default);
    Task<TokenPair?> RefreshAsync(string refreshToken, string ipAddress, string userAgent, CancellationToken ct = default);
    Task RevokeAllUserTokensAsync(Guid userId, CancellationToken ct = default);
    Task<bool> IsJtiRevokedAsync(string jti, Guid tenantId, CancellationToken ct = default);
    Task RevokeJtiAsync(string jti, Guid tenantId, TimeSpan remaining, CancellationToken ct = default);
}

public record TokenPair(string AccessToken, string RefreshToken, DateTime ExpiresAt);
