---
name: rtm-relay-implementation
description: "CC-003: RTM Relay Infrastructure — single-port SignalR relay, key facts for widget integration"
type: impl
updated: 2026-05-31
---

## RTM Relay — delivered CC-003 (commit 0c3c902)

Shell acts as SignalR client to RTM Service. Browser opens only port 443.

### Key files

- `CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs` — Singleton, 677 lines
- `CcDashboard.Application/Interfaces/IRtmRelayService.cs` — interface
- `CcDashboard.Web/Hubs/RtmRelayHub.cs` — browser hub at `/hubs/rtm-relay`
- `CcDashboard.Domain/Domain/Rtm/` — CellValue, AgentSnapshot, UnionStateChange, GridCellUpdate

### Hub URL

`TenantSettings.SignalRConnectionUrl` — already existed in code, no migration.
Redis cache: `{tenantId}:rtm:hub_url` TTL 5 min.

### RTM Hub protocol (DO NOT CHANGE)

- `updateUserGrid`: `On<JsonElement, JsonElement, JsonElement>` — 3 params, только 3-й используется
- `removeUser`: `On<JsonElement, JsonElement>` — 2-й param = `[{"name":"loginName"}]`
- `updateGridData`: `On<JsonElement>` — массив `[{CellId, Value}]`
- DataGrid: `init` + `refreshCells` на коннект (только `init` не даёт данных)
- Типизированные параметры НЕЛЬЗЯ — молча дропают сообщения

### Widget integration pattern

```csharp
@inject IRtmRelayService RtmRelay

// OnInitializedAsync:
_handler = async change => await InvokeAsync(() => { ApplyChange(change); StateHasChanged(); });
await RtmRelay.SubscribeUnionAsync(TenantId, unionId, _handler, ct);

// DisposeAsync:
await RtmRelay.UnsubscribeUnionAsync(TenantId, unionId, _handler);
```

### Reference project

`D:\Temp\RTMView\RTMView\Services\Rtm\RtmHubService.cs` — отработанный референс
