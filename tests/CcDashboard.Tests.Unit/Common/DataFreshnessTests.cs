using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// BL-V4-STALE-VALUES-LOOK-LIVE-01. The verdict "what the screen shows is no longer current" lives
/// outside the widgets precisely so it can be tested: a component's private members are not visible
/// to tests and there is no bUnit in this solution.
///
/// Each claim here has its opposite next to it. A freshness check that can only say "stale" would
/// mark a healthy screen and teach people to ignore the mark - the same failure in reverse.
/// </summary>
public class DataFreshnessTests
{
    private static readonly DateTime Now = new(2026, 10, 22, 12, 00, 00, DateTimeKind.Utc);

    [Fact]
    public void ThresholdIsThreePollIntervals_notOne()
    {
        // One missed poll is ordinary; three in a row is not. The number is the point here.
        DataFreshness.StaleAfter(TimeSpan.FromSeconds(300)).Should().Be(TimeSpan.FromSeconds(900));
        DataFreshness.StaleAfter(TimeSpan.FromSeconds(20)).Should().Be(TimeSpan.FromSeconds(60));
    }

    [Fact]
    public void ThresholdNeverFallsBelowFifteenSeconds()
    {
        // A one-second poll must not start accusing itself after three seconds.
        DataFreshness.StaleAfter(TimeSpan.FromSeconds(1)).Should().Be(TimeSpan.FromSeconds(15));
        DataFreshness.StaleAfter(TimeSpan.FromSeconds(5)).Should().Be(TimeSpan.FromSeconds(15));
        // ...and the floor must not override a genuinely larger window:
        DataFreshness.StaleAfter(TimeSpan.FromSeconds(10)).Should().Be(TimeSpan.FromSeconds(30));
    }

    [Fact]
    public void AnAnswerOlderThanTheThreshold_isStale()
    {
        var poll = TimeSpan.FromSeconds(5);   // Wfm's interval: threshold 15 s
        DataFreshness.IsStale(Now.AddSeconds(-16), Now, poll).Should().BeTrue();
    }

    [Fact]
    public void AFreshAnswer_isNotStale()
    {
        // NEGATIVE HALF #1: the check must be able to answer "fine", or it is useless as a signal.
        var poll = TimeSpan.FromSeconds(5);
        DataFreshness.IsStale(Now.AddSeconds(-4), Now, poll).Should().BeFalse();
        DataFreshness.IsStale(Now, Now, poll).Should().BeFalse();
    }

    [Fact]
    public void ExactlyAtTheThreshold_isNotYetStale()
    {
        // The boundary is stated on purpose: "> threshold", not ">=", so a poll that lands exactly
        // on the limit is not accused.
        var poll = TimeSpan.FromSeconds(5);
        DataFreshness.IsStale(Now.AddSeconds(-15), Now, poll).Should().BeFalse();
        DataFreshness.IsStale(Now.AddSeconds(-15).AddMilliseconds(-1), Now, poll).Should().BeTrue();
    }

    [Fact]
    public void BeforeTheFirstAnswer_nothingIsStale()
    {
        // NEGATIVE HALF #2: with no data yet there is nothing on screen to be old, and the widget
        // shows its own empty state. Marking this as stale would put a "no connection" notice on a
        // widget that is merely still loading.
        DataFreshness.IsStale(null, Now, TimeSpan.FromSeconds(5)).Should().BeFalse();
    }

    [Fact]
    public void AFutureAnswer_isNotStale()
    {
        // Clock skew between the shell and whatever produced the snapshot must not read as "old".
        DataFreshness.IsStale(Now.AddMinutes(5), Now, TimeSpan.FromSeconds(5)).Should().BeFalse();
    }
}
