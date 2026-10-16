using System.Collections.Concurrent;
using System.Reflection;
using System.Runtime.CompilerServices;
using FluentAssertions;
using RTM;
using RTM.Configuration;
using CA = Microsoft.CodeAnalysis;
using CS = Microsoft.CodeAnalysis.CSharp;

namespace RTM.Engine.Tests;

/// <summary>
/// SYNC-PORT 2026-10-15, rail D2: legacy rounds 08-05 (orphan reap, FAIL-SAFE OFF), 08-06 engine side (segment de-dup,
/// per-agent day de-dup, Item-4 callback on the bulk terminal) and the receiving side of the 07-15/07-20 bulk terminal
/// (interactionRemovedAll), plus the D1 leftovers (removeCall, ring-only terminal).
/// Every behaviour has its negative half; the switches are static, so this class shares the D1 collection.
/// </summary>
[Collection("AppConfigSwitches")]
public class LegacyPortD2Tests
{
    // ---------- harness ----------

    private static DBMng StubDb()
    {
        var db = (DBMng)RuntimeHelpers.GetUninitializedObject(typeof(DBMng));
        var queueField = typeof(DBMng).GetField("_requestsQueue", BindingFlags.NonPublic | BindingFlags.Instance)!;
        queueField.SetValue(db, Activator.CreateInstance(queueField.FieldType));
        return db;
    }

    private static ConcurrentDictionary<Call, DateTime> CallsOf(UserManager agent) =>
        (ConcurrentDictionary<Call, DateTime>)typeof(UserManager)
            .GetField("_calls", BindingFlags.NonPublic | BindingFlags.Instance)!.GetValue(agent)!;

    /// <summary>A Call whose interaction is REGISTERED in the call's own list, so SetCall acts on it (not on a fresh one).</summary>
    private static (Call call, IDInteraction it) RegisteredCall(DBMng db, UserManagerList users, string id, string type, string userId)
    {
        var list = new IDInteractionsList(new UnionList());
        var it = new IDInteraction(id, 1, db, false) { InteractionType = type, Workgroup = "wg", UserId = userId, Direction = "Incoming" };
        list.Add(it, false);
        var call = new Call(id, users, list, db);
        typeof(Call).GetProperty("IdInteraction")!.SetValue(call, it);
        return (call, it);
    }

    private static void SetCall(Call call, IDInteraction it, string state, string userId, bool isCallbackRequest = false) =>
        call.SetCall(it.InteractionType, it.Segment, "External", "Incoming", state, DateTime.Now, "wg", userId,
            TimeSpan.Zero, TimeSpan.Zero, false, "", "", "", "",
            "", "", new List<string>(), false, "", "",
            "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
            isCallbackRequest, 1);

    private static T WithSwitch<T>(Func<bool> get, Action<bool> set, bool value, Func<T> body)
    {
        var saved = get();
        try { set(value); return body(); }
        finally { set(saved); }
    }

    // ---------- 08-06 Item 1: segment de-dup in the compiled queue metrics ----------

    // The test namespace RTM.Engine.Tests makes RTM.Engine a namespace here, so the engine class is reached by reflection
    // (same approach as EngineCompiledFunctionTests).
    private static readonly Type EngineType = typeof(DBMng).Assembly.GetType("RTM.Engine", throwOnError: true)!;

    private static List<CA.MetadataReference> TemplateRefs() =>
        (List<CA.MetadataReference>)EngineType.GetMethod("buildTemplateReferences", BindingFlags.NonPublic | BindingFlags.Static)!.Invoke(null, null)!;

    private static Task RemovedAll(object engine, string interactionId, string cause, long messageId, bool isCallbackRequest = false) =>
        (Task)EngineType.GetMethod("interactionRemovedAll")!.Invoke(engine, new object[] { interactionId, cause, DateTime.Now, messageId, isCallbackRequest })!;

    private static MetricDef Compile(string functionName, string format = "#0.##%")
    {
        var engine = RuntimeHelpers.GetUninitializedObject(EngineType);
        var listProp = EngineType.GetProperty("MetricFunctionList", BindingFlags.NonPublic | BindingFlags.Instance)!;
        var bodies = new ConcurrentDictionary<string, string>();
        listProp.SetValue(engine, bodies);
        EngineType.GetMethod("setMetricFunctions", BindingFlags.NonPublic | BindingFlags.Instance, null, Type.EmptyTypes, null)!
            .Invoke(engine, null);

        var body = bodies[functionName]
            .Replace("METRIC_PARAMETER", "true")
            .Replace("METRIC_DIRECTION", "true")
            .Replace("METRIC_FORMAT", "\"" + format + "\"");
        var def = new MetricDef { ID = "D2_" + functionName + "_" + Guid.NewGuid().ToString("N"), Function = functionName, Parameter = "true", Format = format };
        EngineType.GetMethod("CompileAndSetMetricFunction")!.Invoke(engine, new object[] { def, body });
        def.MetricFunction.Should().NotBeNull("the template must compile - it reads the switch through RTM.MetricTemplateSwitches");
        return def;
    }

    /// <summary>Interaction X with two segments, Y with one: three segments, two calls.</summary>
    private static ConcurrentBag<IDInteraction> TwoCallsThreeSegments(Action<IDInteraction> x1, Action<IDInteraction> x2, Action<IDInteraction> y1)
    {
        var a = new IDInteraction("X", 1, null, false); x1(a);
        var b = new IDInteraction("X", 2, null, false); x2(b);
        var c = new IDInteraction("Y", 1, null, false); y1(c);
        return new ConcurrentBag<IDInteraction> { a, b, c };
    }

    private static string Run(MetricDef def, ConcurrentBag<IDInteraction> bag, bool dedup) =>
        WithSwitch(() => AppConfig.SegmentDedupEnabled, v => AppConfig.SegmentDedupEnabled = v, dedup, () => def.MetricFunction(bag, true));

    // ---------- template reference surface: RTM.Configuration (secrets) is not nameable from a metric template ----------

    [Fact]
    public void TemplateReferences_DropConfiguration_KeepEngine()
    {
        var tpa = ((string)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")).Split(Path.PathSeparator).Select(p => Path.GetFileName(p)).ToList();
        var refs = TemplateRefs()
            .OfType<CA.PortableExecutableReference>().Select(r => Path.GetFileName(r.FilePath)).ToList();

        // negative half: the platform list really carries RTM.Configuration, so the filter has something to remove
        tpa.Should().Contain(n => string.Equals(n, "RTM.Configuration.dll", StringComparison.OrdinalIgnoreCase));
        refs.Should().NotContain(n => string.Equals(n, "RTM.Configuration.dll", StringComparison.OrdinalIgnoreCase));
        refs.Should().Contain(Path.GetFileName(typeof(IDInteraction).Assembly.Location));
    }

    [Fact]
    public void SecretNamingSource_FailsWithTemplateRefs_CompilesOnlyWithConfigurationRef()
    {
        // compiled only, never executed: no secret value is read
        var tree = CS.CSharpSyntaxTree.ParseText(
            "public static class Probe { public static int F() => (RTM.Configuration.AppConfig.DatabasePassword ?? \"\").Length; }");
        var opts = new CS.CSharpCompilationOptions(CA.OutputKind.DynamicallyLinkedLibrary);
        var refs = TemplateRefs();

        CS.CSharpCompilation.Create("ProbeNoCfg", new[] { tree }, refs, opts).GetDiagnostics()
            .Where(d => d.Severity == CA.DiagnosticSeverity.Error).Should().NotBeEmpty("a template must not be able to name AppConfig");

        var withCfg = refs.Concat(new[] { CA.MetadataReference.CreateFromFile(typeof(AppConfig).Assembly.Location) }).ToList();
        CS.CSharpCompilation.Create("ProbeCfg", new[] { tree }, withCfg, opts).GetDiagnostics()
            .Where(d => d.Severity == CA.DiagnosticSeverity.Error).Should().BeEmpty("positive control: only the missing reference blocks it");
    }

    [Fact]
    public void ProductCompilePath_RejectsSecretTemplate_SwitchTemplateWorksBothWays()
    {
        var engine = RuntimeHelpers.GetUninitializedObject(EngineType);
        var compile = EngineType.GetMethod("CompileAndSetMetricFunction")!;

        var bad = new MetricDef { ID = "D2_secret_" + Guid.NewGuid().ToString("N"), Function = "probe", Parameter = "true", Format = "" };
        compile.Invoke(engine, new object[] { bad, "return (RTM.Configuration.AppConfig.DatabasePassword ?? \"\").Length.ToString();" });
        bad.MetricFunction.Should().BeNull("the secret-naming template must not compile");

        var good = new MetricDef { ID = "D2_switch_" + Guid.NewGuid().ToString("N"), Function = "probe", Parameter = "true", Format = "" };
        compile.Invoke(engine, new object[] { good, "return RTM.MetricTemplateSwitches.SegmentDedupEnabled ? \"on\" : \"off\";" });
        good.MetricFunction.Should().NotBeNull();
        var bag = new ConcurrentBag<IDInteraction>();
        WithSwitch(() => AppConfig.SegmentDedupEnabled, v => AppConfig.SegmentDedupEnabled = v, true, () => good.MetricFunction(bag, true)).Should().Be("on");
        WithSwitch(() => AppConfig.SegmentDedupEnabled, v => AppConfig.SegmentDedupEnabled = v, false, () => good.MetricFunction(bag, true)).Should().Be("off");
    }

    [Fact]
    public void AnsweredCount_CountsACallOnce_DedupOn_PerSegment_DedupOff()
    {
        var def = Compile("AnsweredCount");
        var bag = TwoCallsThreeSegments(i => i.IsAnswered = true, i => i.IsAnswered = true, i => i.IsAnswered = true);

        Run(def, bag, dedup: true).Should().Be("2");
        Run(def, bag, dedup: false).Should().Be("3", "a literal false restores the per-segment count");
    }

    [Fact]
    public void InteractionsCount_CountsDistinctInteractions()
    {
        var def = Compile("InteractionsCount");
        var bag = TwoCallsThreeSegments(_ => { }, _ => { }, _ => { });

        Run(def, bag, dedup: true).Should().Be("2");
        Run(def, bag, dedup: false).Should().Be("3");
    }

    [Fact]
    public void AbandonedPercent_DedupsNumeratorAndDenominator_AndKeepsEmptyOnNoData()
    {
        var def = Compile("AbandonedPercent");
        var bag = TwoCallsThreeSegments(i => i.IsAbandoned = true, i => i.IsAbandoned = true, i => i.IsAnswered = true);

        Run(def, bag, dedup: true).Should().Be((0.5).ToString("#0.##%"), "1 of 2 calls");
        Run(def, bag, dedup: false).Should().Be((2.0 / 3.0).ToString("#0.##%"), "2 of 3 segments");
        Run(def, new ConcurrentBag<IDInteraction>(), dedup: true).Should().Be(string.Empty, "our empty-on-no-data rule survives the port");
    }

    [Fact]
    public void WaitDurationAvg_TakesOneWaitPerInteraction()
    {
        var def = Compile("WaitDurationAvg", "");
        var bag = TwoCallsThreeSegments(i => i.TimeInQueue = 10, i => i.TimeInQueue = 30, i => i.TimeInQueue = 20);

        Run(def, bag, dedup: true).Should().Be("00:00:25", "X counts its longest wait (30), Y 20");
        Run(def, bag, dedup: false).Should().Be("00:00:20", "per segment: (10+30+20)/3");
    }

    [Fact]
    public void TalkDurationAvg_SumsTheSegmentsOfACall()
    {
        var def = Compile("TalkDurationAvg", "");
        var bag = TwoCallsThreeSegments(
            i => { i.IsAnswered = true; i.TalkTime = 10; },
            i => { i.IsAnswered = true; i.TalkTime = 30; },
            i => { i.IsAnswered = true; i.TalkTime = 20; });

        Run(def, bag, dedup: true).Should().Be("00:00:30", "X talks 10+30=40, Y 20");
        Run(def, bag, dedup: false).Should().Be("00:00:20");
    }

    // ---------- 08-06 Item 3: per-agent day de-dup ----------

    [Fact]
    public void CallsDurationList_CreditsAReCyclingInteractionOncePerDay()
    {
        WithSwitch(() => AppConfig.SegmentDedupEnabled, v => AppConfig.SegmentDedupEnabled = v, true, () =>
        {
            var list = new CallsDurationList("t");
            list.Add("A"); list.Remove("A"); list.Add("A");   // same interaction, next segment, same agent
            list.Add("B");
            list.Count.Should().Be(2);

            list.midnightClear();
            list.Remove("A"); list.Add("A");
            list.Count.Should().Be(1, "a new day credits it again");
            return 0;
        });
    }

    [Fact]
    public void CallsDurationList_DedupOff_CreditsEveryActivePeriod()
    {
        WithSwitch(() => AppConfig.SegmentDedupEnabled, v => AppConfig.SegmentDedupEnabled = v, false, () =>
        {
            var list = new CallsDurationList("t");
            list.Add("A"); list.Remove("A"); list.Add("A");
            list.Count.Should().Be(2);
            return 0;
        });
    }

    // ---------- 08-05: orphan reap (FAIL-SAFE) ----------

    private static (UserManager agent, Call old, IDInteraction oldIt) AgentWithLiveVoiceCall(DBMng db, bool held = false)
    {
        var users = new UserManagerList();
        var agent = new UserManager("o1", new UnionList(), db, new ConcurrentDictionary<string, MetricDef>());
        var (old, it) = RegisteredCall(db, users, "OLD", "Call", "o1");
        it.IsTalk = true;
        it.IsAnswered = true;
        if (held) it.IsHeld = true;
        CallsOf(agent)[old] = DateTime.Now.AddHours(-3);
        return (agent, old, it);
    }

    [Fact]
    public void Evict_Off_IsANoOp()
    {
        WithSwitch(() => AppConfig.OrphanReapEnabled, v => AppConfig.OrphanReapEnabled = v, false, () =>
        {
            var db = StubDb();
            var (agent, _, oldIt) = AgentWithLiveVoiceCall(db);
            var (newCall, _) = RegisteredCall(db, new UserManagerList(), "NEW", "Call", "o1");

            agent.EvictStalePrimaryVoiceCalls(newCall, DateTime.Now, 1);

            oldIt.IsTalk.Should().BeTrue("the family stays OFF unless a literal true");
            return 0;
        });
    }

    [Fact]
    public void Evict_On_FinalizesTheOtherLiveVoiceCall_ButNeverAHeldLeg()
    {
        WithSwitch(() => AppConfig.OrphanReapEnabled, v => AppConfig.OrphanReapEnabled = v, true, () =>
        {
            var db = StubDb();
            var (agent, _, oldIt) = AgentWithLiveVoiceCall(db);
            var (newCall, _) = RegisteredCall(db, new UserManagerList(), "NEW", "Call", "o1");
            agent.EvictStalePrimaryVoiceCalls(newCall, DateTime.Now, 1);
            oldIt.IsTalk.Should().BeFalse("accepting a new primary voice call proves the old one ended");

            var (agent2, _, heldIt) = AgentWithLiveVoiceCall(StubDb(), held: true);
            var (newCall2, _) = RegisteredCall(StubDb(), new UserManagerList(), "NEW2", "Call", "o1");
            agent2.EvictStalePrimaryVoiceCalls(newCall2, DateTime.Now, 1);
            heldIt.IsTalk.Should().BeTrue("a held leg is a hold/consult, never evicted");
            return 0;
        });
    }

    [Fact]
    public void Backstop_FinalizesOnlyCallsSilentLongerThanTheLimit()
    {
        WithSwitch(() => AppConfig.OrphanReapEnabled, v => AppConfig.OrphanReapEnabled = v, true, () =>
        {
            var now = DateTime.Now;
            var (agent, old, oldIt) = AgentWithLiveVoiceCall(StubDb());

            old.LastEventUtc = now.AddSeconds(-5000);
            agent.FinalizeStaleSilentVoiceCalls(TimeSpan.FromSeconds(5400), 1, now);
            oldIt.IsTalk.Should().BeTrue("silent 5000 s < 5400 s");

            old.LastEventUtc = now.AddSeconds(-6000);
            agent.FinalizeStaleSilentVoiceCalls(TimeSpan.FromSeconds(5400), 1, now);
            oldIt.IsTalk.Should().BeFalse("silent 6000 s >= 5400 s");
            return 0;
        });
    }

    [Fact]
    public void Backstop_Off_IsANoOp()
    {
        WithSwitch(() => AppConfig.OrphanReapEnabled, v => AppConfig.OrphanReapEnabled = v, false, () =>
        {
            var now = DateTime.Now;
            var (agent, old, oldIt) = AgentWithLiveVoiceCall(StubDb());
            old.LastEventUtc = now.AddSeconds(-60000);

            agent.FinalizeStaleSilentVoiceCalls(TimeSpan.FromSeconds(5400), 1, now);

            oldIt.IsTalk.Should().BeTrue();
            return 0;
        });
    }

    // ---------- bulk terminal: the forceClose cases in Call ----------

    private static IDInteraction QueuedSegment(DBMng db, out Call call, UserManagerList users = null, string userId = "")
    {
        var (c, it) = RegisteredCall(db, users ?? new UserManagerList(), "Q", "Call", userId);
        it.InQueue();
        call = c;
        return it;
    }

    [Fact]
    public void ForceClose_DequeuesWithoutAbandoning()
    {
        var it = QueuedSegment(StubDb(), out var call);
        SetCall(call, it, "forceClose", "");
        it.IsInQueue.Should().BeFalse();
        it.IsAbandoned.Should().BeFalse("cause completed: a phantom queued segment is not an abandon");
    }

    [Fact]
    public void ForceCloseAbandoned_AbandonsAQueuedSegment_UnlessItIsACallbackOptOut()
    {
        var it = QueuedSegment(StubDb(), out var call);
        SetCall(call, it, "forceCloseAbandoned", "");
        it.IsAbandoned.Should().BeTrue("cause canceled: the caller hung up in queue");

        var cb = QueuedSegment(StubDb(), out var cbCall);
        SetCall(cbCall, cb, "forceCloseAbandoned", "", isCallbackRequest: true);
        cb.IsCallbackRequest.Should().BeTrue();
        cb.IsAbandoned.Should().BeFalse("Item-4: a callback opt-out is not an abandonment");
    }

    [Fact]
    public void ForceClose_RingOnly_RemovesTheDeadEntryFromTheAgent()
    {
        var db = StubDb();
        var users = new UserManagerList();
        var agent = new UserManager("r", new UnionList(), db, new ConcurrentDictionary<string, MetricDef>());
        users["r"] = agent;
        var it = QueuedSegment(db, out var call, users, "r");
        CallsOf(agent)[call] = DateTime.Now;

        SetCall(call, it, "forceClose", "r");

        CallsOf(agent).ContainsKey(call).Should().BeFalse("a never-talking segment must not linger in the agent's active set");
    }

    // ---------- bulk terminal: Engine.interactionRemovedAll ----------

    private static object EngineWith(WorkgroupManager wgm, IDInteractionsList interactions, CallsList calls, DBMng db)
    {
        var engine = RuntimeHelpers.GetUninitializedObject(EngineType);
        void Set(string name, object value)
        {
            var f = EngineType.GetField(name, BindingFlags.NonPublic | BindingFlags.Instance);
            if (f != null) { f.SetValue(engine, value); return; }
            EngineType.GetProperty(name, BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Instance)!.SetValue(engine, value);
        }
        var wgList = new WorkgroupManagerList();
        wgList["wg"] = wgm;
        Set("_workgroupManagerList", wgList);
        Set("_interactionsList", interactions);
        Set("_userManagerList", new UserManagerList());
        Set("CallsList", calls);
        Set("_lastDisconnectedQ", new ConcurrentQueue<string>());
        Set("_applicList", new ApplicList(new UnionList()));
        Set("_dbMng", db);
        return engine;
    }

    private static Task<Call> Event(WorkgroupManager wgm, string id, int seg, string state, string user,
        bool isConsult = false, string consultCallId = "") =>
        wgm.interactionAction(true, id, seg, false, "External", "Call", "Incoming", state, DateTime.Now,
            TimeSpan.Zero, TimeSpan.Zero, isConsult, consultCallId, "", "", user, "",
            "", "", "", "", "", new List<string>(), false, "", "",
            "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", seg);

    private static (WorkgroupManager wgm, IDInteractionsList interactions, CallsList calls, DBMng db) Workgroup()
    {
        var db = StubDb();
        var interactions = new IDInteractionsList(new UnionList());
        var calls = new CallsList();
        var wgm = new WorkgroupManager("wg", new UserManagerList(), calls, new ConcurrentQueue<string>(), interactions, db);
        return (wgm, interactions, calls, db);
    }

    [Fact]
    public async Task RemovedAll_Canceled_ClosesEverySegment_AndAbandonsTheQueuedOne()
    {
        var (wgm, interactions, calls, db) = Workgroup();
        await Event(wgm, "R1", 1, "pending", "");                // queued, nobody ringing
        var engine = EngineWith(wgm, interactions, calls, db);

        await RemovedAll(engine, "R1", "canceled", 1);

        interactions.GetActiveSegments("R1").Should().BeEmpty("the bulk terminal closes every active segment");
        interactions.getInteraction("R1", 1).IsAbandoned.Should().BeTrue();
    }

    [Fact]
    public async Task RemovedAll_WithoutCause_IsTheNonAbandoningTerminal()
    {
        var (wgm, interactions, calls, db) = Workgroup();
        await Event(wgm, "R2", 1, "pending", "");
        var engine = EngineWith(wgm, interactions, calls, db);
        var (cause, isCb) = RTMAdapter.ParseRemovedAllOptions(new Dictionary<string, object>());   // an adapter that sends no cause

        await RemovedAll(engine, "R2", cause, 1, isCb);

        interactions.GetActiveSegments("R2").Should().BeEmpty();
        interactions.getInteraction("R2", 1).IsAbandoned.Should().BeFalse("absent cause = completed");
    }

    [Fact]
    public async Task RemovedAll_FinalizesARetainedConsultLegFirst()
    {
        var (wgm, interactions, calls, db) = Workgroup();
        await Event(wgm, "R3", 1, "accepted", "A");
        await Event(wgm, "R3", 2, "pending", "B", isConsult: true, consultCallId: "A");
        wgm.RetainedConsultLegCount.Should().Be(1, "precondition");
        var engine = EngineWith(wgm, interactions, calls, db);

        await RemovedAll(engine, "R3", "completed", 1);

        wgm.RetainedConsultLegCount.Should().Be(0);
        interactions.GetActiveSegments("R3").Should().BeEmpty();
    }

    // ---------- the old wire keeps the old behaviour ----------

    [Fact]
    public void WireDefaults_OnlyAnExplicitCanceledAbandons()
    {
        RTMAdapter.ParseRemovedAllOptions(new Dictionary<string, object>()).Should().Be(("completed", false));
        RTMAdapter.ParseRemovedAllOptions(new Dictionary<string, object> { ["cause"] = "canceled" }).Should().Be(("canceled", false));
        RTMAdapter.ParseRemovedAllOptions(new Dictionary<string, object> { ["cause"] = "Canceled" }).Should().Be(("completed", false));
        RTMAdapter.ParseRemovedAllOptions(new Dictionary<string, object> { ["isCallbackRequest"] = true }).Should().Be(("completed", true));
    }

    [Fact]
    public async Task OldWire_PerSegmentRemoval_IsUnchanged_AndNothingIsAbandoned()
    {
        // The production adapter never sends interactionRemovedAll; it removes per segment with state "canceled" etc.
        // The bulk terminal must not change that path: no retained legs, the segment ends through interactionRemoved.
        var (wgm, interactions, _, _) = Workgroup();
        await Event(wgm, "R4", 1, "accepted", "A");

        await wgm.interactionRemoved("R4", 1, true, "", "A", "completed", TimeSpan.Zero, false, 1);

        interactions.GetActiveSegments("R4").Should().BeEmpty();
        interactions.getInteraction("R4", 1).IsAbandoned.Should().BeFalse();
        wgm.RetainedConsultLegCount.Should().Be(0);
    }
}
