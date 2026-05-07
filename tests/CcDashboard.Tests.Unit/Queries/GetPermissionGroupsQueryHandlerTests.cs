using CcDashboard.Application.Interfaces;
using CcDashboard.Application.Queries.PermissionGroups;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Queries;

public class GetPermissionGroupsQueryHandlerTests
{
    private readonly IPermissionGroupRepository _repo = Substitute.For<IPermissionGroupRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly GetPermissionGroupsQueryHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public GetPermissionGroupsQueryHandlerTests()
    {
        _user.TenantId.Returns(TenantId);
        _handler = new GetPermissionGroupsQueryHandler(_repo, _user);
    }

    [Fact]
    public async Task Handle_ReturnsMappedDtos()
    {
        var pgId = Guid.NewGuid();
        var group = new PermissionGroup
        {
            Id = pgId,
            TenantId = TenantId,
            Name = "Agents",
            Description = "Agent group",
            IsActive = true,
            CreatedAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc),
            UpdatedAt = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)
        };
        group.MenuPermissions.Add(new MenuPermission { MenuKey = "menu.dashboards", TenantId = TenantId, PermissionGroupId = pgId });
        _repo.GetAllByTenantAsync(TenantId, Arg.Any<CancellationToken>()).Returns([group]);

        var result = await _handler.Handle(new GetPermissionGroupsQuery(), CancellationToken.None);

        result.Should().HaveCount(1);
        result[0].Id.Should().Be(pgId);
        result[0].Name.Should().Be("Agents");
        result[0].MenuPermissions.Should().ContainSingle("menu.dashboards");
    }

    [Fact]
    public async Task Handle_EmptyTenant_ReturnsEmptyList()
    {
        _repo.GetAllByTenantAsync(TenantId, Arg.Any<CancellationToken>())
            .Returns(Array.Empty<PermissionGroup>());

        var result = await _handler.Handle(new GetPermissionGroupsQuery(), CancellationToken.None);

        result.Should().BeEmpty();
    }
}
