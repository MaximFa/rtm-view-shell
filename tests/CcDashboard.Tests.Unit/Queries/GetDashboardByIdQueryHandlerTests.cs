using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Queries.Dashboards;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Queries;

public class GetDashboardByIdQueryHandlerTests
{
    private readonly IDashboardRepository _repo = Substitute.For<IDashboardRepository>();
    private readonly GetDashboardByIdQueryHandler _handler;

    public GetDashboardByIdQueryHandlerTests()
    {
        _handler = new GetDashboardByIdQueryHandler(_repo);
    }

    [Fact]
    public async Task Handle_ExistingDashboard_ReturnsMappedDto()
    {
        var id = Guid.NewGuid();
        var tenantId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        var now = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc);

        var dashboard = new Dashboard
        {
            Id = id,
            TenantId = tenantId,
            Name = "Ops Monitor",
            Description = "Real-time view",
            Status = DashboardStatus.Published,
            IsPublic = true,
            CreatedByUserId = userId,
            CreatedAt = now,
            UpdatedAt = now,
            RowVersion = 5
        };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(dashboard);

        var result = await _handler.Handle(new GetDashboardByIdQuery(id), CancellationToken.None);

        result.Should().NotBeNull();
        result!.Id.Should().Be(id);
        result.Name.Should().Be("Ops Monitor");
        result.IsPublic.Should().BeTrue();
        result.RowVersion.Should().Be(5);
    }

    [Fact]
    public async Task Handle_NotFound_ReturnsNull()
    {
        var id = Guid.NewGuid();
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns((Dashboard?)null);

        var result = await _handler.Handle(new GetDashboardByIdQuery(id), CancellationToken.None);

        result.Should().BeNull();
    }
}
