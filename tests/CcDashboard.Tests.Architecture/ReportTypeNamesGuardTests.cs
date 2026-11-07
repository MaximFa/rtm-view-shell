using CcDashboard.Application.HistoricalReports;
using CcDashboard.Domain.Domain.Reports;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// Coordinator 15:05:51Z: the xlsx names an untitled widget's sheet by the type's English name (ReportTypeNames), which must
/// be the screen's en-US name (Report_{type} in SharedResources.en-US.resx). Measured for every type, so a new type or a
/// renamed resource cannot leave the file with another name than the screen.
/// </summary>
public class ReportTypeNamesGuardTests
{
    [Fact]
    public void EveryTypesFileName_isTheScreensEnglishName()
    {
        var resx = EnUs();
        var types = Enum.GetValues<ReportWidgetType>();
        types.Should().NotBeEmpty();
        foreach (var type in types)
            resx.Should().Contain($"<data name=\"Report_{type}\"><value>{ReportTypeNames.English(type)}</value></data>",
                $"{type}: the file's sheet name must be the screen's English name");
    }

    [Fact]
    public void NEGATIVE_theEnumName_isNotTheScreensName()
        => EnUs().Should().NotContain("<data name=\"Report_EndOfShiftQueues\"><value>EndOfShiftQueues</value></data>");

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
