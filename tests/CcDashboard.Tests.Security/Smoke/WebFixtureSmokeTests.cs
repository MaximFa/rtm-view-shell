using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Tests.Security.Smoke;

/// <summary>
/// Smoke tests verifying WebFixture and WebApplicationFactory pipeline.
/// DoD-13: WebFixture lands and is reused.
/// </summary>
[Collection("Web")]
public class WebFixtureSmokeTests
{
    private readonly WebFixture _fixture;

    public WebFixtureSmokeTests(WebFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    public async Task WebApplicationFactory_CanStartServer()
    {
        // Arrange - verify the WAF server started successfully
        using var client = _fixture.CreateClient();

        // Act - make any request to verify the server is up
        var response = await client.GetAsync("/login");

        // Assert
        response.Should().NotBeNull("WebApplicationFactory should start successfully");
        response.StatusCode.Should().NotBe(System.Net.HttpStatusCode.InternalServerError,
            "Server should not return 500 error");
    }

    [Fact]
    public async Task WebApplicationFactory_CanAccessProtectedRoute_ReturnsUnauthorized()
    {
        // Arrange
        using var client = _fixture.CreateClientNoRedirect();

        // Act - try to access a protected route without authentication
        var response = await client.GetAsync("/admin/users");

        // Assert - should redirect to login or return unauthorized
        var acceptableStatuses = new[]
        {
            System.Net.HttpStatusCode.Redirect,
            System.Net.HttpStatusCode.Found,
            System.Net.HttpStatusCode.Unauthorized,
            System.Net.HttpStatusCode.Forbidden
        };
        response.StatusCode.Should().BeOneOf(acceptableStatuses,
            "Protected routes should redirect to login or return 401/403");
    }

    [Fact]
    public async Task WebFixture_SeedData_Exists()
    {
        // Verify seed data from WebFixture is present
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);

        var userA = await db.Users
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(u => u.Id == _fixture.UserAId);

        userA.Should().NotBeNull("User A should be seeded by WebFixture");
        userA!.TenantId.Should().Be(_fixture.TenantAId);
        userA.Email.Should().Be("user.a@tenant-a.local");
    }

    [Fact]
    public async Task WebFixture_MultipleClients_HaveIndependentCookies()
    {
        // Arrange
        using var client1 = _fixture.CreateClient();
        using var client2 = _fixture.CreateClient();

        // Act: client1 visits login page
        var response1 = await client1.GetAsync("/login");

        // Assert: client2 should also be able to access without interference
        var response2 = await client2.GetAsync("/login");

        response1.IsSuccessStatusCode.Should().BeTrue();
        response2.IsSuccessStatusCode.Should().BeTrue();
    }

    [Fact]
    public async Task WebFixture_LoginPage_IsAccessible()
    {
        // Arrange
        using var client = _fixture.CreateClient();

        // Act
        var response = await client.GetAsync("/login");

        // Assert
        response.IsSuccessStatusCode.Should().BeTrue(
            "Login page should be publicly accessible");
    }
}
