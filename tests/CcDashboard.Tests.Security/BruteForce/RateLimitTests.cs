using CcDashboard.Web.Middleware;
using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Moq;

namespace CcDashboard.Tests.Security.BruteForce;

/// <summary>
/// Tests for login rate limiting per BFP-02.
/// Max 10 requests per minute per IP to login endpoints.
/// </summary>
public class RateLimitTests
{
    private readonly Mock<ILogger<LoginRateLimitMiddleware>> _loggerMock = new();

    [Fact]
    [Trait("Req", "BFP-02")]
    public async Task InvokeAsync_FirstRequest_PassesThrough()
    {
        // Arrange
        var nextCalled = false;
        RequestDelegate next = _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        };
        var sut = new LoginRateLimitMiddleware(next, _loggerMock.Object);
        var ctx = CreateHttpContext("/login", "POST", "192.168.1.100");

        // Act
        await sut.InvokeAsync(ctx);

        // Assert
        nextCalled.Should().BeTrue("First request should pass through");
        ctx.Response.StatusCode.Should().NotBe(429);
    }

    [Fact]
    [Trait("Req", "BFP-02")]
    public async Task InvokeAsync_TenRequests_AllPassThrough()
    {
        // Arrange
        var callCount = 0;
        RequestDelegate next = _ =>
        {
            callCount++;
            return Task.CompletedTask;
        };
        var sut = new LoginRateLimitMiddleware(next, _loggerMock.Object);
        var uniqueIp = $"192.168.10.{Random.Shared.Next(1, 254)}";

        // Act - 10 requests from same IP
        for (int i = 0; i < 10; i++)
        {
            var ctx = CreateHttpContext("/login", "POST", uniqueIp);
            await sut.InvokeAsync(ctx);
        }

        // Assert
        callCount.Should().Be(10, "First 10 requests should all pass through [BFP-02]");
    }

    [Fact]
    [Trait("Req", "BFP-02")]
    public async Task InvokeAsync_EleventhRequest_Returns429()
    {
        // Arrange
        RequestDelegate next = _ => Task.CompletedTask;
        var sut = new LoginRateLimitMiddleware(next, _loggerMock.Object);
        var uniqueIp = $"192.168.11.{Random.Shared.Next(1, 254)}";

        // Act - 11 requests from same IP
        HttpContext? lastCtx = null;
        for (int i = 0; i < 11; i++)
        {
            lastCtx = CreateHttpContext("/login", "POST", uniqueIp);
            await sut.InvokeAsync(lastCtx);
        }

        // Assert
        lastCtx!.Response.StatusCode.Should().Be(429, "11th request should be rate limited [BFP-02]");
    }

    [Fact]
    [Trait("Req", "BFP-02")]
    public async Task InvokeAsync_DifferentIps_NotAffected()
    {
        // Arrange
        var callCount = 0;
        RequestDelegate next = _ =>
        {
            callCount++;
            return Task.CompletedTask;
        };
        var sut = new LoginRateLimitMiddleware(next, _loggerMock.Object);

        // Act - 5 requests each from 3 different IPs
        for (int ip = 1; ip <= 3; ip++)
        {
            var ipAddress = $"192.168.20.{ip}";
            for (int i = 0; i < 5; i++)
            {
                var ctx = CreateHttpContext("/login", "POST", ipAddress);
                await sut.InvokeAsync(ctx);
            }
        }

        // Assert
        callCount.Should().Be(15, "Different IPs should have independent rate limits");
    }

    [Fact]
    [Trait("Req", "BFP-02")]
    public async Task InvokeAsync_GetRequest_NotRateLimited()
    {
        // Arrange
        var callCount = 0;
        RequestDelegate next = _ =>
        {
            callCount++;
            return Task.CompletedTask;
        };
        var sut = new LoginRateLimitMiddleware(next, _loggerMock.Object);
        var uniqueIp = $"192.168.30.{Random.Shared.Next(1, 254)}";

        // Act - 15 GET requests
        for (int i = 0; i < 15; i++)
        {
            var ctx = CreateHttpContext("/login", "GET", uniqueIp);
            await sut.InvokeAsync(ctx);
        }

        // Assert
        callCount.Should().Be(15, "GET requests should not be rate limited");
    }

    [Fact]
    [Trait("Req", "BFP-02")]
    public async Task InvokeAsync_NonLoginPath_NotRateLimited()
    {
        // Arrange
        var callCount = 0;
        RequestDelegate next = _ =>
        {
            callCount++;
            return Task.CompletedTask;
        };
        var sut = new LoginRateLimitMiddleware(next, _loggerMock.Object);
        var uniqueIp = $"192.168.40.{Random.Shared.Next(1, 254)}";

        // Act - 15 POST requests to non-login path
        for (int i = 0; i < 15; i++)
        {
            var ctx = CreateHttpContext("/api/users", "POST", uniqueIp);
            await sut.InvokeAsync(ctx);
        }

        // Assert
        callCount.Should().Be(15, "Non-login paths should not be rate limited");
    }

    [Fact]
    [Trait("Req", "BFP-02")]
    public async Task InvokeAsync_TwoFactorEndpoint_IsRateLimited()
    {
        // Arrange
        RequestDelegate next = _ => Task.CompletedTask;
        var sut = new LoginRateLimitMiddleware(next, _loggerMock.Object);
        var uniqueIp = $"192.168.50.{Random.Shared.Next(1, 254)}";

        // Act - 11 requests to 2FA endpoint
        HttpContext? lastCtx = null;
        for (int i = 0; i < 11; i++)
        {
            lastCtx = CreateHttpContext("/login/2fa", "POST", uniqueIp);
            await sut.InvokeAsync(lastCtx);
        }

        // Assert
        lastCtx!.Response.StatusCode.Should().Be(429, "2FA endpoint should also be rate limited [BFP-02]");
    }

    [Fact]
    [Trait("Req", "BFP-02")]
    public async Task InvokeAsync_ApiLoginEndpoint_IsRateLimited()
    {
        // Arrange
        RequestDelegate next = _ => Task.CompletedTask;
        var sut = new LoginRateLimitMiddleware(next, _loggerMock.Object);
        var uniqueIp = $"192.168.60.{Random.Shared.Next(1, 254)}";

        // Act - 11 requests to API login endpoint
        HttpContext? lastCtx = null;
        for (int i = 0; i < 11; i++)
        {
            lastCtx = CreateHttpContext("/api/auth/login", "POST", uniqueIp);
            await sut.InvokeAsync(lastCtx);
        }

        // Assert
        lastCtx!.Response.StatusCode.Should().Be(429, "API login endpoint should be rate limited [BFP-02]");
    }

    #region Helpers

    private static HttpContext CreateHttpContext(string path, string method, string remoteIp)
    {
        var ctx = new DefaultHttpContext();
        ctx.Request.Path = path;
        ctx.Request.Method = method;
        ctx.Connection.RemoteIpAddress = System.Net.IPAddress.Parse(remoteIp);
        ctx.Response.Body = new MemoryStream();
        return ctx;
    }

    #endregion
}
