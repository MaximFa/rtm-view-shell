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

    // PR234-V4-REPORT-EDITOR-NEW-WIDGET-POSITION-01 (operator 2026-11-08 10:50 / 11:02). The layout measured on 234
    // (ba72973, report "test"): canvas 1785 wide; "queues" (0,0) 920x390; "agents" (0,400) 2080x530. The drops are the
    // four measured ones; the old rule put three of them at y=940, below the visible edge (878).
    private static readonly CanvasRect[] Board234 = { new(0, 0, 920, 390), new(0, 400, 2080, 530) };
    private const int Width234 = 1785;

    private static CanvasRect Drop(int x, int y, IReadOnlyCollection<CanvasRect>? others = null)
        => ReportCanvasLayout.NearestFree(ReportCanvasLayout.AnchoredAt(x, y, 400, 300), others ?? Board234, Width234);

    [Fact]
    public void ADropOnAFreePlace_staysWhereItWasLetGo()
        => Drop(1300, 100).Should().Be(new CanvasRect(1300, 100, 400, 300), "measured drop 1: the free place right of the queues");

    [Fact]
    public void ADropNextToAWidget_goesToTheNearestFreePlace_notBelowEverything()
    {
        var placed = Drop(1000, 300);   // measured drop 2: the old rule gave (1000, 940)
        ReportCanvasLayout.OverlapsAny(placed, Board234).Should().BeFalse();
        placed.Should().Be(new CanvasRect(1000, 100, 400, 300), "200 px up is free (its bottom touches the agents report)");

        // NEGATIVE HALF: the measured outcome of the old rule is far from the drop - this case would be red on it.
        Distance(new CanvasRect(1000, 940, 400, 300), new CanvasRect(1000, 300, 400, 300))
            .Should().BeGreaterThan(Distance(placed, new CanvasRect(1000, 300, 400, 300)));
    }

    [Fact]
    public void ADropOnTopOfAWidget_staysNearTheMouse_andCoversNothing()
    {
        var placed = Drop(300, 200);   // measured drop 3, on top of the queues report; the old rule gave (300, 940)
        ReportCanvasLayout.OverlapsAny(placed, Board234).Should().BeFalse();
        placed.Bottom.Should().BeLessThanOrEqualTo(878, "it must be on the visible part of the canvas measured on 234");
        placed.Should().Be(new CanvasRect(920, 100, 400, 300), "the nearest free place: touching the queues report on the right");
    }

    [Fact]
    public void ADropNextToANewWidget_andAtTheRightEdge_staysInsideTheCanvas()
    {
        var withFirst = Board234.Append(new CanvasRect(1300, 100, 400, 300)).ToList();
        var placed = Drop(1500, 20, withFirst);   // measured drop 4; the old rule gave (1500, 940), right edge 1900
        ReportCanvasLayout.OverlapsAny(placed, withFirst).Should().BeFalse();
        placed.Right.Should().BeLessThanOrEqualTo(Width234, "never past the canvas' right edge");
        // Here no free place exists above the agents report (worked out by hand: right of the first new widget is past
        // the edge, left of it is the queues report) - the nearest is below it, and the page scrolls it into view.
        placed.Should().Be(new CanvasRect(1380, 930, 400, 300));

        // NEGATIVE HALF: a drop at the very right edge is pulled in, not left hanging out.
        Drop(1700, 0).Right.Should().BeLessThanOrEqualTo(Width234);
    }

    private static double Distance(CanvasRect a, CanvasRect b) => Math.Sqrt(Math.Pow(a.X - b.X, 2) + Math.Pow(a.Y - b.Y, 2));

    // ---- the page uses it ---------------------------------------------------------------------------------------

    [Fact]
    public void TheEditor_dropsWhereTheMouseWasLetGo_andNeverOnAnotherWidget()
    {
        var drop = Regex.Match(Editor(), @"private async Task OnDropAtPosition\(DragEventArgs e\)[\s\S]*?\n    \}");
        drop.Success.Should().BeTrue("the drop handler must be readable here");
        drop.Value.Should().Contain("widgetResize.getDropPosition", "the drop point, as the dashboard editor takes it");
        drop.Value.Should().Contain("ReportCanvasLayout.NearestFree").And.Contain("ReportCanvasLayout.AnchoredAt")
            .And.Contain("drop.Width", "the canvas width bounds the search");
        drop.Value.Should().Contain("widgetResize.scrollWidgetIntoView", "a new widget is brought into view");
        drop.Value.Should().NotContain("PlaceFree", "the rule that threw widgets below everything is gone");
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
