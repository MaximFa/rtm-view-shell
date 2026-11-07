using System.Reflection;
using System.Text.RegularExpressions;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Contracts.Common;
using CcDashboard.Web.Components.ReportWidgets;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// The agent performance report is refused by the server without a mode ("Mode (summary|byDate)
/// required for the agent performance report"), exactly as the end-of-shift reports were refused
/// without their hours. That defect cost a production screen that could only draw an English
/// refusal, so its shape is held here rather than trusted not to return:
///
///   1. the two mode values the dialog saves ARE the server's enum names, camelCased, and they
///      cover every value the enum has - a third mode must turn this red, not be silently unoffered;
///   2. the widget refuses locally when no mode is set, and sends no shift hours - the server
///      rejects hours on any type but the end-of-shift pair, so "just in case" would break it;
///   3. the dialog offers both modes, blocks Save without one, and its texts exist in all three
///      locales.
/// </summary>
public class AgentPerformanceModeGuardTests
{
    [Fact]
    public void TheWireValues_areTheEnumNamesCamelCased_andCoverEveryMode()
    {
        var enumNames = Enum.GetNames<AgentPerformanceMode>();
        enumNames.Should().NotBeEmpty("the mode enum must be readable, or this guard checks nothing");

        var expected = enumNames.Select(CamelCase).ToHashSet(StringComparer.Ordinal);
        var declared = WireValues();

        declared.Should().BeEquivalentTo(expected,
            "the dialog may only save values the server's camelCase string-enum converter accepts, "
            + "and it must offer every mode the enum has");

        // NEGATIVE HALF: a mode the constants do not carry must be seen as uncovered. Built from a
        // name that is not in the enum, so this stays capable of failing even when both sides agree.
        var pretendEnum = expected.Append("weeklyRollup").ToHashSet(StringComparer.Ordinal);
        pretendEnum.Except(declared).Should().Contain("weeklyRollup",
            "the comparison must still spot a mode with no constant - that is the red this guard produces");
    }

    [Fact]
    public void TheWidget_refusesWithoutAMode_andSendsNoShiftHours()
    {
        var widget = WidgetSource();

        widget.Should().Contain("AgentPerformanceModes.Summary",
            "the widget must compare against the shared constants, not against strings of its own");
        widget.Should().Contain("_needsMode",
            "an unset mode must be caught in the widget, so no query is sent and the message is localised");
        widget.Should().Contain("ReportWidget_ModeMissing",
            "and that message must come from the resources");

        var call = QueryCall(widget);
        Regex.IsMatch(call, @"[Ss]tartHour|[Ee]ndHour").Should().BeFalse(
            "shift hours on this type are refused by the server: \"Shift hours apply only to the end-of-shift reports\"");

        // NEGATIVE HALF: the shape that would have been wrong - hours copied over from the
        // end-of-shift widget this one was derived from.
        const string callWithHours = """
            new RunReportWidgetQuery(
                ReportWidgetType.AgentPerformance,
                configJson,
                From,
                To,
                _page,
                TenantId,
                false,
                startHour,
                endHour)
            """;
        Regex.IsMatch(callWithHours, @"[Ss]tartHour|[Ee]ndHour").Should().BeTrue(
            "the predicate must be able to see hours where they exist, or its silence means nothing");
    }

    [Fact]
    public void TheDialog_offersBothModes_blocksSave_andHasItsTextsInEveryLocale()
    {
        var modal = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "ReportWidgetConfigModal.razor"));

        foreach (var value in WireValues())
        {
            var constant = value == "summary" ? "AgentPerformanceModes.Summary" : "AgentPerformanceModes.ByDate";
            modal.Should().Contain(constant, $"the dialog must offer the {value} mode");
        }
        modal.Should().Contain("ModeProblem is null",
            "Save must be blocked while no mode is chosen, not merely warned about");

        foreach (var locale in new[] { "en-US", "ru-RU", "he-IL" })
        {
            var resx = File.ReadAllText(Path.Combine(
                RepoRoot(), "src", "CcDashboard.Web", "Resources", $"SharedResources.{locale}.resx"));

            foreach (var key in new[]
                     {
                         "Report_AgentPerformance",
                         "ReportWidget_Mode",
                         "ReportWidget_ModeSummary",
                         "ReportWidget_ModeByDate",
                         "ReportWidget_ModeRequired",
                         "ReportWidget_ModeMissing"
                     })
                resx.Should().Contain($"name=\"{key}\"", $"{key} is missing from {locale} and would render blank");

            // NEGATIVE CONTROL for the presence check itself.
            resx.Should().NotContain("name=\"ReportWidget_Mode__NoSuchKeyForTheGuard__\"");
        }
    }

    [Fact]
    public void TheDateColumnFollowsTheMode_notThePicker()
    {
        // The rule (coordinator, 2026-11-04): in "by date" the date is shown whether it was picked
        // or not, and in "summary" it is not shown even if it was. It lives in AgentSummaryColumns
        // because a .razor component's members are not reachable from tests - so what is held here
        // is that the widget USES the rule instead of carrying a weaker copy of it.
        var widget = WidgetSource();

        widget.Should().Contain("AgentSummaryColumns.ForMode",
            "the mode rule must come from the one place that is unit-tested");
        widget.Should().NotContain("!columns.Contains(\"Date\")",
            "the earlier version only added the date when the server's standard set lacked it - "
            + "a hand-picked column list defeated that");

        // And the rule itself, exercised here too, so this file fails if the behaviour changes
        // even while the call stays in place.
        AgentSummaryColumns.ForMode(new[] { "Handled" }, byDate: true).Should().Equal("Date", "Handled");
        AgentSummaryColumns.ForMode(new[] { "Date", "Handled" }, byDate: false).Should().Equal("Handled");

        // The shared table must still be able to print it, or the column would render as an empty
        // cell - the same silence one layer down. It is no longer a question of a hand-written
        // switch: the table asks ReportColumns what the column holds, so what this now checks is
        // that the rule knows the column at all.
        CcDashboard.Application.HistoricalReports.ReportColumns
            .Find(CcDashboard.Domain.Domain.Reports.ReportWidgetType.AgentPerformance, "Date")
            .Should().NotBeNull("the date column must be known to the one column rule");
    }

    private static string CamelCase(string name) => char.ToLowerInvariant(name[0]) + name[1..];

    /// <summary>The wire values as the constants declare them - read from the type, not retyped here.</summary>
    private static HashSet<string> WireValues()
        => typeof(AgentPerformanceModes)
            .GetFields(BindingFlags.Public | BindingFlags.Static)
            .Where(f => f.IsLiteral && f.FieldType == typeof(string))
            .Select(f => (string)f.GetRawConstantValue()!)
            .ToHashSet(StringComparer.Ordinal);

    private static string WidgetSource()
        => File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "AgentPerformanceReportWidget.razor"));

    private static string QueryCall(string widget)
    {
        // Constructor call, with or without an object initializer after it (the filters arrived
        // that way). Both parts are returned: a parser that read only the constructor would stop
        // noticing anything the initializer sets - weaker, not fixed.
        var call = Regex.Match(widget, @"new RunReportWidgetQuery\((?<args>[\s\S]*?)\)\s*(?<init>\{[\s\S]*?\})?\s*\);");
        call.Success.Should().BeTrue("the widget must build a query, readable here");
        return call.Groups["args"].Value + call.Groups["init"].Value;
    }

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
