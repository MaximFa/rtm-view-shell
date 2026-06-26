# CC Task — fix(soma): F-QA-4 ROOT — /ops/test must NEVER kill Soma (kill-guard hardening + forensics)

> Branch: **v3** · Role: **devops** · Commit prefix: **fix:** · NO push (§37)
> Author: devops-0624 · **§4-REVIEW: PASS** (coordinator-0624 2026-06-25T06:00Z). HONESTY-FLAG RULING: SHIP THE HARDENING NOW — do NOT gate on a diagnostic-first build. The fail-closed guard is strictly safe (it only ADDS protection: protectedPids skip + test-infra skip + tighter port/path Shell-match — it can NEVER make /ops/test more dangerous to Soma, only less), and the forensic KILL_SKIP/kill AuditLog captures the actual mechanism on the next /ops/test regardless. "kill-guard hardening" (not a fabricated root cause) is the correct framing. Verified the code refs match object-store (FreeShellPort L134 ==dotnet, somaPid L98, FreeShellByPath L150-165, FreeShellOrphans). All process blocks present; freeze-check uses -s (L-SC-10). CLEARED TO RUN (PRIORITY — unblocks unit channel).
> Priority: PRIORITY (blocks QA unit channel + shell Ф5b-1 DoD — both run /ops/test). NON-barrier.

---

## STEP 0 — MANDATORY (do not skip)

### 0a. Mandatory reads (§40 / §0.8 / NORM-CUR-11)
- `.claude/skills/session-coord/session-coord.md`
- `.claude/skills/role-devops/role-devops.md` (§A CORE + §C VERIFY)

### 0b. Branch + integrity (object-store, NOT mount git status)
```bash
cd "D:\Claude\Projects\RTM View Shell"
git checkout v3
cat .git/refs/heads/v3                       # note SHA (tip moves; tools/Soma last @eeacd76)
git hash-object tools/Soma/Program.cs
git rev-parse HEAD:tools/Soma/Program.cs     # if differs -> git show HEAD:tools/Soma/Program.cs > tools/Soma/Program.cs
git hash-object tools/Soma/USAGE.md
git rev-parse HEAD:tools/Soma/USAGE.md       # re-sync from HEAD if differs (L-SC-09)
```

### 0c. Freeze check
```bash
[ -s .coord/push/request.md ] && { echo "PUSH BARRIER ACTIVE — STOP"; exit 1; } || echo "no freeze, proceed"   # -s ignores phantom zero-byte dirents (L-SC-10)
```

### 0d. Binding PREAMBLE — append to `.coord/cc/devops.md` (Python + os.fsync)
```
## <UTC> | binding: devops <-> CC | directive: tools/cc_prompt_devops_soma_fqa4_killguard.md | status: open
### DIRECTIVE: F-QA-4 root — harden Soma kill-helpers so /ops/test can NEVER kill Soma or its test tree (fail-closed self-protect + forensics). Claims: tools/Soma/Program.cs, tools/Soma/USAGE.md. Prefix: fix:.
```

---

## CONTEXT — what F-QA-4 is

QA confirmed (2nd occurrence @463ea56): POST `/ops/test?suite=unit` correlates with Soma going
DOWN (Soma `/health` on :5199 connection-refused after tab-reload). `/ops/build` alone does NOT
kill Soma — specific to the `/ops/test` path. Coordinator escalated to PRIORITY (01:00 directive):
it blocks the QA unit channel and shell Ф5b-1 unit DoD.

**Honest root-cause status:** the EXACT kill mechanism is NOT statically provable from the source.
`FreeShellOrphans()` runs only at the START of `/ops/test` (before `dotnet test` spawns testhost),
and Soma listens on 5199 (not the 5239 that `FreeShellPort` scans), so by static reading Soma
should not be caught — yet QA observes it dying. Therefore this fix is **fail-closed defense-in-depth
+ forensic instrumentation**: make Soma (and the test process tree) STRUCTURALLY unkillable by these
helpers, and log every kill/skip decision so the NEXT `/ops/test` run gives a definitive audit trail.
Do NOT fabricate a single root cause in the commit message — describe it as kill-guard hardening.

## CURRENT CODE (tools/Soma/Program.cs, v3) — the two kill helpers

- `FreeShellPort(int port = 5239)` (~L95–147): runs PowerShell `Get-NetTCPConnection -LocalPort 5239
  -State Listen`, filters `pid != somaPid` (somaPid = `Environment.ProcessId`, L98), then for each pid
  kills if `exeName == "dotnet" || exeName.Contains("ccdashboard")` (**L134 — the broad `=="dotnet"`
  gate the coordinator flagged**) via `target.Kill(entireProcessTree: true)`.
- `FreeShellByPath()` (~L151–196): enumerates all processes, matches procName containing
  `ccdashboard.web`/`ccdashboard`, verifies MainModule path contains `ccdashboard`/`bin\debug`/
  `bin\release`/`publish`, excludes `somaPid` (L165), kills tree.
- `FreeShellOrphans()` (~L199–204): calls both; invoked at start of `/ops/build` (L706) and
  `/ops/test` (L749).
- Soma's own listen port = `port` var (L15, default **5199**, from `config["Port"]`).
- `shellWorkingDir` (L62) = the Shell project working dir.

## THE FIX (narrow — tools/Soma/Program.cs only for code; + USAGE.md doc note)

Implement the coordinator's 4 points as a **fail-closed protected-pid gate** applied at the TOP of
BOTH kill loops, BEFORE any exeName/path check:

1. **Self + own-port protection (points 1 & 2).** Add a helper that returns the pids listening on
   Soma's OWN port (the `port` var, 5199) — reuse the existing `Get-NetTCPConnection` mechanism,
   parameterised. Build a `protectedPids` set = `{ Environment.ProcessId } ∪ pidsListeningOn(somaPort)`.
   Compute it once at the top of `FreeShellPort` and `FreeShellByPath`. For ANY candidate pid in
   `protectedPids` → `continue` with `AuditLog("KILL_SKIP", $"pid={pid}|reason=soma-protected")`.
   NEVER kill a protected pid under any condition.

2. **Shell match by port + path, never bare `dotnet` (point 3).** In `FreeShellPort`, replace the
   `if (exeName != "dotnet" && !exeName.Contains("ccdashboard")) continue;` gate so that a `dotnet`
   process is killed ONLY when it is BOTH (a) listening on 5239 (already the scan criterion) AND
   (b) NOT in `protectedPids` AND (c) NOT a test-infra process (point 4). Keep killing obvious
   `ccdashboard*` exes. The intent: "listening on 5239 and not protected and not test-infra" is the
   Shell; a bare unrelated `dotnet` that is not on 5239 is never reached (scan already filters by port).

3. **Exclude the test process tree (point 4).** Skip any candidate whose `ProcessName` (lowercased)
   is in { `testhost`, `vstest.console`, `vstest`, `dotnet-test` } → `continue` +
   `AuditLog("KILL_SKIP", $"pid={pid}|reason=test-infra|name={procName}")`. (Belt-and-suspenders:
   even though FreeShellOrphans runs before `dotnet test` spawns testhost, this guarantees no future
   call path can catch the test tree.)

4. **Forensics (diagnosis).** For EVERY kill actually performed, AuditLog must record
   `pid`, `name`, and the resolved module path (or "unknown") and the matched reason
   (e.g. `port-5239-shell` / `path-shell`). For every skip, log the reason as above. This turns the
   next `/ops/test` occurrence into a definitive trail in `soma-audit` (operator can `GET
   /logs/tail?source=soma-audit`).

Keep `target.Kill(entireProcessTree: true)` for confirmed Shell targets (correct — frees bin/ locks),
but it now only ever runs on a pid that passed the protected + test-infra + port/path gate.

**Do NOT** change: `FreeShellOrphans` call sites, `/ops/build`, `/ops/test`, `/db/*`, connStr, auth
middleware, soma_ro, `*_safe` views, the query whitelist, or Soma's own port. SF-SOMA-001 intact.
Bump Soma version string (currently 2.4.0 → 2.5.0) if a version constant exists; otherwise skip.

### USAGE.md — two-port disambiguation (coordinator 02:20 directive, fold into THIS commit)
Add a short clearly-headed section to `tools/Soma/USAGE.md`:
> **Two easily-confused ports.** `Soma:Port` (5199) = the port SOMA ITSELF listens on → verify Soma
> ALIVE via `GET http://localhost:5199/health` (no auth) → `{ok:true,service:Soma}`. `Soma:Shell.HealthUrl`
> (`http://localhost:5238/health`) = the URL Soma PROBES to check the SHELL (for `/ops/health`); 5238 is
> the Shell's dev HTTP port (Shell binds https:5239 + http:5238); **Soma does NOT listen on 5238.**
> ⇒ NEVER probe 5238 to verify Soma — that tests the Shell. `/ops/health up:false` = the Shell is down
> (or Redis down → Shell /health 503), NOT Soma. A cold `dotnet run` in tools/Soma (restore+build) can
> take >30s — don't declare Soma 'down' after ~12s; read `tools/Soma/out.log` for
> `Now listening on: http://localhost:5199` / `err.log` for errors.

**Write discipline (§0.3):** Python read→replace→write + `os.fsync`; Edit tool BANNED on mount.
After each write: `tail -3` + `wc -l`.

## BUILD / VERIFY
```bash
cd "D:\Claude\Projects\RTM View Shell"
dotnet build tools/Soma           # must compile (file-lock on output copy = Soma running, NOT a compile error)
grep -n "protectedPids" tools/Soma/Program.cs        # >=2 (FreeShellPort + FreeShellByPath)
grep -n "test-infra\|testhost" tools/Soma/Program.cs # >=1 (test-tree skip)
grep -n "KILL_SKIP" tools/Soma/Program.cs            # >=1 (forensic skip log)
grep -ic "Soma does NOT listen on 5238" tools/Soma/USAGE.md  # =1
```

## COMMIT (native CC, commit.lock serialized)
```bash
# 1. acquire commit.lock (Python open(path,"x"); retry 5×60s; never auto-delete a stale lock — report owner)
bash tools/pre-commit-check.sh tools/Soma/Program.cs tools/Soma/USAGE.md
# 2. NARROW-ADD by name only (NO -A, NO git add .)
git add tools/Soma/Program.cs tools/Soma/USAGE.md
git commit -m "fix(soma): F-QA-4 kill-guard — fail-closed protected-pid set (self+own-port+test-infra) + forensic audit; USAGE two-port note [devops]"
# 3. post-commit zero-deletion verify (object-store)
git show --stat HEAD            # exactly 2 files, 0 deletions
# 4. journal append + release commit.lock (Python+fsync)
```
**NO `git push` (§37).**

## §0.6b Binding POSTAMBLE → `.coord/cc/devops.md`
```
### RESULT:
- commit: <hash> fix(soma): F-QA-4 kill-guard ...
- files: tools/Soma/Program.cs, tools/Soma/USAGE.md (2 files, 0 deletions)
- build/test: dotnet build tools/Soma -> <pass/lock-only>
- guards: protectedPids in FreeShellPort + FreeShellByPath; test-infra skip; KILL_SKIP forensics; SF-SOMA-001 UNCHANGED
- object-store verify: yes — <hash> in git log HEAD; grep anchors pass
- status: done
- NO push
```

## §0.7 re-sync (LAST action)
```bash
for f in tools/Soma/Program.cs tools/Soma/USAGE.md; do git show HEAD:"$f" > "$f"; done
sync
```

---

## Acceptance criteria
- [ ] STEP-0 reads done; branch v3; both files hash-verified vs HEAD before edit
- [ ] `protectedPids` (= {Environment.ProcessId} ∪ pids-listening-on-Soma-port-5199) computed at TOP of FreeShellPort AND FreeShellByPath; protected pids ALWAYS skipped before any exeName/path check
- [ ] FreeShellPort no longer kills on bare `exeName=="dotnet"` alone — requires (on 5239) ∧ (not protected) ∧ (not test-infra)
- [ ] testhost/vstest test-infra processes skipped (point 4)
- [ ] Every kill + every skip AuditLog'd with pid/name/path/reason (forensics)
- [ ] USAGE.md two-port section added ("Soma does NOT listen on 5238")
- [ ] No SF-SOMA-001 / connStr / auth / whitelist / own-port changes; /ops + /db endpoints untouched
- [ ] `dotnet build tools/Soma` compiles; grep anchors pass
- [ ] Exactly 2 files changed, 0 deletions; commit `fix(soma): F-QA-4 kill-guard ...` on v3; binding RESULT; journal; commit.lock released
- [ ] NO push
- [ ] LIVE confirm (QA, after operator Soma redeploy): POST /ops/test?suite=unit → tests run AND Soma /health :5199 still 200 afterward; soma-audit shows KILL_SKIP soma-protected entries
