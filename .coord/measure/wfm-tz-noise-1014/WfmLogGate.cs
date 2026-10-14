using System.Collections.Concurrent;
using CcDashboard.Domain.Interfaces;

namespace CcDashboard.Infrastructure.Wfm;

/// <summary>
/// Per-key rate gate for repeating Wfm log lines, registered as a SINGLETON.
///
/// Why a separate component instead of a field on the service: WfmInputQueryService is registered
/// AddScoped (InfrastructureServiceExtensions.cs:186) and WfmRealtimeLoop creates a fresh scope on
/// every tick (WfmRealtimeLoop.cs:74). A new instance per tick means any state kept in its fields -
/// including its two existing TTL caches - starts empty every 30 seconds, so "warn at most once an
/// hour" cannot be expressed there at all. The gate therefore has to outlive the scope.
///
/// This also explains the measured noise exactly: 21 queues x 2 ticks per minute = 42 lines/min,
/// which is the figure devops reported (1260 lines in 30 minutes).
///
/// Time comes from IDateTimeProvider - the project's own abstraction, already registered as a
/// singleton (InfrastructureServiceExtensions.cs:32). TimeProvider/FakeTimeProvider would have been
/// the modern choice, but Microsoft.Extensions.TimeProvider.Testing is NOT referenced anywhere in
/// this solution (measured), and introducing a package is not part of a log-noise fix.
/// </summary>
public interface IWfmLogGate
{
    /// <summary>
    /// True when this key has not been logged within <paramref name="interval"/>, or when
    /// <paramref name="context"/> differs from the last logged one (a changed situation is news
    /// again, however recently the previous line was written). Records the decision when it returns
    /// true.
    /// </summary>
    bool ShouldLog(string key, string? context, TimeSpan interval);
}

public sealed class WfmLogGate(IDateTimeProvider clock) : IWfmLogGate
{
    private readonly ConcurrentDictionary<string, (DateTime At, string? Context)> _last = new();

    public bool ShouldLog(string key, string? context, TimeSpan interval)
    {
        var now = clock.UtcNow;

        // AddOrUpdate keeps the decision and the write atomic: two tenants' ticks can run
        // concurrently, and a race here would either double-log or swallow a line.
        var allowed = false;

        _last.AddOrUpdate(
            key,
            _ =>
            {
                allowed = true;                      // never seen -> log
                return (now, context);
            },
            (_, prev) =>
            {
                var contextChanged = !string.Equals(prev.Context, context, StringComparison.Ordinal);
                var expired = now - prev.At >= interval;

                if (contextChanged || expired)
                {
                    allowed = true;
                    return (now, context);
                }

                allowed = false;
                return prev;                          // keep the earlier timestamp
            });

        return allowed;
    }
}
