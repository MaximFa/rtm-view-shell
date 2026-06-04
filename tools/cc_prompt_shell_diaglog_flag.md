# Task: Add hot-reloadable DiagPushLogging flag to Shell RtmRelayService

## Purpose

Allow enabling/disabling RECV diagnostic logs at runtime by changing
`appsettings.json` without restart.

## Approach — two options, implement Option A

**Option A (recommended):** dedicated `DiagPushLogging` flag read via
`IOptionsMonitor<RtmRelayOptions>` (hot-reload built-in).

**Option B (simpler but less granular):** ASP.NET Core log level override —
change `Logging:LogLevel:CcDashboard.Infrastructure.RtmRelay.RtmRelayService`
between `Information` and `Warning` in `appsettings.json`.

## Change 1 — new options class

Create `src/CcDashboard.Infrastructure/RtmRelay/RtmRelayOptions.cs`:
```csharp
namespace CcDashboard.Infrastructure.RtmRelay;

public class RtmRelayOptions
{
    public const string Section = "RtmRelay";
    public bool DiagPushLogging { get; set; } = false;
}
```

## Change 2 — appsettings.json (CcDashboard.Web)

Add to `src/CcDashboard.Web/appsettings.json`:
```json
"RtmRelay": {
  "DiagPushLogging": false
}
```

## Change 3 — Program.cs

Add in DI registration:
```csharp
builder.Services.Configure<RtmRelayOptions>(
    builder.Configuration.GetSection(RtmRelayOptions.Section));
```

## Change 4 — RtmRelayService.cs

Inject `IOptionsMonitor<RtmRelayOptions> options` in constructor.
Store as `private readonly IOptionsMonitor<RtmRelayOptions> _options;`

In `HandleGridUpdateAsync`, replace the existing LogInformation:
```csharp
if (_options.CurrentValue.DiagPushLogging)
{
    var cellLog = string.Join(", ", updates.Select(u => $"Cell{u.CellId}={u.Value}"));
    _logger.LogInformation(
        "RECV updateGridData grid {GridId}: {Count} cells [{Cells}], {HandlerCount} handlers",
        key.GridId, updates.Count, cellLog, handlers.Count);
}
```

In `HandleUpdateAsync`, replace the existing LogDebug:
```csharp
if (_options.CurrentValue.DiagPushLogging)
{
    var agentLog = string.Join(" | ", upserted.Select(a =>
    {
        var state = a.Fields.TryGetValue("MonAgentState", out var sv) ? sv.Raw : "(no state field)";
        var fieldNames = string.Join(",", a.Fields.Keys.Take(8));
        return $"{a.LoginName}=>state={state} fields=[{fieldNames}]";
    }));
    _logger.LogInformation(
        "RECV updateUserGrid union {UnionId}: {Count} agents [{Agents}]",
        key.UnionId, upserted.Count, agentLog);
}
```

## Usage

Enable: set `"DiagPushLogging": true` in `appsettings.json` → takes effect
immediately (IOptionsMonitor hot-reload, no restart needed).
Disable: set `false`.

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore
grep -n "DiagPushLogging\|CurrentValue" src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
```

## Commit message

```
diag: hot-reloadable DiagPushLogging flag in Shell RtmRelay appsettings

Set RtmRelay:DiagPushLogging=true in appsettings.json to enable RECV logs
without restart (IOptionsMonitor). Default false.
```

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```
