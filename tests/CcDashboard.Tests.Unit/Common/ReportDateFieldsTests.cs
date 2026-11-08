using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// The dates a report screen opens on. Until 2026-11-08 this file also held "one date field or two": a screen of
/// end-of-shift agents reports showed one date plus shift hours. Agent Report takes a period now
/// (FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01, operator 07:54), no report takes one date, and the rule went with it -
/// its eight cases asked a question that no longer has a "yes". What is left is asked here.
/// </summary>
public class ReportDateFieldsTests
{
    [Fact]
    public void TheScreen_opensOnTheLastWeek_endingOnTheGivenDay()
    {
        var today = new DateTime(2026, 11, 8);
        ReportDateFields.DefaultRange(today).Should().Be((new DateTime(2026, 11, 1), today));
        ReportDateFields.DefaultDaysBack.Should().Be(7);
    }

    [Fact]
    public void TheDefaultRange_keepsOnlyTheDatePart()
    {
        var (from, to) = ReportDateFields.DefaultRange(new DateTime(2026, 11, 8, 13, 45, 0));
        from.TimeOfDay.Should().Be(TimeSpan.Zero);
        to.Should().Be(new DateTime(2026, 11, 8));
    }

    [Fact]
    public void NoRuleAboutOneDateOrShiftHours_isLeft()
    {
        // An empty rule ("which types take one date? none") invites a type back into it without anyone noticing.
        OneDateRules(typeof(ReportDateFields).GetMethods().Select(m => m.Name)).Should().BeEmpty();

        // NEGATIVE HALF: the names the rule had are caught.
        OneDateRules(new[] { "SingleDate", "DefaultRange" }).Should().Equal("SingleDate");
        OneDateRules(new[] { "TakesShiftHours", "IsEndOfShift" }).Should().HaveCount(2);
    }

    private static List<string> OneDateRules(IEnumerable<string> names)
        => names.Where(n => n is "SingleDate" or "TakesShiftHours" or "IsEndOfShift").Distinct().ToList();
}
