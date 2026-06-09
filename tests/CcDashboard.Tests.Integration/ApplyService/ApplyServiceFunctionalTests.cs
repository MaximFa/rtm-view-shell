using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using CcDashboard.Contracts.DTOs.Metrics;
using FluentAssertions;

namespace CcDashboard.Tests.Integration.ApplyService;

/// <summary>
/// Functional integration tests for ApplyService.
/// Tests: idempotent apply, RT-only appliedRtMetricIds, bad migration rollback.
/// </summary>
[Collection("ApplyService")]
public class ApplyServiceFunctionalTests
{
    private readonly ApplyServiceFixture _fixture;

    public ApplyServiceFunctionalTests(ApplyServiceFixture fixture)
    {
        _fixture = fixture;
    }

    /// <summary>
    /// Scenario 1: apply-twice idempotent.
    /// 1st apply → success, ledgerRows populated, RTSGrid_Metric rows inserted.
    /// 2nd apply (same migrationRef) → success, ledgerRows EMPTY + warning, RTSGrid_Metric unchanged.
    /// </summary>
    [Fact]
    public async Task ApplyTwice_ShouldBeIdempotent()
    {
        // Arrange
        await using var factory = _fixture.CreateWebApplicationFactory();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _fixture.TestToken);

        var request = new ApplyMetricsRequest
        {
            PackageRef = "test-commit-1",
            MigrationRef = _fixture.FixtureMigrationFileName,
            MetricIds = new[] { _fixture.RtMetricId, _fixture.HistoryMetricId },
            TriggeredBy = "test-user"
        };

        var metricsBefore = await _fixture.GetMetricRowCountAsync();

        // Act 1: First apply
        var response1 = await client.PostAsJsonAsync("/apply-metrics", request);

        // Assert 1
        response1.StatusCode.Should().Be(HttpStatusCode.OK);
        var result1 = await response1.Content.ReadFromJsonAsync<ApplyMetricsResponse>();
        result1.Should().NotBeNull();
        result1!.Success.Should().BeTrue();
        result1.LedgerRows.Should().HaveCount(2); // Both metrics inserted
        result1.AppliedRtMetricIds.Should().ContainSingle(_fixture.RtMetricId); // Only RT

        var metricsAfter1 = await _fixture.GetMetricRowCountAsync();
        metricsAfter1.Should().Be(metricsBefore + 2); // 2 new metrics

        // Act 2: Second apply (same migrationRef)
        var response2 = await client.PostAsJsonAsync("/apply-metrics", request);

        // Assert 2
        response2.StatusCode.Should().Be(HttpStatusCode.OK);
        var result2 = await response2.Content.ReadFromJsonAsync<ApplyMetricsResponse>();
        result2.Should().NotBeNull();
        result2!.Success.Should().BeTrue();
        result2.LedgerRows.Should().BeEmpty(); // No new ledger rows (ON CONFLICT DO NOTHING)

        var metricsAfter2 = await _fixture.GetMetricRowCountAsync();
        metricsAfter2.Should().Be(metricsAfter1); // Unchanged (idempotent)
    }

    /// <summary>
    /// Scenario 2: RT-only appliedRtMetricIds.
    /// Manifest has 1 RT + 1 History; response.appliedRtMetricIds contains ONLY the RT id.
    /// </summary>
    [Fact]
    public async Task AppliedRtMetricIds_ShouldContainOnlyRtMetrics()
    {
        // Arrange
        await using var factory = _fixture.CreateWebApplicationFactory();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _fixture.TestToken);

        var request = new ApplyMetricsRequest
        {
            PackageRef = "test-commit-rt",
            MigrationRef = _fixture.FixtureMigrationFileName,
            MetricIds = new[] { _fixture.RtMetricId, _fixture.HistoryMetricId },
            TriggeredBy = "test-user"
        };

        // Act
        var response = await client.PostAsJsonAsync("/apply-metrics", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var result = await response.Content.ReadFromJsonAsync<ApplyMetricsResponse>();
        result.Should().NotBeNull();
        result!.AppliedRtMetricIds.Should().ContainSingle(_fixture.RtMetricId);
        result.AppliedRtMetricIds.Should().NotContain(_fixture.HistoryMetricId);
    }

    /// <summary>
    /// Scenario 3: bad migration (syntax error) → 500.
    /// Transaction rolled back: metric_deploy_log has NO new rows, no audit row, RTSGrid_Metric unchanged.
    /// </summary>
    [Fact]
    public async Task BadMigration_ShouldReturn500AndRollback()
    {
        // Arrange
        var badFile = _fixture.CreateBadMigration();
        await using var factory = _fixture.CreateWebApplicationFactory();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _fixture.TestToken);

        var ledgerBefore = await _fixture.GetLedgerRowCountAsync();
        var auditBefore = await _fixture.GetAuditRowCountAsync();
        var metricsBefore = await _fixture.GetMetricRowCountAsync();

        var request = new ApplyMetricsRequest
        {
            PackageRef = "test-bad-commit",
            MigrationRef = badFile,
            MetricIds = new[] { _fixture.RtMetricId },
            TriggeredBy = "test-user"
        };

        // Act
        var response = await client.PostAsJsonAsync("/apply-metrics", request);

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.InternalServerError);
        var result = await response.Content.ReadFromJsonAsync<ApplyMetricsResponse>();
        result.Should().NotBeNull();
        result!.Success.Should().BeFalse();
        result.Error.Should().Contain("Transaction failed");

        // Verify rollback
        var ledgerAfter = await _fixture.GetLedgerRowCountAsync();
        var auditAfter = await _fixture.GetAuditRowCountAsync();
        var metricsAfter = await _fixture.GetMetricRowCountAsync();

        ledgerAfter.Should().Be(ledgerBefore); // No new ledger rows
        auditAfter.Should().Be(auditBefore); // No audit row (tx failed before audit)
        metricsAfter.Should().Be(metricsBefore); // RTSGrid_Metric unchanged

        // Reset manifest for other tests
        _fixture.ResetManifest();
    }
}
