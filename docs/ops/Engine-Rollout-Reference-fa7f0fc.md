# Engine rollout on 234 — reference flight (fa7f0fc, 2026-10-17)

This flight is the **reference** for every future engine (RTM) rollout on production server 234.
It records the path that finally went green and every mistake made on the way, with the rule each mistake produced.

Result: engine `a593823` → `fa7f0fc` (legacy engine port D1–D4), installer exit 0, all rows green.
Report: `.measurements/234_20261017_112219_install-fa7f0fc.txt` (sha256 `e3b7fe5e…702f`).

## 1. The path (what to repeat)

| Step | Where | What | Gate |
|---|---|---|---|
| 0. Readings | 234, read-only | upsert body, InteractionType values, BU time zones, free disk | coordinator accepts |
| 1. Delta | station | `git diff --name-only <deployed>..<pin>` by path: `RTM/`, `db/`, `deploy/`, `tools/` | `db/` = 0 (POSCTL: migrations exist in tree) ⇒ `-Mode RTM -SkipDB` |
| 2. Package | station | `probe_WS_<date>_rtmpkg-<pin>.ps1`: clean clone at pin, blob-by-blob provenance of every `RTM/` file of the delta, `Build-ProdRelease -Mode RTM -SkipDB`, freshness, needles before (floor package) / after (new), hand-over copy + `.origin.txt` | READY TO HAND OVER; coordinator accepts |
| 3. Box review | coordinator | §4 on probe sha + box text | PASS **before** the box reaches the operator |
| 4. Box issue | devops (owner) | the box is issued by the role that owns the work, never by the coordinator | — |
| 5. Install | 234 | `probe_234_<date>_install-<pin>.ps1`, phase 1 read-only, phase 2 `Update-RTMView.ps1 -SkipShell -DBPort 5433 -SkipDrift -SkipCacheMigration -DBPassword (Read-Host -AsSecureString)` | phase 1 gate; verdict DONE |
| 6. Report | devops → coordinator | numbers before/after, path + sha of the report | coordinator accepts |

Phase 1 (read-only, may STOP): bus gate (blessing found by a Cyrillic needle, no STOP word after it, POSCTL on a test line) · package sha · rollback floor sha on 234 · disk ≥ two Shell+RTM sets and ≥ 4 GB · needle before-halves in `RTM.Configuration.dll` (appearing 0/0, POSCTL `AppConfig.PipeName = ` ≥ 1) · P0 before-half over all engine logs (P0 texts 0, POSCTL = lines of `RTM.Tools.AsyncLogger` ≥ 1) · services, pids, versions, hashes of what must not move.

Phase 2 (writes): extract to `incoming\pkg_<pin>_<stamp>` · install · installer's own words counted (no migrations 1, drift skipped 1, `RTM updated ->` 1, `Preserved:` 3, `-ForceDeploy` 0) · this run's backup (+1 dir, one `db_*.dump` > 0, backed-up `RTM.dll` = deployed before) · engine new pid, shell Running, adapter new pid (poll ≤ 420 s; came back at +31 s) · needles after · `RTM.exe/RTM.dll/RTM.Configuration.dll` = staging · 7 must-not-move files unchanged · P0: the exact AppConfig lines stamped ≥ install start (poll ≤ 180 s) + fresh PipeName · ledger line.

Facts worth knowing:
- `Update-RTMView.ps1` stops and starts **both** services whatever `-SkipShell` says; the shell blinks, its files do not change.
- The updater **preserves** the machine `appsettings.json`, `log4net.config`, `data.sys` of the engine: new `RTM:*` keys never reach the machine; the **code defaults** apply. P0 expectations are therefore the defaults in `AppConfig.cs` at the pin.
- An engine restart drops the adapter; the engine raises it. Never start the adapter by hand.
- Engine logs on 234: 38 files, ~3.5 GB, ~10.8 M lines.

## 2. The mistakes and the rule each one produced

| # | What happened | Cause | Rule |
|---|---|---|---|
| 1 | Coordinator issued the box to the operator himself | role confusion | The box is issued by the owner of the work; the coordinator only blesses (§4). |
| 2 | Operator interrupted run 1 by accident: the window looked dead | long silent stretches (copy over RDP, inbox read, log read) | Every box prints timestamped "signs of life" before each long stretch and says how long it may take. |
| 3 | Run 2 died in the box: `[ref]$parseErr` on a non-existent variable | variable lived in the old window from earlier boxes; a new window does not have it | Initialise every `[ref]` variable (`$parseTokens = $null; $parseErr = $null`) before `ParseFile`. Review the box text by eye, not only by a parse in a warm window. |
| 4 | Run 3 hung in phase 1 (>10 min) | the probe read every log whole into an array, once per needle, over 3.5 GB | Logs are read in **one streaming pass per file** with a shared reader, keeping only the lines that can matter; one progress line per file. |
| 5 | Run 4 stopped at the gate: P0 POSCTL = 0. I explained it as "the start rolled out of the logs" | the explanation was never measured; in fact the reader read nothing (see 6) | A zero is not explained until the reader that produced it is proven to see something. "Plausible" is not "measured". |
| 6 | Run 5 stopped at the gate: lines read = 0 over 3.5 GB | `[IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete` written **inside** a `New-Object` argument list: the comma binds tighter than `-bor`, the constructor got wrong arguments, `New-Object` failed **non-terminating**, the trap stayed silent | Never use `-bor` inside a method/constructor argument list — compute flags first (`[IO.FileShare]'ReadWrite, Delete'`). Open files with static `[IO.File]::Open` (throws) rather than `New-Object` (may only write an error). Every reader carries a POSCTL "lines read ≥ 1". If it fails again: test the reader on a copy of one log on the station against `Measure-Object -Line` before touching 234 again. |
| 7 | The package was missing from `incoming` on a later run | not established | The box always verifies by sha and re-copies; never rely on an earlier run having left a file. |

What held every time: phase 1 never wrote anything, and every STOP left the server unchanged (checked by a read-only status box after the interruption: engine files still `097F087D…` of a593823, no new backup, services Running).

## 3. Open after this flight
- Free disk on C: dropped 10946.6 → 7103.5 MB; the two-set gate (~7.5 GB) would now fail. Addressed by the installer change: automatic pruning of old installer backups (`-KeepBackups`, default 2, by parsed timestamp, before the new backup is written; non-installer folders untouched) — PR234-INSTALLER-BACKUP-SORT-BY-NAME-01.
- The context line in the install probe still carries the disproved "rolled out" text; fix at the next touch.
- BU 10 "before" reading for P-U3, then acceptance.
