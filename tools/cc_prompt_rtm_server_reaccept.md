# CC task — RTM NamedPipeServer RE-ACCEPT loop (reconnect fix, server side) — AWAITING §4
> Owner: backend (backend-0626). Branch **v3**. Commit `rtm:`. **NO push** (§37). ⛔ЧП. Batches with BU/SG live-pickup into ONE RTMService rebuild.
> §4 PENDING — self-§4 PASS; posted to inbox/coordinator.md.

## ROOT (object-store @ v3)
`RTM/RTM.Tools/NamedPipeServer.cs` `Start()` is SINGLE-ACCEPT: `Pipe.BeginWaitForConnection(WaitForConnectionCallBack)` ONCE (:37); `WaitForConnectionCallBack` (:47) EndWaitForConnection → OnClientConnected → `StartReading().GetAwaiter().GetResult()` (blocks until client drops) → returns. NOTHING re-calls BeginWaitForConnection ⇒ after a client (adapter) disconnects, the server never re-accepts. (For OUR-RTM-RESTART the server is fresh so single-accept works once; the re-accept loop adds robustness for transient client drops + stop→start pipe races — coordinator ruled it my call: I recommend YES.)

## FIX — re-accept loop
`WaitForConnectionCallBack`: after `StartReading()` returns (client dropped), loop back to accept the next client. Pattern:
```csharp
private void WaitForConnectionCallBack(IAsyncResult result)
{
    try
    {
        Pipe.EndWaitForConnection(result);
        OnClientConnected();
        StartReading().GetAwaiter().GetResult();   // blocks until this client disconnects
    }
    catch (Exception ex) { Console.WriteLine(ex); }
    finally
    {
        // RE-ACCEPT: reset the pipe + wait for the next client (unless disposed/stopping)
        try
        {
            if (Pipe != null)
            {
                if (Pipe.IsConnected) Pipe.Disconnect();
                Pipe.BeginWaitForConnection(WaitForConnectionCallBack, null);
            }
        }
        catch (ObjectDisposedException) { /* server stopping — do not re-accept */ }
        catch (Exception ex) { Console.WriteLine(ex); }
    }
}
```
- Keep `MaxAllowedServerInstances`. If `NamedPipeServerStream` cannot be reused after Disconnect on this platform, instead create a FRESH `NamedPipeServerStream` (same params as Start()) via a small helper and BeginWaitForConnection on it — verify at build which works; state it. Do NOT change PipeTransmissionMode.Message / params (wire framing unchanged).
- Dispose() must stop the loop cleanly (a stopping flag or the ObjectDisposedException guard) — no re-accept after Dispose.

## Mandatory reads (§40/§0.8): session-coord; role-backend §A(⛔ЧП)+§C; object-store RTM.Tools/NamedPipeServer.cs + NamedPipeBase.StartReading.
## INIT (§0.6a): cd repo; HEAD==v3 (SHA); hash-verify claim vs HEAD; §0.3 Python+fsync; Edit BANNED. Claim(file-mode)=["RTM/RTM.Tools/NamedPipeServer.cs"]. NARROW-ADD; commit.lock 5×60s; §0.6 post-commit; §0.7 re-sync; **NO push**.
## STEP 1 binding PREAMBLE (.coord/cc/backend.md): `## BINDING <UTC> | spec: backend | directive: tools/cc_prompt_rtm_server_reaccept.md | status: open` + directive line.
## STEP 2 implement re-accept loop. STEP 3 VERIFY: dotnet build the RTM project 0 err (report). object-store: only NamedPipeServer.cs, zero deletions. STEP 4 commit `rtm: NamedPipeServer re-accept loop (accept next client after drop) - adapter reconnect [backend]`, commit.lock, cc_post_commit, NO push. STEP 5 binding RESULT.
## ACCEPTANCE: server re-accepts a new client after the previous drops (BeginWaitForConnection re-armed in finally); Dispose stops cleanly; no framing/param change; build 0; 1 file; NO push. Live gate (with the client timeout prompt): restart OUR RTMService → adapter reconnects rtmpipe_v3.
