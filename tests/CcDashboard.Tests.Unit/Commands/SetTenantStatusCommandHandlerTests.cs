using CcDashboard.Application.Commands.Tenants;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

public class SetTenantStatusCommandHandlerTests
{
    private readonly ITenantRepository _repo = Substitute.For<ITenantRepository>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();
    private readonly SetTenantStatusCommandHandler _handler;

    private static readonly DateTime Now = new(2026, 5, 1, 14, 0, 0, DateTimeKind.Utc);

    public SetTenantStatusCommandHandlerTests()
    {
        _clock.UtcNow.Returns(Now);
        _handler = new SetTenantStatusCommandHandler(_repo, _clock);
    }

    [Fact]
    public async Task Handle_SuspendActiveTenant_UpdatesStatusAndTimestamp()
    {
        var id = Guid.NewGuid();
        var tenant = new Tenant
        {
            Id = id,
            Slug = "active-tenant",
            Name = "Active Tenant",
            Status = TenantStatus.Active,
            UpdatedAt = Now.AddDays(-10)
        };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(tenant);

        await _handler.Handle(new SetTenantStatusCommand(id, TenantStatus.Suspended), CancellationToken.None);

        tenant.Status.Should().Be(TenantStatus.Suspended);
        tenant.UpdatedAt.Should().Be(Now);
        _repo.Received(1).Update(tenant);
    }

    [Fact]
    public async Task Handle_ResumeSuspendedTenant_SetsActive()
    {
        var id = Guid.NewGuid();
        var tenant = new Tenant
        {
            Id = id,
            Slug = "suspended-tenant",
            Name = "Suspended Tenant",
            Status = TenantStatus.Suspended
        };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(tenant);

        await _handler.Handle(new SetTenantStatusCommand(id, TenantStatus.Active), CancellationToken.None);

        tenant.Status.Should().Be(TenantStatus.Active);
    }

    [Fact]
    public async Task Handle_DeleteTenant_SetsDeleted()
    {
        var id = Guid.NewGuid();
        var tenant = new Tenant
        {
            Id = id,
            Slug = "to-delete",
            Name = "To Delete",
            Status = TenantStatus.Suspended
        };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(tenant);

        await _handler.Handle(new SetTenantStatusCommand(id, TenantStatus.Deleted), CancellationToken.None);

        tenant.Status.Should().Be(TenantStatus.Deleted);
        tenant.UpdatedAt.Should().Be(Now);
    }

    [Fact]
    public async Task Handle_TenantNotFound_ThrowsKeyNotFoundException()
    {
        var id = Guid.NewGuid();
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns((Tenant?)null);

        var act = () => _handler.Handle(
            new SetTenantStatusCommand(id, TenantStatus.Suspended),
            CancellationToken.None);

        await act.Should().ThrowAsync<KeyNotFoundException>()
            .WithMessage($"*{id}*");
    }

    [Fact]
    public async Task Handle_SameStatus_StillUpdatesTimestamp()
    {
        var id = Guid.NewGuid();
        var tenant = new Tenant
        {
            Id = id,
            Slug = "already-active",
            Name = "Already Active",
            Status = TenantStatus.Active,
            UpdatedAt = Now.AddDays(-5)
        };
        _repo.GetByIdAsync(id, Arg.Any<CancellationToken>()).Returns(tenant);

        await _handler.Handle(new SetTenantStatusCommand(id, TenantStatus.Active), CancellationToken.None);

        tenant.UpdatedAt.Should().Be(Now);
        _repo.Received(1).Update(tenant);
    }
}
