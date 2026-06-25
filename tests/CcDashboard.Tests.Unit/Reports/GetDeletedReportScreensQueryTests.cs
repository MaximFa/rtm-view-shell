using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Reports.Interfaces;
using CcDashboard.Application.Reports.Queries;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Domain.Reports;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Reports;

/// <summary>
/// Tests for GetDeletedReportScreensQuery — Trash list (mirrors GetDeletedDashboardsQuery).
/// </summary>
public class GetDeletedReportScreensQueryTests
{
    private static readonly Guid TenantId = Guid.NewGuid();
    private static readonly Guid UserId = Guid.NewGuid();

    private readonly IReportScreenRepository _repo = Substitute.For<IReportScreenRepository>();
    private readonly IUserRepository _users = Substitute.For<IUserRepository>();
    private readonly ITenantSettingsRepository _tenantSettings = Substitute.For<ITenantSettingsRepository>();
    private readonly ICurrentUserAccessor _currentUser = Substitute.For<ICurrentUserAccessor>();

    public GetDeletedReportScreensQueryTests()
    {
        _currentUser.TenantId.Returns(TenantId);
        _currentUser.UserId.Returns(UserId);
        _currentUser.Role.Returns("Administrator");
    }

    [Fact]
    public async Task ReturnsEmpty_WhenSoftDeleteDisabled()
    {
        _tenantSettings.GetByTenantAsync(TenantId, Arg.Any<CancellationToken>())
            .Returns(new TenantSettings { TenantId = TenantId, SoftDeleteDashboards = false });

        var handler = new GetDeletedReportScreensQueryHandler(_repo, _users, _tenantSettings, _currentUser);
        var query = new GetDeletedReportScreensQuery(null);

        var result = await handler.Handle(query, CancellationToken.None);

        result.Items.Should().BeEmpty();
        result.TotalCount.Should().Be(0);
    }

    [Fact]
    public async Task ReturnsDeletedScreens_WhenSoftDeleteEnabled()
    {
        var settings = new TenantSettings
        {
            TenantId = TenantId,
            SoftDeleteDashboards = true,
            SoftDeleteRetentionDays = 30
        };
        _tenantSettings.GetByTenantAsync(TenantId, Arg.Any<CancellationToken>()).Returns(settings);

        var deletedByUser = Guid.NewGuid();
        var deletedScreens = new List<ReportScreen>
        {
            new()
            {
                Id = Guid.NewGuid(),
                TenantId = TenantId,
                Name = "Deleted Report 1",
                Description = "Test description",
                IsDeleted = true,
                DeletedAt = DateTime.UtcNow.AddDays(-5),
                DeletedByUserId = deletedByUser
            },
            new()
            {
                Id = Guid.NewGuid(),
                TenantId = TenantId,
                Name = "Deleted Report 2",
                IsDeleted = true,
                DeletedAt = DateTime.UtcNow.AddDays(-10),
                DeletedByUserId = deletedByUser
            }
        };

        _repo.GetDeletedPageAsync(TenantId, null, 1, 25, Arg.Any<CancellationToken>())
            .Returns((deletedScreens, 2));

        _users.GetByIdAsync(deletedByUser, Arg.Any<CancellationToken>())
            .Returns(new ApplicationUserSnapshot(
                deletedByUser, TenantId, "johndoe", "john@test.com", "John", "Doe",
                "Administrator", null, true, false, null, "en-US", null, DateTime.UtcNow,
                null, 0, null, false));

        var handler = new GetDeletedReportScreensQueryHandler(_repo, _users, _tenantSettings, _currentUser);
        var query = new GetDeletedReportScreensQuery(null);

        var result = await handler.Handle(query, CancellationToken.None);

        result.Items.Should().HaveCount(2);
        result.TotalCount.Should().Be(2);
        result.Items[0].Name.Should().Be("Deleted Report 1");
        result.Items[0].DeletedByName.Should().Be("John Doe");
        result.Items[0].DaysUntilPermanentDelete.Should().BeGreaterThan(0);
    }

    [Fact]
    public async Task CalculatesDaysUntilPermanentDelete_Correctly()
    {
        var settings = new TenantSettings
        {
            TenantId = TenantId,
            SoftDeleteDashboards = true,
            SoftDeleteRetentionDays = 30
        };
        _tenantSettings.GetByTenantAsync(TenantId, Arg.Any<CancellationToken>()).Returns(settings);

        var deletedAt = DateTime.UtcNow.AddDays(-10);
        var deletedScreens = new List<ReportScreen>
        {
            new()
            {
                Id = Guid.NewGuid(),
                TenantId = TenantId,
                Name = "Test Report",
                IsDeleted = true,
                DeletedAt = deletedAt,
                DeletedByUserId = null
            }
        };

        _repo.GetDeletedPageAsync(TenantId, null, 1, 25, Arg.Any<CancellationToken>())
            .Returns((deletedScreens, 1));

        var handler = new GetDeletedReportScreensQueryHandler(_repo, _users, _tenantSettings, _currentUser);
        var query = new GetDeletedReportScreensQuery(null);

        var result = await handler.Handle(query, CancellationToken.None);

        // Deleted 10 days ago, retention 30 days = 20 days remaining
        result.Items[0].DaysUntilPermanentDelete.Should().BeInRange(19, 21);
    }

    [Fact]
    public async Task TenantScoped_OnlyReturnsCurrentTenantScreens()
    {
        var settings = new TenantSettings
        {
            TenantId = TenantId,
            SoftDeleteDashboards = true,
            SoftDeleteRetentionDays = 30
        };
        _tenantSettings.GetByTenantAsync(TenantId, Arg.Any<CancellationToken>()).Returns(settings);

        // The repo call is scoped to TenantId
        _repo.GetDeletedPageAsync(TenantId, null, 1, 25, Arg.Any<CancellationToken>())
            .Returns((new List<ReportScreen>(), 0));

        var handler = new GetDeletedReportScreensQueryHandler(_repo, _users, _tenantSettings, _currentUser);
        var query = new GetDeletedReportScreensQuery(null);

        await handler.Handle(query, CancellationToken.None);

        // Verify repo was called with correct tenant ID
        await _repo.Received(1).GetDeletedPageAsync(TenantId, null, 1, 25, Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Paged_ReturnsCorrectPageInfo()
    {
        var settings = new TenantSettings
        {
            TenantId = TenantId,
            SoftDeleteDashboards = true,
            SoftDeleteRetentionDays = 30
        };
        _tenantSettings.GetByTenantAsync(TenantId, Arg.Any<CancellationToken>()).Returns(settings);

        _repo.GetDeletedPageAsync(TenantId, null, 2, 10, Arg.Any<CancellationToken>())
            .Returns((new List<ReportScreen>(), 25));

        var handler = new GetDeletedReportScreensQueryHandler(_repo, _users, _tenantSettings, _currentUser);
        var query = new GetDeletedReportScreensQuery(null, Page: 2, PageSize: 10);

        var result = await handler.Handle(query, CancellationToken.None);

        result.Page.Should().Be(2);
        result.PageSize.Should().Be(10);
        result.TotalCount.Should().Be(25);
    }

    [Fact]
    public async Task Search_PassesSearchTermToRepo()
    {
        var settings = new TenantSettings
        {
            TenantId = TenantId,
            SoftDeleteDashboards = true,
            SoftDeleteRetentionDays = 30
        };
        _tenantSettings.GetByTenantAsync(TenantId, Arg.Any<CancellationToken>()).Returns(settings);

        _repo.GetDeletedPageAsync(TenantId, "test", 1, 25, Arg.Any<CancellationToken>())
            .Returns((new List<ReportScreen>(), 0));

        var handler = new GetDeletedReportScreensQueryHandler(_repo, _users, _tenantSettings, _currentUser);
        var query = new GetDeletedReportScreensQuery("test");

        await handler.Handle(query, CancellationToken.None);

        await _repo.Received(1).GetDeletedPageAsync(TenantId, "test", 1, 25, Arg.Any<CancellationToken>());
    }
}
