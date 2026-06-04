# CC Task: Fix RtmRelayService bugs + remove simulator CORS

## MANDATORY RULES (CLAUDE.md §0)

§0.3 — Edit tool BANNED. Python atomic writes only.
After EVERY write: `sync && tail -3 <path> && wc -l <path>`

§0.5 — Before every commit: `bash tools/pre-commit-check.sh` (exit 0)

---

## §0 — SESSION-RESUME (run first)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git log --oneline -1   # expected: 245ee49
git status --short
```
For every M file: `tail -3 <path>` — restore truncated with `git show HEAD:<path> > <path>`

---

## Fix 1 — RtmRelayService: append /signalr to hub URL

**File:** `src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs`

`GetHubUrlAsync` returns the raw `SignalRConnectionUrl` (e.g. `"http://localhost:5045"`).
Both `BuildUnionConnection` and `BuildGridConnection` use this directly via `.WithUrl(hubUrl)`.
But the SignalR hub is at `/signalr`, not at the root. Widgets previously appended `/signalr`
manually — the relay must do the same.

Find in `GetHubUrlAsync` (the return statement at the end):
```csharp
        // 3. Cache for 5 minutes
        await db.StringSetAsync(cacheKey, url, TimeSpan.FromMinutes(5));
        return url;
```
Replace with:
```csharp
        // 3. Normalise: append /signalr hub path (SignalRConnectionUrl stores base URL)
        if (!url.TrimEnd('/').EndsWith("/signalr", StringComparison.OrdinalIgnoreCase))
            url = url.TrimEnd('/') + "/signalr";

        // 4. Cache for 5 minutes
        await db.StringSetAsync(cacheKey, url, TimeSpan.FromMinutes(5));
        return url;
```

---

## Fix 2 — RtmRelayService: use Newtonsoft JSON protocol

**File:** `src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs`

The simulator and real RTM server both use `.AddNewtonsoftJsonProtocol()` with PascalCase.
The relay currently uses `.Build()` without specifying a protocol — defaults to System.Text.Json.
This causes a protocol mismatch on SignalR handshake.

First, check if the NuGet package is available:
```bash
dotnet list src/CcDashboard.Infrastructure package | grep -i newtonsoft
```

If `Microsoft.AspNetCore.SignalR.Protocols.NewtonsoftJson` is not listed, add it:
```bash
dotnet add src/CcDashboard.Infrastructure package Microsoft.AspNetCore.SignalR.Protocols.NewtonsoftJson
```

Add using at top of `RtmRelayService.cs` if not present:
```csharp
using Newtonsoft.Json.Serialization;
```

In `BuildUnionConnection`, find:
```csharp
        var conn = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .ConfigureLogging(b => b.SetMinimumLevel(LogLevel.Information))
            .Build();
```
Replace with:
```csharp
        var conn = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .AddNewtonsoftJsonProtocol(opts =>
                opts.PayloadSerializerSettings.ContractResolver = new DefaultContractResolver())
            .ConfigureLogging(b => b.SetMinimumLevel(LogLevel.Information))
            .Build();
```

Apply the **identical** replacement to `BuildGridConnection`.

---

## Fix 3 — Simulator: remove CORS

Simulator is now accessed server-to-server only (by RtmRelayService).
Browsers never connect to it directly. CORS is irrelevant for server-to-server HTTP.

**File:** `tools/SignalRSimulator/Program.cs`

Remove the CORS setup block (find and delete):
```csharp
// CORS origins loaded from appsettings — CcDashboard.Web URL must be listed
var corsOrigins = builder.Configuration.GetSection("CorsOrigins").Get<string[]>()
    ?? new[] { "http://localhost:5000" };

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(corsOrigins)
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
    });
});
```

Remove middleware call (find and delete):
```csharp
app.UseCors();
```

**File:** `tools/SignalRSimulator/appsettings.json`

Remove the `CorsOrigins` array:
```json
  "CorsOrigins": [
    "http://localhost:5000",
    "http://localhost:5239"
  ]
```

---

## Verification

```bash
# 1. Build
dotnet build src/CcDashboard.Infrastructure --no-restore 2>&1 | tail -3
dotnet build tools/SignalRSimulator/SignalRSimulator.csproj --no-restore 2>&1 | tail -3

# 2. /signalr appended
grep -n "signalr" src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
# Expected: line with TrimEnd('/') + "/signalr"

# 3. Newtonsoft in relay
grep -n "AddNewtonsoftJsonProtocol" src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
# Expected: 2 lines (BuildUnionConnection + BuildGridConnection)

# 4. No CORS in simulator
grep -n "Cors\|cors" tools/SignalRSimulator/Program.cs
# Expected: no output

# 5. Tests
dotnet test CcDashboard.sln 2>&1 | tail -3
```

---

## Commit

```
fix(relay): append /signalr to hub URL + Newtonsoft protocol; remove simulator CORS

- RtmRelayService.GetHubUrlAsync: normalise URL — append /signalr (base URL stored in
  SignalRConnectionUrl, hub is at /signalr path; matches prior widget behaviour)
- RtmRelayService.BuildUnionConnection + BuildGridConnection: AddNewtonsoftJsonProtocol
  (simulator and real RTM server use Newtonsoft PascalCase — relay must match)
- SignalRSimulator: remove CORS (server-to-server only; browsers no longer connect directly)
```
