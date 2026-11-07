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
    public void OnlyEndOfShiftAgentsReports_getOneField()
    {
        // Since 2026-11-07 only the agents report is one date plus hours; the queues report takes a
        // period (FEAT-REPORT-EOS-CONFIGURABLE-01) - its screen keeps both fields, see the NEGATIVE
        // case below.
        ReportDateFields.SingleDate(new[]
        {
            ReportWidgetType.EndOfShiftAgents,
            ReportWidgetType.EndOfShiftAgents
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
    public void AOneFieldScreen_opensOnToday()
    {
        // Measured on 234 on 2026-11-06: it opened on 30.10 with the site's today at 06.11,
        // because the page chose the dates before it knew how many fields it would draw. On a
        // one-field screen that date IS the window, so a week-old default shows a week-old shift
        // to anyone who does not look at the field.
        var today = new DateTime(2026, 11, 6);
        ReportDateFields.DefaultRange(today, singleDate: true).Should().Be((today, today));
    }

    [Fact]
    public void ATwoFieldScreen_opensOnTheLastWeek()
    {
        // THE OTHER HALF: on a two-field screen the same seven days are the sensible period, so
        // the fix must not turn every report into a one-day report.
        var today = new DateTime(2026, 11, 6);
        ReportDateFields.DefaultRange(today, singleDate: false)
            .Should().Be((new DateTime(2026, 10, 30), today));
    }

    [Fact]
    public void TheDefaultRange_keepsOnlyTheDatePart()
    {
        // "Today" arrives as a wall-clock instant; a time of day left on it would travel into the
        // query and shift the window by hours.
        var noon = new DateTime(2026, 11, 6, 12, 34, 56);
        var (from, to) = ReportDateFields.DefaultRange(noon, singleDate: true);
        from.TimeOfDay.Should().Be(TimeSpan.Zero);
        to.TimeOfDay.Should().Be(TimeSpan.Zero);
    }

    [Fact]
    public void OnlyTheEndOfShiftAgentsReport_takesOneDateAndShiftHours()
    {
        // Pinned against the enum rather than listed again: a new type is NOT single-date until
        // somebody says so here, which is the safe direction - a wrongly single-date screen hides
        // a control, while a wrongly two-field screen only shows one too many.
        // Narrowed 2026-11-07 (FEAT-REPORT-EOS-CONFIGURABLE-01): the end-of-shift QUEUES report
        // takes a period and a step now, so it is end-of-shift by name and two-field by time.
        foreach (var type in Enum.GetValues<ReportWidgetType>())
        {
            var endOfShift = type is ReportWidgetType.EndOfShiftAgents or ReportWidgetType.EndOfShiftQueues;
            var oneDate = type is ReportWidgetType.EndOfShiftAgents;
            ReportDateFields.IsEndOfShift(type).Should().Be(endOfShift, $"{type} must be classified explicitly");
            ReportDateFields.TakesShiftHours(type).Should().Be(oneDate, $"{type}: shift hours");
            ReportDateFields.SingleDate(new[] { type }).Should().Be(oneDate, $"{type}: one date field");
        }
    }

    [Fact]
    public void NEGATIVE_aScreenWithTheQueuesReport_keepsBothDateFields()
    {
        // The shape of the rule before 2026-11-07 ("every end-of-shift type takes one date") would
        // answer true for both of these - and hide the "to" field from a report that needs it.
        ReportDateFields.SingleDate(new[] { ReportWidgetType.EndOfShiftQueues }).Should().BeFalse();
        ReportDateFields.SingleDate(new[] { ReportWidgetType.EndOfShiftAgents, ReportWidgetType.EndOfShiftQueues })
            .Should().BeFalse();
        ReportDateFields.SingleDate(new[] { ReportWidgetType.EndOfShiftAgents, ReportWidgetType.EndOfShiftAgents })
            .Should().BeTrue("a screen made only of the agents report still has one date");
    }
}
