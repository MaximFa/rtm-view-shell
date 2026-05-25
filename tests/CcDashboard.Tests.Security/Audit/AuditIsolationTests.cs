using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using UUIDNext;

namespace CcDashboard.Tests.Security.Audit;

/// <summary>
/// DoD-B2: Audit write isolation (AUD-01).
/// Verifies that audit writes survive business transaction rollback.
/// Per CLAUDE.md §16: "Audit writes use a separate AuditDbContext and are never
/// rolled back with the business transaction."
/// </summary>
[Collection("Postgres")]
public class AuditIsolationTests
{
    private readonly PostgresFixture _fixture;

    public AuditIsolationTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    [Trait("Req", "AUD-01")]
    public async Task AuditWrite_SurvivesBusinessTransactionRollback()
    {
        // Arrange
        var tenantId = _fixture.TenantAId;
        var userId = _fixture.UserAId;
        var testEventType = $"Test.IsolationCheck.{Uuid.NewSequential():N}";
        var clock = new TestDateTimeProvider();

        await using var appDb = _fixture.CreateDbContext(tenantId);
        await using var auditDb = _fixture.CreateAuditDbContext();
        var auditService = new AuditService(auditDb, clock);

        // Act - Start business transaction, write audit, then rollback
        await using var transaction = await appDb.Database.BeginTransactionAsync();

        // Write audit event (uses separate AuditDbContext - should NOT be in this transaction)
        await auditService.LogAsync(
            testEventType,
            AuditEventResult.Success,
            tenantId,
            userId,
            "test@isolation.local",
            "127.0.0.1",
            "TestAgent/1.0",
            new { Test = "IsolationCheck", Timestamp = clock.UtcNow });

        // Rollback the business transaction
        await transaction.RollbackAsync();

        // Assert - Audit log should still exist despite business TX rollback
        await using var verifyAuditDb = _fixture.CreateAuditDbContext();
        var auditLog = await verifyAuditDb.AuditLogs
            .AsNoTracking()
            .Where(l => l.EventType == testEventType)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull(
            "Audit log must survive business transaction rollback [AUD-01]");
        auditLog!.TenantId.Should().Be(tenantId);
        auditLog.UserId.Should().Be(userId);
        auditLog.EventResult.Should().Be(AuditEventResult.Success);

        // Cleanup
        verifyAuditDb.AuditLogs.Remove(auditLog);
        await verifyAuditDb.SaveChangesAsync();
    }

    [Fact]
    [Trait("Req", "AUD-01")]
    public void AuditWrite_UsedSeparateDbContext_NotSharedWithAppDbContext()
    {
        // Arrange - verify that AuditDbContext is a completely separate context
        var auditContextType = typeof(AuditDbContext);
        var appContextType = typeof(AppDbContext);

        // Assert - different types, no inheritance relationship
        auditContextType.BaseType.Should().Be(typeof(DbContext),
            "AuditDbContext should inherit directly from DbContext");
        // AppDbContext inherits from IdentityDbContext (which inherits from DbContext)
        // The key point is that AuditDbContext is NOT derived from or related to AppDbContext
        auditContextType.Should().NotBe(appContextType,
            "AuditDbContext must be separate from AppDbContext [AUD-01]");
        auditContextType.IsAssignableFrom(appContextType).Should().BeFalse(
            "AppDbContext must not derive from AuditDbContext");
        appContextType.IsAssignableFrom(auditContextType).Should().BeFalse(
            "AuditDbContext must not derive from AppDbContext");
    }

    [Fact]
    [Trait("Req", "AUD-01")]
    public async Task AuditWrite_DoesNotParticipateInUnitOfWork()
    {
        // Arrange
        var tenantId = _fixture.TenantAId;
        var userId = _fixture.UserAId;
        var testEventType = $"Test.UoWCheck.{Uuid.NewSequential():N}";
        var clock = new TestDateTimeProvider();

        await using var appDb = _fixture.CreateDbContext(tenantId);
        await using var auditDb = _fixture.CreateAuditDbContext();
        var auditService = new AuditService(auditDb, clock);

        // Act - Write audit without SaveChanges on AppDbContext
        await auditService.LogAsync(
            testEventType,
            AuditEventResult.Success,
            tenantId,
            userId,
            "uow@test.local");

        // Don't call appDb.SaveChangesAsync() - simulating incomplete UoW

        // Assert - Audit should be persisted immediately, independent of AppDbContext
        await using var verifyAuditDb = _fixture.CreateAuditDbContext();
        var auditLog = await verifyAuditDb.AuditLogs
            .AsNoTracking()
            .Where(l => l.EventType == testEventType)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull(
            "Audit writes via AuditService must be immediate and independent [AUD-01]");

        // Cleanup
        verifyAuditDb.AuditLogs.Remove(auditLog!);
        await verifyAuditDb.SaveChangesAsync();
    }

    [Fact]
    [Trait("Req", "AUD-01")]
    public async Task AuditWrite_WithFailureResult_StillPersisted()
    {
        // Arrange
        var tenantId = _fixture.TenantAId;
        var testEventType = $"Test.FailureAudit.{Uuid.NewSequential():N}";
        var clock = new TestDateTimeProvider();

        await using var auditDb = _fixture.CreateAuditDbContext();
        var auditService = new AuditService(auditDb, clock);

        // Act - Write audit with Failure result
        await auditService.LogAsync(
            testEventType,
            AuditEventResult.Failure,
            tenantId,
            null,
            "anonymous",
            "192.168.1.1",
            "FailedClient/1.0",
            new { Reason = "Test failure scenario" });

        // Assert
        await using var verifyAuditDb = _fixture.CreateAuditDbContext();
        var auditLog = await verifyAuditDb.AuditLogs
            .AsNoTracking()
            .Where(l => l.EventType == testEventType)
            .FirstOrDefaultAsync();

        auditLog.Should().NotBeNull("Failure audit events must be persisted [AUD-01]");
        auditLog!.EventResult.Should().Be(AuditEventResult.Failure);
        auditLog.UserId.Should().BeNull("Anonymous failure events may have null UserId");

        // Cleanup
        verifyAuditDb.AuditLogs.Remove(auditLog);
        await verifyAuditDb.SaveChangesAsync();
    }

    [Fact]
    [Trait("Req", "AUD-01")]
    public async Task AuditDbContext_UsesAuditSchema()
    {
        // Arrange
        await using var auditDb = _fixture.CreateAuditDbContext();

        // Act - Check that the model is configured with audit schema
        var entityType = auditDb.Model.FindEntityType(typeof(AuditLog));

        // Assert
        entityType.Should().NotBeNull();
        entityType!.GetSchema().Should().Be("audit",
            "AuditLog entity must use 'audit' schema for separation [AUD-01]");
        entityType.GetTableName().Should().Be("audit_logs");
    }
}
