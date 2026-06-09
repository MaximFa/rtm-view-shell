using System.Security.Cryptography;
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
