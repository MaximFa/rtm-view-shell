using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.Configuration;
using CcDashboard.Domain.Domain;
using CcDashboard.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands.Configuration;

public class SaveSiteCommandHandlerTests
{
    private readonly INgcSiteRepository _repo = Substitute.For<INgcSiteRepository>();
    private readonly ICurrentUserAccessor _user = Substitute.For<ICurrentUserAccessor>();
    private readonly IConfigurationApiHook _apiHook = Substitute.For<IConfigurationApiHook>();
    private readonly SaveSiteCommandHandler _handler;

    private static readonly Guid TenantId = Guid.NewGuid();

    public SaveSiteCommandHandlerTests()
    {
        _user.TenantId.Returns(TenantId);
        _handler = new SaveSiteCommandHandler(_repo, _user, _apiHook);
    }

    [Fact]
    public async Task Handle_NewSite_CreatesAndNotifiesApi()
    {
        NgcSite? saved = null;
        await _repo.AddAsync(Arg.Do<NgcSite>(s => saved = s), Arg.Any<CancellationToken>());

        var req = new SaveSiteRequest("SITE-001", "Main Site", "Main office", "+03:00", "08:00", true);
        var result = await _handler.Handle(new SaveSiteCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        saved.Should().NotBeNull();
        saved!.SiteId.Should().Be("SITE-001");
        saved.SiteName.Should().Be("Main Site");
        saved.Description.Should().Be("Main office");
        saved.TimeZone.Should().Be("+03:00");
        saved.ClearTime.Should().Be("08:00");
        saved.TenantId.Should().Be(TenantId);

        await _apiHook.Received(1).NotifyAsync("Site", Arg.Any<object>(), Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Handle_UpdateSite_ModifiesExisting()
    {
        var existing = new NgcSite
        {
            SiteId = "SITE-002",
            TenantId = TenantId,
            SiteName = "Old Name",
            Description = "Old desc"
        };
        _repo.GetByIdAsync("SITE-002", TenantId, Arg.Any<CancellationToken>()).Returns(existing);

        var req = new SaveSiteRequest("SITE-002", "New Name", "New desc", "+05:00", "09:00", false);
        var result = await _handler.Handle(new SaveSiteCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        existing.SiteName.Should().Be("New Name");
        existing.Description.Should().Be("New desc");
        existing.TimeZone.Should().Be("+05:00");
        existing.ClearTime.Should().Be("09:00");
        _repo.Received(1).Update(existing);
    }

    [Fact]
    public async Task Handle_UpdateNonExistent_ReturnsFailure()
    {
        _repo.GetByIdAsync("MISSING", TenantId, Arg.Any<CancellationToken>()).Returns((NgcSite?)null);

        var req = new SaveSiteRequest("MISSING", "Name", null, null, null, false);
        var result = await _handler.Handle(new SaveSiteCommand(req), CancellationToken.None);

        result.IsSuccess.Should().BeFalse();
        result.Error.Should().Contain("not found");
    }

    [Fact]
    public async Task Handle_TrimsWhitespace()
    {
        NgcSite? saved = null;
        await _repo.AddAsync(Arg.Do<NgcSite>(s => saved = s), Arg.Any<CancellationToken>());

        var req = new SaveSiteRequest("  SITE-003  ", "  Trimmed  ", "  Desc  ", "  +02:00  ", "  07:00  ", true);
        await _handler.Handle(new SaveSiteCommand(req), CancellationToken.None);

        saved!.SiteId.Should().Be("SITE-003");
        saved.SiteName.Should().Be("Trimmed");
        saved.Description.Should().Be("Desc");
        saved.TimeZone.Should().Be("+02:00");
        saved.ClearTime.Should().Be("07:00");
    }
}
