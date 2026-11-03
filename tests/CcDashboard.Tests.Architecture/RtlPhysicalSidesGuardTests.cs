using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// FEAT-HE-DROPDOWNS-01: an arrow drawn on a physical side must have an RTL counterpart.
///
/// The defect the operator photographed ("כל הסטטוסים", "כל הקטגוריות", "כל הארגונים"): the select
/// reserved its space with padding-inline-end, which is LOGICAL and moves to the left under RTL,
/// while the arrow was placed with background-position: right, which is PHYSICAL and stayed put -
/// on top of the text. Bootstrap's own RTL build gets this right; our app.css loads after it and
/// was overriding it back, so the Hebrew UI lost the fix that was already there.
///
/// This guard reads the stylesheet. It does not ban physical sides - plenty of them are deliberate
/// (a chequerboard swatch, a shimmer keyframe). It bans exactly the combination that bit us: a
/// select whose arrow is pinned to a physical side with no [dir="rtl"] rule to move it.
/// </summary>
public class RtlPhysicalSidesGuardTests
{
    // Anchored at the start of a line, so a base rule (".form-select {") is told apart from an
    // RTL one ("[dir=\"rtl\"] .form-select {") by position rather than by a variable-width
    // look-behind. .NET would accept the look-behind, but then the same expression could not be
    // replayed in a scratch script to check this guard before asking for a run - and a guard I
    // cannot rehearse is a guard I cannot trust.
    private static readonly Regex SelectWithPhysicalArrow = new(
        @"^(?<sel>\.form-select(?:-sm)?)\s*\{[^}]*background-position:\s*(?<side>right|left)[^}]*\}",
        RegexOptions.Compiled | RegexOptions.Multiline);

    private static readonly Regex RtlOverride = new(
        @"^\[dir=""rtl""\]\s+(?<sel>\.form-select(?:-sm)?)\s*\{[^}]*background-position:\s*(?<side>right|left)[^}]*\}",
        RegexOptions.Compiled | RegexOptions.Multiline);

    [Fact]
    public void EverySelectArrowPinnedToASide_hasAnRtlCounterpart()
    {
        var css = AppCss();

        var pinned = SelectWithPhysicalArrow.Matches(css)
            .Select(m => m.Groups["sel"].Value)
            .Distinct()
            .ToList();
        var overridden = RtlOverride.Matches(css)
            .Select(m => m.Groups["sel"].Value)
            .Distinct()
            .ToList();

        pinned.Should().NotBeEmpty("the selects must still be styled here, or this guard watches nothing");
        pinned.Except(overridden).Should().BeEmpty(
            "a select whose arrow is pinned to a physical side needs an [dir=\"rtl\"] rule, or the arrow lands on the text in Hebrew");
    }

    [Fact]
    public void TheRtlRuleMovesTheArrowToTheOtherSide_notTheSame()
    {
        // An override that repeats the same side would satisfy the first test and fix nothing.
        var css = AppCss();

        foreach (var m in RtlOverride.Matches(css).Cast<Match>())
        {
            var sel = m.Groups["sel"].Value;
            var rtlSide = m.Groups["side"].Value;

            var ltr = SelectWithPhysicalArrow.Matches(css).Cast<Match>()
                .FirstOrDefault(x => x.Groups["sel"].Value == sel);
            ltr.Should().NotBeNull($"{sel} must have a base rule to be flipped from");
            rtlSide.Should().NotBe(ltr!.Groups["side"].Value,
                $"{sel}: the RTL rule must put the arrow on the opposite side");
        }
    }

    [Fact]
    public void LeftToRightIsLeftAlone()
    {
        // NEGATIVE HALF #1: the fix must not touch en-US. The base rules keep the arrow on the
        // right, and the override is scoped to [dir="rtl"] only - a bare .form-select rule with
        // the arrow on the left would break every Latin screen instead.
        var css = AppCss();

        Regex.IsMatch(css, @"\n\.form-select\s*\{[^}]*background-position:\s*right").Should().BeTrue(
            "the default direction must still place the arrow on the right");
        Regex.Matches(css, @"\n\.form-select(?:-sm)?\s*\{[^}]*background-position:\s*left").Count
            .Should().Be(0, "no unscoped rule may move the arrow left");
    }

    [Fact]
    public void ResizeHandlesAreLogical_soTheGestureMustTranslateTheirNames()
    {
        // FEAT-RTL-RESIZE-01, the same defect in the editor: the handles are placed with logical
        // properties, so under RTL the one named "e" is physically on the left, while the drag
        // maths is physical (deltaX added to width for "e", style.left moved for "w"). Dragging
        // the left edge shrank the widget instead of growing it.
        var css = AppCss();
        var js = ResizeScript();

        // The handles are logical - that is deliberate and matches the viewer's own RTL fix.
        Regex.IsMatch(css, @"\.resize-handle\.resize-e\s*\{[^}]*inset-inline-end").Should().BeTrue(
            "if the handles ever become physical, the translation below turns from a fix into a bug");

        // So the gesture must translate the name into the side actually occupied, once, at the start.
        js.Should().Contain("physicalHandle", "the handle name must be resolved against the direction");
        Regex.IsMatch(js, @"startResize:[\s\S]{0,400}this\.physicalHandle\(handle, widget\)").Should().BeTrue(
            "the translation belongs at the start of the gesture, before anything is measured");

        // NEGATIVE HALF: a translation that fires in LTR too would break every Latin board.
        Regex.IsMatch(js, @"physicalHandle:[\s\S]{0,500}dir !== 'rtl'\s*\)\s*return handle;").Should().BeTrue(
            "under LTR the handle name must be returned untouched");

        // And it must flip only the inline axis: n/s carry no direction.
        Regex.IsMatch(js, @"replace\(/\[ew\]/g").Should().BeTrue(
            "only e/w may be swapped - flipping n/s would break vertical resizing in Hebrew");
    }

    [Fact]
    public void Guard_canGoRed_onThePreFixStylesheet()
    {
        // NEGATIVE HALF #2: the needles must report the stylesheet as it stood before this unit.
        const string beforeTheFix = """
            .form-select {
            padding-inline-end: 2rem;
            background-repeat: no-repeat;
            background-position: right 0.5rem center;
            }
            """;
        var pinned = SelectWithPhysicalArrow.Matches(beforeTheFix).Select(m => m.Groups["sel"].Value).ToList();
        var overridden = RtlOverride.Matches(beforeTheFix).Select(m => m.Groups["sel"].Value).ToList();

        pinned.Should().Contain(".form-select", "the detector must recognise the shape at all");
        overridden.Should().BeEmpty();
        pinned.Except(overridden).Should().NotBeEmpty(
            "so the first test would have reported it - that is the red this guard can produce");
    }

    private static string ResizeScript()
    {
        var path = Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "wwwroot", "js", "widget-resize.js");
        File.Exists(path).Should().BeTrue("widget-resize.js must exist");
        return File.ReadAllText(path);
    }

    private static string AppCss()
    {
        var path = Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "wwwroot", "app.css");
        File.Exists(path).Should().BeTrue("app.css must exist");
        return File.ReadAllText(path);
    }

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;

        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
