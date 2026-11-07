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

    [Fact]
    public void ADropOnAFreePlace_staysWhereItWasLetGo()
        => ReportCanvasLayout.PlaceFree(new CanvasRect(500, 40, 400, 300), new[] { new CanvasRect(0, 0, 400, 300) })
            .Should().Be(new CanvasRect(500, 40, 400, 300));

    [Fact]
    public void ADropOnATakenPlace_goesBelow_andCoversNothing()
    {
        var others = new[] { new CanvasRect(0, 0, 1600, 470), new CanvasRect(0, 480, 600, 200) };
        var placed = ReportCanvasLayout.PlaceFree(new CanvasRect(50, 50, 400, 300), others);

        ReportCanvasLayout.OverlapsAny(placed, others).Should().BeFalse();
        placed.X.Should().Be(50, "it stays in the column where it was dropped");
        placed.Y.Should().BeGreaterThan(50);
        // NEGATIVE: the place the old code used is caught as taken.
        ReportCanvasLayout.OverlapsAny(new CanvasRect(50, 50, 400, 300), others).Should().BeTrue();
    }

    // ---- the page uses it ---------------------------------------------------------------------------------------

    [Fact]
    public void TheEditor_dropsWhereTheMouseWasLetGo_andNeverOnAnotherWidget()
    {
        var drop = Regex.Match(Editor(), @"private async Task OnDropAtPosition\(DragEventArgs e\)[\s\S]*?\n    \}");
        drop.Success.Should().BeTrue("the drop handler must be readable here");
        drop.Value.Should().Contain("widgetResize.getDropPosition", "the drop point, as the dashboard editor takes it");
        drop.Value.Should().Contain("ReportCanvasLayout.PlaceFree");
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
        Regex.IsMatch(css, @"\.report-canvas \.dashboard-widget\s*\{[^}]*isolation:\s*isolate")
            .Should().BeTrue("each report widget must keep its own z-indexes inside itself");
        // NEGATIVE / reason: the thing being guarded against exists - a sticky table header with a z-index.
        Regex.IsMatch(css, @"table\.report-widget-table thead th\s*\{[^}]*position:\s*sticky[^}]*z-index")
            .Should().BeTrue("if the sticky header lost its z-index this guard would protect nothing - say so");
        // The two report canvases carry the class; the dashboards' general rule does not get isolation.
        Editor().Should().Contain("dashboard-canvas-grid report-canvas");
        File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports", "ReportViewPage.razor"))
            .Should().Contain("fullscreen-design-layer report-canvas");
        Regex.IsMatch(css, @"\n\.dashboard-canvas-grid \.dashboard-widget\s*\{[^}]*isolation")
            .Should().BeFalse("the dashboards' canvas is out of scope");
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
