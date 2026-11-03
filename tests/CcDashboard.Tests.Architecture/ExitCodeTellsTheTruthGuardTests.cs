using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// PR234-V4-WEB-MIGRATE-EXITCODE-01: a failure must show up in the exit code, not only in the log.
///
/// Found by devops: `CcDashboard.Web.exe migrate` wrote "[FTL] Application terminated unexpectedly"
/// and still exited 0. A top-level program that falls out of its catch block returns success, so
/// the log said failure and the process said success. The scripts that run migrate read the code,
/// not the log - Rebuild-Proof.ps1 throws on a non-zero code - so a half-migrated schema was
/// accepted and its "proof" built on top of it. A green that proves nothing is worse than a red.
///
/// This guard reads source: the exit code of a process cannot be reached from a unit test, and the
/// real check is running migrate against a wrong password and looking at the code (devops, live).
/// What is held here is the shape that made the lie possible.
/// </summary>
public class ExitCodeTellsTheTruthGuardTests
{
    [Fact]
    public void TheFatalCatchReturnsANonZeroCode()
    {
        var program = ProgramSource();

        // The catch that logs Fatal must also return non-zero. Matching the two together, not just
        // "a return 1 exists somewhere", is the point: a stray return elsewhere would not help.
        var fatalCatch = Regex.Match(program,
            @"catch \(Exception ex\) when \(ex is not HostAbortedException\)\s*\{(?<body>[\s\S]*?)\n\}",
            RegexOptions.Compiled);

        fatalCatch.Success.Should().BeTrue("the top-level catch must still be there to be checked");
        var body = fatalCatch.Groups["body"].Value;

        body.Should().Contain("Log.Fatal", "the failure must still be logged");
        Regex.IsMatch(body, @"return\s+[1-9]\d*\s*;").Should().BeTrue(
            "and it must leave a non-zero exit code, or every caller reads the failure as success");
    }

    [Fact]
    public void SuccessPathsStillReturnZero()
    {
        // NEGATIVE HALF #1: a guard that only demanded "return non-zero" would be satisfied by a
        // program that always fails. The success paths must keep saying success, or the installer
        // would treat every good migrate as broken - the same defect with the sign flipped.
        var program = ProgramSource();

        program.Should().Contain("return 0;",
            "the migrate-only path and the normal shutdown must report success");
        Regex.Matches(program, @"return\s+0\s*;").Count.Should().BeGreaterThanOrEqualTo(2,
            "both the migrate-only exit and the end of the web host lifetime are success paths");
    }

    [Fact]
    public void Guard_canGoRed_onThePreFixShape()
    {
        // NEGATIVE HALF #2: the needle must fail on the code as it stood before this unit.
        const string beforeTheFix = """
            catch (Exception ex) when (ex is not HostAbortedException)
            {
                Log.Fatal(ex, "Application terminated unexpectedly");
            }
            """;
        var fatalCatch = Regex.Match(beforeTheFix,
            @"catch \(Exception ex\) when \(ex is not HostAbortedException\)\s*\{(?<body>[\s\S]*?)\n\}");
        fatalCatch.Success.Should().BeTrue("the detector must recognise the old shape at all");
        Regex.IsMatch(fatalCatch.Groups["body"].Value, @"return\s+[1-9]\d*\s*;").Should().BeFalse(
            "so the first test would have reported it - that is the red this guard can produce");
    }

    private static string ProgramSource()
    {
        var path = Path.Combine(RepoRoot(), "src", "CcDashboard.Web", "Program.cs");
        File.Exists(path).Should().BeTrue("Program.cs must exist");
        return File.ReadAllText(path);
    }

    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "CcDashboard.Web")))
            dir = dir.Parent;

        dir.Should().NotBeNull("the repository root must be locatable from the test output directory");
        return dir!.FullName;
    }
}
