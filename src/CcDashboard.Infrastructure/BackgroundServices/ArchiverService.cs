using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.BackgroundServices;

/// <summary>
/// Background service that archives RTSData_* rows to arch_rtsdata_* tables.
/// Per Reports_v1_DataArch.md: reads contour (RTSData_*), writes reporting-owned (arch_*).
/// Per-tenant DI scope (ARCH-07). Watermark scan with 2-min safety lag. Batch <=10k.
/// Idempotent: ON CONFLICT per table's conflict policy (DO UPDATE for UPSERT sources, DO NOTHING for append-only).
/// Invariant: archive-FIRST -> purge-SECOND (watermark only advances after batch commit).
///
/// NOTE: Uses raw SQL for archive inserts because EF entity RtsDataInteraction does not have
/// CustomCallData1-20 columns. Raw SQL INSERT...SELECT is faithful column-map and avoids
/// routing ~255M rows through the EF change-tracker.
/// ChatMessage CARVED OUT per SF-ARC-001/002/003 (source has no TenantId column).
/// </summary>
public class ArchiverService(
    IServiceScopeFactory scopeFactory,
    ILogger<ArchiverService> logger) : BackgroundService
{
    private const int BatchSize = 10000;
    private static readonly TimeSpan SafetyLag = TimeSpan.FromMinutes(2);
    private static readonly TimeSpan ArchiveInterval = TimeSpan.FromHours(1);
    private static readonly TimeSpan StartupDelay = TimeSpan.FromMinutes(2);
    private static readonly TimeSpan InterBatchYield = TimeSpan.FromMilliseconds(300);
    private static readonly TimeSpan PartitionCheckInterval = TimeSpan.FromDays(1);

    private DateTime _lastPartitionCheck = DateTime.MinValue;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("ArchiverService: starting, initial delay = {Delay}", StartupDelay);
        await Task.Delay(StartupDelay, stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (DateTime.UtcNow - _lastPartitionCheck > PartitionCheckInterval)
                {
                    await EnsureArchivePartitionsAsync(stoppingToken);
                    _lastPartitionCheck = DateTime.UtcNow;
                }

                await RunArchiveAsync(stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogError(ex, "ArchiverService: error during archive run");
            }

            await Task.Delay(ArchiveInterval, stoppingToken);
        }
    }

    private async Task RunArchiveAsync(CancellationToken ct)
    {
        logger.LogInformation("ArchiverService: starting archive run");

        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var tenants = await db.Tenants.AsNoTracking().Select(t => t.Id).ToListAsync(ct);

        foreach (var tenantId in tenants)
        {
            try
            {
                await ArchiveForTenantAsync(tenantId, ct);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogError(ex, "ArchiverService: error for tenant {TenantId}", tenantId);
            }
        }

        logger.LogInformation("ArchiverService: archive run complete");
    }

    private async Task ArchiveForTenantAsync(Guid tenantId, CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var tenantContext = scope.ServiceProvider.GetRequiredService<ITenantContext>();
        tenantContext.Set(tenantId, string.Empty);

        var appDb = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        // Archive each table type using raw SQL (EF entities don't have all columns)
        // ChatMessage CARVED OUT per SF-ARC-001/002/003 (source has no TenantId column)
        await ArchiveInteractionsAsync(tenantId, appDb, ct);
        await ArchiveUserStatusLogsAsync(tenantId, appDb, ct);
        await ArchiveUserStatusesAsync(tenantId, appDb, ct);
    }

    private async Task ArchiveInteractionsAsync(Guid tenantId, AppDbContext db, CancellationToken ct)
    {
        const string tableName = "arch_rtsdata_interaction";
        var watermark = await GetWatermarkAsync(db, tableName, tenantId, ct);
        var cutoff = DateTime.UtcNow - SafetyLag;

        // Archive using raw SQL with ON CONFLICT DO UPDATE (source is UPSERTED)
        // PartTime = COALESCE("InQueueDateTime", to_timestamp("OnDate",'DD/MM/YYYY'))
        // OnDate format is DD/MM/YYYY per RtsDataInteraction entity comments
        var count = await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO public.arch_rtsdata_interaction (
                "InteractionId", "Segment", "OnDate", "ServerId", "Workgroup", "PartTime",
                "TenantId", "UserId", "ClassificationCode", "InteractionType", "CallType", "Direction",
                "CustomCallData", "IsTransferred", "IsAnswered", "IsInQueue", "IsTalk", "IsAbandoned",
                "TimeInQueue", "TalkTime", "InQueueDateTime", "AnsweredDateTime", "UpdateTime",
                "LastUserId", "LastWorkgroup", "IsMessaging", "RemoteAddress", "IsCallbackRequest", "TimeZone",
                "CustomCallData1", "CustomCallData2", "CustomCallData3", "CustomCallData4", "CustomCallData5",
                "CustomCallData6", "CustomCallData7", "CustomCallData8", "CustomCallData9", "CustomCallData10",
                "CustomCallData11", "CustomCallData12", "CustomCallData13", "CustomCallData14", "CustomCallData15",
                "CustomCallData16", "CustomCallData17", "CustomCallData18", "CustomCallData19", "CustomCallData20"
            )
            SELECT
                "InteractionId", "Segment", "OnDate", "ServerId", "Workgroup",
                COALESCE("InQueueDateTime", to_timestamp("OnDate", 'DD/MM/YYYY')) AS "PartTime",
                "TenantId", "UserId", "ClassificationCode", "InteractionType", "CallType", "Direction",
                "CustomCallData", "IsTransferred", "IsAnswered", "IsInQueue", "IsTalk", "IsAbandoned",
                "TimeInQueue", "TalkTime", "InQueueDateTime", "AnsweredDateTime", "UpdateTime",
                "LastUserId", "LastWorkgroup", "IsMessaging", "RemoteAddress", "IsCallbackRequest", "TimeZone",
                "CustomCallData1", "CustomCallData2", "CustomCallData3", "CustomCallData4", "CustomCallData5",
                "CustomCallData6", "CustomCallData7", "CustomCallData8", "CustomCallData9", "CustomCallData10",
                "CustomCallData11", "CustomCallData12", "CustomCallData13", "CustomCallData14", "CustomCallData15",
                "CustomCallData16", "CustomCallData17", "CustomCallData18", "CustomCallData19", "CustomCallData20"
            FROM "RTSData_Interaction"
            WHERE "TenantId" = {tenantId}
              AND "UpdateTime" > {watermark}
              AND "UpdateTime" <= {cutoff}
            ORDER BY "UpdateTime"
            LIMIT {BatchSize}
            ON CONFLICT ("InteractionId", "Segment", "OnDate", "ServerId", "Workgroup", "PartTime") DO UPDATE SET
                "TenantId" = EXCLUDED."TenantId", "UserId" = EXCLUDED."UserId",
                "ClassificationCode" = EXCLUDED."ClassificationCode", "InteractionType" = EXCLUDED."InteractionType",
                "CallType" = EXCLUDED."CallType", "Direction" = EXCLUDED."Direction",
                "CustomCallData" = EXCLUDED."CustomCallData", "IsTransferred" = EXCLUDED."IsTransferred",
                "IsAnswered" = EXCLUDED."IsAnswered", "IsInQueue" = EXCLUDED."IsInQueue",
                "IsTalk" = EXCLUDED."IsTalk", "IsAbandoned" = EXCLUDED."IsAbandoned",
                "TimeInQueue" = EXCLUDED."TimeInQueue", "TalkTime" = EXCLUDED."TalkTime",
                "InQueueDateTime" = EXCLUDED."InQueueDateTime", "AnsweredDateTime" = EXCLUDED."AnsweredDateTime",
                "UpdateTime" = EXCLUDED."UpdateTime", "LastUserId" = EXCLUDED."LastUserId",
                "LastWorkgroup" = EXCLUDED."LastWorkgroup", "IsMessaging" = EXCLUDED."IsMessaging",
                "RemoteAddress" = EXCLUDED."RemoteAddress", "IsCallbackRequest" = EXCLUDED."IsCallbackRequest",
                "TimeZone" = EXCLUDED."TimeZone",
                "CustomCallData1" = EXCLUDED."CustomCallData1", "CustomCallData2" = EXCLUDED."CustomCallData2",
                "CustomCallData3" = EXCLUDED."CustomCallData3", "CustomCallData4" = EXCLUDED."CustomCallData4",
                "CustomCallData5" = EXCLUDED."CustomCallData5", "CustomCallData6" = EXCLUDED."CustomCallData6",
                "CustomCallData7" = EXCLUDED."CustomCallData7", "CustomCallData8" = EXCLUDED."CustomCallData8",
                "CustomCallData9" = EXCLUDED."CustomCallData9", "CustomCallData10" = EXCLUDED."CustomCallData10",
                "CustomCallData11" = EXCLUDED."CustomCallData11", "CustomCallData12" = EXCLUDED."CustomCallData12",
                "CustomCallData13" = EXCLUDED."CustomCallData13", "CustomCallData14" = EXCLUDED."CustomCallData14",
                "CustomCallData15" = EXCLUDED."CustomCallData15", "CustomCallData16" = EXCLUDED."CustomCallData16",
                "CustomCallData17" = EXCLUDED."CustomCallData17", "CustomCallData18" = EXCLUDED."CustomCallData18",
                "CustomCallData19" = EXCLUDED."CustomCallData19", "CustomCallData20" = EXCLUDED."CustomCallData20",
                "ArchivedAt" = now()
            """, ct);

        if (count > 0)
        {
            // Advance watermark to max UpdateTime of archived rows
            await db.Database.ExecuteSqlInterpolatedAsync($"""
                INSERT INTO public.arch_watermark ("TableName", "TenantId", "ArchivedThrough")
                SELECT {tableName}, {tenantId}, MAX("UpdateTime")
                FROM "RTSData_Interaction"
                WHERE "TenantId" = {tenantId}
                  AND "UpdateTime" > {watermark}
                  AND "UpdateTime" <= {cutoff}
                ON CONFLICT ("TableName", "TenantId") DO UPDATE SET "ArchivedThrough" = EXCLUDED."ArchivedThrough"
                """, ct);

            await Task.Delay(InterBatchYield, ct);
            logger.LogDebug("ArchiverService: tenant {TenantId} archived {Count} interactions", tenantId, count);
        }
    }

    private async Task ArchiveUserStatusLogsAsync(Guid tenantId, AppDbContext db, CancellationToken ct)
    {
        const string tableName = "arch_rtsdata_userstatuslog";
        var watermark = await GetWatermarkAsync(db, tableName, tenantId, ct);
        var cutoff = DateTime.UtcNow - SafetyLag;

        // Archive using raw SQL with ON CONFLICT DO NOTHING (source is APPEND-ONLY)
        // PartTime = COALESCE("StartTime", to_timestamp("OnDate",'DD/MM/YYYY'))
        var count = await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO public.arch_rtsdata_userstatuslog (
                "Id", "PartTime", "TenantId", "UserId", "StatusId", "ServerId", "OnDate",
                "StartTime", "EndTime", "Duration", "UpdateTime", "TimeZone", "StatusGroup"
            )
            SELECT
                "Id",
                COALESCE("StartTime", to_timestamp("OnDate", 'DD/MM/YYYY')) AS "PartTime",
                "TenantId", "UserId", "StatusId", "ServerId", "OnDate",
                "StartTime", "EndTime", "Duration", "UpdateTime", "TimeZone", "StatusGroup"
            FROM "RTSData_UserStatusLog"
            WHERE "TenantId" = {tenantId}
              AND "UpdateTime" > {watermark}
              AND "UpdateTime" <= {cutoff}
            ORDER BY "UpdateTime"
            LIMIT {BatchSize}
            ON CONFLICT ("Id", "PartTime") DO NOTHING
            """, ct);

        if (count > 0)
        {
            await db.Database.ExecuteSqlInterpolatedAsync($"""
                INSERT INTO public.arch_watermark ("TableName", "TenantId", "ArchivedThrough")
                SELECT {tableName}, {tenantId}, MAX("UpdateTime")
                FROM "RTSData_UserStatusLog"
                WHERE "TenantId" = {tenantId}
                  AND "UpdateTime" > {watermark}
                  AND "UpdateTime" <= {cutoff}
                ON CONFLICT ("TableName", "TenantId") DO UPDATE SET "ArchivedThrough" = EXCLUDED."ArchivedThrough"
                """, ct);

            await Task.Delay(InterBatchYield, ct);
            logger.LogDebug("ArchiverService: tenant {TenantId} archived {Count} status logs", tenantId, count);
        }
    }

    private async Task ArchiveUserStatusesAsync(Guid tenantId, AppDbContext db, CancellationToken ct)
    {
        const string tableName = "arch_rtsdata_userstatus";
        var watermark = await GetWatermarkAsync(db, tableName, tenantId, ct);
        var cutoff = DateTime.UtcNow - SafetyLag;

        // Archive using raw SQL with ON CONFLICT DO UPDATE (source is UPSERTED daily)
        // PartTime = to_timestamp("OnDate",'DD/MM/YYYY') (OnDate is stable snapshot key)
        var count = await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO public.arch_rtsdata_userstatus (
                "UserId", "StatusId", "ServerId", "OnDate", "PartTime", "TenantId",
                "StatusName", "StatusGroup", "TotalDuration", "MaxDuraction", "TotalCount",
                "UpdateTime", "DisplayName", "TimeZone"
            )
            SELECT
                "UserId", "StatusId", "ServerId", "OnDate",
                to_timestamp("OnDate", 'DD/MM/YYYY') AS "PartTime",
                "TenantId", "StatusName", "StatusGroup", "TotalDuration", "MaxDuraction", "TotalCount",
                "UpdateTime", "DisplayName", "TimeZone"
            FROM "RTSData_UserStatus"
            WHERE "TenantId" = {tenantId}
              AND "UpdateTime" > {watermark}
              AND "UpdateTime" <= {cutoff}
            ORDER BY "UpdateTime"
            LIMIT {BatchSize}
            ON CONFLICT ("UserId", "StatusId", "ServerId", "OnDate", "PartTime") DO UPDATE SET
                "TenantId" = EXCLUDED."TenantId", "StatusName" = EXCLUDED."StatusName",
                "StatusGroup" = EXCLUDED."StatusGroup", "TotalDuration" = EXCLUDED."TotalDuration",
                "MaxDuraction" = EXCLUDED."MaxDuraction", "TotalCount" = EXCLUDED."TotalCount",
                "UpdateTime" = EXCLUDED."UpdateTime", "DisplayName" = EXCLUDED."DisplayName",
                "TimeZone" = EXCLUDED."TimeZone", "ArchivedAt" = now()
            """, ct);

        if (count > 0)
        {
            await db.Database.ExecuteSqlInterpolatedAsync($"""
                INSERT INTO public.arch_watermark ("TableName", "TenantId", "ArchivedThrough")
                SELECT {tableName}, {tenantId}, MAX("UpdateTime")
                FROM "RTSData_UserStatus"
                WHERE "TenantId" = {tenantId}
                  AND "UpdateTime" > {watermark}
                  AND "UpdateTime" <= {cutoff}
                ON CONFLICT ("TableName", "TenantId") DO UPDATE SET "ArchivedThrough" = EXCLUDED."ArchivedThrough"
                """, ct);

            await Task.Delay(InterBatchYield, ct);
            logger.LogDebug("ArchiverService: tenant {TenantId} archived {Count} user statuses", tenantId, count);
        }
    }

    private static async Task<DateTime> GetWatermarkAsync(AppDbContext db, string tableName, Guid tenantId, CancellationToken ct)
    {
        var watermark = await db.Database
            .SqlQueryRaw<DateTime?>(
                """SELECT "ArchivedThrough" FROM public.arch_watermark WHERE "TableName" = {0} AND "TenantId" = {1}""",
                tableName, tenantId)
            .FirstOrDefaultAsync(ct);

        return watermark ?? DateTime.MinValue;
    }

    private async Task EnsureArchivePartitionsAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        // ChatMessage CARVED OUT per SF-ARC-001/002/003
        var tables = new[] { "arch_rtsdata_interaction", "arch_rtsdata_userstatuslog",
                            "arch_rtsdata_userstatus" };

        foreach (var table in tables)
        {
            await db.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT fn_hist_ensure_partitions({table}, 1, 2)", ct);
        }

        logger.LogInformation("ArchiverService: ensured archive partitions (back=1, ahead=2)");
    }
}
