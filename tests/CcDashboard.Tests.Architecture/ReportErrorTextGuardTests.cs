using System.Text.RegularExpressions;
using CcDashboard.Application.HistoricalReports.Queries;
using CcDashboard.Contracts.Common;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// A failed report says why in the reader's language, and never shows the log line.
///
/// ReportWidgetResult carries two things: Error, whose own summary says "for the log only - never
/// shown as is", and ErrorCode, "the screen shows this". All eight report widgets were printing
/// Error. So a retired report told whoever opened it "Report type QueueInterval is retired" - in
/// English, on a Hebrew board - and a bad configuration showed whatever sentence the handler
/// happened to write for the log. Same family as the caveat that used to arrive as English prose.
///
/// ReportErrorText lives in Contracts, which cannot reference Application, so it pairs the codes
/// by their text. That pairing is the dangerous part - a code renamed on one side and not the
/// other would fall through to the general sentence and look like a fault in the report - so it is
/// MEASURED here against ReportReasonCodes itself, not trusted.
/// </summary>
public class ReportErrorTextGuardTests
{
    [Fact]
    public void EveryReasonCodeTheServerCanSend_hasASentenceOfItsOwn()
    {
        ReportReasonCodes.All.Should().NotBeEmpty("the codes must be findable, or this guard watches nothing");

        foreach (var code in ReportReasonCodes.All)
            ReportErrorText.IsUnknown(code)
                .Should().BeFalse($"the screen must have words for \"{code}\" - the general sentence is for codes we have not seen yet");
    }

    [Fact]
    public void NEGATIVE_anUnknownOrMissingCode_stillSaysSomething()
    {
        // The opposite of the caveat rule, on purpose: a caveat is an explanation and may be
        // omitted, but a report that FAILED must never fail silently - an empty widget reads as
        // "there was no work".
        ReportErrorText.IsUnknown("status-start-bucket").Should().BeTrue("a code we do not know must be recognised as unknown");
        ReportErrorText.IsUnknown(null).Should().BeTrue();
        ReportErrorText.IsUnknown("").Should().BeTrue();

        ReportErrorText.KeyFor("something-new-from-the-server")
            .Should().Be("Report_ErrorUnknown", "and it must still have a sentence");
        ReportErrorText.KeyFor(null).Should().NotBeNullOrWhiteSpace();
    }

    [Fact]
    public void TheCodeIsReadCaseAndSpaceInsensitively()
    {
        ReportErrorText.KeyFor("  RETIRED ").Should().Be(ReportErrorText.KeyFor("retired"));
    }

    [Fact]
    public void NoReportWidget_printsTheServersLogLine()
    {
        var widgets = Directory.GetFiles(ReportWidgetsDirectory(), "*ReportWidget.razor");
        widgets.Length.Should().BeGreaterThan(1, "the widgets must be findable");

        foreach (var file in widgets)
        {
            var text = File.ReadAllText(file);
            var name = Path.GetFileName(file);

            Regex.IsMatch(text, @"_error\s*=\s*res\.Error\s*;")
                .Should().BeFalse($"{name} shows the server's log line - English prose on whatever board opens it");
            Regex.IsMatch(text, @"_error\s*=\s*ex\.Message\s*;")
                .Should().BeFalse($"{name} shows the exception message - that is for the log, not for the reader");

            if (text.Contains("_error ="))
                text.Should().Contain("ReportErrorText",
                    $"{name} sets an error of its own without the one rule for the words");
        }
    }

    [Fact]
    public void EverySentenceExists_inEnglish()
    {
        // A key with no value renders as the key itself: "Report_ErrorRetired" on the board.
        var resx = File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Resources", "SharedResources.en-US.resx"));

        var keys = ReportReasonCodes.All.Select(ReportErrorText.KeyFor)
            .Append(ReportErrorText.KeyFor("unheard-of"))
            .Distinct();

        foreach (var key in keys)
            resx.Should().Contain($"name=\"{key}\"", $"{key} must have an English value");
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
