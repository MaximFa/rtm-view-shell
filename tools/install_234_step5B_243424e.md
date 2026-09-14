# STEP 5 — PART B: install on 234, and leave the system in a state the acceptance run can measure

> Author: devops-0912, 2026-09-13. **REV 2** - this file changed after its first review; do not treat a
> familiar path as work already done. What changed: `-SkipDrift` is now part of every installer
> invocation, and the reason is recorded below. Everything else stands as reviewed.
> Entry pins, re-measured: `v3 = 243424e`, `adapters = 8d28531`.
> Awaiting coordinator §4 on the TEXT; the word to HAND OUT comes separately.
> Every box below runs on **SERVER 234** and WRITES. Nothing here runs on the workstation.
> The acceptance measurement is NOT in this document — it belongs to `shell-0912` and comes after.

## 0. WHAT WE ARE INSTALLING — named before it is installed

```
RTM package   13092026.1653_RTM.zip     77 823 467 B
              sha256 7A25E17195BC85CFA35068D959E95C82CE18F0C74EC85F0F86DB30F175DC7607
Shell package 13092026.1654_Shell.zip   55 709 284 B
              sha256 2DE008B727F065765CB515B6B3F3D48301B34CF509DF796D4D76F177A3C68C51
adapter       publish\twilio\  RTM.Twilio.exe 151 552 B
              sha256 CC124AC26C6D27037E424987AFF105BA03C1371789E5FE9C901E73F24BC2850E
built from    v3 = 243424e  (Shell + engine)   adapters = 8d28531  (adapter)
tests         RTM.Adapter.Common.Tests 14/14/0 · CcDashboard.Tests.Unit 284/284/0 · engine: NO test project
```
These sha256 values come from the build run, not from my own measurement. **Every one of them is
re-measured on 234 after the transfer, before anything is installed** — that is the first gate below.

## 0b. WHY `-SkipDrift`, recorded in the words that belong in the registry

The drift gate fired on the first attempt and stopped the deploy. It was RIGHT to fire in the sense that
it finally ran at all - `PR234-INST-12`, fixed this morning, is why it resolved its tool for the first
time in the package layout. But what it measured was itself:

```
B \ S  - routine names declared by the package's own db module, absent on the server : 0
S \ B  - names on the server beyond the package : 59, of which 57 are POSTGRES EXTENSION functions
         (pgcrypto, pg_trgm, pg_stat_statements) and 2 are ours from history partitioning
tables / indexes / constraints / sequences : none missing, none extra
prokind: matches fully · metrics: match · migration ledger: nothing unapplied · sequences: no 23505 risk
```
[measured: `.measurements/234_20260913_175300_routine-sets.txt`, negative control 0, psql exit 0, port 5433]

So the comparator counts extension functions as drift and compares routine signatures in two different
notations (baseline `name(types)`, server `name(mode name type)`), which makes every routine appear as
both missing and extra. That is `PR234-CMP-01`, and it means the gate is false-red BY CONSTRUCTION on
any database with pgcrypto and pg_trgm enabled - ours, always.

**This is therefore not "the gate was bypassed". It is: deploying over a database verified by a DIFFERENT
predicate, because the standard one is broken and its brokenness is measured.** The operator decided to
install today on that basis [operator's word, 2026-09-13].

`-SkipDrift` is the flag used, NOT `-ForceDeploy`. Their behaviour is identical at `Update-RTMView.ps1:161`,
but the name goes into the history and must say exactly what was done: we skipped a named, broken gate -
we did not force a deploy past a real warning.

**The `[E1] drift tool resolved:` line must still be printed and reported.** Its meaning changes: it no
longer says "no drift", it says we skipped THIS gate deliberately rather than losing it silently again.
No such line means the run never reached the gate - report that, do not assume it.

**And know the cost before it is paid:** `PR234-INST-13` is NOT fixed today - a throw at any step after
step 1 leaves both services stopped, as it did at 17:31 for ~8 minutes. If that happens, bring them up
with the same box as at 17:39 (RTMService, then RTMTwilio_1, then RTMViewShell) and do not improvise.

## 1. TRAPS IN THE TOOL ITSELF — read before the first box

1. **`Update-RTMView.ps1` defaults to `-DBPort 5432`. On 234 that is the OLD PostgreSQL 15.**
   The live database is PG18 on **5433**. `-DBPort 5433` is mandatory on every invocation. This is a
   defect of the installer's defaults, not our forgetfulness — it is recorded as such.
2. **`-SkipShell` / `-SkipRTM` do NOT leave the other service alone — both get bounced.** So an install
   move restarts the Shell too, and the acceptance window can NOT be taken from an install bounce (§5).
3. **`-DBPassword` is entered ONLY as `Read-Host -AsSecureString`.** A bare prompt already put the
   production superuser password into a chat once. Also: without it the internal `pg_dump` overwrites
   `PGPASSWORD` and the run dies AFTER both services are stopped (13.07).
4. **`-FreshDb` is never spoken, and neither is `-ForceDeploy`** - the flag is `-SkipDrift` (see 0b). No migrations in this batch: `-MigrationList` stays empty.
5. `-SkipCacheMigration` on every invocation — we are not migrating Memurai to Garnet here.
6. `.ps1` arriving from another machine carries mark-of-the-web: `Unblock-File` is step 0, always.

## 2. PERIMETER — absolute, on every box

`C:\IceDash\` is not touched by anything, including reads. The production `RTM.Twilio` service is not
touched. Legacy `RTM` runs permanently and is not touched. PostgreSQL 15 on 5432 is not touched.
`C:\Program Files\CcDashboard\` (the May-built second Shell) is not touched. Machine 140 is not addressed.
`C:\RTMView\Backup\rtmtwilio_aa19743_20260913_011524` (357 files) is NOT deleted — it is the R4 rollback base.

## 3. ORDER — three moves, a report between each. They are NOT merged

```
C0  transfer + verify sha256 of both packages and the adapter payload ON 234      (read + copy only)
C1  engine:  Update-RTMView.ps1 -SkipShell -SkipDrift -DBPort 5433 -SkipCacheMigration  (writes, bounces both)
C2  shell:   Update-RTMView.ps1 -SkipRTM   -SkipDrift -DBPort 5433 -SkipCacheMigration  (writes, bounces both)
C3  adapter: stop RTMTwilio_1 -> full directory backup -> lay down publish ->
             restore the machine appsettings.json from that backup with a sha check -> start
C4  proof of provenance and of update, one reading probe                          (read only)
```
Merging moves costs us the ability to say WHICH one broke. That is the whole reason for the split.

## 4. GATES PER MOVE — stated before the numbers

**C0.** `Get-FileHash -Algorithm SHA256` of both zips on 234 must equal the three values in §0.
Mismatch = STOP, nothing is installed, the transfer is repeated. A package whose hash does not match
is not "probably fine".

**C1 / C2.** Before: record `ProductVersion`, sha256 and mtime of `RTM.exe` and `CcDashboard.Web.exe`,
the file count of each installation directory, and the newest file time there. After, the installer's
own output must show:
- the `[E1] drift tool resolved:` line — this proves the drift gate actually RAN. Since `PR234-INST-12`
  a missing tool THROWS instead of silently skipping, so a green run with no such line means the gate
  never reached and must be reported, not assumed;
- no `Applying migration` anywhere, and the EF history count unchanged — no migrations ship in this batch;
- a pre-install backup directory that did NOT exist before (there were 0 of them at measurement A).
Then: service Running, `/health` 200 **and** the pipe `rtmpipe_v3` present in
`[IO.Directory]::GetFiles("\\.\pipe\")` — `/health` alone is a false liveness criterion, the HTTP host
comes up whether or not the engine did.

**C3.** The machine `appsettings.json` of the adapter is restored from the backup made in the same move,
and its sha256 is compared against the value recorded in measurement A. The installer is not involved.

**C4 — provenance of what actually LANDED, mandatory (coordinator, 2026-09-13).** One reading probe
prints, for each of `C:\RTMView\RTM\RTM.exe`, `C:\RTMView\Shell\CcDashboard.Web.exe`,
`C:\RTMView\RTM.Twilio\RTM.Twilio.exe`, three things on three lines:
```
ProductVersion          <- accompanies; it is a stamp, not a proof
PDB compilation root    <- proves WHOSE binary this is; read from inside the assembly
sha256                  <- proves its exact composition
```
Expected roots: the two from the clean `v3` clone, and `D:\Claude\Projects\RTMView-adapters-wt` for the
adapter. **If even one does not match, the install is declared unproven by provenance — and that is NOT
a reason to quietly reinstall: it goes to the coordinator.** The instrument already exists and runs in
seconds: `.probes/probe_234_20260913_literals.ps1`, extended to these three paths.
Same probe carries the second floor of integrity: hash and size prove that what was placed equals what
was taken; a CONTENT anchor (a known literal, the version line, a config key) proves it was whole.

## 5. THE ONE THING THAT DECIDES WHETHER THE DAY COUNTS

The acceptance predicate for `PR234-SHELL-RESUB-01` holds only if the Shell process did **not** restart
in the measured window. Install moves bounce the Shell (§1.2), so **the window may not start from an
install bounce** — doing so yields a GREEN that proves nothing and would close the subject without
fixing it. That false green is worse than any of today's false reds.

Therefore the report of this part prints **two times, not one**:
```
T1 = the LAST install-time restart of each service (engine, shell, adapter), to the second
T2 = a SEPARATE, deliberate restart of the ENGINE ONLY, performed after everything has settled
```
and the invariant holds at T2 as well: **restarting the engine is always accompanied by restarting the
adapter** — on this revision the adapter has no reconnect of its own, and a probe taken after a lone
engine restart is invalid. The supervisor added in `fc51ae0` ships here for the first time and is NOT
relied upon in the same window that is supposed to measure something else; it gets its own check later.
`shell-0912` takes the window from T2 and must confirm from his own log that the Shell did not restart in it.

## 6. WHAT THIS PART DOES NOT PROVE, said before the numbers

- The adapter's auto-reconnect supervisor is newly deployed and unverified here.
- `PR234-INST-11` (the dead resync in step 7 of `Provision-FreshDb`) is untouched: `Update-RTMView`
  never calls it, so it travels as a passenger and closes only on a clean install.
- The engine change has no test coverage at all (`PR234-ENGINE-NOTESTS-01`).
- Nothing here proves the fixes WORK; it proves what is installed and that the system is measurable.
  Working is what the acceptance run measures, and it belongs to `shell-0912`.
