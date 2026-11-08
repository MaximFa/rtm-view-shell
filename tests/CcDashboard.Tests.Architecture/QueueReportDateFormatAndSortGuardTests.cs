using System.Text.RegularExpressions;
using CcDashboard.Web.Components.ReportWidgets;
using CcDashboard.Web.Components.Shared;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// FEAT-REPORT-QUEUE-DATE-FORMAT-01 and FEAT-REPORT-QUEUE-COLUMN-SORT-01 (operator 2026-11-07 22:29 / 22:32), Queue Report
/// only: "agents - not now". The common places (ReportCellFormat, ReportRowTable, ColumnFilterPopup) are split by an
/// opt-in that only Queue Report takes; these cases ask both halves - Queue Report changed, the agents' reports not.
/// </summary>
public class QueueReportDateFormatAndSortGuardTests
{
    // ---- the filter window's date -------------------------------------------------------------------

    [Fact]
    public void WithTheQueueFormat_theFilterReadsDayMonthYear_exactly()
    {
        const string format = "dd'/'MM'/'yyyy";
        ColumnFilterDates.Parse("03/11/2026", format).Should().Be(new DateTime(2026, 11, 3));
        ColumnFilterDates.Show(new DateTime(2026, 11, 3), format).Should().Be("03/11/2026");

        // NEGATIVE HALF: other shapes are refused, not guessed - the US order, ISO, dots, a two-digit year.
        foreach (var bad in new[] { "11/03/2026x", "2026-11-03", "03.11.2026", "3/11/26", "31/02/2026" })
            ColumnFilterDates.Parse(bad, format).Should().BeNull(bad);
    }

    [Fact]
    public void WithoutAFormat_theFilterKeepsTheBrowsersDateField()
    {
        // The agents' reports pass no format: the browser's date field speaks ISO, as before.
        ColumnFilterDates.Parse("2026-11-03", null).Should().Be(new DateTime(2026, 11, 3));
        ColumnFilterDates.Show(new DateTime(2026, 11, 3), null).Should().Be("2026-11-03");
        var popup = Read("src", "CcDashboard.Web", "Components", "Shared", "ColumnFilterPopup.razor");
        popup.Should().Contain("type=\"date\"", "without a format the window keeps the browser's date field");
        popup.Should().Contain("IsTime && DateFormat is not null", "the text field is only for a report that asks for it");
    }

    // ---- who takes the Queue Report opt-ins ---------------------------------------------------------

    // Widened 2026-11-08 (FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01, operator 07:54): Agent Report takes the same format and
    // sort as Queue Report. The question stays "who takes the opt-ins": exactly the two configurable reports, and none
    // of the retired ones that still draw on old boards.
    [Fact]
    public void OnlyQueueReport_takesTheDateFormat_andTheSort()
    {
        var widgets = Directory.GetFiles(Widgets(), "*ReportWidget.razor").ToDictionary(f => Path.GetFileName(f)!, File.ReadAllText);
        widgets.Count.Should().BeGreaterThan(5, "the widgets must be findable");
        var two = new[] { "EndOfShiftAgentsReportWidget.razor", "EndOfShiftQueuesReportWidget.razor" };
        TakersOf(widgets, "DateFormat=").Should().Equal(two);
        TakersOf(widgets, "OnSort=").Should().Equal(two);

        // NEGATIVE HALF: a retired agents' widget that took the sort is caught.
        var leaked = new Dictionary<string, string>(widgets) { ["AgentMonthlyReportWidget.razor"] = "<ReportRowTable OnSort=\"X\"" };
        TakersOf(leaked, "OnSort=").Should().HaveCount(3);
    }

    private static List<string> TakersOf(Dictionary<string, string> files, string needle)
        => files.Where(f => f.Value.Contains(needle)).Select(f => f.Key).OrderBy(x => x).ToList();

    [Fact]
    public void TheAgentsFormat_isUntouched_inTheCommonCellRule()
    {
        // ReportCellFormat writes every other report; its DateTime / Date forms stay as they were.
        var rule = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "ReportCellFormat.cs");
        rule.Should().Contain("ToString(\"yyyy-MM-dd HH:mm\", CultureInfo.CurrentCulture)");
        rule.Should().Contain("ToString(\"d\", CultureInfo.CurrentCulture)");
        // Queue Report's own: every date column through its CellText, the stamp through the same rule.
        var queue = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "EndOfShiftQueuesReportWidget.razor");
        queue.Should().Contain("ReportIntervalLabel.Instant(WallClock.ToServerLocal(_dataThroughUtc.Value))");
        queue.Should().NotContain("ToString(\"yyyy-MM-dd HH:mm\")", "no date of Queue Report is written in the old form");
        queue.Should().Contain("kind is not (ReportColumnKind.DateTime or ReportColumnKind.Date)");
    }

    // ---- sorting ----------------------------------------------------------------------------------

    [Fact]
    public void AClickOnAColumnName_goesAscendingDescendingAndBack()
    {
        ReportSortCycle.Next(null, false, "Offered").Should().Be(("Offered", false));
        ReportSortCycle.Next("Offered", false, "Offered").Should().Be(("Offered", true));
        ReportSortCycle.Next("Offered", true, "Offered").Should().Be(((string?)null, false));
        ReportSortCycle.Next("Offered", true, "Workgroup").Should().Be(("Workgroup", false), "another column starts ascending");
    }

    [Fact]
    public void TheSort_goesToTheServer_andStartsAgainFromPageOne()
    {
        var queue = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "EndOfShiftQueuesReportWidget.razor");
        var build = Regex.Match(queue, @"private RunReportWidgetQuery BuildQuery\([\s\S]*?\n    \}").Value;
        build.Should().Contain("SortColumn = _sortColumn").And.Contain("SortDescending = _sortDescending",
            "the server pages the rows, so it must sort them - one page sorted on the screen is not the report's order");
        var sort = Regex.Match(queue, @"private async Task SortByAsync\([\s\S]*?\n    \}").Value;
        sort.Should().Contain("_page = 1").And.Contain("ReportSortCycle.Next");

        // NEGATIVE HALF: a sort kept on the screen only is caught.
        "Rows.OrderBy(r => r.Offered)".Should().NotContain("SortColumn =");
    }

    [Fact]
    public void TheTable_offersTheClick_onlyWhenAWidgetAsksForIt()
    {
        var table = Read("src", "CcDashboard.Web", "Components", "ReportWidgets", "ReportRowTable.razor");
        table.Should().Contain("@if (OnSort.HasDelegate)", "without a handler the header stays plain text");
        table.Should().Contain("aria-sort=\"@AriaSort(column)\"");
        Regex.IsMatch(table, @"=> !OnSort\.HasDelegate \? null").Should().BeTrue("no aria-sort on a table that does not sort");
    }

    private static string Widgets() => Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "ReportWidgets");

    private static string Read(params string[] parts) => File.ReadAllText(Path.Combine(new[] { RepoRoot() }.Concat(parts).ToArray()));

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;
        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
