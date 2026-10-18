using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using FluentAssertions;
using Xunit;

namespace CcDashboard.Tests.Unit.Seeding;

/// <summary>
/// Metric definitions shipped for a FRESH install must carry the fixes the migrations applied to live databases.
/// Canonical fresh install = db/tools/Provision-FreshDb.ps1 -> db/data/*.sql (02_metrics.sql TRUNCATE + COPY over the seed);
/// the seed (DatabaseInitializer.SeedRtsGridMetricsAsync) is what a path without db/data gets.
/// Every predicate is whitespace-tolerant and is proven able to go RED on the known old text (negative half).
/// </summary>
public class MetricSeedConsistencyTests
{
    // ---------- predicates ----------

    // 20260605_004 step 4: "[QueueNumAnsweredCalls30sec ]" (space inside the key) makes the Calc lookup miss -> numerator 0.
    private static bool HasSpacedCalcKey(string parameter) => Regex.IsMatch(parameter, @"\[\s*QueueNumAnsweredCalls30sec\s+\]|\[\s+QueueNumAnsweredCalls30sec\s*\]");

    // 20260605_004 step 3: the "external only" metric must not count Intercom.
    private static bool CountsIntercom(string parameter) => Regex.IsMatch(parameter, @"CallType\s*==\s*""Intercom""");

    // 20260607_003: the engine switch is case-sensitive: case "CurLoginTimestamp" (RTM UserManager).
    private static bool IsEngineLoginTimestampFunction(string function) => function == "CurLoginTimestamp";

    // Double-encoded UTF-8 of an em dash ("\u2014" read as cp1252 and re-encoded).
    private static bool HasMojibake(string text) => text.Contains("\u00e2\u20ac");

    // ---------- negative halves: each predicate goes red on the known old text ----------

    [Fact]
    public void Predicates_GoRedOnTheKnownOldText()
    {
        HasSpacedCalcKey("[QueueNumIncomingCompletedCalls]==0 ? 0 : ((double)[QueueNumAnsweredCalls30sec ]/([QueueNumIncomingCompletedCalls]*0.8))").Should().BeTrue();
        HasSpacedCalcKey("((double)[QueueNumAnsweredCalls30sec]/[X])").Should().BeFalse();

        CountsIntercom("(InteractionType==\"Call\" ||  InteractionType==\"Callback\") && (CallType==\"External\" || CallType==\"Intercom\") && Direction==\"Incoming\"").Should().BeTrue();
        CountsIntercom(" (InteractionType==\"Call\" ||  InteractionType==\"Callback\") && CallType==\"External\" && Direction==\"Incoming\"").Should().BeFalse();

        IsEngineLoginTimestampFunction("CurLoginTimeStamp").Should().BeFalse();
        IsEngineLoginTimestampFunction("CurLoginTimestamp").Should().BeTrue();

        // The check reads the MetricFunction COLUMN only: a catalog note that still names the old value must not trip it.
        var noteMentionsOld = "MonAgentCurrentLoginTimeStamp\tx\tUser\tCurLoginTimestamp\t\t\\N\t\\N\ttext\tAgent\tAgent\tFIXED: was 'CurLoginTimeStamp'";
        var columnStillOld = "MonAgentCurrentLoginTimeStamp\tx\tUser\tCurLoginTimeStamp\t\t\\N\t\\N\ttext\tAgent\tAgent\tnote";
        IsEngineLoginTimestampFunction(CopyFields(noteMentionsOld)[Function]!).Should().BeTrue();
        IsEngineLoginTimestampFunction(CopyFields(columnStillOld)[Function]!).Should().BeFalse();

        HasMojibake("ISO 18295-1:2017, Annex A (informative) \u00e2\u20ac\u201d Metrics guidelines").Should().BeTrue();
        HasMojibake("ISO 18295-1:2017, Annex A (informative) \u2014 Metrics guidelines").Should().BeFalse();
    }

    // ---------- the shipped files ----------

    private static string RepoFile(string relative)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "CcDashboard.sln"))) dir = dir.Parent;
        dir.Should().NotBeNull("the test must find the repository root (CcDashboard.sln) above its output folder");
        var path = Path.Combine(dir!.FullName, relative.Replace('/', Path.DirectorySeparatorChar));
        File.Exists(path).Should().BeTrue(path + " must exist");
        return path;
    }

    private static string?[] CopyFields(string line) => line.Split('\t').Select(x => x == "\\N" ? null : x).ToArray();

    /// <summary>db/data/02_metrics.sql RTSGrid_Metric COPY rows: MetricId -> 21 columns (\N = null).</summary>
    private static Dictionary<string, string?[]> CanonicalRows()
    {
        var rows = new Dictionary<string, string?[]>();
        bool inCopy = false;
        foreach (var line in File.ReadLines(RepoFile("db/data/02_metrics.sql"), Encoding.UTF8))
        {
            if (line.StartsWith("COPY \"RTSGrid_Metric\"")) { inCopy = true; continue; }
            if (!inCopy) continue;
            if (line == "\\.") break;
            var p = CopyFields(line);
            rows[p[0]!] = p;
        }
        return rows;
    }

    private const int Function = 3, Parameter = 4, StandardRef = 19;

    /// <summary>Seed rows: MetricId -> (field -> value) from SeedRtsGridMetricsAsync.</summary>
    private static Dictionary<string, Dictionary<string, string?>> SeedRows()
    {
        var src = File.ReadAllText(RepoFile("src/CcDashboard.Infrastructure/Seeding/DatabaseInitializer.cs"), Encoding.UTF8);
        int a = src.IndexOf("private async Task SeedRtsGridMetricsAsync", StringComparison.Ordinal);
        int b = src.IndexOf("private async Task SeedHistoryMetricsAsync", StringComparison.Ordinal);
        a.Should().BeGreaterThan(0); b.Should().BeGreaterThan(a);
        var rows = new Dictionary<string, Dictionary<string, string?>>();
        foreach (Match m in Regex.Matches(src[a..b], @"new\(\)\s*\{(.*?)\},\s*\n", RegexOptions.Singleline))
        {
            var d = new Dictionary<string, string?>();
            foreach (Match f in Regex.Matches(m.Groups[1].Value, @"(\w+)\s*=\s*(null|""((?:[^""\\]|\\.)*)"")"))
                d[f.Groups[1].Value] = f.Groups[2].Value == "null" ? null : Regex.Unescape(f.Groups[3].Value);
            if (d.TryGetValue("MetricId", out var id) && id != null) rows[id] = d;
        }
        return rows;
    }

    [Fact]
    public void CanonicalFreshInstall_CarriesTheMigrationFixes()
    {
        var rows = CanonicalRows();
        rows.Should().ContainKeys("QueueSLAIn30secFrom80PctInc", "MonAgentNumberOfInboundCallsOnly", "MonAgentCurrentLoginTimeStamp",
            "QueueNumAbandonedCalls", "QueueNumAbandonedCallbacks", "QueueNumTransferredCalls");

        HasSpacedCalcKey(rows["QueueSLAIn30secFrom80PctInc"][Parameter]!).Should().BeFalse("20260605_004 step 4");
        CountsIntercom(rows["MonAgentNumberOfInboundCallsOnly"][Parameter]!).Should().BeFalse("20260605_004 step 3");
        IsEngineLoginTimestampFunction(rows["MonAgentCurrentLoginTimeStamp"][Function]!).Should().BeTrue("20260607_003");
        foreach (var id in new[] { "QueueNumAbandonedCalls", "QueueNumAbandonedCallbacks", "QueueNumTransferredCalls" })
            HasMojibake(rows[id][StandardRef] ?? "").Should().BeFalse(id + " StandardRef");
        HasMojibake(File.ReadAllText(RepoFile("db/data/02_metrics.sql"), Encoding.UTF8)).Should().BeFalse("no double-encoded text anywhere in the file");
    }

    [Fact]
    public void Seed_CarriesTheMigrationFixes_AndEveryCanonicalMetric()
    {
        var seed = SeedRows();
        HasSpacedCalcKey(seed["QueueSLAIn30secFrom80PctInc"]["MetricParameter"]!).Should().BeFalse("20260605_004 step 4");
        CountsIntercom(seed["MonAgentNumberOfInboundCallsOnly"]["MetricParameter"]!).Should().BeFalse("20260605_004 step 3");
        IsEngineLoginTimestampFunction(seed["MonAgentCurrentLoginTimeStamp"]["MetricFunction"]!).Should().BeTrue("20260607_003");

        seed.Keys.Should().BeEquivalentTo(CanonicalRows().Keys, "the seed and the canonical fresh install ship the same metric set");
    }
}
