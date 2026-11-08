using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// A widget left out of an exported file must be named on the screen. These tests pin the three
/// codes the server sends, and - the half that matters - pin that an unrecognised code still
/// produces a visible line instead of silence.
/// </summary>
public class ExportSkipReasonTests
{
    [Theory]
    [InlineData(ExportSkipReason.Denied, "Reports_ExportSkippedDenied")]
    [InlineData(ExportSkipReason.NoData, "Reports_ExportSkippedNoData")]
    [InlineData(ExportSkipReason.InvalidConfig, "Reports_ExportSkippedInvalidConfig")]
    public void EachKnownCode_mapsToItsOwnKey(string code, string expectedKey)
    {
        ExportSkipReason.KeyFor(code).Should().Be(expectedKey);
        ExportSkipReason.IsUnknown(code).Should().BeFalse();
    }

    [Fact]
    public void TheKnownCodes_doNotShareAKey()
    {
        // A map that returned the same key for two codes would read as "translated" while telling
        // the operator the wrong thing about which widget failed and why.
        new[] { ExportSkipReason.Denied, ExportSkipReason.NoData, ExportSkipReason.InvalidConfig }
            .Select(ExportSkipReason.KeyFor)
            .Should().OnlyHaveUniqueItems();
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("whatever-backend-adds-next")]
    [InlineData("Denied ")]
    public void AnUnknownOrEmptyCode_isReportedAsUnknown_notAsNothing(string? code)
    {
        // THE NEGATIVE HALF of the whole feature: the screen must still name the widget. "Unknown"
        // is asked as its own question precisely so a page cannot turn it into an empty list by
        // accident - which is the defect this unit exists to remove, moved one step downstream.
        //
        // "Denied " with a trailing space is in this list on purpose: it is NOT unknown. It is the
        // same code with whitespace, and a map that only compared raw strings would have shown a
        // nameless line for a reason it actually knows.
        var isPaddedKnownCode = code?.Trim().Equals("denied", StringComparison.OrdinalIgnoreCase) == true;

        if (isPaddedKnownCode)
        {
            ExportSkipReason.IsUnknown(code).Should().BeFalse("whitespace around a known code is still that code");
            ExportSkipReason.KeyFor(code).Should().Be("Reports_ExportSkippedDenied");
        }
        else
        {
            ExportSkipReason.IsUnknown(code).Should().BeTrue();
            ExportSkipReason.KeyFor(code).Should().BeNull("a reason must never be invented for a code we do not know");
        }
    }

    [Fact]
    public void TheTwoLineKeysDiffer()
    {
        // One line names the widget and the reason, the other names the widget alone. If these
        // were the same key, the unknown-code path would print a dangling separator or swallow
        // the name, and this guard would be the only place that noticed.
        ExportSkipReason.ItemKey.Should().NotBe(ExportSkipReason.ItemWithoutReasonKey);
    }
}
