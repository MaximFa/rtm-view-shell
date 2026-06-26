# CC task — DEVOPS: Soma shell-control lifecycle robustness (F-QA-3 / F-QA-4 / F-QA-7)
> §4-PASS coordinator-0623 2026-06-24T09:38:28Z — GREENLIT (v3 window OPEN; serialize with backend Ф2, one at a time). Owner devops-0619.
> Branch **v3** (Soma's current code lives there — verify by-SHA). FREE/MIT, loopback-only, auth/audit intact, NO new external surface. NO push (§37). fix: prefix.
> ⚠ SEQUENCING: AUTHOR + §4 now (non-committing). EXECUTE in the v3 tree-window AFTER backend's Ф1 commits — coordinator signals the window (single shared v3 WT).

## STEP 0 — PRE-FLIGHT
- MANDATORY READ (§40/§0.8): `.claude/skills/role-devops/role-devops.md` (§A+§C) + `.claude/skills/session-coord/session-coord.md`.
- §0.2/§0.5 object-store. Confirm Soma code path + branch by-SHA: `tools/Soma/Program.cs` on v3 (ref `git show refs/heads/v3:tools/Soma/Program.cs`, 781 ln, /shell/* at L499-561). Verify line numbers haven't drifted (Ф1 may have touched the file) before editing.
- ⚠ NARROW-ADD (L-SC-09): stage ONLY `tools/Soma/Program.cs` (+ a runbook .md if you add one). `git status --short` pre-commit = only those. Re-sync shared files from HEAD if stale. POST-COMMIT zero-deletion stat (git show --stat: no unexpected deletions).

## ROOT CAUSE (object-store confirmed, v3 Program.cs)
- L511 `/shell/start`: returns Conflict only if the TRACKED process runs; does NOT check whether port 5239 is held by an ORPHAN -> `Process.Start` -> the new Shell crashes `IOException: Failed to bind ... :5239: address already in use` (F-QA-3/7).
- L534/L536 `/shell/stop`: if tracking is lost (`trackedShellProcess` null/exited) -> NO-OP ("No tracked shell process"); the `Kill(entireProcessTree)` only kills the TRACKED tree -> an untracked orphan keeps holding 5239 (F-QA-3/7).
- L543 `/shell/restart`: same stop-then-start, same gaps.

## THE FIX (tools/Soma/Program.cs)
Add a port-based free/kill helper and wire it into stop/start/restart + a new kill-stray op. Soma is C# — implement WITHOUT a shell where possible (P/Invoke `iphlpapi.GetExtendedTcpTable` to map port->PID is preferred; if you must shell out, spawn `powershell.exe` via `ProcessStartInfo.ArgumentList` (no shell-string concat, §47) running `Get-NetTCPConnection -LocalPort 5239` and parse OwningProcess).

1. **Helper `FreeShellPort(int port = 5239)`** — returns the freed PIDs:
   - Resolve the PID(s) currently LISTENING on `port` (127.0.0.1).
   - **F-QA-4 SAFETY (mandatory):** EXCLUDE `Environment.ProcessId` (Soma's own PID) and any process that is NOT the Shell — verify by process MainModule path (the Shell exe path / project path), do NOT kill arbitrary processes. **NEVER** enumerate `Process.GetProcessesByName("dotnet")` and blanket-kill — that kills Soma itself.
   - For each remaining target PID: `proc.Kill(entireProcessTree: true); WaitForExit(10000)`. AuditLog each (`SHELL_FREE_PORT pid=...`).
2. **`/shell/stop`** (L531): keep killing the tracked tree, THEN ALWAYS call `FreeShellPort(5239)` so orphans are freed even when tracking is lost. Return `{stopped:true, freed:[pids]}` even if `trackedShellProcess` was null (no longer a pure no-op). Null tracking after.
3. **`/shell/start`** (L509): BEFORE `Process.Start`, call `FreeShellPort(5239)` (free any orphan holding the port). Keep the tracked-running Conflict guard. Then start + track.
4. **`/shell/restart`** (L543): stop (tracked + FreeShellPort) -> start (FreeShellPort first). 
5. **NEW `POST /shell/kill-stray`**: explicit recover path — `FreeShellPort(5239)` + reset `trackedShellProcess=null`; returns freed PIDs. (Adopt-or-free: lets QA/operator clear an orphan without a full stop/start.)
6. Bump `version` (L243) e.g. `2.3.0 -> 2.4.0` so a deployed Soma is identifiable as carrying the fix.

Keep the `shellLock`, auth, AuditLog, loopback bind, and all other endpoints unchanged. No new external surface.

## RECOVERY RUNBOOK (F-QA-4) — add a short note (Soma README or docs/ops)
"To free the Shell port, target PID by port (Get-NetTCPConnection -LocalPort 5239 / Soma /shell/kill-stray) — NEVER `Get-Process dotnet | Stop-Process` (that kills Soma itself). Exclude Soma's PID."

## VERIFY (build + object-store)
- `dotnet build tools/Soma` succeeds. 
- Object-store: only tools/Soma/Program.cs (+ runbook) changed; post-commit `git show --stat` shows NO unexpected deletions; FreeShellPort present + excludes Environment.ProcessId + no `GetProcessesByName("dotnet")` blanket-kill; /shell/stop calls FreeShellPort; /shell/start calls FreeShellPort before start; /shell/kill-stray added; version bumped.
- Functional (operator/QA via Soma after deploy): orphan on 5239 -> /shell/start succeeds (port freed first); tracking lost -> /shell/stop still frees 5239; Soma itself never killed.

## COMMIT (fix:, NO push) under commit.lock — NARROW ADD
`fix(soma): shell-control lifecycle — kill-by-port free 5239 on stop/start/restart + /shell/kill-stray recover path; never blanket-dotnet-kill (exclude Soma PID); fixes F-QA-3/4/7 [devops]`
then §0.6 post-commit (status clean of non-claimed; zero unexpected deletions) + §0.6b binding -> .coord/cc/devops.md + §0.7 re-sync.

## ACCEPTANCE
FreeShellPort(5239) helper (P/Invoke or no-shell), F-QA-4 safe (excludes Soma PID, no blanket dotnet-kill); stop/start/restart wired; /shell/kill-stray added; version bumped; build OK; narrow-add (only Soma file + runbook); NO push. Submit to coordinator §4 BEFORE run; EXECUTE only in the v3 window after backend Ф1.

## REPORT -> binding cc/devops.md RESULT + inbox/coordinator.md: commit hash, files, build OK, zero-deletion stat, NO push.
