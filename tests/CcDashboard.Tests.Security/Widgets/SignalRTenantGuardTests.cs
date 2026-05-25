using System.Security.Claims;
using CcDashboard.Web.Hubs;
using FluentAssertions;
using Microsoft.AspNetCore.SignalR;
using NSubstitute;

namespace CcDashboard.Tests.Security.Widgets;

/// <summary>
/// Tests for SignalR Hub TenantId guard (ARCH-09).
/// Verifies that Hub methods check token TenantId before adding connections to groups.
/// </summary>
public class SignalRTenantGuardTests
{
    private readonly Guid _tenantAId = Guid.Parse("11111111-1111-1111-1111-111111111111");
    private readonly Guid _tenantBId = Guid.Parse("22222222-2222-2222-2222-222222222222");

    // ── DoD-7a: Valid token with matching TenantId → group added ─────────────

    [Fact]
    [Trait("Req", "ARCH-09")]
    public async Task JoinGridGroup_MatchingTenantId_AddsToGroup()
    {
        // Arrange
        var hub = CreateHubWithTenant(_tenantAId);
        var groupManager = (IGroupManager)hub.Groups;

        // Act
        await hub.JoinGridGroup(_tenantAId, "dashboard-123");

        // Assert: Group should be added with tenant-prefixed name
        await groupManager.Received(1).AddToGroupAsync(
            Arg.Any<string>(),
            $"t:{_tenantAId}:dashboard-123",
            Arg.Any<CancellationToken>());
    }

    // ── DoD-7b: Token with mismatched TenantId → connection rejected ─────────

    [Fact]
    [Trait("Req", "ARCH-09")]
    public async Task JoinGridGroup_MismatchedTenantId_ThrowsHubException()
    {
        // Arrange: User authenticated as tenant A, tries to join tenant B group
        var hub = CreateHubWithTenant(_tenantAId);

        // Act & Assert
        var act = () => hub.JoinGridGroup(_tenantBId, "dashboard-456");

        await act.Should().ThrowAsync<HubException>()
            .WithMessage("*Tenant mismatch*");
    }

    // ── DoD-7c: Unauthenticated request → rejected ───────────────────────────

    [Fact]
    [Trait("Req", "ARCH-09")]
    public async Task JoinGridGroup_Unauthenticated_ThrowsHubException()
    {
        // Arrange: No tenant_id claim (unauthenticated or missing claim)
        var hub = CreateHubWithoutTenant();

        // Act & Assert
        var act = () => hub.JoinGridGroup(_tenantAId, "dashboard-789");

        await act.Should().ThrowAsync<HubException>()
            .WithMessage("*Unauthenticated*");
    }

    // ── Additional: LeaveGridGroup uses correct group naming ─────────────────

    [Fact]
    [Trait("Req", "ARCH-09")]
    public async Task LeaveGridGroup_UsesTenantPrefixedGroupName()
    {
        // Arrange
        var hub = CreateHubWithTenant(_tenantAId);
        var groupManager = (IGroupManager)hub.Groups;

        // Act
        await hub.LeaveGridGroup(_tenantAId, "dashboard-123");

        // Assert: Group name follows "t:{tenantId}:{groupName}" pattern
        await groupManager.Received(1).RemoveFromGroupAsync(
            Arg.Any<string>(),
            $"t:{_tenantAId}:dashboard-123",
            Arg.Any<CancellationToken>());
    }

    // ── Helper methods ───────────────────────────────────────────────────────

    private GridNotificationHub CreateHubWithTenant(Guid tenantId)
    {
        var hub = new GridNotificationHub();

        var claims = new List<Claim>
        {
            new("tenant_id", tenantId.ToString()),
            new(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString())
        };
        var identity = new ClaimsIdentity(claims, "TestAuth");
        var principal = new ClaimsPrincipal(identity);

        var context = Substitute.For<HubCallerContext>();
        context.User.Returns(principal);
        context.ConnectionId.Returns(Guid.NewGuid().ToString());

        var groups = Substitute.For<IGroupManager>();

        // Use reflection to set Hub properties (they're normally set by SignalR runtime)
        typeof(Hub).GetProperty("Context")!.SetValue(hub, context);
        typeof(Hub).GetProperty("Groups")!.SetValue(hub, groups);

        return hub;
    }

    private GridNotificationHub CreateHubWithoutTenant()
    {
        var hub = new GridNotificationHub();

        // Principal with no tenant_id claim
        var identity = new ClaimsIdentity(); // Unauthenticated
        var principal = new ClaimsPrincipal(identity);

        var context = Substitute.For<HubCallerContext>();
        context.User.Returns(principal);
        context.ConnectionId.Returns(Guid.NewGuid().ToString());

        var groups = Substitute.For<IGroupManager>();

        typeof(Hub).GetProperty("Context")!.SetValue(hub, context);
        typeof(Hub).GetProperty("Groups")!.SetValue(hub, groups);

        return hub;
    }
}
