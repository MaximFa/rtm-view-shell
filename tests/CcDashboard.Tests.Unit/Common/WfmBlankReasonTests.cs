using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Unit.Common;

/// <summary>
/// BL-V4-WFM-NO-REASON-SHOWN-01. On 234 the widget showed 20 serving agents, arrivals 2.0/hr,
/// AHT 0s and nine dashes, and nobody could tell from the screen which of five situations it was.
/// These tests pin the one that matters most - the real reading from that day - and then pin the
/// distinctions that make the line worth printing at all.
/// </summary>
public class WfmBlankReasonTests
{
    [Fact]
    public void TheRealReadingFrom234_isNoAnsweredCalls()
    {
        // Exactly what was on screen 2026-10-22: N known and healthy, traffic arriving, AHT zero.
        WfmBlankReason.Classify("nodata", lambdaPerHour: 2.0, ahtSec: 0, nActual: 20)
            .Should().Be(WfmBlankReason.NoAnsweredCalls);
    }

    [Fact]
    public void AnEmptyWindowIsNotTheSameAsNoAnsweredCalls()
    {
        // Nothing arrived at all: a quiet line, not a queue whose calls go unanswered. Telling
        // these two apart is the whole point of printing a cause instead of a dash.
        WfmBlankReason.Classify("nodata", lambdaPerHour: 0, ahtSec: 0, nActual: 20)
            .Should().Be(WfmBlankReason.NoArrivals);
    }

    [Fact]
    public void AnUnknownAgentCountIsNotZeroAgents()
    {
        // The engine not saying is not the same as nobody serving, and the standing rule is to
        // show nothing rather than compute on a stand-in. Order of checks is what guarantees this:
        // an unknown count wins even when AHT is also missing.
        WfmBlankReason.Classify("nodata", lambdaPerHour: 5, ahtSec: 0, nActual: null)
            .Should().Be(WfmBlankReason.AgentCountUnknown);

        WfmBlankReason.Classify("nodata", lambdaPerHour: 5, ahtSec: 120, nActual: 0)
            .Should().Be(WfmBlankReason.NobodyServing);
    }

    [Fact]
    public void OverloadIsItsOwnAnswer_notAMissingInput()
    {
        // The figures ARE computed here; Erlang C simply has no answer. Reporting this as "no
        // data" would send someone looking for a broken feed instead of for more agents.
        WfmBlankReason.Classify("overloaded", lambdaPerHour: 300, ahtSec: 240, nActual: 2)
            .Should().Be(WfmBlankReason.Overloaded);
    }

    [Fact]
    public void WhenEverythingIsComputed_thereIsNothingToExplain()
    {
        // NEGATIVE HALF #1: the line must stay off on a healthy widget. A permanent explanatory
        // note next to working figures is noise, and noise is how a real warning gets ignored.
        WfmBlankReason.Classify("ok", lambdaPerHour: 30, ahtSec: 180, nActual: 10)
            .Should().Be(WfmBlankReason.None);
    }

    [Fact]
    public void NoDataWithEveryInputUsable_saysNothingRatherThanGuessing()
    {
        // NEGATIVE HALF #2: the state says "no data" while the inputs all look fine - we do not
        // know why, so the widget must not print a cause. A guess dressed as an explanation is
        // worse than a dash, because it sends the operator somewhere specific and wrong.
        WfmBlankReason.Classify("nodata", lambdaPerHour: 10, ahtSec: 200, nActual: 5)
            .Should().Be(WfmBlankReason.None);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("something-new-from-the-engine")]
    public void AnUnknownState_isTreatedAsNoData_andStillExplained(string? state)
    {
        // A state we have never seen must not silently become "ok": the figures would be dashes
        // with no cause again, which is the defect. With N unknown the answer is still useful.
        WfmBlankReason.Classify(state, lambdaPerHour: 0, ahtSec: 0, nActual: null)
            .Should().Be(WfmBlankReason.AgentCountUnknown);
    }

    [Fact]
    public void NegativeInputsAreTreatedAsMissing_notAsValues()
    {
        // Defensive, and cheap: a negative AHT or agent count is corrupt input, and computing on
        // it would put a plausible wrong number on a wall display.
        WfmBlankReason.Classify("nodata", lambdaPerHour: 5, ahtSec: -1, nActual: 20)
            .Should().Be(WfmBlankReason.NoAnsweredCalls);
        WfmBlankReason.Classify("nodata", lambdaPerHour: 5, ahtSec: 120, nActual: -3)
            .Should().Be(WfmBlankReason.NobodyServing);
    }
}
