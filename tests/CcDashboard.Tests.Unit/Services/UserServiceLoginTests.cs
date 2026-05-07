using CcDashboard.Application.DTOs;
using CcDashboard.Application.Security;
using CcDashboard.Application.Services;
using CcDashboard.Core.Domain;
using CcDashboard.Core.Enums;
using CcDashboard.Core.Exceptions;
using CcDashboard.Core.Interfaces;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Services;

public class UserServiceLoginTests
{
    private readonly IUserRepository _users = Substitute.For<IUserRepository>();
    private readonly IPasswordHasher _hasher = Substitute.For<IPasswordHasher>();
    private readonly IAuditService _audit = Substitute.For<IAuditService>();
    private readonly IJwtTokenService _jwt = Substitute.For<IJwtTokenService>();
    private readonly UserService _sut;

    public UserServiceLoginTests()
    {
        _sut = new UserService(_users, _hasher, _audit, _jwt, NullLogger<UserService>.Instance);
    }

    private static User ActiveUser(bool twoFactor = false) => new()
    {
        Id = Guid.NewGuid(),
        Email = "user@example.com",
        DisplayName = "Test User",
        PasswordHash = "salt:hash",
        IsActive = true,
        TwoFactorEnabled = twoFactor
    };

    [Fact]
    public async Task Unknown_email_throws_ForbiddenException()
    {
        _users.GetByEmailAsync(Arg.Any<string>()).Returns((User?)null);

        await _sut.Invoking(s => s.LoginAsync(new LoginRequest("x@x.com", "pass")))
            .Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Inactive_user_throws_ForbiddenException()
    {
        var user = ActiveUser();
        user.IsActive = false;
        _users.GetByEmailAsync(Arg.Any<string>()).Returns(user);

        await _sut.Invoking(s => s.LoginAsync(new LoginRequest(user.Email, "pass")))
            .Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Locked_account_throws_ForbiddenException()
    {
        var user = ActiveUser();
        user.LockoutEnd = DateTime.UtcNow.AddMinutes(10);
        _users.GetByEmailAsync(Arg.Any<string>()).Returns(user);

        await _sut.Invoking(s => s.LoginAsync(new LoginRequest(user.Email, "pass")))
            .Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*locked*");
    }

    [Fact]
    public async Task Expired_lockout_allows_login()
    {
        var user = ActiveUser();
        user.LockoutEnd = DateTime.UtcNow.AddMinutes(-1);
        _users.GetByEmailAsync(Arg.Any<string>()).Returns(user);
        _hasher.Verify(Arg.Any<string>(), Arg.Any<string>()).Returns(true);
        _jwt.GenerateTokenPair(Arg.Any<UserDto>()).Returns(new TokenPair("at", "rt", DateTime.UtcNow.AddMinutes(15)));

        var result = await _sut.LoginAsync(new LoginRequest(user.Email, "pass"));
        result.RequiresTwoFactor.Should().BeFalse();
    }

    [Fact]
    public async Task Wrong_password_throws_ForbiddenException()
    {
        var user = ActiveUser();
        _users.GetByEmailAsync(Arg.Any<string>()).Returns(user);
        _hasher.Verify(Arg.Any<string>(), Arg.Any<string>()).Returns(false);

        await _sut.Invoking(s => s.LoginAsync(new LoginRequest(user.Email, "wrong")))
            .Should().ThrowAsync<ForbiddenException>();
    }

    [Fact]
    public async Task Five_wrong_passwords_set_LockoutEnd()
    {
        var user = ActiveUser();
        _users.GetByEmailAsync(Arg.Any<string>()).Returns(user);
        _hasher.Verify(Arg.Any<string>(), Arg.Any<string>()).Returns(false);

        for (int i = 0; i < 5; i++)
        {
            await _sut.Invoking(s => s.LoginAsync(new LoginRequest(user.Email, "wrong")))
                .Should().ThrowAsync<ForbiddenException>();
        }

        user.LockoutEnd.Should().NotBeNull()
            .And.BeCloseTo(DateTime.UtcNow.AddMinutes(15), TimeSpan.FromSeconds(5));
    }

    [Fact]
    public async Task Correct_password_without_2FA_returns_tokens()
    {
        var user = ActiveUser(twoFactor: false);
        _users.GetByEmailAsync(Arg.Any<string>()).Returns(user);
        _hasher.Verify(Arg.Any<string>(), Arg.Any<string>()).Returns(true);
        _jwt.GenerateTokenPair(Arg.Any<UserDto>()).Returns(new TokenPair("access_token", "refresh_token", DateTime.UtcNow.AddMinutes(15)));

        var result = await _sut.LoginAsync(new LoginRequest(user.Email, "pass"));

        result.RequiresTwoFactor.Should().BeFalse();
        result.AccessToken.Should().Be("access_token");
        result.RefreshToken.Should().Be("refresh_token");
    }

    [Fact]
    public async Task Correct_password_with_2FA_returns_RequiresTwoFactor()
    {
        var user = ActiveUser(twoFactor: true);
        _users.GetByEmailAsync(Arg.Any<string>()).Returns(user);
        _hasher.Verify(Arg.Any<string>(), Arg.Any<string>()).Returns(true);

        var result = await _sut.LoginAsync(new LoginRequest(user.Email, "pass"));

        result.RequiresTwoFactor.Should().BeTrue();
        result.AccessToken.Should().BeNull();
        result.RefreshToken.Should().BeNull();
    }

    [Fact]
    public async Task Successful_login_resets_AccessFailedCount()
    {
        var user = ActiveUser();
        user.AccessFailedCount = 3;
        _users.GetByEmailAsync(Arg.Any<string>()).Returns(user);
        _hasher.Verify(Arg.Any<string>(), Arg.Any<string>()).Returns(true);
        _jwt.GenerateTokenPair(Arg.Any<UserDto>()).Returns(new TokenPair("at", "rt", DateTime.UtcNow.AddMinutes(15)));

        await _sut.LoginAsync(new LoginRequest(user.Email, "pass"));

        user.AccessFailedCount.Should().Be(0);
    }
}
