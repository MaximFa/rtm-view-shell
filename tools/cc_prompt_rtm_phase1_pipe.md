# CC task — PHASE 1 (RTM-only): eliminate the AgentGrid pipe drop (read-loop drain + re-accept race fix)
> §4-PASS (coordinator 2026-07-15) — RTM.Tools-only, legacy-safe. CONDITIONS: build0 on RTM.Tools AND RTM; functional seal = 140 runtime re-test (keep diag d8c239f) WITH agents online -> RECV setWorkgroups+userWorkgroupActivation + no early disconnect + AgentGrid populates; if still drops -> Phase 2. RUN-CLEARED.

## Mandatory — read before starting
Read file: .claude/skills/widget-planner/widget-planner.md
Read file: .claude/skills/widget-creator/widget-creator.md
Read file: .claude/skills/session-coord/session-coord.md
Read file: .claude/skills/role-backend/role-backend.md
Only after reading all files: proceed.

## Step 0 — INTEGRITY
cd "D:\Claude\Projects\RTM View Shell"; git status --short
For every M file: if HEAD line-count > working, `git show HEAD:"$f" > "$f"`. sync.

## Git push
Do NOT run `git push`. Commit only.

## BINDING preamble
Append to `.coord/cc/backend.md`:
`## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_rtm_phase1_pipe.md | status: open`
`### DIRECTIVE: Phase-1 RTM-only pipe hardening (drain + re-accept race). Claims: RTM/RTM.Tools/NamedPipeBase.cs, RTM/RTM.Tools/NamedPipeServer.cs. prefix fix(rtm).`

## CONTEXT (why)
On 140 the adapter connects to our RTM (rtmpipe_v3), our RTM receives ONLY the first snapshot message (setSkills) then the pipe drops (RTM.log 02:00:38-39) → union.Users empty → AgentGrid empty. TWO RTM-side defects cause/risk this:
1. Read loop blocks on the message handler: `OnMessageReceived` runs `setSkills` (21 synchronous DB upserts, ~40ms) ON the read thread → the pipe is not drained during the snapshot. Only `InvalidOperationException` is caught → any other handler exception silently kills the loop.
2. `StartReading()` uses `Task.Factory.StartNew(async …)` → it returns IMMEDIATELY (Task<Task>). Combined with the NamedPipeServer re-accept, `WaitForConnectionCallBack` re-accepts instantly and `Initialize(CreatePipe())` REASSIGNS the shared `_stream`/`Pipe` fields WHILE the background read loop is still using them → the live connection's stream is swapped out → InvalidOperationException → disconnect after the first message.

Scope: OUR RTM only (RTM/RTM.Tools). Legacy is a separate binary — untouched. Do NOT touch the adapter (RTM.Twilio / RTM.Adapter.Common), db/, src/, RTM.ININ. Phase-2 (adapter auto-reconnect) is separate.

## CLAIM (touch ONLY these)
- RTM/RTM.Tools/NamedPipeBase.cs
- RTM/RTM.Tools/NamedPipeServer.cs

## CHANGE 1 — RTM/RTM.Tools/NamedPipeBase.cs : StartReading (drain + robust + awaitable-to-completion)
Replace the current `StartReading()` body. Requirements:
- Read the pipe in a tight loop and hand each message to an ORDERED background worker so the read side NEVER blocks on the handler/DB work.
- Preserve message ORDER (single consumer).
- Survive a handler exception (log + continue) — do NOT let it kill the loop.
- The method must run to completion ONLY when the pipe actually breaks (ReadString throws), then fire OnDisconnected. Do NOT call Dispose() here (the server owns per-connection teardown + re-accept).
- Dependency-free: use `System.Collections.Concurrent.BlockingCollection<string>` (BCL) — do NOT add any NuGet package. Add `using System.Collections.Concurrent;`.

Reference implementation:
```csharp
protected async Task StartReading()
{
    var queue = new BlockingCollection<string>();
    var worker = Task.Run(() =>
    {
        try
        {
            foreach (var msg in queue.GetConsumingEnumerable())
            {
                try { OnMessageReceived(msg); }
                catch (Exception ex) { Console.WriteLine("NamedPipe handler error: " + ex); }
            }
        }
        catch { }
    });

    try
    {
        while (true)
        {
            var message = await _stream.ReadString();
            queue.Add(message);
        }
    }
    catch (Exception)
    {
        // pipe closed / broke — fall through to teardown
    }
    finally
    {
        queue.CompleteAdding();
        try { await worker; } catch { }
        OnDisconnected();
    }
}
```
(Keep the existing `OnDisconnected` / `OnMessageReceived` / `_stream` members. Only StartReading changes. Do NOT call Dispose() inside StartReading anymore.)

## CHANGE 2 — RTM/RTM.Tools/NamedPipeServer.cs : WaitForConnectionCallBack (await read-to-completion BEFORE re-accept; per-connection dispose)
Make the callback `async void`, capture THIS connection's pipe, AWAIT StartReading to completion (disconnect), dispose ONLY this connection's pipe, THEN re-accept a fresh pipe. This removes the race where re-accept reassigns `_stream`/`Pipe` under a live read.

Reference implementation:
```csharp
private async void WaitForConnectionCallBack(IAsyncResult result)
{
    var connectedPipe = Pipe;   // capture this connection
    try
    {
        connectedPipe.EndWaitForConnection(result);
        OnClientConnected();
        await StartReading();    // returns only on disconnect (read loop drains via worker)
    }
    catch (ObjectDisposedException)
    {
        return; // server stopping
    }
    catch (Exception ex)
    {
        Console.WriteLine(ex);
    }
    finally
    {
        try { connectedPipe?.Dispose(); } catch { }  // close THIS connection only
    }

    if (_stopping) return;

    try
    {
        Initialize(CreatePipe());   // fresh pipe for the NEXT client — only AFTER this one ended
        Pipe.BeginWaitForConnection(WaitForConnectionCallBack, null);
    }
    catch (ObjectDisposedException) { }
    catch (Exception ex) { Console.WriteLine(ex); }
}
```
Keep `Dispose()` (server shutdown: `_stopping=true` + Disconnect/Dispose) as-is. Do NOT set `_stopping` on a client disconnect.

## CONSTRAINTS
- OUR RTM (RTM.Tools) only. No adapter/legacy/db/src touch. No new NuGet packages. No `git push`.
- Edit via Python + os.fsync (§0.3). After each write: `sync; tail -3 <f>; wc -l <f>`.
- Preserve message ordering; do not reorder snapshot messages (setSkills → setWorkgroups → userWorkgroupActivation must arrive in order).

## ACCEPTANCE
- `dotnet build RTM/RTM.Tools` and `dotnet build RTM/RTM` = 0 errors (build0).
- grep confirms: StartReading uses BlockingCollection worker + no Dispose() call; WaitForConnectionCallBack is async void + awaits StartReading + disposes connectedPipe in finally.
- Architecture/behavior note in the binding RESULT: single-client-at-a-time preserved; re-accept happens only after disconnect.
- pre-commit-check.sh green.

## COMMIT
`bash tools/pre-commit-check.sh` -> if exit 1 restore+retry.
commit.lock (§42.4). prefix: `fix(rtm): phase-1 pipe hardening — drain read loop off-thread + await-to-completion before re-accept (eliminates AgentGrid snapshot drop)`.
NO push. Journal append + lock release + §0.7 re-sync of the 2 files from HEAD.

## BINDING postamble
Append RESULT to `.coord/cc/backend.md`: commit hash, files+line counts, build result, verified: object-store.
