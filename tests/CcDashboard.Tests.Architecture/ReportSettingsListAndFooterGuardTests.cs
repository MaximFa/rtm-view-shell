using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// Two findings of the operator on 234 after f7006b5 (2026-11-07):
/// PR234-V4-REPORT-SETTINGS-MODAL-CRAMPED-01 - the list of the report widget settings window showed one row of 40:
/// absolute, it did not count in the window body and was clipped by the body's own scroll (scrollHeight 516 against
/// clientHeight 310). PR234-V4-REPORT-TABLE-FOOTER-TALL-01 - the table footer was 70px: the rows caption wrapped under
/// the number box, 8px padding; and the footer markup lived in seven copies.
/// </summary>
public class ReportSettingsListAndFooterGuardTests
{
    [Fact]
    public void TheSettingsWindowList_standsInTheFlow_andScrollsOnItsOwn()
    {
        InFlowWithOwnScroll(Css()).Should().BeTrue("inside .report-config-modal the list must be position: static with a max-height in vh");

        // NEGATIVE HALF: the global absolute list alone (the 26.06 state) is caught; a fixed pixel cap is caught too.
        InFlowWithOwnScroll(".searchable-dropdown {\n    position: absolute;\n    max-height: 240px;\n}\n").Should().BeFalse();
        InFlowWithOwnScroll(".report-config-modal .searchable-dropdown {\n    position: static;\n    max-height: 240px;\n}\n").Should().BeFalse();
        InFlowWithOwnScroll(".report-config-modal .searchable-dropdown {\n    position: static;\n    max-height: min(50vh, 420px);\n}\n").Should().BeTrue();
    }

    private static bool InFlowWithOwnScroll(string css)
    {
        var rule = Regex.Match(css, @"\.report-config-modal \.searchable-dropdown\s*\{([^}]*)\}");
        return rule.Success
            && Regex.IsMatch(rule.Groups[1].Value, @"position:\s*static")
            && Regex.IsMatch(rule.Groups[1].Value, @"max-height:[^;]*vh");
    }

    [Fact]
    public void TheTableFooter_isDrawnInOnePlace_andEveryTableWidgetUsesIt()
    {
        var files = Directory.GetFiles(ComponentsDirectory(), "*.razor", SearchOption.AllDirectories)
            .ToDictionary(f => Path.GetFileName(f), File.ReadAllText);
        Drawers(files).Should().Equal(new[] { "ReportTableFooter.razor" }, "the footer markup must live in one file");

        var tables = files.Where(f => f.Key.EndsWith("ReportWidget.razor") && f.Value.Contains("<ReportRowTable")).ToList();
        tables.Count.Should().BeGreaterThanOrEqualTo(7, "the seven table widgets must be findable");
        foreach (var t in tables)
            t.Value.Should().Contain("<ReportTableFooter", $"{t.Key} must draw the common footer");

        // NEGATIVE HALF: a copy left in one widget is caught.
        var withCopy = new Dictionary<string, string>(files) { ["AgentMonthlyReportWidget.razor"] = "<div class=\"report-widget-footer\">" };
        Drawers(withCopy).Should().HaveCount(2);
    }

    private static List<string> Drawers(Dictionary<string, string> files)
        => files.Where(f => f.Value.Contains("class=\"report-widget-footer\"")).Select(f => f.Key).OrderBy(x => x).ToList();

    [Fact]
    public void TheTableFooter_isOneLine_withMinimalPadding()
    {
        OneLine(Css()).Should().BeTrue("vertical padding of the footer at most 4px, the rows block inline-flex");

        // NEGATIVE HALF: the f7006b5 rules are caught.
        OneLine(".report-widget-footer {\n    padding: 0.5rem 0.75rem;\n}\n.report-widget-footer-pagesize {\n    display: inline-flex;\n}\n").Should().BeFalse();
        OneLine(".report-widget-footer {\n    padding: 2px 8px;\n}\n").Should().BeFalse("without the inline-flex the caption wraps under the box again");
    }

    private static bool OneLine(string css)
    {
        var footer = Regex.Match(css, @"\n\.report-widget-footer\s*\{([^}]*)\}");
        var size = Regex.Match(css, @"\n\.report-widget-footer-pagesize\s*\{([^}]*)\}");
        if (!footer.Success || !size.Success) return false;
        var pad = Regex.Match(footer.Groups[1].Value, @"padding:\s*(\d+)px\b");
        return pad.Success && int.Parse(pad.Groups[1].Value) <= 4
            && Regex.IsMatch(size.Groups[1].Value, @"display:\s*inline-flex");
    }

    private static string Css() => "\n" + File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "wwwroot", "app.css"));

    private static string ComponentsDirectory() => Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components");

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;
        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
