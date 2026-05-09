using CcDashboard.Application.Commands.Tenants;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Tenants;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Enums;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

public class CreateTenantCommandHandlerTests
{
    private readonly ITenantRepository _repo = Substitute.For<ITenantRepository>();
    private readonly IDateTimeProvider _clock = Substitute.For<IDateTimeProvider>();
    private readonly CreateTenantCommandHandler _handler;

    private static readonly DateTime Now = new(2026, 4, 1, 9, 0, 0, DateTimeKind.Utc);

    public CreateTenantCommandHandlerTests()
    {
        _clock.UtcNow.Returns(Now);
        _handler = new CreateTenantCommandHandler(_repo, _clock);
    }

    [Fact]
    public async Task Handle_ValidRequest_CreatesTenantWithActiveStatus()
    {
        Tenant? saved = null;
        await _repo.AddAsync(Arg.Do<Tenant>(t => saved = t), Arg.Any<CancellationToken>());

        var req = new CreateTenantRequest("acme-corp", "Acme Corporation");
        var result = await _handler.Handle(new CreateTenantCommand(req), CancellationToken.None);

        result.Should().NotBeNull();
        result.Slug.Should().Be("acme-corp");
        result.Name.Should().Be("Acme Corporation");
        result.Status.Should().Be(TenantStatus.Active);
        result.CreatedAt.Should().Be(Now);
        result.UpdatedAt.Should().Be(Now);

        saved.Should().NotBeNull();
        saved!.Id.Should().NotBeEmpty();
    }

    [Fact]
    public async Task Handle_TrimsAndLowercasesSlug()
    {
        Tenant? saved = null;
        await _repo.AddAsync(Arg.Do<Tenant>(t => saved = t), Arg.Any<CancellationToken>());

        var req = new CreateTenantRequest("  UPPER-Case  ", "Some Tenant");
        await _handler.Handle(new CreateTenantCommand(req), CancellationToken.None);

        saved!.Slug.Should().Be("upper-case");
    }

    [Fact]
    public async Task Handle_TrimsName()
    {
        Tenant? saved = null;
        await _repo.AddAsync(Arg.Do<Tenant>(t => saved = t), Arg.Any<CancellationToken>());

        var req = new CreateTenantRequest("slug", "  Name With Spaces  ");
        await _handler.Handle(new CreateTenantCommand(req), CancellationToken.None);

        saved!.Name.Should().Be("Name With Spaces");
    }

    [Fact]
    public async Task Handle_GeneratesUniqueId()
    {
        var ids = new List<Guid>();
        await _repo.AddAsync(Arg.Do<Tenant>(t => ids.Add(t.Id)), Arg.Any<CancellationToken>());

        await _handler.Handle(new CreateTenantCommand(new("a", "A")), CancellationToken.None);
        await _handler.Handle(new CreateTenantCommand(new("b", "B")), CancellationToken.None);

        ids.Should().HaveCount(2);
        ids[0].Should().NotBe(ids[1]);
        ids.All(id => id != Guid.Empty).Should().BeTrue();
    }
}
