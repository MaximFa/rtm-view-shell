using CcDashboard.Application.Commands.Tenants;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Exceptions;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using FluentValidation.TestHelper;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands.Tenants;

public class SwitchTenantCommandTests
{
    private readonly ICurrentUserAccessor _currentUser = Substitute.For<ICurrentUserAccessor>();
    private readonly ITenantContext _tenantContext = Substitute.For<ITenantContext>();
    private readonly ITenantRepository _tenants = Substitute.For<ITenantRepository>();
    private readonly IAuditService _auditService = Substitute.For<IAuditService>();
    private readonly SwitchTenantCommandHandler _handler;

    private static readonly Guid HomeTenantId = Guid.NewGuid();
    private static readonly Guid TargetTenantId = Guid.NewGuid();
    private static readonly Guid UserId = Guid.NewGuid();

    public SwitchTenantCommandTests()
    {
        _tenantContext.TenantId.Returns(HomeTenantId);
        _currentUser.UserId.Returns(UserId);
        _currentUser.UserName.Returns("admin@platform.local");

        _handler = new SwitchTenantCommandHandler(_currentUser, _tenantContext, _tenants, _auditService);
    }

    [Fact]
    public async Task Handle_NonSuperadmin_ThrowsForbiddenAndAuditsFailure()
    {
        // Arrange: Administrator (not Superadmin)
        _currentUser.Role.Returns("Administrator");

        var cmd = new SwitchTenantCommand(TargetTenantId);

        // Act
        var act = () => _handler.Handle(cmd, CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<ForbiddenException>()
            .WithMessage("*Superadmin*");

        // Verify Authorization.Failure audit was written
        await _auditService.Received(1).LogAsync(
            "Authorization.Failure",
            AuditEventResult.Failure,
            HomeTenantId,
            UserId,
            "admin@platform.local",
            Arg.Any<string?>(),
            Arg.Any<string?>(),
            Arg.Is<object>(d => d.ToString()!.Contains("TenantSwitchForbidden")),
            Arg.Any<CancellationToken>());

        // Verify NO Tenant.Switched audit
        await _auditService.DidNotReceive().LogAsync(
            "Tenant.Switched",
            Arg.Any<AuditEventResult>(),
            Arg.Any<Guid?>(),
            Arg.Any<Guid?>(),
            Arg.Any<string?>(),
            Arg.Any<string?>(),
            Arg.Any<string?>(),
            Arg.Any<object?>(),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Handle_Superadmin_TargetNotFound_ThrowsNotFoundException()
    {
        // Arrange
        _currentUser.Role.Returns("Superadmin");
        _tenants.GetByIdAsync(TargetTenantId, Arg.Any<CancellationToken>()).Returns((Tenant?)null);

        var cmd = new SwitchTenantCommand(TargetTenantId);

        // Act
        var act = () => _handler.Handle(cmd, CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<NotFoundException>()
            .WithMessage($"*{TargetTenantId}*");

        // Verify NO Tenant.Switched audit
        await _auditService.DidNotReceive().LogAsync(
            "Tenant.Switched",
            Arg.Any<AuditEventResult>(),
            Arg.Any<Guid?>(),
            Arg.Any<Guid?>(),
            Arg.Any<string?>(),
            Arg.Any<string?>(),
            Arg.Any<string?>(),
            Arg.Any<object?>(),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Handle_Superadmin_TargetSuspended_ThrowsDomainException()
    {
        // Arrange
        _currentUser.Role.Returns("Superadmin");
        var suspendedTenant = new Tenant
        {
            Id = TargetTenantId,
            Slug = "suspended-tenant",
            Name = "Suspended Corp",
            Status = TenantStatus.Suspended
        };
        _tenants.GetByIdAsync(TargetTenantId, Arg.Any<CancellationToken>()).Returns(suspendedTenant);

        var cmd = new SwitchTenantCommand(TargetTenantId);

        // Act
        var act = () => _handler.Handle(cmd, CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<DomainException>()
            .WithMessage("*not available*Suspended*");

        // Verify NO Tenant.Switched audit
        await _auditService.DidNotReceive().LogAsync(
            "Tenant.Switched",
            Arg.Any<AuditEventResult>(),
            Arg.Any<Guid?>(),
            Arg.Any<Guid?>(),
            Arg.Any<string?>(),
            Arg.Any<string?>(),
            Arg.Any<string?>(),
            Arg.Any<object?>(),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Handle_Superadmin_TargetActive_ReturnsResultAndAuditsSwitched()
    {
        // Arrange
        _currentUser.Role.Returns("Superadmin");
        var activeTenant = new Tenant
        {
            Id = TargetTenantId,
            Slug = "target-corp",
            Name = "Target Corp",
            Status = TenantStatus.Active
        };
        _tenants.GetByIdAsync(TargetTenantId, Arg.Any<CancellationToken>()).Returns(activeTenant);

        var cmd = new SwitchTenantCommand(TargetTenantId);

        // Act
        var result = await _handler.Handle(cmd, CancellationToken.None);

        // Assert
        result.TenantId.Should().Be(TargetTenantId);
        result.Slug.Should().Be("target-corp");
        result.Name.Should().Be("Target Corp");

        // Verify Tenant.Switched audit with from/to details
        await _auditService.Received(1).LogAsync(
            "Tenant.Switched",
            AuditEventResult.Success,
            TargetTenantId,
            UserId,
            "admin@platform.local",
            Arg.Any<string?>(),
            Arg.Any<string?>(),
            Arg.Is<object>(d => d.ToString()!.Contains(HomeTenantId.ToString()) && d.ToString()!.Contains(TargetTenantId.ToString())),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public void Validator_EmptyTargetTenantId_Invalid()
    {
        // Arrange
        var validator = new SwitchTenantCommandValidator();
        var cmd = new SwitchTenantCommand(Guid.Empty);

        // Act
        var result = validator.TestValidate(cmd);

        // Assert
        result.ShouldHaveValidationErrorFor(x => x.TargetTenantId)
            .WithErrorMessage("Target tenant ID is required.");
    }
}
