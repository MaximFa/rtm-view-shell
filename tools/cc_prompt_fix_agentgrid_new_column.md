# Task: Reload RTM metrics after saving new AgentGrid columns

## Problem

When a user adds a new column to AgentGrid and saves, the Shell inserts the
column into `RTSUserGrid_Column` via `SaveAgentGridRtsCommand`. However,
RTM Service loaded its `_userGridMetrics` at startup and has no knowledge of
the new column. `updateUserGrid` does not include the new field → widget shows `-`.

RTM Service has an existing endpoint: `GET /LoadData` → triggers full reload
of all configuration including `RTSUserGrid_Column`.

## Fix — ScreenEditorPage.razor

After `SaveAgentGridRtsCommand` succeeds, call RTM Service's `/LoadData`
using the tenant's `SignalRConnectionUrl` as base URL.

### Step 1 — find where SaveAgentGridRts is called

Find the block:
```csharp
var rtsResult = await Mediator.Send(new SaveAgentGridRtsCommand(
```

### Step 2 — add RTM reload after successful save

After the `SaveAgentGridRtsCommand` call, add:

```csharp
// Notify RTM Service to reload metrics so new columns are included in updateUserGrid
_ = NotifyRtmLoadDataAsync();
```

### Step 3 — add the helper method to ScreenEditorPage

```csharp
private async Task NotifyRtmLoadDataAsync()
{
    try
    {
        var tenantId = CurrentUser.TenantId;
        if (tenantId == null) return;

        var settings = await Mediator.Send(new GetTenantSettingsQuery(tenantId.Value));
        if (string.IsNullOrEmpty(settings?.SignalRConnectionUrl)) return;

        // Build base URL from SignalR URL (strip /signalr suffix if present)
        var baseUrl = settings.SignalRConnectionUrl.TrimEnd('/');
        if (baseUrl.EndsWith("/signalr", StringComparison.OrdinalIgnoreCase))
            baseUrl = baseUrl[..^8];

        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
        await http.GetAsync($"{baseUrl}/LoadData");
        Logger.LogInformation("ScreenEditorPage: RTM LoadData triggered after column save");
    }
    catch (Exception ex)
    {
        Logger.LogWarning(ex, "ScreenEditorPage: RTM LoadData notification failed (non-critical)");
    }
}
```

**Notes:**
- `GetTenantSettingsQuery` — verify the exact query name used elsewhere in the page
  to get tenant settings. Use the same pattern already in the page.
- `CurrentUser` — verify the property name for the current user/tenant context.
- The call is fire-and-forget (`_ = ...`) — failure is non-critical, logged as Warning.
- `HttpClient` is created locally (not DI-injected) to avoid lifetime issues
  in a scoped Blazor component; timeout is short (5s).

## Also trigger for QueueGrid column changes

If there is a similar `SaveQueueGridRtsCommand` call in the same file,
add `_ = NotifyRtmLoadDataAsync()` after it as well.

## Verification

```bash
dotnet build src/CcDashboard.Web --no-restore
```

After deploy: add a new column to AgentGrid → save → new column should
receive data on the next RTM push without requiring RTM Service restart.

## Git push
Do NOT run `git push` automatically. Commit only.

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```

## Commit message

```
fix: trigger RTM /LoadData after saving new AgentGrid/QueueGrid columns

New columns saved to RTSUserGrid_Column were not included in updateUserGrid
because RTM Service loaded _userGridMetrics at startup. After save, call
GET /LoadData on RTM Service (fire-and-forget) to reload column definitions.
```
