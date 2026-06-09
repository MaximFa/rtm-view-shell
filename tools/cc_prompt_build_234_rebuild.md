# CC Task — REBUILD Server-234/next Full IN-PLACE package (clean worktree @160259a)

> Session devops-2-0607. Rebuild of the in-place package from the POST-orchestrator-patch tip 160259a
> (contains d6b1672: E-015 psql-stderr+abort-rollback, E-016 fn01 sig-agnostic DROP, E-018 orphan-exe kill,
> E-010a -ReleaseCommit manifest). Supersedes the 5a16226 build. Variant (b): self-sufficient — NO fresh-install
> restore script in the package, so the data-wipe HARD RULE holds by construction.
>
> ███ HARD RULE (coordinator, non-negotiable) ███
> On Server 234 NEVER run DROP DATABASE / pg_dump baseline-restore / Install-RTMView / Restore-SqlDump.
> 234 is IN-PLACE: apply migrations(5-set) + re-apply functions via Apply-Server45Upgrade.ps1 only.
> (Invoke-Rollback may DROP+restore the Phase-2 backup of 234's OWN data — that is rollback, NOT a wipe.)

## 0. §0.6a integrity check FIRST (main WT). 0b. §40 skill reads. Standard preamble.

## Multi-session sync (§42.6) — slug devops-2-0607
Claims: **NONE** on tracked source. READ-ONLY build off a fresh git worktree; outputs to untracked
`Installations/` + temp build dir. Modify no tracked file. No commit, no push.
- S1 push-barrier (MARKER-based): `grep -q "FREEZE ACTIVE" .coord/push/request.md` -> if match STOP & report.
  A non-empty tombstone ("BARRIER CLEARED"/"FREEZE LIFTED") does NOT block.
- No S2/S3/S4 (nothing committed). Refresh heartbeat note only.
## Git push — DO NOT (§37). §0.3 — any throwaway script via Python+fsync.

---

## Build — all steps run NATIVE on Windows (git/dotnet/psql work natively; the mount does not)

Constants: REPO=`D:\Claude\Projects\RTM View Shell` ; TIP=`160259a` ; BUILD=`D:\Claude\_build\rtm-160259a`
PKG=`D:\Claude\_build\pkg234` ; build-box PG=18.

### Step 1 — CLEAN source worktree @160259a (FLAG-2: never build from the dirty WT)
```powershell
cd "D:\Claude\Projects\RTM View Shell"
if (Test-Path "D:\Claude\_build\rtm-160259a") { git worktree remove --force "D:\Claude\_build\rtm-160259a" 2>$null; Remove-Item -Recurse -Force "D:\Claude\_build\rtm-160259a" -ErrorAction SilentlyContinue }
git worktree add -f "D:\Claude\_build\rtm-160259a" 160259a
$src = (git -C "D:\Claude\_build\rtm-160259a" rev-parse HEAD)
if ($src -notlike "160259a*") { throw "Worktree HEAD $src != 160259a — ABORT (FLAG-2)." }
"Worktree HEAD = $src"
```

### Step 2 — Publish binaries from the worktree (Shell = Web ; + RTM)
```powershell
$wt = "D:\Claude\_build\rtm-160259a"
dotnet publish "$wt\src\CcDashboard.Web" -c Release -r win-x64 --self-contained -o "$wt\publish\shell"
dotnet publish "$wt\RTM\RTM"             -c Release -r win-x64 --self-contained -o "$wt\publish\rtm"
if (-not (Test-Path "$wt\publish\shell\CcDashboard.Web.dll")) { throw "Shell publish failed." }
if (-not (Test-Path "$wt\publish\rtm\*.exe"))                 { throw "RTM publish failed." }
```
(CcDashboard.Api NOT in the orchestrator deploy path — Shell+RTM only, per coordinator. No Api on 234.)

### Step 3 — Assemble the IN-PLACE bundle (layout the orchestrator expects)
```powershell
$wt="D:\Claude\_build\rtm-160259a"; $pkg="D:\Claude\_build\pkg234"
Remove-Item -Recurse -Force $pkg -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $pkg | Out-Null
# orchestrator + probe MUST sit next to each other (Join-Path $ScriptDir 'server45_dependency_probe.sql','\migrations','\functions')
Copy-Item "$wt\deploy\Apply-Server45Upgrade.ps1"        $pkg\
Copy-Item "$wt\staging\server45_dependency_probe.sql"   $pkg\
New-Item -ItemType Directory -Force "$pkg\functions"  | Out-Null; Copy-Item "$wt\db\functions\*.sql"  "$pkg\functions\"
New-Item -ItemType Directory -Force "$pkg\migrations" | Out-Null; Copy-Item "$wt\db\migrations\*.sql" "$pkg\migrations\"   # all 16; 234 applies 5 via -MigrationList
Copy-Item "$wt\db\tools\Compare-ToBaseline.ps1"         $pkg\
New-Item -ItemType Directory -Force "$pkg\db" | Out-Null
Copy-Item "$wt\db\schema.sql" "$pkg\db\"; Copy-Item -Recurse "$wt\db\functions" "$pkg\db\"; Copy-Item -Recurse "$wt\db\data" "$pkg\db\"; Copy-Item -Recurse "$wt\db\migrations" "$pkg\db\"
New-Item -ItemType Directory -Force "$pkg\bin\Shell" | Out-Null; Copy-Item -Recurse "$wt\publish\shell\*" "$pkg\bin\Shell\"
New-Item -ItemType Directory -Force "$pkg\bin\RTM"   | Out-Null; Copy-Item -Recurse "$wt\publish\rtm\*"   "$pkg\bin\RTM\"
```

### Step 4 — Generate INSTALL.txt (UTF-8 BOM, §35). NEW: -ReleaseCommit + -PgVersion per target.
Write `$pkg\INSTALL.txt` (Python+fsync, BOM) containing exactly:
```
SERVER 234/next — FULL IN-PLACE UPGRADE. Run on target (PowerShell, ADMIN — required: Stop-Service needs elevation), from this extracted folder.
DO NOT run any DB restore / Install-RTMView / DROP DATABASE — this is an in-place upgrade.

-PgVersion: set to the TARGET server's PostgreSQL major (234 = 15  [prod data on :5432, PG15.5];  fresh PG18 server = 18).
The orchestrator auto-detects the running server version and logs it; -PgVersion selects the matching client toolchain (psql/pg_dump bin).

1) Pre-flight (READ-ONLY): psql ... -f server45_dependency_probe.sql   (all 't' except db_patch_history=f)
2) Apply:
   .\Apply-Server45Upgrade.ps1 -PgVersion <15|18 per target> -AutoRollback -ReleaseCommit "160259a" `
     -AppPassword "<APP_PW>" -SuperPassword "<PG_PW>" -InstallRoot "C:\RTMView" `
     -MigrationList "20260604_001_add_agent_state_pct_metrics.sql,20260605_004_metrics_dedup.sql,20260606_005_history_unavailable_metrics.sql,20260607_002_db_patch_history.sql,20260607_003_fix_curlogintimestamp.sql" `
     -ShellPublish ".\bin\Shell" -RtmPublish ".\bin\RTM"
   (_008 omitted — already applied on 234. Default-6 also safe; all migration files present.)
   On success the orchestrator writes C:\RTMView-Ops\SERVER.md + _ledger.txt with ReleaseCommit=160259a (E-010a).
3) Verify: Compare-ToBaseline.ps1 -BaselineDir .\db -Database rtmviewdb -User ccdashboard_user -Password "<APP_PW>" -OutDir .  => expect B=0.
```

### Step 5 — Zip into Installations/
```powershell
$ts = Get-Date -Format "yyyyMMdd-HHmm"
$zip = "D:\Claude\Projects\RTM View Shell\Installations\234_Full_rebuild_160259a_$ts.zip"
Compress-Archive -Path "$pkg\*" -DestinationPath $zip -Force
"ZIP: $zip  $([math]::Round((Get-Item $zip).Length/1MB,1)) MB"
```

### Step 6 — E-016 REGRESSION GUARD (REQUIRED — fresh-DB re-apply, no longer static-only)
Proves on a REAL DB that re-applying functions/01 on a procedure-server no longer aborts (the 234 defect).
Runs on the build box's PG18 against a THROWAWAY DB. If no Postgres on the build box: SKIP and report
"E-016 guard NOT run (no PG) — must validate on next server redeploy" (do NOT silently pass).
```powershell
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$wt   = "D:\Claude\_build\rtm-160259a"
if (Test-Path $psql) {
  # fresh DB = apply #1 (schema+functions+data). Uses the §39 dev convention (local rtmviewdb recreated).
  powershell -ExecutionPolicy Bypass -File "$wt\db\tools\Create-FreshDb.ps1" -AppPassword "!@#qweASDzxc" -SuperPassword "!@#qweASDzxc"
  $env:PGPASSWORD="!@#qweASDzxc"
  & $psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f "$wt\db\functions\01_ngc_functions.sql" | Out-Null; $r1=$LASTEXITCODE
  & $psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f "$wt\db\functions\01_ngc_functions.sql" | Out-Null; $r2=$LASTEXITCODE   # RE-APPLY = the E-016 guard
  $bad = (& $psql -h localhost -U postgres -d rtmviewdb -t -A -c "SELECT count(*) FROM pg_proc WHERE proname LIKE 'NGC_%' AND prokind NOT IN ('p','f');").Trim()
  $env:PGPASSWORD=$null
  if ($r1 -ne 0 -or $r2 -ne 0) { throw "E-016 GUARD FAIL: 01 apply exit r1=$r1 r2=$r2 (expect 0/0)." }
  if ([int]$bad -ne 0)         { throw "E-016 GUARD FAIL: $bad NGC_% routines with unexpected prokind." }
  "E-016 guard: fresh-DB apply + RE-APPLY 01 exit 0/0; NGC prokind clean ($bad bad) — PASS"
} else { "E-016 guard: NO PG on build box — NOT RUN. Must validate on next server redeploy." }
```

### Step 7 — HARD-RULE + FLAG self-tests (REQUIRED — report each)
```powershell
$pkg="D:\Claude\_build\pkg234"
# (i) HARD RULE: NO fresh-restore installer in the package:
$bad = Get-ChildItem -Recurse $pkg | Where-Object { $_.Name -match 'Install-RTMView|Restore-SqlDump' -or $_.Name -ieq 'baseline.sql' }
if ($bad) { throw "HARD-RULE FAIL: restore-capable artefact in package: $($bad.Name -join ', ')" }
"HARD RULE i: no Install-RTMView / Restore-SqlDump / baseline.sql — OK"
# (i.b) ASSERT every DROP DATABASE is INSIDE Invoke-Rollback — FAIL otherwise.
$op  = "$pkg\Apply-Server45Upgrade.ps1"
$ast = [System.Management.Automation.Language.Parser]::ParseFile($op, [ref]$null, [ref]$null)
$fn  = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-Rollback' }, $true)[0]
if (-not $fn) { throw "HARD-RULE FAIL: Invoke-Rollback not found." }
$fnS=$fn.Extent.StartLineNumber; $fnE=$fn.Extent.EndLineNumber
$hits = Select-String -Path $op -Pattern 'DROP DATABASE'
foreach ($h in $hits) { if ($h.LineNumber -lt $fnS -or $h.LineNumber -gt $fnE) { throw "HARD-RULE FAIL: DROP DATABASE line $($h.LineNumber) OUTSIDE Invoke-Rollback ($fnS..$fnE)." } }
"HARD RULE i.b: all $($hits.Count) DROP DATABASE inside Invoke-Rollback ($fnS..$fnE) — OK"
# (i.c) E-010a present: -ReleaseCommit param + SERVER.md manifest write
if (-not (Select-String -Path $op -Pattern '\$ReleaseCommit'))  { throw "E-010a FAIL: -ReleaseCommit param missing." }
if (-not (Select-String -Path $op -Pattern 'SERVER\.md'))       { throw "E-010a FAIL: SERVER.md manifest write missing." }
"E-010a: -ReleaseCommit param + SERVER.md manifest present — OK"
# (ii) FLAG-2 source proof + manifest
"Worktree HEAD (build source) = $(git -C 'D:\Claude\_build\rtm-160259a' rev-parse HEAD)  (must be 160259a)"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$e=[System.IO.Compression.ZipFile]::OpenRead($zip).Entries.FullName
"bin/Shell: $(($e -like 'bin/Shell/*').Count)  bin/RTM: $(($e -like 'bin/RTM/*').Count)  migrations: $(($e -like 'migrations/*').Count)  functions: $(($e -like 'functions/*').Count)"
@('Apply-Server45Upgrade.ps1','server45_dependency_probe.sql','Compare-ToBaseline.ps1','INSTALL.txt') | % { "$(if($_ -in $e){'[OK]'}else{'[MISS]'}) $_" }
```
Expected: HARD RULE i OK ; i.b AST-assert pass ; E-010a present ; worktree HEAD=160259a ; migrations=16, functions=4, bin/Shell>0, bin/RTM>0, all 4 named files [OK].

### Step 8 — Cleanup worktree (keep the zip)
```powershell
git worktree remove --force "D:\Claude\_build\rtm-160259a"
```

## Report back
ZIP path+size ; 4 manifest counts ; HARD-RULE i ; i.b AST assert (DROP DATABASE count + Invoke-Rollback range) ;
E-010a present ; **E-016 guard result (PASS with r1/r2=0/0, or NOT-RUN if no PG)** ; worktree HEAD=160259a.
NOTHING committed, NO push.
