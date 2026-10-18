using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// The product spells filter operators in more than one alphabet, and each is read by exactly one
/// method:
///   * saved config rules — lower case ("greaterequal", "startswith"), read by MatchesTableFilterRule;
///   * the column funnel the viewer sets — camelCase ("lessOrEqual", "startsWith"), kept in the
///     browser's localStorage and read by MatchesValueFilter.
/// There is no live defect today: neither string ever reaches the other method, and the two are
/// stored in different places. These guards exist so that stays true — the cheap way to break it is
/// to copy a branch from the neighbouring method, and the result would be a filter that silently
/// stops filtering, with nothing on screen to show it.
///
/// Markers are compared CASE-SENSITIVELY on purpose: "startswith" and "startsWith" differ only in
/// one letter, and that is the whole trap.
/// </summary>
public class FilterOperatorAlphabetGuardTests
{
    // Operators that exist ONLY in the lower-case (saved rules) alphabet.
    private static readonly string[] SavedRuleOnly =
        { "greaterequal", "lessequal", "notcontains", "notequal", "notempty", "empty", "startswith", "endswith" };

    // Operators that exist ONLY in the camelCase (funnel) alphabet.
    private static readonly string[] FunnelOnly =
        { "lessOrEqual", "greaterOrEqual", "startsWith", "endsWith" };

    // "equal", "contains", "greater", "less" are spelled the same in both, so they are useless as
    // markers and are deliberately absent from the lists above.

    [Theory]
    [InlineData("AgentGridWidget.razor")]
    [InlineData("QueueGridWidget.razor")]
    public void TheFunnelMethodDoesNotSpeakTheSavedRuleAlphabet(string widget)
    {
        var body = MethodBody(widget, "private static bool MatchesValueFilter");
        body.Should().NotBeNullOrEmpty($"MatchesValueFilter must be found in {widget}");

        var strays = Literals(body).Intersect(SavedRuleOnly, StringComparer.Ordinal).ToList();
        strays.Should().BeEmpty(
            "the funnel reads its own camelCase alphabet; a lower-case operator here would never "
            + "match what the dropdown writes, so the filter would quietly pass every row. Found: "
            + string.Join(", ", strays));
    }

    [Fact]
    public void TheSavedRuleMethodDoesNotSpeakTheFunnelAlphabet()
    {
        var body = MethodBody("AgentGridWidget.razor", "private static bool MatchesTableFilterRule");
        body.Should().NotBeNullOrEmpty("MatchesTableFilterRule must be found");

        var strays = Literals(body).Intersect(FunnelOnly, StringComparer.Ordinal).ToList();
        strays.Should().BeEmpty(
            "saved rules are written in lower case by the editor; a camelCase operator here would "
            + "never match a saved rule. Found: " + string.Join(", ", strays));
    }

    [Fact]
    public void Guards_canGoRed_andEachMethodReallySpeaksItsOwnAlphabet()
    {
        // POSITIVE CONTROL. Without it both guards above stay green if MethodBody returned nothing
        // or if the markers simply never occur anywhere.
        var funnel = Literals(MethodBody("AgentGridWidget.razor", "private static bool MatchesValueFilter"));
        var saved = Literals(MethodBody("AgentGridWidget.razor", "private static bool MatchesTableFilterRule"));

        funnel.Should().Contain("lessOrEqual", "the funnel must really use the camelCase alphabet");
        saved.Should().Contain("greaterequal", "saved rules must really use the lower-case alphabet");

        // And the needle must be able to see a stray: the same intersection on a hand-made body.
        var planted = Literals("            \"lessOrEqual\" => true,").Intersect(FunnelOnly, StringComparer.Ordinal);
        planted.Should().NotBeEmpty("the check must detect a foreign operator when one is present");

        // Case sensitivity is the point: these two must not be treated as the same word.
        SavedRuleOnly.Should().Contain("startswith");
        FunnelOnly.Should().Contain("startsWith");
        string.Equals("startswith", "startsWith", StringComparison.Ordinal).Should().BeFalse();
    }

    private static List<string> Literals(string body)
        => Regex.Matches(body, "\"([A-Za-z]+)\"")
            .Select(m => m.Groups[1].Value)
            .Distinct(StringComparer.Ordinal)
            .ToList();

    private static string MethodBody(string widgetFileName, string signature)
    {
        var path = Path.Combine(WidgetsDirectory(), widgetFileName);
        File.Exists(path).Should().BeTrue($"{widgetFileName} must exist");

        var source = File.ReadAllText(path);
        var start = source.IndexOf(signature, StringComparison.Ordinal);
        if (start < 0) return string.Empty;

        // The method ends at the first closing brace at method indentation.
        var end = source.IndexOf("\n    }", start, StringComparison.Ordinal);
        return end < 0 ? source[start..] : source[start..end];
    }

    private static string WidgetsDirectory()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;

        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return Path.Combine(dir!.FullName, "src", "CcDashboard.Web", "Components", "Widgets");
    }
}
