using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Tests.Security.Identity;

/// <summary>
/// Golden-path login tests via WebApplicationFactory.
/// These tests exercise the full ASP.NET Core auth pipeline including cookie authentication.
/// Phase C: Unblocks skipped tests from Phase A and Phase B.
/// </summary>
[Collection("Web")]
public class GoldenPathLoginTests : IAsyncLifetime
{
    private readonly WebFixture _fixture;

    public GoldenPathLoginTests(WebFixture fixture)
    {
        _fixture = fixture;
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public async Task DisposeAsync()
    {
        // Cleanup: reset MaxConcurrentConnections to unlimited (0) after each test
        await _fixture.SetMaxConcurrentConnectionsAsync(_fixture.TenantAId, 0);
        await _fixture.ClearUserSessionsAsync(_fixture.UserAId);
    }

    /// <summary>
    /// Resets session state for LICENSE-SESSION tests to ensure isolation.
    /// </summary>
    private async Task ResetSessionStateAsync()
    {
        await _fixture.ClearUserSessionsAsync(_fixture.UserAId);
        // Reset to unlimited - specific tests will set their own limit
        await _fixture.SetMaxConcurrentConnectionsAsync(_fixture.TenantAId, 0);
    }

    #region Phase A Inherited Tests — TenantMismatch Positive Path (ARCH-04)

    /// <summary>
    /// Previously skipped in TenantMismatchLoginTests — now using WebFixture.
    /// Verifies that a user can successfully log in when their tenant matches the subdomain.
    /// </summary>
    [Fact]
    [Trait("Req", "ARCH-04")]
    public async Task PasswordSignInAsync_CorrectTenant_ReturnsSuccess()
    {
        // Arrange: User A belongs to Tenant A; we're logging into Tenant A
        using var result = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "Test@123456",
            "tenant-a");

        // Assert: Login should succeed with redirect to /screens or /change-password
        result.IsSuccessRedirect.Should().BeTrue(
            "User logging into their own tenant should succeed [ARCH-04]");
    }

    /// <summary>
    /// Contrast test: verifies that tenant mismatch still fails.
    /// </summary>
    [Fact]
    [Trait("Req", "ARCH-04")]
    [Trait("Req", "BFP-03")]
    public async Task PasswordSignInAsync_WrongTenant_DoesNotRedirectToScreens()
    {
        // Arrange: User A belongs to Tenant A; we're logging into Tenant B
        using var result = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "Test@123456",
            "tenant-b");

        // Assert: Should NOT redirect to success pages
        result.IsSuccessRedirect.Should().BeFalse(
            "User logging into wrong tenant should not succeed [ARCH-04, BFP-03]");
    }

    #endregion

    #region Phase A Inherited Tests — SuspendedAndDeleted Positive Path (ARCH-06)

    /// <summary>
    /// Previously skipped in SuspendedAndDeletedTenantTests — now using WebFixture.
    /// Verifies that a user can successfully log in to an Active tenant.
    /// </summary>
    [Fact]
    [Trait("Req", "ARCH-06")]
    public async Task PasswordSignInAsync_ActiveTenant_SucceedsWithCorrectCredentials()
    {
        // Arrange: Tenant A is Active (seeded by WebFixture)
        using var result = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "Test@123456",
            "tenant-a");

        // Assert: Login to active tenant should succeed
        result.IsSuccessRedirect.Should().BeTrue(
            "Login to active tenant with correct credentials should succeed [ARCH-06]");
    }

    /// <summary>
    /// Previously skipped in SuspendedAndDeletedTenantTests — now using WebFixture.
    /// Tests that transitioning tenant status affects login behavior.
    /// </summary>
    [Fact]
    [Trait("Req", "ARCH-06")]
    public async Task TenantStatus_Transition_AffectsLoginBehavior()
    {
        // Arrange: First verify login works for active tenant
        using var result1 = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "Test@123456",
            "tenant-a");
        result1.IsSuccessRedirect.Should().BeTrue("Login should succeed when tenant is active");

        // Act: Suspend the tenant
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);
        var tenant = await db.Tenants.IgnoreQueryFilters()
            .FirstAsync(t => t.Id == _fixture.TenantAId);
        tenant.Status = Domain.Enums.TenantStatus.Suspended;
        await db.SaveChangesAsync();

        try
        {
            // Assert: Login should now fail
            using var result2 = await _fixture.LoginAsync(
                "user.a@tenant-a.local",
                "Test@123456",
                "tenant-a");
            result2.IsSuccessRedirect.Should().BeFalse(
                "Login should fail after tenant is suspended [ARCH-06]");
        }
        finally
        {
            // Cleanup: Restore tenant status for other tests
            tenant.Status = Domain.Enums.TenantStatus.Active;
            await db.SaveChangesAsync();
        }
    }

    #endregion

    #region AUTH-WEB-02 — Claims Materialization

    /// <summary>
    /// DoD-16: Verifies that successful login materializes correct claims.
    /// </summary>
    [Fact]
    [Trait("Req", "AUTH-WEB-02")]
    public async Task CompleteSignInAsync_ValidUser_MaterialisesClaimsCorrectly()
    {
        // Arrange & Act: Login as User A
        using var loginResult = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "Test@123456",
            "tenant-a");

        loginResult.IsSuccessRedirect.Should().BeTrue("Login should succeed");

        // Follow the redirect to establish the authenticated session
        if (loginResult.Response.Headers.Location != null)
        {
            var redirectUrl = loginResult.Response.Headers.Location.ToString();
            var afterLoginResponse = await loginResult.Client.GetAsync(redirectUrl);

            // Verify we can access the authenticated page
            afterLoginResponse.StatusCode.Should().NotBe(System.Net.HttpStatusCode.Unauthorized,
                "After login, user should be able to access protected pages");
        }

        // Verify claims in database session
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);
        var session = await db.UserSessions
            .IgnoreQueryFilters()
            .Where(s => s.UserId == _fixture.UserAId)
            .OrderByDescending(s => s.CreatedAt)
            .FirstOrDefaultAsync();

        session.Should().NotBeNull("A session should be created on successful login");
        session!.TenantId.Should().Be(_fixture.TenantAId, "Session TenantId should match user's tenant [AUTH-WEB-02]");
        session.UserId.Should().Be(_fixture.UserAId, "Session UserId should match logged-in user [AUTH-WEB-02]");
    }

    #endregion

    #region Utility Tests

    [Fact]
    public async Task Login_DiagnosticTest()
    {
        // Smoke test verifying the full login flow works
        using var result = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "Test@123456",
            "tenant-a");

        // Verify we got a redirect to screens
        var acceptableStatuses = new[]
        {
            System.Net.HttpStatusCode.Found,
            System.Net.HttpStatusCode.Redirect
        };
        result.Response.StatusCode.Should().BeOneOf(acceptableStatuses,
            "Login should redirect on success");

        result.IsSuccessRedirect.Should().BeTrue(
            "Valid credentials should redirect to /screens");
    }

    [Fact]
    public async Task Login_WithWrongPassword_DoesNotRedirect()
    {
        using var result = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "WrongPassword123!",
            "tenant-a");

        result.IsSuccessRedirect.Should().BeFalse(
            "Login with wrong password should not succeed");
    }

    [Fact]
    public async Task Login_NonExistentUser_DoesNotRedirect()
    {
        using var result = await _fixture.LoginAsync(
            "nonexistent@tenant-a.local",
            "AnyPassword123!",
            "tenant-a");

        result.IsSuccessRedirect.Should().BeFalse(
            "Login with non-existent user should not succeed");
    }

    #endregion

    #region Phase B Inherited Tests — LICENSE-SESSION (AUTH-WEB-04)

    /// <summary>
    /// Previously skipped in LicenseSessionTests — now using WebFixture.
    /// When MaxConcurrentConnections = 0, no limit is enforced.
    /// </summary>
    [Fact]
    [Trait("Req", "AUTH-WEB-04")]
    public async Task PasswordSignInAsync_NoLimit_AllowsMultipleConnections()
    {
        // Arrange - MaxConcurrentConnections = 0 means unlimited
        await ResetSessionStateAsync();
        await _fixture.SetMaxConcurrentConnectionsAsync(_fixture.TenantAId, 0);

        // Act - login from 3 different IPs
        for (int i = 1; i <= 3; i++)
        {
            using var result = await _fixture.LoginAsync(
                "user.a@tenant-a.local",
                "Test@123456",
                "tenant-a",
                $"192.168.100.{i}");

            // Assert
            result.IsSessionLimitExceeded.Should().BeFalse(
                $"Connection {i} should succeed when MaxConcurrentConnections = 0 [AUTH-WEB-04]");
            result.IsSuccessRedirect.Should().BeTrue(
                $"Login {i} should redirect to /screens when no limit [AUTH-WEB-04]");
        }
    }

    /// <summary>
    /// Previously skipped in LicenseSessionTests — now using WebFixture.
    /// Login from within the concurrent connection limit should succeed.
    /// </summary>
    [Fact]
    [Trait("Req", "AUTH-WEB-04")]
    public async Task PasswordSignInAsync_WithinLimit_AllowsLogin()
    {
        // Arrange - limit to 3 concurrent connections
        await ResetSessionStateAsync();
        await _fixture.SetMaxConcurrentConnectionsAsync(_fixture.TenantAId, 3);

        // Create 2 existing sessions from different IPs
        await _fixture.CreateUserSessionAsync(_fixture.UserAId, _fixture.TenantAId, "192.168.200.1");
        await _fixture.CreateUserSessionAsync(_fixture.UserAId, _fixture.TenantAId, "192.168.200.2");

        // Act - third IP (within limit)
        using var result = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "Test@123456",
            "tenant-a",
            "192.168.200.3");

        // Assert - should succeed (3rd connection, limit is 3)
        result.IsSessionLimitExceeded.Should().BeFalse(
            "Login from 3rd IP should succeed when limit is 3 [AUTH-WEB-04]");
        result.IsSuccessRedirect.Should().BeTrue(
            "Login within limit should redirect to /screens [AUTH-WEB-04]");
    }

    /// <summary>
    /// Previously skipped in LicenseSessionTests — now using WebFixture.
    /// Same IP should not count against the limit (unlimited from same IP).
    /// </summary>
    [Fact]
    [Trait("Req", "AUTH-WEB-04")]
    public async Task PasswordSignInAsync_SameIp_AllowsUnlimitedConnections()
    {
        // Arrange - limit to 1 concurrent connection
        await ResetSessionStateAsync();
        await _fixture.SetMaxConcurrentConnectionsAsync(_fixture.TenantAId, 1);

        // Create existing session from same IP that will be used
        await _fixture.CreateUserSessionAsync(_fixture.UserAId, _fixture.TenantAId, "192.168.202.1");

        // Act - same IP (should allow unlimited from same IP)
        using var result = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "Test@123456",
            "tenant-a",
            "192.168.202.1");

        // Assert
        result.IsSessionLimitExceeded.Should().BeFalse(
            "Multiple connections from same IP should always be allowed [AUTH-WEB-04]");
    }

    /// <summary>
    /// Previously skipped in LicenseSessionTests — now using WebFixture.
    /// Expired sessions should not count toward the limit.
    /// </summary>
    [Fact]
    [Trait("Req", "AUTH-WEB-04")]
    public async Task PasswordSignInAsync_ExpiredSession_NotCounted()
    {
        // Arrange - limit to 1 concurrent connection
        await ResetSessionStateAsync();
        await _fixture.SetMaxConcurrentConnectionsAsync(_fixture.TenantAId, 1);

        // Create expired session (should not count toward limit)
        await _fixture.CreateUserSessionAsync(_fixture.UserAId, _fixture.TenantAId, "192.168.203.1", expired: true);

        // Act - new IP (should succeed since expired session doesn't count)
        using var result = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "Test@123456",
            "tenant-a",
            "192.168.203.2");

        // Assert
        result.IsSessionLimitExceeded.Should().BeFalse(
            "Expired sessions should not count toward limit [AUTH-WEB-04]");
    }

    /// <summary>
    /// Previously skipped in LicenseSessionTests — now using WebFixture.
    /// Revoked sessions should not count toward the limit.
    /// </summary>
    [Fact]
    [Trait("Req", "AUTH-WEB-04")]
    public async Task PasswordSignInAsync_RevokedSession_NotCounted()
    {
        // Arrange - limit to 1 concurrent connection
        await ResetSessionStateAsync();
        await _fixture.SetMaxConcurrentConnectionsAsync(_fixture.TenantAId, 1);

        // Create revoked session (should not count toward limit)
        await _fixture.CreateUserSessionAsync(_fixture.UserAId, _fixture.TenantAId, "192.168.204.1", revoked: true);

        // Act - new IP (should succeed since revoked session doesn't count)
        using var result = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "Test@123456",
            "tenant-a",
            "192.168.204.2");

        // Assert
        result.IsSessionLimitExceeded.Should().BeFalse(
            "Revoked sessions should not count toward limit [AUTH-WEB-04]");
    }

    #endregion
}
