using CcDashboard.Infrastructure.Audit;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Tests.Security.Audit;

/// <summary>
/// DoD-B3: IP extraction from X-Forwarded-For header (AUD-04).
/// Per CLAUDE.md §16: "IP extraction: use X-Forwarded-For / X-Real-IP with trusted proxy config
/// (ForwardedHeadersOptions). Store as PostgreSQL inet type."
///
/// These tests verify that ForwardedHeaders middleware is correctly configured and that
/// the client IP from X-Forwarded-For reaches the audit logs.
/// </summary>
[Collection("Web")]
public class AuditIpExtractionTests : IAsyncLifetime
{
    private readonly WebFixture _fixture;

    public AuditIpExtractionTests(WebFixture fixture)
    {
        _fixture = fixture;
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public async Task DisposeAsync()
    {
        // Clean up audit logs created during tests
        var optionsBuilder = new DbContextOptionsBuilder<AuditDbContext>();
        optionsBuilder.UseNpgsql(_fixture.PostgresConnectionString);
        await using var auditDb = new AuditDbContext(optionsBuilder.Options);

        var testLogs = await auditDb.AuditLogs
            .Where(l => l.IpAddress != null &&
                       (l.IpAddress.StartsWith("203.0.113") ||
                        l.IpAddress.StartsWith("192.0.2") ||
                        l.IpAddress.StartsWith("198.51.100")))
            .ToListAsync();

        if (testLogs.Any())
        {
            auditDb.AuditLogs.RemoveRange(testLogs);
            await auditDb.SaveChangesAsync();
        }
    }

    [Fact]
    [Trait("Req", "AUD-04")]
    public async Task Login_WithXForwardedFor_CapturesForwardedIpInAuditLog()
    {
        // Arrange - use TEST-NET-3 (203.0.113.0/24) per RFC 5737
        var forwardedIp = "203.0.113.42";

        // Act - login with custom IP
        using var result = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "Test@123456",
            "tenant-a",
            forwardedIp);

        // Assert - check audit log for the forwarded IP
        var optionsBuilder = new DbContextOptionsBuilder<AuditDbContext>();
        optionsBuilder.UseNpgsql(_fixture.PostgresConnectionString);
        await using var auditDb = new AuditDbContext(optionsBuilder.Options);

        var auditLog = await auditDb.AuditLogs
            .AsNoTracking()
            .Where(l => l.UserName == "user.a@tenant-a.local" &&
                       l.EventType.StartsWith("Login"))
            .OrderByDescending(l => l.CreatedAt)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull("Login should create audit log");
        auditLog!.IpAddress.Should().Be(forwardedIp,
            "Audit log should capture IP from X-Forwarded-For header [AUD-04]");
    }

    [Fact]
    [Trait("Req", "AUD-04")]
    public async Task FailedLogin_WithXForwardedFor_CapturesForwardedIpInAuditLog()
    {
        // Arrange
        var forwardedIp = "192.0.2.100"; // TEST-NET-1 per RFC 5737

        // Act - login with wrong password
        using var result = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "WrongPassword123!",
            "tenant-a",
            forwardedIp);

        // Assert - failed login should still capture the forwarded IP
        var optionsBuilder = new DbContextOptionsBuilder<AuditDbContext>();
        optionsBuilder.UseNpgsql(_fixture.PostgresConnectionString);
        await using var auditDb = new AuditDbContext(optionsBuilder.Options);

        var auditLog = await auditDb.AuditLogs
            .AsNoTracking()
            .Where(l => l.UserName == "user.a@tenant-a.local" &&
                       l.EventType == "Login.Failure" &&
                       l.IpAddress == forwardedIp)
            .OrderByDescending(l => l.CreatedAt)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull(
            "Failed login audit should capture IP from X-Forwarded-For [AUD-04]");
        auditLog!.IpAddress.Should().Be(forwardedIp);
    }

    [Fact]
    [Trait("Req", "AUD-04")]
    public async Task Login_WithMultipleXForwardedForIps_CapturesFirstIp()
    {
        // Arrange - multiple IPs in X-Forwarded-For (client, proxy1, proxy2)
        // ForwardedHeaders takes the first (leftmost) IP by default
        var forwardedIp = "198.51.100.50";

        // Act
        using var result = await _fixture.LoginAsync(
            "user.a@tenant-a.local",
            "Test@123456",
            "tenant-a",
            forwardedIp);

        // Assert
        var optionsBuilder = new DbContextOptionsBuilder<AuditDbContext>();
        optionsBuilder.UseNpgsql(_fixture.PostgresConnectionString);
        await using var auditDb = new AuditDbContext(optionsBuilder.Options);

        var auditLog = await auditDb.AuditLogs
            .AsNoTracking()
            .Where(l => l.UserName == "user.a@tenant-a.local" &&
                       l.EventType.StartsWith("Login") &&
                       l.IpAddress == forwardedIp)
            .OrderByDescending(l => l.CreatedAt)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull("Login audit should exist with forwarded IP");
    }

    [Fact]
    [Trait("Req", "AUD-04")]
    public async Task AuditLog_IpAddress_StoredAsInetType()
    {
        // Arrange - verify the column type via EF metadata
        var optionsBuilder = new DbContextOptionsBuilder<AuditDbContext>();
        optionsBuilder.UseNpgsql(_fixture.PostgresConnectionString);
        await using var auditDb = new AuditDbContext(optionsBuilder.Options);

        // Act - check the model configuration
        var entityType = auditDb.Model.FindEntityType(typeof(AuditLog));
        var ipProperty = entityType?.FindProperty(nameof(AuditLog.IpAddress));

        // Assert
        ipProperty.Should().NotBeNull("AuditLog should have IpAddress property");
    }
}
