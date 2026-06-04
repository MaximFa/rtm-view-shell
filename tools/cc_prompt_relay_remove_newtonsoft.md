# CC Task: Remove AddNewtonsoftJsonProtocol from RtmRelayService connections

## MANDATORY RULES (CLAUDE.md §0)

§0.3 — Edit tool BANNED. Python atomic writes only.
After EVERY write: `sync && tail -3 <path> && wc -l <path>`
§0.5 — Before commit: `bash tools/pre-commit-check.sh` (exit 0)

---

## §0 — SESSION-RESUME (run first)

```bash
cd "D:\Claude\Projects\RTM View Shell"
git log --oneline -1
git status --short
```

---

## Root Cause — widgets connected but no data

`RtmRelayService.BuildUnionConnection` and `BuildGridConnection` use:
  `conn.On<JsonElement>(...)` — handler type is System.Text.Json JsonElement

But in commit 1473000 we added `.AddNewtonsoftJsonProtocol(...)` to both builders.
When Newtonsoft is the client protocol, it tries to deserialize the incoming JSON
into `JsonElement` — a System.Text.Json type that Newtonsoft cannot produce.
Result: handler fires but receives an empty/invalid JsonElement → ValueKind != Array
→ early return → no data processed → widget shows "—".

Fix: remove `.AddNewtonsoftJsonProtocol(...)` from both connection builders.
System.Text.Json parses Newtonsoft-formatted PascalCase JSON correctly
(TryGetProperty("CellId") works fine with PascalCase keys regardless of serializer).

---

## File: src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs

### Change 1 — BuildUnionConnection: remove Newtonsoft

Find:
```csharp
        var conn = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .AddNewtonsoftJsonProtocol(opts =>
                opts.PayloadSerializerSettings.ContractResolver = new DefaultContractResolver())
            .ConfigureLogging(b => b.SetMinimumLevel(LogLevel.Information))
            .Build();
```
Replace with:
```csharp
        var conn = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .ConfigureLogging(b => b.SetMinimumLevel(LogLevel.Information))
            .Build();
```

### Change 2 — BuildGridConnection: same removal

Find the second identical block (in BuildGridConnection) and apply the same replacement.

### Change 3 — remove unused using (if present)

If the file has:
```csharp
using Newtonsoft.Json.Serialization;
```
Remove it.

---

## Verification

```bash
dotnet build src/CcDashboard.Infrastructure --no-restore 2>&1 | tail -3
# Expected: Build succeeded. 0 Error(s).

grep -n "AddNewtonsoftJsonProtocol" \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs
# Expected: no output

grep -n "JsonElement\|On<" \
  src/CcDashboard.Infrastructure/RtmRelay/RtmRelayService.cs | head -10
# Expected: JsonElement still there — only Newtonsoft removed
```

---

## Commit

```
fix(relay): remove AddNewtonsoftJsonProtocol from connection builders

Relay uses On<JsonElement> handlers (System.Text.Json). Newtonsoft protocol
cannot deserialize into JsonElement → cells.ValueKind = Undefined → data
silently dropped. System.Text.Json parses PascalCase JSON from RTM server
correctly without Newtonsoft on the client side.
```
