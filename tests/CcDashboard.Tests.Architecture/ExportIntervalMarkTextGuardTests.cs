using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// FEAT-REPORT-INTERVAL-LABEL-NO-EDGE-MARK-01 (operator 2026-11-07 18:51, «в дате убрать то, что в скобках»): the xlsx writes
/// the start of an interval exactly as the screen does - ReportIntervalLabel.Cell(start, step), the one rule - and carries
/// no edge-mark sentence of its own. Before this the file held the three en-US mark sentences as constants; a copy left
/// behind would bring the brackets back into the file while the screen has none.
/// </summary>
public class ExportIntervalMarkTextGuardTests
{
    private static readonly Regex MarkLiteral = new("\"\\((from|to) ", RegexOptions.Compiled);
    private static readonly Regex OneRuleCall = new(@"ReportIntervalLabel\.Cell\(start, step\)", RegexOptions.Compiled);

    [Fact]
    public void TheFile_writesTheIntervalByTheOneRule_andHasNoMarkSentenceOfItsOwn()
    {
        var src = Export();
        OneRuleCall.IsMatch(src).Should().BeTrue("the file must write the interval start by the screen's rule");
        MarkLiteral.IsMatch(src).Should().BeFalse("no \"(from …\" / \"(to …\" sentence may live in the export");
    }

    [Fact]
    public void NEGATIVE_theOldConstant_wouldBeCaught()
        => MarkLiteral.IsMatch("    public const string IntervalFromText = \"(from {0})\";").Should().BeTrue();

    private static string Export()
        => File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Application", "Reports", "Export", "ExportReportCommand.cs"));

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;
        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
