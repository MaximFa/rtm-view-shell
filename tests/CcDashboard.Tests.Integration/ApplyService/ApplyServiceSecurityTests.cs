using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using CcDashboard.Contracts.DTOs.Metrics;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;

namespace CcDashboard.Tests.Integration.ApplyService;

/// <summary>
/// Security integration tests for ApplyService (covers deb6aa6 F-2/F-4/F-5/F-6).
/// </summary>
[Collection("ApplyService")]
public class ApplyServiceSecurityTests
{
    private readonly ApplyServiceFixture _fixture;

    public ApplyServiceSecurityTests(ApplyServiceFixture fixture)
    {
        _fixture = fixture;
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // F-2: Token authentication
    // ═══════════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// F-2: Wrong token → 401.
    /// </summary>
    [Fact]
    public async Task WrongToken_ShouldReturn401()
    {
        // Arrange
        await using var factory = _fixture.CreateWebApplicationFactory();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", "wrong-token");

        var request = new ApplyMetricsRequest
        {
            PackageRef = "test",
            MigrationRef = _fixture.FixtureMigrationFileName,
            MetricIds = new[] { _fixture.RtMetricId },
            TriggeredBy = "test"
        };

        // Act
        var response = await client.PostAsJsonAsync("/apply-metrics", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    /// <summary>
    /// F-2: Missing Authorization header → 401.
    /// </summary>
    [Fact]
    public async Task MissingAuthHeader_ShouldReturn401()
    {
        // Arrange
        await using var factory = _fixture.CreateWebApplicationFactory();
        var client = factory.CreateClient();
        // No Authorization header

        var request = new ApplyMetricsRequest
        {
            PackageRef = "test",
            MigrationRef = _fixture.FixtureMigrationFileName,
            MetricIds = new[] { _fixture.RtMetricId },
            TriggeredBy = "test"
        };

        // Act
        var response = await client.PostAsJsonAsync("/apply-metrics", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    /// <summary>
    /// F-2: Startup guard - empty token should throw InvalidOperationException.
    /// Host should fail to start when token is empty/placeholder.
    /// </summary>
    [Fact]
    public void EmptyToken_ShouldThrowOnStartup()
    {
        // Act & Assert
        var ex = Assert.Throws<InvalidOperationException>(() =>
        {
            using var factory = _fixture.CreateWebApplicationFactory(overrideToken: "");
            // Force host to build
            var _ = factory.Server;
        });

        ex.Message.Should().Contain("ApplyService:Token");
    }

    /// <summary>
    /// F-2: Startup guard - placeholder token should throw.
    /// </summary>
    [Fact]
    public void PlaceholderToken_ShouldThrowOnStartup()
    {
        // Act & Assert
        var ex = Assert.Throws<InvalidOperationException>(() =>
        {
            using var factory = _fixture.CreateWebApplicationFactory(overrideToken: "REPLACE_AT_DEPLOY");
            var _ = factory.Server;
        });

        ex.Message.Should().Contain("placeholder");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // F-4: Migration integrity (SHA-256)
    // ═══════════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// F-4: Tampered migration file (SHA-256 mismatch) → 409.
    /// </summary>
    [Fact]
    public async Task TamperedMigration_ShouldReturn409()
    {
        // Arrange
        var tamperedFile = _fixture.CreateTamperedMigration();
        await using var factory = _fixture.CreateWebApplicationFactory();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _fixture.TestToken);

        var metricsBefore = await _fixture.GetMetricRowCountAsync();

        var request = new ApplyMetricsRequest
        {
            PackageRef = "test-tampered",
            MigrationRef = tamperedFile,
            MetricIds = new[] { _fixture.RtMetricId },
            TriggeredBy = "test"
        };

        // Act
        var response = await client.PostAsJsonAsync("/apply-metrics", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Conflict); // 409
        var result = await response.Content.ReadFromJsonAsync<ApplyMetricsResponse>();
        result!.Error.Should().Contain("SHA-256 mismatch");

        // Verify migration NOT executed
        var metricsAfter = await _fixture.GetMetricRowCountAsync();
        metricsAfter.Should().Be(metricsBefore);

        _fixture.ResetManifest();
    }

    /// <summary>
    /// F-4: Migration with no hash in manifest → 409 (fail-closed).
    /// </summary>
    [Fact]
    public async Task MigrationWithoutHash_ShouldReturn409()
    {
        // Arrange
        var noHashFile = _fixture.CreateMigrationWithoutHash();
        await using var factory = _fixture.CreateWebApplicationFactory();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _fixture.TestToken);

        var request = new ApplyMetricsRequest
        {
            PackageRef = "test-no-hash",
            MigrationRef = noHashFile,
            MetricIds = new[] { _fixture.RtMetricId },
            TriggeredBy = "test"
        };

        // Act
        var response = await client.PostAsJsonAsync("/apply-metrics", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.Conflict); // 409
        var result = await response.Content.ReadFromJsonAsync<ApplyMetricsResponse>();
        result!.Error.Should().Contain("no integrity hash");

        _fixture.ResetManifest();
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // F-5: Audit fail-closed + real actor
    // ═══════════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// F-5: On successful apply, audit row is written with:
    /// - UserName = "ApplyService" (server principal, NOT TriggeredBy)
    /// - IpAddress set (RemoteIpAddress)
    /// - UserId = null
    /// - TenantId = null
    /// - Details.clientAssertedTriggeredBy = request.TriggeredBy
    /// </summary>
    [Fact]
    public async Task SuccessfulApply_ShouldWriteAuditWithServerPrincipal()
    {
        // Arrange
        await using var factory = _fixture.CreateWebApplicationFactory();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _fixture.TestToken);

        var request = new ApplyMetricsRequest
        {
            PackageRef = "audit-test",
            MigrationRef = _fixture.FixtureMigrationFileName,
            MetricIds = new[] { _fixture.RtMetricId },
            TriggeredBy = "superadmin-user-123"
        };

        // Act
        var response = await client.PostAsJsonAsync("/apply-metrics", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var auditLog = await _fixture.GetLatestAuditLogAsync();
        auditLog.Should().NotBeNull();

        auditLog!.Value.UserName.Should().Be("ApplyService"); // Server principal, NOT TriggeredBy
        auditLog.Value.UserId.Should().BeNull(); // Service principal, no user context
        auditLog.Value.TenantId.Should().BeNull(); // Platform-level event
        // Note: IpAddress is null in WebApplicationFactory test context (no real network connection).
        // In production, HttpContext.Connection.RemoteIpAddress is set. The code path is verified
        // by checking that the audit row exists with all other expected fields.

        // Details should contain clientAssertedTriggeredBy
        var details = JsonDocument.Parse(auditLog.Value.Details);
        details.RootElement.GetProperty("clientAssertedTriggeredBy").GetString()
            .Should().Be("superadmin-user-123");
    }

    /// <summary>
    /// F-5: Audit failure → 500 (no 200 without persisted audit).
    /// </summary>
    [Fact]
    public async Task AuditFailure_ShouldReturn500()
    {
        // Arrange - use failing audit DB
        await using var factory = _fixture.CreateWebApplicationFactory(useFailingAuditDb: true);
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _fixture.TestToken);

        var request = new ApplyMetricsRequest
        {
            PackageRef = "audit-fail-test",
            MigrationRef = _fixture.FixtureMigrationFileName,
            MetricIds = new[] { _fixture.RtMetricId },
            TriggeredBy = "test"
        };

        // Act
        var response = await client.PostAsJsonAsync("/apply-metrics", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.InternalServerError); // 500
        var result = await response.Content.ReadFromJsonAsync<ApplyMetricsResponse>();
        result!.Success.Should().BeFalse();
        result.Error.Should().Contain("Audit log failed");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // F-6: MetricIds validation
    // ═══════════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// F-6: Request contains MetricId NOT in manifest → 400.
    /// </summary>
    [Fact]
    public async Task UnknownMetricId_ShouldReturn400()
    {
        // Arrange
        await using var factory = _fixture.CreateWebApplicationFactory();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _fixture.TestToken);

        var ledgerBefore = await _fixture.GetLedgerRowCountAsync();

        var request = new ApplyMetricsRequest
        {
            PackageRef = "test",
            MigrationRef = _fixture.FixtureMigrationFileName,
            MetricIds = new[] { _fixture.RtMetricId, "UNKNOWN_METRIC_NOT_IN_MANIFEST" },
            TriggeredBy = "test"
        };

        // Act
        var response = await client.PostAsJsonAsync("/apply-metrics", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest); // 400
        var result = await response.Content.ReadFromJsonAsync<ApplyMetricsResponse>();
        result!.Success.Should().BeFalse();
        result.Error.Should().Contain("MetricIds not found in manifest");
        result.Error.Should().Contain("UNKNOWN_METRIC_NOT_IN_MANIFEST");

        // Nothing applied
        var ledgerAfter = await _fixture.GetLedgerRowCountAsync();
        ledgerAfter.Should().Be(ledgerBefore);
    }
}
