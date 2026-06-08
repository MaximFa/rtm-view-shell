# CC Task — Build the Server-234 Full PG18 IN-PLACE package (from clean worktree @5a16226)

> Session devops-2-0607. Produce ONE zip that upgrades Server 234 IN-PLACE (Shell+RTM binaries +
> in-place DB migrations/functions via the hardened orchestrator). Variant (b): self-sufficient —
> the package deliberately contains NO fresh-install restore script, so the data-wipe HARD RULE is
> guaranteed by construction.
>
> ███ HARD RULE (coordinator, non-negotiable) ███
> On Server 234 NEVER run DROP DATABASE / pg_dump baseline-restore / Install-RTMView / Restore-SqlDump.
> 234 is IN-PLACE: apply migrations(5-set) + re-apply functions via Apply-Server45Upgrade.ps1 only.
> (The orchestrator's Invoke-Rollback may DROP+restore the Phase-2 backup of 234's OWN data — that is
> the rollback path, NOT a wipe, and is allowed.)

## 0. §0.6a integrity check FIRST (main WT). 0b. §40 skill reads. Standard preamble.

## Multi-session sync (§42.6) — slug devops-2-0607
Claims: **NONE** on tracked source. This is a READ-ONLY build off a fresh git worktree; outputs go to
untracked `Installations/` + a temp build dir. Do not modify any tracked file. No commit, no push.
- S1 push-barrier check: if `.coord/push/request.md` is non-empty → STOP, report.
- No S2/S3/S4 (nothing committed). Refresh heartbeat note only.
## Git push — DO NOT (§37). §0.3 — any throwaway script via Python+fsync.

---

## Build — all steps run NATIVE on Windows (git/dotnet work natively; the mount does not)

Constants: REPO=`D:\Claude\Projects\RTM View Shell` ; TIP=`5a16226` ; BUILD=`D:\Claude\_build\rtm-5a16226`
PKG=`D:\Claude\_build\pkg234` ; PG=18.

### Step 1 — CLEAN source worktree @5a16226 (FLAG-2: never build from the dirty WT)
```powershell
cd "D:\Claude\Projects\RTM View Shell"
if (Test-Path "D:\Claude\_build\rtm-5a16226") { git worktree remove --force "D:\Claude\_build\rtm-5a16226" 2>$null; Remove-Item -Recurse -Force "D:\Claude\_build\rtm-5a16226" -ErrorAction SilentlyContinue }
git worktree add -f "D:\Claude\_build\rtm-5a16226" 5a16226
# PROVE source = the approved tip:
$src = (git -C "D:\Claude\_build\rtm-5a16226" rev-parse HEAD)
if ($src -notlike "5a16226*") { throw "Worktree HEAD $src != 5a16226 — ABORT (FLAG-2)." }
"Worktree HEAD = $src"
```

### Step 2 — Publish binaries from the worktree (Shell = Web ; + RTM)
```powershell
$wt = "D:\Claude\_build\rtm-5a16226"
dotnet publish "$wt\src\CcDashboard.Web" -c Release -r win-x64 --self-contained -o "$wt\publish\shell"
dotnet publish "$wt\RTM\RTM"             -c Release -r win-x64 --self-contained -o "$wt\publish\rtm"
# sanity
if (-not (Test-Path "$wt\publish\shell\CcDashboard.Web.dll")) { throw "Shell publish failed." }
if (-not (Test-Path "$wt\publish\rtm\*.exe"))                 { throw "RTM publish failed." }
```
(NOTE: CcDashboard.Api is NOT in the orchestrator's deploy path (Shell+RTM only). If 234 runs a
separate Api site, that's out of scope for this orchestrator path — flag in the report, do not guess.)

### Step 3 — Assemble the IN-PLACE bundle (layout the orchestrator expects)
```powershell
$wt="D:\Claude\_build\rtm-5a16226"; $pkg="D:\Claude\_build\pkg234"
Remove-Item -Recurse -Force $pkg -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $pkg | Out-Null
# orchestrator + probe MUST sit next to each other (script does Join-Path $ScriptDir 'server45_dependency_probe.sql', '\migrations', '\functions')
Copy-Item "$wt\deploy\Apply-Server45Upgrade.ps1"        $pkg\
Copy-Item "$wt\staging\server45_dependency_probe.sql"   $pkg\
New-Item -ItemType Directory -Force "$pkg\functions"  | Out-Null; Copy-Item "$wt\db\functions\*.sql"  "$pkg\functions\"
New-Item -ItemType Directory -Force "$pkg\migrations" | Out-Null; Copy-Item "$wt\db\migrations\*.sql" "$pkg\migrations\"   # all 16 (no missing-file footgun; 234 applies 5 via -MigrationList)
Copy-Item "$wt\db\tools\Compare-ToBaseline.ps1"         $pkg\
# full db/ baseline for the VERIFY (Compare) step — READ-ONLY use only:
New-Item -ItemType Directory -Force "$pkg\db" | Out-Null
Copy-Item "$wt\db\schema.sql" "$pkg\db\"; Copy-Item -Recurse "$wt\db\functions" "$pkg\db\"; Copy-Item -Recurse "$wt\db\data" "$pkg\db\"; Copy-Item -Recurse "$wt\db\migrations" "$pkg\db\"
# binaries
New-Item -ItemType Directory -Force "$pkg\bin\Shell" | Out-Null; Copy-Item -Recurse "$wt\publish\shell\*" "$pkg\bin\Shell\"
New-Item -ItemType Directory -Force "$pkg\bin\RTM"   | Out-Null; Copy-Item -Recurse "$wt\publish\rtm\*"   "$pkg\bin\RTM\"
```

### Step 4 — Generate INSTALL.txt (the exact, ONLY-supported 234 command — UTF-8 BOM, §35)
Write `$pkg\INSTALL.txt` (Python+fsync, BOM) containing exactly:
```
SERVER 234 — FULL PG18 IN-PLACE UPGRADE. Run on 234 (PowerShell, Admin), from this extracted folder.
DO NOT run any DB restore / Install-RTMView / DROP DATABASE — this is an in-place upgrade.

1) Pre-flight (READ-ONLY): psql ... -f server45_dependency_probe.sql   (all 't' except db_patch_history=f)
2) Apply:
   .\Apply-Server45Upgrade.ps1 -PgVersion 18 -AutoRollback `
     -AppPassword "<APP_PW>" -SuperPassword "<PG_PW>" -InstallRoot "C:\RTMView" `
     -MigrationList "20260604_001_add_agent_state_pct_metrics.sql,20260605_004_metrics_dedup.sql,20260606_005_history_unavailable_metrics.sql,20260607_002_db_patch_history.sql,20260607_003_fix_curlogintimestamp.sql" `
     -ShellPublish ".\bin\Shell" -RtmPublish ".\bin\RTM"
   (_008 omitted — already applied on 234. Default-6 also safe; all migration files are present.)
3) Verify: Compare-ToBaseline.ps1 -BaselineDir .\db -Database rtmviewdb -User ccdashboard_user -Password "<APP_PW>" -OutDir .  => expect B=0.
```

### Step 5 — Zip into Installations/
```powershell
$ts = Get-Date -Format "yyyyMMdd-HHmm"
$zip = "D:\Claude\Projects\RTM View Shell\Installations\234_Full_PG18_$ts.zip"
Compress-Archive -Path "$pkg\*" -DestinationPath $zip -Force
"ZIP: $zip  $([math]::Round((Get-Item $zip).Length/1MB,1)) MB"
```

### Step 6 — HARD-RULE + FLAG self-tests (REQUIRED — report each)
```powershell
# (i) HARD RULE: package contains NO fresh-restore installer:
$bad = Get-ChildItem -Recurse $pkg | Where-Object { $_.Name -match 'Install-RTMView|Restore-SqlDump' -or $_.Name -ieq 'baseline.sql' }
if ($bad) { throw "HARD-RULE FAIL: restore-capable artefact in package: $($bad.Name -join ', ')" }
"HARD RULE i: no Install-RTMView / Restore-SqlDump / baseline.sql in package — OK"
# (i.b) ASSERT (not just report) every DROP DATABASE is INSIDE the Invoke-Rollback function body — FAIL otherwise.
$op   = "$pkg\Apply-Server45Upgrade.ps1"
$ast  = [System.Management.Automation.Language.Parser]::ParseFile($op, [ref]$null, [ref]$null)
$fn   = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-Rollback' }, $true)[0]
if (-not $fn) { throw "HARD-RULE FAIL: Invoke-Rollback function not found." }
$fnS = $fn.Extent.StartLineNumber; $fnE = $fn.Extent.EndLineNumber
$hits = Select-String -Path $op -Pattern 'DROP DATABASE'
foreach ($h in $hits) {
    if ($h.LineNumber -lt $fnS -or $h.LineNumber -gt $fnE) {
        throw "HARD-RULE FAIL: DROP DATABASE at line $($h.LineNumber) is OUTSIDE Invoke-Rollback ($fnS..$fnE)."
    }
}
"HARD RULE i.b: all $($hits.Count) DROP DATABASE statement(s) confirmed INSIDE Invoke-Rollback (lines $fnS..$fnE) — OK"
# (ii) FLAG-2 source proof:
"Worktree HEAD (build source) = $(git -C 'D:\Claude\_build\rtm-5a16226' rev-parse HEAD)  (must be 5a16226)"
# manifest
Add-Type -AssemblyName System.IO.Compression.FileSystem
$e=[System.IO.Compression.ZipFile]::OpenRead($zip).Entries.FullName
"bin/Shell: $(($e -like 'bin/Shell/*').Count)  bin/RTM: $(($e -like 'bin/RTM/*').Count)  migrations: $(($e -like 'migrations/*').Count)  functions: $(($e -like 'functions/*').Count)"
@('Apply-Server45Upgrade.ps1','server45_dependency_probe.sql','Compare-ToBaseline.ps1','INSTALL.txt') | % { "$(if($_ -in $e){'[OK]'}else{'[MISS]'}) $_" }
```
Expected: HARD RULE i OK ; (i.b) AST-asserts every DROP DATABASE inside Invoke-Rollback (throws otherwise) ; worktree HEAD = 5a16226 ;
migrations=16, functions=4, bin/Shell>0, bin/RTM>0, all 4 named files [OK].

### Step 7 — Cleanup worktree (keep the zip)
```powershell
git worktree remove --force "D:\Claude\_build\rtm-5a16226"
```

## Report back
ZIP path + size ; the 4 manifest counts ; HARD-RULE i result ; the (i.b) AST assertion result (count of DROP DATABASE + Invoke-Rollback line range, must PASS) ; worktree HEAD proof (=5a16226) ; any Api-site note. NOTHING committed, NO push.
