# CC task — RTM.Adapter.Common: extract MINIMAL RTM-independent adapter lib + re-point RTM.Twilio + WIRE contract test — §4 PRE-BLESSED

> Operator-approved: adapters carry a MINIMAL adapter-specific lib (RTM.Adapter.Common), NOT a fork of full RTM.Tools/RTM.Types. Analysis verified: adapter uses 9 files, ZERO RTM-core coupling. WIRE format stays a contract (CLAUDE.md §48 [WIRE-01..05]). Owner: backend. Native CC. Work in `10072026/` (adapter solution, NOT v3 yet — branch commit is a SEPARATE follow-up). §0.3 Python+fsync. Report-scoped.

## Mandatory reads
Read: CLAUDE.md **§48 [WIRE-01..05] + [WIRE-VALIDATION]** (the contract this guards); .coord/wire_contract.md; session-coord.
Read: 10072026/RTM.Twilio/RTM.Twilio.csproj (current refs), 10072026/RTM.Tools/, 10072026/RTM.Types/.

## SAFETY snapshot (no git for 10072026 yet)
```bash
cd "D:\Claude\Projects\RTM View Shell\10072026"
[ -d "RTM.Twilio.orig-preextract" ] || cp -r RTM.Twilio RTM.Twilio.orig-preextract
```

## THE WORK

### A. Create the minimal lib `10072026/RTM.Adapter.Common/`
- New `RTM.Adapter.Common.csproj` (net8.0 classlib, Nullable enable, ImplicitUsings enable). NuGet: `log4net`, `Newtonsoft.Json` (match versions used by 10072026/RTM.Tools).
- COPY these 9 .cs files VERBATIM into it (keep their EXISTING namespaces `RTM.Tools` / `RTM.Types` — do NOT rename, so adapter `using RTM.Tools;`/`using RTM.Types;` still resolve):
  from 10072026/RTM.Tools/: `AsyncLogger.cs`, `DictionarySerializer.cs`, `IPCConnection.cs`, `NamedPipeBase.cs`, `NamedPipeClient.cs`, `StreamString.cs`
  from 10072026/RTM.Types/: `Agent.cs`, `Interaction.cs`, `Reservation.cs`
- Do NOT copy: DBAdapter.cs, NamedPipeServer.cs, WindowsServiceHelper.cs, NGCLog.cs (RTM.Tools); Site.cs, Statistic.cs, StatisticParameter.cs, and any other RTM.Types file (adapter doesn't use them).
- ⚠ VERIFY the copied set COMPILES standalone (transitive closure): IPCConnection→(IClient/IServer/MessageReceivedEventArgs), NamedPipeClient→NamedPipeBase→StreamString, Interaction→Reservation. If IPCConnection.cs bundles IServer and it references nothing external, keep it as-is (harmless). If any copied file references a NOT-copied type → report it (means the closure is bigger than analysis said).

### B. Re-point 10072026/RTM.Twilio/RTM.Twilio.csproj
- REMOVE: `<ProjectReference Include="..\RTM.Tools\RTM.Tools.csproj" />` and `..\RTM.Types\RTM.Types.csproj`.
- ADD: `<ProjectReference Include="..\RTM.Adapter.Common\RTM.Adapter.Common.csproj" />`.
- Keep the 4 PackageReferences unchanged.
- NO change to any RTM.Twilio .cs (namespaces preserved → source untouched).

### C. WIRE contract test — [WIRE-VALIDATION] guard (10072026/RTM.Adapter.Common.Tests/ or a test in the adapter solution)
Add an xUnit test project referencing RTM.Adapter.Common. Assert the format contract (CLAUDE.md §48):
- [WIRE-02] `DictionarySerializer.SerializeToJson(new Dictionary<string,object>{{"d", new DateTime(2026,7,11,8,4,5,DateTimeKind.Utc)}})` → the date renders with format `yyyy-MM-ddTHH:mm:ss.fffffffK` (assert the substring/pattern).
- [WIRE-01] a representative `userStatusChanged` dict (method+userId+statusId+...+messageId as string) round-trips through `SerializeToJson` then `DictionarySerializer` deserialize helpers (getString/getBool/...) back to the same values, case-sensitive keys.
- [WIRE-03] `JsonConvert.SerializeObject(new List<Agent>{ new Agent{ UserId="u1", DisplayName="d" } })` contains PascalCase `"UserId"` and `"DisplayName"` (assert property names present, not camelCase).
Test must PASS. (Full cross-copy round-trip vs RTM Service copy = the v3-side mirror test, separate; this guards the ADAPTER side format.)

## VERIFY / DoD — REPORT NUMBERS
- **Object-store:** RTM.Adapter.Common.csproj + exactly the 9 files (namespaces preserved); RTM.Twilio.csproj re-pointed (no ..\RTM.Tools/..\RTM.Types, +..\RTM.Adapter.Common); WIRE test present.
- **Build — REPORT NUMBERS:** `dotnet build "10072026\RTM.Twilio\RTM.Twilio.csproj" -c Release` = **0 errors** (report W). Then `dotnet build` the test proj + `dotnet test` = the WIRE test PASSES (report counts). If the minimal lib is INSUFFICIENT (missing-type compile error) → report the exact missing type verbatim + STOP (closure bigger than analysis).
- Confirm RTM.Twilio no longer references RTM.Tools/RTM.Types projects (only RTM.Adapter.Common).

## NO git commit / NO branch yet (branch `adapters` creation + commit = SEPARATE follow-up after this is green). NO push.
## Report → inbox/coordinator.md: build 0/W, WIRE test pass/fail counts, the final file list of RTM.Adapter.Common, any closure surprise.
