using CcDashboard.Application.Commands.Configuration;
using CcDashboard.Application.Validators;
using CcDashboard.Contracts.DTOs.Configuration;
using FluentAssertions;
using Xunit;

namespace CcDashboard.Tests.Unit.Commands.Configuration;

/// <summary>
/// PR234-SITE-TZ-FIXED-OFFSET-01: a site may carry a time zone id (with daylight saving) as well as a fixed offset.
/// Negative half: the old rule (^[+-]\d{2}:\d{2}$, max 10) rejected every zone id, so IL could only be "+02:00".
/// </summary>
public class SiteTimeZoneValidatorTests
{
    private static string IsraelId()
    {
        foreach (var id in new[] { "Israel Standard Time", "Asia/Jerusalem" })
        {
            try { TimeZoneInfo.FindSystemTimeZoneById(id); return id; } catch (TimeZoneNotFoundException) { }
        }
        throw new InvalidOperationException("no Israel time zone id on this machine");
    }

    private static bool Valid(string? tz) => Errors(tz).Length == 0;

    // The failure text names the rule that rejected the value (the first run on the Windows agent said only "False").
    private static string Errors(string? tz) => string.Join(" | ",
        new SaveSiteCommandValidator().Validate(new SaveSiteCommand(new SaveSiteRequest("IL", "Israel", null, tz, "00:00", true)))
            .Errors.Select(e => e.PropertyName + ": " + e.ErrorMessage));

    [Fact]
    public void Accepts_FixedOffsets_ZoneIds_AndEmpty()
    {
        Valid("+02:00").Should().BeTrue();
        Valid("-05:00").Should().BeTrue();
        var id = IsraelId();
        SaveSiteCommandValidator.IsOffsetOrKnownZoneId(id).Should().BeTrue($"the predicate itself must accept '{id}'");
        Errors(id).Should().BeEmpty($"the whole validator must accept '{id}'");
        Valid(null).Should().BeTrue();
        Valid("").Should().BeTrue();

        System.Text.RegularExpressions.Regex.IsMatch(IsraelId(), @"^[+-]\d{2}:\d{2}$").Should().BeFalse("negative half: the old rule rejected any zone id");
    }

    [Fact]
    public void Rejects_UnknownIds_LooseOffsets_AndTooLong()
    {
        Valid("Mars/Olympus").Should().BeFalse();
        Valid("+2").Should().BeFalse();
        Valid("UTC+3").Should().BeFalse();
        Valid(new string('A', 65)).Should().BeFalse();
    }
}
