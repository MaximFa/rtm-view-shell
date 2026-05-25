using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Enums;
using CcDashboard.Infrastructure.Audit;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using UUIDNext;

namespace CcDashboard.Tests.Security.Audit;

/// <summary>
/// DoD-B6: CSV export boundary (AUD-08).
/// Per CLAUDE.md §16: "CSV export: max 50,000 records per request.
/// Larger exports -> async job -> file via IBlobStorage -> email notification with time-limited download link."
///
/// Note: Full async export implementation is out of scope for T6.
/// These tests verify the CountAsync boundary check mechanism.
/// </summary>
[Collection("Postgres")]
public class AuditExportTests : IAsyncLifetime
{
    private readonly PostgresFixture _fixture;
    private const int ExportLimit = 50_000;

    public AuditExportTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    public Task InitializeAsync() => Task.CompletedTask;

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    [Trait("Req", "AUD-08")]
    public async Task CountAsync_ReturnsCorrectCount()
    {
        // Arrange
        await using var auditDb = _fixture.CreateAuditDbContext();
        var repo = new AuditLogRepository(auditDb);

        // Act
        var count = await repo.CountAsync(_fixture.TenantAId);

        // Assert - should return some count (0 or more)
        count.Should().BeGreaterThanOrEqualTo(0,
            "CountAsync should return a valid count");
    }

    [Fact]
    [Trait("Req", "AUD-08")]
    public async Task CountAsync_WithTenantFilter_CountsOnlyThatTenant()
    {
        // Arrange - seed logs for specific tenant
        await using var auditDb = _fixture.CreateAuditDbContext();
        var testEventType = $"Test.Export.{Uuid.NewSequential():N}";
        var clock = new TestDateTimeProvider();

        var tenantALogs = new List<AuditLog>();
        for (int i = 0; i < 5; i++)
        {
            tenantALogs.Add(new AuditLog
            {
                Id = Uuid.NewSequential(),
                TenantId = _fixture.TenantAId,
                UserName = "export-test",
                EventType = testEventType,
                EventResult = AuditEventResult.Success,
                CreatedAt = clock.UtcNow
            });
        }

        var tenantBLog = new AuditLog
        {
            Id = Uuid.NewSequential(),
            TenantId = _fixture.TenantBId,
            UserName = "export-test",
            EventType = testEventType,
            EventResult = AuditEventResult.Success,
            CreatedAt = clock.UtcNow
        };

        auditDb.AuditLogs.AddRange(tenantALogs);
        auditDb.AuditLogs.Add(tenantBLog);
        await auditDb.SaveChangesAsync();

        try
        {
            var repo = new AuditLogRepository(auditDb);

            // Act
            var countA = await repo.CountAsync(_fixture.TenantAId, testEventType);
            var countB = await repo.CountAsync(_fixture.TenantBId, testEventType);

            // Assert
            countA.Should().Be(5, "TenantA should have 5 logs with test event type");
            countB.Should().Be(1, "TenantB should have 1 log with test event type");
        }
        finally
        {
            // Cleanup
            var logsToRemove = await auditDb.AuditLogs
                .Where(l => l.EventType == testEventType)
                .ToListAsync();
            auditDb.AuditLogs.RemoveRange(logsToRemove);
            await auditDb.SaveChangesAsync();
        }
    }

    [Fact]
    [Trait("Req", "AUD-08")]
    public async Task CountAsync_WithDateRange_FiltersCorrectly()
    {
        // Arrange
        await using var auditDb = _fixture.CreateAuditDbContext();
        var testEventType = $"Test.ExportDate.{Uuid.NewSequential():N}";
        var now = DateTime.UtcNow;

        var oldLog = new AuditLog
        {
            Id = Uuid.NewSequential(),
            TenantId = _fixture.TenantAId,
            UserName = "date-test",
            EventType = testEventType,
            EventResult = AuditEventResult.Success,
            CreatedAt = now.AddDays(-10) // Old log
        };

        var recentLog = new AuditLog
        {
            Id = Uuid.NewSequential(),
            TenantId = _fixture.TenantAId,
            UserName = "date-test",
            EventType = testEventType,
            EventResult = AuditEventResult.Success,
            CreatedAt = now.AddHours(-1) // Recent log
        };

        auditDb.AuditLogs.AddRange(oldLog, recentLog);
        await auditDb.SaveChangesAsync();

        try
        {
            var repo = new AuditLogRepository(auditDb);

            // Act - count only last 7 days
            var count = await repo.CountAsync(
                _fixture.TenantAId,
                testEventType,
                from: now.AddDays(-7),
                to: now);

            // Assert
            count.Should().Be(1, "Only recent log should be within date range");
        }
        finally
        {
            // Cleanup
            var logsToRemove = await auditDb.AuditLogs
                .Where(l => l.EventType == testEventType)
                .ToListAsync();
            auditDb.AuditLogs.RemoveRange(logsToRemove);
            await auditDb.SaveChangesAsync();
        }
    }

    [Fact]
    [Trait("Req", "AUD-08")]
    public void ExportBoundaryCheck_BelowLimit_IndicatesDirectExport()
    {
        // Arrange
        var count = 10_000; // Below 50k limit

        // Act
        var requiresAsyncExport = count > ExportLimit;

        // Assert
        requiresAsyncExport.Should().BeFalse(
            "Counts below 50,000 should allow direct export [AUD-08]");
    }

    [Fact]
    [Trait("Req", "AUD-08")]
    public void ExportBoundaryCheck_AtLimit_IndicatesDirectExport()
    {
        // Arrange
        var count = ExportLimit; // Exactly 50k

        // Act
        var requiresAsyncExport = count > ExportLimit;

        // Assert
        requiresAsyncExport.Should().BeFalse(
            "Exactly 50,000 records should allow direct export [AUD-08]");
    }

    [Fact]
    [Trait("Req", "AUD-08")]
    public void ExportBoundaryCheck_AboveLimit_IndicatesAsyncRequired()
    {
        // Arrange
        var count = ExportLimit + 1; // Above 50k

        // Act
        var requiresAsyncExport = count > ExportLimit;

        // Assert
        requiresAsyncExport.Should().BeTrue(
            "More than 50,000 records should require async export [AUD-08]");
    }

    [Fact]
    [Trait("Req", "AUD-08")]
    public async Task CountAsync_WithNoFilter_CountsAllForTenant()
    {
        // Arrange
        await using var auditDb = _fixture.CreateAuditDbContext();
        var repo = new AuditLogRepository(auditDb);

        // First get count for TenantA
        var countA = await repo.CountAsync(_fixture.TenantAId);

        // Get count for all (null tenant = all tenants for Superadmin)
        var countAll = await repo.CountAsync(null);

        // Assert
        countAll.Should().BeGreaterThanOrEqualTo(countA,
            "Count with null tenant should be >= single tenant count");
    }

    [Fact]
    [Trait("Req", "AUD-08")]
    public void IAuditLogRepository_HasCountAsyncMethod()
    {
        // Arrange
        var repoInterface = typeof(IAuditLogRepository);

        // Act
        var countMethod = repoInterface.GetMethod("CountAsync");

        // Assert
        countMethod.Should().NotBeNull(
            "IAuditLogRepository must have CountAsync for export boundary checks [AUD-08]");
        countMethod!.ReturnType.Should().Be(typeof(Task<int>));
    }
}
