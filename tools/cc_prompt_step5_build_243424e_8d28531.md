# CC PROMPT — STEP 5 (part A, BUILD ONLY): two branches in one window

> Author: devops-0912, 2026-09-13. Runs on the LOCAL build workstation. Awaiting coordinator §4.
> **This prompt builds and proves. It does NOT install and does NOT touch server 234.**
> The install on 234 is a separate run-box, issued by devops after these numbers exist. Nothing here
> contacts 234, any database, or any service.

## 0. NORMS CARRIED INSIDE (do not go looking — `CLAUDE.md` is 146 207 chars against a 40 000 read limit)

1. **Object store is the truth.** `git show` / `cat-file` / `hash-object`. Never the working tree, never memory.
2. **NO push.** Commit if the task says so; the push barrier belongs to the coordinator.
3. **Say the expectation BEFORE the number.** A number without its stated expectation is not a gate.
4. **Report what you did NOT prove**, in words, in the same report.
5. **`git commit -m "..." -- "<path>"`** — pathspec LAST. `git commit -- <path> -m "..."` makes git treat
   `-m` and the message as pathspecs and fails. A protective construct must itself be proven executable.
6. **Encoding:** any `.ps1` you touch stays UTF-8 **BOM + CRLF**; verify by BYTES, never by line count.
7. **§47 — Soma (only if you need it):** `http://localhost:5199`, `/health` needs no auth. Other endpoints
   need `Authorization: Bearer <token>`; the token is referenced BY PATH — `tools/Soma/appsettings.json`,
   key `Soma:Token`. **Its value never enters this prompt, your output, a report, or the chat.**
   From a sandbox with no host loopback: open a host Chrome tab on `/health`, then same-origin `fetch()`.
8. **Perimeter, absolute:** do not touch `C:\IceDash\`, the production `RTM.Twilio` service, legacy `RTM`
   (it runs permanently), PostgreSQL 15 on 5432, `C:\Program Files\CcDashboard\`, or machine 140.

## 1. ENTRY PINS — a mismatch is a STOP, never a guess

```
v3       = 243424e654dc44e341b29de548f3278b735a3531
adapters = 8d285311bb66671476f0f6312f19f3d4bc50d0e5
```
Print both with `git rev-parse` before anything else.

**If a tip has MOVED, that is CONTEXT, not automatically a refusal.** Other roles commit to `v3` with
their own hands between the writing of this prompt and your run. The gate that must hold is about MY
artifacts: the four commits below must be ANCESTORS of what you build, and the adapter tip must be exactly
`8d28531`. Check the ancestry explicitly and report it:
```
git merge-base --is-ancestor 531cf31 v3   ; echo $?     # relay resub (shell)
git merge-base --is-ancestor 35989b6 v3   ; echo $?     # Engine.cs refreshUnions after LoadData
git merge-base --is-ancestor 06aeaaf v3   ; echo $?     # Union.cs zero-denominator guard
git merge-base --is-ancestor 3d55673 v3   ; echo $?     # probes
```
All four must print `0`. If `v3` moved, name the new sha and the commits added, then continue.
If the ADAPTER tip is not `8d28531` — STOP and report; that one is mine and nobody else writes it.

## 2. ARTIFACT FRESHNESS — measure your own threshold, never borrow one

Before building, record the newest existing artifact timestamp **for the thing you are about to build**,
and print it. Adapter and Shell/engine have SEPARATE thresholds; a threshold taken from another role's
artifact produces a permanent false red (this already happened today).

```powershell
# adapter threshold - from the ADAPTER's own artifacts
Get-ChildItem "D:\Claude\Projects\RTMView-adapters-wt\publish" -Recurse -File -EA SilentlyContinue |
  Sort-Object LastWriteTime -Desc | Select-Object -First 3 FullName, LastWriteTime, Length
```
After the build, every artifact you claim as new must be NEWER than the threshold you printed. A build
that "succeeded" while its output kept an old timestamp did not happen — the run can honestly report
"Task already completed" for work that never ran.

## 3. BUILD — two branches, one window, in this order

### 3a. Adapter (`adapters` worktree)
`cd "D:\Claude\Projects\RTMView-adapters-wt"` and run the checks from INSIDE that directory
(`git rev-parse --abbrev-ref HEAD` -> `adapters`, `git rev-parse HEAD` -> `8d28531…`, `git status --short`).
Do not run `git worktree prune` or `add` without the coordinator's word.
```powershell
dotnet build   "RTM.Twilio\RTM.Twilio.csproj" -c Release
dotnet test    "RTM.Adapter.Common.Tests\RTM.Adapter.Common.Tests.csproj" -c Release
dotnet publish "RTM.Twilio\RTM.Twilio.csproj" -c Release -r win-x64 --self-contained -o "D:\Claude\Projects\RTMView-adapters-wt\publish\twilio"
```

### 3b. Shell + engine (`v3`)
Build from a CLEAN CLONE at the `v3` tip, the way the b4ad301 batch was built — not from the working tree,
which carries untracked files. Name the clone path and the sha you cloned. Then the packages:
```powershell
# -Mode RTM and -Mode Shell, NOT -Mode Full, NOT -FreshDb: the server install goes through
# Update-RTMView.ps1, which preserves machine configuration. -SkipDB keeps the DB password out of this run.
tools\Build-ProdRelease.ps1 -Mode RTM   -SkipDB -GarnetDir <cache> -NssmDir <cache>
tools\Build-ProdRelease.ps1 -Mode Shell -SkipDB -GarnetDir <cache> -NssmDir <cache>
```
`tools/cache` is git-ignored, so a fresh clone has no Garnet/NSSM — point those two switches at the
working tree's cache (read-only). This exact omission killed the first build attempt on 08.09.

## 4. TEST-GATE — numbers BEFORE any talk of installing

**The GATE is two things, and the test COUNT is not one of them:**
```
gate 1 : failed = 0
gate 2 : the test assembly's build timestamp MOVED during this run - print it before and after
```
A count named in advance is an EXPECTATION: print it, compare, report any difference AS a difference.
Do not fail the run on a count alone. The split is deliberate - it catches the real fraud (green numbers
reported over a build that never happened) without going red on honest work that simply has a different
number of tests. Three false reds cost us hours today, every one of them a rigid expectation.

Two test projects, each reported as `total / passed / failed`:
- `RTM.Adapter.Common.Tests` — carries the §48 WIRE round-trip contract. Expectation: **14/14**, from the
  last measured green run. A re-count of `[Fact]`/`[Theory]`/`InlineData` gives 15, but that matcher counts
  `InlineData` rows too, so it is suspect and does not overturn 14. Report the actual; a difference is a
  line in the report, and only a WIRE test that FAILS is a regression that stops the run.
- `CcDashboard.Tests.Unit` — the shell suite. Expectation: **284**, the last measured green
  (`shell-0912` on `531cf31`). Nothing under `tests/` changed between `531cf31` and `243424e`
  [`git diff --name-only 531cf31..243424e -- tests/` = 0] and the engine change adds no tests, so 284 is
  what the tree predicts. Report the actual.

**There is NO test project for the engine.** Write that as a line, in these words —
`PR234-ENGINE-NOTESTS-01: no test project covers RTM/RTM (engine); the engine change is unverified by tests`
— because silence reads as a pass and it is not one.

## 5. PACKAGE — say WHAT you are shipping, not just HOW

For each produced package print: full path, size in bytes, **SHA256**, and the top-level contents listing.
A permission that names the method and not the artifact is a hole. Confirm explicitly:
- the RTM package contains `db\tools\Compare-ToBaseline.ps1` (the E1 drift gate resolves it in the package
  layout since `PR234-INST-12`; absent means the gate throws on the server, by design);
- the Shell package contains `CcDashboard.Web.exe`;
- the adapter publish contains `RTM.Twilio.exe` (self-contained) **and** `log4net.config` (the reason
  `aa19743` exists at all).

Also print, for the built binaries, the `ProductVersion` **and** the PDB compilation root inside the
assembly. Version accompanies; the compilation root is what proves WHOSE binary it is; the sha256 proves
its exact composition. All three, never one alone.

## 6. WHAT THIS RUN MUST NOT DO

No install, no service touched, no file written to any server, no push, no commit unless explicitly
requested later, no `-Mode Full`, no `-FreshDb`, no database contacted, no 140, no `C:\IceDash\`.

## 7. REPORT

Entry pins + the four ancestry checks; the two freshness thresholds and the post-build timestamps;
build errors/warnings as counts; both test triplets; the `PR234-ENGINE-NOTESTS-01` line; package paths,
sizes, SHA256, contents checks, ProductVersion + PDB root. Then stop and wait.

---

# WHAT COMES AFTER THIS PROMPT (context, not your task)

Install on 234 goes through `Update-RTMView.ps1` with the machine configuration preserved (`data.sys`,
`appsettings.json`, `log4net.config` — restored as the procedure states), then:

- **Engine restart is ALWAYS accompanied by an adapter restart** — on this adapter revision the pipe has no
  reconnect of its own, and a probe taken after a lone engine restart is invalid.
- **The acceptance measurement is run by `shell-0912`, not by devops.** Devops' job ends at a system where
  that measurement is possible: Shell alive, and then the engine (with the adapter) restarted **while the
  Shell process is NOT restarted**. Restarting both destroys the predicate — the whole point is whether our
  Shell re-subscribes on its own after a lone engine restart.
- **Integrity has two floors after install:** hash and size prove that what was placed equals what was
  taken; a CONTENT anchor (a known literal, a version line, a config key) proves the thing was whole in the
  first place. Report both.
