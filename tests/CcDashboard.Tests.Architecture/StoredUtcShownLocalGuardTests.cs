using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// BL-V4-INFOSLOT-TIME-NO-LOCAL-01: a stored UTC stamp must not be printed raw.
///
/// InfoSlotWidget printed CreatedAt and ExpiresAt with a bare ToString("HH:mm") while the same
/// values were printed through ToLocalTime() in InfoSlotMessages - so one message showed two
/// different times, three hours apart on 234 in summer. The columns are "timestamp with time zone"
/// and the shell stamps them from clock.UtcNow, so the raw print was simply UTC on screen.
///
/// The guard watches the SHAPE in source: any print of a *CreatedAt / *ExpiresAt / *UpdatedAt /
/// *DeletedAt / *LastLoginAt value must go through ToLocalTime(), WallClock, or the display-zone
/// helper. It deliberately does NOT demand a conversion everywhere a time is printed: values that
/// arrive already local (DateTime.Now, or an interval start converted in Application) must stay
/// untouched, and converting those is the opposite defect.
/// </summary>
public class StoredUtcShownLocalGuardTests
{
    // Properties that, in this codebase, always hold a stored UTC instant.
    private static readonly Regex StoredStampPrinted = new(
        @"\b\w*(CreatedAt|ExpiresAt|UpdatedAt|DeletedAt|LastLoginAt)\b[\w.?()\[\]]*\.ToString\(",
        RegexOptions.Compiled);

    private static readonly Regex Converted = new(
        @"ToLocalTime\(\)|WallClock\.|Zone\.ToDisplay|ToDisplay\(", RegexOptions.Compiled);

    [Fact]
    public void NoStoredUtcStampIsPrintedWithoutConversion()
    {
        var offenders = new List<string>();

        foreach (var path in SourceFiles())
        {
            var lines = File.ReadAllLines(path);
            for (var i = 0; i < lines.Length; i++)
            {
                if (!StoredStampPrinted.IsMatch(lines[i])) continue;
                if (Converted.IsMatch(lines[i])) continue;
                offenders.Add($"{Path.GetFileName(path)}:{i + 1}");
            }
        }

        offenders.Should().BeEmpty(
            "a stored UTC stamp printed raw shows UTC on screen while the rest of the shell shows local time");
    }

    [Fact]
    public void TheSearchAreaIsNotEmpty_andTheGuardCanGoRed()
    {
        // NEGATIVE HALF. "Found nothing" is worth nothing without the area, and a needle that
        // matches nothing is green on everything.
        var files = SourceFiles();
        files.Should().NotBeEmpty("the Web project's sources must actually be found");
        files.Count.Should().BeGreaterThan(20, "the area must be the whole project, not one folder");

        // The exact pre-fix line from InfoSlotWidget.razor:37 must be caught...
        const string beforeTheFix = """@if (ShowTimestamp) { <span class="is-time">@msg.CreatedAt.ToString("HH:mm")</span> }""";
        StoredStampPrinted.IsMatch(beforeTheFix).Should().BeTrue("this is the shape the guard exists for");
        Converted.IsMatch(beforeTheFix).Should().BeFalse("and it carries no conversion, so it would be reported");

        // ...while the fixed line and a legitimately-local print must NOT be reported.
        const string afterTheFix = """@if (ShowTimestamp) { <span class="is-time">@WallClock.HourMinute(msg.CreatedAt)</span> }""";
        (StoredStampPrinted.IsMatch(afterTheFix) && !Converted.IsMatch(afterTheFix)).Should().BeFalse();

        const string alreadyLocal = """@L["Widget_LastUpdated"]: @_lastUpdate.ToString("HH:mm:ss")""";
        StoredStampPrinted.IsMatch(alreadyLocal).Should().BeFalse(
            "DateTime.Now values must not be dragged into this guard - converting them is the opposite defect");
    }

    private static IReadOnlyList<string> SourceFiles()
    {
        var web = WebDirectory();
        return Directory.GetFiles(web, "*.razor", SearchOption.AllDirectories)
            .Concat(Directory.GetFiles(web, "*.cs", SearchOption.AllDirectories))
            .Where(p => !p.Contains(Path.DirectorySeparatorChar + "obj" + Path.DirectorySeparatorChar)
                     && !p.Contains(Path.DirectorySeparatorChar + "bin" + Path.DirectorySeparatorChar))
            .ToList();
    }

    private static string WebDirectory()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;

        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return Path.Combine(dir!.FullName, "src", "CcDashboard.Web");
    }
}
