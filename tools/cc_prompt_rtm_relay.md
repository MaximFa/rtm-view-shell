# CC-003 — RTM Relay Infrastructure

**Sprint:** CC-003  
**Session name:** RTM — CC-003 RTM Relay  
**CLAUDE.md ref:** §34 (RTM Relay Architecture), §33 (RTM Multi-tenancy)  
**Reference project:** `D:\Temp\RTMView\RTMView\Services\Rtm\RtmHubService.cs`

---

## §0 — Session-resume integrity check (MANDATORY FIRST STEP)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git status --short
```

For every `M` file in the output: `tail -3 <path>` — check for truncation.  
Truncated → `git show HEAD:<path> > <path>`. Do NOT start work until tree is clean.

---

## Цель спринта

Реализовать relay-паттерн: Shell выступает SignalR-клиентом к RTM Service,
виджеты подключаются только к Shell (один порт 443). Детали в CLAUDE.md §34.

---

## Шаг 1 — NuGet package

```bash
dotnet add src/CcDashboard.Infrastructure package Microsoft.AspNetCore.SignalR.Client
```

Убедись что пакет добавлен в `CcDashboard.Infrastructure.csproj`.

---

## Шаг 2 — Domain models (RTM data types)

Создать папку `src/CcDashboard.Domain/Domain/Rtm/` и четыре файла.  
Референс: `D:\Temp\RTMView\RTMView\Models\Rtm\` — взять структуры напрямую,
адаптировав namespace на `CcDashboard.Domain.Domain.Rtm`.

### `CellValue.cs`
```csharp
namespace CcDashboard.Domain.Domain.Rtm;

/// <summary>
/// Raw string value from RTM Hub. May represent a number, a clock (epoch ms), or plain text.
/// </summary>
public readonly record struct CellValue(string Raw)
{
    public static CellValue Parse(string? s) => new(s ?? "");

    public bool IsClock => long.TryParse(Raw, out var ms) && ms > 1_000_000_000_000L;
    public long EpochMs => long.TryParse(Raw, out var ms) ? ms : 0L;

    public string ToDisplay(DateTimeOffset? serverNow, TimeSpan? serverOffset)
    {
        if (!IsClock) return Raw;
        var epoch = DateTimeOffset.FromUnixTimeMilliseconds(EpochMs);
        var elapsed = (serverNow ?? DateTimeOffset.UtcNow) - epoch;
        return elapsed.TotalSeconds < 0 ? "0:00"
             : elapsed.TotalHours >= 1  ? $"{(int)elapsed.TotalHours}:{elapsed.Minutes:D2}:{elapsed.Seconds:D2}"
             :                            $"{elapsed.Minutes}:{elapsed.Seconds:D2}";
    }

    public override string ToString() => Raw;
}
```

### `AgentSnapshot.cs`
```csharp
namespace CcDashboard.Domain.Domain.Rtm;

/// <summary>Immutable snapshot of one agent's metric fields at a point in time.</summary>
public sealed record AgentSnapshot(
    string AgentLoginName,
    IReadOnlyDictionary<string, CellValue> Fields,
    DateTime ReceivedAt);
```

### `UnionStateChange.cs`
```csharp
namespace CcDashboard.Domain.Domain.Rtm;

/// <summary>
/// Discriminated union for changes delivered to IRtmRelayService subscribers.
/// </summary>
public abstract record UnionStateChange
{
    /// <summary>Full snapshot delivered immediately on Subscribe.</summary>
    public sealed record InitialSnapshot(
        IReadOnlyDictionary<string, AgentSnapshot> Agents,
        TimeSpan ServerTimeOffset) : UnionStateChange;

    /// <summary>One or more agents were added or updated.</summary>
    public sealed record AgentsUpserted(
        IReadOnlyList<AgentSnapshot> Agents) : UnionStateChange;

    /// <summary>One or more agents were removed (logged out / disconnected).</summary>
    public sealed record AgentsRemoved(
        IReadOnlyList<string> AgentLoginNames) : UnionStateChange;
}
```

### `GridCellUpdate.cs`
```csharp
namespace CcDashboard.Domain.Domain.Rtm;

/// <summary>Single cell value update from RTM Hub updateGridData.</summary>
public sealed record GridCellUpdate(int CellId, string Value);
```

---

## Шаг 3 — Interface (Application layer)

Создать `src/CcDashboard.Application/Interfaces/IRtmRelayService.cs`:

```csharp
using CcDashboard.Domain.Domain.Rtm;

namespace CcDashboard.Application.Interfaces;

/// <summary>
/// Server-side relay between RTM Service SignalR Hub and Blazor widget components.
/// Registered as Singleton — one HubConnection per (TenantId, UnionId/GridId).
/// See CLAUDE.md §34.
/// </summary>
public interface IRtmRelayService
{
    // ── Per-union (AgentGrid) ────────────────────────────────────────────────
    Task SubscribeUnionAsync(Guid tenantId, int unionId,
        Func<UnionStateChange, Task> handler,
        CancellationToken ct = default);

    Task UnsubscribeUnionAsync(Guid tenantId, int unionId,
        Func<UnionStateChange, Task> handler);

    // ── Per-grid (DataGrid) ──────────────────────────────────────────────────
    Task SubscribeGridAsync(Guid tenantId, int gridId,
        Func<IReadOnlyList<GridCellUpdate>, Task> handler,
        CancellationToken ct = default);

    Task UnsubscribeGridAsync(Guid tenantId, int gridId,
        Func<IReadOnlyList<GridCellUpdate>, Task> handler);

    // ── Tenant lifecycle ─────────────────────────────────────────────────────
    /// <summary>
    /// Disconnect all active connections for a tenant (called on Suspend/Delete).
    /// </summary>
    Task DisconnectTenantAsync(Guid tenantId);
}
```

---

## Шаг 4 — RtmRelayService (Infrastructure)

Создать `src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs`.

**Базируйся на референсе:** прочитай `D:\Temp\RTMView\RTMView\Services\Rtm\RtmHubService.cs` —
это проверенная реализация. Адаптируй следующим образом:

### Ключевые отличия от референса:

**1. Составной ключ вместо int:**
```csharp
private readonly ConcurrentDictionary<(Guid TenantId, int UnionId), UnionState> _unions = new();
private readonly ConcurrentDictionary<(Guid TenantId, int GridId),  GridState>  _grids  = new();
```

**2. URL хаба из БД через IServiceScopeFactory (Singleton не может инжектировать Scoped):**
```csharp
private readonly IServiceScopeFactory _scopeFactory;
private readonly IConnectionMultiplexer _redis;

private async Task<string> GetHubUrlAsync(Guid tenantId, CancellationToken ct)
{
    // 1. Check Redis cache
    var db = _redis.GetDatabase();
    var cacheKey = $"{tenantId}:rtm:hub_url";
    var cached = await db.StringGetAsync(cacheKey);
    if (cached.HasValue) return cached.ToString();

    // 2. Load from DB
    await using var scope = _scopeFactory.CreateAsyncScope();
    var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    var url = await dbContext.TenantSettings
        .IgnoreQueryFilters()
        .Where(s => s.TenantId == tenantId)
        .Select(s => s.SignalRHubUrl)
        .FirstOrDefaultAsync(ct);

    if (string.IsNullOrEmpty(url))
        throw new InvalidOperationException(
            $"RTM Hub URL not configured for tenant {tenantId}. " +
            "Set SignalRHubUrl in Tenant Settings → SignalR Widgets.");

    // 3. Cache for 5 minutes
    await db.StringSetAsync(cacheKey, url, TimeSpan.FromMinutes(5));
    return url;
}
```

**3. `DisconnectTenantAsync` — разорвать все соединения тенанта:**
```csharp
public async Task DisconnectTenantAsync(Guid tenantId)
{
    var unionKeys = _unions.Keys.Where(k => k.TenantId == tenantId).ToList();
    foreach (var key in unionKeys)
    {
        if (_unions.TryRemove(key, out var state))
        {
            state.IsDisposing = true;
            if (state.Connection != null)
                await state.Connection.DisposeAsync();
        }
    }

    var gridKeys = _grids.Keys.Where(k => k.TenantId == tenantId).ToList();
    foreach (var key in gridKeys)
    {
        if (_grids.TryRemove(key, out var state))
        {
            state.IsDisposing = true;
            if (state.Connection != null)
                await state.Connection.DisposeAsync();
        }
    }

    _logger.LogInformation(
        "RtmRelayService: disconnected {UnionCount} unions and {GridCount} grids for tenant {TenantId}",
        unionKeys.Count, gridKeys.Count, tenantId);
}
```

**4. `BuildConnection` получает URL динамически:**
```csharp
// В SubscribeAsync — перед GetOrAdd:
var hubUrl = await GetHubUrlAsync(tenantId, ct);
// Передать hubUrl в BuildConnection(key, state, hubUrl)
```

**5. Namespace и using:**
```csharp
using CcDashboard.Domain.Domain.Rtm;
using CcDashboard.Application.Interfaces;
using CcDashboard.Infrastructure.Persistence;
// ...
namespace CcDashboard.Infrastructure.RtmRelay;
```

**Всё остальное** (UnionState, GridState, reconnect с backoff, grace timer,
HandleUpdateAsync, HandleRemoveAsync, HandleGridUpdateAsync, FanOutAsync) —
**берёшь из референса без изменений**, только меняешь namespace и ключи словарей.

### RTM Hub protocol (ВАЖНО — из референса, не менять):
- `updateUserGrid`: `On<JsonElement, JsonElement, JsonElement>` — 3 параметра JsonElement,
  первые два игнорируются, третий — payload. Нельзя использовать типизированные параметры,
  иначе сообщения молча дропаются.
- `removeUser`: `On<JsonElement, JsonElement>` — 2 параметра, второй = `[{"name":"loginName"}]`
- `updateGridData`: `On<JsonElement>` — один массив `[{CellId, Value}]`
- `init`: `InvokeAsync<string>("init", $"u{unionId}")` для union; `InvokeAsync<JsonElement>("init", gridId.ToString())` для grid
- `refreshCells`: только для grid, после init: `InvokeAsync<JsonElement>("refreshCells", gridId.ToString())`

---

## Шаг 5 — TenantSettings: добавить SignalRHubUrl

### `src/CcDashboard.Domain/Domain/TenantSettings.cs`
Добавить свойство:
```csharp
public string? SignalRHubUrl { get; set; }
```

### `src/CcDashboard.Infrastructure/Persistence/Configurations/TenantSettingsConfiguration.cs`
Добавить в `Configure`:
```csharp
builder.Property(e => e.SignalRHubUrl)
    .HasColumnName("signal_r_hub_url")
    .HasMaxLength(500);
```

### EF Migration
```bash
dotnet ef migrations add AddSignalRHubUrlToTenantSettings \
  --project src/CcDashboard.Infrastructure \
  --startup-project src/CcDashboard.Web
```

---

## Шаг 6 — RtmRelayHub (browser-facing)

Создать `src/CcDashboard.Web/Hubs/RtmRelayHub.cs`:

```csharp
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain.Rtm;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace CcDashboard.Web.Hubs;

/// <summary>
/// Browser-facing SignalR Hub. Relays RTM Service pushes to JS/external widget clients.
/// Blazor Server components should inject IRtmRelayService directly instead.
/// See CLAUDE.md §34.7.
/// </summary>
[Authorize]
public sealed class RtmRelayHub : Hub
{
    private readonly IRtmRelayService _relay;
    private readonly ILogger<RtmRelayHub> _logger;

    public RtmRelayHub(IRtmRelayService relay, ILogger<RtmRelayHub> logger)
    {
        _relay = relay;
        _logger = logger;
    }

    private Guid TenantId =>
        Guid.TryParse(Context.User?.FindFirst("tenant_id")?.Value, out var tid)
            ? tid
            : throw new HubException("tenant_id claim missing");

    /// <summary>Subscribe to agent grid updates for a union.</summary>
    public async Task SubscribeUnion(int unionId)
    {
        var tenantId = TenantId;
        Func<UnionStateChange, Task> handler = async change =>
        {
            try { await Clients.Caller.SendAsync("unionUpdate", change); }
            catch (Exception ex)
            {
                _logger.LogDebug(ex,
                    "RtmRelayHub: failed to send unionUpdate to caller (connection may be closed)");
            }
        };

        StoreHandler($"union:{unionId}", tenantId, unionId, 0, handler, null);
        await _relay.SubscribeUnionAsync(tenantId, unionId, handler);
    }

    /// <summary>Subscribe to data grid cell updates.</summary>
    public async Task SubscribeGrid(int gridId)
    {
        var tenantId = TenantId;
        Func<IReadOnlyList<GridCellUpdate>, Task> handler = async updates =>
        {
            try { await Clients.Caller.SendAsync("gridUpdate", updates); }
            catch (Exception ex)
            {
                _logger.LogDebug(ex,
                    "RtmRelayHub: failed to send gridUpdate to caller (connection may be closed)");
            }
        };

        StoreHandler($"grid:{gridId}", tenantId, 0, gridId, null, handler);
        await _relay.SubscribeGridAsync(tenantId, gridId, handler);
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        foreach (var key in Context.Items.Keys.ToList())
        {
            if (Context.Items[key] is not HubSubscription sub) continue;
            try
            {
                if (sub.UnionHandler != null)
                    await _relay.UnsubscribeUnionAsync(sub.TenantId, sub.UnionId, sub.UnionHandler);
                if (sub.GridHandler != null)
                    await _relay.UnsubscribeGridAsync(sub.TenantId, sub.GridId, sub.GridHandler);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "RtmRelayHub: error unsubscribing on disconnect");
            }
        }
        await base.OnDisconnectedAsync(exception);
    }

    private void StoreHandler(string key, Guid tenantId, int unionId, int gridId,
        Func<UnionStateChange, Task>? unionHandler,
        Func<IReadOnlyList<GridCellUpdate>, Task>? gridHandler)
    {
        Context.Items[key] = new HubSubscription(tenantId, unionId, gridId, unionHandler, gridHandler);
    }

    private sealed record HubSubscription(
        Guid TenantId, int UnionId, int GridId,
        Func<UnionStateChange, Task>? UnionHandler,
        Func<IReadOnlyList<GridCellUpdate>, Task>? GridHandler);
}
```

---

## Шаг 7 — DI Registration + Hub mapping

В `src/CcDashboard.Web/Program.cs` найти секцию регистрации сервисов и добавить:

```csharp
// RTM Relay — Singleton, server-side SignalR client to RTM Service (CLAUDE.md §34)
builder.Services.AddSingleton<IRtmRelayService, RtmRelayService>();
```

В секцию endpoints (после `app.MapRazorComponents`):
```csharp
app.MapHub<RtmRelayHub>("/hubs/rtm-relay");
```

Добавить using-и в Program.cs:
```csharp
using CcDashboard.Infrastructure.RtmRelay;
using CcDashboard.Web.Hubs;
```

Startup log warning если `SignalRHubUrl` не задан (аналогично RTMView):
```csharp
// После app.Build():
// Note: URL checked per-tenant at subscribe time, not at startup.
// Misconfigured tenants will get InvalidOperationException on first Subscribe.
```

---

## Шаг 8 — Build check

```bash
dotnet build src/CcDashboard.Web/CcDashboard.Web.csproj
```

Должен быть 0 errors. Warning'и допустимы.

```bash
dotnet build CcDashboard.sln
```

Весь solution должен собираться.

---

## Шаг 9 — Tests

```bash
dotnet test tests/CcDashboard.Tests.Architecture
```

Архитектурные тесты не должны падать (новые зависимости: Domain ← Application ← Infrastructure ← Web).

```bash
dotnet test CcDashboard.sln
```

Все тесты должны оставаться зелёными.

---

## MANDATORY pre-commit check

```bash
bash tools/pre-commit-check.sh
```

Если exit code 1 — НЕ делать commit. Восстановить truncated файлы через
`git show HEAD:<path> > <path>`, повторить запись через Python.

---

## Git commit

```bash
git add \
  src/CcDashboard.Domain/Domain/Rtm/ \
  src/CcDashboard.Application/Interfaces/IRtmRelayService.cs \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs \
  src/CcDashboard.Infrastructure/Persistence/Migrations/ \
  src/CcDashboard.Infrastructure/Persistence/Configurations/TenantSettingsConfiguration.cs \
  src/CcDashboard.Infrastructure/CcDashboard.Infrastructure.csproj \
  src/CcDashboard.Domain/Domain/TenantSettings.cs \
  src/CcDashboard.Web/Hubs/RtmRelayHub.cs \
  src/CcDashboard.Web/Program.cs

git commit -m "feat(CC-003): RTM Relay Infrastructure — single-port SignalR relay

- Add SignalRHubUrl to TenantSettings + EF migration
- Domain models: CellValue, AgentSnapshot, UnionStateChange, GridCellUpdate
- IRtmRelayService interface (Application layer)
- RtmRelayService Singleton (Infrastructure) — server-side HubConnection
  per (TenantId, UnionId/GridId) with ref-count, grace timer, snapshot
- RtmRelayHub — browser-facing /hubs/rtm-relay for JS widget clients
- DI registration + MapHub in Program.cs

Ref: CLAUDE.md §34, RTMView RtmHubService pattern"
```

---

## MANDATORY post-commit verification

```bash
git status --short
# Expected: empty

git diff HEAD -- \
  src/CcDashboard.Domain/Domain/Rtm/CellValue.cs \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs \
  src/CcDashboard.Web/Hubs/RtmRelayHub.cs
# Expected: empty (no diff)

git show HEAD:src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs | wc -l
wc -l src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
# Both numbers must match
```

---

## MANDATORY re-sync (PD-007 — counteracts Cowork cache write-back)

```bash
for f in \
  src/CcDashboard.Domain/Domain/Rtm/CellValue.cs \
  src/CcDashboard.Domain/Domain/Rtm/AgentSnapshot.cs \
  src/CcDashboard.Domain/Domain/Rtm/UnionStateChange.cs \
  src/CcDashboard.Domain/Domain/Rtm/GridCellUpdate.cs \
  src/CcDashboard.Application/Interfaces/IRtmRelayService.cs \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs \
  src/CcDashboard.Web/Hubs/RtmRelayHub.cs \
  src/CcDashboard.Web/Program.cs \
  src/CcDashboard.Domain/Domain/TenantSettings.cs \
  src/CcDashboard.Infrastructure/Persistence/Configurations/TenantSettingsConfiguration.cs; do
    git show HEAD:"$f" > "$f"
    echo "Re-synced: $f ($(wc -l < "$f") lines)"
done
sync
```
