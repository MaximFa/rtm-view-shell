using CcDashboard.Infrastructure.Services;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using NSubstitute;
using Xunit;

namespace CcDashboard.Tests.Unit.HistoricalReports;

/// <summary>
/// BL-234-INTERACTION-TIME-AHEAD-01: the report/day-trend handlers convert to the display zone ONLY when IDisplayTimeZone
/// is registered (otherwise they fall back to UTC, which after the engine fix shows times 2-3 h early). So the
/// registration itself is part of the fix and is pinned here, together with how the zone is chosen.
/// </summary>
public class DisplayTimeZoneRegistrationTests
{
    private static string RepoFile(string relative)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "CcDashboard.sln"))) dir = dir.Parent;
        dir.Should().NotBeNull("the test must find the repository root (CcDashboard.sln)");
        return Path.Combine(dir!.FullName, relative.Replace('/', Path.DirectorySeparatorChar));
    }

    private static IConfiguration Config(string? zoneId)
    {
        var c = Substitute.For<IConfiguration>();
        c["Display:TimeZoneId"].Returns(zoneId);
        return c;
    }

    [Fact]
    public void Registration_IsInTheInfrastructureSetup_ExactlyOnce()
    {
        var src = File.ReadAllText(RepoFile("src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs"));
        src.Split("services.AddSingleton<IDisplayTimeZone, DisplayTimeZone>();").Length.Should().Be(2,
            "without this line every report and the day trend show UTC (the file at f697917 did not have it)");
    }

    [Fact]
    public void NoSetting_UsesTheServerZone()
    {
        new DisplayTimeZone(Config(null), NullLogger<DisplayTimeZone>.Instance).Zone.Should().Be(TimeZoneInfo.Local);
        new DisplayTimeZone(Config("  "), NullLogger<DisplayTimeZone>.Instance).Zone.Should().Be(TimeZoneInfo.Local);
    }

    [Fact]
    public void KnownSetting_IsUsed_AndFollowsDst()
    {
        string? id = null;
        foreach (var candidate in new[] { "Israel Standard Time", "Asia/Jerusalem" })
        {
            try { TimeZoneInfo.FindSystemTimeZoneById(candidate); id = candidate; break; } catch (TimeZoneNotFoundException) { }
        }
        id.Should().NotBeNull("an Israel zone id must exist on the build machine");

        var zone = new DisplayTimeZone(Config(id), NullLogger<DisplayTimeZone>.Instance).Zone;
        zone.SupportsDaylightSavingTime.Should().BeTrue();
        zone.GetUtcOffset(new DateTime(2026, 7, 15, 10, 0, 0, DateTimeKind.Utc)).Should().Be(TimeSpan.FromHours(3));
        zone.GetUtcOffset(new DateTime(2026, 1, 15, 10, 0, 0, DateTimeKind.Utc)).Should().Be(TimeSpan.FromHours(2));
    }

    [Fact]
    public void UnknownSetting_FallsBackToTheServerZone_AndSaysSo()
    {
        var logger = new CapturingLogger();
        new DisplayTimeZone(Config("No/Such_Zone"), logger).Zone.Should().Be(TimeZoneInfo.Local);
        logger.Levels.Should().Contain(LogLevel.Warning, "a wrong setting must be visible in the log, not silently ignored");

        var quiet = new CapturingLogger();
        new DisplayTimeZone(Config(null), quiet);
        quiet.Levels.Should().NotContain(LogLevel.Warning, "negative half: no setting is not a warning");
    }

    private sealed class CapturingLogger : ILogger<DisplayTimeZone>
    {
        public readonly List<LogLevel> Levels = new();
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
        public bool IsEnabled(LogLevel logLevel) => true;
        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
            => Levels.Add(logLevel);
    }
}
