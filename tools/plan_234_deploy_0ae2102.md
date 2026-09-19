# DEPLOY PLAN — the filter line (seven commits) to server 234, carried by the tip `0ae2102`

> Author: devops-0916, 2026-09-18. **PLAN, not a run.** Boxes on 234 begin after the coordinator's §4 AND
> after `shell-0912` has a plan for ONE measurement pass (coordinator's requirement: without it the "after"
> halves land on different states of the ground).
> Entry pins, measured this hour: `v3 = 0ae2102` · `origin/v3 = ed3e292` · unpushed **23**.
> [измерено: git rev-parse / rev-list --count / log --oneline origin/v3..v3]
> Installed on 234 today: engine and shell `+621a797`, adapter `+8d28531`
> [измерено 2026-09-16: .measurements/234_20260916_181430_inst13-step0.txt; NOT re-measured since — step 0 of this
> flight re-takes it, and no decision here rests on it].
> **binding:** `.coord/cc/devops.md`, a block opened for THIS flight before the first box; `RESULT` with numbers
> per gate is appended there afterwards, **including a flight that broke off**.
> `commit.lock` / `cc_prompt_sync_block`: **NOT APPLICABLE, with the reason** — the flight makes no commit and
> touches no clone beyond reading it to build the package. A commit here would bring the lock back with it.
> **NO push.** The §37 barrier is the coordinator's, and the operator's order is deploy -> checks -> barrier.

## 1. WHAT IS BEING DEPLOYED — named by sha, not by story

Package tip: **`0ae2102`**. What it carries, measured against what is installed (`621a797`):
```
filter line (shell), 7 commits, none deployed:
  0864147 fix(web): filter branch on the metric ValueType, case-insensitively
  41c54f5 fix(web): filter popup no longer inherits pre-line from the header cell
  cdaafc7 fix(web): agent grid filter popup no longer inherits the header cell wrapping mode
  a6c150e fix(web): filter popup anchors to the funnel button instead of the header cell
  0e5568d fix(web): filter popup edits a draft; only Apply commits and persists
  6f3ae87 chore(web): drop the now-unused GetOrCreateFilter from both grid widgets
  0ae2102 feat(web): opening a filter popup closes the ones in other widgets
also inside the range, NOT product code:
  8b3da25 / 9ae966f  deploy/Update-RTMView.ps1   (INST-13, INST-14)  <- ships as a FILE in the package
  082506b / 5efbcf5  db/tools/Compare-ToBaseline.ps1 (CMP-01 parts 2/2b)
  56e06f5 / 15048f9 / e7116ce / 55c1945 / f4c011d / 6f4c8f2 / 6447754 / 96b826b  protocol files, not packaged
```
**The engine is not being changed by this flight** (no `RTM/` source commit in the range) — but the package is
built `-Mode Full` and the installer bounces both services regardless (`-SkipShell`/`-SkipRTM` do not leave the
other alone — runbook §3.2). So the flight is planned as a two-service outage, not a shell-only one.

## 2. PROVENANCE — five pins, each printed by the box BEFORE the transfer

1. **Clean clone**: `git clone` of the working clone into `D:\Claude\Build\rtm_clean_0ae2102_<stamp>`,
   then `git rev-parse HEAD` there -> must equal `0ae2102`. The clone directory must NOT exist before.
2. **Cleanliness**: in the clean clone, `git status --porcelain` -> 0 lines. (Native git on the workstation,
   not through the mount.)
3. **Content**: `git rev-parse HEAD:src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor` in the clean
   clone == the same in the working clone == what `git show 0ae2102:` gives. One file is enough as a witness
   because the whole tree is addressed by `HEAD`; the point is that the builder reads THAT tree.
4. **Build**: `tools/Build-ProdRelease.ps1 -Mode Full` run IN the clean clone. Its zip name and `sha256` are
   printed and recorded; the package is copied to 234 and its `sha256` re-printed there — equal, or STOP.
5. **Compilation root**: after the install, the PDB root inside `C:\RTMView\Shell\CcDashboard.Web.exe` contains
   `rtm_clean_0ae2102`, and `ProductVersion` carries `+0ae2102…`; `Dropbox`/`IceDash`/`Program Files` -> 0.
   **Without pin 5 the install is "unproven by provenance"** and goes back to the coordinator, not re-installed.

## 3. THE DRIFT GATE — the way past it carries its reason IN THE ARTEFACT

`realDriftA` is red **by construction** until CMP-01 part 1: the baseline is tables-only while the server dump
carries routine blocks — 910 of 910 extra lines are routine blocks
[измерено: .measurements/234_20260918_113121_cmp01-detail.txt].
Therefore the flight passes `-SkipDrift`, and the box PRINTS INTO ITS OWN REPORT, before the installer runs:
```
-SkipDrift reason: PR234-CMP-01, dimension A compares asymmetric corpora (baseline tables-only vs server dump
with routine blocks). Measured 2026-09-18: extra 910, of which routine-block lines 910 (48 headers + 862 body),
table/index/sequence/alter/other 0. The gate cannot be green on a healthy database until part 1 lands.
```
A reference to "we know about it" is not a reason; the sentence above, with its numbers, is. `-ForceDeploy` is
NOT used: it would record a different intention (`PR234-INST-14` — and this is the first flight where the
installer prints the flag that was actually passed).

## 3b. REV 2 — FOURTH REQUIREMENT (coordinator 2026-09-18T16:3xZ): proving AFTERWARDS that THIS build is on 234

The application cannot say which commit it was built from: no `SourceRevisionId` / `InformationalVersion` in
the Web csproj, `/health` says nothing about a version [измерено координатором 2026-09-18; пере-снято мной:
`git show v3:deploy/Update-RTMView.ps1 | grep -ci 'ledger|SERVER.md|ReleaseCommit'` -> 0 — **our install path
has no manifest step at all**; `-ReleaseCommit` exists only in `deploy/Apply-Server45Upgrade.ps1:79`, which this
flight does not use]. So "this build is deployed" is, today, an act of trust in whoever deployed it.

Two mechanical, non-circular proofs — the behaviour of the seven fixes takes no part in either:

**(1) Binary identity, server against package.** `sha256` of `C:\RTMView\Shell\CcDashboard.Web.exe` and
`...\CcDashboard.Web.dll` on 234, against the same two files extracted from the package zip on the workstation.
Equal -> the bytes on the ground are the bytes we built. This proves "this build", and nothing about its origin.

**(2) Build-to-commit link, written by the box, because the installer writes no manifest.** `-ReleaseCommit`
belongs to a different installer, so the box writes the line itself into the ops ledger that the project
already uses (`C:\RTMView-Ops\applied\_ledger.txt`, CLAUDE.md §43):
```
<UTC> | MANIFEST | commit=0ae2102 package=<zip name> package_sha256=<...> web.dll_sha256=<...> by=devops-0916
```
The package `sha256` is computed on the workstation from the CLEAN clone whose `HEAD` equals `0ae2102` (pins 1-4
of §2). The chain is: clone HEAD -> package sha256 -> file sha256 on 234, each link measured, none inferred.

**If either proof cannot be taken, the flight is reported with "body not pinned"**, and `shell-0912` starts its
pass knowing that — never with a silent assumption. Note the honest limit of both: they pin the BYTES and their
provenance chain, not the source of the bytes inside the binary — a PDB compilation root (§2 pin 5) remains the
third, weaker witness and is reported alongside, not instead.

## 4. STEPS — one box each, "WHERE IT RUNS" as text before the box, box handed out together with its file

- **Step 0 (workstation).** Clean clone + pins 1-3 + build + package `sha256`. Nothing touches 234.
- **Step 1 (234, read-only).** Pre-state: three services with pid and `StartTime`, liveness pair
  (pipe `rtmpipe_v3` + shell `/health` 200 via `curl.exe`; the engine has NO `/health` route — its listener
  answering any code is the liveness signal), installed `ProductVersion`s, config sha256 set, `pg_dump` of
  `rtmviewdb` on 5433 + fingerprint F0, free disk. Verdict READY / NOT READY.
- **Step 2 (234, the install).** Transfer, `sha256` equal, `Unblock-File`, then
  `Update-RTMView.ps1 -DBPort 5433 -SkipDrift -SkipCacheMigration -KeepBackups 50 -MigrationList ""`
  with `-DBPassword` read as `Read-Host -AsSecureString`.
  `-MigrationList` stays EMPTY and the run must print `No migrations specified` — this flight changes no schema.
  `-KeepBackups 50`: the default 5 would delete the R4 rollback base in the very run that needs it (15.09).
- **Step 3 (234, acceptance).** Services back (RTMService first), liveness pair polled in a LOOP up to 180 s,
  `RTMTwilio_1` Running (the engine raises it — never by hand), `ProductVersion` + PDB root = pin 5,
  F == F0, config sha256 == step 1, the installer's new backup directory exists.
- **Step 4 (234, CMP-01 live acceptance — the part this flight closes).** Run `Compare-ToBaseline.ps1` from the
  package, read-only, and compare `[A-R]` against 13.09: `Missing on server` 46 and `Extra on server` 116 must
  fall to numbers **explained line by line**, not merely smaller. Anything still listed is named individually.
  This is what turns CMP-01 parts 2 and 2b from DELIVERED to CLOSED.
- **Step 5.** `RESULT` into the binding; hand the ground to `shell-0912` for its single measurement pass.

## 5. ROLLBACK — printed by every writing box before its first write
```
R1  services down mid-run:   Start-Service RTMService ; wait pipe+listener ; Start-Service RTMViewShell ;
                             wait /health 200. RTMTwilio_1 is NOT started by hand.
R2  binaries:                the installer's own pre-install backup under C:\RTMView\Backup\<stamp>\ (its
                             APPEARANCE is part of step 3 — a backup that did not appear means the run did not
                             reach step 2 of the installer). Stop services, swap the directory back, R1.
R3  database:                not expected — no migrations in this flight. The step-1 pg_dump is the floor:
                             pg_restore -p 5433 -d rtmviewdb --clean --if-exists <dump>, then F == F0, then R1.
                             R3 needs the operator's word at the moment.
R4  the 13.09 adapter base   C:\RTMView\Backup\rtmtwilio_aa19743_20260913_011524 (357 files) is NOT touched and
                             NOT deleted by this flight; `-KeepBackups 50` is what protects it.
```

## 6. WHAT THIS FLIGHT DOES NOT PROVE, said before the numbers
- It does not prove the seven filter fixes WORK: that is `shell-0912`'s measurement pass, one pass, after this.
- It does not fix `CMP-01` part 1 — the gate stays red by construction and is skipped with the reason above.
- It does not close `PR234-INST-13 E2`: that half needs a run where a migration fails mid-flight, and this
  flight applies no migrations. It stays deferred, as the coordinator recorded.
- Nobody has accepted `0ae2102` into `origin`: unpushed 23. The chain proves provenance, not acceptance.

## 7. PRECONDITION I DO NOT DECIDE
`shell-0912` must have its ONE-pass measurement plan ready before step 2 runs. Until then this plan waits; the
steps that touch nothing (step 0) may run earlier if the operator wants the package ready.

**REV 2**, 2026-09-18: section 3b added on the coordinator's fourth requirement; the plan had three.

— devops-0916, 2026-09-18
