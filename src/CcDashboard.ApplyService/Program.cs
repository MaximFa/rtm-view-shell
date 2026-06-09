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
    var expectedToken = config["ApplyService:Token"] ?? "";
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

    // 3. Load manifest -> map MetricId to metricType (RT|History)
    var manifestPath = config["ManifestPath"] ?? "";
    var metricTypes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    var warnings = new List<string>();
    
    if (File.Exists(manifestPath))
    {
        try
        {
            var manifestJson = await File.ReadAllTextAsync(manifestPath);
            var manifest = JsonSerializer.Deserialize<ManifestEntry[]>(manifestJson, 
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? [];
            
            foreach (var entry in manifest)
            {
                if (!string.IsNullOrEmpty(entry.MetricId) && !string.IsNullOrEmpty(entry.MetricType))
                {
                    metricTypes[entry.MetricId] = entry.MetricType;
                }
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "ApplyMetrics: Failed to parse manifest at {ManifestPath}", manifestPath);
            warnings.Add($"Failed to parse manifest: {ex.Message}");
        }
    }
    else
    {
        logger.LogWarning("ApplyMetrics: Manifest not found at {ManifestPath}", manifestPath);
        warnings.Add("Manifest not found; cannot classify RT vs History metrics");
    }

    // Check requested MetricIds against manifest
    foreach (var metricId in request.MetricIds)
    {
        if (!metricTypes.ContainsKey(metricId))
        {
            warnings.Add($"MetricId '{metricId}' not found in manifest");
        }
    }

    // 4. Execute in ONE transaction
    var ledgerRows = new List<LedgerRow>();
    var appliedRtMetricIds = new List<string>();
    var now = clock.UtcNow;

    await using var tx = await db.Database.BeginTransactionAsync();
    try
    {
        // 4a. Execute migration file
        var migrationSql = await File.ReadAllTextAsync(migrationPath);
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

    // 5. Write audit (SEPARATE context - AUD-01)
    string? auditId = null;
    try
    {
        var auditLog = new AuditLog
        {
            Id = Uuid.NewSequential(),
            TenantId = null,
            UserId = null,
            UserName = request.TriggeredBy ?? "system",
            EventType = "System.MetricsDeployed",
            EventResult = AuditEventResult.Success,
            IpAddress = null,
            UserAgent = "ApplyService",
            Details = JsonSerializer.Serialize(new
            {
                migrationRef,
                sourceCommit = request.PackageRef,
                appliedMetricIds = ledgerRows.Select(r => r.MetricId).ToArray(),
                triggeredBy = request.TriggeredBy
            }),
            CreatedAt = now
        };
        auditDb.AuditLogs.Add(auditLog);
        await auditDb.SaveChangesAsync();
        auditId = auditLog.Id.ToString();
    }
    catch (Exception ex)
    {
        logger.LogWarning(ex, "ApplyMetrics: Failed to write audit log (non-blocking)");
        warnings.Add($"Audit log failed: {ex.Message}");
    }

    // 6. Compute appliedRtMetricIds = RT-only (history excluded per R1)
    foreach (var metricId in request.MetricIds)
    {
        if (metricTypes.TryGetValue(metricId, out var type) 
            && type.Equals("RT", StringComparison.OrdinalIgnoreCase))
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

// Manifest entry structure
public record ManifestEntry
{
    public string MetricId { get; init; } = "";
    public string MetricType { get; init; } = "";
}

// Simple IDateTimeProvider implementation
public class UtcDateTimeProvider : IDateTimeProvider
{
    public DateTime UtcNow => DateTime.UtcNow;
}