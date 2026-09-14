# CC PROMPT — R4 · `PR234-ADPT-SUPERVISOR-01`: `StartReading()` returns before it reads

> Author: devops-0912, 2026-09-13. Target branch: **`adapters`** (NOT `v3`).
> Status: awaiting coordinator §4 review. **Does NOT go to build** until the shell and backend fixes
> are ready — one canonical rebuild carries all three.

## 0. NORMS THIS PROMPT CARRIES INSIDE ITSELF (read them here; do not go looking)

`CLAUDE.md` is 146 207 characters against a 40 000-character read limit, so a CC session does NOT have
it whole in context and MUST NOT assume any section of it is loaded (`CLAUDE-OVERSIZE-01`). Everything
this task needs is stated below.

1. **Object store is the truth.** Facts about code come from `git show` / `git cat-file` / `git hash-object`,
   never from the working tree and never from memory. State the sha of anything you assert.
2. **NO push.** Commit only. The push barrier is the coordinator's; you do not cross it, and you do not
   ask the operator to.
3. **One unit of work, one commit.** Do not bundle unrelated files. Do not reformat. Do not "tidy" nearby
   code. The diff must be readable as one decision.
4. **Preserve file encoding byte-for-byte.** `RTM.Adapter.Common/NamedPipeBase.cs` starts with a UTF-8 BOM
   (`EF BB BF`). After editing, verify the first three bytes are still `EF BB BF` and that you did not
   change the file's line-ending style. Verify by BYTES, never by line count.
5. **Test-gate.** In a multi-project solution, building the app does NOT run the tests — they are separate
   targets. A green gate needs an ACTUAL test run with COUNTS (`failed=0`). A missing test result is a
   HARD STOP, not a pass. If a public signature changes, its tests change in the SAME commit.
6. **Local-validation gate.** Object store proves WHAT shipped; only a run on the real app proves it WORKS.
   You are NOT performing the local validation here — that is devops on server 234, after the canonical
   rebuild. Do not claim the fix is verified in production; say exactly what you proved.
7. **Report what you did NOT prove.** An unproven step named is cheap; an unproven step implied is a defect.

## 1. THE DEFECT, pinned

File: `RTM.Adapter.Common/NamedPipeBase.cs`, blob `72df66c93fdfb037933267af3fb250b460e5f0a5`
at `adapters = aa19743`, lines 41-59, method `StartReading()`.

```csharp
protected async Task StartReading()
{
    await Task.Factory.StartNew(async () =>
    {
        try
        {
            while (true)
            {
                var message = await _stream.ReadString();
                OnMessageReceived(message);
            }
        }
        catch (Exception ex) when (ex is InvalidOperationException or System.IO.IOException or ObjectDisposedException)
        {
            OnDisconnected();
            Dispose();
        }
    });
}
```

`Task.Factory.StartNew` with an `async` lambda returns `Task<Task>`: the OUTER task completes as soon as
the lambda hits its first `await`, and the INNER task — the actual read loop — is never awaited and never
observed. So `await StartNew(...)` awaits the wrong task, `StartReading()` returns almost immediately, and
its single caller treats that as "reading finished".

Caller, same revision — `RTM.Adapter.Common/NamedPipeClient.cs:44`:

```csharp
await StartReading();
```
inside `Connect()`. When `StartReading()` returns early, `Connect()` returns, and the auto-reconnect
supervisor added by `6ebd39f` reads that as a finished connection and reconnects on top of a pipe that is
still being read by the orphaned inner task. `fc51ae0` did not introduce the defect — it made a latent
defect active by adding the supervisor that reacts to the early return.

**The engine's own copy of this class does NOT have the defect** — `v3:RTM/RTM.Tools/NamedPipeBase.cs`,
`StartReading()`: it runs the read loop inline, hands messages to a `BlockingCollection` worker, and
completes the worker in a `finally`. That is the reference shape and the proof this is a divergence bug,
not a design choice.

## 2. THE CHANGE — minimal, and nothing else

In `RTM.Adapter.Common/NamedPipeBase.cs`, `StartReading()`: **await the read loop itself.** Remove the
`Task.Factory.StartNew` wrapper so the method does not return until the loop ends, keeping the existing
`catch` filter and the existing `OnDisconnected()` + `Dispose()` teardown exactly as they are:

```csharp
protected async Task StartReading()
{
    try
    {
        while (true)
        {
            var message = await _stream.ReadString();
            OnMessageReceived(message);
        }
    }
    catch (Exception ex) when (ex is InvalidOperationException or System.IO.IOException or ObjectDisposedException)
    {
        OnDisconnected();
        Dispose();
    }
}
```

**Deliberately OUT OF SCOPE, do not do it in this commit:** adopting the engine's queue+worker shape;
broadening the `catch` filter; touching `Connect()`, the supervisor, `ConnectTimeoutMs`, logging, or any
other file. Those are separate decisions and a mixed diff cannot be reviewed.

**Do not change** `RTM/RTM.Tools/NamedPipeBase.cs` on `v3` — it is already correct.

## 2b. WHERE YOU WORK — read this before touching anything

The main clone `D:\Claude\Projects\RTM View Shell` is on `v3` and carries **15 untracked probe files**
that belong to the second unit of work below. **Do NOT switch its branch** — a checkout drags those
untracked files across and mixes the two units.

`adapters` already has its own worktree: `D:\Claude\Projects\RTMView-adapters-wt`, at `aa19743`
[measured: `git worktree list`]. Do the C# change THERE. Confirm before editing:
**`cd` into that directory first and run the checks from INSIDE it**, not with `git -C` from elsewhere:
`git rev-parse --abbrev-ref HEAD` -> `adapters`, `git rev-parse HEAD` -> `aa19743...`, and
`git status --short` -> report verbatim, whatever it prints.
If the worktree is missing or not on `adapters`, STOP and report - do not improvise a checkout in the
main clone, and do NOT run `git worktree prune` or `git worktree add` without the coordinator's word.
One reason the checks must come from inside: a `git worktree list` taken through the remote bridge
prints `prunable` for this worktree and three others, but that listing is produced from a Linux VM to
which `D:\...` paths do not exist at all. `prunable` there may describe the OBSERVER, not the world -
the same class of mistake as reading another system's log as your own. Your run is native on Windows
and can settle it by measurement.

**Order: the `v3` probe commit FIRST, in the main clone; the adapter fix SECOND, in the worktree.**
That way the main clone is clean before anything else happens to it.

## 2c. ENTRY AND EXIT PREDICATES — a run can claim "already done" for work that never happened

Before you change anything, print and check: the branch name, `HEAD` sha, and the sha256 (or
`git hash-object`) of `RTM.Adapter.Common/NamedPipeBase.cs` on disk. If the file already differs from
blob `72df66c9…`, the change may be half-applied by an earlier run — STOP and report the difference
instead of editing on top of it.
After the commit, print the same three values again plus the new sha. Numbers from a build that did not
happen are indistinguishable from numbers from one that did, unless the before/after pair is shown.

## 2d. THE COMMIT COMMAND ITSELF — argument order is part of the guard

`git commit -- <path> -m "..."` is WRONG: after `--` git treats everything as pathspec, including `-m`
and the message text, and the command fails with `pathspec '-m' did not match any file(s)`. Worse, a
different argument order can succeed while committing something other than intended.

**Correct form — pathspec LAST:**
```
git commit -m "subject line" -m "body paragraph" -- "RTM.Adapter.Common/NamedPipeBase.cs"
```
Equally correct and already proven: `git add -- "<path>"` followed by `git commit -m "..."`. Do not
"improve" a working form by merging it with another.
A protective construct must itself be checked for executability: "I wrote a pathspec" and "the pathspec
took effect" are different claims. Prove it with `git show <sha> --stat` — exactly one file.

## 3. GATES — run them and report the numbers, do not summarize them

1. `git rev-parse --abbrev-ref HEAD` — must be `adapters`. Wrong branch = stop, report, change nothing.
2. `git rev-parse adapters` BEFORE the change — record it.
3. Build the solution that contains `RTM.Adapter.Common`. Report errors and warnings as COUNTS.
4. **Test-gate:** run the test project(s) and report `total / passed / failed`. `failed` must be 0. If no
   test project covers this library, say so in exactly those words — "no test project covers
   RTM.Adapter.Common" — and do not call the gate green.
5. Byte check after the edit: first three bytes of `RTM.Adapter.Common/NamedPipeBase.cs` are `EF BB BF`;
   the file contains no NUL bytes; report its size before and after.
6. `git show <new-sha> --stat` — expect exactly ONE file changed.
7. `git grep -n 'Task.Factory.StartNew' aa19743 -- '*.cs'` and the same on your new commit: report both
   counts. The count must drop by exactly one, and any remaining occurrence must be named with its file
   and line so the coordinator can judge it.

## 4. COMMIT

One commit on `adapters`, no push. Message:

```
fix(adapter): await the pipe read loop itself - StartReading returned before it read

Task.Factory.StartNew with an async lambda returns Task<Task>: awaiting it awaited the
outer task, which completes at the first await inside the lambda, so StartReading()
returned while the read loop was still running unobserved. Connect() then returned and
the auto-reconnect supervisor (6ebd39f) reconnected over a pipe that was still being
read. fc51ae0 did not introduce this - it made a latent defect active.
The engine's copy of the same class (v3:RTM/RTM.Tools/NamedPipeBase.cs) never had it.
```

## 5. REPORT BACK

Give the coordinator: the sha before, the sha after, the one-file `--stat`, build counts, test counts
(or the explicit "no test project covers ..." sentence), the byte check, and the two
`Task.Factory.StartNew` counts. Then stop. **Do not deploy, do not push, do not touch server 234.**

---

# SECOND, SEPARATE UNIT — 15 probes missing from `v3`

The coordinator asked for the probes in "the same commit". **That is not possible and here is why:** the
fix above lives on `adapters`, the probes live on `v3`. One commit cannot span two branches. So this is a
second commit, on `v3`, and it must not be mixed with the fix.

The set is named, not inferred from a count — a difference of totals gives a number but not a membership
(`121 - 107 = 14` is equally consistent with "20 extra on disk, 6 missing"). Measured with
`comm -13 <sorted tree list> <sorted disk list>`, which yields 15 files, all additions, nothing missing
from disk:

```
probe_234_20260913_addgrid-exception.ps1   probe_234_20260913_resub-v2.ps1
probe_234_20260913_early-ask.ps1           probe_234_20260913_resub-v3.ps1
probe_234_20260913_engine-predicate.ps1    probe_234_20260913_resub-v4.ps1
probe_234_20260913_flag-on.ps1             probe_234_20260913_resub-v5.ps1
probe_234_20260913_literals.ps1            probe_234_20260913_resub-v6.ps1
probe_234_20260913_ours-only.ps1           probe_234_20260913_resub-v7.ps1
probe_234_20260913_provenance.ps1          probe_234_20260913_resub.ps1
probe_234_20260913_whose-log.ps1
```

Add exactly these 15 under `.probes/`, on `v3`, in the MAIN CLONE, one commit, no push, and use the
pathspec-last form from section 2d (`git add -- ".probes/<file>"` per file, then one `git commit -m`). They are instruments, not
measurements: a measurement file must NEVER be committed — `.measurements/` holds live customer data and
is git-ignored on purpose. Before committing, confirm no `.measurements/` path is staged and report that
check explicitly.

Message:

```
devops(probes): track the 15 instruments of the 13 September Shell/engine diagnosis

A measurement is not reproducible without the instrument that took it, and these were
rewritten repeatedly during the cycle - each version fixing the previous one's defect.
The set is named by comm(tree, disk), not by a count difference: a difference gives a
number, never a membership.
```
