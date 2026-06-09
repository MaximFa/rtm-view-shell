using System.Security.Cryptography;
using System.Text.Json;
using CcDashboard.Contracts.DTOs.Metrics;
using CcDashboard.Domain.Domain.Metrics;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
using Microsoft.EntityFrameworkCore;
using Serilog;
using UUIDNext;

var builder = WebApplication.CreateBuilder(args);

// Serilog
builder.Host.UseSerilog((ctx, cfg) => cfg.ReadFrom.Configuration(ctx.Configuration));

// ═══════════════════════════════════════════════════════════════════════════════
// F-2 (HIGH): STARTUP GUARD — fail-closed if token is unset/placeholder
// ═══════════════════════════════════════════════════════════════════════════════
var startupToken = builder.Configuration["ApplyService:Token"];
var knownPlaceholders = new[] { "REPLACE_AT_DEPLOY", "", null };
if (string.IsNullOrWhiteSpace(startupToken) || knownPlaceholders.Contains(startupToken))
{
    Log.Fatal("ApplyService token unset/placeholder — refusing to start (F-2 fail-closed)");
    throw new InvalidOperationException("ApplyService:Token is missing or set to a known placeholder. " +
        "Configure a real token before starting the service.");
}
Log.Information("ApplyService token configured ({Length} chars)", startupToken.Length);

// Kestrel: 127.0.0.1 ONLY (never 0.0.0.0)
var port = builder.Configuration.GetValue<int>("ApplyService:Port", 5099);
builder.WebHost.UseUrls($"http://127.0.0.1:{port}");

// DbContexts - catalogue owner for writes, audit for audit logs
builder.Services.AddDbContext<ApplyDbContext>(opt =>
    opt.UseNpgsql(builder.Configuration.GetConnectionString("CatalogueOwner") 
                  ?? builder.Configuration["CatalogueOwner:ConnectionString"]));

builder.Services.AddDbContext<AuditDbContext>(opt =>
    opt.UseNpgsql(builder.Configuration.GetConnectionString("Audit") 
                  ?? builder.Configuration["Audit:ConnectionString"]));

builder.Services.AddSingleton<IDateTimeProvider, UtcDateTimeProvider>();

var app = builder.Build();

app.MapPost("/apply-metrics", async (
    HttpContext httpContext,
    ApplyMetricsRequest request,
    ApplyDbContext db,
    AuditDbContext auditDb,
    IDateTimeProvider clock,
    IConfiguration config,
    ILogger<Program> logger) =>
{
    // 1. AuthN: Bearer token constant-time compare
    // F-2: NO fallback — token MUST be configured (startup guard ensures this, but defense-in-depth)
    var expectedToken = config["ApplyService:Token"];
    if (string.IsNullOrWhiteSpace(expectedToken))
    {
        logger.LogError("ApplyMetrics: Token not configured at request time — mis-provisioned (F-2)");
        return Results.StatusCode(503); // Service unavailable (mis-provisioned)
    }

    var authHeader = httpContext.Request.Headers.Authorization.ToString();
    if (string.IsNullOrEmpty(authHeader) || !authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
    {
        logger.LogWarning("ApplyMetrics: Missing or invalid Authorization header");
        return Results.Unauthorized();
    }
    
    var providedToken = authHeader["Bearer ".Length..];
    if (!ConstantTimeEquals(providedToken, expectedToken))
    {
        logger.LogWarning("ApplyMetrics: Token mismatch");
        return Results.Unauthorized();
    }

    // 2. Validate migrationRef - no path traversal
    var migrationRef = request.MigrationRef ?? "";
    if (string.IsNullOrWhiteSpace(migrationRef) 
        || migrationRef.Contains("..") 
        || migrationRef.Contains('/') 
        || migrationRef.Contains('\\')
        || migrationRef.Contains(':'))
    {
        logger.LogWarning("ApplyMetrics: Invalid migrationRef (path traversal attempt): {MigrationRef}", migrationRef);
        return Results.BadRequest(new ApplyMetricsResponse 
        { 
            Success = false, 
            Error = "Invalid migrationRef: path traversal detected" 
        });
    }

    var migrationsDir = config["PackageMigrationsDir"] ?? "";
    var migrationPath = Path.Combine(migrationsDir, migrationRef);
    if (!File.Exists(migrationPath))
    {
        logger.LogWarning("ApplyMetrics: Migration file not found: {MigrationPath}", migrationPath);
        return Results.BadRequest(new ApplyMetricsResponse 
        { 
            Success = false, 
            Error = $"Migration file not found: {migrationRef}" 
        });
    }

    // 3. Load manifest -> map MetricId to (metricType, sha256)
    var manifestPath = config["ManifestPath"] ?? "";
    var manifestEntries = new Dictionary<string, ManifestEntry>(StringComparer.OrdinalIgnoreCase);
    var migrationHashes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    
    if (!File.Exists(manifestPath))
    {
        // F-4: No manifest = fail-closed (cannot verify integrity)
        logger.LogError("ApplyMetrics: Manifest not found at {ManifestPath} — integrity check cannot proceed (F-4 fail-closed)", manifestPath);
        return Results.Json(new ApplyMetricsResponse 
        { 
            Success = false, 
            Error = "Manifest not found — cannot verify migration integrity" 
        }, statusCode: 409);
    }

    try
    {
        var manifestJson = await File.ReadAllTextAsync(manifestPath);
        var manifest = JsonSerializer.Deserialize<ManifestData>(manifestJson, 
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        
        if (manifest?.Metrics != null)
        {
            foreach (var entry in manifest.Metrics)
            {
                if (!string.IsNullOrEmpty(entry.MetricId))
                {
                    manifestEntries[entry.MetricId] = entry;
                }
            }
        }
        
        if (manifest?.Migrations != null)
        {
            foreach (var mig in manifest.Migrations)
            {
                if (!string.IsNullOrEmpty(mig.FileName) && !string.IsNullOrEmpty(mig.Sha256))
                {
                    migrationHashes[mig.FileName] = mig.Sha256;
                }
            }
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "ApplyMetrics: Failed to parse manifest at {ManifestPath}", manifestPath);
        return Results.Json(new ApplyMetricsResponse 
        { 
            Success = false, 
            Error = $"Failed to parse manifest: {ex.Message}" 
        }, statusCode: 409);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // F-6 (MED): Validate request.MetricIds ⊆ manifest MetricIds (reject if not)
    // ═══════════════════════════════════════════════════════════════════════════════
    var unknownMetricIds = request.MetricIds.Where(id => !manifestEntries.ContainsKey(id)).ToList();
    if (unknownMetricIds.Count > 0)
    {
        logger.LogWarning("ApplyMetrics: Request contains MetricIds not in manifest (F-6 validation): {UnknownIds}", 
            string.Join(", ", unknownMetricIds));
        return Results.BadRequest(new ApplyMetricsResponse
        {
            Success = false,
            Error = $"MetricIds not found in manifest: {string.Join(", ", unknownMetricIds)}"
        });
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // F-4 (HIGH): Verify migration file integrity (SHA-256) before execution
    // ═══════════════════════════════════════════════════════════════════════════════
    if (!migrationHashes.TryGetValue(migrationRef, out var expectedHash) || string.IsNullOrWhiteSpace(expectedHash))
    {
        // No hash for this migration in manifest = fail-closed
        logger.LogError("ApplyMetrics: No SHA-256 hash in manifest for {MigrationRef} — integrity check failed (F-4 fail-closed)", migrationRef);
        return Results.Json(new ApplyMetricsResponse
        {
            Success = false,
            Error = $"Migration '{migrationRef}' has no integrity hash in manifest — cannot execute"
        }, statusCode: 409);
    }

    var migrationBytes = await File.ReadAllBytesAsync(migrationPath);
    var actualHash = Convert.ToHexString(SHA256.HashData(migrationBytes)).ToLowerInvariant();
    expectedHash = expectedHash.ToLowerInvariant();

    if (actualHash != expectedHash)
    {
        logger.LogError("ApplyMetrics: SHA-256 mismatch for {MigrationRef} — expected {Expected}, actual {Actual} (F-4 integrity failure)", 
            migrationRef, expectedHash, actualHash);
        return Results.Json(new ApplyMetricsResponse
        {
            Success = false,
            Error = $"Migration integrity check failed: SHA-256 mismatch"
        }, statusCode: 409);
    }
    logger.LogInformation("ApplyMetrics: Migration {MigrationRef} integrity verified (SHA-256 OK)", migrationRef);

    // 4. Execute in ONE transaction
    var ledgerRows = new List<LedgerRow>();
    var appliedRtMetricIds = new List<string>();
    var now = clock.UtcNow;
    var warnings = new List<string>();

    await using var tx = await db.Database.BeginTransactionAsync();
    try
    {
        // 4a. Execute migration file (integrity already verified)
        var migrationSql = System.Text.Encoding.UTF8.GetString(migrationBytes);
        await db.Database.ExecuteSqlRawAsync(migrationSql);

        // 4b. Insert ledger rows (parameterised - CODE-01)
        foreach (var metricId in request.MetricIds)
        {
            var inserted = await db.Database.ExecuteSqlInterpolatedAsync(
                $"""
                INSERT INTO public.metric_deploy_log ("MetricId", "DeployedAt", "SourceCommit")
                VALUES ({metricId}, {now}, {request.PackageRef})
                ON CONFLICT ("MetricId") DO NOTHING
                """);

            if (inserted > 0)
            {
                ledgerRows.Add(new LedgerRow
                {
                    MetricId = metricId,
                    DeployedAt = now,
                    SourceCommit = request.PackageRef ?? ""
                });
            }
        }

        // 4c. Defense-in-depth: db_patch_history self-record for migrationRef
        var migrationName = Path.GetFileNameWithoutExtension(migrationRef);
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"""
            INSERT INTO public.db_patch_history (migration_name)
            VALUES ({migrationName})
            ON CONFLICT (migration_name) DO NOTHING
            """);

        // 4d. Commit
        await tx.CommitAsync();
        logger.LogInformation("ApplyMetrics: Successfully applied {MigrationRef}, {LedgerCount} ledger rows", 
            migrationRef, ledgerRows.Count);
    }
    catch (Exception ex)
    {
        await tx.RollbackAsync();
        logger.LogError(ex, "ApplyMetrics: Transaction failed for {MigrationRef}", migrationRef);
        return Results.Json(new ApplyMetricsResponse
        {
            Success = false,
            Error = $"Transaction failed: {ex.Message}"
        }, statusCode: 500);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // F-5 (MED): BLOCKING audit write — 500 on failure (AUD-01: separate context)
    // Actor = server principal ("ApplyService"), NOT client-asserted TriggeredBy
    // IpAddress = server-side RemoteIpAddress; UserId/TenantId = null (service principal)
    // Committed-but-audit-failed surfaces as 500 + is idempotent-retryable (acceptable)
    // ═══════════════════════════════════════════════════════════════════════════════
    string auditId;
    try
    {
        var remoteIp = httpContext.Connection.RemoteIpAddress?.ToString();
        var auditLog = new AuditLog
        {
            Id = Uuid.NewSequential(),
            TenantId = null, // Platform-level event (RTSGrid_Metric is cross-tenant, WGT-01)
            UserId = null,   // Service principal, no user context (NOT client-asserted value)
            UserName = "ApplyService", // Server principal identity, NOT TriggeredBy
            EventType = "System.MetricsDeployed",
            EventResult = AuditEventResult.Success,
            IpAddress = remoteIp, // Server-observed, NOT client-asserted
            UserAgent = "ApplyService",
            Details = JsonSerializer.Serialize(new
            {
                migrationRef,
                sourceCommit = request.PackageRef,
                appliedMetricIds = ledgerRows.Select(r => r.MetricId).ToArray(),
                clientAssertedTriggeredBy = request.TriggeredBy // Labelled as client-asserted
            }),
            CreatedAt = now
        };
        auditDb.AuditLogs.Add(auditLog);
        await auditDb.SaveChangesAsync();
        auditId = auditLog.Id.ToString();
        logger.LogInformation("ApplyMetrics: Audit log written {AuditId}", auditId);
    }
    catch (Exception ex)
    {
        // F-5: Audit failure = 500 (fail-closed). Retry is safe (idempotent ON CONFLICT).
        logger.LogError(ex, "ApplyMetrics: Audit write failed — returning 500 (F-5 fail-closed)");
        return Results.Json(new ApplyMetricsResponse
        {
            Success = false,
            Error = $"Audit log failed: {ex.Message}. Catalogue/ledger committed (idempotent). Retry safe."
        }, statusCode: 500);
    }

    // 6. Compute appliedRtMetricIds = RT-only (history excluded per R1)
    foreach (var metricId in request.MetricIds)
    {
        if (manifestEntries.TryGetValue(metricId, out var entry) 
            && entry.MetricType.Equals("RT", StringComparison.OrdinalIgnoreCase))
        {
            appliedRtMetricIds.Add(metricId);
        }
    }

    // 7. Response
    return Results.Ok(new ApplyMetricsResponse
    {
        Success = true,
        AppliedRtMetricIds = appliedRtMetricIds,
        LedgerRows = ledgerRows,
        Warnings = warnings,
        AuditId = auditId
    });
});

app.Run();

// Helper: constant-time string compare to prevent timing attacks
static bool ConstantTimeEquals(string a, string b)
{
    if (a.Length != b.Length) return false;
    var diff = 0;
    for (var i = 0; i < a.Length; i++)
    {
        diff |= a[i] ^ b[i];
    }
    return diff == 0;
}

// Minimal ApplyDbContext for this service
public class ApplyDbContext(DbContextOptions<ApplyDbContext> options) : DbContext(options)
{
    public DbSet<MetricDeployLog> MetricDeployLogs => Set<MetricDeployLog>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<MetricDeployLog>(e =>
        {
            e.ToTable("metric_deploy_log", "public");
            e.HasKey(x => x.MetricId);
            e.Property(x => x.MetricId).HasColumnName("MetricId").HasMaxLength(200).IsRequired();
            e.Property(x => x.DeployedAt).HasColumnName("DeployedAt").HasColumnType("timestamptz").IsRequired();
            e.Property(x => x.SourceCommit).HasColumnName("SourceCommit");
        });
    }
}

// Manifest structures
public record ManifestData
{
    public ManifestEntry[]? Metrics { get; init; }
    public MigrationEntry[]? Migrations { get; init; }
}

public record ManifestEntry
{
    public string MetricId { get; init; } = "";
    public string MetricType { get; init; } = ""; // "RT" or "history"
}

public record MigrationEntry
{
    public string FileName { get; init; } = "";
    public string Sha256 { get; init; } = "";
}

// Simple IDateTimeProvider implementation
public class UtcDateTimeProvider : IDateTimeProvider
{
    public DateTime UtcNow => DateTime.UtcNow;
}