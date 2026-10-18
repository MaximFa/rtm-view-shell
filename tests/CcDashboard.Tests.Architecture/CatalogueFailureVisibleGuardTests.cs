using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// A failed read of the metric catalogue must be VISIBLE and RETRIED.
///
/// This is the defect this guard was written for, measured on 234 after effcd27: the read failed
/// (concurrent reads through one context), the widget swallowed it, every column silently became
/// text, and it stayed that way until the page was reloaded. Silence looked exactly like working
/// software — the columns were simply never numeric again.
///
/// The guard reads SOURCE, so it watches the shape of the handling, not the behaviour: that the
/// catch sets a visible flag, logs an error once, and that the loader can run again instead of
/// being a one-shot call. The behaviour itself is checked on screen after the deploy — a widget's
/// private members are not reachable from tests and there is no bUnit in this solution.
/// </summary>
public class CatalogueFailureVisibleGuardTests
{
    private static readonly string[] WidgetsUsingTheCatalogue =
        { "AgentGridWidget.razor", "QueueGridWidget.razor", "DataSlotWidget.razor" };

    [Theory]
    [InlineData("AgentGridWidget.razor")]
    [InlineData("QueueGridWidget.razor")]
    [InlineData("DataSlotWidget.razor")]
    public void AFailedCatalogueRead_isRemembered_loggedAsError_andShownToTheUser(string widget)
    {
        var source = Source(widget);

        source.Should().Contain("_catalogueUnavailable = true",
            "a failed read must be remembered, not swallowed");
        source.Should().Contain("Widget_ColumnTypesUnavailable",
            "the widget must say the types are unavailable instead of quietly showing every value as text");
        Regex.IsMatch(source, @"Logger\.LogError\(ex,").Should().BeTrue(
            "a read failure is an error, not a warning: it disables sorting and thresholds");
        source.Should().Contain("_catalogueErrorLogged",
            "the error is logged once per failure spell, not on every retry");
    }

    [Theory]
    [InlineData("AgentGridWidget.razor")]
    [InlineData("QueueGridWidget.razor")]
    [InlineData("DataSlotWidget.razor")]
    public void TheLoaderCanRunAgain_soAOneOffFailureDoesNotLastUntilAReload(string widget)
    {
        var source = Source(widget);

        // Named "Ensure…", called more than once: once at init and again when fresh data arrives.
        var calls = Regex.Matches(source, @"await Ensure(MetricValueTypes?|MetricValueType)Async\(").Count;
        calls.Should().BeGreaterThan(1,
            $"{widget} must retry the catalogue on new data, not only at initialisation");

        source.Should().NotContain("LoadMetricValueTypesAsync",
            "the one-shot loader is gone; its name surviving would mean a second, non-retrying path");
    }

    [Fact]
    public void Guard_canGoRed_andDoesNotAcceptTheOldSwallowingShape()
    {
        // NEGATIVE HALF. Without this the two guards above are green if Source() returned nothing
        // or if the needles match any text at all.
        var agent = Source("AgentGridWidget.razor");
        agent.Should().NotBeNullOrEmpty("the widget source must actually be read");

        // The old shape: swallow, warn, blank the dictionary. It must NOT be what we have now.
        agent.Should().NotContain("metric catalogue unavailable, columns shown as text",
            "that was the silent handling this guard exists to prevent");

        // And the needles must be able to fail on a hand-made source that lacks the handling.
        const string swallowing = "catch (Exception ex) { _types = new(); }";
        swallowing.Contains("_catalogueUnavailable = true").Should().BeFalse();
        Regex.IsMatch(swallowing, @"Logger\.LogError\(ex,").Should().BeFalse();
    }

    [Fact]
    public void EveryWidgetThatReadsTheCatalogue_isCoveredHere()
    {
        // Guards that name files by hand rot when a fourth widget starts reading the catalogue.
        var dir = WidgetsDirectory();
        var readers = Directory.GetFiles(dir, "*.razor")
            .Where(f => File.ReadAllText(f).Contains("IMetricCatalogue"))
            .Select(Path.GetFileName)
            .ToList();

        readers.Should().BeEquivalentTo(WidgetsUsingTheCatalogue,
            "a widget reading the catalogue without this handling would fail silently again");
    }

    private static string Source(string widgetFileName)
    {
        var path = Path.Combine(WidgetsDirectory(), widgetFileName);
        File.Exists(path).Should().BeTrue($"{widgetFileName} must exist");
        return File.ReadAllText(path);
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
