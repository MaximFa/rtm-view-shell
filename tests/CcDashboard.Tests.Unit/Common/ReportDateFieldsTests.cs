using CcDashboard.Contracts.Common;
using CcDashboard.Domain.Domain.Reports;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// One date field, or two. The rule decides what a person can touch, so each case here is a
/// screen somebody could build, not an abstract combination.
/// </summary>
public class ReportDateFieldsTests
{
    [Fact]
    public void OnlyEndOfShiftReports_getOneField()
    {
        ReportDateFields.SingleDate(new[]
        {
            ReportWidgetType.EndOfShiftAgents,
            ReportWidgetType.EndOfShiftQueues
        }).Should().BeTrue();
    }

    [Fact]
    public void OneOtherReport_isEnoughToKeepBothFields()
    {
        // THE NEGATIVE HALF: the mixed screen. Every other report reads a period, so taking its
        // end date away would quietly change what it shows.
        ReportDateFields.SingleDate(new[]
        {
            ReportWidgetType.EndOfShiftAgents,
            ReportWidgetType.QueueInterval
        }).Should().BeFalse();
    }

    [Fact]
    public void AnEmptyScreen_keepsBothFields()
    {
        // A report with no widgets says nothing about what it will hold. Guessing "single" here
        // would hide a field from the person who then drops a period report onto the screen.
        ReportDateFields.SingleDate(Array.Empty<ReportWidgetType>()).Should().BeFalse();
        ReportDateFields.SingleDate(null).Should().BeFalse();
    }

    [Fact]
    public void TheTwoEndOfShiftTypes_areTheOnlySingleDateTypes()
    {
        // Pinned against the enum rather than listed again: a new type is NOT single-date until
        // somebody says so here, which is the safe direction - a wrongly single-date screen hides
        // a control, while a wrongly two-field screen only shows one too many.
        foreach (var type in Enum.GetValues<ReportWidgetType>())
        {
            var expected = type is ReportWidgetType.EndOfShiftAgents or ReportWidgetType.EndOfShiftQueues;
            ReportDateFields.IsEndOfShift(type).Should().Be(expected, $"{type} must be classified explicitly");
            ReportDateFields.SingleDate(new[] { type }).Should().Be(expected);
        }
    }
}
