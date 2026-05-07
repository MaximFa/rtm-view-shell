using System.Security.Cryptography;
using CcDashboard.Core.Enums;
using CcDashboard.Core.Exceptions;
using CcDashboard.Core.Interfaces;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Application.Security;

public class TwoFactorService : ITwoFactorService
{
    private const int CodeValidMinutes = 10;

    private readonly IUserRepository _users;
    private readonly IEmailSender _email;
    private readonly IPasswordHasher _hasher;
    private readonly IAuditService _audit;
    private readonly ILogger<TwoFactorService> _logger;

    public TwoFactorService(
        IUserRepository users,
        IEmailSender email,
        IPasswordHasher hasher,
        IAuditService audit,
        ILogger<TwoFactorService> logger)
    {
        _users = users;
        _email = email;
        _hasher = hasher;
        _audit = audit;
        _logger = logger;
    }

    public async Task SendCodeAsync(Guid userId, string email, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(userId, ct)
            ?? throw new NotFoundException(nameof(Core.Domain.User), userId);

        var code = GenerateCode();

        user.TwoFactorSecret = _hasher.Hash(code);
        user.TwoFactorSecretExpiry = DateTime.UtcNow.AddMinutes(CodeValidMinutes);
        await _users.UpdateAsync(user, ct);

        await _email.SendAsync(
            email,
            "Your verification code",
            $"<p>Your one-time verification code is: <strong>{code}</strong></p>" +
            $"<p>Valid for {CodeValidMinutes} minutes.</p>",
            ct);

        await _audit.LogAsync(AuditEventType.TwoFactorSent, userId, string.Empty, string.Empty, ct: ct);
        _logger.LogInformation("Two-factor code sent to user {UserId}", userId);
    }

    public async Task<bool> VerifyCodeAsync(Guid userId, string code, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(userId, ct)
            ?? throw new NotFoundException(nameof(Core.Domain.User), userId);

        if (user.TwoFactorSecret is null || user.TwoFactorSecretExpiry is null)
        {
            await _audit.LogAsync(AuditEventType.TwoFactorFailed, userId, string.Empty, string.Empty, "No pending code", ct);
            return false;
        }

        if (DateTime.UtcNow > user.TwoFactorSecretExpiry)
        {
            await _audit.LogAsync(AuditEventType.TwoFactorFailed, userId, string.Empty, string.Empty, "Code expired", ct);
            return false;
        }

        var valid = _hasher.Verify(code, user.TwoFactorSecret);

        if (valid)
        {
            user.TwoFactorSecret = null;
            user.TwoFactorSecretExpiry = null;
            await _users.UpdateAsync(user, ct);
            await _audit.LogAsync(AuditEventType.TwoFactorVerified, userId, string.Empty, string.Empty, ct: ct);
        }
        else
        {
            await _audit.LogAsync(AuditEventType.TwoFactorFailed, userId, string.Empty, string.Empty, "Invalid code", ct);
        }

        return valid;
    }

    private static string GenerateCode()
        => RandomNumberGenerator.GetInt32(100_000, 1_000_000).ToString("D6");
}
