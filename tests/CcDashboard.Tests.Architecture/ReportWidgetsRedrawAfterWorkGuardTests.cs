using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// A report widget must not change what it shows off the render path.
///
/// Measured on 234 on 2026-11-07, with the operator watching: the agent report sat with a spinner
/// and no rows for minutes. The data had arrived long before - a single keystroke anywhere in the
/// field cleared it instantly. The filter scheduled its request from a background task (a delay,
/// then InvokeAsync), so the state was updated outside the event that caused it and nothing asked
/// the screen to redraw. From outside it looked like a broken server.
///
/// The cure was to remove the background path rather than to add a redraw to it: while such a
/// path exists, the next person repeats the mistake next door. This guard holds that removal -
/// not the spelling of one old line, but the rule: in a report widget, no timers, no background
/// tasks, no per-keystroke input. Work follows an event, and a redraw follows the work.
/// </summary>
public class ReportWidgetsRedrawAfterWorkGuardTests
{
    /// <summary>Ways of leaving the render path that this family of widgets must not use.</summary>
    private static readonly (string Name, string Pattern)[] OffRenderPathShapes =
    {
        ("Task.Run", @"Task\s*\.\s*Run\s*\("),
        ("Task.Delay", @"Task\s*\.\s*Delay\s*\("),
        ("a timer", @"\bnew\s+(System\.Threading\.)?Timer\s*\(|PeriodicTimer"),
        ("input on every keystroke", @"@oninput\s*="),
    };

    [Theory]
    [InlineData("EndOfShiftAgentsReportWidget.razor")]
    [InlineData("AgentPerformanceReportWidget.razor")]
    [InlineData("EndOfShiftQueuesReportWidget.razor")]
    public void AReportWidget_doesNoWorkOffTheRenderPath(string widgetFile)
    {
        var widget = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), widgetFile));

        foreach (var (name, pattern) in OffRenderPathShapes)
            Regex.IsMatch(widget, pattern).Should().BeFalse(
                $"{widgetFile} uses {name}: state changed there is not followed by a redraw, "
                + "and the widget sits spinning after its data has arrived");

        // The widget must still actually filter - otherwise this guard is watching something that
        // cannot fail in the way the defect failed.
        widget.Should().Contain("ApplyFilterAsync",
            $"{widgetFile} must apply its filter on an event - by the button or by Enter");
    }

    [Fact]
    public void ThePredicateCanGoRed()
    {
        // NEGATIVE HALF: each shape, written the way it would really appear, must be caught. If
        // this fact ever passes while the loop above sees nothing, the loop is blind.
        const string backgroundTask = """
            private void ScheduleFilter()
            {
                _ = Task.Run(async () =>
                {
                    await Task.Delay(500, cts.Token);
                    await InvokeAsync(ApplyFilterAsync);
                });
            }
            """;
        const string perKeystroke = """
            <input type="text" value="@_agentFilter" @oninput="e => OnFilterInput(e, isName: false)" />
            """;

        OffRenderPathShapes.Where(s => Regex.IsMatch(backgroundTask, s.Pattern))
            .Select(s => s.Name)
            .Should().Contain(new[] { "Task.Run", "Task.Delay" },
                "the background scheduler that caused the stuck spinner must be seen");

        OffRenderPathShapes.Where(s => Regex.IsMatch(perKeystroke, s.Pattern))
            .Select(s => s.Name)
            .Should().Contain("input on every keystroke",
                "a request per letter must be seen - that was the flicker half of the same defect");
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
