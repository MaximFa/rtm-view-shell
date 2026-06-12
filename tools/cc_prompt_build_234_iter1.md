# CC Task — Build 234 ITER-1 INFRA package (from PUSHED tip 60fc6aa) + deploy steps

> Session devops-2-0607. 234 iteration-1 = INFRA-ONLY hot-reload + security remediation. NO new metric
> (that is iter-2, metrics-3 on HOLD). Reuse the existing 234 DB. Builds ONE in-place package from the
> pushed origin tip 60fc6aa + an INSTALL.txt the coordinator §4-reviews before the operator runs on 234.
>
> ███ HARD RULE (234, non-negotiable) ███ IN-PLACE only. NEVER DROP DATABASE / pg_dump-restore / Install-RTMView /
> Restore-SqlDump. Migrations + functions re-apply + binaries via Apply-Server45Upgrade.ps1 only.
> Iter-1 carries (in 60fc6aa): ApplyService (F-2/4/5/6 guards), orchestrator (deploys ApplyService 127.0.0.1 +
> catowner role + token wiring), F-3 loopback (hub *:8088->127.0.0.1 + SignalRConnectionUrl loopback), F-1 read-only MetricsPage.

## 0. §0.6a integrity FIRST. 0b. §40 reads. Standard preamble.
## Sync slug devops-2-0607. Claims: NONE (read-only build off a worktree; outputs to Installations/). No commit, no push.
- S1 marker barrier (grep FREEZE ACTIVE -> STOP). No S2/S3/S4. §37 no push. Build runs NATIVE on Windows.

Constants: REPO=`D:\Claude\Projects\RTM View Shell` ; TIP=`60fc6aa` ; WT=`D:\Claude\_build\rtm-60fc6aa` ; PKG=`D:\Claude\_build\pkg234_iter1` ; 234 PG=15.

### Step 1 — CLEAN worktree @60fc6aa (build from the PUSHED tip exactly)
```powershell
cd "D:\Claude\Projects\RTM View Shell"
if (Test-Path $WT) { git worktree remove --force "D:\Claude\_build\rtm-60fc6aa" 2>$null; Remove-Item -Recurse -Force "D:\Claude\_build\rtm-60fc6aa" -ErrorAction SilentlyContinue }
git worktree add -f "D:\Claude\_build\rtm-60fc6aa" 60fc6aa
$src = git -C "D:\Claude\_build\rtm-60fc6aa" rev-parse HEAD
if ($src -notlike "60fc6aa*") { throw "Worktree HEAD $src != 60fc6aa — ABORT." }
"Worktree HEAD = $src"
```

### Step 2 — Publish THREE binaries (§27 fixed dirs, self-contained win-x64)
```powershell
$wt="D:\Claude\_build\rtm-60fc6aa"
dotnet publish "$wt\src\CcDashboard.Web"          -c Release -r win-x64 --self-contained -o "$wt\publish\shell"
dotnet publish "$wt\RTM\RTM"                       -c Release -r win-x64 --self-contained -o "$wt\publish\rtm"
dotnet publish "$wt\src\CcDashboard.ApplyService"  -c Release -r win-x64 --self-contained -o "$wt\publish\applysvc"
foreach ($p in @("shell\CcDashboard.Web.dll","applysvc\CcDashboard.ApplyService.dll")) { if (-not (Test-Path "$wt\publish\$p")) { throw "publish missing: $p" } }
if (-not (Test-Path "$wt\publish\rtm\*.exe")) { throw "RTM publish failed." }
```

### Step 3 — Assemble in-place bundle (orchestrator layout)
```powershell
$wt="D:\Claude\_build\rtm-60fc6aa"; $pkg="D:\Claude\_build\pkg234_iter1"
Remove-Item -Recurse -Force $pkg -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $pkg | Out-Null
Copy-Item "$wt\deploy\Apply-Server45Upgrade.ps1"      $pkg\
Copy-Item "$wt\staging\server45_dependency_probe.sql" $pkg\
Copy-Item "$wt\db\tools\Compare-ToBaseline.ps1"       $pkg\
New-Item -ItemType Directory -Force "$pkg\functions"  | Out-Null; Copy-Item "$wt\db\functions\*.sql"  "$pkg\functions\"
New-Item -ItemType Directory -Force "$pkg\migrations" | Out-Null; Copy-Item "$wt\db\migrations\*.sql" "$pkg\migrations\"   # incl 20260609_010_metric_deploy_log.sql
New-Item -ItemType Directory -Force "$pkg\db\setup"   | Out-Null; Copy-Item "$wt\db\setup\*.sql"      "$pkg\db\setup\"     # 02_catowner_role.sql (orchestrator reads db\setup\)
New-Item -ItemType Directory -Force "$pkg\db" | Out-Null
Copy-Item "$wt\db\schema.sql" "$pkg\db\"; Copy-Item -Recurse "$wt\db\functions" "$pkg\db\"; Copy-Item -Recurse "$wt\db\data" "$pkg\db\"; Copy-Item -Recurse "$wt\db\migrations" "$pkg\db\"
New-Item -ItemType Directory -Force "$pkg\bin\Shell"      | Out-Null; Copy-Item -Recurse "$wt\publish\shell\*"    "$pkg\bin\Shell\"
New-Item -ItemType Directory -Force "$pkg\bin\RTM"        | Out-Null; Copy-Item -Recurse "$wt\publish\rtm\*"      "$pkg\bin\RTM\"
New-Item -ItemType Directory -Force "$pkg\bin\ApplyService" | Out-Null; Copy-Item -Recurse "$wt\publish\applysvc\*" "$pkg\bin\ApplyService\"
```

### Step 4 — INSTALL.txt = the DEPLOY STEPS (UTF-8 BOM, §35). Write exactly:
```
SERVER 234 — ITER-1 INFRA (hot-reload + security). PowerShell ADMIN, from this extracted folder. IN-PLACE — NO DB restore / Install-RTMView / DROP DATABASE.
234 = PostgreSQL 15 (prod data on :5432).

STEP A — Pre-flight (READ-ONLY go/no-go): the orchestrator runs server45_dependency_probe.sql at Phase 0; if anything required is missing it STOPS. (Optional: run Compare-ToBaseline.ps1 -BaselineDir .\db -Database rtmviewdb -User ccdashboard_user -Password "<APP_PW>" -OutDir . first to confirm the migration delta.)

STEP B — Apply (in-place upgrade; ApplyService deployed + provisioned + F-3 rebind happen inside):
  .\Apply-Server45Upgrade.ps1 -PgVersion 15 -AutoRollback -ReleaseCommit "60fc6aa" `
    -AppPassword "<APP_PW>" -SuperPassword "<PG_PW>" -InstallRoot "C:\RTMView" `
    -MigrationList "20260609_010_metric_deploy_log.sql" `
    -ShellPublish ".\bin\Shell" -RtmPublish ".\bin\RTM" -ApplyServicePublish ".\bin\ApplyService"
  (010 = new metric_deploy_log ledger. 234 already has the prior set; if Compare flags more unapplied, append them to -MigrationList. functions/ re-apply (Phase 5) refreshes NGC procs incl the sig-agnostic 01 fix. ApplyService: catowner role + CSRNG token in env-registry + appsettings 127.0.0.1. F-3: RTM hub -> 127.0.0.1:8088 + SignalRConnectionUrl loopback. On success -> SERVER.md manifest (ReleaseCommit=60fc6aa).)
  NO metric create/migrate (iter-2).

STEP C — POST-DEPLOY OPERATOR CHECKS (capture output to C:\RTMView-Ops\output\):
  DG-1 [F-3 runtime proof]: Get-NetTCPConnection -State Listen -LocalPort 8088 | Select LocalAddress,LocalPort
        -> LocalAddress MUST be 127.0.0.1 ONLY (NO :: / 0.0.0.0). If :: -> FAIL, F-3 not effective.
  DG-2 [F-2 fail-closed]: confirm the RTMApplyService env-registry has a REAL ApplyService__Token (not REPLACE_AT_DEPLOY)
        and Shell has MetricsApply__Token. Get-Service RTMApplyService -> Running. If the token were placeholder the
        F-2 startup guard REFUSES to start (service stops) — that is the expected fail-closed behaviour, not a bug.
        Smoke: Invoke-WebRequest http://127.0.0.1:5099/apply-metrics -Method POST  -> 401 (no token) ; with the real Bearer + empty body -> handled per contract.
  ITER-1 ACCEPTANCE (infra-only, NO metric): metric_deploy_log table exists ; RTMHub.compileMetrics registered (RTM log) ;
        Shell "Deploy new metrics" tab renders with EMPTY undeployed list (correct — no new metric) ; existing Shell/RTM/grids work, RTM log clean (no regression).
```

### Step 5 — Zip
```powershell
$ts = Get-Date -Format "yyyyMMdd-HHmm"
$zip = "D:\Claude\Projects\RTM View Shell\Installations\234_iter1_60fc6aa_$ts.zip"
Compress-Archive -Path "$pkg\*" -DestinationPath $zip -Force
"ZIP: $zip  $([math]::Round((Get-Item $zip).Length/1MB,1)) MB"
```

### Step 6 — B-test apply-twice idempotent (ACTUALLY RUN on build-box PG, NOT static)
Proves the iter-1 re-applies are idempotent (the coordinator requirement). Throwaway DB; if no PG -> report NOT-RUN (no silent pass).
```powershell
$psql="C:\Program Files\PostgreSQL\18\bin\psql.exe"; $wt="D:\Claude\_build\rtm-60fc6aa"
if (Test-Path $psql) {
  powershell -ExecutionPolicy Bypass -File "$wt\db\tools\Create-FreshDb.ps1" -AppPassword "!@#qweASDzxc" -SuperPassword "!@#qweASDzxc"
  $env:PGPASSWORD="!@#qweASDzxc"
  # migration 010 twice
  & $psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f "$wt\db\migrations\20260609_010_metric_deploy_log.sql"|Out-Null; $m1=$LASTEXITCODE
  & $psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f "$wt\db\migrations\20260609_010_metric_deploy_log.sql"|Out-Null; $m2=$LASTEXITCODE
  # functions/01 twice (sig-agnostic re-apply guard)
  & $psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f "$wt\db\functions\01_ngc_functions.sql"|Out-Null; $f1=$LASTEXITCODE
  & $psql -h localhost -U postgres -d rtmviewdb -v ON_ERROR_STOP=1 -f "$wt\db\functions\01_ngc_functions.sql"|Out-Null; $f2=$LASTEXITCODE
  $env:PGPASSWORD=$null
  if ($m1 -or $m2 -or $f1 -or $f2) { throw "APPLY-TWICE GUARD FAIL: mig=$m1/$m2 fn01=$f1/$f2 (expect 0/0/0/0)." }
  "apply-twice idempotent: migration 010 = $m1/$m2 ; functions/01 = $f1/$f2 (all 0) — PASS"
} else { "apply-twice: NO PG on build box — NOT RUN (must validate on 234 redeploy)." }
```

### Step 7 — HARD-RULE + manifest self-tests
```powershell
$pkg="D:\Claude\_build\pkg234_iter1"
$bad = Get-ChildItem -Recurse $pkg | ? { $_.Name -match 'Install-RTMView|Restore-SqlDump' -or $_.Name -ieq 'baseline.sql' }
if ($bad) { throw "HARD-RULE FAIL: $($bad.Name -join ', ')" }; "HARD RULE i: no restore installer — OK"
$op="$pkg\Apply-Server45Upgrade.ps1"; $ast=[System.Management.Automation.Language.Parser]::ParseFile($op,[ref]$null,[ref]$null)
$fn=$ast.FindAll({param($n)$n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-Rollback'},$true)[0]
$fnS=$fn.Extent.StartLineNumber;$fnE=$fn.Extent.EndLineNumber
foreach($h in (Select-String -Path $op -Pattern 'DROP DATABASE')){ if($h.LineNumber -lt $fnS -or $h.LineNumber -gt $fnE){throw "DROP DATABASE outside Invoke-Rollback line $($h.LineNumber)"} }
"HARD RULE i.b: DROP DATABASE only in Invoke-Rollback — OK"
if (-not (Select-String -Path $op -Pattern '\$ReleaseCommit')) { throw "E-010a missing." }; "E-010a manifest param — OK"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$e=[System.IO.Compression.ZipFile]::OpenRead($zip).Entries.FullName
"bin/Shell:$(($e -like 'bin/Shell/*').Count) bin/RTM:$(($e -like 'bin/RTM/*').Count) bin/ApplyService:$(($e -like 'bin/ApplyService/*').Count) migrations:$(($e -like 'migrations/*').Count) functions:$(($e -like 'functions/*').Count)"
@('Apply-Server45Upgrade.ps1','server45_dependency_probe.sql','Compare-ToBaseline.ps1','INSTALL.txt','db/setup/02_catowner_role.sql','migrations/20260609_010_metric_deploy_log.sql') | % { "$(if($_ -in $e){'[OK]'}else{'[MISS]'}) $_" }
"Worktree HEAD = $(git -C 'D:\Claude\_build\rtm-60fc6aa' rev-parse HEAD) (must be 60fc6aa)"
```
Expected: bin/ApplyService>0 ; migration 010 present ; db/setup/02_catowner_role.sql present ; worktree=60fc6aa.

### Step 8 — cleanup worktree (keep zip)
`git worktree remove --force "D:\Claude\_build\rtm-60fc6aa"`

## Report back
ZIP path+size ; 5 manifest counts (incl bin/ApplyService>0) ; **apply-twice B-test exit codes (migration 010 + functions/01, all 0) OR NOT-RUN** ; HARD-RULE i + i.b + E-010a ; worktree HEAD=60fc6aa ; INSTALL.txt DG-1/DG-2 present. NOTHING committed, NO push.
