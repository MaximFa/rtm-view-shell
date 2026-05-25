using CcDashboard.Application.Behaviors;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using MediatR;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;

namespace CcDashboard.Tests.Security.Authorization;

/// <summary>
/// Tests for AuthorizationBehavior permission enforcement [PG-04, CODE-03].
/// Per MC-T4-1: verifies that RequiredPermission is now enforced (SF-005 fixed).
/// </summary>
public class AuthorizationBehaviorTests
{
    private readonly Mock<IPermissionService> _permissionService = new();

    private static readonly Guid TestTenantId = Guid.NewGuid();
    private static readonly Guid TestUserId = Guid.NewGuid();
    private static readonly Guid TestPgId = Guid.NewGuid();

    private static RequestHandlerDelegate<string> CreateNext() => (ct) => Task.FromResult("success");

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task Handle_UserWithoutRequiredPermission_ThrowsForbiddenException()
    {
        // Arrange
        var currentUser = CreateUserAccessor("Editor", TestPgId);
        var behavior = new AuthorizationBehavior<TestPermissionCommand, string>(
            currentUser, _permissionService.Object, NullLogger<AuthorizationBehavior<TestPermissionCommand, string>>.Instance);

        var command = new TestPermissionCommand { RequiredPermission = "menu.users" };

        _permissionService
            .Setup(x => x.HasPermissionAsync(TestPgId, TestTenantId, "menu.users", It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        // Act & Assert
        var act = async () => await behavior.Handle(command, CreateNext(), CancellationToken.None);

        await act.Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*menu.users*");
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task Handle_SuperadminUser_BypassesPermissionCheck()
    {
        // Arrange
        var currentUser = CreateUserAccessor("Superadmin", permissionGroupId: null);
        var behavior = new AuthorizationBehavior<TestPermissionCommand, string>(
            currentUser, _permissionService.Object, NullLogger<AuthorizationBehavior<TestPermissionCommand, string>>.Instance);

        var command = new TestPermissionCommand { RequiredPermission = "menu.users" };

        // Act
        var result = await behavior.Handle(command, CreateNext(), CancellationToken.None);

        // Assert
        result.Should().Be("success");
        _permissionService.Verify(
            x => x.HasPermissionAsync(It.IsAny<Guid?>(), It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task Handle_UserWithRequiredPermission_ProceedsToHandler()
    {
        // Arrange
        var currentUser = CreateUserAccessor("Administrator", TestPgId);
        var behavior = new AuthorizationBehavior<TestPermissionCommand, string>(
            currentUser, _permissionService.Object, NullLogger<AuthorizationBehavior<TestPermissionCommand, string>>.Instance);

        var command = new TestPermissionCommand { RequiredPermission = "menu.users" };

        _permissionService
            .Setup(x => x.HasPermissionAsync(TestPgId, TestTenantId, "menu.users", It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        // Act
        var result = await behavior.Handle(command, CreateNext(), CancellationToken.None);

        // Assert
        result.Should().Be("success");
        _permissionService.Verify(
            x => x.HasPermissionAsync(TestPgId, TestTenantId, "menu.users", It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task Handle_NoAuthentication_ThrowsForbiddenException()
    {
        // Arrange
        var currentUser = CreateUserAccessor(role: null, permissionGroupId: null, isAuthenticated: false);
        var behavior = new AuthorizationBehavior<TestPermissionCommand, string>(
            currentUser, _permissionService.Object, NullLogger<AuthorizationBehavior<TestPermissionCommand, string>>.Instance);

        var command = new TestPermissionCommand { RequiredPermission = "menu.users" };

        // Act & Assert
        var act = async () => await behavior.Handle(command, CreateNext(), CancellationToken.None);

        await act.Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*Authentication required*");
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task Handle_RoleNotAllowed_ThrowsForbiddenException()
    {
        // Arrange
        var currentUser = CreateUserAccessor("Viewer", TestPgId);
        var behavior = new AuthorizationBehavior<TestRoleRestrictedCommand, string>(
            currentUser, _permissionService.Object,
            NullLogger<AuthorizationBehavior<TestRoleRestrictedCommand, string>>.Instance);

        var command = new TestRoleRestrictedCommand();

        // Act & Assert
        var act = async () => await behavior.Handle(command, CreateNext(), CancellationToken.None);

        await act.Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*Administrator*");
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task Handle_RoleAllowed_ProceedsWithoutPermissionCheck()
    {
        // Arrange
        var currentUser = CreateUserAccessor("Administrator", TestPgId);
        var behavior = new AuthorizationBehavior<TestRoleOnlyCommand, string>(
            currentUser, _permissionService.Object,
            NullLogger<AuthorizationBehavior<TestRoleOnlyCommand, string>>.Instance);

        var command = new TestRoleOnlyCommand();

        // Act
        var result = await behavior.Handle(command, CreateNext(), CancellationToken.None);

        // Assert
        result.Should().Be("success");
        _permissionService.Verify(
            x => x.HasPermissionAsync(It.IsAny<Guid?>(), It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    [Trait("Req", "PG-04")]
    public async Task Handle_NoTenantContext_ThrowsForbiddenException_WhenPermissionRequired()
    {
        // Arrange
        var currentUser = new StubCurrentUserAccessor
        {
            UserId = TestUserId,
            Role = "Editor",
            PermissionGroupId = TestPgId,
            TenantId = null,
            IsAuthenticated = true
        };
        var behavior = new AuthorizationBehavior<TestPermissionCommand, string>(
            currentUser, _permissionService.Object, NullLogger<AuthorizationBehavior<TestPermissionCommand, string>>.Instance);

        var command = new TestPermissionCommand { RequiredPermission = "menu.users" };

        // Act & Assert
        var act = async () => await behavior.Handle(command, CreateNext(), CancellationToken.None);

        await act.Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*Tenant context required*");
    }

    private static StubCurrentUserAccessor CreateUserAccessor(
        string? role, Guid? permissionGroupId, bool isAuthenticated = true)
    {
        return new StubCurrentUserAccessor
        {
            UserId = isAuthenticated ? TestUserId : null,
            Role = role,
            PermissionGroupId = permissionGroupId,
            TenantId = isAuthenticated ? TestTenantId : null,
            IsAuthenticated = isAuthenticated
        };
    }

}

public record TestPermissionCommand : IRequest<string>, IRequiresPermission
{
    public string? RequiredPermission { get; init; }
    public string[] AllowedRoles => [];
}

public record TestRoleRestrictedCommand : IRequest<string>, IRequiresPermission
{
    public string[] AllowedRoles => ["Administrator", "Editor"];
    public string? RequiredPermission => null;
}

public record TestRoleOnlyCommand : IRequest<string>, IRequiresPermission
{
    public string[] AllowedRoles => ["Administrator"];
    public string? RequiredPermission => null;
}

internal class StubCurrentUserAccessor : ICurrentUserAccessor
{
    public Guid? UserId { get; init; }
    public string? UserName { get; init; }
    public string? Role { get; init; }
    public Guid? PermissionGroupId { get; init; }
    public Guid? TenantId { get; init; }
    public string PreferredLocale { get; init; } = "en-US";
    public bool IsAuthenticated { get; init; }

    public Task InitAsync() => Task.CompletedTask;
}
