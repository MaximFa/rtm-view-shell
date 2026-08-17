# CC task — adapter NamedPipeClient CONNECT TIMEOUT (reconnect fix, client side) — AWAITING §4
> Owner: backend (backend-0626). Branch **`adapters`** (worktree D:\Claude\Projects\RTMView-adapters-wt). Commit `fix:`. **NO push** (§37). ⛔ЧП. 6ebd39f follow-up.
> §4 PENDING — self-§4 PASS; posted to inbox/coordinator.md.

## ROOT (object-store @ adapters 6ebd39f)
`RTM.Adapter.Common/NamedPipeClient.Connect` (:28) does `await Pipe.ConnectAsync()` (:36) with NO timeout → against a non-listening server it HANGS FOREVER, so the SuperviseAsync loop never reaches its backoff/retry (stuck in ConnectAndReadAsync). PRIMARY reconnect requirement (coordinator): the rtmpipe_v3 target must reliably re-attempt + reconnect when OUR RTMService comes back.

## FIX — bounded connect + threaded cancellation
1. `RTM.Adapter.Common/NamedPipeClient.cs` — give Connect a CancellationToken + timeout:
```csharp
public async Task Connect(CancellationToken ct = default)
{
    Initialize(new NamedPipeClientStream(".", _name, PipeDirection.InOut, PipeOptions.Asynchronous));
    try
    {
        OnClientStarted();
        await Pipe.ConnectAsync(ConnectTimeoutMs, ct);   // was ConnectAsync() — bounded so a stalled connect returns
        Pipe.ReadMode = PipeTransmissionMode.Message;
        OnConnectedToServer();
        await StartReading();
    }
    catch (OperationCanceledException) { throw; }          // propagate cancellation to the supervisor
    catch (TimeoutException) { AsyncLogger.Info($"CLIENT[{_name}] => connect timeout ({ConnectTimeoutMs}ms)"); }
    catch (Exception ex) { AsyncLogger.Error($"CLIENT[{_name}] => connect/read error", ex); }
}
```
- `ConnectTimeoutMs` = a const (e.g. 5000) or configurable; state it. On timeout/error Connect returns → ConnectAndReadAsync returns → SuperviseAsync backs off + retries (its existing loop). (If AsyncLogger isn't referenced in Common, keep Console.WriteLine or add the using — do NOT change any serializer/framing.)
- Do NOT change StreamString / ReadString / message-mode / DictionarySerializer / Agent DTO — wire FORMAT untouched.
2. `RTM.Twilio/RTMAdapter.cs` `ConnectAndReadAsync` — pass the supervisor's ct: `await pipe.Connect(ct);` (was `pipe.Connect()`).

## §48 WIRE: touches RTM.Adapter.Common (NamedPipeClient — a LIFECYCLE method, not the format) → run the contract round-trip test **14/14 GREEN**; DictionarySerializer/StreamString/Agent UNTOUCHED.
## Mandatory reads (§40/§0.8): CLAUDE.md §48; session-coord; role-backend §A(⛔ЧП)+§C; object-store NamedPipeClient.cs + RTMAdapter.SuperviseAsync/ConnectAndReadAsync.
## INIT (§0.6a): cd worktree; HEAD==adapters (SHA, >=6ebd39f); §0.3 Python+fsync; Edit BANNED. Claim=["RTM.Adapter.Common/NamedPipeClient.cs","RTM.Twilio/RTMAdapter.cs"]. NARROW-ADD; commit.lock; NO push.
## STEP 1 binding PREAMBLE. STEP 2 implement. STEP 3 VERIFY: dotnet build RTM.Twilio Release 0 err + WIRE test 14/14 GREEN (PASTE); object-store only 2 files, zero deletions, no format diff. STEP 4 commit `fix(adapter): bounded ConnectAsync timeout so supervisor retries (reconnect to our RTM) [backend]`, commit.lock, NO push. STEP 5 binding RESULT (+ WIRE counts).
## ACCEPTANCE: ConnectAsync bounded by timeout + ct-cancellable; on stall it returns → supervisor backs off + retries; §48 WIRE 14/14; no format change; build 0; 2 files; NO push. LIVE gate: restart OUR RTMService only (legacy untouched) → adapter reconnects rtmpipe_v3 (log 'connected' + re-register), legacy feed uninterrupted.
