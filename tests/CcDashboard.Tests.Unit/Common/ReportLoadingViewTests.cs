using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// The rows a person is reading must not be taken away while a newer answer is fetched. These pin
/// the four cases, including the two that look alike from the outside and must not be confused:
/// "nothing yet" and "something, being refreshed".
/// </summary>
public class ReportLoadingViewTests
{
    [Fact]
    public void FirstLoad_showsTheSpinner()
    {
        ReportLoadingView.ShowSpinner(loading: true, hasRows: false).Should().BeTrue();
        ReportLoadingView.ShowUpdatingMark(loading: true, hasRows: false).Should().BeFalse(
            "there is nothing to mark as refreshing yet");
    }

    [Fact]
    public void RefreshingKeepsTheRows_andSaysSo()
    {
        // THE DEFECT THIS EXISTS FOR: applying a filter used to blank the table. The rows are one
        // answer old, not wrong.
        ReportLoadingView.ShowSpinner(loading: true, hasRows: true).Should().BeFalse(
            "the rows already on screen must not be replaced by a spinner");
        ReportLoadingView.ShowUpdatingMark(loading: true, hasRows: true).Should().BeTrue(
            "and the wait must be visible, or a stuck screen looks healthy");
    }

    [Fact]
    public void WhenNothingIsLoading_neitherIsShown()
    {
        foreach (var hasRows in new[] { true, false })
        {
            ReportLoadingView.ShowSpinner(loading: false, hasRows).Should().BeFalse();
            ReportLoadingView.ShowUpdatingMark(loading: false, hasRows).Should().BeFalse();
        }
    }

    [Fact]
    public void TheTwoStatesAreNeverBothTrue()
    {
        // A widget that showed both would draw a spinner over its own rows - the blink again, with
        // extra steps. Checked over every combination rather than argued about.
        foreach (var loading in new[] { true, false })
            foreach (var hasRows in new[] { true, false })
                (ReportLoadingView.ShowSpinner(loading, hasRows)
                 && ReportLoadingView.ShowUpdatingMark(loading, hasRows))
                    .Should().BeFalse($"loading={loading}, hasRows={hasRows}");
    }
}
