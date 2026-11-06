using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// The caveat sentence belongs to the screen, the code to the server. These pin the one known
/// code, and - the half that matters - that silence and "a code we do not understand" are two
/// different answers, so the widget cannot print a raw code where a sentence belongs.
/// </summary>
public class ReportCaveatTests
{
    [Fact]
    public void TheKnownCode_mapsToItsKey()
    {
        ReportCaveat.KeyFor(ReportCaveat.StatusStartBucket).Should().Be("Report_CaveatStatusStartBucket");
        ReportCaveat.IsUnknown(ReportCaveat.StatusStartBucket).Should().BeFalse();
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void NoCode_isNotAnUnknownCode(string? code)
    {
        // Nothing to say is the ordinary case for most reports: it must not be logged as a
        // surprise, or the log fills with noise and the real surprise is lost in it.
        ReportCaveat.KeyFor(code).Should().BeNull();
        ReportCaveat.IsUnknown(code).Should().BeFalse();
    }

    [Theory]
    [InlineData("whatever-backend-adds-next")]
    [InlineData("STATUS_START_BUCKET")]
    public void AnUnrecognisedCode_isReportedAsUnknown(string code)
    {
        // THE NEGATIVE HALF: a code this screen cannot put into words must be visible to us in the
        // log rather than printed on the board. "STATUS_START_BUCKET" is in the list on purpose:
        // it is NOT the known code - the contract is lower-case and hyphenated - and a map that
        // guessed at it would show a sentence about bucketing for a code that may mean anything.
        ReportCaveat.KeyFor(code).Should().BeNull();
        ReportCaveat.IsUnknown(code).Should().BeTrue();
    }

    [Fact]
    public void WhitespaceAroundTheKnownCode_isStillTheKnownCode()
    {
        ReportCaveat.KeyFor("  status-start-bucket  ").Should().Be("Report_CaveatStatusStartBucket");
        ReportCaveat.IsUnknown("  status-start-bucket  ").Should().BeFalse();
    }
}
