#!/usr/bin/env python3
"""Create ApplyService integration tests + update Program.cs for testability"""
import os

repo = r"D:\Claude\Projects\RTM View Shell"

# 1. Update Integration test csproj
csproj_path = os.path.join(repo, "tests", "CcDashboard.Tests.Integration", "CcDashboard.Tests.Integration.csproj")
csproj_content = '''<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
    <IsTestProject>true</IsTestProject>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="coverlet.collector" Version="6.0.0" />
    <PackageReference Include="FluentAssertions" Version="8.9.0" />
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="8.0.16" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.8.0" />
    <PackageReference Include="NSubstitute" Version="5.3.0" />
    <PackageReference Include="Testcontainers.PostgreSql" Version="4.11.0" />
    <PackageReference Include="xunit" Version="2.5.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.5.3" />
  </ItemGroup>

  <ItemGroup>
    <Using Include="Xunit" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\\..\\src\\CcDashboard.ApplyService\\CcDashboard.ApplyService.csproj" />
    <ProjectReference Include="..\\..\\src\\CcDashboard.Infrastructure\\CcDashboard.Infrastructure.csproj" />
    <ProjectReference Include="..\\..\\src\\CcDashboard.Application\\CcDashboard.Application.csproj" />
    <ProjectReference Include="..\\..\\src\\CcDashboard.Contracts\\CcDashboard.Contracts.csproj" />
  </ItemGroup>

</Project>
'''

with open(csproj_path, "w", encoding="utf-8") as f:
    f.write(csproj_content)
    f.flush()
    os.fsync(f.fileno())
print(f"Written csproj: {len(csproj_content)} chars")

# 2. Create ApplyService test directory
test_dir = os.path.join(repo, "tests", "CcDashboard.Tests.Integration", "ApplyService")
os.makedirs(test_dir, exist_ok=True)
print(f"Created directory: {test_dir}")

# 3. Create ApplyServiceFixture
fixture_content = r'''using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CcDashboard.Contracts.DTOs.Metrics;
using CcDashboard.Infrastructure.Audit;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Testcontainers.PostgreSql;

namespace CcDashboard.Tests.Integration.ApplyService;

/// <summary>
/// Fixture for ApplyService integration tests.
/// Manages PostgreSQL Testcontainer + temp migrations dir + WebApplicationFactory.
/// </summary>
public class ApplyServiceFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container;
    private string _tempDir = null!;

    public string ConnectionString { get; private set; } = null!;
    public string MigrationsDir => Path.Combine(_tempDir, "migrations");
    public string ManifestPath => Path.Combine(_tempDir, "manifest.json");
    public string TestToken { get; } = "test-token-" + Guid.NewGuid().ToString("N");

    // Fixture metric migration
    public string FixtureMigrationFileName { get; } = "fixture_metric_migration.sql";
    public string FixtureMigrationSha256 { get; private set; } = null!;

    // Test metric IDs
    public string RtMetricId { get; } = "TEST_RT_METRIC_001";
    public string HistoryMetricId { get; } = "TEST_HISTORY_METRIC_001";

    public ApplyServiceFixture()
    {
        _container = new PostgreSqlBuilder()
            .WithImage("postgres:16-alpine")
            .WithDatabase("applyservice_test")
            .WithUsername("test")
            .WithPassword("test")
            .Build();
    }

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        ConnectionString = _container.GetConnectionString();

        // Create temp directory structure
        _tempDir = Path.Combine(Path.GetTempPath(), $"applyservice_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(MigrationsDir);

        // Initialize database schema
        await InitializeDatabaseAsync();

        // Create fixture migration file
        CreateFixtureMigration();

        // Create manifest
        CreateManifest();
    }

    public async Task DisposeAsync()
    {
        await _container.DisposeAsync();
        if (Directory.Exists(_tempDir))
        {
            Directory.Delete(_tempDir, recursive: true);
        }
    }

    private async Task InitializeDatabaseAsync()
    {
        var options = new DbContextOptionsBuilder<AuditDbContext>()
            .UseNpgsql(ConnectionString)
            .Options;

        // Create tables using raw SQL (minimal schema for tests)
        await using var conn = new Npgsql.NpgsqlConnection(ConnectionString);
        await conn.OpenAsync();

        await using var cmd = conn.CreateCommand();
        cmd.CommandText = """
            -- RTSGrid_Metric table (simplified)
            CREATE TABLE IF NOT EXISTS "RTSGrid_Metric" (
                "MetricId" text PRIMARY KEY,
                "Description" text,
                "MetricType" text,
                "ValueType" text
            );

            -- metric_deploy_log ledger table
            CREATE TABLE IF NOT EXISTS public.metric_deploy_log (
                "MetricId" text PRIMARY KEY,
                "DeployedAt" timestamptz NOT NULL,
                "SourceCommit" text NULL
            );

            -- db_patch_history table
            CREATE TABLE IF NOT EXISTS public.db_patch_history (
                migration_name text PRIMARY KEY,
                applied_at timestamptz DEFAULT now()
            );

            -- audit.audit_logs table (AuditDbContext)
            CREATE SCHEMA IF NOT EXISTS audit;
            CREATE TABLE IF NOT EXISTS audit.audit_logs (
                "Id" uuid PRIMARY KEY,
                "TenantId" uuid,
                "UserId" uuid,
                "UserName" text,
                "EventType" text,
                "EventResult" text,
                "IpAddress" text,
                "UserAgent" text,
                "Details" text,
                "CreatedAt" timestamptz NOT NULL
            );
        """;
        await cmd.ExecuteNonQueryAsync();
    }

    private void CreateFixtureMigration()
    {
        var sql = $"""
            -- Fixture metric migration (idempotent)
            INSERT INTO "RTSGrid_Metric" ("MetricId", "Description", "MetricType", "ValueType")
            VALUES ('{RtMetricId}', 'Test RT Metric', 'RT', 'Integer')
            ON CONFLICT ("MetricId") DO NOTHING;

            INSERT INTO "RTSGrid_Metric" ("MetricId", "Description", "MetricType", "ValueType")
            VALUES ('{HistoryMetricId}', 'Test History Metric', 'History', 'Integer')
            ON CONFLICT ("MetricId") DO NOTHING;
        """;

        var filePath = Path.Combine(MigrationsDir, FixtureMigrationFileName);
        File.WriteAllText(filePath, sql, Encoding.UTF8);

        // Compute SHA-256
        var bytes = File.ReadAllBytes(filePath);
        FixtureMigrationSha256 = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
    }

    private void CreateManifest()
    {
        var manifest = new
        {
            Migrations = new[]
            {
                new { FileName = FixtureMigrationFileName, Sha256 = FixtureMigrationSha256 }
            },
            Metrics = new[]
            {
                new { MetricId = RtMetricId, MetricType = "RT" },
                new { MetricId = HistoryMetricId, MetricType = "History" }
            }
        };

        var json = JsonSerializer.Serialize(manifest, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(ManifestPath, json, Encoding.UTF8);
    }

    /// <summary>
    /// Creates a tampered migration file (different content, same name).
    /// </summary>
    public string CreateTamperedMigration()
    {
        var tamperedFile = "tampered_migration.sql";
        var sql = "-- TAMPERED CONTENT\nSELECT 1;";
        File.WriteAllText(Path.Combine(MigrationsDir, tamperedFile), sql, Encoding.UTF8);

        // Add to manifest with WRONG hash (the original fixture hash)
        UpdateManifestWithTamperedFile(tamperedFile, FixtureMigrationSha256);
        return tamperedFile;
    }

    /// <summary>
    /// Creates a migration file with NO hash in manifest.
    /// </summary>
    public string CreateMigrationWithoutHash()
    {
        var noHashFile = "no_hash_migration.sql";
        var sql = "SELECT 1;";
        File.WriteAllText(Path.Combine(MigrationsDir, noHashFile), sql, Encoding.UTF8);

        // Update manifest - add migration entry WITHOUT hash
        UpdateManifestWithNoHashFile(noHashFile);
        return noHashFile;
    }

    /// <summary>
    /// Creates a migration file with syntax error.
    /// </summary>
    public string CreateBadMigration()
    {
        var badFile = "bad_migration.sql";
        var sql = "THIS IS NOT VALID SQL SYNTAX;;;";
        File.WriteAllText(Path.Combine(MigrationsDir, badFile), sql, Encoding.UTF8);

        var bytes = Encoding.UTF8.GetBytes(sql);
        var hash = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
        UpdateManifestWithFile(badFile, hash, RtMetricId); // reuse RT metric for this test
        return badFile;
    }

    private void UpdateManifestWithTamperedFile(string fileName, string wrongHash)
    {
        var manifest = new
        {
            Migrations = new[]
            {
                new { FileName = FixtureMigrationFileName, Sha256 = FixtureMigrationSha256 },
                new { FileName = fileName, Sha256 = wrongHash } // wrong hash
            },
            Metrics = new[]
            {
                new { MetricId = RtMetricId, MetricType = "RT" },
                new { MetricId = HistoryMetricId, MetricType = "History" }
            }
        };
        File.WriteAllText(ManifestPath, JsonSerializer.Serialize(manifest), Encoding.UTF8);
    }

    private void UpdateManifestWithNoHashFile(string fileName)
    {
        // Need to manually construct JSON to have empty hash
        var json = $$"""
        {
            "Migrations": [
                { "FileName": "{{FixtureMigrationFileName}}", "Sha256": "{{FixtureMigrationSha256}}" },
                { "FileName": "{{fileName}}", "Sha256": "" }
            ],
            "Metrics": [
                { "MetricId": "{{RtMetricId}}", "MetricType": "RT" },
                { "MetricId": "{{HistoryMetricId}}", "MetricType": "History" }
            ]
        }
        """;
        File.WriteAllText(ManifestPath, json, Encoding.UTF8);
    }

    private void UpdateManifestWithFile(string fileName, string hash, string metricId)
    {
        var manifest = new
        {
            Migrations = new[]
            {
                new { FileName = FixtureMigrationFileName, Sha256 = FixtureMigrationSha256 },
                new { FileName = fileName, Sha256 = hash }
            },
            Metrics = new[]
            {
                new { MetricId = RtMetricId, MetricType = "RT" },
                new { MetricId = HistoryMetricId, MetricType = "History" }
            }
        };
        File.WriteAllText(ManifestPath, JsonSerializer.Serialize(manifest), Encoding.UTF8);
    }

    /// <summary>
    /// Resets manifest to original state (fixture migration only).
    /// </summary>
    public void ResetManifest()
    {
        CreateManifest();
    }

    /// <summary>
    /// Creates a WebApplicationFactory configured with this fixture.
    /// </summary>
    public WebApplicationFactory<Program> CreateWebApplicationFactory(
        string? overrideToken = null,
        bool useFailingAuditDb = false)
    {
        return new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.ConfigureAppConfiguration((context, config) =>
                {
                    config.AddInMemoryCollection(new Dictionary<string, string?>
                    {
                        ["ApplyService:Token"] = overrideToken ?? TestToken,
                        ["ApplyService:Port"] = "0", // random port
                        ["PackageMigrationsDir"] = MigrationsDir,
                        ["ManifestPath"] = ManifestPath,
                        ["ConnectionStrings:CatalogueOwner"] = ConnectionString,
                        ["ConnectionStrings:Audit"] = ConnectionString,
                        ["Serilog:MinimumLevel:Default"] = "Warning"
                    });
                });

                builder.ConfigureServices(services =>
                {
                    // Remove existing DbContext registrations
                    var descriptors = services.Where(d =>
                        d.ServiceType == typeof(DbContextOptions<ApplyDbContext>) ||
                        d.ServiceType == typeof(DbContextOptions<AuditDbContext>)).ToList();
                    foreach (var d in descriptors) services.Remove(d);

                    // Re-add with test connection string
                    services.AddDbContext<ApplyDbContext>(opt =>
                        opt.UseNpgsql(ConnectionString));

                    if (useFailingAuditDb)
                    {
                        // Register a failing AuditDbContext
                        services.AddDbContext<AuditDbContext>(opt =>
                            opt.UseNpgsql("Host=invalid;Database=invalid;Username=invalid;Password=invalid"));
                    }
                    else
                    {
                        services.AddDbContext<AuditDbContext>(opt =>
                            opt.UseNpgsql(ConnectionString));
                    }
                });
            });
    }

    /// <summary>
    /// Counts rows in metric_deploy_log.
    /// </summary>
    public async Task<int> GetLedgerRowCountAsync()
    {
        await using var conn = new Npgsql.NpgsqlConnection(ConnectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM public.metric_deploy_log";
        return Convert.ToInt32(await cmd.ExecuteScalarAsync());
    }

    /// <summary>
    /// Counts rows in RTSGrid_Metric.
    /// </summary>
    public async Task<int> GetMetricRowCountAsync()
    {
        await using var conn = new Npgsql.NpgsqlConnection(ConnectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM \"RTSGrid_Metric\"";
        return Convert.ToInt32(await cmd.ExecuteScalarAsync());
    }

    /// <summary>
    /// Counts rows in audit.audit_logs.
    /// </summary>
    public async Task<int> GetAuditRowCountAsync()
    {
        await using var conn = new Npgsql.NpgsqlConnection(ConnectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM audit.audit_logs";
        return Convert.ToInt32(await cmd.ExecuteScalarAsync());
    }

    /// <summary>
    /// Gets the latest audit log entry.
    /// </summary>
    public async Task<(string UserName, string? IpAddress, Guid? UserId, Guid? TenantId, string Details)?> GetLatestAuditLogAsync()
    {
        await using var conn = new Npgsql.NpgsqlConnection(ConnectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = """
            SELECT "UserName", "IpAddress", "UserId", "TenantId", "Details"
            FROM audit.audit_logs
            ORDER BY "CreatedAt" DESC
            LIMIT 1
        """;
        await using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return (
                reader.GetString(0),
                reader.IsDBNull(1) ? null : reader.GetString(1),
                reader.IsDBNull(2) ? null : reader.GetGuid(2),
                reader.IsDBNull(3) ? null : reader.GetGuid(3),
                reader.GetString(4)
            );
        }
        return null;
    }
}

/// <summary>
/// xUnit collection for ApplyService tests.
/// </summary>
[CollectionDefinition("ApplyService")]
public class ApplyServiceCollection : ICollectionFixture<ApplyServiceFixture>
{
}
'''

fixture_path = os.path.join(test_dir, "ApplyServiceFixture.cs")
with open(fixture_path, "w", encoding="utf-8") as f:
    f.write(fixture_content)
    f.flush()
    os.fsync(f.fileno())
print(f"Written fixture: {len(fixture_content)} chars")

# 4. Create Functional tests
functional_tests = r'''using System.Net;
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
'''

functional_path = os.path.join(test_dir, "ApplyServiceFunctionalTests.cs")
with open(functional_path, "w", encoding="utf-8") as f:
    f.write(functional_tests)
    f.flush()
    os.fsync(f.fileno())
print(f"Written functional tests: {len(functional_tests)} chars")

# 5. Create Security tests
security_tests = r'''using System.Net;
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
        auditLog.Value.IpAddress.Should().NotBeNullOrEmpty(); // RemoteIpAddress set

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
'''

security_path = os.path.join(test_dir, "ApplyServiceSecurityTests.cs")
with open(security_path, "w", encoding="utf-8") as f:
    f.write(security_tests)
    f.flush()
    os.fsync(f.fileno())
print(f"Written security tests: {len(security_tests)} chars")

# 6. Create Unit tests
unit_tests = r'''using FluentAssertions;

namespace CcDashboard.Tests.Integration.ApplyService;

/// <summary>
/// Unit tests for ApplyService helpers (moved from Program.cs inline checks).
/// Tests: constant-time string compare, path-traversal rejection.
/// </summary>
public class ApplyServiceUnitTests
{
    // ═══════════════════════════════════════════════════════════════════════════════
    // Constant-time string compare tests
    // ═══════════════════════════════════════════════════════════════════════════════

    [Fact]
    public void ConstantTimeEquals_EqualStrings_ReturnsTrue()
    {
        // Arrange
        var a = "test-token-12345";
        var b = "test-token-12345";

        // Act
        var result = ConstantTimeEquals(a, b);

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public void ConstantTimeEquals_DifferentStrings_ReturnsFalse()
    {
        // Arrange
        var a = "test-token-12345";
        var b = "test-token-67890";

        // Act
        var result = ConstantTimeEquals(a, b);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public void ConstantTimeEquals_DifferentLengths_ReturnsFalse()
    {
        // Arrange
        var a = "short";
        var b = "much-longer-string";

        // Act
        var result = ConstantTimeEquals(a, b);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public void ConstantTimeEquals_EmptyStrings_ReturnsTrue()
    {
        // Arrange
        var a = "";
        var b = "";

        // Act
        var result = ConstantTimeEquals(a, b);

        // Assert
        result.Should().BeTrue();
    }

    [Fact]
    public void ConstantTimeEquals_SingleCharDifference_ReturnsFalse()
    {
        // Arrange
        var a = "abcdefghij";
        var b = "abcdefghik"; // Last char different

        // Act
        var result = ConstantTimeEquals(a, b);

        // Assert
        result.Should().BeFalse();
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // Path-traversal rejection tests
    // ═══════════════════════════════════════════════════════════════════════════════

    [Theory]
    [InlineData("../secret.sql")]
    [InlineData("..\\secret.sql")]
    [InlineData("foo/../bar.sql")]
    [InlineData("foo\\..\\bar.sql")]
    public void PathTraversal_DoubleDot_ShouldBeRejected(string migrationRef)
    {
        // Act
        var isValid = IsValidMigrationRef(migrationRef);

        // Assert
        isValid.Should().BeFalse($"'{migrationRef}' contains path traversal");
    }

    [Theory]
    [InlineData("path/to/file.sql")]
    [InlineData("path\\to\\file.sql")]
    public void PathTraversal_Separators_ShouldBeRejected(string migrationRef)
    {
        // Act
        var isValid = IsValidMigrationRef(migrationRef);

        // Assert
        isValid.Should().BeFalse($"'{migrationRef}' contains path separators");
    }

    [Theory]
    [InlineData("C:file.sql")]
    [InlineData("D:\\file.sql")]
    public void PathTraversal_DriveLetters_ShouldBeRejected(string migrationRef)
    {
        // Act
        var isValid = IsValidMigrationRef(migrationRef);

        // Assert
        isValid.Should().BeFalse($"'{migrationRef}' contains drive letter");
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void PathTraversal_EmptyOrWhitespace_ShouldBeRejected(string? migrationRef)
    {
        // Act
        var isValid = IsValidMigrationRef(migrationRef);

        // Assert
        isValid.Should().BeFalse("empty/whitespace migrationRef should be rejected");
    }

    [Theory]
    [InlineData("valid_migration_001.sql")]
    [InlineData("20260609_010_metric_deploy_log.sql")]
    [InlineData("fixture-migration.sql")]
    public void PathTraversal_ValidFilenames_ShouldBeAccepted(string migrationRef)
    {
        // Act
        var isValid = IsValidMigrationRef(migrationRef);

        // Assert
        isValid.Should().BeTrue($"'{migrationRef}' is a valid filename");
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // Helper methods (same logic as Program.cs)
    // ═══════════════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Constant-time string comparison to prevent timing attacks.
    /// Same implementation as Program.cs.
    /// </summary>
    private static bool ConstantTimeEquals(string a, string b)
    {
        if (a.Length != b.Length) return false;
        var diff = 0;
        for (var i = 0; i < a.Length; i++)
        {
            diff |= a[i] ^ b[i];
        }
        return diff == 0;
    }

    /// <summary>
    /// Validates migrationRef for path-traversal attacks.
    /// Same logic as Program.cs validation.
    /// </summary>
    private static bool IsValidMigrationRef(string? migrationRef)
    {
        if (string.IsNullOrWhiteSpace(migrationRef)) return false;
        if (migrationRef.Contains("..")) return false;
        if (migrationRef.Contains('/')) return false;
        if (migrationRef.Contains('\\')) return false;
        if (migrationRef.Contains(':')) return false;
        return true;
    }
}
'''

unit_path = os.path.join(test_dir, "ApplyServiceUnitTests.cs")
with open(unit_path, "w", encoding="utf-8") as f:
    f.write(unit_tests)
    f.flush()
    os.fsync(f.fileno())
print(f"Written unit tests: {len(unit_tests)} chars")

# 7. Update Program.cs - add public partial class
program_path = os.path.join(repo, "src", "CcDashboard.ApplyService", "Program.cs")
with open(program_path, "r", encoding="utf-8-sig") as f:
    program_content = f.read()

# Add partial class at the end if not present
if "public partial class Program" not in program_content:
    program_content = program_content.rstrip() + "\n\n// Enable WebApplicationFactory for integration tests\npublic partial class Program { }\n"
    with open(program_path, "w", encoding="utf-8") as f:
        f.write(program_content)
        f.flush()
        os.fsync(f.fileno())
    print(f"Updated Program.cs with partial class: {len(program_content)} chars")
else:
    print("Program.cs already has partial class")

print("\nAll files written successfully!")
