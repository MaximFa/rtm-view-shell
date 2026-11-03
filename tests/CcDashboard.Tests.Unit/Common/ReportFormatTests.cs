using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// The two report cell formatters, which until now lived in nine copies inside components where no
/// test could reach them. These tests pin the behaviour the existing reports already have, so a
/// migrated report reads exactly like an old one - that is the point of the unit, not an
/// improvement of the format.
/// </summary>
public class ReportFormatTests
{
    [Fact]
    public void NoValuePrintsADash_notZero()
    {
        // The distinction that matters on a report: a queue with no answered calls has no average
        // wait. Printing 0 would read as "instant", which is the opposite of the truth.
        ReportFormat.Pct(null).Should().Be("-");
        ReportFormat.Duration(null).Should().Be("-");
    }

    [Fact]
    public void ZeroIsAValue_andPrintsAsZero()
    {
        // NEGATIVE HALF of the above: a real zero must NOT turn into a dash, or a queue that truly
        // answered everything within the threshold would look like missing data.
        ReportFormat.Pct(0).Should().Be("0.0%");
        ReportFormat.Duration(0).Should().Be("0:00");
    }

    [Theory]
    [InlineData(0, "0:00")]
    [InlineData(5, "0:05")]
    [InlineData(59, "0:59")]
    [InlineData(60, "1:00")]
    [InlineData(599, "9:59")]
    [InlineData(3599, "59:59")]
    public void UnderAnHourPrintsMinutesAndSeconds(double seconds, string expected)
        => ReportFormat.Duration(seconds).Should().Be(expected);

    [Theory]
    [InlineData(3600, "1:00:00")]
    [InlineData(3661, "1:01:01")]
    [InlineData(86399, "23:59:59")]
    [InlineData(90000, "25:00:00")]
    public void AnHourOrMorePrintsHoursToo_andHoursAreNotCappedAtADay(double seconds, string expected)
    {
        // 25:00:00 rather than 1:01:00:00: a shift report may legitimately sum past 24 hours, and
        // the existing reports already spell it this way.
        ReportFormat.Duration(seconds).Should().Be(expected);
    }

    [Fact]
    public void TheBoundaryAtOneHourIsExact()
    {
        // One second either side of the switch, so a change to ">" or ">=" cannot pass unnoticed.
        ReportFormat.Duration(3599).Should().Be("59:59");
        ReportFormat.Duration(3600).Should().Be("1:00:00");
    }

    [Fact]
    public void PercentagesKeepOneDecimal()
    {
        ReportFormat.Pct(12.34).Should().Be("12.3%");
        ReportFormat.Pct(100).Should().Be("100.0%");

        // Values either side of a rounding boundary, chosen so the expectation does not depend on
        // how a double happens to be represented. 99.95 would have "worked" here - the nearest
        // double is a hair ABOVE 99.95, so it rounds up - but a test that passes for that reason
        // is a trap for whoever touches it next.
        ReportFormat.Pct(99.94).Should().Be("99.9%");
        ReportFormat.Pct(99.96).Should().Be("100.0%");
    }

    [Fact]
    public void FractionsOfASecondAreTruncated_notRounded()
    {
        // TimeSpan.FromSeconds keeps the fraction and the format drops it, so 59.9 s is 0:59.
        // Stated because it is the kind of thing a well-meaning rewrite "fixes" into 1:00.
        ReportFormat.Duration(59.9).Should().Be("0:59");
    }
}
