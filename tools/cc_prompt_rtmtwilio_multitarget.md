# CC task — RTM.Twilio multi-target: send to MULTIPLE RTM Services (local multi-instance) per appsettings — §4 PRE-BLESSED

> Adapter (Twilio events → formalize → RTM Service, the RT data source) currently talks to ONE RTM Service. Make it fan-out to N LOCAL RTM Service instances per config. Operator decisions: (1) targets are LOCAL same-host multi-instance → NamedPipe works, per-target pipe name; (2) RTM.Twilio stays SEPARATE — NOT in v3 git, deployed separately → **NO git commit / NO push / NO barrier**. Owner: backend. Executor: native CC. Report-scoped.
> Folder: `10072026/RTM.Twilio/` (project refs ..\RTM.Tools ..\RTM.Types). §0.3 Python+fsync writes (Edit BANNED) for reliability; after each write `tail -3`+`wc -l`.

## Mandatory reads
Read: .claude/skills/session-coord/session-coord.md; .claude/skills/role-backend/role-backend.md (if present). CLAUDE.md §0.3/§0.5.

## SAFETY (no-git backstop): before editing, snapshot pristine copies
```bash
cd "D:\Claude\Projects\RTM View Shell\10072026\RTM.Twilio"
for f in RTMAdapter.cs TwilioAdapter.cs appsettings.json; do cp "$f" "$f.orig"; done
```
(These .orig are the rollback if a write truncates — there is no git for this module.)

## ARCHITECTURE (verified) — TWO channels to each RTM Service
- **Pipe = PRIMARY data channel:** 10 methods build a JSON dict (`"method"` + messageId + timeStamp) → `await client.Send(jsonData)`. RTMAdapter.cs lines: 135 setStatistic, 171 userStatusChanged, 200 userWorkgroupActivation, 234 userConfigurationChanged, 317 interactionChanged, 357 interactionRemoved, 383 setUsers, 410 setSkills, 436 setWorkgroups, 490 messageEventReceived.
- **REST:** exactly 1 — `setUsersStatusList` (L100) `HttpClient.PostAsync(RtmURL + "/SetUsersStatusList", new StringContent(data))`.
- `connect(string rtmURL)` (L65) sets RtmURL, makes HttpClient, `clientStartAsync()` (L39) → `client = new NamedPipeClient("rtmpipe")` + `client.Connect()`; `Client_ConnectedToServer` fires `ServerConnectEvent` → TwilioAdapter snapshot (TwilioAdapter.cs:312-483). Config read once: TwilioAdapter.cs:114 `RTM:RTM_URL` → :117 `RTMAdapter.connect(rtmURL)`.

## §42.6 CLAIM (file-mode) — RTM.Twilio only
- 10072026/RTM.Twilio/RtmTarget.cs (NEW)
- 10072026/RTM.Twilio/RTMAdapter.cs (MODIFY)
- 10072026/RTM.Twilio/TwilioAdapter.cs (MODIFY — config bind + snapshot reentrancy guard)
- 10072026/RTM.Twilio/appsettings.json (MODIFY — RTM:Targets list)

## THE WORK

### A. NEW RtmTarget.cs
```csharp
namespace RTM.Twilio
{
    public sealed class RtmTarget
    {
        public string Url  { get; set; }              // REST base
        public string Pipe { get; set; } = "rtmpipe"; // NamedPipe name (default keeps single-target behavior)
        public IClient Client { get; set; }           // runtime-only per-target pipe; absent from config JSON
    }
}
```
(`using RTM.Tools;` for IClient. `get;set;` so IConfiguration binds.)

### B. appsettings.json — replace the "RTM" block (keep existing url as target[0])
```json
"RTM": {
  "LogConfig": "C:\\IceDash\\RTM.Twilio\\log4net.config",
  "Targets": [
    { "Url": "http://20.80.36.234:8088", "Pipe": "rtmpipe" }
  ]
}
```
(Two instances = add `{ "Url": "http://...:8089", "Pipe": "rtmpipe2" }`. Leaving legacy RTM_URL is harmless — ignored when Targets present.)

### C. TwilioAdapter.cs — replace the RTM_URL bind + connect (around L114-117)
```csharp
var targets = _configuration.GetSection("RTM:Targets").Get<List<RtmTarget>>();
if (targets == null || targets.Count == 0)
{
    string legacyUrl = _configuration.GetValue<string>("RTM:RTM_URL");   // BACKWARD-COMPAT
    targets = string.IsNullOrWhiteSpace(legacyUrl)
        ? new List<RtmTarget>()
        : new List<RtmTarget> { new RtmTarget { Url = legacyUrl, Pipe = "rtmpipe" } };
}
RTMAdapter.ServerConnectEvent += RTMAdapter_ServerConnectEvent;
_ = RTMAdapter.connect(targets);
```

### D. TwilioAdapter.cs — make the snapshot handler reentrant (MANDATORY; it now fires per-target)
Wrap `RTMAdapter_ServerConnectEvent` (L312-483) body in a static gate:
```csharp
private static readonly SemaphoreSlim _snapshotGate = new SemaphoreSlim(1, 1);
private async void RTMAdapter_ServerConnectEvent(object sender, EventArgs e)
{
    await _snapshotGate.WaitAsync();
    try { /* … existing body unchanged … */ }
    catch (Exception ex) { AsyncLogger.Error("RTMAdapter_ServerConnectEvent", ex); }
    finally { _snapshotGate.Release(); }
}
```
(Keep the existing body exactly; just wrap it. The snapshot ops are idempotent — replace/upsert — so re-running per target is safe; a late-joining target re-triggers a full snapshot so it always gets its data.)

### E. RTMAdapter.cs — multi-target refactor
1. FIELDS (replace L11 RtmURL + L15 client; keep HttpClient L13):
```csharp
private static HttpClient HttpClient;                                       // shared, reused across URLs
private static IReadOnlyList<RtmTarget> Targets = Array.Empty<RtmTarget>();  // set once in connect()
```
2. connect (replace L65-82):
```csharp
public static async Task connect(IReadOnlyList<RtmTarget> targets)
{
    try
    {
        Targets = targets;
        var h = new HttpClientHandler();
        h.ServerCertificateCustomValidationCallback = (s,c,ch,e) => true;
        HttpClient = new HttpClient(h);
        await Task.WhenAll(Targets.Select(ConnectTargetAsync));
    }
    catch (Exception ex) { AsyncLogger.Error("RTMAdapter.connect", ex); }
}
```
3. Replace clientStartAsync (L39-62) with per-target connect + the target-aware connected handler:
```csharp
private static async Task ConnectTargetAsync(RtmTarget target)
{
    try
    {
        var pipe = new NamedPipeClient(target.Pipe);
        target.Client = pipe;
        pipe.ClientStarted     += (_, __) => AsyncLogger.Info($"CLIENT[{target.Pipe}] => started.");
        pipe.ConnectedToServer += (_, __) => Client_ConnectedToServer(target);
        pipe.MessageReceived   += (_, a)  => AsyncLogger.Info($"CLIENT[{target.Pipe}] => msg: {(a as MessageReceivedEventArgs)?.Message}");
        pipe.Disconnected      += (_, __) => AsyncLogger.Info($"CLIENT[{target.Pipe}] => disconnected.");
        await pipe.Connect();
    }
    catch (Exception ex) { AsyncLogger.Error($"RTMAdapter.ConnectTargetAsync pipe={target.Pipe}", ex); }
}
private static void Client_ConnectedToServer(RtmTarget target)
{
    AsyncLogger.Info($"CLIENT[{target.Pipe}] => connected to server.");
    ServerConnectEvent?.Invoke(null, new RtmTargetConnectedEventArgs(target));
}
```
4. Event args subclass (keep the existing delegate signature at L35-36 so TwilioAdapter compiles unchanged):
```csharp
public sealed class RtmTargetConnectedEventArgs : EventArgs
{
    public RtmTarget Target { get; }
    public RtmTargetConnectedEventArgs(RtmTarget target) => Target = target;
}
```
5. Pipe fan-out helper:
```csharp
private static async Task SendToAllAsync(string jsonData)
{
    var targets = Targets;
    await Task.WhenAll(targets.Select(async t =>
    {
        try { if (t.Client != null) await t.Client.Send(jsonData); }
        catch (Exception ex) { AsyncLogger.Error($"RTMAdapter.SendToAllAsync pipe={t.Pipe}", ex); }
    }));
}
```
6. REST fan-out helper (fresh StringContent per target — HttpContent is single-use):
```csharp
private static async Task<bool> PostToAllAsync(string endpoint, string data)
{
    var targets = Targets;
    var results = await Task.WhenAll(targets.Select(async t =>
    {
        try
        {
            var content = new StringContent(data);   // per-target; cannot reuse one HttpContent
            var response = await HttpClient.PostAsync(t.Url + endpoint, content);
            string body = await response.Content.ReadAsStringAsync();
            AsyncLogger.Info($"POST {endpoint} -> {t.Url} response={body}");
            return response.IsSuccessStatusCode;
        }
        catch (Exception ex) { AsyncLogger.Error($"RTMAdapter.PostToAllAsync url={t.Url}{endpoint}", ex); return false; }
    }));
    return results.Length > 0 && results.All(r => r);
}
```
7. CALL-SITES — pipe (replace `await client.Send(jsonData);` → `await SendToAllAsync(jsonData);`) at ALL 10 lines: 135, 171, 200, 234, 317, 357, 383, 410, 436, 490. Do NOT move the `MsgId`/`data` build into the loop — one messageId per logical event, fanned out.
8. setUsersStatusList (replace L89-113 body) → use PostToAllAsync:
```csharp
public static async Task<bool> setUsersStatusList(List<Agent> usersStatusList)
{
    try
    {
        string data = JsonConvert.SerializeObject(usersStatusList, Formatting.Indented);
        return await PostToAllAsync("/SetUsersStatusList", data);
    }
    catch (Exception ex) { AsyncLogger.Error("RTMAdapter.setUsersStatusList", ex); return false; }
}
```

## GOTCHAS (must hold)
- MsgId shared across targets = REQUIRED (same id per logical event on every target). Never regenerate per target.
- StringContent per-target (single-use HttpContent).
- One shared HttpClient across URLs (URL is per-request).
- Isolation: Task.WhenAll + per-target try/catch — one down target neither throws nor blocks others; null-check t.Client (pre-connect/down = skip, no NRE).
- No auto-reconnect added (same as today; flag as future work if needed).

## VERIFY / DoD — REPORT NUMBERS
- **Object-store:** RtmTarget.cs created; Targets list replaces RtmURL/client; connect(IReadOnlyList<RtmTarget>); ConnectTargetAsync per-target; SendToAllAsync + PostToAllAsync present; ALL 10 pipe call-sites → SendToAllAsync; setUsersStatusList → PostToAllAsync; TwilioAdapter binds RTM:Targets (+RTM_URL fallback) + snapshot SemaphoreSlim guard; appsettings RTM:Targets.
- **Build — REPORT NUMBERS:** `dotnet build 10072026/RTM.Twilio/RTM.Twilio.csproj -c Release` = **0 errors** (report warnings). If FAILS → report verbatim, do NOT claim done.
- **Backward-compat:** single-element Targets (or legacy RTM_URL fallback) → one pipe "rtmpipe" + one URL, snapshot once — behavior identical to today.
- On success: remove the *.orig backups (`rm *.orig`) ONLY after build 0.

## NO git commit / NO push / NO barrier (RTM.Twilio is separate, deployed independently — operator decision). Report build 0 + object-store + the changed file list to inbox/coordinator.md.
