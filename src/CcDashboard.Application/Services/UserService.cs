using CcDashboard.Application.DTOs;
using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Security;
using CcDashboard.Core.Domain;
using CcDashboard.Core.Enums;
using CcDashboard.Core.Exceptions;
using CcDashboard.Core.Interfaces;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Application.Services;

public class UserService : IUserService
{
    private const int MaxFailedAttempts = 5;
    private const int LockoutMinutes = 15;

    private readonly IUserRepository _users;
    private readonly IPasswordHasher _hasher;
    private readonly IAuditService _audit;
    private readonly IJwtTokenService _jwt;
    private readonly ILogger<UserService> _logger;

    public UserService(
        IUserRepository users,
        IPasswordHasher hasher,
        IAuditService audit,
        IJwtTokenService jwt,
        ILogger<UserService> logger)
    {
        _users = users;
        _hasher = hasher;
        _audit = audit;
        _jwt = jwt;
        _logger = logger;
    }

    public async Task<UserDto?> GetByIdAsync(Guid id, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(id, ct);
        return user is null ? null : MapToDto(user);
    }

    public async Task<IReadOnlyList<UserDto>> GetAllAsync(CancellationToken ct = default)
    {
        var users = await _users.GetAllAsync(ct);
        return users.Select(MapToDto).ToList();
    }

    public async Task<UserDto> CreateAsync(RegisterUserRequest request, CancellationToken ct = default)
    {
        if (await _users.ExistsAsync(u => u.Email == request.Email, ct))
            throw new DomainException($"Email '{request.Email}' is already registered.");

        var user = new User
        {
            Id = Guid.NewGuid(),
            Email = request.Email,
            DisplayName = request.DisplayName,
            PasswordHash = _hasher.Hash(request.Password),
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        await _users.AddAsync(user, ct);
        _logger.LogInformation("User {UserId} created with email {Email}", user.Id, user.Email);
        return MapToDto(user);
    }

    public async Task<UserDto> UpdateAsync(Guid id, UpdateUserRequest request, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(id, ct)
            ?? throw new NotFoundException(nameof(User), id);

        user.DisplayName = request.DisplayName;
        if (request.IsActive.HasValue)
            user.IsActive = request.IsActive.Value;

        await _users.UpdateAsync(user, ct);
        return MapToDto(user);
    }

    public async Task ChangePasswordAsync(Guid id, ChangePasswordRequest request, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(id, ct)
            ?? throw new NotFoundException(nameof(User), id);

        if (!_hasher.Verify(request.CurrentPassword, user.PasswordHash))
            throw new ForbiddenException("Current password is incorrect.");

        user.PasswordHash = _hasher.Hash(request.NewPassword);
        await _users.UpdateAsync(user, ct);
        await _audit.LogAsync(AuditEventType.PasswordChanged, id, string.Empty, string.Empty, ct: ct);
    }

    public async Task DeactivateAsync(Guid id, CancellationToken ct = default)
    {
        var user = await _users.GetByIdAsync(id, ct)
            ?? throw new NotFoundException(nameof(User), id);

        user.IsActive = false;
        await _users.UpdateAsync(user, ct);
    }

    public async Task AssignToGroupAsync(Guid userId, Guid groupId, CancellationToken ct = default)
    {
        if (!await _users.ExistsAsync(u => u.Id == userId, ct))
            throw new NotFoundException(nameof(User), userId);

        await _users.AddToGroupAsync(userId, groupId, ct);
    }

    public async Task RemoveFromGroupAsync(Guid userId, Guid groupId, CancellationToken ct = default)
    {
        await _users.RemoveFromGroupAsync(userId, groupId, ct);
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest request, CancellationToken ct = default)
    {
        var user = await _users.GetByEmailAsync(request.Email, ct);

        if (user is null || !user.IsActive)
        {
            await _audit.LogAsync(AuditEventType.LoginFailed, null, string.Empty, string.Empty,
                "Unknown or inactive email", ct);
            throw new ForbiddenException("Invalid credentials.");
        }

        if (user.LockoutEnd.HasValue && user.LockoutEnd > DateTime.UtcNow)
        {
            await _audit.LogAsync(AuditEventType.LoginFailed, user.Id, string.Empty, string.Empty,
                "Account locked", ct);
            throw new ForbiddenException("Account is temporarily locked. Try again later.");
        }

        if (!_hasher.Verify(request.Password, user.PasswordHash))
        {
            user.AccessFailedCount++;
            if (user.AccessFailedCount >= MaxFailedAttempts)
            {
                user.LockoutEnd = DateTime.UtcNow.AddMinutes(LockoutMinutes);
                user.AccessFailedCount = 0;
                await _audit.LogAsync(AuditEventType.AccountLocked, user.Id, string.Empty, string.Empty, ct: ct);
                _logger.LogWarning("User {UserId} locked out after {Attempts} failed attempts", user.Id, MaxFailedAttempts);
            }
            await _users.UpdateAsync(user, ct);
            await _audit.LogAsync(AuditEventType.LoginFailed, user.Id, string.Empty, string.Empty, ct: ct);
            throw new ForbiddenException("Invalid credentials.");
        }

        user.AccessFailedCount = 0;
        user.LockoutEnd = null;
        user.LastLoginAt = DateTime.UtcNow;
        await _users.UpdateAsync(user, ct);
        await _audit.LogAsync(AuditEventType.Login, user.Id, string.Empty, string.Empty, ct: ct);

        var dto = MapToDto(user);

        if (user.TwoFactorEnabled)
            return new LoginResponse(user.Id, user.Email, user.DisplayName, true, null, null);

        var tokens = _jwt.GenerateTokenPair(dto);
        return new LoginResponse(user.Id, user.Email, user.DisplayName, false, tokens.AccessToken, tokens.RefreshToken);
    }

    private static UserDto MapToDto(User u) =>
        new(u.Id, u.Email, u.DisplayName, u.IsSsoUser, u.TwoFactorEnabled, u.IsActive, u.LastLoginAt, u.CreatedAt);
}
