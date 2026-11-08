using System.Text.RegularExpressions;
using CcDashboard.Domain.Domain.Reports;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// No report takes shift hours or one date any more; both remaining reports take the page's period.
///
/// History: 2026-11-04 the end-of-shift widgets did not send the hours the server required (zero occurrences under
/// src/CcDashboard.Web), and this file held "send both hours, ask for one date". 2026-11-07 the queues report took a
/// period and a step; 2026-11-08 the agents report did too (FEAT-REPORT-EOS-AGENTS-CONFIGURABLE-01, operator 07:54),
/// and the server refuses hours on both. So the question is now the opposite one, for every type the palette offers:
/// no hours in the query, the page's From..To, and a settings dialog that does not keep an hour pair alive.
/// The four cases of the old question became two: the old "sends both hours" and "asks for one date" had no type
/// left to ask about.
/// </summary>
public class EndOfShiftWidgetsSendShiftHoursGuardTests
{
    [Fact]
    public void EveryOfferedReport_sendsNoHours_andThePagesPeriod()
    {
        var types = CcDashboard.Web.Components.ReportWidgets.ReportWidgetPalette.Ready;
        types.Should().Contain(new[] { ReportWidgetType.EndOfShiftQueues, ReportWidgetType.EndOfShiftAgents },
            "both reports must be findable here, or this guard checks nothing");

        foreach (var type in types)
        {
            // Both trend charts are drawn by ONE body (FEAT-REPORT-AGENT-STATE-TREND-01): their query is that file's.
            var file = CcDashboard.Web.Components.ReportWidgets.QueueTrendView.IsTrend(type) ? "QueueTrendReportWidget.razor" : $"{type}ReportWidget.razor";
            var text = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), file));
            var call = QueryStatement(text);
            SendsAnyHour(call).Should().BeFalse($"{type}: the server refuses shift hours");
            ForwardsThePeriod(call).Should().BeTrue($"{type}: the window is the page's From..To");
        }

        // NEGATIVE HALVES, on the shape the agents report had until 2026-11-08: hours from the config, one date.
        const string before = """
            new RunReportWidgetQuery(
                ReportWidgetType.EndOfShiftAgents,
                effectiveConfig.ToJson(),
                shiftDate,
                shiftDate,
                _page,
                TenantId,
                false,
                Config?.ShiftStartHour,
                Config?.ShiftEndHour);
            """;
        SendsAnyHour(before).Should().BeTrue("a query that still sends the hours must be seen");
        ForwardsThePeriod(before).Should().BeFalse("one date on both ends is not the page's period");
    }

    [Fact]
    public void TheSettingsDialog_offersNoHours_andDropsAnOldPairOnSave()
    {
        var modal = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "ReportWidgetConfigModal.razor"));
        DropsHours(modal).Should().BeTrue("a pair left in an old configuration must not be saved again");
        modal.Should().NotContain("@bind=\"_shiftStartHour\"", "the dialog must not offer the hours");

        // NEGATIVE HALF: the 2026-11-07 save line, which kept the pair for the agents report, is caught.
        DropsHours("ShiftStartHour = IsEndOfShiftWidget ? _shiftStartHour : null,").Should().BeFalse();
    }

    private static bool DropsHours(string text)
        => Regex.IsMatch(text, @"ShiftStartHour\s*=\s*null\s*,") && Regex.IsMatch(text, @"ShiftEndHour\s*=\s*null\s*,");

    /// <summary>The query from "new RunReportWidgetQuery(" to the end of its statement.</summary>
    private static string QueryStatement(string text)
    {
        var start = text.IndexOf("new RunReportWidgetQuery(", StringComparison.Ordinal);
        start.Should().BeGreaterThanOrEqualTo(0, "the widget must build a query, readable here");
        var end = text.IndexOf(';', start);
        end.Should().BeGreaterThan(start);
        return text[start..end];
    }

    private static bool SendsAnyHour(string call) => Regex.IsMatch(call, @"[Ss]tartHour|[Ee]ndHour");

    private static bool ForwardsThePeriod(string call)
        => Regex.IsMatch(call, @"^\s*From\s*,\s*$", RegexOptions.Multiline)
           && Regex.IsMatch(call, @"^\s*To\s*,\s*$", RegexOptions.Multiline);

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
