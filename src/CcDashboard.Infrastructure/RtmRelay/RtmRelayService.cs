using System.Collections.Concurrent;
using System.Text.Json;
using CcDashboard.Application.Interfaces;
using CcDashboard.Domain.Domain.Rtm;
using CcDashboard.Infrastructure.Persistence;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json.Serialization;
using StackExchange.Redis;

namespace CcDashboard.Infrastructure.RtmRelay;

/// <summary>
/// Server-side relay between RTM Service SignalR Hub and Blazor widget components.
/// Singleton service — one HubConnection per (TenantId, UnionId/GridId) with ref-count,
/// grace timer, and snapshot delivery. See CLAUDE.md §34.
/// </summary>
public sealed class RtmRelayService : IRtmRelayService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IConnectionMultiplexer _redis;
    private readonly ILogger<RtmRelayService> _logger;
    private readonly IOptionsMonitor<RtmRelayOptions> _options;

    private readonly ConcurrentDictionary<(Guid TenantId, int UnionId), UnionState> _unions = new();
    private readonly ConcurrentDictionary<(Guid TenantId, int GridId), GridState> _grids = new();

    private const string _defaultHubBaseUrl = "http://localhost:5045";

    public RtmRelayService(
        IServiceScopeFactory scopeFactory,
        IConnectionMultiplexer redis,
        ILogger<RtmRelayService> logger,
        IOptionsMonitor<RtmRelayOptions> options)
    {
        _scopeFactory = scopeFactory;
        _redis = redis;
        _logger = logger;
        _options = options;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Hub URL resolution
    // ═══════════════════════════════════════════════════════════════════════════

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
            .Select(s => s.SignalRConnectionUrl)
            .FirstOrDefaultAsync(ct);

        if (string.IsNullOrEmpty(url))
        {
            // Fallback for dev environments — matches prior widget default
            url = _defaultHubBaseUrl;
            _logger.LogWarning(
                "RtmRelayService: SignalRConnectionUrl not set for tenant {TenantId}. " +
                "Using default: {Url}. Set it in Tenant Settings → SignalR Widgets.",
                tenantId, url);
        }

        // 3. Normalise: append /signalr hub path (SignalRConnectionUrl stores base URL)
        if (!url.TrimEnd('/').EndsWith("/signalr", StringComparison.OrdinalIgnoreCase))
            url = url.TrimEnd('/') + "/signalr";

        // 4. Cache for 5 minutes
        await db.StringSetAsync(cacheKey, url, TimeSpan.FromMinutes(5));
        return url;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Per-union (AgentGrid) subscribe/unsubscribe
    // ═══════════════════════════════════════════════════════════════════════════

    public async Task SubscribeUnionAsync(Guid tenantId, int unionId,
        Func<UnionStateChange, Task> handler, CancellationToken ct = default)
    {
        var hubUrl = await GetHubUrlAsync(tenantId, CancellationToken.None);
        var key = (tenantId, unionId);
        var state = _unions.GetOrAdd(key, _ => new UnionState());

        await state.Lock.WaitAsync(CancellationToken.None);
        try
        {
            if (state.GraceCts != null)
            {
                state.GraceCts.Cancel();
                state.GraceCts.Dispose();
                state.GraceCts = null;
            }

            state.Handlers.Add(handler);
            state.RefCount++;

            if (state.Connection == null)
            {
                var conn = BuildUnionConnection(key, state, hubUrl);
                try
                {
                    await conn.StartAsync(CancellationToken.None);
                    state.Connection = conn;
                    _logger.LogInformation(
                        "RtmRelayService: connected to tenant {TenantId} union {UnionId}",
                        tenantId, unionId);
                    await InitUnionAsync(state, unionId, CancellationToken.None);
                }
                catch
                {
                    await conn.DisposeAsync();
                    state.Connection = null;   // allow retry on next Subscribe call
                    throw;                      // propagate → widget catch → Failed state
                }
            }

            // Deliver current snapshot immediately
            var snap = new UnionStateChange.InitialSnapshot(
                new Dictionary<string, AgentSnapshot>(state.Snapshot),
                state.ServerTimeOffset);
            await handler(snap);
        }
        finally
        {
            state.Lock.Release();
        }
    }

    public async Task UnsubscribeUnionAsync(Guid tenantId, int unionId,
        Func<UnionStateChange, Task> handler)
    {
        var key = (tenantId, unionId);
        if (!_unions.TryGetValue(key, out var state)) return;

        await state.Lock.WaitAsync();
        try
        {
            var removed = state.Handlers.Remove(handler);
            if (removed)
                state.RefCount = Math.Max(0, state.RefCount - 1);
            else
                _logger.LogWarning(
                    "RtmRelayService: UnsubscribeUnionAsync — handler not found in list for union {UnionId} (RefCount={RefCount}), skipping decrement",
                    unionId, state.RefCount);

            if (state.RefCount == 0)
            {
                var cts = new CancellationTokenSource();
                state.GraceCts = cts;
                _ = RunUnionGraceTimerAsync(key, state, cts.Token);
                _logger.LogInformation(
                    "RtmRelayService: tenant {TenantId} union {UnionId} has no subscribers — 30 s grace timer started",
                    tenantId, unionId);
            }
        }
        finally
        {
            state.Lock.Release();
        }
    }

    // ── Union connection management ───────────────────────────────────────────

    private HubConnection BuildUnionConnection((Guid TenantId, int UnionId) key, UnionState state, string hubUrl)
    {
        var conn = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .AddNewtonsoftJsonProtocol(opts =>
                opts.PayloadSerializerSettings.ContractResolver = new DefaultContractResolver())
            .ConfigureLogging(b => b.SetMinimumLevel(LogLevel.Information))
            .Build();

        // Using On<JToken> — Newtonsoft protocol cannot deserialize to System.Text.Json.JsonElement.
        conn.On<JToken, JToken, JToken>("updateUserGrid",
            (d, _, res) => HandleUpdateAsync(state, key, res));

        conn.On<JToken, JToken>("removeUser",
            (_, users) => HandleRemoveAsync(state, key, users));

        conn.Closed += ex =>
        {
            _logger.LogInformation(ex,
                "RtmRelayService: tenant {TenantId} union {UnionId} connection closed",
                key.TenantId, key.UnionId);
            if (!state.IsDisposing)
                _ = ReconnectUnionWithBackoffAsync(state, key);
            return Task.CompletedTask;
        };

        return conn;
    }

    private async Task InitUnionAsync(UnionState state, int unionId, CancellationToken ct)
    {
        var raw = await state.Connection!
            .InvokeAsync<string>("init", $"u{unionId}", ct);

        if (DateTime.TryParse(raw, null,
                System.Globalization.DateTimeStyles.RoundtripKind, out var serverTime))
        {
            state.ServerTimeOffset = serverTime.ToUniversalTime() - DateTime.UtcNow;
        }

        _logger.LogInformation(
            "RtmRelayService: init union {UnionId}, serverTimeOffset={OffsetMs:F1} ms",
            unionId, state.ServerTimeOffset.TotalMilliseconds);
    }

    private async Task ReconnectUnionWithBackoffAsync(UnionState state, (Guid TenantId, int UnionId) key)
    {
        var delay = TimeSpan.FromSeconds(5);
        var maxDelay = TimeSpan.FromSeconds(60);

        while (true)
        {
            if (state.IsDisposing) return;

            await state.Lock.WaitAsync();
            var refCount = state.RefCount;
            var unionAlive = _unions.ContainsKey(key);
            state.Lock.Release();
            if (!unionAlive || refCount == 0) return;

            _logger.LogInformation(
                "RtmRelayService: reconnecting tenant {TenantId} union {UnionId} in {Delay:F0} s",
                key.TenantId, key.UnionId, delay.TotalSeconds);

            await Task.Delay(delay);

            if (state.IsDisposing || !_unions.ContainsKey(key)) return;

            try
            {
                var hubUrl = await GetHubUrlAsync(key.TenantId, default);

                state.IsDisposing = true;
                var old = state.Connection;
                state.Connection = BuildUnionConnection(key, state, hubUrl);
                if (old != null) await old.DisposeAsync();
                state.IsDisposing = false;

                await state.Connection.StartAsync();
                _logger.LogInformation(
                    "RtmRelayService: reconnected tenant {TenantId} union {UnionId}",
                    key.TenantId, key.UnionId);

                await InitUnionAsync(state, key.UnionId, default);

                List<Func<UnionStateChange, Task>> handlers;
                IReadOnlyDictionary<string, AgentSnapshot> snap;
                await state.Lock.WaitAsync();
                try
                {
                    handlers = state.Handlers.ToList();
                    snap = new Dictionary<string, AgentSnapshot>(state.Snapshot);
                }
                finally { state.Lock.Release(); }

                await FanOutAsync(handlers, new UnionStateChange.InitialSnapshot(snap, state.ServerTimeOffset));
                return;
            }
            catch (Exception ex)
            {
                state.IsDisposing = false;
                _logger.LogWarning(ex,
                    "RtmRelayService: reconnect attempt failed for tenant {TenantId} union {UnionId}",
                    key.TenantId, key.UnionId);
                var next = delay * 2;
                delay = next > maxDelay ? maxDelay : next;
            }
        }
    }

    private async Task RunUnionGraceTimerAsync((Guid TenantId, int UnionId) key, UnionState state, CancellationToken ct)
    {
        try { await Task.Delay(TimeSpan.FromSeconds(30), ct); }
        catch (OperationCanceledException) { return; }

        HubConnection? toDispose = null;
        await state.Lock.WaitAsync();
        try
        {
            if (state.RefCount == 0)
            {
                _unions.TryRemove(key, out _);
                toDispose = state.Connection;
                state.IsDisposing = true;
                _logger.LogInformation(
                    "RtmRelayService: disposing tenant {TenantId} union {UnionId} connection (grace period expired)",
                    key.TenantId, key.UnionId);
            }
        }
        finally { state.Lock.Release(); }

        if (toDispose != null)
            await toDispose.DisposeAsync();
    }

    // ── Union event handlers ──────────────────────────────────────────────────

    private async Task HandleUpdateAsync(UnionState state, (Guid TenantId, int UnionId) key, JToken res)
    {
        if (res is not JObject resObj) return;
        if (resObj["Data"] is not JArray dataArray) return;

        var upserted = new List<AgentSnapshot>();
        List<Func<UnionStateChange, Task>> handlers;

        await state.Lock.WaitAsync();
        try
        {
            foreach (var item in dataArray)
            {
                if (item is not JObject itemObj) continue;
                var agentLoginName = itemObj["AgentLoginName"]?.Value<string>();
                if (agentLoginName == null) continue;

                var fields = new Dictionary<string, CellValue>();
                foreach (var prop in itemObj.Properties())
                {
                    fields[prop.Name] = CellValue.Parse(
                        prop.Value.Type == JTokenType.String
                            ? prop.Value.Value<string>()
                            : prop.Value.ToString());
                }

                var snapshot = new AgentSnapshot(agentLoginName, fields, DateTime.UtcNow);
                state.Snapshot[agentLoginName] = snapshot;
                upserted.Add(snapshot);
            }

            handlers = state.Handlers.ToList();
        }
        finally { state.Lock.Release(); }

        if (_options.CurrentValue.DiagPushLogging)
        {
            var agentLog = string.Join(" | ", upserted.Select(a =>
            {
                var st = a.Fields.TryGetValue("MonAgentState", out var sv) ? sv.Raw
                       : a.Fields.TryGetValue("AgentState",    out var sv2) ? sv2.Raw
                       : "(no state field)";
                var fieldNames = string.Join(",", a.Fields.Keys.Take(8));
                return $"{a.AgentLoginName}=>state={st} fields=[{fieldNames}]";
            }));
            _logger.LogInformation(
                "RECV updateUserGrid union {UnionId}: {Count} agents [{Agents}]",
                key.UnionId, upserted.Count, agentLog);
        }

        if (upserted.Count > 0)
            await FanOutAsync(handlers, new UnionStateChange.AgentsUpserted(upserted));
    }

    private async Task HandleRemoveAsync(UnionState state, (Guid TenantId, int UnionId) key, JToken users)
    {
        if (users is not JArray usersArray) return;

        var removed = new List<string>();
        List<Func<UnionStateChange, Task>> handlers;

        await state.Lock.WaitAsync();
        try
        {
            if (!state.HasLoggedRemovePayload)
            {
                _logger.LogInformation(
                    "RtmRelayService: removeUser first payload tenant {TenantId} union {UnionId} — raw: {Raw}",
                    key.TenantId, key.UnionId, users.ToString());
                state.HasLoggedRemovePayload = true;
            }

            foreach (var userToken in usersArray)
            {
                if (userToken is not JObject userObj) continue;
                var name = userObj["name"]?.Value<string>();
                if (name == null) continue;

                if (state.Snapshot.Remove(name))
                    removed.Add(name);
            }

            handlers = state.Handlers.ToList();
        }
        finally { state.Lock.Release(); }

        _logger.LogDebug(
            "RtmRelayService: removeUser tenant {TenantId} union {UnionId}, {Count} agents removed",
            key.TenantId, key.UnionId, removed.Count);

        if (removed.Count > 0)
            await FanOutAsync(handlers, new UnionStateChange.AgentsRemoved(removed));
    }

    // ── Union helpers ─────────────────────────────────────────────────────────

    private static async Task FanOutAsync(
        List<Func<UnionStateChange, Task>> handlers, UnionStateChange change)
    {
        foreach (var h in handlers)
        {
            try { await h(change); }
            catch { /* subscriber handler threw — logged by caller if needed */ }
        }
    }

    // ── Per-union state ───────────────────────────────────────────────────────

    private sealed class UnionState
    {
        public HubConnection? Connection;
        public TimeSpan ServerTimeOffset;
        public bool IsDisposing;
        public bool HasLoggedRemovePayload;
        public readonly Dictionary<string, AgentSnapshot> Snapshot = new();
        public readonly List<Func<UnionStateChange, Task>> Handlers = new();
        public int RefCount;
        public CancellationTokenSource? GraceCts;
        public readonly SemaphoreSlim Lock = new(1, 1);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Per-grid (DataGrid) subscribe/unsubscribe
    // ═══════════════════════════════════════════════════════════════════════════

    public async Task SubscribeGridAsync(Guid tenantId, int gridId,
        Func<IReadOnlyList<GridCellUpdate>, Task> handler, CancellationToken ct = default)
    {
        var hubUrl = await GetHubUrlAsync(tenantId, CancellationToken.None);
        var key = (tenantId, gridId);
        var state = _grids.GetOrAdd(key, _ => new GridState());

        await state.Lock.WaitAsync(CancellationToken.None);
        try
        {
            if (state.GraceCts != null)
            {
                state.GraceCts.Cancel();
                state.GraceCts.Dispose();
                state.GraceCts = null;
            }

            state.Handlers.Add(handler);
            state.RefCount++;

            if (state.Connection == null)
            {
                var conn = BuildGridConnection(key, state, hubUrl);
                try
                {
                    // Use CancellationToken.None for the connection phase.
                    // The component CT must not cancel the Hub connection itself —
                    // Blazor may call StateHasChanged during init causing CT cancellation,
                    // which would incorrectly fail the connection for other widgets sharing
                    // the same page refresh cycle.
                    await conn.StartAsync(CancellationToken.None);
                    state.Connection = conn;
                    _logger.LogInformation(
                        "RtmRelayService: connected to tenant {TenantId} grid {GridId}",
                        tenantId, gridId);
                    await GridInitAsync(state, gridId, CancellationToken.None);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex,
                        "RtmRelayService: failed to connect grid {GridId} - {ExType}: {Msg}",
                        gridId, ex.GetType().Name, ex.Message);
                    await conn.DisposeAsync();
                    state.Connection = null;   // allow retry on next Subscribe call
                    throw;                      // propagate -> widget catch -> Failed state
                }
            }
            else if (state.CellSnapshot.Count > 0)
            {
                // Late subscriber: deliver current cell values immediately
                var snapshot = state.CellSnapshot
                    .Select(kvp => new GridCellUpdate(kvp.Key, kvp.Value.Value, kvp.Value.Value2))
                    .ToList();
                _logger.LogInformation(
                    "RtmRelayService: delivering snapshot of {Count} cells to late subscriber for grid {GridId}",
                    snapshot.Count, gridId);
                await handler(snapshot);
            }
        }
        finally
        {
            state.Lock.Release();
        }
    }

    public async Task UnsubscribeGridAsync(Guid tenantId, int gridId,
        Func<IReadOnlyList<GridCellUpdate>, Task> handler)
    {
        var key = (tenantId, gridId);
        if (!_grids.TryGetValue(key, out var state)) return;

        await state.Lock.WaitAsync();
        try
        {
            var removed = state.Handlers.Remove(handler);
            if (removed)
                state.RefCount = Math.Max(0, state.RefCount - 1);
            else
                _logger.LogWarning(
                    "RtmRelayService: UnsubscribeGridAsync — handler not found in list for grid {GridId} (RefCount={RefCount}), skipping decrement",
                    gridId, state.RefCount);

            if (state.RefCount == 0)
            {
                var cts = new CancellationTokenSource();
                state.GraceCts = cts;
                _ = RunGridGraceTimerAsync(key, state, cts.Token);
                _logger.LogInformation(
                    "RtmRelayService: tenant {TenantId} grid {GridId} has no subscribers — 30 s grace timer started",
                    tenantId, gridId);
            }
        }
        finally
        {
            state.Lock.Release();
        }
    }

    // ── Grid connection management ────────────────────────────────────────────

    private HubConnection BuildGridConnection((Guid TenantId, int GridId) key, GridState state, string hubUrl)
    {
        var conn = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .AddNewtonsoftJsonProtocol(opts =>
                opts.PayloadSerializerSettings.ContractResolver = new DefaultContractResolver())
            .ConfigureLogging(b => b.SetMinimumLevel(LogLevel.Information))
            .Build();

        // Using On<JToken> — Newtonsoft protocol cannot deserialize to System.Text.Json.JsonElement.
        // JToken is the correct type when AddNewtonsoftJsonProtocol is active.
        conn.On<JToken>("updateGridData",
            cells => HandleGridUpdateAsync(state, key, cells));

        conn.Closed += ex =>
        {
            _logger.LogInformation(ex,
                "RtmRelayService: tenant {TenantId} grid {GridId} connection closed",
                key.TenantId, key.GridId);
            if (!state.IsDisposing)
                _ = ReconnectGridWithBackoffAsync(state, key);
            return Task.CompletedTask;
        };

        return conn;
    }

    private async Task GridInitAsync(GridState state, int gridId, CancellationToken ct)
    {
        // Hub uses the same 'init' method for both unions ('u{id}') and grids ('{id}').
        // Return type is string (datetime) - using JsonElement causes Newtonsoft/STJ conflict.
        await state.Connection!.InvokeAsync<string>("init", gridId.ToString(), ct);

        // refreshCells causes the server to push updateGridData with all current values.
        // Use SendAsync (fire-and-forget) - refreshCells is a void Hub method.
        await state.Connection!.SendAsync("refreshCells", gridId.ToString(), CancellationToken.None);

        _logger.LogInformation("RtmRelayService: init+refreshCells complete for grid {GridId}", gridId);
    }

    private async Task ReconnectGridWithBackoffAsync(GridState state, (Guid TenantId, int GridId) key)
    {
        var delay = TimeSpan.FromSeconds(5);
        var maxDelay = TimeSpan.FromSeconds(60);

        while (true)
        {
            if (state.IsDisposing) return;

            await state.Lock.WaitAsync();
            var refCount = state.RefCount;
            var gridAlive = _grids.ContainsKey(key);
            state.Lock.Release();
            if (!gridAlive || refCount == 0) return;

            _logger.LogInformation(
                "RtmRelayService: reconnecting tenant {TenantId} grid {GridId} in {Delay:F0} s",
                key.TenantId, key.GridId, delay.TotalSeconds);

            await Task.Delay(delay);

            if (state.IsDisposing || !_grids.ContainsKey(key)) return;

            try
            {
                var hubUrl = await GetHubUrlAsync(key.TenantId, default);

                state.IsDisposing = true;
                var old = state.Connection;
                state.Connection = BuildGridConnection(key, state, hubUrl);
                if (old != null) await old.DisposeAsync();
                state.IsDisposing = false;

                await state.Connection.StartAsync();
                _logger.LogInformation("RtmRelayService: reconnected tenant {TenantId} grid {GridId}",
                    key.TenantId, key.GridId);

                await GridInitAsync(state, key.GridId, default);
                return;
            }
            catch (Exception ex)
            {
                // Dispose connection that was started but failed init
                if (state.Connection != null)
                {
                    try { await state.Connection.DisposeAsync(); } catch { }
                    state.Connection = null;
                }
                state.IsDisposing = false;
                _logger.LogWarning(ex,
                    "RtmRelayService: reconnect attempt failed for tenant {TenantId} grid {GridId}",
                    key.TenantId, key.GridId);
                var next = delay * 2;
                delay = next > maxDelay ? maxDelay : next;
            }
        }
    }

    private async Task RunGridGraceTimerAsync((Guid TenantId, int GridId) key, GridState state, CancellationToken ct)
    {
        try { await Task.Delay(TimeSpan.FromSeconds(30), ct); }
        catch (OperationCanceledException) { return; }

        HubConnection? toDispose = null;
        await state.Lock.WaitAsync();
        try
        {
            if (state.RefCount == 0)
            {
                _grids.TryRemove(key, out _);
                toDispose = state.Connection;
                state.IsDisposing = true;
                _logger.LogInformation(
                    "RtmRelayService: disposing tenant {TenantId} grid {GridId} connection (grace period expired)",
                    key.TenantId, key.GridId);
            }
        }
        finally { state.Lock.Release(); }

        if (toDispose != null)
            await toDispose.DisposeAsync();
    }

    // ── Grid event handler ────────────────────────────────────────────────────

    private async Task HandleGridUpdateAsync(GridState state, (Guid TenantId, int GridId) key, JToken cells)
    {
        if (cells is not JArray cellsArray)
        {
            _logger.LogWarning(
                "RtmRelayService: updateGridData tenant {TenantId} grid {GridId} — unexpected payload type {Type}",
                key.TenantId, key.GridId, cells?.Type.ToString() ?? "null");
            return;
        }

        var updates = new List<GridCellUpdate>();
        List<Func<IReadOnlyList<GridCellUpdate>, Task>> handlers;

        await state.Lock.WaitAsync();
        try
        {
            foreach (var item in cellsArray)
            {
                var cellIdToken = item["CellId"];
                var valueToken = item["Value"];
                if (cellIdToken == null || valueToken == null) continue;
                var cellId = cellIdToken.Value<int>();
                var value = valueToken.Value<string>() ?? "";
                var value2 = item["Value2"]?.Value<string>();
                state.CellSnapshot[cellId] = (value, value2);
                updates.Add(new GridCellUpdate(cellId, value, value2));
            }

            handlers = state.Handlers.ToList();
        }
        finally { state.Lock.Release(); }

        if (_options.CurrentValue.DiagPushLogging)
        {
            var cellLog = string.Join(", ", updates.Select(u => u.Value2 != null ? $"Cell{u.CellId}={u.Value}|v2={u.Value2}" : $"Cell{u.CellId}={u.Value}"));
            _logger.LogInformation(
                "RECV updateGridData grid {GridId}: {Count} cells [{Cells}], {HandlerCount} handlers",
                key.GridId, updates.Count, cellLog, handlers.Count);
        }

        if (updates.Count > 0)
            await FanOutGridAsync(handlers, updates);
    }

    private static async Task FanOutGridAsync(
        List<Func<IReadOnlyList<GridCellUpdate>, Task>> handlers,
        IReadOnlyList<GridCellUpdate> updates)
    {
        foreach (var h in handlers)
        {
            try { await h(updates); }
            catch { /* subscriber handler threw */ }
        }
    }

    // ── Per-grid state ────────────────────────────────────────────────────────

    private sealed class GridState
    {
        public HubConnection? Connection;
        public bool IsDisposing;
        public readonly Dictionary<int, (string Value, string? Value2)> CellSnapshot = new();
        public readonly List<Func<IReadOnlyList<GridCellUpdate>, Task>> Handlers = new();
        public int RefCount;
        public CancellationTokenSource? GraceCts;
        public readonly SemaphoreSlim Lock = new(1, 1);
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // Compile metrics invoke (hot-reload §34 / contract §6)
    // ═══════════════════════════════════════════════════════════════════════════

    public async Task InvokeCompileMetricsAsync(Guid tenantId, IReadOnlyList<string> metricIds, CancellationToken ct = default)
    {
        if (metricIds == null || metricIds.Count == 0)
        {
            _logger.LogInformation(
                "RtmRelayService: InvokeCompileMetricsAsync called with empty metricIds for tenant {TenantId}, no-op",
                tenantId);
            return;
        }

        var hubUrl = await GetHubUrlAsync(tenantId, ct);
        _logger.LogInformation(
            "RtmRelayService: invoking compileMetrics for tenant {TenantId} with {Count} RT metric(s): [{MetricIds}]",
            tenantId, metricIds.Count, string.Join(", ", metricIds));

        // Short-lived connection for the compile invoke (rare admin operation)
        var conn = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .AddNewtonsoftJsonProtocol(opts =>
                opts.PayloadSerializerSettings.ContractResolver = new DefaultContractResolver())
            .Build();

        try
        {
            await conn.StartAsync(ct);
            // Fire-and-forget: SendAsync, not InvokeAsync (RTM-PROTO, contract §6)
            await conn.SendAsync("compileMetrics", metricIds.ToArray(), ct);
            _logger.LogInformation(
                "RtmRelayService: compileMetrics sent successfully for tenant {TenantId}",
                tenantId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "RtmRelayService: compileMetrics failed for tenant {TenantId}: {Message}",
                tenantId, ex.Message);
            throw;
        }
        finally
        {
            await conn.DisposeAsync();
        }
    }

        // ═══════════════════════════════════════════════════════════════════════════
    // Tenant lifecycle
    // ═══════════════════════════════════════════════════════════════════════════

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
}
