using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Queries.Audit;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using CcDashboard.Infrastructure.Audit;
using CcDashboard.Infrastructure.Persistence.Repositories;
using CcDashboard.Tests.Security.Fixtures;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using UUIDNext;

namespace CcDashboard.Tests.Security.Audit;

/// <summary>
/// DoD-B5: Role-aware audit log scoping (AUD-06).
/// Per CLAUDE.md §16: "Audit log query (AUD-06): role-aware scoping: Admin sees own tenant;
/// Superadmin sees all; tenant filter param."
/// </summary>
[Collection("Postgres")]
public class AuditScopingTests : IAsyncLifetime
{
    private readonly PostgresFixture _fixture;
    private readonly List<Guid> _testAuditLogIds = new();

    public AuditScopingTests(PostgresFixture fixture)
    {
        _fixture = fixture;
    }

    public async Task InitializeAsync()
    {
        // Seed audit logs for different tenants
        await using var auditDb = _fixture.CreateAuditDbContext();
        var clock = new TestDateTimeProvider();

        var tenantALog = new AuditLog
        {
            Id = Uuid.NewSequential(),
            TenantId = _fixture.TenantAId,
            UserId = _fixture.UserAId,
            UserName = "user.a@tenant-a.local",
            EventType = "Test.ScopingA",
            EventResult = AuditEventResult.Success,
            IpAddress = "127.0.0.1",
            CreatedAt = clock.UtcNow
        };

        var tenantBLog = new AuditLog
        {
            Id = Uuid.NewSequential(),
            TenantId = _fixture.TenantBId,
            UserId = _fixture.UserBId,
            UserName = "user.b@tenant-b.local",
            EventType = "Test.ScopingB",
            EventResult = AuditEventResult.Success,
            IpAddress = "127.0.0.1",
            CreatedAt = clock.UtcNow
        };

        var platformLog = new AuditLog
        {
            Id = Uuid.NewSequential(),
            TenantId = _fixture.PlatformTenantId,
            UserId = _fixture.SuperadminId,
            UserName = "superadmin@platform.local",
            EventType = "Test.ScopingPlatform",
            EventResult = AuditEventResult.Success,
            IpAddress = "127.0.0.1",
            CreatedAt = clock.UtcNow
        };

        auditDb.AuditLogs.AddRange(tenantALog, tenantBLog, platformLog);
        await auditDb.SaveChangesAsync();

        _testAuditLogIds.AddRange([tenantALog.Id, tenantBLog.Id, platformLog.Id]);
    }

    public async Task DisposeAsync()
    {
        await using var auditDb = _fixture.CreateAuditDbContext();
        var logsToRemove = await auditDb.AuditLogs
            .Where(l => _testAuditLogIds.Contains(l.Id) ||
                       l.EventType.StartsWith("Test.Scoping"))
            .ToListAsync();

        if (logsToRemove.Any())
        {
            auditDb.AuditLogs.RemoveRange(logsToRemove);
            await auditDb.SaveChangesAsync();
        }
    }

    [Fact]
    [Trait("Req", "AUD-06")]
    public async Task GetAuditLogs_AsAdministrator_ReturnsOnlyOwnTenantLogs()
    {
        // Arrange
        await using var auditDb = _fixture.CreateAuditDbContext();
        var repo = new AuditLogRepository(auditDb);

        var currentUserMock = new Mock<ICurrentUserAccessor>();
        currentUserMock.Setup(c => c.Role).Returns("Administrator");
        currentUserMock.Setup(c => c.TenantId).Returns(_fixture.TenantAId);

        var handler = new GetAuditLogsQueryHandler(repo, currentUserMock.Object);
        var query = new GetAuditLogsQuery();

        // Act
        var result = await handler.Handle(query, CancellationToken.None);

        // Assert
        result.Items.Should().NotBeEmpty();
        result.Items.Should().OnlyContain(l => l.TenantId == _fixture.TenantAId,
            "Administrator should only see logs from their own tenant [AUD-06]");
        result.Items.Should().NotContain(l => l.TenantId == _fixture.TenantBId,
            "Administrator must not see other tenants' logs");
    }

    [Fact]
    [Trait("Req", "AUD-06")]
    public async Task GetAuditLogs_AsSuperadmin_WithNoTenantFilter_ReturnsAllTenantLogs()
    {
        // Arrange
        await using var auditDb = _fixture.CreateAuditDbContext();
        var repo = new AuditLogRepository(auditDb);

        var currentUserMock = new Mock<ICurrentUserAccessor>();
        currentUserMock.Setup(c => c.Role).Returns("Superadmin");
        currentUserMock.Setup(c => c.TenantId).Returns(_fixture.PlatformTenantId);

        var handler = new GetAuditLogsQueryHandler(repo, currentUserMock.Object);
        var query = new GetAuditLogsQuery(); // No TenantId filter

        // Act
        var result = await handler.Handle(query, CancellationToken.None);

        // Assert
        result.Items.Should().NotBeEmpty();
        var tenantIds = result.Items.Select(l => l.TenantId).Distinct().ToList();
        tenantIds.Count.Should().BeGreaterThan(1,
            "Superadmin with no tenant filter should see logs from multiple tenants [AUD-06]");
    }

    [Fact]
    [Trait("Req", "AUD-06")]
    public async Task GetAuditLogs_AsSuperadmin_WithTenantFilter_ReturnsOnlyFilteredTenant()
    {
        // Arrange
        await using var auditDb = _fixture.CreateAuditDbContext();
        var repo = new AuditLogRepository(auditDb);

        var currentUserMock = new Mock<ICurrentUserAccessor>();
        currentUserMock.Setup(c => c.Role).Returns("Superadmin");
        currentUserMock.Setup(c => c.TenantId).Returns(_fixture.PlatformTenantId);

        var handler = new GetAuditLogsQueryHandler(repo, currentUserMock.Object);
        var query = new GetAuditLogsQuery(TenantId: _fixture.TenantBId); // Filter to TenantB

        // Act
        var result = await handler.Handle(query, CancellationToken.None);

        // Assert
        result.Items.Should().NotBeEmpty();
        result.Items.Should().OnlyContain(l => l.TenantId == _fixture.TenantBId,
            "Superadmin with tenant filter should only see that tenant's logs [AUD-06]");
    }

    [Fact]
    [Trait("Req", "AUD-06")]
    public async Task GetAuditLogs_AsEditor_ReturnsOnlyOwnTenantLogs()
    {
        // Arrange - Editor role should behave like Administrator (own tenant only)
        await using var auditDb = _fixture.CreateAuditDbContext();
        var repo = new AuditLogRepository(auditDb);

        var currentUserMock = new Mock<ICurrentUserAccessor>();
        currentUserMock.Setup(c => c.Role).Returns("Editor");
        currentUserMock.Setup(c => c.TenantId).Returns(_fixture.TenantAId);

        var handler = new GetAuditLogsQueryHandler(repo, currentUserMock.Object);
        var query = new GetAuditLogsQuery();

        // Act
        var result = await handler.Handle(query, CancellationToken.None);

        // Assert
        result.Items.Should().OnlyContain(l => l.TenantId == _fixture.TenantAId,
            "Non-Superadmin roles should only see own tenant logs [AUD-06]");
    }

    [Fact]
    [Trait("Req", "AUD-06")]
    public async Task GetAuditLogs_WithEventTypeFilter_FiltersCorrectly()
    {
        // Arrange
        await using var auditDb = _fixture.CreateAuditDbContext();
        var repo = new AuditLogRepository(auditDb);

        var currentUserMock = new Mock<ICurrentUserAccessor>();
        currentUserMock.Setup(c => c.Role).Returns("Superadmin");
        currentUserMock.Setup(c => c.TenantId).Returns(_fixture.PlatformTenantId);

        var handler = new GetAuditLogsQueryHandler(repo, currentUserMock.Object);
        var query = new GetAuditLogsQuery(EventType: "Test.ScopingA");

        // Act
        var result = await handler.Handle(query, CancellationToken.None);

        // Assert
        result.Items.Should().OnlyContain(l => l.EventType == "Test.ScopingA",
            "EventType filter should work correctly");
    }

    [Fact]
    [Trait("Req", "AUD-06")]
    public async Task GetAuditLogs_WithDateRangeFilter_FiltersCorrectly()
    {
        // Arrange
        await using var auditDb = _fixture.CreateAuditDbContext();
        var repo = new AuditLogRepository(auditDb);

        var currentUserMock = new Mock<ICurrentUserAccessor>();
        currentUserMock.Setup(c => c.Role).Returns("Superadmin");
        currentUserMock.Setup(c => c.TenantId).Returns(_fixture.PlatformTenantId);

        var handler = new GetAuditLogsQueryHandler(repo, currentUserMock.Object);
        var fromDate = DateTime.UtcNow.AddDays(-1);
        var toDate = DateTime.UtcNow.AddDays(1);
        var query = new GetAuditLogsQuery(From: fromDate, To: toDate);

        // Act
        var result = await handler.Handle(query, CancellationToken.None);

        // Assert
        result.Items.Should().OnlyContain(l => l.CreatedAt >= fromDate && l.CreatedAt <= toDate,
            "Date range filter should work correctly");
    }

    [Fact]
    [Trait("Req", "AUD-06")]
    public async Task GetAuditLogs_Pagination_ReturnsCorrectPage()
    {
        // Arrange
        await using var auditDb = _fixture.CreateAuditDbContext();
        var repo = new AuditLogRepository(auditDb);

        var currentUserMock = new Mock<ICurrentUserAccessor>();
        currentUserMock.Setup(c => c.Role).Returns("Superadmin");
        currentUserMock.Setup(c => c.TenantId).Returns(_fixture.PlatformTenantId);

        var handler = new GetAuditLogsQueryHandler(repo, currentUserMock.Object);
        var query = new GetAuditLogsQuery(Page: 1, PageSize: 2);

        // Act
        var result = await handler.Handle(query, CancellationToken.None);

        // Assert
        result.Items.Count.Should().BeLessThanOrEqualTo(2,
            "Page size should be respected");
        result.Page.Should().Be(1);
        result.PageSize.Should().Be(2);
    }

    [Fact]
    [Trait("Req", "AUD-06")]
    public async Task GetDistinctEventTypes_AsAdministrator_ReturnsOnlyOwnTenantEventTypes()
    {
        // Arrange
        await using var auditDb = _fixture.CreateAuditDbContext();
        var repo = new AuditLogRepository(auditDb);

        var currentUserMock = new Mock<ICurrentUserAccessor>();
        currentUserMock.Setup(c => c.Role).Returns("Administrator");
        currentUserMock.Setup(c => c.TenantId).Returns(_fixture.TenantAId);

        var handler = new GetDistinctAuditEventTypesQueryHandler(repo, currentUserMock.Object);
        var query = new GetDistinctAuditEventTypesQuery();

        // Act
        var result = await handler.Handle(query, CancellationToken.None);

        // Assert - should include TenantA's event type but not TenantB's
        result.Should().Contain("Test.ScopingA",
            "Administrator should see event types from own tenant");
        result.Should().NotContain("Test.ScopingB",
            "Administrator should not see event types from other tenants [AUD-06]");
    }
}
