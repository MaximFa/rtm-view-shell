using System.Collections.Concurrent;
using System.Reflection;
using System.Runtime.CompilerServices;
using FluentAssertions;
using RTM;
using RTM.Configuration;

namespace RTM.Engine.Tests;

/// <summary>
/// SYNC-PORT 2026-10-16, rail D3: legacy rounds 08-19 (Fix A status authority, Fix C cap verify-before-kill, absolute
/// ceiling), 08-25 (day-wrap), 09-07 (retained-leg real fix: alive-by-interaction, alive touch; cross-channel OnPhone
/// guard), 09-14 engine side (email typing) and 09-15 (cold-start seed). Every behaviour has its negative half: the
/// kill-switch off, or the same input one condition short. The switches are static: shared collection, every test restores.
/// </summary>
[Collection("AppConfigSwitches")]
public class LegacyPortD3Tests
{
    // ---------- harness ----------

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

    private static Call AddCall(UserManager agent, DBMng db, string id, string type, bool talking, DateTime addTime)
    {
        var call = new Call(id, new UserManagerList(), new IDInteractionsList(new UnionList()), db);
        var it = new IDInteraction(id, 1, db, false) { InteractionType = type };
        it.IsTalk = talking;
        typeof(Call).GetProperty("IdInteraction")!.SetValue(call, it);
        CallsOf(agent)[call] = addTime;
        return call;
    }

    /// <summary>A Call whose interaction is registered in the call's own list, so SetCall acts on it.</summary>
    private static (Call call, IDInteraction it) RegisteredCall(DBMng db, UserManagerList users, string id, string type, string userId)
    {
        var list = new IDInteractionsList(new UnionList());
        var it = new IDInteraction(id, 1, db, false) { InteractionType = type, Workgroup = "wg", UserId = userId, Direction = "Incoming" };
        list.Add(it, false);
        var call = new Call(id, users, list, db);
        typeof(Call).GetProperty("IdInteraction")!.SetValue(call, it);
        return (call, it);
    }

    private static void SetCallAt(Call call, IDInteraction it, string state, string userId, DateTime at, long messageId) =>
        call.SetCall(it.InteractionType, it.Segment, "External", "Incoming", state, at, "wg", userId,
            TimeSpan.Zero, TimeSpan.Zero, false, "", "", "", "",
            "", "", new List<string>(), false, "", "",
            "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
            false, messageId);

    private static void With<T>(Func<T> get, Action<T> set, T value, Action body)
    {
        var saved = get();
        try { set(value); body(); }
        finally { set(saved); }
    }

    private static async Task WithAsync<T>(Func<T> get, Action<T> set, T value, Func<Task> body)
    {
        var saved = get();
        try { set(value); await body(); }
        finally { set(saved); }
    }

    // Per test instance: later than every UserManager birth stamp in the test.
    private readonly DateTime T0 = DateTime.Now.AddMinutes(5);
    private DateTime T(int s) => T0.AddSeconds(s);

    private void Real(UserManager a, string status, int s) =>
        a.setStatus(true, status, status, status.ToUpperInvariant(), T(s), "", false, DateTime.MinValue, s, false);

    private void Calc(UserManager a, string status, bool onPhone, int s) =>
        a.setStatus(true, status, status, "ONPHONE", T(s), "", onPhone, T(s), s, true);

    // ---------- 08-19 Fix A: the wait-entry token obeys the live-call authority ----------

    private const string WaitEntry = "ממתין לשיחה";

    private UserManager OnPhoneAgent(string id, bool liveVoice)
    {
        var db = StubDb();
        var agent = NewAgent(id, db);
        Real(agent, "Available", 1);
        Calc(agent, "Incoming Ext Call", onPhone: true, 2);
        if (liveVoice) AddCall(agent, db, id + "-voice", "Call", talking: true, T(2));
        return agent;
    }

    [Fact]
    public void FixA_On_WaitEntryDuringALiveCall_IsDropped()
    {
        With(() => AppConfig.WaitStatusAuthorityEnabled, v => AppConfig.WaitStatusAuthorityEnabled = v, true, () =>
        {
            var agent = OnPhoneAgent("fa1", liveVoice: true);
            Real(agent, WaitEntry, 3);
            agent.UserStatus.Should().Be("Incoming Ext Call", "during a call the calculated status is authoritative");
            agent.OnPhone.Should().BeTrue();
        });
    }

    [Fact]
    public void FixA_Off_OrNoLiveCall_WaitEntryAppliesAsBefore()
    {
        With(() => AppConfig.WaitStatusAuthorityEnabled, v => AppConfig.WaitStatusAuthorityEnabled = v, false, () =>
        {
            var agent = OnPhoneAgent("fa2", liveVoice: true);
            Real(agent, WaitEntry, 3);
            agent.UserStatus.Should().Be(WaitEntry, "a literal false restores the unconditional wait-entry apply");
        });

        With(() => AppConfig.WaitStatusAuthorityEnabled, v => AppConfig.WaitStatusAuthorityEnabled = v, true, () =>
        {
            var agent = OnPhoneAgent("fa3", liveVoice: false);
            Real(agent, WaitEntry, 3);
            agent.UserStatus.Should().Be(WaitEntry, "with no live call the wait entry is untouched by Fix A");
        });
    }

    // ---------- 08-19 Fix C + safety circle, 09-07 changes 1 and 2: the retained consult leg cap ----------

    private static (WorkgroupManager wgm, IDInteractionsList interactions) NewWorkgroup(DBMng db)
    {
        var interactions = new IDInteractionsList(new UnionList());
        var wgm = new WorkgroupManager("wg", new UserManagerList(), new CallsList(), new ConcurrentQueue<string>(), interactions, db);
        return (wgm, interactions);
    }

    private Task<Call> Event(WorkgroupManager wgm, string id, int seg, string state, string user,
        bool isConsult = false, string consultCallId = "") =>
        wgm.interactionAction(true, id, seg, false, "External", "Call", "Incoming", state, T(seg),
            TimeSpan.Zero, TimeSpan.Zero, isConsult, consultCallId, "", "", user, "",
            "", "", "", "", "", new List<string>(), false, "", "",
            "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", seg);

    /// <summary>Initiator A on segment 1 warm-transfers to B on segment 2: segment 1 is retained (live, talking).</summary>
    private async Task<(WorkgroupManager wgm, IDInteractionsList interactions)> RetainedLeg(string id)
    {
        var (wgm, interactions) = NewWorkgroup(StubDb());
        await Event(wgm, id, 1, "accepted", "A");
        await Event(wgm, id, 2, "pending", "B", isConsult: true, consultCallId: "A");
        wgm.RetainedConsultLegCount.Should().Be(1, "precondition: the initiator's leg is retained");
        return (wgm, interactions);
    }

    private static readonly TimeSpan Cap = TimeSpan.FromSeconds(1800);

    [Fact]
    public async Task CapVerify_On_KeepsAnAliveLegAndReArmsTheCap_Off_FinalizesIt()
    {
        await WithAsync(() => AppConfig.ConsultLegCapVerifyEnabled, v => AppConfig.ConsultLegCapVerifyEnabled = v, true, async () =>
        {
            var (wgm, _) = await RetainedLeg("C1");
            var at = DateTime.UtcNow.AddSeconds(1900);
            await wgm.FinalizeStaleConsultLegs(Cap, at);
            wgm.RetainedConsultLegCount.Should().Be(1, "the leg is still live: the cap re-arms instead of killing it");
            var state = wgm.RetainedLegCapState("C1", 1)!.Value;
            state.CapExtensions.Should().Be(1);
            state.CapAnchorUtc.Should().Be(at);
        });

        await WithAsync(() => AppConfig.ConsultLegCapVerifyEnabled, v => AppConfig.ConsultLegCapVerifyEnabled = v, false, async () =>
        {
            var (wgm, _) = await RetainedLeg("C2");
            await wgm.FinalizeStaleConsultLegs(Cap, DateTime.UtcNow.AddSeconds(1900));
            wgm.RetainedConsultLegCount.Should().Be(0, "a literal false restores the blind finalize at the cap");
        });
    }

    [Fact]
    public async Task CapVerify_On_ADeadLegIsStillFinalizedAtTheCap()
    {
        await WithAsync(() => AppConfig.ConsultLegCapVerifyEnabled, v => AppConfig.ConsultLegCapVerifyEnabled = v, true, async () =>
        {
            var (wgm, interactions) = await RetainedLeg("C3");
            interactions.getInteraction("C3", 1).IsTalk = false;   // the leg's own record is no longer live

            await wgm.FinalizeStaleConsultLegs(Cap, DateTime.UtcNow.AddSeconds(1700));
            wgm.RetainedConsultLegCount.Should().Be(1, "inside the cap window nothing is decided");

            await wgm.FinalizeStaleConsultLegs(Cap, DateTime.UtcNow.AddSeconds(1900));
            wgm.RetainedConsultLegCount.Should().Be(0, "verify-before-kill keeps only a demonstrably alive leg");
        });
    }

    [Fact]
    public async Task AbsoluteCeiling_FinalizesAnExtendedLeg_ZeroDisablesIt()
    {
        var savedVerify = AppConfig.ConsultLegCapVerifyEnabled;
        var savedAbs = AppConfig.ConsultLegAbsoluteMaxSeconds;
        try
        {
            AppConfig.ConsultLegCapVerifyEnabled = true;

            AppConfig.ConsultLegAbsoluteMaxSeconds = 3000;
            var (wgm, _) = await RetainedLeg("A1");
            var start = DateTime.UtcNow;
            await wgm.FinalizeStaleConsultLegs(Cap, start.AddSeconds(1900));      // extended: anchor moves to +1900
            wgm.RetainedConsultLegCount.Should().Be(1, "precondition: extended once");
            await wgm.FinalizeStaleConsultLegs(Cap, start.AddSeconds(3100));      // window 1200 s < cap, but total >= 3000
            wgm.RetainedConsultLegCount.Should().Be(0, "the ceiling is checked before the cap window and overrides it");

            AppConfig.ConsultLegAbsoluteMaxSeconds = 0;
            var (wgm2, _) = await RetainedLeg("A2");
            var start2 = DateTime.UtcNow;
            await wgm2.FinalizeStaleConsultLegs(Cap, start2.AddSeconds(1900));
            await wgm2.FinalizeStaleConsultLegs(Cap, start2.AddSeconds(3100));
            wgm2.RetainedConsultLegCount.Should().Be(1, "an explicit value <= 0 disables the ceiling");
        }
        finally
        {
            AppConfig.ConsultLegCapVerifyEnabled = savedVerify;
            AppConfig.ConsultLegAbsoluteMaxSeconds = savedAbs;
        }
    }

    [Fact]
    public async Task AliveByInteraction_On_NeedsNoSibling_Off_RequiresAnotherActiveSegment()
    {
        var savedVerify = AppConfig.ConsultLegCapVerifyEnabled;
        var savedAlive = AppConfig.ConsultLegAliveByInteractionEnabled;
        try
        {
            AppConfig.ConsultLegCapVerifyEnabled = true;

            AppConfig.ConsultLegAliveByInteractionEnabled = true;
            var (wgm, interactions) = await RetainedLeg("B1");
            interactions.getInteraction("B1", 2).Disconnected();   // the transferred-to segment ended first
            await wgm.FinalizeStaleConsultLegs(Cap, DateTime.UtcNow.AddSeconds(1900));
            wgm.RetainedConsultLegCount.Should().Be(1, "the initiator alone with the customer is a live call");

            AppConfig.ConsultLegAliveByInteractionEnabled = false;
            var (wgm2, interactions2) = await RetainedLeg("B2");
            var start = DateTime.UtcNow;
            await wgm2.FinalizeStaleConsultLegs(Cap, start.AddSeconds(1900));
            wgm2.RetainedConsultLegCount.Should().Be(1, "positive control of the 08-19 rule: a sibling is active");
            interactions2.getInteraction("B2", 2).Disconnected();
            await wgm2.FinalizeStaleConsultLegs(Cap, start.AddSeconds(3800));
            wgm2.RetainedConsultLegCount.Should().Be(0, "a literal false restores the sibling requirement");
        }
        finally
        {
            AppConfig.ConsultLegCapVerifyEnabled = savedVerify;
            AppConfig.ConsultLegAliveByInteractionEnabled = savedAlive;
        }
    }

    [Fact]
    public async Task AliveTouch_AnEventOnTheRetainedSegmentReAnchorsTheCap_OnlyWhenOn()
    {
        await WithAsync(() => AppConfig.ConsultLegAliveTouchEnabled, v => AppConfig.ConsultLegAliveTouchEnabled = v, true, async () =>
        {
            var (wgm, _) = await RetainedLeg("L1");
            var before = wgm.RetainedLegCapState("L1", 1)!.Value;
            await Event(wgm, "L1", 1, "accepted", "A");
            var after = wgm.RetainedLegCapState("L1", 1)!.Value;
            after.AliveTouches.Should().Be(1);
            after.CapAnchorUtc.Should().BeOnOrAfter(before.CapAnchorUtc);
        });

        await WithAsync(() => AppConfig.ConsultLegAliveTouchEnabled, v => AppConfig.ConsultLegAliveTouchEnabled = v, false, async () =>
        {
            var (wgm, _) = await RetainedLeg("L2");
            var before = wgm.RetainedLegCapState("L2", 1)!.Value;
            await Event(wgm, "L2", 1, "accepted", "A");
            var after = wgm.RetainedLegCapState("L2", 1)!.Value;
            after.AliveTouches.Should().Be(0, "a literal false removes the re-anchor");
            after.CapAnchorUtc.Should().Be(before.CapAnchorUtc);
        });
    }

    // ---------- 09-07 cross-channel OnPhone guard ----------

    /// <summary>Agent on a live voice call (OnPhone) who also holds a second talking interaction of the given type.</summary>
    private (UserManager agent, Call other, IDInteraction otherIt) VoiceAgentWithSecond(string id, string secondType)
    {
        var db = StubDb();
        var users = new UserManagerList();
        var agent = NewAgent(id, db);
        users[id] = agent;
        Real(agent, "Available", 1);
        Calc(agent, "Incoming Ext Call", onPhone: true, 2);
        AddCall(agent, db, id + "-voice", "Call", talking: true, T(2));
        var (other, it) = RegisteredCall(db, users, id + "-second", secondType, id);
        it.IsTalk = true;
        it.IsAnswered = true;
        CallsOf(agent)[other] = T(2);
        return (agent, other, it);
    }

    [Fact]
    public void CrossChannel_On_AChatEndingDuringAVoiceCallKeepsOnPhone_Off_ClearsIt()
    {
        With(() => AppConfig.CrossChannelOnPhoneGuardEnabled, v => AppConfig.CrossChannelOnPhoneGuardEnabled = v, true, () =>
        {
            var (agent, chat, chatIt) = VoiceAgentWithSecond("x1", "Chat");
            SetCallAt(chat, chatIt, "forceClose", "x1", T(3), 3);
            agent.OnPhone.Should().BeTrue("the chat end must not run the phone-end resolution while the voice call lives");
        });

        With(() => AppConfig.CrossChannelOnPhoneGuardEnabled, v => AppConfig.CrossChannelOnPhoneGuardEnabled = v, false, () =>
        {
            var (agent, chat, chatIt) = VoiceAgentWithSecond("x2", "Chat");
            SetCallAt(chat, chatIt, "forceClose", "x2", T(3), 3);
            agent.OnPhone.Should().BeFalse("a literal false restores the old behaviour - the defect itself");
        });
    }

    [Fact]
    public void CrossChannel_On_AVoiceEndIsNeverSuppressed()
    {
        With(() => AppConfig.CrossChannelOnPhoneGuardEnabled, v => AppConfig.CrossChannelOnPhoneGuardEnabled = v, true, () =>
        {
            var (agent, dup, dupIt) = VoiceAgentWithSecond("x3", "Call");
            SetCallAt(dup, dupIt, "forceClose", "x3", T(3), 3);
            agent.OnPhone.Should().BeFalse("only a chat/email end is guarded; a voice end behaves exactly as before");
        });
    }

    // ---------- 09-14 email typing (engine side) ----------

    [Fact]
    public void EmailChannel_On_AcceptsTheWireValueInAnyCase_Off_OnlyTheExactWord()
    {
        With(() => AppConfig.EmailTypingFixEnabled, v => AppConfig.EmailTypingFixEnabled = v, true, () =>
        {
            UserManager.IsEmailChannel("email").Should().BeTrue();
            UserManager.IsEmailChannel("Email").Should().BeTrue();
            UserManager.IsEmailChannel("Call").Should().BeFalse();
        });

        With(() => AppConfig.EmailTypingFixEnabled, v => AppConfig.EmailTypingFixEnabled = v, false, () =>
        {
            UserManager.IsEmailChannel("email").Should().BeFalse("a literal false restores the exact \"Email\" comparison");
            UserManager.IsEmailChannel("Email").Should().BeTrue();
        });
    }

    [Fact]
    public void EmailChannel_On_AnEmailTaskIsNotALiveVoiceCall()
    {
        With(() => AppConfig.EmailTypingFixEnabled, v => AppConfig.EmailTypingFixEnabled = v, true, () =>
        {
            var db = StubDb();
            var agent = NewAgent("e1", db);
            AddCall(agent, db, "mail", "email", talking: true, T(1));
            agent.HasLiveVoiceCall().Should().BeFalse("the wire value \"email\" is an email, not a voice call");
        });

        With(() => AppConfig.EmailTypingFixEnabled, v => AppConfig.EmailTypingFixEnabled = v, false, () =>
        {
            var db = StubDb();
            var agent = NewAgent("e2", db);
            AddCall(agent, db, "mail", "email", talking: true, T(1));
            agent.HasLiveVoiceCall().Should().BeTrue("the old exact test counts it as voice - the defect itself");
        });
    }

    // ---------- 09-15 cold-start seed ----------

    private static void SeedAt(UserManager a, string status, DateTime at, long messageId) =>
        a.setStatus(true, status, status, status.ToUpperInvariant(), at, "", false, DateTime.MinValue, messageId, false);

    [Fact]
    public void ColdStart_On_TheSeedThatCreatesTheUserApplies_AGenuinelyLateUpdateIsStillDropped()
    {
        With(() => AppConfig.ColdStartSeedFixEnabled, v => AppConfig.ColdStartSeedFixEnabled = v, true, () =>
        {
            var agent = NewAgent("s1", StubDb());
            var seedAt = DateTime.Now.AddSeconds(-5);           // stamped before the user was born
            agent.TimeInStatus.Should().BeCloseTo(DateTime.Now, TimeSpan.FromMinutes(1), "before the seed, readers still see the birth time");

            SeedAt(agent, "Available", seedAt, 1);
            agent.UserStatus.Should().Be("Available", "a newborn user knows nothing, so the seed is never stale");
            agent.TimeInStatus.Should().Be(seedAt);

            SeedAt(agent, "Break", seedAt.AddSeconds(-5), 2);
            agent.UserStatus.Should().Be("Available", "an update older than an applied status is still dropped");
        });
    }

    [Fact]
    public void ColdStart_Off_TheSeedIsDroppedAsBefore()
    {
        With(() => AppConfig.ColdStartSeedFixEnabled, v => AppConfig.ColdStartSeedFixEnabled = v, false, () =>
        {
            var agent = NewAgent("s2", StubDb());
            SeedAt(agent, "Available", DateTime.Now.AddSeconds(-5), 1);
            agent.UserStatus.Should().Be("SIGNOFF", "a literal false restores the birth stamp that out-ranks the seed - the defect");
        });
    }

    // ---------- 08-25 day-wrap ----------

    [Fact]
    public void WholeHours_KeepsTheDays_IdenticalBelow24h()
    {
        var long1 = new TimeSpan(1, 23, 52, 16);
        long1.ToString(@"hh\:mm\:ss").Should().Be("23:52:16", "the defect: hh drops the days");
        DurationText.WholeHours(long1).Should().Be("47:52:16");

        var short1 = new TimeSpan(0, 1, 2, 3);
        DurationText.WholeHours(short1).Should().Be(short1.ToString(@"hh\:mm\:ss"), "below 24 h nothing changes");
        DurationText.WholeHours(TimeSpan.Zero).Should().Be("00:00:00");
    }

    private static readonly Type EngineType = typeof(DBMng).Assembly.GetType("RTM.Engine", throwOnError: true)!;

    [Fact]
    public void WaitDurationAvgTemplate_RendersWaitsOver24hInWholeHours()
    {
        var engine = RuntimeHelpers.GetUninitializedObject(EngineType);
        var bodies = new ConcurrentDictionary<string, string>();
        EngineType.GetProperty("MetricFunctionList", BindingFlags.NonPublic | BindingFlags.Instance)!.SetValue(engine, bodies);
        EngineType.GetMethod("setMetricFunctions", BindingFlags.NonPublic | BindingFlags.Instance, null, Type.EmptyTypes, null)!
            .Invoke(engine, null);
        var body = bodies["WaitDurationAvg"].Replace("METRIC_PARAMETER", "true").Replace("METRIC_DIRECTION", "true").Replace("METRIC_FORMAT", "\"\"");
        var def = new MetricDef { ID = "D3_wait_" + Guid.NewGuid().ToString("N"), Function = "WaitDurationAvg", Parameter = "true", Format = "" };
        EngineType.GetMethod("CompileAndSetMetricFunction")!.Invoke(engine, new object[] { def, body });
        def.MetricFunction.Should().NotBeNull("the template must compile against buildTemplateReferences (RTM.DurationText)");

        var longWait = new ConcurrentBag<IDInteraction> { new IDInteraction("W1", 1, null, false) { TimeInQueue = 26 * 3600 + 90 } };
        def.MetricFunction(longWait, true).Should().Be("26:01:30", "a 26 h wait is not shown as 02:01:30");

        var shortWait = new ConcurrentBag<IDInteraction> { new IDInteraction("W2", 1, null, false) { TimeInQueue = 90 } };
        def.MetricFunction(shortWait, true).Should().Be("00:01:30", "below 24 h the text is unchanged");
    }
}
