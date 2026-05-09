using System.Security.Cryptography;
using System.Text;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Identity;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;
using UUIDNext;

namespace CcDashboard.Infrastructure.Security;

public class TwoFactorService(
    AppDbContext db,
    IEmailSender emailSender,
    IConnectionMultiplexer redis,
    IDateTimeProvider clock,
    ILogger<TwoFactorService> logger)
    : ITwoFactorService
{
    private readonly IDatabase _cache = redis.GetDatabase();

    public async Task<TwoFactorSendResult> SendCodeAsync(
        Guid userId, Guid tenantId, string email, CancellationToken ct = default)
    {
        // Rate-limit resend: 1 per minute per userId [2FA-04] [ARCH-08]
        var throttleKey = $"{tenantId}:2fa_resend:{userId}";
        if (await _cache.KeyExistsAsync(throttleKey))
            return new TwoFactorSendResult(false, "Please wait before requesting another code.");

        // Generate 6-digit code via CSRNG [2FA-02]
        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");

        // Generate salt and HMAC-SHA256 [2FA-03]
        var saltBytes = RandomNumberGenerator.GetBytes(16);
        var salt = Convert.ToHexString(saltBytes);
        var hash = ComputeHmac(code, salt);

        // Invalidate any existing unused codes for this user
        var existingCodes = await db.TwoFactorCodes
            .IgnoreQueryFilters()
            .Where(c => c.UserId == userId && c.ConsumedAt == null && c.ExpiresAt > clock.UtcNow)
            .ToListAsync(ct);
        foreach (var old in existingCodes)
            old.ConsumedAt = clock.UtcNow;

        // Persist new code
        var record = new TwoFactorCode
        {
            Id = Uuid.NewSequential(),
            UserId = userId,
            TenantId = tenantId,
            CodeHash = hash,
            Salt = salt,
            ExpiresAt = clock.UtcNow.AddMinutes(10),
            AttemptCount = 0
        };
        db.TwoFactorCodes.Add(record);
        await db.SaveChangesAsync(ct);

        // Set resend throttle key with 60s TTL
        await _cache.StringSetAsync(throttleKey, "1", TimeSpan.FromSeconds(60));

        // Send email — body contains only the code [2FA-05]
        await emailSender.SendAsync(
            email,
            "Your one-time code",
            $"Your verification code is: {code}\n\nThis code is valid for 10 minutes.");

        logger.LogInformation("2FA code sent for userId={UserId}", userId);
        return new TwoFactorSendResult(true);
    }

    public async Task<TwoFactorVerifyResult> VerifyCodeAsync(
        Guid userId, string code, CancellationToken ct = default)
    {
        var record = await db.TwoFactorCodes
            .IgnoreQueryFilters()
            .Where(c => c.UserId == userId && c.ConsumedAt == null && c.ExpiresAt > clock.UtcNow)
            .OrderByDescending(c => c.ExpiresAt)
            .FirstOrDefaultAsync(ct);

        if (record == null)
            return new TwoFactorVerifyResult(false, Error: "Code not found or expired.");

        record.AttemptCount++;

        if (record.AttemptCount >= 3)
        {
            // Invalidate on exceed [2FA-04]
            record.ConsumedAt = clock.UtcNow;
            await db.SaveChangesAsync(ct);
            return new TwoFactorVerifyResult(false, MaxAttemptsExceeded: true, Error: "Too many attempts. Please request a new code.");
        }

        var expectedHash = ComputeHmac(code.Trim(), record.Salt);
        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(expectedHash),
                Encoding.UTF8.GetBytes(record.CodeHash)))
        {
            await db.SaveChangesAsync(ct);
            return new TwoFactorVerifyResult(false, Error: "Invalid code.");
        }

        record.ConsumedAt = clock.UtcNow;
        await db.SaveChangesAsync(ct);
        return new TwoFactorVerifyResult(true);
    }

    public async Task<bool> IsResendThrottledAsync(Guid userId, Guid tenantId, CancellationToken ct = default)
    {
        return await _cache.KeyExistsAsync($"{tenantId}:2fa_resend:{userId}");
    }

    private static string ComputeHmac(string code, string salt)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(salt));
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(code));
        return Convert.ToHexString(hash);
    }
}
