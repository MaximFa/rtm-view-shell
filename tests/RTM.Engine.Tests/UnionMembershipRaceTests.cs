using System.Collections.Concurrent;
using FluentAssertions;
using RTM;

namespace RTM.Engine.Tests;

/// <summary>
/// PR234-UNIONMAP-RACE-01 — the regression guard for the fix in 35989b6.
///
/// The defect: refreshUnions() had exactly two callers, both inside workgroupActivation().
/// Union membership was therefore computed at the moment an activation arrived and never again,
/// so a mapping row (union.UserGroups) loaded AFTER that activation never reached the agent —
/// he stayed out of the union until his NEXT activation, which may not come before end of shift.
/// The fix adds a second pass over every UserManager at the end of Engine.LoadData.
///
/// WHAT THESE TESTS DO AND DO NOT COVER — stated here so nobody reads more into a green run:
/// they pin the CONTRACT the fix relies on (a second refreshUnions after the mapping lands puts
/// the agent in, and does not put in an agent who does not belong). They do NOT execute
/// Engine.LoadData itself: that method reads from the database on its first lines, so covering the
/// loop in place needs a seam that does not exist yet. That gap stays open under
/// PR234-ENGINE-NOTESTS-01 and is not closed by these tests passing.
/// </summary>
public class UnionMembershipRaceTests
{
    private const string Workgroup = "wg-alpha";
    private const int UnionId = 42;
    private const int SupergroupId = 7;

    private static (UserManager agent, Union union, UnionList unions) Arrange()
    {
        var metrics = new ConcurrentDictionary<string, MetricDef>();
        var unions = new UnionList();
        var union = new Union(UnionId, metrics);
        unions.TryAdd(UnionId, union);

        // dbMng is null on purpose: neither workgroupActivation nor refreshUnions touches it
        // (verified against the bodies, not assumed).
        var agent = new UserManager("agent-1", unions, null, metrics);
        return (agent, union, unions);
    }

    /// <summary>
    /// THE DEFECT ITSELF. The activation arrives BEFORE the mapping is loaded, so the agent is not
    /// in the union — this is the state the engine was left in. This test is the negative half:
    /// it asserts the gap exists, and it passes on the body WITHOUT the fix too. Its job is to make
    /// the next test meaningful, not to prove anything on its own.
    /// </summary>
    [Fact]
    public void ActivationBeforeMapping_LeavesAgentOutOfUnion()
    {
        var (agent, union, _) = Arrange();

        agent.workgroupActivation(Workgroup, true);   // activation first
        AddMapping(union);                            // mapping lands afterwards (what LoadData does)

        union.Users.Should().NotContain(agent,
            "the activation was processed while union.UserGroups was still empty");
    }

    /// <summary>
    /// THE FIX. The second pass — the one Engine.LoadData now performs over every UserManager —
    /// puts the agent in without waiting for his next activation.
    /// </summary>
    [Fact]
    public void SecondPassAfterMappingLands_PutsAgentIntoUnion()
    {
        var (agent, union, _) = Arrange();

        agent.workgroupActivation(Workgroup, true);
        AddMapping(union);

        agent.refreshUnions();                        // what LoadData now does for every manager

        union.Users.Should().Contain(agent,
            "a mapping row that landed after the activation must still reach the agent");
    }

    /// <summary>
    /// SECOND NEGATIVE HALF — the one that stops "it works" from meaning "it adds everyone".
    /// An agent whose workgroups do not cover the union's requirement must stay OUT even after the
    /// second pass. Without this, a fix that simply added every manager to every union would look
    /// just as green as the correct one.
    /// </summary>
    [Fact]
    public void SecondPass_DoesNotAddAnAgentWhoseWorkgroupsDoNotMatch()
    {
        var (agent, union, _) = Arrange();

        agent.workgroupActivation("wg-unrelated", true);
        AddMapping(union);                            // union needs wg-alpha, the agent has none of it

        agent.refreshUnions();

        union.Users.Should().NotContain(agent,
            "membership must follow the mapping, not the mere fact that a second pass ran");
    }

    /// <summary>
    /// Guard against a silent no-op: an agent already in the union must not be added twice by the
    /// second pass, which now runs on EVERY LoadData.
    /// </summary>
    [Fact]
    public void SecondPass_IsIdempotent_NoDuplicateMembership()
    {
        var (agent, union, _) = Arrange();

        AddMapping(union);                            // mapping first this time
        agent.workgroupActivation(Workgroup, true);   // activation already puts him in

        agent.refreshUnions();
        agent.refreshUnions();

        union.Users.Count(u => ReferenceEquals(u, agent)).Should().Be(1,
            "the second pass runs on every LoadData and must not duplicate membership");
    }

    private static void AddMapping(Union union)
        => union.UserGroups.TryAdd(SupergroupId, new List<string> { Workgroup });
}
