using CcDashboard.Application.Reports.Export;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// FEAT-REPORT-EOS-CONFIGURABLE-01 (coordinator 11:22:59Z): the xlsx writes the cut-edge mark of a month / year row with the
/// en-US sentences of the screen (Report_IntervalFrom / _To / _FromTo). The file cannot read the Web resources, so it holds
/// the three sentences as constants; this guard MEASURES them against en-US.resx, so the two cannot drift apart.
/// </summary>
public class ExportIntervalMarkTextGuardTests
{
    [Theory]
    [InlineData("Report_IntervalFrom", ExportReportCommandHandler.IntervalFromText)]
    [InlineData("Report_IntervalTo", ExportReportCommandHandler.IntervalToText)]
    [InlineData("Report_IntervalFromTo", ExportReportCommandHandler.IntervalFromToText)]
    public void TheFilesMark_isTheScreensEnglishSentence(string key, string fileText)
        => EnUs().Should().Contain($"<data name=\"{key}\"><value>{fileText}</value></data>");

    [Fact]
    public void NEGATIVE_aSentenceTheScreenDoesNotHave_isNotFound()
        => EnUs().Should().NotContain("<data name=\"Report_IntervalFrom\"><value>(since {0})</value></data>");

    private static string EnUs()
        => File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Resources", "SharedResources.en-US.resx"));

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;
        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
