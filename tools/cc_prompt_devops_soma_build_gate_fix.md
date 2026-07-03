# CC TASK — Fix Soma /ops/build so test-project compile drift CANNOT hide — DIRECTIVE (C).2

> Owner: role-devops. Branch: **v3** (only branch). status: DRAFT -> coordinator §4 -> RUN on operator poke.
> WHY: /ops/build runs `dotnet build CcDashboard.sln` (Program.cs:783-789). The 4 test projects ARE in the .sln, so it
> SHOULD have failed on the 62 Tests.Unit compile errors — but it reported exitCode 0 while /ops/test found 62. Cause:
> INCREMENTAL build up-to-date check skipped recompiling the test project (stale outputs looked current). `dotnet test`
> force-builds, so it surfaced them. Fix: make /ops/build force a full compile so it can't hide test-project drift.

## Mandatory reads
.claude/skills/role-devops/role-devops.md (§A + §C) ; .claude/skills/session-coord/session-coord.md (§1/§10).
tools/Soma/USAGE.md (endpoint catalogue). Reality wins.

## STEP 0 — Integrity + branch
```bash
cd "D:\Claude\Projects\RTM View Shell"
git rev-parse --abbrev-ref HEAD    # MUST be v3
```
BINDING PREAMBLE -> .coord/cc/devops.md (status open, directive ref).

## STEP 1 — Edit tools/Soma/Program.cs /ops/build handler (Python+fsync, §0.3 — Edit tool BANNED)
In the `/ops/build` handler (~L789) the build args are:
```csharp
psi.ArgumentList.Add("build"); psi.ArgumentList.Add("CcDashboard.sln");
```
Add `--no-incremental` so every project (incl the 4 test projects) is force-compiled and a compile error CANNOT be skipped by an up-to-date check:
```csharp
psi.ArgumentList.Add("build"); psi.ArgumentList.Add("CcDashboard.sln"); psi.ArgumentList.Add("--no-incremental");
```
(Single-invocation fix; no `dotnet clean` step needed. Matches the CI gate's --no-incremental.)

## STEP 2 — USAGE.md note (Python+fsync)
Under the /ops/build entry in tools/Soma/USAGE.md, add: "/ops/build runs `dotnet build CcDashboard.sln --no-incremental` — a FULL rebuild so it reliably surfaces compile errors in EVERY project, including the 4 test projects (prevents the incremental-staleness false-0 that hid 62 Tests.Unit errors, 2026-07-02)."

## STEP 3 — Build Soma (native CC), NO push
```bash
dotnet build tools/Soma        # compile OK (if Soma is running it may lock output — that's a copy lock, NOT a syntax error; note it)
```

## STEP 4 — Empirical confirmation (acceptance — after operator redeploys Soma)
Soma must be RESTARTED by the operator to pick up this change (running instance won't hot-reload) — same as prior Soma fixes.
Prove the gate now catches test-compile drift (via host Chrome same-origin fetch to 127.0.0.1:5199, Bearer from tools/Soma/appsettings.json — never echo/commit the token; §47):
- If the 62 Tests.Unit errors are STILL present on the tree: `POST /ops/build` MUST return `success:false, exitCode!=0`, with `tail` showing the CS-errors — NOT `success:true`. (Old incremental behaviour returned success:true.)
- If the tree is already clean (errors fixed by backend): inject a trivial compile error into a Tests.Unit file, `POST /ops/build` MUST report failure, then revert. This proves --no-incremental force-compiles the test project.
Report the observed exitCode + tail either way.

## STEP 5 — Commit (v3, NO push) — pre-commit + commit.lock
```bash
bash tools/pre-commit-check.sh tools/Soma/Program.cs tools/Soma/USAGE.md   # exit 0
# commit.lock -> narrow add ONLY tools/Soma/Program.cs + tools/Soma/USAGE.md (NEVER D Installations/*) ->
# git commit -m "fix(soma): /ops/build --no-incremental — force full compile so test-project drift can't hide (DIRECTIVE C.2) [devops]"
# -> journal -> release lock
```
BINDING POSTAMBLE -> .coord/cc/devops.md RESULT (commit hash, +1/-0 line on Program.cs, USAGE note, build OK, empirical result, status done). **NO push** (§37). §0.7 re-sync both files from HEAD.

## DO NOT
- NO push. Touch ONLY tools/Soma/Program.cs + tools/Soma/USAGE.md. Do NOT change SF-SOMA-001 guards (soma_ro, *_safe views, secrets revoked) or the F-QA-4 kill-guard / FreeShellOrphans logic. Do NOT stage D Installations/*. Do NOT commit to v2-backend.
