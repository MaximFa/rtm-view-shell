using System.Text.RegularExpressions;
using FluentAssertions;

namespace CcDashboard.Tests.Architecture;

/// <summary>
/// PR234-V4-REPORT-WIDGET-INTERMITTENT-FAIL-01: the widgets of a report page run together on one Blazor circuit, where the
/// scoped AppDbContext is ONE instance. A read of HistoricalReportRepository on that shared context let two widgets meet in
/// it - "A second operation was started on this context instance" (journal 234, 2026-11-09: 3 cases, all in
/// GetWatermarkAsync). Every read (Get*) must open its own context from the factory; the shared `db` is for the
/// aggregator's writes only. Measured on the source, method by method.
/// </summary>
public class ReportReadsOwnContextGuardTests
{
    private static readonly Regex Method = new(@"public async Task(<[^\n]*?>)?\s+(?<name>\w+)\(", RegexOptions.Compiled);   // Task and Task<T> both end a body
    private static readonly Regex SharedContext = new(@"(?<![\w.])db\.", RegexOptions.Compiled);

    /// <summary>The Get* methods whose body touches the shared `db`.</summary>
    internal static List<string> ReadsOnTheSharedContext(string source)
    {
        var found = Method.Matches(source).ToList();
        var offenders = new List<string>();
        for (var i = 0; i < found.Count; i++)
        {
            var name = found[i].Groups["name"].Value;
            var end = i + 1 < found.Count ? found[i + 1].Index : source.Length;
            var body = source[found[i].Index..end];
            if (name.StartsWith("Get", StringComparison.Ordinal) && SharedContext.IsMatch(body))
                offenders.Add(name);
        }
        return offenders;
    }

    [Fact]
    public void EveryReadOfTheHistoricalReportRepository_OpensItsOwnContext()
    {
        var source = File.ReadAllText(Path.Combine(RepoRoot(), "src", "CcDashboard.Infrastructure", "Persistence", "Repositories", "HistoricalReportRepository.cs"));
        Method.Matches(source).Select(m => m.Groups["name"].Value).Should().Contain("GetWatermarkAsync", "the guard must see the methods, or it watches nothing");
        ReadsOnTheSharedContext(source).Should().BeEmpty();
    }

    [Fact]
    public void NEGATIVE_aReadOnTheSharedContext_IsCaught_AWriteIsNot()
    {
        const string source = """
            public async Task<HistAggregationWatermark?> GetWatermarkAsync(Guid tenantId, CancellationToken ct)
            {
                return await db.HistAggregationWatermarks.AsNoTracking().FirstOrDefaultAsync(x => x.TenantId == tenantId, ct);
            }
            public async Task<int> InsertAsync(CancellationToken ct)
            {
                return await db.SaveChangesAsync(ct);
            }
            public async Task<int> GetOkAsync(CancellationToken ct)
            {
                await using var ctx = await dbFactory.CreateDbContextAsync(ct);
                return await ctx.Things.CountAsync(ct);
            }
            """;
        ReadsOnTheSharedContext(source).Should().Equal("GetWatermarkAsync");
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
