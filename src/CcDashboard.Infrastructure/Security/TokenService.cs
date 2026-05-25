using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using StackExchange.Redis;
using UUIDNext;

namespace CcDashboard.Infrastructure.Security;

public class TokenService(
    AppDbContext db,
    IConnectionMultiplexer redis,
    IDateTimeProvider clock,
    IConfiguration config,
    ILogger<TokenService> logger)
    : ITokenService
{
    private readonly IDatabase _cache = redis.GetDatabase();
    private RSA? _rsaKey;
    private readonly object _rsaLock = new();

    private string Issuer => config["Jwt:Issuer"] ?? "RTMView";
    private string Audience => config["Jwt:Audience"] ?? "RTMView.Users";
    private int AccessTokenMinutes => int.TryParse(config["Jwt:AccessTokenExpiryMinutes"], out var m) ? m : 15;
    private int RefreshTokenHours => int.TryParse(config["Jwt:RefreshTokenExpiryHours"], out var h) ? h : 8;
    private bool UseRsaSigning => !string.IsNullOrEmpty(config["Jwt:PrivateKeyPath"]);

    /// <summary>
    /// Gets signing credentials. Uses RS256 if PrivateKeyPath is configured [AUTH-API-02],
    /// falls back to HS256 for development only.
    /// </summary>
    private SigningCredentials GetSigningCredentials()
    {
        // Production: RS256 with RSA-2048+ key [AUTH-API-02]
        var privateKeyPath = config["Jwt:PrivateKeyPath"];
        if (!string.IsNullOrEmpty(privateKeyPath))
        {
            lock (_rsaLock)
            {
                if (_rsaKey is null)
                {
                    _rsaKey = RSA.Create();
                    var keyPem = File.ReadAllText(privateKeyPath);
                    _rsaKey.ImportFromPem(keyPem);
                    logger.LogInformation("JWT signing: RS256 with RSA key from {Path}", privateKeyPath);
                }
            }
            return new SigningCredentials(new RsaSecurityKey(_rsaKey), SecurityAlgorithms.RsaSha256);
        }

        // Development fallback: HS256 (NOT for production)
        var secret = config["Jwt:SecretKey"];
        if (string.IsNullOrEmpty(secret))
            throw new InvalidOperationException(
                "JWT signing not configured. Set Jwt:PrivateKeyPath (production) or Jwt:SecretKey (dev only).");

        if (!secret.Contains("dev", StringComparison.OrdinalIgnoreCase))
            logger.LogWarning("JWT using HS256 symmetric key. For production, configure Jwt:PrivateKeyPath with RSA key.");

        return new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)),
            SecurityAlgorithms.HmacSha256);
    }

    public async Task<TokenPair> CreateTokenPairAsync(
        Guid userId, Guid tenantId, string role, Guid? pgId,
        string ipAddress, string userAgent, CancellationToken ct = default)
    {
        var jti = Uuid.NewSequential();
        var now = clock.UtcNow;
        var accessExpiry = now.AddMinutes(AccessTokenMinutes);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, userId.ToString()),
            new(JwtRegisteredClaimNames.Jti, jti.ToString()),
            new(JwtRegisteredClaimNames.Iat, new DateTimeOffset(now).ToUnixTimeSeconds().ToString(), ClaimValueTypes.Integer64),
            new("tenant_id", tenantId.ToString()),
            new(ClaimTypes.Role, role)
        };
        if (pgId.HasValue)
            claims.Add(new Claim("permission_group_id", pgId.Value.ToString()));

        var credentials = GetSigningCredentials();
        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            NotBefore = now,
            Expires = accessExpiry,
            Issuer = Issuer,
            Audience = Audience,
            SigningCredentials = credentials
        };

        var handler = new JwtSecurityTokenHandler();
        var accessToken = handler.WriteToken(handler.CreateToken(tokenDescriptor));

        // Refresh token — random bytes, store SHA-256 hash [AUTH-API-03]
        var rawRefresh = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
        var refreshHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(rawRefresh)));
        var refreshExpiry = now.AddHours(RefreshTokenHours);

        var refreshRecord = new RefreshToken
        {
            Id = Uuid.NewSequential(),
            UserId = userId,
            TenantId = tenantId,
            Jti = jti,
            TokenHash = refreshHash,
            ExpiresAt = refreshExpiry,
            IssuedAt = now,
            IpAddress = ipAddress,
            UserAgent = userAgent
        };
        db.RefreshTokens.Add(refreshRecord);
        await db.SaveChangesAsync(ct);

        return new TokenPair(accessToken, rawRefresh, accessExpiry);
    }

    public async Task<TokenPair?> RefreshAsync(
        string refreshToken, string ipAddress, string userAgent, CancellationToken ct = default)
    {
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(refreshToken)));

        var record = await db.RefreshTokens
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(r => r.TokenHash == hash, ct);

        if (record == null)
            return null;

        // Detect token reuse [AUTH-API-04]
        if (record.IsRevoked)
        {
            await RevokeAllUserTokensAsync(record.UserId, ct);
            return null;
        }

        if (record.IsExpired)
            return null;

        // Revoke old token and issue new pair
        record.RevokedAt = clock.UtcNow;

        var user = await db.Set<ApplicationUser>()
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(u => u.Id == record.UserId, ct);
        if (user == null)
            return null;

        var roles = await db.Set<Microsoft.AspNetCore.Identity.IdentityUserRole<Guid>>()
            .Where(ur => ur.UserId == user.Id)
            .Join(db.Set<ApplicationRole>(), ur => ur.RoleId, r => r.Id, (_, r) => r.Name!)
            .FirstOrDefaultAsync(ct);

        var pair = await CreateTokenPairAsync(
            user.Id, user.TenantId, roles ?? "Viewer",
            user.PermissionGroupId, ipAddress, userAgent, ct);

        // Link replacement
        var newRecord = await db.RefreshTokens
            .IgnoreQueryFilters()
            .OrderByDescending(r => r.IssuedAt)
            .FirstOrDefaultAsync(r => r.UserId == user.Id && r.IssuedAt >= clock.UtcNow.AddSeconds(-5), ct);
        if (newRecord != null)
            record.ReplacedByTokenId = newRecord.Id;

        await db.SaveChangesAsync(ct);
        return pair;
    }

    public async Task RevokeAllUserTokensAsync(Guid userId, CancellationToken ct = default)
    {
        var tokens = await db.RefreshTokens
            .IgnoreQueryFilters()
            .Where(r => r.UserId == userId && r.RevokedAt == null)
            .ToListAsync(ct);
        foreach (var t in tokens)
            t.RevokedAt = clock.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task<bool> IsJtiRevokedAsync(string jti, Guid tenantId, CancellationToken ct = default)
    {
        return await _cache.KeyExistsAsync($"{tenantId}:revoked_jti:{jti}");
    }

    public async Task RevokeJtiAsync(string jti, Guid tenantId, TimeSpan remaining, CancellationToken ct = default)
    {
        // Skip if token already expired — no need to add to revocation list
        if (remaining <= TimeSpan.Zero)
            return;

        await _cache.StringSetAsync($"{tenantId}:revoked_jti:{jti}", "1", remaining);
    }
}
