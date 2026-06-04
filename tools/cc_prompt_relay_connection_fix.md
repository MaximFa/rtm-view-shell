# CC Task: Fix RtmRelayService — null URL fallback + connection retry after failure

## MANDATORY RULES (CLAUDE.md §0)

§0.3 — Edit tool BANNED. Python atomic writes only.
After EVERY write: `sync && tail -3 <path> && wc -l <path>`
§0.5 — Before commit: `bash tools/pre-commit-check.sh` (exit 0)

---

## §0 — SESSION-RESUME (run first)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git log --oneline -1   # expected: f930283
git status --short
```
Restore any truncated M files before starting.

---

## Root Cause Analysis

All relay-based widgets (QueueGrid, DataSlot, AgentGrid, AgentStateDistribution) show
"Connection failed". DayTrend and InfoSlot (no relay) work fine.

Two bugs in `src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs`:

### Bug 1 — No fallback URL when SignalRConnectionUrl is null in DB

`GetHubUrlAsync` throws `InvalidOperationException` if `SignalRConnectionUrl` is not set
in tenant_settings. Widgets previously had a hardcoded fallback:
```csharp
var simulatorUrl = settings?.SignalRConnectionUrl ?? "http://localhost:5045";
```
The relay has no such fallback — it throws immediately.

### Bug 2 — state.Connection not reset after StartAsync failure

In both `SubscribeGridAsync` and `SubscribeUnionAsync`:
```csharp
state.Connection = BuildGridConnection(key, state, hubUrl);
await state.Connection.StartAsync(ct);  // ← if this throws...
```
If `StartAsync` throws, `state.Connection` is LEFT as a non-null (but disconnected) object.
On the next subscribe call (widget Retry), the guard `if (state.Connection == null)` is
FALSE → relay never attempts to reconnect → widget stays "Connection failed" forever.

---

## Fix 1 — Fallback URL in GetHubUrlAsync

**File:** `src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs`

Find the null/empty check in `GetHubUrlAsync`:
```csharp
        if (string.IsNullOrEmpty(url))
            throw new InvalidOperationException(
                $"RTM Hub URL not configured for tenant {tenantId}. " +
                "Set SignalRConnectionUrl in Tenant Settings → SignalR Widgets.");
```
Replace with:
```csharp
        if (string.IsNullOrEmpty(url))
        {
            // Fallback for dev environments — matches prior widget default
            url = _defaultHubBaseUrl;
            _logger.LogWarning(
                "RtmRelayService: SignalRConnectionUrl not set for tenant {TenantId}. " +
                "Using default: {Url}. Set it in Tenant Settings → SignalR Widgets.",
                tenantId, url);
        }
```

Add the default URL field. Find the class constructor or field declarations area
(near `_unions`, `_grids`, `_redis` fields) and add:
```csharp
    private const string _defaultHubBaseUrl = "http://localhost:5045";
```

---

## Fix 2 — Reset state.Connection on StartAsync failure

Apply to BOTH `SubscribeGridAsync` and `SubscribeUnionAsync`.

### In SubscribeGridAsync

Find:
```csharp
            if (state.Connection == null)
            {
                state.Connection = BuildGridConnection(key, state, hubUrl);
                await state.Connection.StartAsync(ct);
                _logger.LogInformation(
                    "RtmRelayService: connected to tenant {TenantId} grid {GridId}",
                    tenantId, gridId);
                await GridInitAsync(state, gridId, ct);
            }
```
Replace with:
```csharp
            if (state.Connection == null)
            {
                var conn = BuildGridConnection(key, state, hubUrl);
                try
                {
                    await conn.StartAsync(ct);
                    state.Connection = conn;
                    _logger.LogInformation(
                        "RtmRelayService: connected to tenant {TenantId} grid {GridId}",
                        tenantId, gridId);
                    await GridInitAsync(state, gridId, ct);
                }
                catch
                {
                    await conn.DisposeAsync();
                    state.Connection = null;   // allow retry on next Subscribe call
                    throw;                      // propagate → widget catch → Failed state
                }
            }
```

### In SubscribeUnionAsync

Find:
```csharp
            if (state.Connection == null)
            {
                state.Connection = BuildUnionConnection(key, state, hubUrl);
                await state.Connection.StartAsync(ct);
                _logger.LogInformation(
                    "RtmRelayService: connected to tenant {TenantId} union {UnionId}",
                    tenantId, unionId);
                await InitUnionAsync(state, unionId, ct);
            }
```
Replace with:
```csharp
            if (state.Connection == null)
            {
                var conn = BuildUnionConnection(key, state, hubUrl);
                try
                {
                    await conn.StartAsync(ct);
                    state.Connection = conn;
                    _logger.LogInformation(
                        "RtmRelayService: connected to tenant {TenantId} union {UnionId}",
                        tenantId, unionId);
                    await InitUnionAsync(state, unionId, ct);
                }
                catch
                {
                    await conn.DisposeAsync();
                    state.Connection = null;   // allow retry on next Subscribe call
                    throw;                      // propagate → widget catch → Failed state
                }
            }
```

---

## Verification

```bash
# 1. Build
dotnet build src/CcDashboard.Infrastructure --no-restore 2>&1 | tail -3
dotnet build src/CcDashboard.Web --no-restore 2>&1 | tail -3
# Expected: Build succeeded. 0 Error(s).

# 2. Fallback URL present
grep -n "defaultHubBaseUrl\|localhost:5045" \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs

# 3. state.Connection = null in catch blocks
grep -n "state\.Connection = null" \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
# Expected: 2 lines (one for grid, one for union)

# 4. Tests
dotnet test CcDashboard.sln 2>&1 | tail -3
```

---

## Commit

```
fix(relay): null URL fallback + reset connection on StartAsync failure

- GetHubUrlAsync: fallback to http://localhost:5045 if SignalRConnectionUrl not
  configured (matches prior widget behaviour; logs a warning)
- SubscribeGridAsync + SubscribeUnionAsync: set state.Connection = null when
  StartAsync throws — allows widget Retry to attempt reconnection
```
