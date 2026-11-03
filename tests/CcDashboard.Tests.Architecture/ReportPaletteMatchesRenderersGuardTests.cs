using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// A report widget type may appear in the palette only when something can draw it.
///
/// What went wrong: the palette listed Enum.GetValues&lt;ReportWidgetType&gt;(), so the three new
/// types showed up the moment the server side landed - with a technical name, no description and a
/// placeholder icon - and dropping one on a board rendered "unknown widget", because
/// RenderReportWidget had no branch for it. The palette promised what nothing could draw.
///
/// The rule (operator, 2026-11-03): a type enters the palette in the same commit as its renderer.
/// ReportWidgetPalette.Ready is the single list that decides it; this guard holds the other half.
/// </summary>
public class ReportPaletteMatchesRenderersGuardTests
{
    [Fact]
    public void EveryTypeInThePalette_hasABranchInTheDispatcher()
    {
        var ready = ReadyTypes();
        var dispatched = DispatchedTypes();

        ready.Should().NotBeEmpty("the palette must still offer something, or this guard watches nothing");
        ready.Except(dispatched).Should().BeEmpty(
            "a type offered in the palette with no renderer draws \"unknown widget\" when dropped");
    }

    [Fact]
    public void EveryTypeInThePalette_hasAName_aDescriptionAndAnIcon()
    {
        // A type present in Ready but missing from the presentation switches would fall through to
        // the technical enum name, an empty description and the placeholder icon - which is what
        // the operator saw. The switches must name it explicitly.
        var palette = PaletteSource();

        foreach (var type in ReadyTypes())
        {
            Regex.Matches(palette, $@"ReportWidgetType\.{Regex.Escape(type)}\b").Count
                .Should().BeGreaterThanOrEqualTo(5,
                    $"{type} must be named in Ready plus all four presentation switches (category, name, description, icon)");
        }
    }

    [Fact]
    public void ThePaletteDoesNotEnumerateTheEnum()
    {
        // NEGATIVE HALF #1: the whole fix is that the list is explicit. If someone puts
        // Enum.GetValues back, every future server-side type reappears in the palette unfinished,
        // and the first guard above would still pass as long as renderers happened to exist.
        var editor = File.ReadAllText(Path.Combine(ReportsDirectory(), "ReportEditorPage.razor"));

        editor.Should().NotContain("Enum.GetValues<ReportWidgetType>",
            "the palette must come from ReportWidgetPalette.Ready, not from the enum");
        editor.Should().Contain("ReportWidgetPalette.Ready", "and it must come from that one list");
    }

    [Fact]
    public void AnUnfinishedTypeIsOutOfThePalette_andTheGuardWouldNoticeIfItWereAdded()
    {
        // NEGATIVE HALF #2: the two agent summary types have a server side and no renderer yet, so
        // they must be absent. This also proves the guard can go red: adding either to Ready
        // without a renderer breaks the first test - checked here on the real lists rather than
        // asserted in prose.
        var ready = ReadyTypes();
        var dispatched = DispatchedTypes();

        ready.Should().NotContain("EndOfShiftAgents", "its renderer does not exist yet");
        ready.Should().NotContain("AgentPerformance", "its renderer does not exist yet");

        var hypothetical = ready.Append("EndOfShiftAgents").ToList();
        hypothetical.Except(dispatched).Should().NotBeEmpty(
            "so Ready + a type without a renderer must fail the first test - that is the red this guard produces");
    }

    [Fact]
    public void AWidgetTakesItsColumnsFromTheAnswer_notFromItsOwnCalculation()
    {
        // The column rule belongs to the server (Application.HistoricalReports.ReportWidgetConfig):
        // it decides "what the user picked, else the standard set", and the response carries the
        // outcome as EffectiveColumns. A widget that recomputed it could disagree with the cells
        // it is drawing - and there is a second trap: TWO types are named ReportWidgetConfig, the
        // web one (Appearance/Scope/PageSize) and the server one (the column rules). A widget sees
        // both namespaces, so the bare name binds to the web type, which has no such method. My
        // first attempt did exactly that and did not compile.
        var widget = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "EndOfShiftQueuesReportWidget.razor"));

        widget.Should().Contain("res.EffectiveColumns",
            "the columns must come from the response, so the header cannot disagree with the data");
        Regex.IsMatch(widget, @"(?<!CcDashboard\.Application\.HistoricalReports\.)ReportWidgetConfig\s*\.\s*(GetEffectiveColumns|DefaultColumns|AllowedColumns)")
            .Should().BeFalse(
            "a column rule may only be reached through the server type's full name, never through the bare name");

        // NEGATIVE HALF: if the fallback is there at all, it must be the server's rule by full name.
        if (widget.Contains("DefaultColumns"))
            widget.Should().Contain("CcDashboard.Application.HistoricalReports.ReportWidgetConfig",
                "the fallback must name the server type in full - that is the whole point");
    }

    [Fact]
    public void EveryColumnAnyRowCanCarry_hasALabel()
    {
        // The picker offers AllowedColumns (a row record's fields) and a widget draws what was
        // picked. A column offered without a label shows a technical identifier to the operator;
        // measured before the picker was built, 27 of 30 columns already had a key, each under a
        // different name than the field, so a field-to-key guess would have missed almost all.
        var labels = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "ReportColumnLabels.cs"));
        var known = Regex.Matches(labels, @"\[""(?<c>\w+)""\]\s*=")
            .Select(m => m.Groups["c"].Value).ToHashSet();

        var rowColumns = RowColumns();
        rowColumns.Should().NotBeEmpty("the row records must be readable, or this guard checks nothing");
        rowColumns.Except(known).Should().BeEmpty("every column a row can carry needs a label");

        // NEGATIVE HALF: a label naming a resource key that does not exist would render blank.
        var resx = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Resources", "SharedResources.en-US.resx"));
        var resourceKeys = Regex.Matches(resx, @"name=""(?<k>Report_\w+)""").Select(m => m.Groups["k"].Value).ToHashSet();
        var used = Regex.Matches(labels, @"=\s*""(?<k>Report_\w+)""").Select(m => m.Groups["k"].Value).Distinct();
        used.Except(resourceKeys).Should().BeEmpty("a label pointing at a missing resource key shows an empty header");
    }

    [Fact]
    public void ThePickerUsesTheServerColumnRule_byFullName()
    {
        // Two types are named ReportWidgetConfig; the bare name binds to the web one, which has no
        // column rules. The picker must reach the server's rule by full name - both for what it
        // offers and for the standard set - so the offer cannot differ from what the server
        // returns.
        var modal = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "ReportWidgetConfigModal.razor"));

        modal.Should().Contain("CcDashboard.Application.HistoricalReports.ReportWidgetConfig",
            "the server's column rule must be named in full");
        // The stub text lives in the resources, not in the markup - so check it where it is.
        // (My first version of this line looked for it inside the .razor, which could never
        // match and would have passed whatever the resources said.)
        var resxForStub = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Resources", "SharedResources.en-US.resx"));
        resxForStub.Should().NotContain("Column configuration will be available",
            "the \"future update\" stub must be gone now that the picker exists");

        // An empty tick list must be stored as "standard set", never as an empty column list:
        // a report with no columns renders an empty table, which reads as "no data".
        modal.Should().Contain("_selectedColumns.Count == 0", "an empty choice must be handled, not saved");
    }

    private static IReadOnlyList<string> RowColumns()
    {
        var dir = Path.Combine(RepoRoot(), "src", "CcDashboard.Application", "HistoricalReports", "Queries");
        var columns = new List<string>();
        foreach (var file in Directory.GetFiles(dir, "*.cs"))
        {
            var text = File.ReadAllText(file);
            foreach (var record in Regex.Matches(text, @"public record \w+Row\((?<body>[^)]*)\)", RegexOptions.Singleline).Cast<Match>())
                columns.AddRange(Regex.Matches(record.Groups["body"].Value, @"[\w?<>.]+\s+(?<name>\w+)\s*(?:,|$)")
                    .Select(m => m.Groups["name"].Value));
        }
        return columns.Distinct().ToList();
    }

    private static IReadOnlyList<string> ReadyTypes()
    {
        var palette = PaletteSource();
        var block = Regex.Match(palette, @"Ready\s*=\s*new\[\]\s*\{(?<body>[\s\S]*?)\};");
        block.Success.Should().BeTrue("ReportWidgetPalette.Ready must be a plain array literal, readable here");

        return Regex.Matches(block.Groups["body"].Value, @"ReportWidgetType\.(?<t>\w+)")
            .Select(m => m.Groups["t"].Value)
            .ToList();
    }

    private static IReadOnlyList<string> DispatchedTypes()
    {
        var dispatcher = File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "RenderReportWidget.razor"));
        return Regex.Matches(dispatcher, @"case ReportWidgetType\.(?<t>\w+)\s*:")
            .Select(m => m.Groups["t"].Value)
            .Distinct()
            .ToList();
    }

    private static string PaletteSource()
        => File.ReadAllText(Path.Combine(ReportWidgetsDirectory(), "ReportWidgetPalette.cs"));

    private static string ReportWidgetsDirectory()
        => Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "ReportWidgets");

    private static string ReportsDirectory()
        => Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Components", "Reports");

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;

        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
