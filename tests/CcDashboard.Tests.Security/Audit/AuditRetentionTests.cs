using CcDashboard.Domain.Domain;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;

namespace CcDashboard.Tests.Security.Audit;

/// <summary>
/// DoD-B7: Retention config read (AUD-03).
/// Per CLAUDE.md §16: "Audit retention: 365 days (tenant-configurable)."
/// Full retention purge background service is out of scope for T6.
/// </summary>
[Collection("Postgres")]
public class AuditRetentionTests
{
    private readonly PostgresFixture _fixture;

    public AuditRetentionTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    [Trait("Req", "AUD-03")]
    public void TenantSettings_HasAuditRetentionDaysProperty()
    {
        // Arrange
        var settingsType = typeof(TenantSettings);

        // Act
        var property = settingsType.GetProperty(nameof(TenantSettings.AuditRetentionDays));

        // Assert
        property.Should().NotBeNull("TenantSettings must have AuditRetentionDays property [AUD-03]");
        property!.PropertyType.Should().Be(typeof(int));
    }

    [Fact]
    [Trait("Req", "AUD-03")]
    public void TenantSettings_AuditRetentionDays_DefaultsTo365()
    {
        // Arrange
        var settings = new TenantSettings();

        // Assert
        settings.AuditRetentionDays.Should().Be(365,
            "Default audit retention should be 365 days per CLAUDE.md §16 [AUD-03]");
    }

    [Fact]
    [Trait("Req", "AUD-03")]
    public async Task TenantSettings_AuditRetentionDays_IsPersisted()
    {
        // Arrange
        await using var db = _fixture.CreateDbContext(_fixture.TenantAId);

        // Act
        var settings = await db.TenantSettings
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.TenantId == _fixture.TenantAId);

        // Assert
        settings.Should().NotBeNull("TenantSettings should exist for test tenant");
        settings!.AuditRetentionDays.Should().BeGreaterThan(0,
            "AuditRetentionDays should be readable from database [AUD-03]");
    }

    [Fact]
    [Trait("Req", "AUD-03")]
    public async Task TenantSettings_AuditRetentionDays_CanBeUpdated()
    {
        // Arrange
        var testTenantId = UUIDNext.Uuid.NewSequential();
        await using var db = _fixture.CreateDbContext(_fixture.PlatformTenantId);

        // Create a test tenant with custom retention
        var tenant = new Tenant
        {
            Id = testTenantId,
            Slug = $"retention-test-{testTenantId:N}"[..20],
            Name = "Retention Test Tenant",
            Status = Domain.Enums.TenantStatus.Active,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        db.Tenants.Add(tenant);

        var settings = new TenantSettings
        {
            TenantId = testTenantId,
            DefaultLocale = "en-US",
            AuditRetentionDays = 180 // Custom retention
        };
        db.TenantSettings.Add(settings);
        await db.SaveChangesAsync();

        // Act - verify it was saved
        await using var verifyDb = _fixture.CreateDbContext(_fixture.PlatformTenantId);
        var loaded = await verifyDb.TenantSettings
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(s => s.TenantId == testTenantId);

        // Assert
        loaded.Should().NotBeNull();
        loaded!.AuditRetentionDays.Should().Be(180,
            "Custom audit retention days should be persisted [AUD-03]");

        // Cleanup
        verifyDb.TenantSettings.Remove(loaded);
        var tenantToRemove = await verifyDb.Tenants.IgnoreQueryFilters()
            .FirstOrDefaultAsync(t => t.Id == testTenantId);
        if (tenantToRemove != null)
            verifyDb.Tenants.Remove(tenantToRemove);
        await verifyDb.SaveChangesAsync();
    }

    [Theory]
    [Trait("Req", "AUD-03")]
    [InlineData(30)]
    [InlineData(90)]
    [InlineData(365)]
    [InlineData(730)]
    public void TenantSettings_AuditRetentionDays_AcceptsVariousValues(int days)
    {
        // Arrange
        var settings = new TenantSettings();

        // Act
        settings.AuditRetentionDays = days;

        // Assert
        settings.AuditRetentionDays.Should().Be(days,
            $"AuditRetentionDays should accept {days} days [AUD-03]");
    }
}
