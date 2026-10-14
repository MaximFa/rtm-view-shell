using CcDashboard.Application.Commands.TenantSettings;
using CcDashboard.Application.Interfaces;
using CcDashboard.Contracts.DTOs.TenantSettings;
using CcDashboard.Domain.Interfaces;
using TenantSettingsEntity = CcDashboard.Domain.Domain.TenantSettings;
using FluentAssertions;
using NSubstitute;

namespace CcDashboard.Tests.Unit.Commands;

/// <summary>
/// WfmServingStateGroups is the only setting on this handler where an empty list is a meaningful
/// value ("no groups configured") rather than "field not sent". The old line collapsed the two with
/// `is { Count: > 0 }`, so clearing every checkbox in the UI was silently discarded.
/// These tests pin both halves: an empty list is stored, a null leaves the stored value alone.
/// </summary>
public class UpdateTenantSettingsWfmGroupsTests
{
    private readonly ITenantSettingsRepository _repo = Substitute.For<ITenantSettingsRepository>();
    private readonly ICurrentUserAccessor _currentUser = Substitute.For<ICurrentUserAccessor>();
    private readonly UpdateTenantSettingsCommandHandler _handler;

    private static readonly Guid TenantId = Guid.Parse("11111111-1111-1111-1111-111111111111");

    public UpdateTenantSettingsWfmGroupsTests()
    {
        _currentUser.TenantId.Returns(TenantId);
        _currentUser.Role.Returns("Admin");
        _handler = new UpdateTenantSettingsCommandHandler(_repo, _currentUser);
    }

    [Fact]
    public async Task EmptyList_IsStoredAsEmpty_NotSilentlyIgnored()
    {
        // THE defect: operator unticks every group, save reports success, old groups come back.
        var stored = Existing(new[] { "Available", "On Phone" });
        _repo.GetByTenantAsync(TenantId, Arg.Any<CancellationToken>()).Returns(stored);

        await _handler.Handle(new UpdateTenantSettingsCommand(Request(new List<string>())), default);

        stored.WfmServingStateGroups.Should().BeEmpty();
        await _repo.Received(1).UpsertAsync(stored, Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Null_LeavesStoredValueUntouched()
    {
        // NEGATIVE half: a fix that simply always assigns would wipe the setting for any caller
        // that does not send the field, and would pass the test above.
        var stored = Existing(new[] { "Available", "On Phone" });
        _repo.GetByTenantAsync(TenantId, Arg.Any<CancellationToken>()).Returns(stored);

        await _handler.Handle(new UpdateTenantSettingsCommand(Request(null)), default);

        stored.WfmServingStateGroups.Should().Equal("Available", "On Phone");
    }

    [Fact]
    public async Task NonEmptyList_IsStoredVerbatim_CaseAndOrderKept()
    {
        // The WFM comparison is character-for-character, so normalising here would break it.
        var stored = Existing(new[] { "Available" });
        _repo.GetByTenantAsync(TenantId, Arg.Any<CancellationToken>()).Returns(stored);

        await _handler.Handle(
            new UpdateTenantSettingsCommand(Request(new List<string> { "ON PHONE", "AVAILABLE" })),
            default);

        stored.WfmServingStateGroups.Should().Equal("ON PHONE", "AVAILABLE");
    }

    [Fact]
    public async Task OtherWfmFields_AreUnaffectedByThisChange()
    {
        // Regression guard: the edit touches one line, so the neighbouring settings must still land.
        var stored = Existing(new[] { "Available" });
        _repo.GetByTenantAsync(TenantId, Arg.Any<CancellationToken>()).Returns(stored);

        await _handler.Handle(new UpdateTenantSettingsCommand(Request(new List<string>())), default);

        // Stored was 5 / 55 / 5 / false; the request carries 30 / 80 / 20 / true. Equality with the
        // request proves assignment happened, not that the object was merely constructed.
        stored.WfmWindowMinutes.Should().Be(30);
        stored.WfmSlTargetPct.Should().Be(80);
        stored.WfmSlThresholdSec.Should().Be(20);
        stored.WfmEnableRealtime.Should().BeTrue();
    }

    // ── helpers ──────────────────────────────────────────────────────────────────

    private static TenantSettingsEntity Existing(string[] groups) => new()
    {
        TenantId = TenantId,
        WfmServingStateGroups = groups,
        // Deliberately NOT the domain defaults (30 / 80 / 20 / true): the neighbouring-fields test
        // must fail if the handler stops assigning them. With the defaults here it would pass even
        // against a handler that assigns nothing — a false green.
        WfmWindowMinutes = 5,
        WfmSlTargetPct = 55,
        WfmSlThresholdSec = 5,
        WfmEnableRealtime = false
    };

    private static UpdateTenantSettingsRequest Request(List<string>? groups) => new(
        PasswordMinLength: 12,
        PasswordExpireDays: 90,
        Require2faForAll: false,
        AuditRetentionDays: 365,
        DefaultLocale: "en-US",
        SoftDeleteDashboards: true,
        SoftDeleteRetentionDays: 30,
        PurchasedLicences: 10,
        MaxConcurrentConnections: 10,
        SignalRConnectionUrl: null,
        BackgroundColorPalette: null,
        FontColorPalette: null,
        FontSizes: null,
        WfmServingStateGroups: groups,
        WfmWindowMinutes: 30,
        WfmSlTargetPct: 80,
        WfmSlThresholdSec: 20,
        WfmTrunkCapacity: 100,
        WfmDefaultShrinkage: 0.3,
        WfmEnableRealtime: true,
        WfmThresholds: null);
}
