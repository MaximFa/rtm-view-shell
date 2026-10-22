using System.Data.SqlTypes;
using System.Reflection;
using System.Runtime.CompilerServices;
using FluentAssertions;
using RTM;
using RTM.Tools;

namespace RTM.Engine.Tests;

/// <summary>
/// BL-234-INTERACTION-TIME-AHEAD-01. Measured on 234 (timeahead-1018): interaction times stored +2h ahead (site zone
/// +02:00 stamped as UTC), status-log times +3h (machine zone stamped as UTC). Every test has its negative half:
/// the OLD boundary expression (DateTime.SpecifyKind(local, Utc)) or the old reload (no conversion) goes red on the
/// same input, the new DbTime boundary goes green.
/// </summary>
public class TimeAheadTests
{
    private static readonly DateTime TrueUtc = new(2026, 10, 18, 17, 27, 4, DateTimeKind.Utc);

    private static IDInteraction Interaction(string zone)
    {
        // Same stub as LegacyPortD3Tests: a DBMng with only its request queue, no connection.
        var db = (DBMng)RuntimeHelpers.GetUninitializedObject(typeof(DBMng));
        var queueField = typeof(DBMng).GetField("_requestsQueue", BindingFlags.NonPublic | BindingFlags.Instance)!;
        queueField.SetValue(db, Activator.CreateInstance(queueField.FieldType));
        return new IDInteraction("i-1", 1, db, false) { TimeZone = zone };
    }

    private static string DstZoneId()
    {
        foreach (var id in new[] { "Israel Standard Time", "Asia/Jerusalem" })
        {
            try { TimeZoneInfo.FindSystemTimeZoneById(id); return id; } catch (TimeZoneNotFoundException) { }
        }
        throw new InvalidOperationException("neither Windows nor IANA id for Israel is available on this machine");
    }

    [Theory]
    [InlineData("+02:00", 2)]
    [InlineData("-05:00", -5)]
    [InlineData("03:00", 3)]
    public void EngineStamp_FixedOffset_IsWrittenAsTrueUtc_NotAsLocalLabelledUtc(string zone, int hours)
    {
        var local = Interaction(zone).toLocal(TrueUtc); // exactly what the engine stamps into InQueueDateTime / UpdateTime

        // negative half: the old DB boundary stored the local value labelled as UTC -> ahead by the zone offset
        (DateTime.SpecifyKind(local, DateTimeKind.Utc) - TrueUtc).Should().Be(TimeSpan.FromHours(hours));

        var written = DbTime.EngineLocalToUtc(local, zone);
        written.Should().Be(TrueUtc);
        written.Kind.Should().Be(DateTimeKind.Utc);
    }

    [Fact]
    public void EngineStamp_EmptyZone_WasAlreadyRight_AndStaysRight()
    {
        // Positive control: rows with an empty zone (5 804 on 234) were never shifted; the fix must not shift them either.
        var local = Interaction("").toLocal(TrueUtc);
        local.Should().Be(TrueUtc);
        DbTime.EngineLocalToUtc(local, "").Should().Be(TrueUtc);
        DbTime.UtcToEngineLocal(TrueUtc, "").Should().Be(TrueUtc);
    }

    [Fact]
    public void EngineStamp_DstZone_RoundTripsExactly_InSummerAndWinter()
    {
        var zone = DstZoneId();
        foreach (var utc in new[] { TrueUtc, new DateTime(2026, 1, 15, 9, 0, 0, DateTimeKind.Utc) })
        {
            var local = Interaction(zone).toLocal(utc);
            (DateTime.SpecifyKind(local, DateTimeKind.Utc) - utc).Should().BeGreaterThan(TimeSpan.Zero, "negative half: old boundary is ahead");
            DbTime.EngineLocalToUtc(local, zone).Should().Be(utc);
            DbTime.UtcToEngineLocal(DbTime.EngineLocalToUtc(local, zone), zone).Should().Be(local);
        }
    }

    [Fact]
    public void Sentinels_PassThroughUntouched_BothWays()
    {
        var max = (DateTime)SqlDateTime.MaxValue;
        var min = (DateTime)SqlDateTime.MinValue;
        DbTime.EngineLocalToUtc(max, "+02:00").Should().Be(max);
        DbTime.EngineLocalToUtc(min, "+02:00").Should().Be(min);
        DbTime.UtcToEngineLocal(new DateTime(9999, 12, 31, 23, 59, 59), "+02:00").Year.Should().Be(9999, "lossy text round trip of MaxValue stays a sentinel");
        DbTime.UtcToEngineLocal(min, "+02:00").Should().Be(min);
    }

    [Fact]
    public void Restart_TodayStaysToday_ForAnInteractionJustAfterLocalMidnight()
    {
        const string zone = "+02:00";
        var nowUtc = new DateTime(2026, 10, 17, 23, 0, 0, DateTimeKind.Utc);           // 01:00 local on the 18th
        var inQueueUtc = new DateTime(2026, 10, 17, 22, 30, 0, DateTimeKind.Utc);      // 00:30 local on the 18th
        var stamped = Interaction(zone).toLocal(inQueueUtc);
        stamped.Date.Should().Be(new DateTime(2026, 10, 18), "the engine's own day for this interaction");

        // write -> DB (true UTC) -> function returns ("InQueueDateTime" AT TIME ZONE 'UTC') -> engine parses its text
        var stored = DbTime.EngineLocalToUtc(stamped, zone);
        var readBack = DBAdapter.getDateTimeValue(DateTime.SpecifyKind(stored, DateTimeKind.Unspecified).ToString());

        // negative half: reloading the UTC value WITHOUT converting makes today's interaction "yesterday's"
        var oldReload = Interaction(zone);
        oldReload.InQueueDateTime = readBack;
        oldReload.IsBackdated(nowUtc).Should().BeTrue("without the reload conversion the interaction falls into the 17th");

        var newReload = Interaction(zone);
        newReload.InQueueDateTime = DbTime.UtcToEngineLocal(readBack, zone);
        newReload.InQueueDateTime.Should().Be(stamped);
        newReload.IsBackdated(nowUtc).Should().BeFalse("after a restart today stays today");
    }

    [Fact]
    public void ExternalTimes_AreConvertedByKind()
    {
        var utc = TrueUtc;
        DbTime.ExternalToUtc(utc).Should().Be(utc);

        var local = utc.ToLocalTime(); // what DateTime.Now / an offset-carrying adapter string deserializes to
        DbTime.ExternalToUtc(local).Should().Be(utc);
        DbTime.ExternalToUtc(DateTime.SpecifyKind(local, DateTimeKind.Unspecified)).Should().Be(utc, "Unspecified is taken as machine local");

        // negative half (meaningful only on a machine that is not on UTC, e.g. 234: +03:00 in summer)
        var machineOffset = TimeZoneInfo.Local.GetUtcOffset(utc);
        (DateTime.SpecifyKind(local, DateTimeKind.Utc) - utc).Should().Be(machineOffset, "the old boundary stored machine-local time labelled as UTC");
    }

    [Fact]
    public void ZoneChangedBetweenStampAndWrite_TheStoredInstantIsStillTrue()
    {
        // metrics-1014 (coordinator-1019 12:28:40Z): the row's TimeZone is overwritten whenever the interaction is added to
        // a bag - queue bag = site zone, agent bag = RTM:DefaultTimeZone (absent on 234 -> empty). Stamped in the queue
        // under +02:00, written after the agent bag set the zone to "".
        var it = Interaction("+02:00");
        var before = DateTime.UtcNow;
        it.InQueue();
        var after = DateTime.UtcNow;
        it.TimeZone = "";

        var written = DbTime.ToDbUtc(it.InQueueUtc ?? it.InQueueDateTime, it.TimeZone);
        written.Kind.Should().Be(DateTimeKind.Utc);
        written.Should().BeOnOrAfter(before).And.BeOnOrBefore(after);

        // negative half: converting the LOCAL stamp with the zone in force at write time is off by the site offset
        var viaRowZone = DbTime.EngineLocalToUtc(it.InQueueDateTime, it.TimeZone);
        (viaRowZone - written).Should().BeCloseTo(TimeSpan.FromHours(2), TimeSpan.FromSeconds(1));
    }

    [Fact]
    public void RowsWithEmptyOrIsraelZone_AreStoredAsTrueUtc()
    {
        // '' rows: stamps were already UTC (toLocal with an empty zone = UTC) and stay exact.
        var empty = Interaction("");
        var t0 = DateTime.UtcNow; empty.InQueue(); var t1 = DateTime.UtcNow;
        DbTime.ToDbUtc(empty.InQueueUtc ?? empty.InQueueDateTime, "").Should().BeOnOrAfter(t0).And.BeOnOrBefore(t1);

        // 'Israel'-like rows (DST zone id): exact as well, in summer +3 and winter +2 alike (instant captured at stamping).
        var dst = Interaction(DstZoneId());
        var u0 = DateTime.UtcNow; dst.InQueue(); var u1 = DateTime.UtcNow;
        var w = DbTime.ToDbUtc(dst.InQueueUtc ?? dst.InQueueDateTime, dst.TimeZone);
        w.Should().BeOnOrAfter(u0).And.BeOnOrBefore(u1);
        (DateTime.SpecifyKind(dst.InQueueDateTime, DateTimeKind.Utc) - w).Should().BeGreaterThan(TimeSpan.Zero, "negative half: the old boundary stored it ahead");
    }

    [Fact]
    public void DbBoundary_UsesDbTime_AndNoLongerLabelsLocalTimesAsUtc()
    {
        // Structural guard over the write path (DBMng.runSP needs a live connection; this pins WHICH conversion it uses).
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "CcDashboard.sln"))) dir = dir.Parent;
        dir.Should().NotBeNull("repository root (CcDashboard.sln) must be above the test output");
        var src = File.ReadAllText(Path.Combine(dir!.FullName, "RTM", "RTM", "DBMng.cs"));
        int a = src.IndexOf("private async Task runSP", StringComparison.Ordinal);
        int b = src.IndexOf("public DataTable getUsersStatuses", StringComparison.Ordinal);
        a.Should().BeGreaterThan(0); b.Should().BeGreaterThan(a);
        var body = src[a..b];

        body.Split("DateTime.SpecifyKind(").Length.Should().Be(1, "the old boundary stamped every time with SpecifyKind(Utc) - 8 places");
        body.Split("DbTime.ToDbUtc(").Length.Should().Be(1 + 2, "interaction InQueue/Answered: the UTC instant captured at stamping");
        body.Split("DbTime.EngineLocalToUtc(").Length.Should().Be(1 + 2, "interaction Update + status Update: stamped and written in one call, same zone");
        body.Split("DbTime.ExternalToUtc(").Length.Should().Be(1 + 4, "status Start/End + chat Update/TimeStamp");
    }
}
