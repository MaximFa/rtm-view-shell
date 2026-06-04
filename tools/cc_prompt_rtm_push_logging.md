# Task: Add push logging to RTM Service (RTMAdapter.cs)

## Purpose

We need to see exactly what RTM Service pushes on every `updateGridData`
and `updateUserGrid` event — cell IDs/values for grids, field values for agents.

## File: RTM/RTM/RTMAdapter.cs

### Change 1 — updateGridData (around line 495)

Replace:
```csharp
private void Rtm_GridEvent(object sender, GridEventArgs e)
{
    //AsyncLogger.Info("updateGridData GridId=" + e.GridId);
    _rtmHub.Clients.Group(e.GridId.ToString()).SendAsync("updateGridData", e.CellsValuesData);
}
```

With:
```csharp
private void Rtm_GridEvent(object sender, GridEventArgs e)
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
    _rtmHub.Clients.Group(e.GridId.ToString()).SendAsync("updateGridData", e.CellsValuesData);
}
```

Note: `CellsValuesData` is `IEnumerable<CellData>`. Check the actual type in
`GridEventArgs.cs` and `CellData.cs` — use `.CellId` and `.Value` properties.
Adjust property names if different.

### Change 2 — updateUserGrid (around line 508)

Replace:
```csharp
private void Rtm_UserGridEvent(object sender, UserGridEventArgs e)
{
    var unionRes = _engine.getUsers(e.UnionId, false);

    if (unionRes != null)
    {
        //AsyncLogger.Info("updateUserGrid UnionId=" + e.UnionId);
        _rtmHub.Clients.Group("u" + e.UnionId).SendAsync("updateUserGrid", DateTime.Now, e.UnionId, unionRes);
    }
}
```

With:
```csharp
private void Rtm_UserGridEvent(object sender, UserGridEventArgs e)
{
    var unionRes = _engine.getUsers(e.UnionId, false);

    if (unionRes != null)
    {
        try
        {
            var agentLog = unionRes.Data != null
                ? string.Join(" | ", unionRes.Data.Select(d =>
                {
                    var login = d.ContainsKey("AgentLoginName") ? d["AgentLoginName"] : "?";
                    var state = d.ContainsKey("MonAgentState") ? d["MonAgentState"]
                              : d.ContainsKey("AgentState")    ? d["AgentState"]
                              : "(no state field)";
                    return $"{login}=>{state}";
                }))
                : "null";
            AsyncLogger.Info($"PUSH updateUserGrid UnionId={e.UnionId} count={unionRes.Count} agents=[{agentLog}]");
        }
        catch { }
        _rtmHub.Clients.Group("u" + e.UnionId).SendAsync("updateUserGrid", DateTime.Now, e.UnionId, unionRes);
    }
}
```

## Verification

```bash
dotnet build RTM/RTM --no-restore 2>/dev/null || echo "check build"
grep -n "PUSH updateGridData\|PUSH updateUserGrid" RTM/RTM/RTMAdapter.cs
```

## Commit message

```
diag: log every updateGridData and updateUserGrid push in RTMAdapter

Logs cell IDs/values for grid pushes and agent login+state for user grid pushes.
Search logs for "PUSH updateGridData" and "PUSH updateUserGrid".
Remove after root cause of &nbsp; state issue is confirmed.
```

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```
