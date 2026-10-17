using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// A filter, a sort and a threshold must judge the value the person SEES. These pin the one
/// normalisation both the display path and the comparison path now share.
/// </summary>
public class MetricCellValueTests
{
    [Fact]
    public void EnginePlaceholder_readsAsEmpty()
    {
        // The defect: the cell showed a blank while a saved rule compared the raw "&nbsp;", so a
        // rule could never match the rows that look empty.
        MetricCellValue.Display("&nbsp;").Should().BeEmpty();
        ThresholdTextMatch.IsEmpty(MetricCellValue.Display("&nbsp;")).Should().BeTrue(
            "a rule asking for empty cells must find the cells that look empty");
    }

    [Theory]
    [InlineData("NaN")]
    [InlineData("Infinity")]
    [InlineData("-Infinity")]
    public void Anomalies_readAsEmpty_becauseThatIsHowTheyAreShown(string raw)
        => MetricCellValue.Display(raw).Should().BeEmpty();

    [Theory]
    [InlineData("0:07:43", "07:43")]
    [InlineData("1:02:03", "01:02:03")]
    [InlineData("7:5", "07:05")]
    public void TimeIsZeroPadded_andAZeroHourIsDropped(string raw, string expected)
        => MetricCellValue.Display(raw).Should().Be(expected);

    // ── NEGATIVE HALF ────────────────────────────────────────────────────────

    [Theory]
    [InlineData("ONPHONE")]
    [InlineData("0")]
    [InlineData("0%")]
    [InlineData("1800")]
    [InlineData("12.5%")]
    [InlineData("&nbsp")]      // no semicolon — not the placeholder
    [InlineData("nbsp;")]
    [InlineData("a:b")]        // not a time
    public void OrdinaryValues_passThroughUnchanged(string raw)
    {
        // Without this half the suite stays green even if Display() blanked everything, and the
        // near-misses pin the boundary: only the exact placeholder counts as empty.
        MetricCellValue.Display(raw).Should().Be(raw);
        ThresholdTextMatch.IsEmpty(MetricCellValue.Display(raw)).Should().BeFalse();
    }

    [Fact]
    public void NullAndEmpty_areEmpty_withoutThrowing()
    {
        MetricCellValue.Display(null).Should().BeEmpty();
        MetricCellValue.Display("").Should().BeEmpty();
    }
}
