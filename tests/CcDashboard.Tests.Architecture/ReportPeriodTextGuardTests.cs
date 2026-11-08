using System.Text.RegularExpressions;
using CcDashboard.Web.Components.ReportWidgets;
using FluentAssertions;
using Microsoft.Extensions.Localization;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// PR234-V4-REPORT-SHOWN-FOR-DATE-FORMAT-01: the "data for ..." line of every report widget is written by ONE rule,
/// dd/MM/yyyy (operator 2026-11-07 22:32). Before: Queue Report and Agent Report wrote the page culture's short date
/// ("1.11.2026") next to Queue Trend's "01/11/2026" on the same report.
/// </summary>
public class ReportPeriodTextGuardTests
{
    private static readonly string WidgetsDir = Path.Combine("src", "CcDashboard.Web", "Components", "ReportWidgets");

    [Fact]
    public void ThePeriodLine_isDdMmYyyy_andOneDateForOneDay()
    {
        var l = new Echo();
        ReportPeriodText.ShownFor(l, new DateTime(2026, 11, 1), new DateTime(2026, 11, 8)).Should().Be("range 01/11/2026|08/11/2026");
        ReportPeriodText.ShownFor(l, new DateTime(2026, 11, 8), new DateTime(2026, 11, 8, 23, 0, 0)).Should().Be("date 08/11/2026");

        // NEGATIVE HALF: the old way (the page culture's short date) gives another string, which the check above would catch.
        new DateTime(2026, 11, 1).ToString("d", new System.Globalization.CultureInfo("ru-RU")).Should().Be("01.11.2026").And.NotBe("01/11/2026");
    }

    [Fact]
    public void EveryReportWidget_writesItsPeriodLineByTheOneRule()
    {
        // Area of the search: every .razor and .cs file under src/CcDashboard.Web/Components/ReportWidgets.
        var files = Directory.GetFiles(Path.Combine(RepoRoot(), WidgetsDir), "*.*", SearchOption.AllDirectories)
            .Where(f => f.EndsWith(".razor") || f.EndsWith(".cs")).ToList();
        files.Should().NotBeEmpty("an empty search proves nothing");
        files.SelectMany(f => CultureDates(File.ReadAllText(f)).Select(m => Path.GetFileName(f) + ": " + m))
            .Should().BeEmpty("a date in the page culture's own format breaks the one rule");

        foreach (var name in new[] { "EndOfShiftQueuesReportWidget.razor", "EndOfShiftAgentsReportWidget.razor", "QueueTrendReportWidget.razor" })
            File.ReadAllText(Path.Combine(RepoRoot(), WidgetsDir, name)).Should().Contain("ReportPeriodText.ShownFor(L, From, To)", name);

        // NEGATIVE HALF: the line deployed in 12faa24 is caught.
        CultureDates("var from = From.Date.ToString(\"d\");").Should().HaveCount(1);
    }

    private static List<string> CultureDates(string text)
        => Regex.Matches(text, @"\.ToString\(""[dgG]""\)|ToShortDateString\(|ToLongDateString\(").Select(m => m.Value).ToList();

    /// <summary>Returns the key's kind and its arguments, so the test reads the dates, not a translation.</summary>
    private sealed class Echo : IStringLocalizer
    {
        public LocalizedString this[string name] => new(name, name == "Report_ShownForDate" ? "date {0}" : "range {0}|{1}");
        public LocalizedString this[string name, params object[] arguments] => new(name, string.Format(this[name].Value, arguments));
        public IEnumerable<LocalizedString> GetAllStrings(bool includeParentCultures) => Array.Empty<LocalizedString>();
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
