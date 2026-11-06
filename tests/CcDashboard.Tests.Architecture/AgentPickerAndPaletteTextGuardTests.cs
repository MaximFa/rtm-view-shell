using System.Text.RegularExpressions;
using CcDashboard.Domain.Domain.Reports;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// Who the agent picker may offer, and in what language the palette speaks.
///
/// The picker rule is the one the server already enforces: the report narrows AgentIds to the
/// user's scope and drops the rest WITHOUT a word. A screen that offered an agent outside that
/// scope would therefore lie twice - once by offering, once when the report came back without
/// them - so the offer must come from GetScopedAgentsQuery, which is exactly as wide as the
/// report, and never from the rows of a previous answer (an agent with no data in the period
/// would then look like an agent who does not exist).
/// </summary>
public class AgentPickerAndPaletteTextGuardTests
{
    [Fact]
    public void ThePicker_offersTheServersScopedList_andNothingElse()
    {
        var modal = Modal();

        modal.Should().Contain("GetScopedAgentsQuery",
            "the offer must be the server's scoped list, which is exactly as wide as the report");
        modal.Should().Contain("_selectedAgentIds.RemoveWhere",
            "ticks on agents the new list no longer offers must be dropped, or the dialog claims a "
            + "choice the report will silently ignore");

        // NEGATIVE HALF: the shape that was rejected - building the list out of the rows that came
        // back from the report. It is named here so it cannot creep back in as an "optimisation".
        Regex.IsMatch(modal, @"_result\s*\.\s*Rows|AgentSummaryRow")
            .Should().BeFalse("the pickable agents must not be derived from a report answer");
    }

    [Fact]
    public void NothingTicked_isSavedAsNotSet_notAsAnEmptyList()
    {
        // "No choice" and "these zero agents" must not be the same stored value: the first means
        // every agent in scope, which is what an untouched widget has always meant.
        var modal = Modal();

        Regex.IsMatch(modal, @"AgentIds\s*=\s*IsAgentPerformanceWidget\s*&&\s*_selectedAgentIds\.Count\s*>\s*0")
            .Should().BeTrue("an empty tick set must be stored as null");
        Regex.IsMatch(modal, @"AgentIds\s*=\s*.*new List<string>\(\)")
            .Should().BeFalse("an empty list would read as \"these zero agents\"");
    }

    [Fact]
    public void ATruncatedList_saysSo()
    {
        // The server stops at 500. A person who cannot find their agent must learn the list was
        // cut, not conclude the agent is gone - the same rule as the export's skipped widgets.
        Modal().Should().Contain("ReportWidget_AgentsTruncated");

        foreach (var locale in Locales)
            Resx(locale).Should().Contain("name=\"ReportWidget_AgentsTruncated\"", $"missing from {locale}");
    }

    [Fact]
    public void EveryTypeHasALocalisedDescription_inEveryLocale_andTheCheckCanGoRed()
    {
        var editor = File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports", "ReportEditorPage.razor"));

        editor.Should().Contain("ReportWidgetPalette.DescriptionKey",
            "the palette must show the localised description, not the English constant");

        foreach (var locale in Locales)
        {
            var resx = Resx(locale);
            foreach (var type in Enum.GetValues<ReportWidgetType>())
                resx.Should().Contain($"name=\"Report_Desc{type}\"",
                    $"{type} has no description in {locale} and the palette entry would be blank");

            // NEGATIVE CONTROL: the same check on a key nobody added must fail.
            resx.Should().NotContain("name=\"Report_Desc__NoSuchTypeForTheGuard__\"");
        }
    }

    [Fact]
    public void EveryPickerKeyUsedInTheDialog_existsInEveryLocale()
    {
        // Measured the hard way twice already: a key present in en and missing in he renders a
        // blank where a sentence belongs, and only a Hebrew board ever shows it.
        var modal = Modal();
        var used = Regex.Matches(modal, @"L\[""(?<k>ReportWidget_Agents\w*)""\]")
            .Select(m => m.Groups["k"].Value)
            .Distinct()
            .ToList();

        used.Should().NotBeEmpty("the dialog must use the picker's resource keys, or this guard watches nothing");

        foreach (var locale in Locales)
            foreach (var key in used)
                Resx(locale).Should().Contain($"name=\"{key}\"", $"{key} is missing from {locale}");
    }

    private static readonly string[] Locales = { "en-US", "ru-RU", "he-IL" };

    private static string Modal()
        => File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Components", "ReportWidgets", "ReportWidgetConfigModal.razor"));

    private static string Resx(string locale)
        => File.ReadAllText(Path.Combine(
            RepoRoot(), "src", "CcDashboard.Web", "Resources", $"SharedResources.{locale}.resx"));

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;

        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
