using System.Data;
using System.Data.Common;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain;
using CcDashboard.Infrastructure.Metrics;
using CcDashboard.Infrastructure.Persistence;
using CcDashboard.Infrastructure.Persistence.Repositories;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace CcDashboard.Tests.Unit.Metrics;

/// <summary>
/// PR234-V4-ALL-COLUMNS-TEXT-AFTER-EFFCD27-01: widgets of one screen read the metric catalogue at the same
/// time inside one Blazor circuit. Through the circuit-scoped context the second read failed with
/// "A command is already in progress". "Context busy" is reproduced deterministically: the shared context runs the production relational
/// provider and another widget's query is parked at a barrier inside it (see ParkedRelationalContext).
/// </summary>
public class MetricCatalogueConcurrencyTests
{
    private static DbContextOptions<BackendEmulationDbContext> NewDb()
    {
        var opts = new DbContextOptionsBuilder<BackendEmulationDbContext>()
            .UseInMemoryDatabase($"MetricCatalogue_{Guid.NewGuid()}")
            .ConfigureWarnings(w => w.Ignore(InMemoryEventId.TransactionIgnoredWarning))
            .Options;
        using var db = new BackendEmulationDbContext(opts);
        db.RtsGridMetrics.AddRange(
            new RtsGridMetric { MetricId = "MonAgentState", DataType = "User", MetricFunction = "f", MetricParameter = "p", ValueType = "String" },
            new RtsGridMetric { MetricId = "MonAgentTalkDuration", DataType = "User", MetricFunction = "f", MetricParameter = "p", ValueType = "time" },
            new RtsGridMetric { MetricId = "QueueNumAnsweredCalls", DataType = "Interactions Summary", MetricFunction = "f", MetricParameter = "p", ValueType = "number" });
        db.SaveChanges();
        return opts;
    }

    private sealed class CountingFactory(DbContextOptions<BackendEmulationDbContext> options) : IDbContextFactory<BackendEmulationDbContext>
    {
        public int Created;
        public Exception? FailWith;
        public BackendEmulationDbContext CreateDbContext()
        {
            Interlocked.Increment(ref Created);
            if (FailWith is not null) throw FailWith;
            return new BackendEmulationDbContext(options);
        }
    }

    private sealed class ManualClock : TimeProvider
    {
        public DateTimeOffset Now = new(2026, 10, 18, 12, 0, 0, TimeSpan.Zero);
        public override DateTimeOffset GetUtcNow() => Now;
    }

    /// <summary>
    /// The circuit-scoped context as production configures it (Npgsql provider, so the RELATIONAL query pipeline
    /// with EF's concurrency detector), but with no server: opening is suppressed and every reader command is
    /// parked at a barrier and then answered with an empty reader. While a command is parked the context is
    /// GUARANTEED busy - no reliance on timing. (The first version of this test held the detector by hand on an
    /// InMemory context; the InMemory query pipeline does not consult the detector, so it never went red.)
    /// </summary>
    private sealed class ParkedRelationalContext : IAsyncDisposable
    {
        public readonly BackendEmulationDbContext Db;
        public readonly ParkingInterceptor Parking = new();

        public ParkedRelationalContext()
        {
            var opts = new DbContextOptionsBuilder<BackendEmulationDbContext>()
                .UseNpgsql("Host=interceptor.invalid;Database=none")
                .AddInterceptors(new SuppressOpenClose(), Parking)
                .Options;
            Db = new BackendEmulationDbContext(opts);
        }

        public ValueTask DisposeAsync()
        {
            Parking.Release();
            return Db.DisposeAsync();
        }
    }

    private sealed class SuppressOpenClose : DbConnectionInterceptor
    {
        public override InterceptionResult ConnectionOpening(DbConnection c, ConnectionEventData e, InterceptionResult r) => InterceptionResult.Suppress();
        public override ValueTask<InterceptionResult> ConnectionOpeningAsync(DbConnection c, ConnectionEventData e, InterceptionResult r, CancellationToken ct = default)
            => ValueTask.FromResult(InterceptionResult.Suppress());
        public override InterceptionResult ConnectionClosing(DbConnection c, ConnectionEventData e, InterceptionResult r) => InterceptionResult.Suppress();
        public override ValueTask<InterceptionResult> ConnectionClosingAsync(DbConnection c, ConnectionEventData e, InterceptionResult r)
            => ValueTask.FromResult(InterceptionResult.Suppress());
    }

    private sealed class ParkingInterceptor : DbCommandInterceptor
    {
        private readonly TaskCompletionSource _release = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public readonly TaskCompletionSource Entered = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public int Commands;

        public void Release() => _release.TrySetResult();

        public override async ValueTask<InterceptionResult<DbDataReader>> ReaderExecutingAsync(
            DbCommand command, CommandEventData eventData, InterceptionResult<DbDataReader> result, CancellationToken ct = default)
        {
            Interlocked.Increment(ref Commands);
            Entered.TrySetResult();
            await _release.Task.WaitAsync(TimeSpan.FromSeconds(30), ct);
            return InterceptionResult<DbDataReader>.SuppressWithResult(new DataTable().CreateDataReader());
        }

        public override InterceptionResult<DbDataReader> ReaderExecuting(DbCommand command, CommandEventData eventData, InterceptionResult<DbDataReader> result)
        {
            Interlocked.Increment(ref Commands);
            Entered.TrySetResult();
            _release.Task.Wait(TimeSpan.FromSeconds(30));
            return InterceptionResult<DbDataReader>.SuppressWithResult(new DataTable().CreateDataReader());
        }
    }

    [Fact]
    public async Task OldPath_SharedCircuitContext_FailsWhileAnotherWidgetQueryIsInFlight()
    {
        // Positive control: the same call on an IDLE shared context completes without exception.
        await using (var idle = new ParkedRelationalContext())
        {
            idle.Parking.Release();
            var idleRepo = new RtsGridMetricRepository(idle.Db);
            var act = () => idleRepo.GetAllWithTranslationAsync("en-US");
            await act.Should().NotThrowAsync("positive control: on an idle context the old path works");
            idle.Parking.Commands.Should().BeGreaterThan(0, "the query really went through the relational pipeline");
        }

        // Negative half: widget A's catalogue read is in flight (parked inside the command) on the circuit context;
        // widget B issues the same read on the SAME context. This is exactly the 234 defect.
        await using var busy = new ParkedRelationalContext();
        var repo = new RtsGridMetricRepository(busy.Db);
        var widgetA = Task.Run(() => repo.GetAllAsync());
        await busy.Parking.Entered.Task.WaitAsync(TimeSpan.FromSeconds(10)); // barrier: A is now inside its query

        var widgetB = () => repo.GetAllWithTranslationAsync("en-US");
        await widgetB.Should().ThrowAsync<InvalidOperationException>("a second operation on a busy shared context must fail - this is the 234 defect");

        busy.Parking.Release();
        await widgetA; // A itself completes normally once released
    }

    [Fact]
    public async Task Catalogue_Works_WhileTheCircuitContextIsBusy_AndUnderManyParallelCalls()
    {
        var opts = NewDb();
        var factory = new CountingFactory(opts);
        IMetricCatalogue catalogue = new MetricCatalogue(factory, NullLogger<MetricCatalogue>.Instance, new ManualClock());

        // The circuit context is genuinely busy for the whole test: another widget's query is parked inside it.
        await using var busy = new ParkedRelationalContext();
        var inFlight = Task.Run(() => new RtsGridMetricRepository(busy.Db).GetAllAsync());
        await busy.Parking.Entered.Task.WaitAsync(TimeSpan.FromSeconds(10));

        var results = await Task.WhenAll(Enumerable.Range(0, 50).Select(_ => Task.Run(() => catalogue.GetValueTypesAsync(CancellationToken.None))));
        results.Should().OnlyContain(r => r.Count == 3);
        inFlight.IsCompleted.Should().BeFalse("the shared context was still busy while the catalogue answered");

        busy.Parking.Release();
        await inFlight;

        factory.Created.Should().Be(1, "concurrent callers are collapsed into one database read");
        var types = await catalogue.GetValueTypesAsync(CancellationToken.None);
        types["monagentstate"].Should().Be("String", "keys are case-insensitive");
        types["MonAgentTalkDuration"].Should().Be("time", "value types are returned raw, not normalised");
    }

    [Fact]
    public async Task Catalogue_ThrowsOnReadFailure_ForEveryCaller_AndDoesNotCacheTheFailure()
    {
        var opts = NewDb();
        var factory = new CountingFactory(opts) { FailWith = new InvalidOperationException("db down") };
        var catalogue = new MetricCatalogue(factory, NullLogger<MetricCatalogue>.Instance, new ManualClock());

        var calls = Enumerable.Range(0, 5).Select(_ => Task.Run(() => catalogue.GetValueTypesAsync(CancellationToken.None))).ToArray();
        foreach (var call in calls)
        {
            Func<Task> awaitCall = () => call;
            await awaitCall.Should().ThrowAsync<InvalidOperationException>().WithMessage("db down");
        }

        factory.FailWith = null;
        (await catalogue.GetValueTypesAsync(CancellationToken.None)).Should().HaveCount(3, "a failure is never cached and never turned into an empty dictionary");
    }

    [Fact]
    public async Task Catalogue_ReReadsAfterTheTtl_SoEditedMetricsAreSeenWithoutRestart()
    {
        var opts = NewDb();
        var factory = new CountingFactory(opts);
        var clock = new ManualClock();
        var catalogue = new MetricCatalogue(factory, NullLogger<MetricCatalogue>.Instance, clock);

        await catalogue.GetValueTypesAsync(CancellationToken.None);
        clock.Now += MetricCatalogue.CacheTtl - TimeSpan.FromSeconds(1);
        await catalogue.GetValueTypesAsync(CancellationToken.None);
        factory.Created.Should().Be(1, "inside the TTL the cached catalogue is reused");

        await using (var db = new BackendEmulationDbContext(opts))
        {
            db.RtsGridMetrics.Add(new RtsGridMetric { MetricId = "QueueNew", DataType = "d", MetricFunction = "f", MetricParameter = "p", ValueType = "number" });
            await db.SaveChangesAsync();
        }
        clock.Now += TimeSpan.FromSeconds(1);
        (await catalogue.GetValueTypesAsync(CancellationToken.None)).Should().ContainKey("QueueNew");
        factory.Created.Should().Be(2);
    }

    [Fact]
    public void Catalogue_DoesNotDependOnTheCircuitScopedContext()
    {
        // Structural guard: the implementation must take a context FACTORY, never the scoped context itself.
        var ctorParams = typeof(MetricCatalogue).GetConstructors().Single().GetParameters().Select(p => p.ParameterType).ToList();
        ctorParams.Should().Contain(typeof(IDbContextFactory<BackendEmulationDbContext>));
        ctorParams.Should().NotContain(typeof(BackendEmulationDbContext));
        ctorParams.Should().NotContain(typeof(AppDbContext));
    }
}
