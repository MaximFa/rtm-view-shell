using CcDashboard.Infrastructure.Audit;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using System.Reflection;

namespace CcDashboard.Tests.Security.Audit;

/// <summary>
/// DoD-B1: INSERT-only enforcement for audit logs (AUD-02).
/// Per T6-gap-analysis-phase-b.md: no app_role exists in DB, so verify
/// AuditDbContext has no Update/Delete methods exposed architecturally.
/// </summary>
public class AuditInsertOnlyTests
{
    [Fact]
    [Trait("Req", "AUD-02")]
    public void AuditDbContext_DoesNotExposeUpdateMethod()
    {
        // Arrange
        var contextType = typeof(AuditDbContext);

        // Act - check for Update methods that accept AuditLog
        var updateMethods = contextType.GetMethods(BindingFlags.Public | BindingFlags.Instance)
            .Where(m => m.Name == "Update" &&
                        m.GetParameters().Any(p => p.ParameterType == typeof(AuditLog)));

        // Assert
        updateMethods.Should().BeEmpty(
            "AuditDbContext must not expose Update(AuditLog) - audit records are INSERT-only [AUD-02]");
    }

    [Fact]
    [Trait("Req", "AUD-02")]
    public void AuditDbContext_DoesNotExposeRemoveMethod()
    {
        // Arrange
        var contextType = typeof(AuditDbContext);

        // Act - check for Remove methods that accept AuditLog
        var removeMethods = contextType.GetMethods(BindingFlags.Public | BindingFlags.Instance)
            .Where(m => m.Name == "Remove" &&
                        m.GetParameters().Any(p => p.ParameterType == typeof(AuditLog)));

        // Assert
        removeMethods.Should().BeEmpty(
            "AuditDbContext must not expose Remove(AuditLog) - audit records cannot be deleted [AUD-02]");
    }

    [Fact]
    [Trait("Req", "AUD-02")]
    public void AuditService_OnlyHasLogAsyncMethod()
    {
        // Arrange
        var serviceType = typeof(AuditService);

        // Act - get all public instance methods (excluding inherited Object methods)
        var publicMethods = serviceType.GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly)
            .Select(m => m.Name)
            .ToList();

        // Assert - should only have LogAsync, no Update/Delete/Remove methods
        publicMethods.Should().NotContain("Update", "AuditService must not have Update method [AUD-02]");
        publicMethods.Should().NotContain("Delete", "AuditService must not have Delete method [AUD-02]");
        publicMethods.Should().NotContain("Remove", "AuditService must not have Remove method [AUD-02]");
        publicMethods.Should().Contain("LogAsync", "AuditService must expose LogAsync for INSERT operations");
    }

    [Fact]
    [Trait("Req", "AUD-02")]
    public void AuditDbContext_AuditLogsProperty_IsDbSet()
    {
        // Arrange
        var contextType = typeof(AuditDbContext);
        var auditLogsProperty = contextType.GetProperty("AuditLogs");

        // Assert
        auditLogsProperty.Should().NotBeNull("AuditDbContext must have AuditLogs property");
        auditLogsProperty!.PropertyType.Should().Be(typeof(DbSet<AuditLog>),
            "AuditLogs should be DbSet<AuditLog> for INSERT via Add()");
    }

    [Fact]
    [Trait("Req", "AUD-02")]
    public void AuditLog_HasNoSoftDeleteProperty()
    {
        // Arrange - soft delete would imply UPDATE capability
        var auditLogType = typeof(AuditLog);

        // Act
        var isDeletedProperty = auditLogType.GetProperty("IsDeleted");
        var deletedAtProperty = auditLogType.GetProperty("DeletedAt");

        // Assert
        isDeletedProperty.Should().BeNull(
            "AuditLog must not have IsDeleted - audit records cannot be soft-deleted [AUD-02]");
        deletedAtProperty.Should().BeNull(
            "AuditLog must not have DeletedAt - audit records cannot be soft-deleted [AUD-02]");
    }
}
