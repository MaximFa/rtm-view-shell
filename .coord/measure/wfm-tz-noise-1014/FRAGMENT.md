# mixed TimeZones Warning: once an hour per queue, or when the dominant zone changes

Target file (v4): `src/CcDashboard.Infrastructure/Wfm/WfmInputQueryService.cs`, inside
`GetOrRefreshTzMapAsync`. Plus one new file and one registration line. Snapped 2026-10-14T08:51:26Z.
Read from the v4 branch; line numbers are v4's.

## The measured cause is not "it logs too often"

devops counted 1260 lines in 30 minutes = **42 per minute**. That number is not arbitrary:
21 queues x 2 ticks per minute = 42. One line per queue **per tick**, every tick.

The warning sits behind a cache that is supposed to refresh every 5 minutes
(`_tzCache`, TTL `TzCacheTtl = 5 min`), so at worst it should speak 21 times per 5 minutes. It does
not, because **the cache never survives a tick**:

- `services.AddScoped<IWfmInputQueryService, WfmInputQueryService>()` —
  `InfrastructureServiceExtensions.cs:186`;
- `WfmRealtimeLoop` creates a new scope on every tick — `WfmRealtimeLoop.cs:74`,
  `using var scope = scopeFactory.CreateScope();`.

A new scope means a new service instance, which means `_tzCache` — and `_buAgentPoolCache` next to
it — start **empty every 30 seconds**. Both TTL caches in that class are dead weight: the timezone
map and the BU agent pools are re-queried on every tick, and the warning fires on every re-query.

So "warn at most once an hour per queue" **cannot be implemented inside that service**: there is
nowhere to keep the last-logged time. That is why this fragment adds a singleton gate instead of a
field, and why the fix is cheaper than it looks — it also removes a per-tick re-query that nobody
asked for.

## New file: `src/CcDashboard.Infrastructure/Wfm/WfmLogGate.cs`

Delivered as `WfmLogGate.cs` in this folder. `ShouldLog(key, context, interval)` returns true when
the key has not been logged within the interval **or** when the context differs from the last logged
one — so a changed dominant zone is news again immediately, which is the second half of the
coordinator's ask. It takes the project's own `IDateTimeProvider` — already a registered singleton
(`InfrastructureServiceExtensions.cs:32`) — so tests move the clock instead of sleeping.
`TimeProvider`/`FakeTimeProvider` would be the modern choice, but
`Microsoft.Extensions.TimeProvider.Testing` is **not referenced anywhere in this solution**
(measured: no hit in any test project or csproj), and pulling in a package is not part of a
log-noise fix.

## Registration

`src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs`, beside line 186:

```csharp
        // Singleton on purpose: the Wfm services are Scoped and the loop makes a new scope per tick,
        // so any per-tick state (including rate limiting) has to live outside them.
        services.AddSingleton<IWfmLogGate, WfmLogGate>();
```

No other registration is needed: `IDateTimeProvider` is already a singleton at
`InfrastructureServiceExtensions.cs:32`. (I cannot run the build here — no `dotnet` in this
environment — so this is read from the registration line, not from a compile.)

## BEFORE (`WfmInputQueryService.cs:519-527`)

```csharp
            var dominant = wgGroup.OrderByDescending(x => x.Count).First();
            map[wgGroup.Key] = dominant.TimeZone ?? string.Empty;

            // Warn if mixed TZ within workgroup
            if (wgGroup.Count() > 1)
            {
                logger.LogWarning("WfmInputQueryService: workgroup {Workgroup} has mixed TimeZones, using dominant {Tz}",
                    wgGroup.Key, dominant.TimeZone);
            }
```

## AFTER

```csharp
            var dominant = wgGroup.OrderByDescending(x => x.Count).First();
            map[wgGroup.Key] = dominant.TimeZone ?? string.Empty;

            // Mixed zones inside one workgroup is a configuration fact, not an event: it stays true
            // until somebody fixes the data, so repeating it every tick buries the rest of the log
            // (measured: 42 lines/min, 1260 in 30 min, more than half the log). Once an hour per
            // queue is enough to keep it visible; a CHANGED dominant zone speaks immediately,
            // because that is new information and the one case worth interrupting for.
            if (wgGroup.Count() > 1 &&
                logGate.ShouldLog($"wfm-mixed-tz:{tenantId}:{wgGroup.Key}", dominant.TimeZone, TimeSpan.FromHours(1)))
            {
                logger.LogWarning(
                    "WfmInputQueryService: workgroup {Workgroup} has mixed TimeZones ({ZoneCount} distinct), using dominant {Tz}. "
                  + "Repeats of this line are suppressed for an hour unless the dominant zone changes.",
                    wgGroup.Key, wgGroup.Count(), dominant.TimeZone);
            }
```

Two things the new line says that the old one did not: how many distinct zones there are (one is
"mixed with what?", and the count answers it without a second query), and that the line is throttled
— otherwise the next reader will conclude the condition went away when it merely went quiet.

The gate key includes `tenantId`, because the service is per-tenant per tick while the gate is
process-wide; without it one tenant's warning would silence another's.

Constructor gains `IWfmLogGate logGate` alongside `beFactory` and `logger` in the primary
constructor at `WfmInputQueryService.cs:14-16`.

## Named, NOT fixed here

Both TTL caches in `WfmInputQueryService` (`_tzCache`, `_buAgentPoolCache`) are inert for the same
reason — Scoped service, new scope per tick. The timezone map and the BU agent pools are re-queried
every 30 seconds although their code says every 5 minutes. The pools go away with source (A) anyway;
the timezone map does not, and making it actually cache is a separate decision about lifetime, not
part of a log-noise fix. Named for the registry, not touched in this leg.

## Tests, both halves

In `WfmLogGateTests.cs` (this folder), 5 `[Fact]`, with a hand-moved clock:

1. first call for a key → true; immediate second call with the same context → false;
2. clock advanced past the interval → true again (**negative half** of 1: without this a gate that
   always returns false would pass the test above);
3. same key, **changed** context within the interval → true immediately;
4. two different keys do not silence each other — covers the tenant-prefixed key.
5. a null dominant zone neither throws nor counts as a real zone — the caller's value is nullable,
   and confusing null with a zone would make the gate speak or stay silent for the wrong reason.

## Blobs

- \`WfmLogGate.cs\` — \`90534723100551ba0ac36d82678c7acca2c084ed\`, 2936 B
- \`WfmLogGateTests.cs\` — \`b481edfd74b5cab62a86bcca5d191eef53dc9c14\`, 4359 B, 5 \`[Fact]\`, CR 0
- Target paths: \`src/CcDashboard.Infrastructure/Wfm/WfmLogGate.cs\`,
  \`tests/CcDashboard.Tests.Unit/Wfm/WfmLogGateTests.cs\`
