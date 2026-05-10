---
name: signalr-expert
invocation: user
description: >
  Apply correct SignalR patterns to the RTM View Shell (Blazor Server + ASP.NET Core).
  Trigger this skill whenever the user mentions: SignalR, hubs, HubContext, real-time push,
  WebSocket, long-polling, circuit, CircuitHandler, reconnect, backplane, Redis backplane,
  group naming, hub filter, IHubFilter, hub authentication, force-logout push,
  permission change notification, DashboardHub, NotificationHub, HubConnection (JS/C#),
  IAsyncEnumerable streaming, MessagePack protocol, hub CORS, hub rate limiting,
  or any request to push data from server to client in real time.
  Also trigger on: "push to client", "notify on permission change", "force disconnect user",
  "SignalR scale-out", "sticky sessions vs backplane", "hub security", "hub tenant isolation".
  Never skip this skill for any real-time or push notification work.
---

# SignalR Expert — RTM View Shell

This skill governs every SignalR pattern in the project.
Two distinct SignalR surfaces exist — understand the difference before writing any code.

---

## 1. Two SignalR surfaces — critical distinction

| Surface | What it is | Auth | Group scope |
|---|---|---|---|
| **Blazor circuit** | The built-in SignalR connection that Blazor Server uses to sync UI with server | Cookie (automatic) | Internal, not exposed |
| **Application hubs** | Custom hubs you write for real-time push (force-logout, permission changes, live metrics stubs) | Cookie (Blazor pages) or JWT query string (API clients) | Manually managed, tenant-prefixed |

**Never mix them.** Do not use `IHubContext<ComponentHub>` to push to Blazor components —
Blazor circuits are opaque. Use application hubs for all explicit push scenarios.

---

## 2. Hub inventory

| Hub class | Route | Purpose |
|---|---|---|
| `DashboardHub` | `/hubs/dashboard` | Screen viewer: queue filter changes, permission-change invalidation, live metric stubs |
| `NotificationHub` | `/hubs/notifications` | Force-logout push, permission group change alerts, system announcements |

Both hubs **require authentication** (`[Authorize]`).
Both hubs **verify TenantId** on every connection and group join.

---

## 3. Group naming convention [ARCH-09]

```
Format:  "t:{tenantId}:{groupName}"

Examples:
  "t:3fa85f64-5717-4562-b3fc-2c963f66afa6:dashboard:7b2c..."   → per-dashboard group
  "t:3fa85f64-5717-4562-b3fc-2c963f66afa6:pg:9d1e..."         → permission-group group
  "t:3fa85f64-5717-4562-b3fc-2c963f66afa6:user:abc1..."       → per-user group (force-logout)
  "t:3fa85f64-5717-4562-b3fc-2c963f66afa6:all"               → all users in this tenant
```

**[ARCH-09] Rule:** every group name MUST start with `t:{tenantId}:`.
A hub method that adds a connection to a group without verifying TenantId is a **security defect**.

---

## 4. DashboardHub — full implementation

```csharp
// src/CcDashboard.Web/Hubs/DashboardHub.cs

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Interfaces;

namespace CcDashboard.Web.Hubs;

[Authorize]
public class DashboardHub : Hub<IDashboardClient>
{
    private readonly ICurrentUserAccessor _currentUser;
    private readonly IPermissionService   _permissions;
    private readonly ILogger<DashboardHub> _logger;

    public DashboardHub(
        ICurrentUserAccessor currentUser,
        IPermissionService   permissions,
        ILogger<DashboardHub> logger)
    {
        _currentUser = currentUser;
        _permissions = permissions;
        _logger      = logger;
    }

    // Connection lifecycle

    public override async Task OnConnectedAsync()
    {
        var tenantId = _currentUser.TenantId
            ?? throw new HubException("Tenant context missing.");

        var userId = _currentUser.UserId;

        // Always join per-user group (for force-logout targeting)
        await Groups.AddToGroupAsync(
            Context.ConnectionId,
            TenantGroup(tenantId, $"user:{userId}"));

        // Join tenant-wide group
        await Groups.AddToGroupAsync(
            Context.ConnectionId,
            TenantGroup(tenantId, "all"));

        _logger.LogDebug("DashboardHub connected: user={UserId} tenant={TenantId} cxn={CxnId}",
            userId, tenantId, Context.ConnectionId);

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        _logger.LogDebug("DashboardHub disconnected: cxn={CxnId} error={Error}",
            Context.ConnectionId, exception?.Message);
        await base.OnDisconnectedAsync(exception);
    }

    // Client-callable methods

    /// Client joins a dashboard-specific group to receive live updates for that screen.
    /// Verifies the caller has View permission before joining.
    public async Task JoinDashboard(Guid dashboardId)
    {
        var tenantId = GetVerifiedTenantId();
        var userId   = _currentUser.UserId;

        var hasAccess = await _permissions.HasDashboardAccessAsync(
            userId, dashboardId, AccessLevel.View, CancellationToken.None);

        if (!hasAccess)
        {
            _logger.LogWarning(
                "JoinDashboard denied: user={UserId} dashboard={DashboardId}", userId, dashboardId);
            throw new HubException("Access denied.");
        }

        await Groups.AddToGroupAsync(
            Context.ConnectionId,
            TenantGroup(tenantId, $"dashboard:{dashboardId}"));
    }

    public async Task LeaveDashboard(Guid dashboardId)
    {
        var tenantId = GetVerifiedTenantId();
        await Groups.RemoveFromGroupAsync(
            Context.ConnectionId,
            TenantGroup(tenantId, $"dashboard:{dashboardId}"));
    }

    /// Client joins a permission-group group so it receives PG-change invalidations.
    public async Task JoinPermissionGroup(Guid permissionGroupId)
    {
        var tenantId = GetVerifiedTenantId();

        // Verify caller actually belongs to this PG
        if (_currentUser.PermissionGroupId != permissionGroupId)
            throw new HubException("Access denied.");

        await Groups.AddToGroupAsync(
            Context.ConnectionId,
            TenantGroup(tenantId, $"pg:{permissionGroupId}"));
    }

    // Helpers

    private Guid GetVerifiedTenantId()
    {
        var tenantId = _currentUser.TenantId;
        if (tenantId is null)
            throw new HubException("Tenant context missing.");
        return tenantId.Value;
    }

    private static string TenantGroup(Guid tenantId, string suffix)
        => $"t:{tenantId}:{suffix}";
}
```

---

## 5. Strongly-typed client interface

```csharp
// src/CcDashboard.Web/Hubs/IDashboardClient.cs

namespace CcDashboard.Web.Hubs;

public interface IDashboardClient
{
    /// Server → client: permission group permissions changed, re-fetch.
    Task PermissionsChanged(Guid permissionGroupId);

    /// Server → client: force logout (revoked token, deactivation, admin action).
    Task ForceLogout(string reason);

    /// Server → client: dashboard deleted (navigate away).
    Task DashboardDeleted(Guid dashboardId);

    /// Server → client: dashboard renamed.
    Task DashboardRenamed(Guid dashboardId, string newName);

    // TODO: widget-library — future real-time metric push
    // Task MetricUpdate(MetricSnapshotDto snapshot);
}
```

---

## 6. Pushing from application services via IHubContext

Use `IHubContext<THub, TClient>` (strongly-typed variant) everywhere outside the hub itself.

### 6a. Force-logout push

```csharp
// UserService.cs (relevant excerpt)

public class UserService : IUserService
{
    private readonly IHubContext<DashboardHub, IDashboardClient> _hub;

    public UserService(IHubContext<DashboardHub, IDashboardClient> hub, ...)
        => _hub = hub;

    public async Task DeactivateUserAsync(Guid userId, Guid tenantId, CancellationToken ct)
    {
        // ... business logic, revoke tokens ...

        // Push force-logout to ALL connections of this user
        var group = $"t:{tenantId}:user:{userId}";
        await _hub.Clients.Group(group)
            .ForceLogout("Account deactivated by administrator.");

        await _auditService.WriteAsync(AuditEventType.User.Deactivated, ...);
    }
}
```

### 6b. Permission group change notification [PG-07]

```csharp
// UpdatePermissionGroupCommandHandler

public async Task Handle(UpdatePermissionGroupCommand cmd, CancellationToken ct)
{
    // ... save changes ...

    // Invalidate Redis cache [PG-07]
    await _cache.RemoveAsync($"{cmd.TenantId}:pg_permissions:{cmd.PermissionGroupId}");

    // Notify all connected clients in this PG to re-fetch permissions
    var group = $"t:{cmd.TenantId}:pg:{cmd.PermissionGroupId}";
    await _hub.Clients.Group(group)
        .PermissionsChanged(cmd.PermissionGroupId);
}
```

### 6c. Dashboard events

```csharp
// Push to all viewers of a specific dashboard
var group = $"t:{tenantId}:dashboard:{dashboardId}";
await _hub.Clients.Group(group).DashboardRenamed(dashboardId, newName);
await _hub.Clients.Group(group).DashboardDeleted(dashboardId);
```

---

## 7. Client-side hub connection (Blazor component)

```razor
@implements IAsyncDisposable
@inject NavigationManager Nav

@code {
    private HubConnection? _hub;

    protected override async Task OnInitializedAsync()
    {
        _hub = new HubConnectionBuilder()
            .WithUrl(Nav.ToAbsoluteUri("/hubs/dashboard"))  // Cookie auth — no token needed
            .WithAutomaticReconnect(new RetryPolicy())
            .AddMessagePackProtocol()
            .Build();

        // Register handlers BEFORE starting
        _hub.On<Guid>("PermissionsChanged", async pgId =>
        {
            await InvokeAsync(StateHasChanged);
        });

        _hub.On<string>("ForceLogout", async reason =>
        {
            await InvokeAsync(async () =>
            {
                Nav.NavigateTo("/login?reason=force", forceLoad: true);
            });
        });

        _hub.On<Guid>("DashboardDeleted", async dashboardId =>
        {
            await InvokeAsync(() =>
            {
                Nav.NavigateTo("/screens");
                return Task.CompletedTask;
            });
        });

        // CRITICAL: re-subscribe to groups after reconnect
        _hub.Reconnected += async connectionId =>
        {
            await _hub.SendAsync("JoinDashboard", DashboardId);
            await _hub.SendAsync("JoinPermissionGroup", CurrentUser.PermissionGroupId);
        };

        await _hub.StartAsync();

        // Initial group subscriptions
        await _hub.SendAsync("JoinDashboard", DashboardId);
        await _hub.SendAsync("JoinPermissionGroup", CurrentUser.PermissionGroupId);
    }

    public async ValueTask DisposeAsync()
    {
        if (_hub is not null)
        {
            await _hub.SendAsync("LeaveDashboard", DashboardId);
            await _hub.DisposeAsync();
        }
    }
}
```

### Custom retry policy

```csharp
// src/CcDashboard.Web/Services/RetryPolicy.cs

public sealed class RetryPolicy : IRetryPolicy
{
    private static readonly TimeSpan[] _delays =
    [
        TimeSpan.FromSeconds(0),
        TimeSpan.FromSeconds(2),
        TimeSpan.FromSeconds(5),
        TimeSpan.FromSeconds(10),
        TimeSpan.FromSeconds(30),
    ];

    public TimeSpan? NextRetryDelay(RetryContext retryContext)
    {
        var idx = (int)retryContext.PreviousRetryCount;
        return idx < _delays.Length ? _delays[idx] : TimeSpan.FromSeconds(60);
    }
}
```

---

## 8. CircuitHandler — track active Blazor circuits

```csharp
// src/CcDashboard.Infrastructure/SignalR/CircuitTracker.cs

public sealed class CircuitTracker : CircuitHandler
{
    private readonly ICurrentUserAccessor _user;
    private readonly IRedisCacheService   _cache;
    private readonly ILogger<CircuitTracker> _logger;

    public CircuitTracker(
        ICurrentUserAccessor user,
        IRedisCacheService   cache,
        ILogger<CircuitTracker> logger)
    {
        _user   = user;
        _cache  = cache;
        _logger = logger;
    }

    public override async Task OnCircuitOpenedAsync(Circuit circuit, CancellationToken ct)
    {
        var userId   = _user.UserId;
        var tenantId = _user.TenantId;
        if (userId == Guid.Empty || tenantId is null) return;

        var key = $"{tenantId}:active_circuits:{userId}";
        await _cache.SetAddAsync(key, circuit.Id, expiry: TimeSpan.FromHours(9));

        _logger.LogDebug("Circuit opened: {CircuitId} user={UserId}", circuit.Id, userId);
    }

    public override async Task OnCircuitClosedAsync(Circuit circuit, CancellationToken ct)
    {
        var userId   = _user.UserId;
        var tenantId = _user.TenantId;
        if (userId == Guid.Empty || tenantId is null) return;

        var key = $"{tenantId}:active_circuits:{userId}";
        await _cache.SetRemoveAsync(key, circuit.Id);

        _logger.LogDebug("Circuit closed: {CircuitId} user={UserId}", circuit.Id, userId);
    }
}
```

Registration:
```csharp
builder.Services.AddScoped<CircuitHandler, CircuitTracker>();
```

---

## 9. Redis backplane [SCALE-01]

Required from v1 — enables future scale-out without code changes.

```csharp
// Program.cs

builder.Services
    .AddSignalR(opts =>
    {
        opts.ClientTimeoutInterval        = TimeSpan.FromSeconds(60);
        opts.KeepAliveInterval            = TimeSpan.FromSeconds(15);
        opts.MaximumReceiveMessageSize    = 32 * 1024;           // 32 KB
        opts.EnableDetailedErrors         = builder.Environment.IsDevelopment();
    })
    .AddMessagePackProtocol()
    .AddStackExchangeRedis(
        builder.Configuration.GetConnectionString("Redis")!,
        opts =>
        {
            opts.Configuration.ChannelPrefix =
                RedisChannel.Literal("ccdashboard");             // namespace isolation
        });
```

Redis key namespacing — backplane keys vs application cache keys:

```
Backplane:   ccdashboard:SignalR:group:t:{tenantId}:dashboard:{id}
App cache:   {tenantId}:pg_permissions:{pgId}
App cache:   {tenantId}:revoked_jti:{jti}
```

The `ccdashboard` prefix keeps backplane traffic separate from application cache keys.

---

## 10. IHubFilter — tenant verification on every message

```csharp
// src/CcDashboard.Web/Hubs/TenantVerificationFilter.cs

public sealed class TenantVerificationFilter : IHubFilter
{
    public async ValueTask<object?> InvokeMethodAsync(
        HubInvocationContext ctx,
        Func<HubInvocationContext, ValueTask<object?>> next)
    {
        var tenantClaim = ctx.Context.User?
            .FindFirst("tenant_id")?.Value;

        if (string.IsNullOrEmpty(tenantClaim))
        {
            throw new HubException("Tenant claim missing. Re-authenticate.");
        }

        return await next(ctx);
    }
}
```

Registration:
```csharp
builder.Services.AddSignalR()
    .AddHubOptions<DashboardHub>(opts =>
    {
        opts.AddFilter<TenantVerificationFilter>();
    });
```

---

## 11. Authentication in hubs

### Blazor pages → DashboardHub (cookie auth)

Cookie is sent automatically — no special configuration needed.

```csharp
.WithUrl(Nav.ToAbsoluteUri("/hubs/dashboard"))  // that's it
```

### API clients / external JS → DashboardHub (JWT)

JWT cannot be sent as a Bearer header for WebSocket/SSE; use query string:

```csharp
// Program.cs
builder.Services.AddAuthentication()
    .AddJwtBearer(opts =>
    {
        opts.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"];
                var path  = ctx.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(token) &&
                    path.StartsWithSegments("/hubs"))
                {
                    ctx.Token = token;
                }
                return Task.CompletedTask;
            }
        };
    });
```

Client JavaScript:
```javascript
const connection = new signalR.HubConnectionBuilder()
    .withUrl("/hubs/dashboard?access_token=" + accessToken)
    .withAutomaticReconnect()
    .build();
```

**Security:** only use query string token over HTTPS (TLS encrypts the URL).
JWT appears in IIS access logs — use short-lived access tokens (15 min) [AUTH-API-02].

---

## 12. Hub mapping and CORS

```csharp
// Program.cs

builder.Services.AddCors(opts =>
{
    opts.AddPolicy("BlazorPolicy", p => p
        .WithOrigins(
            builder.Configuration["AllowedOrigins"]!.Split(','))
        .AllowAnyMethod()
        .AllowAnyHeader()
        .AllowCredentials());   // Required for cookie auth
});

app.UseCors("BlazorPolicy");

app.MapHub<DashboardHub>("/hubs/dashboard").RequireAuthorization();
app.MapHub<NotificationHub>("/hubs/notifications").RequireAuthorization();
```

---

## 13. IIS WebSocket configuration [DEPLOY-04]

`web.config`:

```xml
<configuration>
  <system.webServer>
    <webSocket enabled="true" />
  </system.webServer>
</configuration>
```

PowerShell (deployment script):
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebSockets
```

---

## 14. Streaming with IAsyncEnumerable

Reserved for future widget-library real-time feeds. Pattern for reference:

```csharp
// Hub method
public async IAsyncEnumerable<QueueSnapshotDto> StreamQueueMetrics(
    Guid queueId,
    [EnumeratorCancellation] CancellationToken ct)
{
    var tenantId = GetVerifiedTenantId();
    // Verify access ...

    while (!ct.IsCancellationRequested)
    {
        // TODO: widget-library — fetch from CC platform adapter
        yield return new QueueSnapshotDto { /* ... */ };
        await Task.Delay(TimeSpan.FromSeconds(5), ct);
    }
}
```

```csharp
// Blazor component
await foreach (var snapshot in _hub.StreamAsync<QueueSnapshotDto>(
    "StreamQueueMetrics", queueId, CancellationToken))
{
    Snapshot = snapshot;
    await InvokeAsync(StateHasChanged);
}
```

---

## 15. Anti-pattern table

| Anti-pattern | Why it's wrong | Correct approach |
|---|---|---|
| Group named `"dashboard:{id}"` without tenant prefix | Cross-tenant data leak | Always `"t:{tenantId}:dashboard:{id}"` [ARCH-09] |
| Hub method without `GetVerifiedTenantId()` call | Bypass tenant isolation | Call `GetVerifiedTenantId()` at the start of every hub method |
| `IHubContext<ComponentHub>` on Blazor circuit | Blazor circuits are opaque | Use application hubs (`DashboardHub`) for explicit push |
| Not re-subscribing groups after `Reconnected` | Groups are lost on reconnect; client misses push events | Always wire `_hub.Reconnected += async _ => { await JoinGroup(); }` |
| `Hub<IClient>.Clients.All.SendAsync(...)` | Sends to ALL tenants | Use `Clients.Group(tenantGroup)` |
| Registering message handlers AFTER `StartAsync` | Race condition — first message may be missed | Register handlers before `StartAsync` |
| JWT token in `localStorage` for hub auth | XSS steals token | Use `HttpOnly` cookie for Blazor; query string (HTTPS only) for API |
| `AddSignalR()` without `AddStackExchangeRedis` | Scale-out fails silently | Add Redis backplane from day 1 [SCALE-01] |
| Hub methods that do not throw on permission denial | Silently ignores unauthorised calls | Always `throw new HubException("Access denied.")` |
| `MaximumReceiveMessageSize` left at default | Large messages silently dropped | Set explicitly in `AddSignalR(opts => ...)` |
| `[AllowAnonymous]` on any hub class or method | Real-time channel without auth | All hubs require `[Authorize]`; verify TenantId inside |
| Direct DB call in hub method without scoped service | DbContext lifetime mismatch | Inject scoped services via constructor (hub is transient) |
| Missing `DisposeAsync` on `HubConnection` | Memory leak; dangling WebSocket | Implement `IAsyncDisposable` in every component using a hub |

---

## 16. Complete Program.cs registration summary

```csharp
// Services
builder.Services.AddScoped<CircuitHandler, CircuitTracker>();
builder.Services.AddSingleton<TenantVerificationFilter>();

builder.Services
    .AddSignalR(opts =>
    {
        opts.ClientTimeoutInterval     = TimeSpan.FromSeconds(60);
        opts.KeepAliveInterval         = TimeSpan.FromSeconds(15);
        opts.MaximumReceiveMessageSize = 32 * 1024;
        opts.EnableDetailedErrors      = builder.Environment.IsDevelopment();
    })
    .AddMessagePackProtocol()
    .AddStackExchangeRedis(
        builder.Configuration.GetConnectionString("Redis")!,
        opts => opts.Configuration.ChannelPrefix = RedisChannel.Literal("ccdashboard"))
    .AddHubOptions<DashboardHub>(opts => opts.AddFilter<TenantVerificationFilter>())
    .AddHubOptions<NotificationHub>(opts => opts.AddFilter<TenantVerificationFilter>());

// Middleware pipeline
app.UseAuthentication();
app.UseAuthorization();

app.MapHub<DashboardHub>("/hubs/dashboard").RequireAuthorization();
app.MapHub<NotificationHub>("/hubs/notifications").RequireAuthorization();
```

---

## 17. Pre-commit checklist

- [ ] All group names prefixed `t:{tenantId}:` [ARCH-09]
- [ ] Every hub method calls `GetVerifiedTenantId()` before any group or DB operation
- [ ] `[Authorize]` on hub class (not just individual methods)
- [ ] `IHubFilter` (`TenantVerificationFilter`) registered on every hub
- [ ] Client registers all `_hub.On<T>` handlers **before** `StartAsync`
- [ ] Client wires `Reconnected` handler to re-join all groups
- [ ] Client implements `IAsyncDisposable` and calls `hub.DisposeAsync()`
- [ ] `IHubContext<DashboardHub, IDashboardClient>` used (strongly-typed, not dynamic)
- [ ] Hub method throws `HubException("Access denied.")` on permission failure
- [ ] Redis backplane `AddStackExchangeRedis` with `ccdashboard` channel prefix registered
- [ ] IIS `webSocket enabled="true"` in `web.config`
- [ ] WebSocket Protocol IIS feature installed in deployment script
- [ ] JWT query-string token extraction wired in `JwtBearerEvents.OnMessageReceived` (if API clients connect)
- [ ] No `Clients.All` calls — always group-scoped within tenant boundary
- [ ] Force-logout push targets `t:{tenantId}:user:{userId}` group
- [ ] Permission-change push targets `t:{tenantId}:pg:{pgId}` group
- [ ] `MaximumReceiveMessageSize` set explicitly in `AddSignalR(opts => ...)`
