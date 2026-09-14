# RUNBOOK — installing and upgrading RTM View on a live server

> Owner: devops. Written 2026-09-13 by `devops-0912`, from the 234 upgrade of that day, and every
> number in it was measured on that run rather than remembered. Operator directive, 2026-09-13:
> *"иначе все твои инкарнации будут тыкаться как слепые мышки, повторяя и умножая твои ошибки"*.
> **Reality wins — update this file.** If the runbook and the machine disagree, the machine is right:
> fix the runbook in the same cycle, do not work around it silently.
>
> Scope: an UPGRADE of an existing installation (`Update-RTMView.ps1`), which is what we do on 234.
> A first install is `deploy/FRESH-INSTALL.md`; rollback is `deploy/ROLLBACK.md`.

---

## 0. The shape of the thing

```
build (workstation)  ->  transfer  ->  C0 verify  ->  C1 engine  ->  C2 shell  ->  C3 adapter
                                                                   ->  C4 provenance  ->  T2  ->  acceptance
```
One move per step, a report between moves. Merging moves costs the ability to say WHICH one broke —
that is the only reason the split exists, and it has paid for itself twice.

Every step is either READ-ONLY or it WRITES, and the run-box says which in its first line, together with
the machine it runs on. A box that does not say where it runs makes the operator carry that state.

---

## 1. BUILD — on the workstation, never on the server

- Build the Shell and the engine from a **clean clone at the branch tip**, not from the working tree:
  the working tree carries untracked files, and a package built from it is not the branch.
- Build the adapter from its own worktree (`adapters` branch). Two branches, one window.
- `tools/Build-ProdRelease.ps1 -Mode RTM` and `-Mode Shell`, **not** `-Mode Full`, **not** `-FreshDb` —
  the server install goes through `Update-RTMView.ps1`, which preserves machine configuration.
  `-SkipDB` keeps the database password out of the build run entirely.
- `tools/cache` is git-ignored, so a fresh clone has **no Garnet and no NSSM**. Point `-GarnetDir` and
  `-NssmDir` at the working tree's cache (read-only). Forgetting this killed a build on 08.09.
- **Freshness threshold is measured, never carried in:** record the newest existing artifact timestamp
  FOR THE THING YOU ARE BUILDING, print it, and require every new artifact to be newer. A threshold
  borrowed from another role's artifacts is a permanent false red (that happened on 13.09).
- **Test-gate, reported as `total / passed / failed`:** `RTM.Adapter.Common.Tests` (carries the §48 WIRE
  contract) and `CcDashboard.Tests.Unit`. The GATE is `failed = 0` **and** the test assembly's build
  timestamp MOVED during the run. A test COUNT is an EXPECTATION: print it, compare, report a difference
  as a difference — do not fail the run on a count, or a correct build dies on a stale number.
  **There is no test project for the engine** (`PR234-ENGINE-NOTESTS-01`) — write that sentence out;
  silence reads as a pass.
- Name the package by **path, size, SHA256 and contents** before anything is installed. A permission
  that names the method and not the artifact is a hole.

---

## 2. TRANSFER — and C0, the step that used to be missing

The build machine and the server are two machines with a transfer between them — exactly where a file
arrives different. So:

- Move ONE bundle (both packages plus the adapter payload) plus the verification probe.
- **C0 re-measures SHA256 of every artifact ON THE SERVER** against the build numbers. Mismatch = STOP,
  install nothing, repeat the transfer. "Probably fine" is not a state a package can be in.
- C0 also records the **pre-install baseline**, which is what later proves the update HAPPENED rather
  than that files merely exist: per service — `ProductVersion`, exe sha256 and mtime, file count of the
  install directory, newest file there, service state and **process start time (T0)**; plus the count of
  `preinstall_*` backup folders (0 is the best baseline there is) and the pipe list.
- A probe that refuses because the target folder already exists must **offer to verify what is there**,
  not only to clear it: if the existing files match by hash, there is nothing to extract. A rule with one
  branch makes the operator work by hand where the instrument could have measured.

---

## 3. TRAPS IN `Update-RTMView.ps1` — read before the first write

1. **`-DBPort` defaults to 5432, which on 234 is the OLD PostgreSQL 15.** The live database is PG18 on
   **5433**. Pass `-DBPort 5433` on every invocation. This is a defect of the tool's defaults.
2. **`-SkipShell` / `-SkipRTM` do NOT leave the other service alone — both are bounced.** Plan the
   measurement window around this (§7); it is also why an install move is never "just the engine".
3. **`-DBPassword` is entered as `Read-Host -AsSecureString`, always.** A bare prompt already put the
   production superuser password into a chat (30.08). Without the parameter the internal `pg_dump`
   overwrites `PGPASSWORD` and the run dies AFTER both services are stopped (13.07).
4. **`-SkipCacheMigration`** unless a Memurai→Garnet migration is actually intended.
5. **`-FreshDb` is never spoken** on a live server. No migrations in a binary-only batch:
   `-MigrationList` stays empty, and the run must print `No migrations specified`.
6. **`.ps1` from another machine carries mark-of-the-web** — `Unblock-File` is step 0, always.
7. **The E1 drift gate runs AFTER the services are stopped** (`PR234-INST-13`). A throw there leaves the
   production system DOWN — it did, for ~8 minutes on 13.09. Until that is fixed, know the recovery line
   before you start (§6).
8. **The skip message names the wrong flag** (`PR234-INST-14`): passing `-SkipDrift` prints
   `Drift gate SKIPPED (-ForceDeploy)`. Behaviour is identical (`:161`), but the history gets a name that
   was never typed.

### The drift gate, and what its red actually means

Since `PR234-INST-12` (13.09) the gate finally resolves its tool in the package layout — before that it
silently WARN-skipped, which means **every earlier deploy ran with an unverified database and nobody
knew**. Its first real run was red. What that red measured, checked by a separate predicate:

```
B \ S  (routine names declared by the package's db module, absent on the server) : 0
S \ B  (names on the server beyond the package) : 59 - of which 57 are POSTGRES EXTENSION functions
        (pgcrypto, pg_trgm, pg_stat_statements) and 2 are ours from history partitioning
tables / indexes / constraints / sequences : none missing, none extra
prokind matches fully · metrics match · migration ledger clean · sequences ahead of column max
```
The comparator counts extension functions as drift and compares routine signatures in two notations
(baseline `name(types)`, server `name(mode name type)`), so every routine shows up as BOTH missing and
extra. That is `PR234-CMP-01`: **false-red by construction on any database with those extensions.**

Therefore, when the gate is skipped, the reason recorded is **"deploying over a database verified by a
DIFFERENT predicate, because the standard one is broken and its brokenness is measured"** — never "the
gate was bypassed". And the skip needs the operator's word, not devops' judgement.

---

## 4. C1 / C2 — engine, then shell

```
Update-RTMView.ps1 -SkipShell -SkipDrift -DBPort 5433 -SkipCacheMigration -DBPassword <masked>   # engine
Update-RTMView.ps1 -SkipRTM   -SkipDrift -DBPort 5433 -SkipCacheMigration -DBPassword <masked>   # shell
```
Run from an ADMINISTRATOR console, with the whole output captured to a file (`Start-Transcript`), and
bring the file — not a pasted console.

What the output must contain, named before the run:
- `Backed up: ... -> C:\RTMView\Backup\<stamp>\...` and a `pg_dump` line;
- **`Preserved:`** lines — engine: `log4net.config`, `appsettings.json`, `data.sys`; shell:
  `appsettings.json`. These are the files the installer used to overwrite; `data.sys` carries the license
  and its loss kills the engine while `/health` still answers 200;
- `No migrations specified` and no `Applying migration` anywhere;
- `[E1] drift tool resolved:` or the skip line — its absence means the run never reached the gate, which
  is a thing to report, not to assume away;
- `UPDATE COMPLETE` plus the backup path.

---

### 4b. READINESS IS A MEASURED SIGNAL, NOT A PAUSE

After a service restart, do not judge by a fixed sleep. On 2026-09-14 the engine was called dead sixteen
seconds after its restart - no listener on its port, no `rtmpipe_v3` - and it was simply still starting;
a minute later both were there. A fixed pause measures the OPERATOR'S patience, not the system, and
produces a false red exactly where the system is healthy but slower than expected.
Poll the SIGNAL until it appears or until a stated timeout, and report the waiting time with the outcome:
```
ready when : a listener exists on the engine's configured port
         AND the pipe from AppConfig.PipeName is present in the named-pipe list
timeout    : "not ready after N seconds" is an honest result; "absent at 16 seconds" is not
```

### 4c. AN AD-HOC BOX IN THE CHAT IS AN INSTRUMENT TOO

Every rule that applies to a `.probes` script applies to a box typed into the chat. The thought "it is
just a one-off command" is precisely what suspends the rules. Measured cost, 2026-09-14: the D3 box
built its SQL with `Set-Content -Encoding UTF8`, which writes a BOM, and `psql -f` died on the FIRST
statement - the `SELECT` that was to record the value BEFORE the update. The UPDATE itself ran, so the
transaction ended without its own "before" and had to borrow a number from an hour-old measurement.
SQL is written with `[IO.File]::WriteAllText(..., New-Object Text.UTF8Encoding($false))` and the first
byte is shown. Masked passwords, named-key reads, expectations before numbers: the channel does not
change the discipline.

## 5. C3 — the adapter, by hand, because the installer does not manage it

Order inside the move, and each gate before the step it protects:
1. prove the payload's `RTM.Twilio.exe` sha256 **before stopping anything**;
2. hash the MACHINE `appsettings.json` and `log4net.config` **before they can be overwritten** — this
   run's own numbers, never numbers borrowed from another run;
3. stop `RTMTwilio_1`, copy the WHOLE directory to a new backup, verify the backup is not short;
4. lay down the payload, verify the new exe hashes to the expected value;
5. restore the two machine config files from that backup and prove them byte-identical;
6. start, and print pid and start time — this is the adapter's T1.

**CORRECTED 2026-09-14 (operator's word): the ENGINE owns the adapter's lifecycle - do NOT start or
stop it by hand.** The engine reads `RTM:AdaptorServiceName` (on 234: `RTMTwilio_1`) and brings the
adapter up itself once it is ready to accept the pipe connection, and stops it as well. The earlier rule
- "always restart the adapter after the engine" - was a correct OBSERVATION (on `8abd19a` the adapter
does not reconnect on its own) turned into a wrong ACTION: a manual `Restart-Service RTMTwilio_1` after
a fixed pause can land BEFORE the engine is ready and break what the engine would have done correctly.
So: ONE restart in the procedure, `RTMService`. The adapter's state is CHECKED, never commanded.
C3 is the exception and stays: it replaces the adapter's FILES while the service is stopped - that is a
deployment, not a lifecycle decision.
The supervisor shipped with `8d28531` is new and unverified - do not lean on it in a window that is
supposed to measure something else.

**Never delete** `C:\RTMView\Backup\rtmtwilio_aa19743_20260913_011524` (357 files) — it is the R4
rollback base.

---

## 6. RECOVERY — known before it is needed

A box that writes prints its own one-line undo. Two that are already proven:

```powershell
# services down after a failed installer run (E1 throw, step-order defect PR234-INST-13)
Start-Service RTMService; Start-Sleep 5; Start-Service RTMTwilio_1; Start-Sleep 3; Start-Service RTMViewShell

# adapter rolled back to the previous build
Stop-Service RTMTwilio_1; Copy-Item -Path "<backup>\*" -Destination "C:\RTMView\RTM.Twilio" -Recurse -Force; Start-Service RTMTwilio_1
```
Recovery must not depend on anyone being awake. Print it, do not remember it.

---

## 7. C4 — proving WHAT is installed, and it is three lines per binary

```
ProductVersion        accompanies. A stamp, and stamps can be wrong.
PDB compilation root  proves WHOSE binary this is - written into the assembly by the compiler.
sha256                proves its exact composition.
```
All three, never one alone. Read the **`.dll`, not the `.exe`**: for a self-contained publish the exe is
an apphost stub (all three of ours are exactly 151552 bytes), and the compilation root lives in the
managed assembly beside it. A root containing `Dropbox\Code\RTM` means a LEGACY binary and is a failure.

**Content anchors** (a known literal from the fix) are the second floor: the hash proves that what was
placed equals what was taken, an anchor proves it was WHOLE.
**Search both byte alignments.** .NET stores literals as UTF-16 and a string may start at an ODD offset;
decoding the file once from offset 0 silently misses it. A negative control cannot catch that — an
impossible literal is absent under both alignments. **Use a POSITIVE control on the same corpus** (a
literal that must exist in any assembly). This produced a false "the fix is not in the binary" on 13.09.

Proof that the update HAPPENED: a NEW `preinstall_*`/backup folder that did not exist at C0, changed
exe mtimes, changed file counts, and the process start times.

---

## 8. HEALTH — check the CONFIG first, then the endpoint. In that order.

This is its own step because doing it backwards cost two people time on 13.09.

1. **Read the endpoints the service itself declares** — `Kestrel:Endpoints:*:Url` in that service's own
   `appsettings.json`. Never an address from memory, never `127.0.0.1` by habit.
2. **Understand what the host name in that URL does: almost nothing.** Kestrel binds to `localhost`, a
   literal IP, `*` or `+`; any OTHER name degenerates to "any address" — measured as `::` in the listener
   table. The config still decides the PORT, the scheme and the certificate; only the name is inert, and
   it is not used to filter the `Host` header. So the URL in the config is NOT the address users reach:
   DNS decides that. (`PR234-SHELL-CFG-02`: write `https://+:8444` in the config, and keep the real entry
   URL — `https://platform.insightense.com:8444` — in the handoff and ops docs, where it can be kept true.)
3. **Find out WHO owns the port before believing an answer from it:**
   ```powershell
   Get-NetTCPConnection -LocalPort <port> -State Listen |
     ForEach-Object { $_.OwningProcess } | ForEach-Object { (Get-Process -Id $_).Path }
   ```
   On 234, `127.0.0.1:5000` is held by a SECOND, foreign Shell (`C:\Program Files\CcDashboard\`, a May
   build, out of perimeter) whose Redis health check fails with `NOAUTH`. Our Shell binds `::` on 5000
   and 8444. Asking `127.0.0.1:5000/health` therefore returns a foreign `503 Unhealthy` — and nearly
   became "our" defect on 13.09. Same class as reading another system's log as your own.
4. **Liveness is a PAIR, never `/health` alone:** `/health` 200 on the declared endpoint **AND** the pipe
   from `AppConfig.PipeName` present in `[IO.Directory]::GetFiles("\\.\pipe\")`. The HTTP host comes up
   whether or not the engine did. A zero pipe count means a blind instrument, not a dead system.
5. `/health` in ASP.NET is AGGREGATE: one red check (a cache, say) paints the whole endpoint red. Read
   the body and the service's own log before calling the application broken.

---

## 9. LOGS — only from the service's own declaration

The set of files to measure comes **only** from the log-path declarations of OUR services — never from a
directory name, never from a guess:

```
service whose BINARY lives under C:\RTMView  ->  Win32_Service.PathName  ->  binary directory
  ->  that binary's OWN logging config: log4net <file value=...> (engine, adapter)
                                        Serilog WriteTo[].Args.path (shell)
  ->  a relative path resolves against the service working directory, %SystemRoot%\System32
```
Consequences measured on 234: the Shell declares `logs/log-.txt`, so its log lands in
`C:\Windows\System32\logs` (`PR234-SHELL-LOGPATH-01`) — **and the foreign Shell writes into the same
directory**, so that corpus is mixed BY CONSTRUCTION. Every line must carry its own file, counts are
printed per file, and the owner of a directory is proven by timestamp format plus the compilation root in
stack frames. `C:\Logs\RTM` belongs to the LEGACY install and enters no corpus of ours.

---

## 10. T1 vs T2 — the step that decides whether the day counts

An acceptance predicate about re-subscription holds only if the Shell process did **not** restart inside
the measured window. Install moves bounce the Shell (§3.2), so the window may NOT start from an install
bounce: that yields a GREEN that proves nothing and would close a subject without fixing it — worse than
any false red.

Report **two times, to the second**:
```
T1 = the LAST install-time restart of each service (engine, shell, adapter)
T2 = a SEPARATE, deliberate restart of the ENGINE ONLY (plus the adapter, per the invariant),
     performed after everything has settled and WITHOUT touching the Shell
```
The acceptance run takes its window from T2 and confirms from its own log that the Shell did not restart
in it.

---

## 11. PERIMETER — absolute on every step

`C:\IceDash\` (legacy `RTM`, `RTM.Bot`, `RTM.Twilio`) is not touched by anything, including reads.
The production `RTM.Twilio` service is not touched. Legacy `RTM` runs permanently.
`C:\Program Files\CcDashboard\` (second Shell, May build) is out of perimeter.
PostgreSQL 15 on 5432 is not touched — it is the rollback path. Machine 140 is READ-ONLY.
`data.sys` is restored per procedure. No push; the push barrier belongs to the coordinator.

---

## 12. What a deploy does NOT prove — say it before the numbers

It proves WHAT is installed and that the system is measurable. It does not prove the fixes WORK: that is
the acceptance run, and it belongs to the role that owns the subject. Passengers stay passengers —
`PR234-INST-11` (the dead resync in `Provision-FreshDb` step 7) travels inside the package and closes
only on a clean install, because `Update-RTMView` never calls it.

---

## 13. APPENDIX — SERVER 234 AS IT ACTUALLY IS (measured 2026-09-13)

This machine carries **three installations**, and only the first is ours. Every incarnation that
assumed otherwise lost a day; this table is here so that nobody re-buys that.

```
OURS, the perimeter of our work
  RTMService    C:\RTMView\RTM\RTM.exe                  engine
  RTMViewShell  C:\RTMView\Shell\CcDashboard.Web.exe    shell, listens :: on 5000 and 8444
  RTMTwilio_1   C:\RTMView\RTM.Twilio\RTM.Twilio.exe    our adapter, pipe rtmpipe_v3

LEGACY - not touched by anything, including reads (operator's standing order)
  RTM           C:\IceDash\RTM\RTM.exe                  runs PERMANENTLY (it is NOT "Stopped" -
                                                        that claim travelled between our own documents
                                                        for weeks and was never measured)
  RTM.Bot       C:\IceDash\RTM.Bot\...
  RTM.Twilio    C:\IceDash\RTM.Twilio\...               the PRODUCTION adapter. Never ours.
  PDB compilation root of all three: C:\Users\user\Dropbox\Code\RTM\...

A SECOND SHELL, out of perimeter, easy to mistake for ours
  CcDashboard          C:\Program Files\CcDashboard\CcDashboard.Web.exe   PV 1.0.0+d2737ac (a May build
                       from a stale clone of OUR repo), binds 127.0.0.1:5000 and ::1:5000
  CcDashboardSignalR   ...\SignalRSimulator\SignalRSimulator.exe
```

### 13.1 Where the logs are, and why the answer is not obvious

**Take the path from the service's own config, never from a directory name.** On this machine that rule
is not pedantry — it is the difference between measuring our system and measuring someone else's:

```
RTMService    C:\RTMView\RTM\log4net.config  ->  <file value="C:\RTMView\RTM\Logs\RTM.log">
              ISO timestamps (2026-09-13 12:35:01,043). OURS.
RTMTwilio_1   C:\RTMView\RTM.Twilio\log4net.config  ->  NO <file> element at all.
              The adapter declares no log path: nothing of it is read, and an "adapter log" found
              somewhere by name is not its log.
RTMViewShell  C:\RTMView\Shell\appsettings.json  ->  Serilog WriteTo[].Args.path
              BEFORE 2026-09-13 22:12 : "logs/log-.txt" - RELATIVE, so a Windows service resolved it
                                         against %SystemRoot%\System32 and the log landed in
                                         C:\Windows\System32\logs  (PR234-SHELL-LOGPATH-01)
              AFTER  (operator fixed it): "C:\\Logs\\RTMViewShell\\log-.txt" - absolute.
              Proven by measurement, not by the edit: after the restart at 22:15:05 a fresh
              log-20260913.txt appeared in C:\Logs\RTMViewShell at 22:15:06.

NOT OURS, and the trap that cost a full day on 12-13.09:
  C:\Logs\RTM          declared by NO service of ours -> belongs to the LEGACY install.
                       dd/MM timestamps (13/09/2026 12:35:05,082), stack frames rooted in Dropbox.
  C:\Windows\System32\logs   the FOREIGN Shell is also a service with the same working directory and
                       writes there too. While our Shell wrote there, that directory was MIXED BY
                       CONSTRUCTION - two systems in one folder, distinguishable only per file.
```

**Cheap separation, if you ever have to read a mixed corpus:** ISO timestamps are ours, `dd/MM` is
legacy; stack frames rooted in `D:\Claude\Build\...` or `D:\Claude\Projects\...` are ours, frames rooted
in `C:\Users\user\Dropbox\Code\RTM` are legacy. Measured counts from 13.09:
`C:\Logs\RTM` = 3847 `dd/MM` lines, 0 ISO, 12 Dropbox frames; `C:\RTMView\RTM\Logs` = 56036 ISO lines,
0 `dd/MM`, 0 Dropbox frames. Every line must carry its own file, and counts are printed PER FILE —
a number without its file is what let the conflation survive as long as it did.

### 13.2 Ports, databases and the rest of the map

```
5000   OUR Shell (::) AND the FOREIGN Shell (127.0.0.1, ::1). Asking 127.0.0.1:5000/health reaches the
       FOREIGN one, whose Redis check fails with NOAUTH and answers 503 Unhealthy. Not our defect.
8444   OUR Shell only. Real entry point: https://platform.insightense.com:8444
       ("insightense.com" without the prefix resolves elsewhere and never reaches this machine.)
5433   PostgreSQL 18.4, database rtmviewdb - THE LIVE ONE. Always pass -DBPort 5433.
5432   PostgreSQL 15.5 - the pre-converge database, kept as the rollback path. Do not touch, do not drop.
5099   Soma - nothing listens on 234 (Soma lives on the workstation, localhost:5199).
pipe   rtmpipe_v3 - the engine<->adapter channel; its presence is half of the liveness pair.
```

### 13.3 Backups on 234 that must survive

```
C:\RTMView\Backup\rtmtwilio_aa19743_20260913_011524   357 files - the R4 rollback base. NEVER delete.
C:\RTMView\Backup\preinstall_20260830_004812          the state before the August install.
C:\RTMView\Backup\<ddMMyyyy_HHmm>\                    created by every Update-RTMView run (binaries +
                                                      pg_dump). Their APPEARANCE is part of the proof
                                                      that an install actually ran.
```

---

## 14. THE SHARED PORT, 8088 -> 8089 — what it was, how it was measured, what counts as acceptance

### 14.1 What was actually wrong (2026-09-13/14)

`tenant_settings."SignalRConnectionUrl"` for the tenant said `http://127.0.0.1:8088`, and **two engines
listened on 8088**: ours bound to `127.0.0.1`, the legacy `C:\IceDash\RTM\RTM.exe` bound to the wildcard
`::`. The Shell's five live sockets were held at the SERVER end by the legacy pid. Our engine had a
listener and **zero** established connections.

That is why, for a whole day, our engine's log showed no `OnConnected`, no `init GridId=`, no
`Groups.Add UnionId` and no `<<getUsers` while the Shell logged a successful handshake in the same
second: our engine was not silent, **nobody was asking it**. Every measurement of the re-subscription
subject taken before the move was against an engine the Shell had never been connected to.

### 14.2 The predicate that settled it — and the rule that did NOT

```powershell
Get-NetTCPConnection -RemotePort <port> -State Established   # client end, with OwningProcess
Get-NetTCPConnection -LocalPort  <port> -State Established   # server end, with OwningProcess
# then MATCH BY SOCKET NUMBER: the client's LocalPort must appear as the server's RemotePort
```
Both ends, matched by number, name the two processes without any theory. **"A more specific binding wins
over a wildcard" is a RULE, not a measurement — and here it did not hold**: ours was bound to
`127.0.0.1`, legacy to `::`, and the connection went to legacy. Whatever the cause (bind timing,
exclusivity, order), it was never measured, so the rule is not used as evidence again.

### 14.3 The move, and why it is two places and not three

```
1) engine  C:\RTMView\RTM\appsettings.json : Kestrel:Endpoints:Http:Url -> http://127.0.0.1:8089
2) database tenant_settings."SignalRConnectionUrl" -> http://127.0.0.1:8089   (UPDATE, exactly 1 row)
3) adapter  NOT touched - RTM:Targets[1].Url was ALREADY http://127.0.0.1:8089 with Pipe rtmpipe_v3
```
The adapter had been configured correctly all along; the ENGINE was the one that had diverged. Check the
DEPLOYED config, never the repository copy: they disagreed twice in one day (`log4net.config`, and the
adapter's target), and the machine was right both times.

### 14.4 Acceptance — "the port is taken" is NOT acceptance

```
1) exactly ONE listener on the new port, and it is our engine's pid
2) our pid is NO LONGER on the old port (legacy stays there; it is not ours to move)
3) the database value reads the new address, one row
4) THE REAL GATE: the Shell's sockets to the new port, matched by NUMBER at both ends, with our engine
   as the server. Anything less measures configuration, not connectivity.
```
Measured on 2026-09-14: engine restarted at `06:46:09.645`, five new sockets created at `06:46:48` -
client pid = our Shell, server pid = our engine, Shell process never restarted. The Shell re-attached on
its own in 39 seconds. Negative half, stated in advance: if the Shell is still on the old port after the
change, that is a STATE (it has not re-dialled), not a failed edit - report it and ask before restarting
the Shell, because that is a decision about someone's measurement window.

---

## 15. INSTRUMENT DEFECTS THAT COST THIS CYCLE — each one produced a confident wrong number

1. **A silent `StreamReader` on a live log.** `New-Object IO.StreamReader($path)` asks for
   `FileShare.Read`; a file open for writing by a service refuses it, and under
   `$ErrorActionPreference='Continue'` the refusal is SILENT - `$sr` stays `$null`, `ReadLine()` returns
   `$null`, and the probe prints a confident ZERO for all sixteen needles. Open with
   `FileShare.ReadWrite`, and make "non-empty file, zero lines read" a HARD FAIL.
2. **PowerShell variable names are CASE-INSENSITIVE.** `foreach ($port in @($PORT, $OLDPORT))` destroys
   `$PORT`: they are the same variable, and after the loop it holds the last element. Two later sections
   then measured the wrong port and printed zeros that looked like findings. Never let a loop variable
   differ from a constant only by case.
3. **A time predicate compared against a typed constant.** `Process.StartTime` carries fractions:
   `22:15:05.926 -gt 22:15:05.000` is true, so a gate meant to check "the Shell did not restart" went red
   on 400 milliseconds and stopped a valid run. Measure BOTH sides: "the Shell started BEFORE the window".
4. **A UTF-16 literal search from one byte alignment.** .NET stores string literals as UTF-16 and one may
   begin at an ODD offset; decoding the file once from offset 0 misses it, and a NEGATIVE control cannot
   catch that (an impossible literal is absent under both alignments). Decode from 0 AND 1, and add a
   POSITIVE control - a literal that must exist in any assembly.
5. **A fixed pause instead of a readiness signal** (see 4b) and **an ad-hoc box exempted from the probe
   rules** (see 4c).
6. **Printing the paths of files the run never wrote.** A probe that announces three outputs and then
   stops at a gate sends the operator hunting for files that do not exist. Print `WRITTEN` only for what
   exists; otherwise print `NOT WRITTEN` with the reason.

Common shape: **a zero across the WHOLE corpus is a suspicion about the instrument, not a fact about the
world.** POSCTL over the full file, per needle, is what separates the two - it caught defects 1 and 2 the
same night.
