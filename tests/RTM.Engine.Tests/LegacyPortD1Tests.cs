using System.Collections.Concurrent;
using System.Reflection;
using System.Runtime.CompilerServices;
using FluentAssertions;
using RTM;
using RTM.Configuration;

namespace RTM.Engine.Tests;

/// <summary>
/// SYNC-PORT 2026-10-15, rail D1: the legacy (Yuval) rounds 07-15, 07-28, 07-30 and 08-12 ported into our engine.
/// Every behaviour here has a negative half: the same input with the kill-switch off, or the same input one condition
/// short, must keep the old behaviour - otherwise a green run would not tell "ported" from "always on".
///
/// The tests share the static AppConfig switches, so they live in ONE collection (no parallel runs between them) and
/// every test restores the switch it touched.
/// </summary>
[Collection("AppConfigSwitches")]
public class LegacyPortD1Tests
{
    // ---------- harness ----------

    /// <summary>
    /// A DBMng that accepts requests and never writes: an uninitialized instance with an un-consumed queue.
    /// The real constructor starts a consumer that talks to PostgreSQL; the engine code under test only enqueues.
    /// </summary>
    private static DBMng StubDb()
    {
        var db = (DBMng)RuntimeHelpers.GetUninitializedObject(typeof(DBMng));
        var queueField = typeof(DBMng).GetField("_requestsQueue", BindingFlags.NonPublic | BindingFlags.Instance)!;
        queueField.SetValue(db, Activator.CreateInstance(queueField.FieldType));
        return db;
    }

    private static UserManager NewAgent(string id, DBMng db) =>
        new UserManager(id, new UnionList(), db, new ConcurrentDictionary<string, MetricDef>());

    private static ConcurrentDictionary<Call, DateTime> CallsOf(UserManager agent) =>
        (ConcurrentDictionary<Call, DateTime>)typeof(UserManager)
            .GetField("_calls", BindingFlags.NonPublic | BindingFlags.Instance)!.GetValue(agent)!;

    /// <summary>A Call carrying a hand-built interaction, added to the agent's active set at the given add-time.</summary>
    private static Call AddCall(UserManager agent, DBMng db, string id, string type, bool talking, bool disconnected, DateTime addTime)
    {
        var call = new Call(id, new UserManagerList(), new IDInteractionsList(new UnionList()), db);
        var it = new IDInteraction(id, 1, db, false) { InteractionType = type };
        if (disconnected) it.Disconnected();
        it.IsTalk = talking;   // set AFTER Disconnected(), which clears it: a dead entry that still claims to talk
        typeof(Call).GetProperty("IdInteraction")!.SetValue(call, it);
        CallsOf(agent)[call] = addTime;
        return call;
    }

    // Per test instance (xunit builds one per test): later than every UserManager birth stamp in the test.
    private readonly DateTime T0 = DateTime.Now.AddMinutes(5);
    private DateTime T(int s) => T0.AddSeconds(s);

    private void Real(UserManager a, string status, int s) =>
        a.setStatus(true, status, status, status.ToUpperInvariant(), T(s), "", false, DateTime.MinValue, s, false);

    private void Calc(UserManager a, string status, bool onPhone, int s) =>
        a.setStatus(true, status, status, "ONPHONE", T(s), "", onPhone, T(s), s, true);

    // ---------- 07-30: stuck-OnPhone reconcile ----------

    [Fact]
    public void Reconcile_On_StaleOnPhoneWithoutLiveCall_RealStatusApplies()
    {
        var saved = AppConfig.OnPhoneReconcileEnabled;
        try
        {
            AppConfig.OnPhoneReconcileEnabled = true;
            var agent = NewAgent("a1", StubDb());
            Real(agent, "Available", 1);
            Calc(agent, "Incoming Ext Call", onPhone: true, 2);   // OnPhone set, no call in _calls: the stuck shape

            Real(agent, "Break", 3);

            agent.UserStatus.Should().Be("Break");
            agent.OnPhone.Should().BeFalse("the reconcile clears the stale flag");
        }
        finally { AppConfig.OnPhoneReconcileEnabled = saved; }
    }

    [Fact]
    public void Reconcile_Off_StaleOnPhone_RealStatusIsDroppedAsBefore()
    {
        var saved = AppConfig.OnPhoneReconcileEnabled;
        try
        {
            AppConfig.OnPhoneReconcileEnabled = false;
            var agent = NewAgent("a2", StubDb());
            Real(agent, "Available", 1);
            Calc(agent, "Incoming Ext Call", onPhone: true, 2);

            Real(agent, "Break", 3);

            agent.UserStatus.Should().Be("Incoming Ext Call", "a literal false restores the old drop");
            agent.OnPhone.Should().BeTrue();
        }
        finally { AppConfig.OnPhoneReconcileEnabled = saved; }
    }

    [Fact]
    public void Reconcile_On_WithALiveVoiceCall_RealStatusIsStillDropped()
    {
        var saved = AppConfig.OnPhoneReconcileEnabled;
        try
        {
            AppConfig.OnPhoneReconcileEnabled = true;
            var db = StubDb();
            var agent = NewAgent("a3", db);
            Real(agent, "Available", 1);
            Calc(agent, "Incoming Ext Call", onPhone: true, 2);
            AddCall(agent, db, "live", "Call", talking: true, disconnected: false, T(2));

            Real(agent, "Break", 3);

            agent.UserStatus.Should().Be("Incoming Ext Call", "during a real call the calc status stays authoritative");
            agent.OnPhone.Should().BeTrue();
        }
        finally { AppConfig.OnPhoneReconcileEnabled = saved; }
    }

    [Fact]
    public void HasLiveVoiceCall_CountsOnlyTalkingNotDisconnectedVoice()
    {
        var db = StubDb();
        var agent = NewAgent("a4", db);
        AddCall(agent, db, "chat", "Chat", talking: true, disconnected: false, T(1));
        AddCall(agent, db, "mail", "Email", talking: true, disconnected: false, T(1));
        AddCall(agent, db, "dead", "Call", talking: true, disconnected: true, T(1));
        AddCall(agent, db, "queued", "Call", talking: false, disconnected: false, T(1));
        agent.HasLiveVoiceCall().Should().BeFalse("chat, email, a dead entry and a not-answered call are not a live voice call");

        AddCall(agent, db, "voice", "Call", talking: true, disconnected: false, T(2));
        agent.HasLiveVoiceCall().Should().BeTrue();
    }

    // ---------- 08-12: LastNoPhone keeps a fresher real status ----------

    private UserManager ArrangeRealStatusAfterPhoneStatus(DBMng db, string id)
    {
        var agent = NewAgent(id, db);
        Real(agent, "Available", 1);
        Calc(agent, "Incoming Ext Call", onPhone: true, 2);                  // remembered as LastPhoneStatusId
        AddCall(agent, db, "c", "Call", talking: false, disconnected: false, T(2));  // in _calls, not live voice
        Real(agent, "Paperwork", 3);                                         // a real status picked after the phone status
        agent.UserStatus.Should().Be("Paperwork", "precondition: the real status applied (reconcile, no live voice call)");
        return agent;
    }

    [Fact]
    public void LastNoPhone_PreserveOn_KeepsTheFresherRealStatus()
    {
        var savedP = AppConfig.LastNoPhonePreserveRealStatusEnabled;
        var savedR = AppConfig.OnPhoneReconcileEnabled;
        try
        {
            AppConfig.OnPhoneReconcileEnabled = true;
            AppConfig.LastNoPhonePreserveRealStatusEnabled = true;
            var agent = ArrangeRealStatusAfterPhoneStatus(StubDb(), "b1");

            Calc(agent, "LastNoPhone", onPhone: false, 4);

            agent.UserStatus.Should().Be("Paperwork");
        }
        finally { AppConfig.LastNoPhonePreserveRealStatusEnabled = savedP; AppConfig.OnPhoneReconcileEnabled = savedR; }
    }

    [Fact]
    public void LastNoPhone_PreserveOff_RestoresTheRememberedPhoneStatusAsBefore()
    {
        var savedP = AppConfig.LastNoPhonePreserveRealStatusEnabled;
        var savedR = AppConfig.OnPhoneReconcileEnabled;
        try
        {
            AppConfig.OnPhoneReconcileEnabled = true;
            AppConfig.LastNoPhonePreserveRealStatusEnabled = false;
            var agent = ArrangeRealStatusAfterPhoneStatus(StubDb(), "b2");

            Calc(agent, "LastNoPhone", onPhone: false, 4);

            agent.UserStatus.Should().Be("Incoming Ext Call", "a literal false restores the legacy resolution - the defect itself");
        }
        finally { AppConfig.LastNoPhonePreserveRealStatusEnabled = savedP; AppConfig.OnPhoneReconcileEnabled = savedR; }
    }

    // ---------- 07-30: ringing round-2 ----------

    [Fact]
    public void LastNoPhone_WithNothingToResolveTo_NeverAppliesAnEmptyStatus()
    {
        var agent = NewAgent("r1", StubDb());
        Real(agent, "ממתין לשיחה", 1);              // logs in without filling the non-phone cache
        Calc(agent, "Ringing", onPhone: false, 2);

        Calc(agent, "LastNoPhone", onPhone: false, 3);

        agent.UserStatus.Should().Be("Ringing", "the empty-resolution guard keeps the current status");
    }

    [Fact]
    public void RingEraser_ClearsOnlyTheRingItTagged()
    {
        var agent = NewAgent("r2", StubDb());
        Real(agent, "Available", 1);
        Calc(agent, "Ringing", onPhone: false, 2);
        agent.TagCalcRinging("X");

        agent.ClearCalcRingingIfTaggedTo("Y", T(3), 3);
        agent.UserStatus.Should().Be("Ringing", "a different interaction's ring death must not clear this ring");

        agent.ClearCalcRingingIfTaggedTo("X", T(4), 4);
        agent.UserStatus.Should().Be("Available", "the tagged ring's death restores the last real activity");
    }

    // ---------- 07-30: Case-B / LongestInteraction ----------

    [Fact]
    public void LongestInteraction_SkipsDeadAndNotHandledEntries()
    {
        var db = StubDb();
        var agent = NewAgent("l1", db);
        AddCall(agent, db, "dead", "Call", talking: true, disconnected: true, T(1));      // oldest, dead
        AddCall(agent, db, "queued", "Call", talking: false, disconnected: false, T(2)); // not being handled
        var live = AddCall(agent, db, "live", "Call", talking: true, disconnected: false, T(3));

        agent.LongestInteraction.Should().BeSameAs(live);
        agent.LongestInteractionDuration.Should().Be(T(3));
    }

    [Fact]
    public void LongestInteraction_IsNullWhenNothingIsHandled()
    {
        var db = StubDb();
        var agent = NewAgent("l2", db);
        AddCall(agent, db, "dead", "Call", talking: true, disconnected: true, T(1));

        agent.LongestInteraction.Should().BeNull();
        agent.LongestInteractionDuration.Should().Be(DateTime.MinValue);
    }

    // ---------- 07-15: consult (warm-transfer) retention ----------

    private static (WorkgroupManager wgm, CallsList calls, IDInteractionsList interactions) NewWorkgroup(DBMng db)
    {
        var unions = new UnionList();
        var interactions = new IDInteractionsList(unions);
        var calls = new CallsList();
        var wgm = new WorkgroupManager("wg", new UserManagerList(), calls, new ConcurrentQueue<string>(), interactions, db);
        return (wgm, calls, interactions);
    }

    private Task<Call> Event(WorkgroupManager wgm, string id, int seg, string state, string user,
        bool isConsult = false, string consultCallId = "", string customCallData19 = "") =>
        wgm.interactionAction(true, id, seg, false, "External", "Call", "Incoming", state, T(seg),
            TimeSpan.Zero, TimeSpan.Zero, isConsult, consultCallId, "", "", user, "",
            "", "", "", "", "", new List<string>(), false, "", "",
            "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", customCallData19, "", seg);

    [Fact]
    public async Task Consult_WarmTransfer_RetainsTheInitiatorsLeg()
    {
        var db = StubDb();
        var (wgm, calls, interactions) = NewWorkgroup(db);
        var first = await Event(wgm, "T1", 1, "accepted", "A");

        await Event(wgm, "T1", 2, "pending", "B", isConsult: true, consultCallId: "A");

        wgm.RetainedConsultLegCount.Should().Be(1);
        calls["T1"].Should().NotBeSameAs(first, "the transferred-to segment runs on a fresh Call");
        interactions.getInteraction("T1", 1).IsTalk.Should().BeTrue("the initiator stays bridged to the held customer");
    }

    [Fact]
    public async Task Consult_NotFlagged_ReleasesTheFirstSegmentAsBefore()
    {
        var db = StubDb();
        var (wgm, calls, interactions) = NewWorkgroup(db);
        var first = await Event(wgm, "T2", 1, "accepted", "A");

        await Event(wgm, "T2", 2, "pending", "B");   // the production adapter: isConsult is always false

        wgm.RetainedConsultLegCount.Should().Be(0);
        calls["T2"].Should().BeSameAs(first);
        interactions.getInteraction("T2", 1).IsTalk.Should().BeFalse("segment advance ends the first segment's talk");
    }

    [Fact]
    public async Task Consult_InitiatorMismatch_FallsBackToTheOrdinaryPath()
    {
        var db = StubDb();
        var (wgm, _, _) = NewWorkgroup(db);
        await Event(wgm, "T3", 1, "accepted", "A");

        await Event(wgm, "T3", 2, "pending", "B", isConsult: true, consultCallId: "Z");

        wgm.RetainedConsultLegCount.Should().Be(0);
    }

    [Fact]
    public async Task ConsultLegSweep_FinalizesOnlyLegsOlderThanTheLimit()
    {
        var db = StubDb();
        var (wgm, _, _) = NewWorkgroup(db);
        await Event(wgm, "T4", 1, "accepted", "A");
        await Event(wgm, "T4", 2, "pending", "B", isConsult: true, consultCallId: "A");
        wgm.RetainedConsultLegCount.Should().Be(1, "precondition");

        // [SYNC-PORT 2026-10-16 src=2026-08-19] This pins the 07-15 blind cap. From 08-19 an alive leg is re-armed instead
        // (Fix C, default ON - covered in LegacyPortD3Tests), so the 07-15 behaviour is exactly the switch-off case.
        var savedVerify = AppConfig.ConsultLegCapVerifyEnabled;
        AppConfig.ConsultLegCapVerifyEnabled = false;
        try
        {
            var maxAge = TimeSpan.FromSeconds(1800);
            await wgm.FinalizeStaleConsultLegs(maxAge, DateTime.UtcNow.AddSeconds(1700));
            wgm.RetainedConsultLegCount.Should().Be(1, "younger than the limit - a genuine consult is never cut short");

            await wgm.FinalizeStaleConsultLegs(maxAge, DateTime.UtcNow.AddSeconds(1900));
            wgm.RetainedConsultLegCount.Should().Be(0, "older than the limit - a stranded leg is cleaned");
        }
        finally { AppConfig.ConsultLegCapVerifyEnabled = savedVerify; }
    }

    // ---------- 07-28 / 07-20 seam: the self-heal never duplicates ----------

    [Fact]
    public void EnsureRouted_IsIdempotent_AndHealsALostInteraction()
    {
        var db = StubDb();
        var unions = new UnionList();
        var union = new Union(1, new ConcurrentDictionary<string, MetricDef>());
        union.Queues.Add("Q");
        unions.TryAdd(1, union);
        var interactions = new IDInteractionsList(unions);

        var it = new IDInteraction("I1", 1, db, false) { Workgroup = "Q" };
        union.addAllInteractions(new List<IDInteraction> { it }, new ApplicList(unions), false); // registers applic Q/ALL and imports it
        int afterImport = QueueBagCount(union);
        afterImport.Should().Be(1, "precondition: the import put it in the queue bag");

        interactions.EnsureRouted(it);
        interactions.EnsureRouted(it);
        QueueBagCount(union).Should().Be(1, "re-routing an interaction already accounted for adds nothing");

        union.addAllInteractions(new List<IDInteraction>(), new ApplicList(unions), false);    // a racing import wipes the bag
        QueueBagCount(union).Should().Be(0, "precondition: the wipe lost it");
        interactions.EnsureRouted(it);
        QueueBagCount(union).Should().Be(1, "the next event re-adds it (keys were cleared in lockstep with the bag)");
    }

    private static int QueueBagCount(Union union)
    {
        var bag = typeof(Union).GetProperty("QueueInteractions", BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Instance)!.GetValue(union)!;
        var inner = bag.GetType().GetProperty("Bag")!.GetValue(bag)!;
        return ((System.Collections.ICollection)inner).Count;
    }
}
