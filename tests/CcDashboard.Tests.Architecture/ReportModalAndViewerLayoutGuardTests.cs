using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// FEAT-REPORT-FILTER-MODAL-01 and PR234-V4-REPORT-VIEW-LAYOUT-DIFFERS-FROM-EDITOR-01 (operator 2026-11-07).
/// The report viewer scales its board with transform: scale(...); position: fixed inside a transformed ancestor is fixed
/// to that ancestor. Measured on 234: the step window drawn inside a widget darkened only the board, the date bar stayed
/// bright and clickable; the filter window inside a widget was clipped or slid under the sticky header. So every modal
/// window of the report screens is drawn by ONE host in the page, outside the scaled layer.
/// And the viewer lays the board out as the editor does (top to top, same edge) - centring added a 197px empty band.
/// </summary>
public class ReportModalAndViewerLayoutGuardTests
{
    [Fact]
    public void NoReportWidget_drawsAModalOrAFilterWindowItself()
    {
        var files = Directory.GetFiles(ReportWidgetsDirectory(), "*ReportWidget.razor");
        files.Length.Should().BeGreaterThan(1, "the widgets must be findable");
        foreach (var f in files)
            DrawsAWindowItself(File.ReadAllText(f)).Should().BeFalse($"{Path.GetFileName(f)} must hand its windows to ReportModalHost");

        // NEGATIVE HALF: the step window as it was - drawn inline in the widget - is caught.
        DrawsAWindowItself("""<div class="modal show d-block" tabindex="-1"><div class="modal-dialog"></div></div>""").Should().BeTrue();
        DrawsAWindowItself("<ColumnFilterPopup ColumnLabel=\"x\" />").Should().BeTrue();
    }

    private static bool DrawsAWindowItself(string markup)
        => markup.Contains("modal show d-block") || markup.Contains("<ColumnFilterPopup");

    [Fact]
    public void TheHost_standsInBothPages_outsideTheScaledLayer()
    {
        var view = Page("ReportViewPage.razor");
        HostOutsideLayer(view).Should().BeTrue("the viewer's host must stand outside fullscreen-design-layer");
        Page("ReportEditorPage.razor").Should().Contain("<ReportModalHost");

        // NEGATIVE HALF: a host placed inside the layer is caught.
        const string inside = """
            <div class="fullscreen-design-layer report-widget-layer">
                <div class="dashboard-widget"></div>
                <ReportModalHost />
            </div>
            """;
        HostOutsideLayer(inside).Should().BeFalse();
    }

    /// <summary>True when ReportModalHost appears after the element that opens the design layer has closed.</summary>
    private static bool HostOutsideLayer(string page)
    {
        var start = page.IndexOf("class=\"fullscreen-design-layer", StringComparison.Ordinal);
        var host = page.IndexOf("<ReportModalHost", StringComparison.Ordinal);
        if (start < 0 || host < 0) return false;
        start = page.LastIndexOf("<div", start, StringComparison.Ordinal);
        var depth = 0;
        var tags = new Regex(@"<div\b|</div>");
        foreach (Match m in tags.Matches(page, start))
        {
            depth += m.Value == "</div>" ? -1 : 1;
            if (depth == 0) return host > m.Index;
        }
        return false;
    }

    [Fact]
    public void TheFilterWindow_isTitledWithTheColumnsName_fromTheOneLabelRule()
    {
        var header = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "ColumnFilterHeader.razor"));
        Regex.IsMatch(header, @"Modal\.ShowAsync\(this,\s*Group,\s*ColumnLabel,").Should().BeTrue("the window's title is the column's name");

        foreach (var f in Directory.GetFiles(ReportWidgetsDirectory(), "*ReportWidget.razor")
                     .Where(f => File.ReadAllText(f).Contains("<ColumnFilterHeader")))
        {
            var w = File.ReadAllText(f);
            w.Should().Contain("ColumnLabel=\"@ColumnLabel(column.Name)\"", $"{Path.GetFileName(f)} passes the column's label");
            Regex.IsMatch(w, @"private string ColumnLabel\(string column\)[\s\S]{0,200}ReportColumnLabels\.KeyFor")
                .Should().BeTrue($"{Path.GetFileName(f)}: the label comes from ReportColumnLabels, not a list of its own");
        }
    }

    [Fact]
    public void TheInWidgetWindowRules_areGone()
    {
        var css = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "wwwroot", "app.css"));
        UnclipsWidgets(css).Should().BeFalse("no filter window lives inside a widget any more - one device, not two");
        // NEGATIVE HALF: the rule that was there is caught.
        UnclipsWidgets(".widget-content:has(.column-filter-popup) { overflow: visible; }").Should().BeTrue();
    }

    private static bool UnclipsWidgets(string css) => css.Contains(":has(.column-filter-popup)");

    [Fact]
    public void TheReportViewer_laysTheBoardOutAsTheEditor_andTheDashboardsKeepTheirs()
    {
        AsEditor(Page("ReportViewPage.razor")).Should().BeTrue("the report viewer must ask for the editor's layout");

        var js = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "wwwroot", "js", "widget-resize.js"));
        Regex.IsMatch(js, @"this\.align === 'editor'\)\s*\{[\s\S]{0,700}marginTop = '0px'").Should().BeTrue(
            "with align 'editor' there is no band above the board");
        Regex.IsMatch(js, @"this\.align = \(options && options\.align\) \|\| 'centre'").Should().BeTrue(
            "without the option the layout is the old one - the dashboards' viewer is out of scope");

        var dashboards = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "Dashboard", "ScreenFullscreenPage.razor"));
        AsEditor(dashboards).Should().BeFalse("the dashboards keep the centred board");

        // NEGATIVE HALF: the call as it was is caught.
        AsEditor("""await JS.InvokeVoidAsync("viewerScale.init", _designLayerRef, _designWidth, _designHeight);""").Should().BeFalse();
    }

    private static bool AsEditor(string page)
        => Regex.IsMatch(page, @"viewerScale\.init""[^;]*align\s*=\s*""editor""");

    private static string Page(string name) => File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports", name));

    private static string ReportWidgetsDirectory()
        => Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "ReportWidgets");

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;
        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
