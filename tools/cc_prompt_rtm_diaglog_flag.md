# Task: Add hot-reloadable DiagPushLogging flag to RTM Service

## Purpose

Allow enabling/disabling push diagnostic logs (PUSH updateGridData,
PUSH updateUserGrid) at runtime by changing `appsettings.json` without restart.

## Change 1 — RTM/RTM/appsettings.json

Add to the `RTM` section:
```json
"RTM": {
  "TenantId": "...",
  "DiagPushLogging": false
}
```

## Change 2 — RTM/RTM.Configuration/AppConfig.cs

Add property and wire it to IConfiguration (already used for other fields):
```csharp
public static bool DiagPushLogging { get; private set; }
```

In `Initialize()`, add:
```csharp
DiagPushLogging = configuration.GetValue<bool>("RTM:DiagPushLogging", false);
```

BUT for hot-reload, AppConfig.Initialize is called only once at startup.
Instead, inject `IConfiguration` into `RTMAdapter` and read on each push:

In `RTMAdapter.cs`, store a reference to `IConfiguration` (it's already
injected via DI — check constructor). Then in `Rtm_GridEvent` and
`Rtm_UserGridEvent`:

```csharp
private void Rtm_GridEvent(object sender, GridEventArgs e)
{
    if (_configuration.GetValue<bool>("RTM:DiagPushLogging", false))
    {
        try
        {
            var cells = e.CellsValuesData;
            var cellLog = cells != null
                ? string.Join(", ", cells.Select(c => $"Cell{c.CellId}={c.Value}"))
                : "null";
            AsyncLogger.Info($"PUSH updateGridData GridId={e.GridId} cells=[{cellLog}]");
        }
        catch { }
    }
    _rtmHub.Clients.Group(e.GridId.ToString()).SendAsync("updateGridData", e.CellsValuesData);
}

private void Rtm_UserGridEvent(object sender, UserGridEventArgs e)
{
    var unionRes = _engine.getUsers(e.UnionId, false);
    if (unionRes != null)
    {
        if (_configuration.GetValue<bool>("RTM:DiagPushLogging", false))
        {
            try
            {
                var agentLog = unionRes.Data != null
                    ? string.Join(" | ", unionRes.Data.Select(d =>
                    {
                        var login = d.ContainsKey("AgentLoginName") ? d["AgentLoginName"] : "?";
                        var state = d.ContainsKey("MonAgentState") ? d["MonAgentState"] : "(no state field)";
                        return $"{login}=>{state}";
                    }))
                    : "null";
                AsyncLogger.Info($"PUSH updateUserGrid UnionId={e.UnionId} count={unionRes.Count} agents=[{agentLog}]");
            }
            catch { }
        }
        _rtmHub.Clients.Group("u" + e.UnionId).SendAsync("updateUserGrid", DateTime.Now, e.UnionId, unionRes);
    }
}
```

Check how `IConfiguration` is available in `RTMAdapter` — if not injected,
inject via constructor alongside other dependencies.

## Usage

Enable: set `"DiagPushLogging": true` in `appsettings.json` → takes effect immediately.
Disable: set `false` → no log overhead on production.

## Commit message

```
diag: hot-reloadable DiagPushLogging flag in RTM Service appsettings

Set RTM:DiagPushLogging=true in appsettings.json to enable PUSH logs
without restart. Default false (no log overhead in production).
```

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```
