using CcDashboard.Domain.Domain;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using NpgsqlTypes;
using UUIDNext;
using Xunit;

namespace CcDashboard.Tests.Security.Widgets;

/// <summary>
/// Regression tests for RTSData_SetUserStatus procedure — guards fix 434e4c7:
/// CALL must APPEND a history row to RTSData_UserStatusLog when p_end_time > p_start_time.
/// </summary>
[Collection("Postgres")]
public class RtsDataUserStatusLogTests(PostgresFixture postgres)
{
    /// <summary>
    /// Helper to CALL "RTSData_SetUserStatus" with typed NpgsqlParameters.
    /// </summary>
    private async Task CallSetUserStatusAsync(
        BackendEmulationDbContext beDb,
        string userId,
        string statusId,
        string serverId,
        string onDate,
        string statusName,
        string statusGroup,
        double totalDuration,
        double maxDuration,
        int totalCount,
        string displayName,
        DateTime? startTime,
        DateTime? endTime,
        string timeZone,
        DateTime updateTime,
        Guid tenantId)
    {
        var parameters = new[]
        {
            new NpgsqlParameter("p1", NpgsqlDbType.Text) { Value = userId },
            new NpgsqlParameter("p2", NpgsqlDbType.Text) { Value = statusId },
            new NpgsqlParameter("p3", NpgsqlDbType.Text) { Value = serverId },
            new NpgsqlParameter("p4", NpgsqlDbType.Text) { Value = onDate },
            new NpgsqlParameter("p5", NpgsqlDbType.Text) { Value = statusName },
            new NpgsqlParameter("p6", NpgsqlDbType.Text) { Value = statusGroup },
            new NpgsqlParameter("p7", NpgsqlDbType.Double) { Value = totalDuration },
            new NpgsqlParameter("p8", NpgsqlDbType.Double) { Value = maxDuration },
            new NpgsqlParameter("p9", NpgsqlDbType.Integer) { Value = totalCount },
            new NpgsqlParameter("p10", NpgsqlDbType.Text) { Value = displayName },
            new NpgsqlParameter("p11", NpgsqlDbType.TimestampTz) { Value = startTime.HasValue ? startTime.Value : DBNull.Value },
            new NpgsqlParameter("p12", NpgsqlDbType.TimestampTz) { Value = endTime.HasValue ? endTime.Value : DBNull.Value },
            new NpgsqlParameter("p13", NpgsqlDbType.Text) { Value = timeZone },
            new NpgsqlParameter("p14", NpgsqlDbType.TimestampTz) { Value = updateTime },
            new NpgsqlParameter("p15", NpgsqlDbType.Uuid) { Value = tenantId }
        };

        await beDb.Database.ExecuteSqlRawAsync(
            @"CALL ""RTSData_SetUserStatus""(@p1, @p2, @p3, @p4, @p5, @p6, @p7, @p8, @p9, @p10, @p11, @p12, @p13, @p14, @p15)",
            parameters);
    }

    /// <summary>
    /// RDUL-01: writes a history row when start < end.
    /// Guards the INSERT that was dropped in the MSSQL->PG port.
    /// </summary>
    [Fact]
    [Trait("Req", "RDUL-01")]
    public async Task SetUserStatus_WithValidTimes_WritesHistoryRow()
    {
        // Arrange
        await postgres.EnsureRtsDataSchemaCompatibilityAsync();
        await postgres.EnsureRtsDataFunctionsAsync();
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        
        var testUserId = Uuid.NewSequential().ToString();
        var tenantId = postgres.TenantAId;
        var now = DateTime.UtcNow;
        var startTime = now.AddMinutes(-1);
        var endTime = now.AddSeconds(-30); // 30 seconds after startTime
        var onDate = now.ToString("dd/MM/yyyy");
        const string statusGroup = "Available";

        // Act
        await CallSetUserStatusAsync(
            beDb,
            userId: testUserId,
            statusId: "STATUS001",
            serverId: "SERVER001",
            onDate: onDate,
            statusName: "Available",
            statusGroup: statusGroup,
            totalDuration: 30000,
            maxDuration: 30000,
            totalCount: 1,
            displayName: "Test Agent",
            startTime: startTime,
            endTime: endTime,
            timeZone: "UTC",
            updateTime: now,
            tenantId: tenantId);

        // Assert
        var logRows = await beDb.RtsDataUserStatusLogs
            .IgnoreQueryFilters()
            .Where(r => r.UserId == testUserId && r.TenantId == tenantId)
            .ToListAsync();

        logRows.Should().HaveCount(1, "CALL with valid start < end must INSERT one history row");
        
        var row = logRows[0];
        row.Duration.Should().Be(30000, "Duration = (end - start) in milliseconds = 30 seconds = 30000 ms");
        row.StatusGroup.Should().Be(statusGroup);
        row.TenantId.Should().Be(tenantId);
    }

    /// <summary>
    /// RDUL-02: guard — NO history row when times null or end <= start.
    /// BUT current-state row IS written to RTSData_UserStatus.
    /// </summary>
    [Fact]
    [Trait("Req", "RDUL-02")]
    public async Task SetUserStatus_WithNullOrInvalidTimes_NoHistoryRow_ButCurrentStateWritten()
    {
        // Arrange
        await postgres.EnsureRtsDataSchemaCompatibilityAsync();
        await postgres.EnsureRtsDataFunctionsAsync();
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        
        var testUserId1 = Uuid.NewSequential().ToString();
        var testUserId2 = Uuid.NewSequential().ToString();
        var tenantId = postgres.TenantAId;
        var now = DateTime.UtcNow;
        var onDate = now.ToString("dd/MM/yyyy");

        // Act — Case 1: null start_time
        await CallSetUserStatusAsync(
            beDb,
            userId: testUserId1,
            statusId: "STATUS002",
            serverId: "SERVER001",
            onDate: onDate,
            statusName: "Break",
            statusGroup: "Break",
            totalDuration: 0,
            maxDuration: 0,
            totalCount: 1,
            displayName: "Test Agent 1",
            startTime: null,  // NULL
            endTime: now,
            timeZone: "UTC",
            updateTime: now,
            tenantId: tenantId);

        // Act — Case 2: end_time == start_time
        await CallSetUserStatusAsync(
            beDb,
            userId: testUserId2,
            statusId: "STATUS003",
            serverId: "SERVER001",
            onDate: onDate,
            statusName: "Paperwork",
            statusGroup: "Paperwork",
            totalDuration: 0,
            maxDuration: 0,
            totalCount: 1,
            displayName: "Test Agent 2",
            startTime: now,
            endTime: now,  // end == start
            timeZone: "UTC",
            updateTime: now,
            tenantId: tenantId);

        // Assert — NO history rows
        var logRows1 = await beDb.RtsDataUserStatusLogs
            .IgnoreQueryFilters()
            .Where(r => r.UserId == testUserId1 && r.TenantId == tenantId)
            .ToListAsync();
        logRows1.Should().BeEmpty("null start_time must NOT create history row");

        var logRows2 = await beDb.RtsDataUserStatusLogs
            .IgnoreQueryFilters()
            .Where(r => r.UserId == testUserId2 && r.TenantId == tenantId)
            .ToListAsync();
        logRows2.Should().BeEmpty("end == start must NOT create history row");

        // Assert — current-state rows ARE written (use raw SQL to avoid EF column name mismatch)
        var count1 = await beDb.Database.SqlQueryRaw<int>(
            @"SELECT COUNT(*)::int AS ""Value"" FROM ""RTSData_UserStatus"" WHERE ""UserId"" = {0} AND ""TenantId"" = {1}",
            testUserId1, tenantId).FirstOrDefaultAsync();
        count1.Should().Be(1, "upsert path must still write to RTSData_UserStatus");

        var count2 = await beDb.Database.SqlQueryRaw<int>(
            @"SELECT COUNT(*)::int AS ""Value"" FROM ""RTSData_UserStatus"" WHERE ""UserId"" = {0} AND ""TenantId"" = {1}",
            testUserId2, tenantId).FirstOrDefaultAsync();
        count2.Should().Be(1, "upsert path must still write to RTSData_UserStatus");
    }

    /// <summary>
    /// RDUL-03: log row is tenant-scoped.
    /// TenantA's row must not appear in TenantB's query and vice versa.
    /// </summary>
    [Fact]
    [Trait("Req", "RDUL-03")]
    public async Task SetUserStatus_LogRowIsTenantScoped()
    {
        // Arrange
        await postgres.EnsureRtsDataSchemaCompatibilityAsync();
        await postgres.EnsureRtsDataFunctionsAsync();
        await using var beDb = postgres.CreateBackendEmulationDbContext();
        
        var testUserIdA = Uuid.NewSequential().ToString();
        var testUserIdB = Uuid.NewSequential().ToString();
        var tenantAId = postgres.TenantAId;
        var tenantBId = postgres.TenantBId;
        var now = DateTime.UtcNow;
        var startTime = now.AddSeconds(-60);
        var endTime = now;
        var onDate = now.ToString("dd/MM/yyyy");

        // Act — CALL for TenantA
        await CallSetUserStatusAsync(
            beDb,
            userId: testUserIdA,
            statusId: "STATUS_A",
            serverId: "SERVER001",
            onDate: onDate,
            statusName: "Available",
            statusGroup: "Available",
            totalDuration: 60000,
            maxDuration: 60000,
            totalCount: 1,
            displayName: "Agent A",
            startTime: startTime,
            endTime: endTime,
            timeZone: "UTC",
            updateTime: now,
            tenantId: tenantAId);

        // Act — CALL for TenantB
        await CallSetUserStatusAsync(
            beDb,
            userId: testUserIdB,
            statusId: "STATUS_B",
            serverId: "SERVER001",
            onDate: onDate,
            statusName: "Break",
            statusGroup: "Break",
            totalDuration: 60000,
            maxDuration: 60000,
            totalCount: 1,
            displayName: "Agent B",
            startTime: startTime,
            endTime: endTime,
            timeZone: "UTC",
            updateTime: now,
            tenantId: tenantBId);

        // Assert — query by TenantA
        var rowsA = await beDb.RtsDataUserStatusLogs
            .IgnoreQueryFilters()
            .Where(r => r.TenantId == tenantAId)
            .Where(r => r.UserId == testUserIdA || r.UserId == testUserIdB)
            .ToListAsync();

        rowsA.Should().HaveCount(1);
        rowsA[0].UserId.Should().Be(testUserIdA);
        rowsA[0].TenantId.Should().Be(tenantAId);

        // Assert — query by TenantB
        var rowsB = await beDb.RtsDataUserStatusLogs
            .IgnoreQueryFilters()
            .Where(r => r.TenantId == tenantBId)
            .Where(r => r.UserId == testUserIdA || r.UserId == testUserIdB)
            .ToListAsync();

        rowsB.Should().HaveCount(1);
        rowsB[0].UserId.Should().Be(testUserIdB);
        rowsB[0].TenantId.Should().Be(tenantBId);
    }
}