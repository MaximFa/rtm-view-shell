using System.Text.RegularExpressions;
using CcDashboard.Web.Components.ReportWidgets;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// The report editor canvas (operator 2026-11-07 16:20):
/// PR234-V4-REPORT-EDITOR-NEW-WIDGET-POSITION-01 - a new widget went to a fixed (50, 50), not where the mouse was let go;
/// PR234-V4-REPORT-EDITOR-WIDGET-OVERLAP-STUCK-01 - it landed on another widget, under that widget's sticky table header,
/// and could not be grabbed. Held here: the drop point is used, widgets never overlap, each report widget is its own
/// stacking layer. The dashboards' canvas is out of scope (coordinator 2026-11-07T15:05:51Z).
/// </summary>
public class ReportCanvasEditorGuardTests
{
    // ---- the rule ----------------------------------------------------------------------------------------------

    [Fact]
    public void Overlap_isSharedArea_touchingEdgesIsNot()
    {
        var a = new CanvasRect(0, 0, 100, 100);
        a.Overlaps(new CanvasRect(50, 50, 100, 100)).Should().BeTrue();
        a.Overlaps(new CanvasRect(10, 10, 10, 10)).Should().BeTrue("inside is overlap");
        // NEGATIVE: neighbours that only touch are allowed - a rule that refused them would make tiling impossible.
        a.Overlaps(new CanvasRect(100, 0, 100, 100)).Should().BeFalse();
        a.Overlaps(new CanvasRect(0, 100, 100, 100)).Should().BeFalse();
    }

    // PR234-V4-REPORT-EDITOR-NEW-WIDGET-POSITION-01. Operator 2026-11-08 11:57: "put the widget exactly where the mouse is,
    // even if it goes over another widget". Two rules in turn moved the widget away from the mouse - "below everything"
    // (f7006b5, three drops of four at y=940 on 234) and "nearest free place" (9c0be65: on the operator's next layout the
    // nearest free 400x300 was again below the agents report). The question now: does the widget land at the mouse?

    [Fact]
    public void ANewWidget_isAnchoredByItsTopLeftCorner_atTheMouse()
    {
        ReportCanvasLayout.AnchoredAt(1000, 300, 400, 300).Should().Be(new CanvasRect(1000, 300, 400, 300));

        // NEGATIVE HALF: the measured drop 3 lands ON the queues report - and that is now allowed, not corrected.
        var onTop = ReportCanvasLayout.AnchoredAt(300, 200, 400, 300);
        ReportCanvasLayout.OverlapsAny(onTop, new[] { new CanvasRect(0, 0, 920, 390) }).Should().BeTrue(
            "the case exists: a drop over a widget - and the page must still put it at the mouse (next case)");
    }

    // ---- the page uses it ---------------------------------------------------------------------------------------

    [Fact]
    public void TheEditor_dropsExactlyWhereTheMouseWasLetGo_evenOnAnotherWidget()
    {
        var drop = Regex.Match(Editor(), @"private async Task OnDropAtPosition\(DragEventArgs e\)[\s\S]*?\n    \}");
        drop.Success.Should().BeTrue("the drop handler must be readable here");
        drop.Value.Should().Contain("widgetResize.getDropPosition", "the drop point, as the dashboard editor takes it");
        drop.Value.Should().Contain("ReportCanvasLayout.AnchoredAt(drop.X, drop.Y", "the widget's corner is the drop point itself");
        SearchesForAPlace(drop.Value).Should().BeEmpty("operator 11:57: exactly at the mouse, even over another widget");

        // NEGATIVE HALF: both rules that moved it away are caught.
        SearchesForAPlace("var rect = ReportCanvasLayout.PlaceFree(new CanvasRect(drop.X, drop.Y, 400, 300), others);").Should().NotBeEmpty();
        SearchesForAPlace("var rect = ReportCanvasLayout.NearestFree(anchored, others, drop.Width);").Should().NotBeEmpty();
        // NEGATIVE: the fixed corner of the old code.
        Regex.IsMatch(drop.Value, @"x\s*=\s*50\s*,\s*y\s*=\s*50").Should().BeFalse();
    }

    [Fact]
    public void MovingOrResizingOntoAnotherWidget_isRefused_andSaid()
    {
        var editor = Editor();
        foreach (var cb in new[] { "OnWidgetMoved", "OnWidgetResized", "OnWidgetsMoved" })
        {
            var body = Regex.Match(editor, $@"public async Task {cb}\([\s\S]*?\n    \}}");
            body.Success.Should().BeTrue($"{cb} must be readable here");
            body.Value.Should().Contain("RefuseOverlapAsync", $"{cb} must check the result for overlap");
        }
        editor.Should().Contain("Report_CanvasNoOverlap", "a widget that jumps back must say why");
    }

    [Fact]
    public void EveryReportWidget_isItsOwnLayer_onTheReportCanvasOnly()
    {
        var css = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "wwwroot", "app.css"));
        Regex.IsMatch(css, @"\.report-widget-layer \.dashboard-widget\s*\{[^}]*isolation:\s*isolate")
            .Should().BeTrue("each report widget must keep its own z-indexes inside itself");
        // NEGATIVE / reason: the thing being guarded against exists - a sticky table header with a z-index.
        Regex.IsMatch(css, @"table\.report-widget-table thead th\s*\{[^}]*position:\s*sticky[^}]*z-index")
            .Should().BeTrue("if the sticky header lost its z-index this guard would protect nothing - say so");
        // The two report canvases carry the class; the dashboards' general rule does not get isolation.
        Editor().Should().Contain("dashboard-canvas-grid report-widget-layer");
        File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports", "ReportViewPage.razor"))
            .Should().Contain("fullscreen-design-layer report-widget-layer");
        Regex.IsMatch(css, @"\n\.dashboard-canvas-grid \.dashboard-widget\s*\{[^}]*isolation")
            .Should().BeFalse("the dashboards' canvas is out of scope");
    }

    /// <summary>
    /// PR234-V4-REPORT-WIDGET-FRAME-01 (operator 2026-11-07 18:44): a frame round the whole board in the viewer and the
    /// editor. Cause measured on 234: the hook class report-canvas, put on both boards in f7006b5, revived a rule dead
    /// since 25.06 (border, padding, background). Question: does any class that the report pages ADD to a board (every
    /// class after the board's own first one) give the board a look - border, padding, margin, background, shadow?
    /// </summary>
    [Fact]
    public void TheClassesAddedToAReportBoard_giveItNoLookOfTheirOwn()
    {
        var css = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "wwwroot", "app.css"));
        var view = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports", "ReportViewPage.razor"));
        var added = AddedClasses(Editor(), "dashboard-canvas-grid").Concat(AddedClasses(view, "fullscreen-design-layer")).ToList();
        added.Should().Contain("report-widget-layer", "both boards must still carry the hook the layer rules hang on");
        foreach (var c in added)
            StylesTheElement(css, c).Should().BeEmpty($"the class {c} on a report board must not draw anything on it");

        // NEGATIVE HALF: the f7006b5 state - hook report-canvas with the dead rule alive - is caught;
        // a class carrying only the layer rules for the widgets inside it is not.
        const string dead = ".report-canvas {\n    border: 1px solid var(--clr-border);\n    padding: var(--sp-4);\n}\n";
        StylesTheElement(dead, "report-canvas").Should().ContainSingle();
        StylesTheElement(".report-widget-layer .dashboard-widget {\n    isolation: isolate;\n}\n", "report-widget-layer").Should().BeEmpty();
        AddedClasses("<div class=\"dashboard-canvas-grid report-canvas\"", "dashboard-canvas-grid").Should().Equal("report-canvas");
    }

    private static IEnumerable<string> AddedClasses(string page, string baseClass)
    {
        var m = Regex.Match(page, "class=\"" + Regex.Escape(baseClass) + "([^\"]*)\"");
        m.Success.Should().BeTrue($"the board with class {baseClass} must be findable");
        return m.Groups[1].Value.Split(' ', StringSplitOptions.RemoveEmptyEntries).Where(c => !c.Contains('@'));
    }

    /// <summary>Rules whose selector targets the element carrying the class itself (not a descendant) and draw on it.</summary>
    private static List<string> StylesTheElement(string css, string cls)
    {
        var hits = new List<string>();
        foreach (Match rule in Regex.Matches(css, @"([^{}]+)\{([^{}]*)\}"))
        {
            var selectors = rule.Groups[1].Value.Split(',').Select(x => Regex.Replace(x, @"/\*[\s\S]*?\*/", "").Trim());
            var onIt = selectors.Any(x => Regex.IsMatch(x, @"\." + Regex.Escape(cls) + @"(:[\w-]+)*$"));
            if (onIt && Regex.IsMatch(rule.Groups[2].Value, @"(^|[\s;])(border|padding|margin|background|box-shadow)[\w-]*\s*:"))
                hits.Add(rule.Groups[1].Value.Trim());
        }
        return hits;
    }

    private static List<string> SearchesForAPlace(string text)
        => Regex.Matches(text, @"PlaceFree|NearestFree|OverlapsAny").Select(m => m.Value).ToList();

    private static string Editor() => File.ReadAllText(Path.Combine(
        RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports", "ReportEditorPage.razor"));

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;
        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
