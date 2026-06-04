# CC Task: Implement HttpConfigurationApiHook — full integration simulation

## MANDATORY RULES (CLAUDE.md §0)

**§0.3 — Edit tool BANNED. Python atomic writes only:**
```python
with open(path, "r", encoding="utf-8") as f: text = f.read()
# ... modify ...
with open(path, "w", encoding="utf-8") as f: f.write(text)
```
After EVERY write: `tail -3 <path> && wc -l <path>`.
Truncated → `git show HEAD:<path> > <path>` + retry.

**§0.5 — Before every commit:** `bash tools/pre-commit-check.sh` (must exit 0)

**§0.4 — git index.lock:** `cp .git/index /tmp/cc-idx && GIT_INDEX_FILE=/tmp/cc-idx git add ... && GIT_INDEX_FILE=/tmp/cc-idx git commit -m "..." && cp /tmp/cc-idx .git/index`

---

## Context

`IConfigurationApiHook.NotifyAsync(entityType, payload, ct)` is called from all widget/grid
save and delete commands. The current implementation `NoOpConfigurationApiHook` is a no-op.

Goal: replace with a real `HttpConfigurationApiHook` that POSTs to the simulator's
`/api/config-notify` endpoint. The simulator receives notifications, logs them, and
auto-starts/stops RTM data generation for the affected GridId.

This gives a 100% realistic dev loop:
**Configure widget → backend calls hook → simulator starts generating data → widget displays it.**

---

## Architecture

```
CcDashboard.Web (Blazor Server)
  └─ Command (SaveQueueGridRtsCommand, etc.)
       └─ IConfigurationApiHook.NotifyAsync(...)
            └─ HttpConfigurationApiHook
                 └─ POST {ConfigApi:BaseUrl}/api/config-notify
                      └─ SignalRSimulator /api/config-notify
                           └─ logs event + auto-manages data generation for GridId
```

Config key (appsettings): `ConfigApi:BaseUrl`
- Development default: `"http://localhost:5045"` (same host as simulator SignalR)
- Production: URL of the real CC platform adapter (future)

---

## Changes Required

---

### Change 1 — `src/CcDashboard.Web/appsettings.json`

Add a new top-level section (after `"Smtp"` block):
```json
"ConfigApi": {
  "BaseUrl": ""
}
```
Empty string = hook behaves like NoOp (logs debug, no HTTP call).

---

### Change 2 — `src/CcDashboard.Web/appsettings.Development.json`

Add (alongside existing Development overrides):
```json
"ConfigApi": {
  "BaseUrl": "http://localhost:5045"
}
```

---

### Change 3 — New file: `src/CcDashboard.Infrastructure/Services/HttpConfigurationApiHook.cs`

```csharp
using System.Net.Http.Json;
using System.Text.Json;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CcDashboard.Infrastructure.Services;

/// <summary>
/// Sends configuration-change notifications to the CC-platform adapter (or simulator)
/// via HTTP POST to {ConfigApi:BaseUrl}/api/config-notify.
/// If BaseUrl is empty, behaves like NoOp (debug log only).
/// </summary>
public sealed class HttpConfigurationApiHook : IConfigurationApiHook
{
    private readonly IHttpClientFactory _httpFactory;
    private readonly ICurrentUserAccessor _currentUser;
    private readonly ILogger<HttpConfigurationApiHook> _logger;
    private readonly string? _baseUrl;

    private static readonly JsonSerializerOptions _jsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public HttpConfigurationApiHook(
        IHttpClientFactory httpFactory,
        ICurrentUserAccessor currentUser,
        IConfiguration configuration,
        ILogger<HttpConfigurationApiHook> logger)
    {
        _httpFactory = httpFactory;
        _currentUser = currentUser;
        _logger = logger;
        _baseUrl = configuration["ConfigApi:BaseUrl"]?.TrimEnd('/');
    }

    public async Task NotifyAsync(string entityType, object payload, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(_baseUrl))
        {
            _logger.LogDebug("[API-HOOK] {EntityType} — ConfigApi:BaseUrl not set, skipping HTTP notify", entityType);
            return;
        }

        var envelope = new
        {
            EventType  = entityType,
            Payload    = payload,
            Timestamp  = DateTime.UtcNow,
            TenantId   = _currentUser.TenantId
        };

        var url = $"{_baseUrl}/api/config-notify";

        try
        {
            var client = _httpFactory.CreateClient("ConfigApi");
            using var response = await client.PostAsJsonAsync(url, envelope, _jsonOptions, ct);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("[API-HOOK] {EntityType} → {Url} → {Status}",
                    entityType, url, (int)response.StatusCode);
            }
            else
            {
                _logger.LogWarning("[API-HOOK] {EntityType} → {Url} → HTTP {Status}",
                    entityType, url, (int)response.StatusCode);
            }
        }
        catch (HttpRequestException ex)
        {
            // Non-critical — CC platform may be unreachable; do not disrupt business transaction
            _logger.LogWarning(ex, "[API-HOOK] {EntityType} → {Url} — HTTP call failed (non-fatal)",
                entityType, url);
        }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested)
        {
            _logger.LogWarning("[API-HOOK] {EntityType} → {Url} — request timed out (non-fatal)",
                entityType, url);
        }
    }
}
```

---

### Change 4 — `src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs`

Find the line:
```csharp
services.AddScoped<IConfigurationApiHook, NoOpConfigurationApiHook>();
```

Replace with:
```csharp
// Register named HTTP client for config notifications
services.AddHttpClient("ConfigApi", client =>
{
    client.Timeout = TimeSpan.FromSeconds(5);
});

// Use HTTP hook when ConfigApi:BaseUrl is configured; NoOp otherwise
var configApiBase = configuration["ConfigApi:BaseUrl"];
if (!string.IsNullOrWhiteSpace(configApiBase))
    services.AddScoped<IConfigurationApiHook, HttpConfigurationApiHook>();
else
    services.AddScoped<IConfigurationApiHook, NoOpConfigurationApiHook>();
```

The method signature already receives `IConfiguration configuration` — verify this before
writing. If it doesn't, add `IConfiguration configuration` parameter and update all callers
(likely just `Program.cs`).

---

### Change 5 — `tools/SignalRSimulator/Program.cs`

Add the `/api/config-notify` endpoint BEFORE `app.Run()`:

```csharp
// Config-notification receiver — simulates CC platform API
app.MapPost("/api/config-notify", async (HttpContext ctx, ILogger<Program> logger) =>
{
    using var reader = new System.IO.StreamReader(ctx.Request.Body);
    var body = await reader.ReadToEndAsync();

    ConfigNotification? notification = null;
    try
    {
        notification = System.Text.Json.JsonSerializer.Deserialize<ConfigNotification>(body,
            new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true });
    }
    catch
    {
        logger.LogWarning("[CONFIG-NOTIFY] Failed to parse notification body: {Body}", body);
        return Results.BadRequest(new { error = "Invalid JSON" });
    }

    if (notification is null)
        return Results.BadRequest(new { error = "Empty notification" });

    logger.LogInformation("[CONFIG-NOTIFY] EventType={EventType} TenantId={TenantId} Payload={Payload}",
        notification.EventType,
        notification.TenantId,
        System.Text.Json.JsonSerializer.Serialize(notification.Payload));

    // React to grid lifecycle events — auto-manage data generation in the simulator
    var hub = ctx.RequestServices.GetService<RtmSimulatorHub>();

    switch (notification.EventType)
    {
        case "QueueGridRts.Saved":
        case "DataSlotRts.Saved":
            if (notification.Payload.TryGetProperty("GridId", out var qgridEl)
                && qgridEl.TryGetInt32(out var qGridId) && qGridId > 0)
            {
                logger.LogInformation("[CONFIG-NOTIFY] Queue/DataSlot GridId={GridId} configured — simulator ready",
                    qGridId);
                // Data generation starts on init() call from the widget — nothing to do here
                // But log so dev knows the grid is registered in the CC platform
            }
            break;

        case "QueueGridRts.Deleted":
            if (notification.Payload.TryGetProperty("GridId", out var dqEl)
                && dqEl.TryGetInt32(out var dqGridId))
            {
                logger.LogInformation("[CONFIG-NOTIFY] QueueGrid GridId={GridId} deleted", dqGridId);
            }
            break;

        case "AgentGridRts.Saved":
            if (notification.Payload.TryGetProperty("GridId", out var agEl)
                && agEl.TryGetInt32(out var agGridId) && agGridId > 0)
            {
                logger.LogInformation("[CONFIG-NOTIFY] AgentGrid GridId={GridId} (UnionId) configured — simulator ready",
                    agGridId);
            }
            break;

        case "AgentGridRts.Deleted":
            if (notification.Payload.TryGetProperty("GridId", out var dagEl)
                && dagEl.TryGetInt32(out var dagGridId))
            {
                logger.LogInformation("[CONFIG-NOTIFY] AgentGrid GridId={GridId} deleted", dagGridId);
            }
            break;

        case "BusinessUnit":
        case "Supergroup":
        case "Site":
            logger.LogInformation("[CONFIG-NOTIFY] Reference data updated: {EventType}", notification.EventType);
            break;

        default:
            logger.LogDebug("[CONFIG-NOTIFY] Unhandled event: {EventType}", notification.EventType);
            break;
    }

    return Results.Ok(new { received = true, eventType = notification.EventType });
});
```

Add the `ConfigNotification` record somewhere accessible in Program.cs (either inline or in Models):
```csharp
// At the top of Program.cs or in Models/RtmModels.cs
public record ConfigNotification(
    string EventType,
    System.Text.Json.JsonElement Payload,
    DateTime Timestamp,
    Guid? TenantId
);
```

Note: use `System.Text.Json.JsonElement` for `Payload` so the endpoint can inspect it
without requiring a strongly-typed model per event.

---

### Change 6 — `tools/SignalRSimulator/appsettings.json`

Add (for clarity, it already serves on 5045):
```json
"ConfigApi": {
  "ReceiverEnabled": true
}
```
(Optional — just documents intent. No code behavior change needed.)

---

## Verification

```bash
# Build both
dotnet restore CcDashboard.sln
dotnet build src/CcDashboard.Web --no-restore 2>&1 | tail -5
dotnet build tools/SignalRSimulator/SignalRSimulator.csproj --no-restore 2>&1 | tail -5

# Verify hook registration
grep -n "HttpConfigurationApiHook\|AddHttpClient.*ConfigApi" \
  src/CcDashboard.Infrastructure/Extensions/InfrastructureServiceExtensions.cs

# Verify endpoint in simulator
grep -n "config-notify\|ConfigNotification" \
  tools/SignalRSimulator/Program.cs
```

Both builds must succeed with 0 errors.

## Manual smoke test (after running both services in dev)

```bash
# Should return {"received":true,"eventType":"Test"}
curl -X POST http://localhost:5045/api/config-notify \
  -H "Content-Type: application/json" \
  -d '{"eventType":"Test","payload":{"GridId":42},"timestamp":"2026-01-01T00:00:00Z","tenantId":null}'
```

---

## Commit

```bash
bash tools/pre-commit-check.sh   # must exit 0
```

Commit message:
```
feat: implement HttpConfigurationApiHook for integration simulation

- Add HttpConfigurationApiHook: POSTs config events to ConfigApi:BaseUrl
- Conditional DI registration: HTTP hook if URL configured, NoOp otherwise
- Named HttpClient "ConfigApi" with 5s timeout
- appsettings.Development.json: default BaseUrl = http://localhost:5045
- SignalRSimulator: add POST /api/config-notify endpoint
  - Logs all config events with full payload
  - Reacts to grid lifecycle events (QueueGridRts, AgentGridRts, DataSlotRts)
```
