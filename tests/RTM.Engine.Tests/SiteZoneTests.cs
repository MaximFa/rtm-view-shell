using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text.RegularExpressions;
using FluentAssertions;
using RTM;
using RTM.Configuration;

namespace RTM.Engine.Tests;

/// <summary>
/// PR234-SITE-TZ-FIXED-OFFSET-01. Measured on 234 (sitetz-1015): site IL = fixed "+02:00", every union cleared at 22:00Z
/// (01:00 Israeli summer time) on 12-20.10. Each test has its negative half: the fixed "+02:00" (or the old reader) gives the
/// measured wrong answer, the zone id gives the right one.
/// </summary>
[Collection("AppConfigSwitches")]
public class SiteZoneTests
{
    private static string Israel()
    {
        foreach (var id in new[] { "Israel Standard Time", "Asia/Jerusalem" })
        {
            try { TimeZoneInfo.FindSystemTimeZoneById(id); return id; } catch (TimeZoneNotFoundException) { }
        }
        throw new InvalidOperationException("neither Windows nor IANA id for Israel is available on this machine");
    }

    private static DateTime Utc(int y, int mo, int d, int h, int mi = 0) => new(y, mo, d, h, mi, 0, DateTimeKind.Utc);

    [Fact]
    public void Reader_AcceptsOffsetsAndZoneIds_RejectsGarbage()
    {
        SiteZone.TryOffset("+02:00", Utc(2026, 7, 15, 12), out var a).Should().BeTrue(); a.Should().Be(TimeSpan.FromHours(2));
        SiteZone.TryOffset("-05:00", Utc(2026, 7, 15, 12), out var b).Should().BeTrue(); b.Should().Be(TimeSpan.FromHours(-5));
        SiteZone.TryOffset("03:00", Utc(2026, 7, 15, 12), out var c).Should().BeTrue(); c.Should().Be(TimeSpan.FromHours(3));
        SiteZone.TryOffset(Israel(), Utc(2026, 7, 15, 12), out var s).Should().BeTrue(); s.Should().Be(TimeSpan.FromHours(3), "summer");
        SiteZone.TryOffset(Israel(), Utc(2026, 1, 15, 12), out var w).Should().BeTrue(); w.Should().Be(TimeSpan.FromHours(2), "winter");

        SiteZone.TryOffset("", Utc(2026, 7, 15, 12), out _).Should().BeFalse();
        SiteZone.TryOffset("Mars/Olympus", Utc(2026, 7, 15, 12), out _).Should().BeFalse();
        SiteZone.TryOffset("3", Utc(2026, 7, 15, 12), out _).Should().BeFalse("'3' parses as 3 DAYS - not an offset");
        SiteZone.Offset("Mars/Olympus", Utc(2026, 7, 15, 12)).Should().Be(TimeSpan.Zero, "toLocal keeps 'unknown => UTC'");
    }

    [Fact]
    public void Clear_Summer_AtLocalMidnight_NotAt0100()
    {
        SiteZone.TryClearUtc(Israel(), new DateOnly(2026, 7, 15), TimeSpan.Zero, out var withId).Should().BeTrue();
        withId.Should().Be(Utc(2026, 7, 14, 21), "00:00 IDT = 21:00Z");

        SiteZone.TryClearUtc("+02:00", new DateOnly(2026, 7, 15), TimeSpan.Zero, out var fixedTwo).Should().BeTrue();
        fixedTwo.Should().Be(Utc(2026, 7, 14, 22), "negative half: the fixed +02:00 clears at 22:00Z = 01:00 IDT, as measured on 234");
    }

    [Fact]
    public void Clear_Winter_BothForms_AgreeAt2200Z()
    {
        SiteZone.TryClearUtc(Israel(), new DateOnly(2026, 1, 15), TimeSpan.Zero, out var withId).Should().BeTrue();
        SiteZone.TryClearUtc("+02:00", new DateOnly(2026, 1, 15), TimeSpan.Zero, out var fixedTwo).Should().BeTrue();
        withId.Should().Be(Utc(2026, 1, 14, 22));
        fixedTwo.Should().Be(withId, "in winter Israel IS +02:00 - the defect lives only in summer");
    }

    [Fact]
    public void Clear_SpringForwardNight_ANonExistingClearTime_MovesForward()
    {
        var zone = TimeZoneInfo.FindSystemTimeZoneById(Israel());
        var day = Enumerable.Range(0, 31).Select(i => new DateOnly(2027, 3, 1).AddDays(i))
            .First(d => zone.IsInvalidTime(d.ToDateTime(new TimeOnly(2, 30))));
        SiteZone.TryClearUtc(Israel(), day, new TimeSpan(2, 30, 0), out var clearUtc).Should().BeTrue();

        var expected = TimeZoneInfo.ConvertTimeToUtc(day.ToDateTime(new TimeOnly(3, 0)), zone);
        clearUtc.Should().Be(expected, "02:30 does not exist that night; the clear moves to the first valid half hour, 03:00");
        Action naive = () => TimeZoneInfo.ConvertTimeToUtc(day.ToDateTime(new TimeOnly(2, 30)), zone);
        naive.Should().Throw<ArgumentException>("negative half: converting the invalid wall time directly fails");
    }

    [Fact]
    public void Clear_FallBackNight_ATwiceOccurringClearTime_IsTakenOnce_AtItsFirstOccurrence()
    {
        var zone = TimeZoneInfo.FindSystemTimeZoneById(Israel());
        var day = Enumerable.Range(0, 31).Select(i => new DateOnly(2026, 10, 1).AddDays(i))
            .First(d => zone.IsAmbiguousTime(d.ToDateTime(new TimeOnly(1, 30))));
        SiteZone.TryClearUtc(Israel(), day, new TimeSpan(1, 30, 0), out var clearUtc).Should().BeTrue();

        var wall = day.ToDateTime(new TimeOnly(1, 30));
        clearUtc.Should().Be(DateTime.SpecifyKind(wall.AddHours(-3), DateTimeKind.Utc), "first occurrence is still summer time (+03:00)");
        TimeZoneInfo.ConvertTimeToUtc(wall, zone).Should().Be(wall.AddHours(-2), "negative half: the default conversion picks the SECOND occurrence");
    }

    [Fact]
    public void ClearDue_OncePerLocalDay_AndNotAt0100()
    {
        var z = Israel();
        SiteZone.IsClearDue(z, TimeSpan.Zero, Utc(2026, 7, 14, 21, 2), null, TimeSpan.FromMinutes(5), out var today).Should().BeTrue();
        today.Should().Be(new DateOnly(2026, 7, 15));
        SiteZone.IsClearDue(z, TimeSpan.Zero, Utc(2026, 7, 14, 21, 3), today, TimeSpan.FromMinutes(5), out _).Should().BeFalse("already cleared today");
        SiteZone.IsClearDue(z, TimeSpan.Zero, Utc(2026, 7, 14, 21, 10), null, TimeSpan.FromMinutes(5), out _).Should().BeFalse("outside the 5-minute window");

        SiteZone.IsClearDue("+02:00", TimeSpan.Zero, Utc(2026, 7, 14, 21, 2), null, TimeSpan.FromMinutes(5), out _).Should().BeFalse(
            "negative half: with the fixed +02:00 it is only 23:02 site time - the clear waits until 22:00Z");
    }

    [Fact]
    public void NextClear_BeforeAndAfterTheOctoberChange()
    {
        var z = Israel();
        SiteZone.TryNextClearUtc(z, TimeSpan.Zero, Utc(2026, 10, 22, 12), out var summer).Should().BeTrue();
        summer.Should().Be(Utc(2026, 10, 22, 21), "23.10 00:00 IDT");
        SiteZone.TryNextClearUtc(z, TimeSpan.Zero, Utc(2026, 11, 2, 12), out var winter).Should().BeTrue();
        winter.Should().Be(Utc(2026, 11, 2, 22), "03.11 00:00 IST");
        SiteZone.TryNextClearUtc("+02:00", TimeSpan.Zero, Utc(2026, 10, 22, 12), out var fixedTwo).Should().BeTrue();
        fixedTwo.Should().Be(Utc(2026, 10, 22, 22), "negative half: 01:00 IDT");
    }

    private static IDInteraction Interaction(string zone)
    {
        var db = (DBMng)RuntimeHelpers.GetUninitializedObject(typeof(DBMng));
        var queueField = typeof(DBMng).GetField("_requestsQueue", BindingFlags.NonPublic | BindingFlags.Instance)!;
        queueField.SetValue(db, Activator.CreateInstance(queueField.FieldType));
        return new IDInteraction("i-1", 1, db, false) { TimeZone = zone };
    }

    [Fact]
    public void RowDay_U2Mode_IsTheLocalDayOfQueueing_InBothSeasons()
    {
        var saved = AppConfig.BackdatedTerminalEnabled;
        try
        {
            AppConfig.BackdatedTerminalEnabled = true;
            var utc = Utc(2026, 7, 14, 21, 30); // 00:30 IDT on 15.07

            var withId = Interaction(Israel());
            withId.InQueueDateTime = withId.toLocal(utc);
            withId.RowDate().Should().Be(new DateTime(2026, 7, 15));

            var fixedTwo = Interaction("+02:00");
            fixedTwo.InQueueDateTime = fixedTwo.toLocal(utc);
            fixedTwo.RowDate().Should().Be(new DateTime(2026, 7, 14), "negative half: the fixed +02:00 files a 00:30 IDT call under yesterday (20.10 on 234)");
        }
        finally { AppConfig.BackdatedTerminalEnabled = saved; }
    }

    [Fact]
    public void RowDay_LastWriteMode_UsesTheSameReader()
    {
        // Mode without U2 (the engine on 234 before 17.10): the row day is the local day of the LAST write = toLocal(now).Date.
        var saved = AppConfig.BackdatedTerminalEnabled;
        try
        {
            AppConfig.BackdatedTerminalEnabled = false;
            var it = Interaction(Israel());
            it.RowDate().Date.Should().Be(it.toLocal(DateTime.UtcNow).Date);

            var utc = Utc(2026, 7, 14, 21, 30);
            Interaction(Israel()).toLocal(utc).Date.Should().Be(new DateTime(2026, 7, 15));
            Interaction("+02:00").toLocal(utc).Date.Should().Be(new DateTime(2026, 7, 14), "negative half");
        }
        finally { AppConfig.BackdatedTerminalEnabled = saved; }
    }

    [Fact]
    public void Engine_HasOneZoneReader()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "CcDashboard.sln"))) dir = dir.Parent;
        dir.Should().NotBeNull();
        string Code(string file) => Regex.Replace(Regex.Replace(File.ReadAllText(Path.Combine(dir!.FullName, "RTM", "RTM", file)),
            @"/\*.*?\*/", "", RegexOptions.Singleline), @"//[^\n]*", "");

        var engine = Code("Engine.cs");
        engine.Should().NotContain("TryParseOffset(", "the hh:mm-only reader made a zone id an INVALID_OFFSET (no clear)");
        engine.Should().Contain("SiteZone.IsClearDue(").And.Contain("SiteZone.TryNextClearUtc(");
        Code("IDInteraction.cs").Should().Contain("SiteZone.Offset(").And.NotContain("FindSystemTimeZoneById");
        Code("UserManager.cs").Should().Contain("SiteZone.Offset(").And.NotContain("FindSystemTimeZoneById");
        Code("DbTime.cs").Should().Contain("SiteZone.Offset(").And.NotContain("FindSystemTimeZoneById");
    }
}
