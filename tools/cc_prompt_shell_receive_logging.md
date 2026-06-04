# Task: Add receive logging to Shell RtmRelayService

## Purpose

Log what Shell receives from RTM Service on every push — grid cell values
and agent field values — so we can compare with what RTM Service sent.

## File: src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs

### Change 1 — HandleGridUpdateAsync (around line 672)

Find the existing LogInformation call:
```csharp
_logger.LogInformation(
    "RtmRelayService: updateGridData grid {GridId}: {Count} cells, {HandlerCount} handlers",
    key.GridId, updates.Count, handlers.Count);
```

Replace with:
```csharp
var cellLog = string.Join(", ", updates.Select(u => $"Cell{u.CellId}={u.Value}"));
_logger.LogInformation(
    "RECV updateGridData grid {GridId}: {Count} cells [{Cells}], {HandlerCount} handlers",
    key.GridId, updates.Count, cellLog, handlers.Count);
```

### Change 2 — HandleUpdateAsync (around line 345)

Find the existing LogDebug call:
```csharp
_logger.LogDebug(
    "RtmRelayService: updateUserGrid tenant {TenantId} union {UnionId}, {Count} agents upserted",
    key.TenantId, key.UnionId, upserted.Count);
```

Replace with:
```csharp
var agentLog = string.Join(" | ", upserted.Select(a =>
{
    var state = a.Fields.TryGetValue("MonAgentState", out var sv) ? sv.Raw
              : a.Fields.TryGetValue("AgentState",    out var sv2) ? sv2.Raw
              : "(no state field)";
    var fieldNames = string.Join(",", a.Fields.Keys.Take(8));
    return $"{a.LoginName}=>state={state} fields=[{fieldNames}]";
}));
_logger.LogInformation(
    "RECV updateUserGrid union {UnionId}: {Count} agents [{Agents}]",
    key.UnionId, upserted.Count, agentLog);
```

Note: `AgentSnapshot` has `LoginName` and `Fields` (Dictionary<string, CellValue>).
`CellValue` has a `Raw` string property. Verify exact property names in
`src/CcDashboard.Domain/Domain/Rtm/AgentSnapshot.cs` and adjust if needed.

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore
grep -n "RECV updateGridData\|RECV updateUserGrid" src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
```

After deploy: search Shell logs for `RECV updateGridData` and `RECV updateUserGrid`.

## Commit message

```
diag: log every received updateGridData and updateUserGrid in RtmRelayService

Logs cell IDs/values for grid receives and agent login+state for user grid receives.
Search logs for "RECV updateGridData" and "RECV updateUserGrid".
Remove after root cause of &nbsp; state issue is confirmed.
```

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```
