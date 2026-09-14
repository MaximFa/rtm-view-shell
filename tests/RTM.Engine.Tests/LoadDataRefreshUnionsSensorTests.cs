using System.Text.RegularExpressions;
using FluentAssertions;

namespace RTM.Engine.Tests;

/// <summary>
/// PR234-ENGINE-NOTESTS-01 — the architecture SENSOR for the fix in 35989b6.
///
/// WHY A SENSOR AND NOT A TEST OF BEHAVIOUR. Engine.LoadData reads from the database on its first
/// lines, so the loop at its end cannot be executed in a unit test without a seam in production
/// code — and the engine runs in production, so the seam was deliberately not cut. The sibling file
/// UnionMembershipRaceTests pins the CONTRACT the fix relies on, but it calls refreshUnions()
/// itself: delete the call from LoadData and those four tests stay green. This file closes exactly
/// that one failure mode — the call disappearing SILENTLY.
///
/// WHAT IT DOES NOT DO, stated here so a green run is not read as more than it is:
///   - it sees the PRESENCE of the call, not that it runs in the right place of the loop;
///   - it sees no ORDER: membership-before-metrics is not checked here;
///   - it is a SENSOR, not a gate. Red means "the line was touched, go and look", not "you broke
///     production". Promoting it to a mandatory gate would make it the process overgrowth it was
///     created to catch.
/// </summary>
public class LoadDataRefreshUnionsSensorTests
{
    private const string CallUnderWatch = "userMng.refreshUnions();";
    private const string AbsentOnPurpose = "userMng.thisCallMustNotExist();";

    /// <summary>
    /// The sensor itself: the call added by 35989b6 is still in Engine.LoadData.
    /// </summary>
    [Fact]
    public void LoadData_StillCallsRefreshUnions_ForEveryUserManager()
    {
        var source = ReadEngineSource();

        source.Should().Contain(CallUnderWatch,
            "35989b6 added this call to the loop at the end of LoadData; without it a mapping row " +
            "that lands after an agent's activation never reaches him, and no behaviour test in " +
            "this project would notice its removal");
    }

    /// <summary>
    /// NEGATIVE HALF — proves the sensor can say no. A predicate that cannot fail is not a check:
    /// without this, a broken file path or an empty read would make the test above green forever.
    /// </summary>
    [Fact]
    public void Sensor_CanFail_OnACallThatIsNotThere()
    {
        var source = ReadEngineSource();

        source.Should().NotContain(AbsentOnPurpose,
            "if this string were found, the sensor is matching something other than the real source");
    }

    /// <summary>
    /// POSITIVE CONTROL of the harness — the file was actually located and read. Otherwise
    /// "call not found" would be indistinguishable from "file not found", which is the same class
    /// of defect the colony has paid for repeatedly: a silent instrument reporting on nothing.
    /// </summary>
    [Fact]
    public void Harness_ActuallyReadsEngineSource()
    {
        var path = LocateEngineSource();
        var source = ReadEngineSource();

        File.Exists(path).Should().BeTrue($"Engine.cs must be locatable from the test run; looked at {path}");
        source.Length.Should().BeGreaterThan(50_000, "Engine.cs is a large file; a tiny read means the wrong file");
        source.Should().Contain("public void LoadData(", "the located file must be the one that defines LoadData");
    }

    /// <summary>
    /// The call must sit inside the loop over every UserManager, not merely somewhere in the file —
    /// this is as close to "place" as a source-level sensor can honestly get. It still says nothing
    /// about execution order at runtime.
    /// </summary>
    [Fact]
    public void RefreshUnionsCall_SitsInsideTheUserManagerLoop()
    {
        var source = ReadEngineSource();

        var loop = Regex.Match(
            source,
            @"foreach\s*\(\s*var\s+userMng\s+in\s+_userManagerList\.Values\s*\)\s*\{(?<body>[^}]*)\}",
            RegexOptions.Singleline);

        loop.Success.Should().BeTrue("the loop over _userManagerList.Values must still exist in LoadData");
        loop.Groups["body"].Value.Should().Contain("refreshUnions()",
            "the call belongs inside that loop — outside it, it would run for nobody or for one manager");
    }

    private static string ReadEngineSource() => File.ReadAllText(LocateEngineSource());

    private static string LocateEngineSource()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "CcDashboard.sln")))
            dir = dir.Parent;

        if (dir is null)
            throw new InvalidOperationException(
                "repository root (the directory holding CcDashboard.sln) not found from " + AppContext.BaseDirectory);

        return Path.Combine(dir.FullName, "RTM", "RTM", "Engine.cs");
    }
}
