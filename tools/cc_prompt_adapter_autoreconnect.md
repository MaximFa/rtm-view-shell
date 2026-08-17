# CC task — RTM.Twilio adapter AUTO-RECONNECT (per-target supervisor + backoff) — AWAITING §4-REVIEW
> Owner: backend (slug **backend-0626**). Branch **`adapters`** (worktree D:\Claude\Projects\RTMView-adapters-wt). Commit `feat:`. **NO push** (§37 — deploy+verify first). ⛔ЧП.
> Design + strategy operator-LOCKED: INFINITE retries, backoff cap 30s, reset to 1s on each successful connect. §4-REVIEW PENDING — backend-0626 self-§4 PASS; posted to inbox/coordinator.md for §4 BEFORE any run. No run until bless.

## ROOT (object-store @ `adapters` tip 8abd19a — diagnosed + blessed)
- `RTM.Twilio/RTMAdapter.cs` `ConnectTargetAsync` (~:58): `new NamedPipeClient(target.Pipe)` → wires `ConnectedToServer += Client_ConnectedToServer(target)` (per-target snapshot 8abd19a), `Disconnected += LOG-ONLY`, `await pipe.Connect()`. Fire-once — no reconnect.
- `RTM.Adapter.Common/NamedPipeClient.Connect`: Initialize → OnClientStarted → `ConnectAsync` → `OnConnectedToServer()` (fires the snapshot) → `await StartReading()` [BLOCKS until pipe breaks] → returns.
- `RTM.Adapter.Common/NamedPipeBase.StartReading` (~:41): `while(true) ReadString()`; `catch (InvalidOperationException) { OnDisconnected(); }` — ONLY that type raises Disconnected; other breaks propagate to Connect()'s `catch → Console.WriteLine` (swallow). Either way Connect() RETURNS on a break.
- ⇒ On RTM restart the pipe breaks, Connect() returns, the target stays dead → manual restart. The per-target snapshot IS wired to ConnectedToServer, so re-sync fires automatically on ANY successful (re)connect — only the reconnect is missing.

## IMPLEMENTATION (adapter-side, per-target — operator-locked)
**1. `RTM.Twilio/RTMAdapter.cs` — per-target SUPERVISOR loop (replaces the fire-once connect path):**
- Add a static `CancellationTokenSource _cts` + a `Stop()`/`Dispose()` that cancels it (wire to the adapter's existing shutdown so no runaway loop after Stop).
- `connect(IReadOnlyList<RtmTarget> targets)`: instead of `Task.WhenAll(targets.Select(ConnectTargetAsync))`, launch ONE supervisor per target: `foreach t: _ = SuperviseAsync(t, _cts.Token);` (store tasks if a clean join on Stop is wanted).
- New:
```csharp
private static async Task SuperviseAsync(RtmTarget target, CancellationToken ct)
{
    var backoff = TimeSpan.FromSeconds(1);
    while (!ct.IsCancellationRequested)
    {
        try
        {
            await ConnectAndReadAsync(target, ct);   // creates pipe, wires events, Connect() (ConnectAsync→snapshot→StartReading blocks until disconnect)
        }
        catch (OperationCanceledException) { break; }
        catch (Exception ex) { AsyncLogger.Error($"RTMAdapter.SuperviseAsync pipe={target.Pipe}", ex); }
        if (ct.IsCancellationRequested) break;
        AsyncLogger.Info($"CLIENT[{target.Pipe}] => disconnected; reconnecting in {backoff.TotalSeconds:0}s");
        try { await Task.Delay(backoff, ct); } catch (OperationCanceledException) { break; }
        backoff = TimeSpan.FromSeconds(Math.Min(backoff.TotalSeconds * 2, 30));   // cap 30s
    }
    AsyncLogger.Info($"CLIENT[{target.Pipe}] => supervisor stopped.");
}
```
- `ConnectAndReadAsync(target, ct)` = the current `ConnectTargetAsync` body (new NamedPipeClient, wire ClientStarted/ConnectedToServer/MessageReceived/Disconnected, `await pipe.Connect()`), keeping the per-target snapshot wiring (`ConnectedToServer += Client_ConnectedToServer(target)`) EXACTLY. Keep `Disconnected += log`.
- **Reset backoff to 1s on each successful connect:** in `Client_ConnectedToServer(target)` (which already fires on every connect), reset this target's backoff — simplest: add `public int ReconnectAttempt`/`TimeSpan Backoff` to `RTM.Twilio/RtmTarget.cs` and have SuperviseAsync read/write `target.Backoff` (reset to 1s in Client_ConnectedToServer). Pick the clean shape; state which. Requirement: after a successful ConnectedToServer, the NEXT disconnect's delay starts at 1s again.
- ONE supervisor per target = inherent single-loop-per-target guard (the loop owns connect+read+reconnect; the Disconnected event stays log-only). Multi-target: only the dropped target's supervisor delays+reconnects; other targets' supervisors keep running (legacy unaffected).

**2. `RTM.Adapter.Common/NamedPipeBase.cs` — HARDEN disconnect detection (StartReading):**
- Broaden the read-loop catch so `OnDisconnected()` fires on ANY pipe-break, not only InvalidOperationException:
```csharp
catch (Exception ex) when (ex is InvalidOperationException or IOException or ObjectDisposedException)
{
    OnDisconnected();
}
```
(Keep behaviour: on a broken/closed pipe, StartReading ends and OnDisconnected fires → Connect() returns → supervisor reconnects.) Do NOT change ReadString / the wire framing / message mode.

**3. §48 WIRE gate:** item 2 touches `RTM.Adapter.Common` (NamedPipeBase) → per CLAUDE.md §48 [WIRE-VALIDATION] the contract round-trip test MUST be GREEN. NO wire-FORMAT change (StreamString UTF-16 message framing, DictionarySerializer date/dict shape, Agent PascalCase DTO all untouched) — only the read-loop catch + the adapter reconnect lifecycle change.

## Mandatory — read before starting (§40/§0.8)
- CLAUDE.md **§48 [WIRE-01..05]+[WIRE-VALIDATION]**; .coord/wire_contract.md; session-coord; role-backend §A (⛔ЧП)+§C.
- Object-store grounding (git show adapters:...): RTMAdapter.cs (ConnectTargetAsync/Client_ConnectedToServer/connect), NamedPipeClient.cs (Connect), NamedPipeBase.cs (StartReading/OnDisconnected), RtmTarget.cs.

## INIT / discipline (§0.6a)
```
cd "D:\Claude\Projects\RTMView-adapters-wt"    # the adapters worktree
git rev-parse --abbrev-ref HEAD                 # MUST be adapters
git fetch origin && git rev-parse origin/adapters   # local >= origin/adapters (8abd19a)
```
If the worktree is gone: `cd "D:\Claude\Projects\RTM View Shell" && git worktree add "D:\Claude\Projects\RTMView-adapters-wt" adapters`.
- §0.3 Python+fsync; Edit BANNED. After each edit: `sync`+`tail -3`+`wc -l`+NUL(0). Preserve file EOL/encoding (Hebrew literals UTF-8 if any).
- **Claim (adapters branch)** = `["RTM.Twilio/RTMAdapter.cs", "RTM.Twilio/RtmTarget.cs", "RTM.Adapter.Common/NamedPipeBase.cs"]`. NARROW-ADD: `git add` ONLY these; post-commit `git show --stat` = only these + zero deletions, else `reset --hard HEAD~1` + STOP. commit.lock (retry 5×60s). **NO push.**

## STEP 1 — binding PREAMBLE (.coord/cc/backend.md, Python+fsync)
```
## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_adapter_autoreconnect.md | status: open
### DIRECTIVE: adapter auto-reconnect — per-target supervisor loop (INFINITE, backoff cap 30s, reset 1s on connect, CT clean-stop) in RTMAdapter.cs; harden NamedPipeBase.StartReading OnDisconnected on any pipe-break; §48 WIRE test GREEN. Claim: RTMAdapter.cs + RtmTarget.cs + NamedPipeBase.cs. gate: build 0 + WIRE 14/14. feat:.
```

## STEP 2 — implement (1)+(2). Keep per-target snapshot wiring exact; no wire-format change.

## STEP 3 — VERIFY (GREEN gate — PASTE)
- From the worktree: `dotnet build "RTM.Twilio\RTM.Twilio.csproj" -c Release` → 0 errors (report W). (Projects are at the adapters branch ROOT, no 10072026/ prefix.)
- WIRE gate: `dotnet test` the RTM.Adapter.Common.Tests → **14/14 GREEN** (§48). Report counts.
- Object-store: only the 3 claimed files; zero deletions; no serializer/DTO/framing diff (confirm `git show --stat` + that DictionarySerializer.cs/StreamString.cs/Agent.cs are UNTOUCHED).
- ⚠ ACCEPTANCE (runtime, coordinator/operator after adapter rebuild): restart RTM Service → adapter auto-reconnects (log shows "reconnecting in Ns" then "connected to server") WITHOUT an adapter restart; workgroups/users re-register (per-target snapshot); legacy target unaffected.

## STEP 4 — commit (feat:, commit.lock, NO push) — NARROW ADD
`git add` the 3 files ONLY → `git status --short` (zero unrelated) → commit `feat(adapter): auto-reconnect per-target supervisor (infinite retry, 30s backoff cap) + harden pipe-disconnect detection [backend]` → §0.6 post-commit (object-store; zero-deletion) → PD-007 re-sync → sync. **NO push.**

## STEP 5 — binding POSTAMBLE / RESULT (.coord/cc/backend.md, Python+fsync)
```
### RESULT: commit <hash> (adapters) . files RTMAdapter.cs(supervisor loop) + RtmTarget.cs(backoff) + NamedPipeBase.cs(disconnect harden) . build 0 . WIRE 14/14 GREEN . only-claimed/zero-deletion/no-format-change . status done|failed . verified: object-store . runtime reconnect-seal -> coordinator/operator after adapter rebuild
<paste build + WIRE test output>
```
Relay a 2-line digest to inbox/coordinator.md (commit + WIRE 14/14 + confirm INFINITE+30s+reset-on-connect + no wire-format change).

## ACCEPTANCE (GREEN gate)
- Per-target supervisor loop: INFINITE retries, backoff doubling capped at 30s, reset to 1s on each successful ConnectedToServer, clean stop via CancellationToken (no runaway after Stop). One supervisor per target; only the dropped target reconnects; legacy unaffected.
- Re-sync automatic via the existing per-target snapshot (unchanged). NamedPipeBase OnDisconnected fires on InvalidOperationException/IOException/ObjectDisposedException.
- §48: WIRE contract test 14/14 GREEN; DictionarySerializer/StreamString/Agent UNTOUCHED (no format change).
- build 0; 3 files; zero deletions; feat: on `adapters`; commit.lock; NO push. Binding PRE+POST.
