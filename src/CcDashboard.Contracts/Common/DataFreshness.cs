namespace CcDashboard.Contracts.Common;

/// <summary>
/// BL-V4-STALE-VALUES-LOOK-LIVE-01: has what the screen shows stopped being current?
///
/// Measured on 234 twice, both times by a checker who nearly accepted the stale numbers:
/// 18.10 20:03:08Z and 20:05:12Z showed 5:53:19 with no increment; 22.10 07:00:37Z and 07:00:54Z
/// showed 1:13:48 and 52:52, also without increment. Nothing on screen said the values were old -
/// only a second reading a minute later revealed it, and an operator has no second reading.
///
/// Worse, the two grids keep a one-second tick of their own that redraws a running duration from
/// its anchor whether or not new data arrives (AgentGridWidget / QueueGridWidget). When the relay
/// loses the RTM hub while the browser stays connected, those durations go on GROWING - a perfect
/// imitation of a live screen, which the "values are moving" check cannot catch at all.
///
/// Two sources, one verdict, because the illness is one: values shown as current while they are not.
/// - The two grids learn it from the relay's connection state (IRtmRelayService.ConnectionChanged).
/// - DayTrend and Wfm poll on their own timer, so for them it is the AGE of the last successful
///   answer: a failed or long-silent poll leaves the previous answer on screen just the same.
///
/// The decision lives here, outside the components, so a test can reach it: a widget's private
/// members are not visible to tests and there is no bUnit in this solution.
/// </summary>
public static class DataFreshness
{
    /// <summary>
    /// How long a polled answer may stand before the screen must say it is old: three polling
    /// intervals, and never less than 15 seconds.
    ///
    /// Three, not one: a single missed poll is ordinary (a slow query, a GC pause, a redeploy of
    /// one node), and marking the screen on every hiccup would train people to ignore the mark -
    /// which is the very failure this unit is about. Three consecutive misses is no longer noise.
    /// The 15-second floor exists because Wfm polls every 5 s: three intervals there would be 15 s
    /// anyway, but a widget configured to poll every second must not start accusing itself after
    /// three seconds.
    /// </summary>
    public static TimeSpan StaleAfter(TimeSpan pollInterval)
    {
        var threeIntervals = pollInterval * 3;
        var floor = TimeSpan.FromSeconds(15);
        return threeIntervals > floor ? threeIntervals : floor;
    }

    /// <summary>
    /// True when a polled widget must mark its values as old.
    /// <paramref name="lastSuccessUtc"/> is null before the first successful answer - then there is
    /// nothing on screen to be stale, so the answer is false and the widget shows its own empty state.
    /// </summary>
    public static bool IsStale(DateTime? lastSuccessUtc, DateTime nowUtc, TimeSpan pollInterval)
    {
        if (lastSuccessUtc is null) return false;
        return nowUtc - lastSuccessUtc.Value > StaleAfter(pollInterval);
    }
}
