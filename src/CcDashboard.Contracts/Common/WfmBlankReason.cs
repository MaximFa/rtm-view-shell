namespace CcDashboard.Contracts.Common;

/// <summary>
/// BL-V4-WFM-NO-REASON-SHOWN-01: why the Wfm widget is showing dashes.
///
/// Measured on 234 on 2026-10-22: the widget showed 20 serving agents, arrivals 2.0/hr and
/// AHT 0s, and all nine Erlang figures were dashes. The operator asked "why doesn't Wfm
/// calculate?" and could not tell from the screen whether the line was quiet, the business unit
/// had no serving groups configured, or something was broken - all three look identical.
///
/// The snapshot already carries everything needed to say which it is (its own comment in
/// WfmTypes.cs says UnknownReason exists "so the widget can show the cause instead of an empty
/// cell with no explanation" - the widget simply never did). UnknownReason alone is not enough:
/// the relay fills it only when the agent count is unknown, while AHT = 0 and N = 0 leave it null,
/// and its text is technical English meant for a log, not for a wall display.
///
/// So the cause is classified here, from the inputs the snapshot already has, and the widget turns
/// the code into a localised line. Here, outside the component, because a widget's private members
/// are not visible to tests and there is no bUnit in this solution.
///
/// The codes are deliberately about the SITUATION, not about the code path: "nobody is serving"
/// is something an operator can act on, "nActual <= 0" is not.
/// </summary>
public static class WfmBlankReason
{
    /// <summary>Everything is computed; the widget shows figures and no explanation.</summary>
    public const string None = "none";

    /// <summary>More traffic than the agents on hand can serve - Erlang C has no answer here.</summary>
    public const string Overloaded = "overloaded";

    /// <summary>The engine has not said how many agents are serving. Not the same as zero.</summary>
    public const string AgentCountUnknown = "agent-count-unknown";

    /// <summary>The count is known and it is zero: nobody is serving this queue.</summary>
    public const string NobodyServing = "nobody-serving";

    /// <summary>No answered call in the window, so there is no average talk time to compute with.</summary>
    public const string NoAnsweredCalls = "no-answered-calls";

    /// <summary>Nothing arrived in the window at all - a quiet line, not a fault.</summary>
    public const string NoArrivals = "no-arrivals";

    /// <summary>
    /// Which situation the widget is in. Order matters and is the point of this method:
    /// an unknown agent count is checked FIRST, because it is not the same as zero agents and the
    /// operator's standing rule is to show nothing rather than compute on a stand-in; then zero
    /// agents, which is a real and actionable state; then a missing AHT, which is what actually
    /// stopped the calculation on 234; and only then an empty window, which is the innocent case.
    /// </summary>
    public static string Classify(string? state, double lambdaPerHour, double ahtSec, int? nActual)
    {
        if (state == "ok") return None;
        if (state == "overloaded") return Overloaded;

        if (nActual is null) return AgentCountUnknown;
        if (nActual <= 0) return NobodyServing;
        if (ahtSec <= 0) return lambdaPerHour <= 0 ? NoArrivals : NoAnsweredCalls;

        // State says "no data" yet every input looks usable. Saying "no arrivals" here would be a
        // guess dressed as an explanation, so the widget shows no cause rather than a wrong one.
        return None;
    }
}
