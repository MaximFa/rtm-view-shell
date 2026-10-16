using System.Collections.Concurrent;
using System.Reflection;
using System.Runtime.CompilerServices;
using FluentAssertions;
using RTM;
using RTM.Configuration;

namespace RTM.Engine.Tests;

/// <summary>
/// SYNC-PORT 2026-10-16, rail D4: operator decisions on the legacy's unmarked themes. U2 backdated terminal (a prior
/// day's interaction closing after midnight goes to its origin day's DB row and leaves today's counters) and U3 live-BU
/// removal applied through /LoadData (Bezeq semantics: removed queues leave at once, agents of a removed group leave,
/// a deleted BU is frozen until its midnight clear). Every part has its OFF half: a literal false must change nothing.
/// </summary>
[Collection("AppConfigSwitches")]
public class LegacyPortD4Tests
{
    // ---------- harness ----------

    private static DBMng StubDb()
    {
        var db = (DBMng)RuntimeHelpers.GetUninitializedObject(typeof(DBMng));
        var queueField = typeof(DBMng).GetField("_requestsQueue", BindingFlags.NonPublic | BindingFlags.Instance)!;
        queueField.SetValue(db, Activator.CreateInstance(queueField.FieldType));
        return db;
    }

    private static void With<T>(Func<T> get, Action<T> set, T value, Action body)
    {
        var saved = get();
        try { set(value); body(); }
        finally { set(saved); }
    }

    private static void Backdated(bool on, Action body) =>
        With(() => AppConfig.BackdatedTerminalEnabled, v => AppConfig.BackdatedTerminalEnabled = v, on, body);

    private static void LiveBu(bool on, Action body) =>
        With(() => AppConfig.LiveBusinessUnitRemovalEnabled, v => AppConfig.LiveBusinessUnitRemovalEnabled = v, on, body);

    private static readonly Type EngineType = typeof(DBMng).Assembly.GetType("RTM.Engine", throwOnError: true)!;

    /// <summary>An engine with only the fields these paths touch.</summary>
    private static object NewEngine(UnionList unions, IDInteractionsList interactions)
    {
        var engine = RuntimeHelpers.GetUninitializedObject(EngineType);
        EngineType.GetProperty("UnionList")!.SetValue(engine, unions);
        EngineType.GetField("_interactionsList", BindingFlags.NonPublic | BindingFlags.Instance)!.SetValue(engine, interactions);
        EngineType.GetField("_lastClearLocalDateByUnion", BindingFlags.NonPublic | BindingFlags.Instance)!
            .SetValue(engine, new ConcurrentDictionary<string, DateOnly>());
        return engine;
    }

    private static object Inv(object engine, string name, params object[] args) =>
        EngineType.GetMethod(name, BindingFlags.NonPublic | BindingFlags.Instance, null, args.Select(a => a.GetType()).ToArray(), null)!
            .Invoke(engine, args)!;

    private static int QueueBagCount(Union union)
    {
        var bag = typeof(Union).GetProperty("QueueInteractions", BindingFlags.NonPublic | BindingFlags.Instance)!.GetValue(union)!;
        var inner = bag.GetType().GetProperty("Bag")!.GetValue(bag)!;
        return ((System.Collections.ICollection)inner).Count;
    }

    // ---------- U2: origin day and the backdated test ----------

    [Fact]
    public void OriginLocalDate_InQueueThenAnsweredThenCreation()
    {
        var it = new IDInteraction("O1", 1, null, false) { TimeZone = "+03:00" };
        it.OriginLocalDate().Should().Be(it.toLocal(it.CreatedUtc).Date, "neither InQueue nor Answered fired: creation time");

        it.AnsweredDateTime = new DateTime(2026, 10, 14, 23, 50, 0);
        it.OriginLocalDate().Should().Be(new DateTime(2026, 10, 14));

        it.InQueueDateTime = new DateTime(2026, 10, 13, 22, 0, 0);
        it.OriginLocalDate().Should().Be(new DateTime(2026, 10, 13), "the queue entry wins over the answer");
    }

    [Fact]
    public void IsBackdated_OnlyWhenTheOriginDayIsBeforeTheLocalToday()
    {
        var nowUtc = new DateTime(2026, 10, 16, 0, 30, 0, DateTimeKind.Utc);   // 03:30 on the 16th at +03:00
        var it = new IDInteraction("B1", 1, null, false) { TimeZone = "+03:00" };

        it.InQueueDateTime = new DateTime(2026, 10, 15, 23, 40, 0);   // yesterday, local
        it.IsBackdated(nowUtc).Should().BeTrue();

        it.InQueueDateTime = new DateTime(2026, 10, 16, 0, 10, 0);    // today, local
        it.IsBackdated(nowUtc).Should().BeFalse();

        var utcZone = new IDInteraction("B2", 1, null, false) { TimeZone = "" };   // our rule: empty TimeZone = UTC
        utcZone.InQueueDateTime = new DateTime(2026, 10, 15, 23, 40, 0);
        utcZone.IsBackdated(nowUtc).Should().BeTrue();
        utcZone.InQueueDateTime = new DateTime(2026, 10, 16, 0, 10, 0);
        utcZone.IsBackdated(nowUtc).Should().BeFalse();
    }

    [Fact]
    public void RowDate_On_IsTheOriginDay_Off_IsTheWriteDay()
    {
        var it = new IDInteraction("R1", 1, null, false) { TimeZone = "" };
        it.InQueueDateTime = DateTime.UtcNow.Date.AddDays(-1).AddHours(23);

        Backdated(true, () => it.RowDate().Date.Should().Be(DateTime.UtcNow.Date.AddDays(-1), "the after-midnight write closes yesterday's row"));
        Backdated(false, () => it.RowDate().Date.Should().Be(it.getLocalDateTime().Date, "a literal false keeps today's write-day row"));
    }

    // ---------- U2: eviction from today's live counters ----------

    private static (object engine, Union union, IDInteractionsList list, IDInteraction it) OneQueuedInteraction(DateTime inQueueLocal)
    {
        var unions = new UnionList();
        var union = new Union(1, new ConcurrentDictionary<string, MetricDef>());
        union.Queues.Add("Q");
        unions.TryAdd(1, union);
        var list = new IDInteractionsList(unions);
        var it = new IDInteraction("E1", 1, StubDb(), false) { Workgroup = "Q", TimeZone = "" };
        it.InQueueDateTime = inQueueLocal;
        list.Add(it, false);
        union.addAllInteractions(new List<IDInteraction> { it }, new ApplicList(unions), false);
        QueueBagCount(union).Should().Be(1, "precondition: the interaction is counted today");
        return (NewEngine(unions, list), union, list, it);
    }

    [Fact]
    public void EvictBackdated_On_RemovesOnlyABackdatedInteraction()
    {
        Backdated(true, () =>
        {
            var nowUtc = DateTime.UtcNow;
            var (engine, union, list, it) = OneQueuedInteraction(nowUtc.Date.AddDays(-1).AddHours(23));
            Inv(engine, "evictBackdated", it, nowUtc);
            QueueBagCount(union).Should().Be(0, "a prior day's terminal leaves today's counters");
            list.getInteraction("E1", 1).Should().BeNull();

            var (engine2, union2, list2, it2) = OneQueuedInteraction(nowUtc);
            Inv(engine2, "evictBackdated", it2, nowUtc);
            QueueBagCount(union2).Should().Be(1, "a same-day terminal is untouched");
            list2.getInteraction("E1", 1).Should().NotBeNull();
        });
    }

    [Fact]
    public void EvictBackdated_Off_ChangesNothing()
    {
        Backdated(false, () =>
        {
            var nowUtc = DateTime.UtcNow;
            var (engine, union, list, it) = OneQueuedInteraction(nowUtc.Date.AddDays(-1).AddHours(23));
            Inv(engine, "evictBackdated", it, nowUtc);
            QueueBagCount(union).Should().Be(1, "a literal false keeps today's behaviour");
            list.getInteraction("E1", 1).Should().NotBeNull();
        });
    }

    // ---------- U3: live removal through /LoadData ----------

    private static Dictionary<string, string> Qc(int union, string queue, string cls) =>
        new() { ["UnionId"] = union.ToString(), ["QueueId"] = queue, ["ClassificationId"] = cls, ["timeZone"] = "+00:00", ["clearTime"] = "00:00:00" };

    private static Dictionary<string, string> Ug(int union, int sg, string group) =>
        new() { ["UnionId"] = union.ToString(), ["SupergroupId"] = sg.ToString(), ["UsergroupId"] = group, ["timeZone"] = "+00:00", ["clearTime"] = "00:00:00" };

    private static (object engine, UnionList unions, Union union) UnionWith(string[] queues, int sg, string[] groups)
    {
        var unions = new UnionList();
        var union = new Union(7, new ConcurrentDictionary<string, MetricDef>());
        var applics = new ApplicList(unions);
        foreach (var q in queues) { union.Queues.Add(q); union.addWorkgroup(q, applics); }
        union.UserGroups[sg] = groups.ToList();
        unions.TryAdd(7, union);
        return (NewEngine(unions, new IDInteractionsList(unions)), unions, union);
    }

    private static List<Union> Reconcile(object engine, List<Dictionary<string, string>> qc, List<Dictionary<string, string>> ug)
    {
        var newUnions = new List<Union>();
        Inv(engine, "reconcileRemovedMappings", qc, ug, newUnions);
        return newUnions;
    }

    [Fact]
    public void RemovedQueue_On_LeavesTheUnionAndTriggersTheRebuild_EvenTheLastOne()
    {
        LiveBu(true, () =>
        {
            var (engine, _, union) = UnionWith(new[] { "Q1", "Q2" }, 5, new[] { "G1" });
            var rebuilt = Reconcile(engine, new() { Qc(7, "Q1", "ALL") }, new() { Ug(7, 5, "G1") });
            union.Queues.Should().Equal("Q1");
            union.Applics.Keys.Select(k => k.QueueId).Should().BeEquivalentTo(new[] { "Q1" });
            rebuilt.Should().Contain(union, "the rebuild subtracts the removed queue's calls at once");

            var (engine2, _, union2) = UnionWith(new[] { "Q1" }, 5, new[] { "G1" });
            Reconcile(engine2, new(), new() { Ug(7, 5, "G1") });
            union2.Queues.Should().BeEmpty("the last queue of a union leaves too - today's defect");
            union2.Applics.Should().BeEmpty();
        });
    }

    [Fact]
    public void RemovedQueue_Off_NothingChanges()
    {
        LiveBu(false, () =>
        {
            var (engine, _, union) = UnionWith(new[] { "Q1" }, 5, new[] { "G1" });
            var rebuilt = Reconcile(engine, new(), new() { Ug(7, 5, "G1") });
            union.Queues.Should().Equal("Q1");
            union.Applics.Should().HaveCount(1);
            rebuilt.Should().BeEmpty();
        });
    }

    [Fact]
    public void RemovedSpecificApplicAndClassification_On_Leave_KeptRowsStay()
    {
        LiveBu(true, () =>
        {
            var (engine, _, union) = UnionWith(new[] { "Q1" }, 5, new[] { "G1" });
            var a1 = new QueueClassification("Q9", "C1");
            var a2 = new QueueClassification("Q9", "C2");
            union.Applics.TryAdd(a1, new Applic(a1));
            union.Applics.TryAdd(a2, new Applic(a2));
            union.Classifications.Add("C7");
            union.addWorkgroup("ALL", new ApplicList(new UnionList()));

            Reconcile(engine, new() { Qc(7, "Q1", "ALL"), Qc(7, "Q9", "C1") }, new() { Ug(7, 5, "G1") });

            union.Applics.Keys.Should().Contain(a1).And.NotContain(a2);
            union.Classifications.Should().BeEmpty();
            union.Applics.Keys.Should().NotContain(new QueueClassification("ALL", "ALL"), "no classification row backs it any more");
            union.Queues.Should().Equal("Q1");
        });
    }

    [Fact]
    public void RemovedAgentGroup_On_LeavesTheClause_AnEmptiedOrRemovedSupergroupIsDropped()
    {
        LiveBu(true, () =>
        {
            var (engine, _, union) = UnionWith(new[] { "Q1" }, 5, new[] { "G1", "G2" });
            union.UserGroups[6] = new List<string> { "G3" };
            union.UserGroups[8] = new List<string> { "G4" };

            Reconcile(engine, new() { Qc(7, "Q1", "ALL") }, new() { Ug(7, 5, "G1"), Ug(7, 8, "G9") });

            union.UserGroups[5].Should().Equal("G1");
            union.UserGroups.ContainsKey(6).Should().BeFalse("its supergroup has no rows");
            union.UserGroups.ContainsKey(8).Should().BeFalse("an emptied clause would admit every agent");
        });

        LiveBu(false, () =>
        {
            var (engine, _, union) = UnionWith(new[] { "Q1" }, 5, new[] { "G1", "G2" });
            Reconcile(engine, new() { Qc(7, "Q1", "ALL") }, new() { Ug(7, 5, "G1") });
            union.UserGroups[5].Should().Equal(new[] { "G1", "G2" }, "a literal false waits for a restart, as before");
        });
    }

    [Fact]
    public void DeletedBU_On_IsFrozen_CountersKept_RevivedWhenItsRowsReturn()
    {
        LiveBu(true, () =>
        {
            var (engine, unions, union) = UnionWith(new[] { "Q1" }, 5, new[] { "G1" });
            var it = new IDInteraction("F1", 1, StubDb(), false) { Workgroup = "Q1" };
            union.addQueueInteraction(it);
            QueueBagCount(union).Should().Be(1, "precondition");

            Reconcile(engine, new(), new());

            union.IsFrozen.Should().BeTrue();
            unions.ContainsKey(7).Should().BeTrue("frozen until its midnight clear, not removed");
            union.Queues.Should().BeEmpty();
            union.Applics.Should().BeEmpty();
            union.UserGroups.Should().BeEmpty();
            QueueBagCount(union).Should().Be(1, "the frozen counters stay on the board until midnight");

            Reconcile(engine, new() { Qc(7, "Q1", "ALL") }, new() { Ug(7, 5, "G1") });
            union.IsFrozen.Should().BeFalse("the same unionId back before midnight revives it");
        });

        LiveBu(false, () =>
        {
            var (engine, _, union) = UnionWith(new[] { "Q1" }, 5, new[] { "G1" });
            Reconcile(engine, new(), new());
            union.IsFrozen.Should().BeFalse();
            union.Queues.Should().Equal("Q1");
        });
    }

    [Fact]
    public void Reap_RemovesOnlyAFrozenUnion_AndItsSubscribers()
    {
        var (engine, unions, union) = UnionWith(new[] { "Q1" }, 5, new[] { "G1" });
        int fired = 0;
        union.UserUnionDeactivateEvent += (_, _) => fired++;

        ((bool)Inv(engine, "reapIfFrozen", union)).Should().BeFalse();
        unions.ContainsKey(7).Should().BeTrue("a live union is never reaped");

        union.IsFrozen = true;
        ((bool)Inv(engine, "reapIfFrozen", union)).Should().BeTrue();
        unions.ContainsKey(7).Should().BeFalse();

        union.UsersToRemove.Add(new UserManager("u", new UnionList(), StubDb(), new ConcurrentDictionary<string, MetricDef>()));
        union.DrainRemovedUsersIfEmpty();
        fired.Should().Be(0, "a reaped union has no subscribers left");
    }

    [Fact]
    public void Drain_FiresRemoveUserOnlyForAnEmptiedUnion_AndOnlyWhenOn()
    {
        UserManager Agent(string id) => new UserManager(id, new UnionList(), StubDb(), new ConcurrentDictionary<string, MetricDef>());

        LiveBu(true, () =>
        {
            var (engine, _, union) = UnionWith(new[] { "Q1" }, 5, new[] { "G1" });
            int fired = 0;
            union.UserUnionDeactivateEvent += (_, _) => fired++;
            union.UsersToRemove.Add(Agent("a"));
            ((int)Inv(engine, "drainEmptiedUnions")).Should().Be(1);
            fired.Should().Be(1, "nobody left in the union: getData would never send this removeUser");
            union.UsersToRemove.Should().BeEmpty();

            union.Users.Add(Agent("stays"));
            union.UsersToRemove.Add(Agent("b"));
            ((int)Inv(engine, "drainEmptiedUnions")).Should().Be(0, "a union with members drains in getData as before");
        });

        LiveBu(false, () =>
        {
            var (engine, _, union) = UnionWith(new[] { "Q1" }, 5, new[] { "G1" });
            union.UsersToRemove.Add(Agent("a"));
            ((int)Inv(engine, "drainEmptiedUnions")).Should().Be(0);
            union.UsersToRemove.Should().HaveCount(1, "a literal false changes nothing");
        });
    }

    [Fact]
    public void Reconcile_IsIdempotent()
    {
        LiveBu(true, () =>
        {
            var (engine, _, union) = UnionWith(new[] { "Q1", "Q2" }, 5, new[] { "G1" });
            var rows = new List<Dictionary<string, string>> { Qc(7, "Q1", "ALL") };
            var groups = new List<Dictionary<string, string>> { Ug(7, 5, "G1") };
            Reconcile(engine, rows, groups).Should().HaveCount(1);
            Reconcile(engine, rows, groups).Should().BeEmpty("unchanged DB rows change nothing the second time");
            union.Queues.Should().Equal("Q1");
            union.UserGroups[5].Should().Equal("G1");
        });
    }
}
