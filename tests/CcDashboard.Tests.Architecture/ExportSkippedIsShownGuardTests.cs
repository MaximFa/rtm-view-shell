using System.Reflection;
using System.Text.RegularExpressions;
using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// A widget left out of an exported file must be visible on the page.
///
/// What went wrong: ExportReportCommandHandler skips a widget whose query is refused, logs it and
/// moves on, so a person downloaded a file with sheets missing and nothing said so. Measured
/// 2026-11-04: both end-of-shift widgets were refused on every export, because the shift hours
/// never reached the query. That is the fifth instance of the same defect - a step that fails
/// quietly - and the cure must not create a sixth one on the screen.
///
/// So the two rules held here are about SILENCE, not about wording:
///   1. the page shows a line for an unrecognised reason code as well, naming the widget without
///      inventing a reason, and logs the code that arrived;
///   2. every key the reason map can return exists in all three locales - a key missing from one
///      locale renders blank, which is silence again, in one language only.
/// </summary>
public class ExportSkippedIsShownGuardTests
{
    [Fact]
    public void ThePage_showsAnUnrecognisedCodeInsteadOfHidingIt()
    {
        var page = File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports", "ReportViewPage.razor"));

        page.Should().Contain("ExportSkipReason.KeyFor",
            "the page must ask the map, not compare reason strings of its own");
        page.Should().Contain("ExportSkipReason.ItemWithoutReasonKey",
            "an unknown code must still produce a line - the widget named, no reason invented");
        page.Should().Contain("LogWarning",
            "and the code that arrived must reach the log, or nobody learns a new code exists");

        // NEGATIVE HALF: the shape that would hide the skip. A branch that drops the item when the
        // map returns null is exactly the sixth instance of this defect, so it is named as a
        // pattern rather than trusted not to appear.
        Regex.IsMatch(page, @"KeyFor\([^)]*\)\s*is\s+null\s*\)\s*\{?\s*(continue|return)\b")
            .Should().BeFalse("a null key means \"name it without a reason\", never \"skip the line\"");
    }

    [Fact]
    public void EveryKeyTheReasonMapCanReturn_existsInAllThreeLocales_andTheCheckCanStillGoRed()
    {
        var codes = ReasonCodes();
        codes.Should().NotBeEmpty("the reason codes must be readable, or this guard checks nothing");

        var keys = codes.Select(ExportSkipReason.KeyFor).Where(k => k is not null).Select(k => k!).ToList();
        keys.Should().HaveCount(codes.Count, "every declared code needs a key of its own");
        keys.Add(ExportSkipReason.ItemKey);
        keys.Add(ExportSkipReason.ItemWithoutReasonKey);
        keys.Add("Reports_ExportSkipped");

        foreach (var locale in Locales)
        {
            var resx = Resx(locale);
            foreach (var key in keys)
                resx.Should().Contain($"name=\"{key}\"", $"{key} is missing from {locale} and would render blank");

            // NEGATIVE HALF: the same predicate on a key nobody added must fail. Without this the
            // loop above could be passing because "Contain" always succeeds on this file.
            resx.Should().NotContain("name=\"Reports_ExportSkipped__NoSuchKeyForTheGuard__\"",
                "the presence check must be capable of coming back negative");
        }
    }

    /// <summary>
    /// The reason codes as the map declares them - read from the type, not listed here, so a fifth
    /// code added tomorrow is covered without touching this file.
    /// </summary>
    private static IReadOnlyList<string> ReasonCodes()
        => typeof(ExportSkipReason)
            .GetFields(BindingFlags.Public | BindingFlags.Static)
            .Where(f => f.IsLiteral && f.FieldType == typeof(string) && !f.Name.EndsWith("Key", StringComparison.Ordinal))
            .Select(f => (string)f.GetRawConstantValue()!)
            .ToList();

    private static readonly string[] Locales = { "en-US", "ru-RU", "he-IL" };

    private static string Resx(string locale)
        => File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Resources", $"SharedResources.{locale}.resx"));

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;

        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
