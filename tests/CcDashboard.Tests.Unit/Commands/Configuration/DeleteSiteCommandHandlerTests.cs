using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands.Configuration;

public class DeleteSiteCommandHandlerTests
{
    private readonly INgcSiteRepository _repo = Substitute.For<INgcSiteRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly DeleteSiteCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public DeleteSiteCommandHandlerTests()
    {
        _user.TenantId.Returns(TenantId);
        _handler = new DeleteSiteCommandHandler(_repo, _user);
    }

    [Fact]
    public async Task Handle_ExistingSite_DeletesSuccessfully()
    {
        var site = new NgcSite { SiteId = "SITE-DEL", TenantId = TenantId, SiteName = "To Delete" };
        _repo.GetByIdAsync("SITE-DEL", TenantId, Arg.Any<CancellationToken>()).Returns(site);

        var result = await _handler.Handle(new DeleteSiteCommand("SITE-DEL"), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        _repo.Received(1).Delete(site);
    }

    [Fact]
    public async Task Handle_NonExistent_ReturnsFailure()
    {
        _repo.GetByIdAsync("MISSING", TenantId, Arg.Any<CancellationToken>()).Returns((NgcSite?)null);

        var result = await _handler.Handle(new DeleteSiteCommand("MISSING"), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
        _repo.DidNotReceive().Delete(Arg.Any<NgcSite>());
    }
}
