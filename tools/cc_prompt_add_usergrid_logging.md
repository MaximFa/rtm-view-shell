# Task: Add diagnostic logging for updateUserGrid payload in RtmRelayService

## Purpose

During production testing we see `&nbsp;` in agent STATE column.
We need to verify exactly what field names and values RTM Service sends
in `updateUserGrid` payload for each agent. Currently `HandleUpdateAsync`
only logs the count of upserted agents, not the actual field values.

## Change

In `src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs`,
in method `HandleUpdateAsync`, add Information-level logging of the
raw payload for the first received message (controlled by a flag).

Find this section (around line 310):
```csharp
private async Task HandleUpdateAsync(UnionState state, (Guid TenantId, int UnionId) key, JToken res)
{
    if (res is not JObject resObj) return;
    if (resObj["Data"] is not JArray dataArray) return;
```

Add after the null checks:
```csharp
    // Diagnostic: log first payload to reveal RTM field names and values
    if (!state.HasLoggedUpdatePayload)
    {
        state.HasLoggedUpdatePayload = true;
        _logger.LogInformation(
            "RtmRelayService: updateUserGrid FIRST PAYLOAD tenant {TenantId} union {UnionId} — raw: {Raw}",
            key.TenantId, key.UnionId, res.ToString(Newtonsoft.Json.Formatting.None));
    }
    else
    {
        // Log field names + state-related values on every update (compact)
        foreach (var item in dataArray)
        {
            if (item is not JObject obj) continue;
            var login = obj["AgentLoginName"]?.Value<string>() ?? "?";
            var stateVal = obj["MonAgentState"]?.ToString()
                        ?? obj["AgentState"]?.ToString()
                        ?? obj["StatusName"]?.ToString()
                        ?? "(field not found)";
            _logger.LogInformation(
                "RtmRelayService: updateUserGrid agent={Login} MonAgentState={State}",
                login, stateVal);
        }
    }
```

Add the flag to `UnionState` private class (find it in the same file):
```csharp
public bool HasLoggedUpdatePayload { get; set; }
```

(`HasLoggedRemovePayload` already exists there — add next to it.)

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore
```

After deploy: grep Shell logs for `updateUserGrid FIRST PAYLOAD` to see
exact field names and values, and `updateUserGrid agent=` for per-agent state.

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```

## Commit message

```
diag: log updateUserGrid raw payload and per-agent state in RtmRelayService

Temporary diagnostic logging to identify field names/values sent by RTM Service.
First message: full raw JSON. Subsequent: agent login + MonAgentState value.
Remove after root cause of &nbsp; state issue is confirmed.
```
