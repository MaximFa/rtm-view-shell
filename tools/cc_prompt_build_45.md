# CC Task — Build SERVER-45 in-place package (from pushed tip 0ef423b, PG17)

> Server 45 = existing PROD, PostgreSQL 17, in-place upgrade (same shape as 234 iter-1, with ALL the backport fixes now in repo).
> Build the orchestrator package: Apply-Server45Upgrade.ps1 + Shell + RTM + ApplyService publishes + db/ + INSTALL.txt.
> NOT Build-ProdRelease.ps1 (that is the fresh-install builder, no ApplyService/orchestrator). NO push. Native Windows build.

## 0. Integrity (PD-007 active) — SELF-HEAL, do not ask the operator
cd "D:\Claude\Projects\RTM View Shell"
# 0a. Clear a stale index.lock if present (CLAUDE.md §0.4). Only remove if no real git is mid-write:
if (Test-Path ".git\index.lock") { Remove-Item ".git\index.lock" -Force -ErrorAction SilentlyContinue }
# 0b. Restore working-tree files corrupted by mount write-back (newlines stripped), from HEAD:
git checkout HEAD -- deploy/ src/ RTM/ db/ tools/ wireframes/
# 0c. If a file still shows as 1-line (lock held), fall back to index-free restore per file:
foreach ($f in @("deploy/Apply-Server45Upgrade.ps1","src/CcDashboard.ApplyService/Program.cs","src/CcDashboard.ApplyService/CcDashboard.ApplyService.csproj")) {
  if (((Get-Content $f -ErrorAction SilentlyContinue) | Measure-Object -Line).Lines -lt 5) { git show ("HEAD:"+$f) | Set-Content ($f -replace '/','\') -Encoding UTF8 }
}
# Build from a CLEAN worktree at the pushed tip:
$tip = git rev-parse HEAD
if ($tip -notlike "0ef423b*") { throw "HEAD $tip != 0ef423b — fetch/checkout the pushed tip first." }
"Tip = $tip"

## 1. Publish THREE binaries (self-contained win-x64, fixed dirs §27)
$R = "D:\Claude\Projects\RTM View Shell"
dotnet publish "$R\src\CcDashboard.Web"          -c Release -r win-x64 --self-contained -o "$R\publish\shell"
dotnet publish "$R\RTM\RTM"                       -c Release -r win-x64 --self-contained -o "$R\publish\rtm"
dotnet publish "$R\src\CcDashboard.ApplyService"  -c Release -r win-x64 --self-contained -o "$R\publish\applysvc"
foreach ($p in @("shell\CcDashboard.Web.dll","applysvc\CcDashboard.ApplyService.dll")) { if (-not (Test-Path "$R\publish\$p")) { throw "publish missing: $p" } }
if (-not (Test-Path "$R\publish\rtm\*.exe")) { throw "RTM publish failed." }
# verify ApplyService UseWindowsService is compiled in (7ba6250): the published Program must have it — sanity-grep the source
if (-not (Select-String -Path "$R\src\CcDashboard.ApplyService\Program.cs" -Pattern "UseWindowsService" -Quiet)) { throw "ApplyService source missing UseWindowsService — restore from HEAD." }

## 2. Assemble package (orchestrator layout)
$pkg = "D:\Claude\_build\pkg45"
Remove-Item -Recurse -Force $pkg -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $pkg | Out-Null
Copy-Item "$R\deploy\Apply-Server45Upgrade.ps1"      $pkg\
Copy-Item "$R\staging\server45_dependency_probe.sql" $pkg\ -ErrorAction SilentlyContinue
Copy-Item "$R\db\tools\Compare-ToBaseline.ps1"       $pkg\
New-Item -ItemType Directory -Force "$pkg\functions"  | Out-Null; Copy-Item "$R\db\functions\*.sql"  "$pkg\functions\"
New-Item -ItemType Directory -Force "$pkg\migrations" | Out-Null; Copy-Item "$R\db\migrations\*.sql" "$pkg\migrations\"
New-Item -ItemType Directory -Force "$pkg\db\setup"   | Out-Null; Copy-Item "$R\db\setup\*.sql"      "$pkg\db\setup\"
New-Item -ItemType Directory -Force "$pkg\db" | Out-Null
Copy-Item "$R\db\schema.sql" "$pkg\db\" -ErrorAction SilentlyContinue
Copy-Item -Recurse "$R\db\functions" "$pkg\db\"; Copy-Item -Recurse "$R\db\data" "$pkg\db\"; Copy-Item -Recurse "$R\db\migrations" "$pkg\db\"
New-Item -ItemType Directory -Force "$pkg\bin\Shell"        | Out-Null; Copy-Item -Recurse "$R\publish\shell\*"    "$pkg\bin\Shell\"
New-Item -ItemType Directory -Force "$pkg\bin\RTM"          | Out-Null; Copy-Item -Recurse "$R\publish\rtm\*"      "$pkg\bin\RTM\"
New-Item -ItemType Directory -Force "$pkg\bin\ApplyService" | Out-Null; Copy-Item -Recurse "$R\publish\applysvc\*" "$pkg\bin\ApplyService\"
# C-fix: catalog ships INSIDE bin\Shell\docs (so MetricsPage resolves it, no fallback)
if (Test-Path "$R\docs\metrics-catalog.json") { New-Item -ItemType Directory -Force "$pkg\bin\Shell\docs" | Out-Null; Copy-Item "$R\docs\metrics-catalog.json" "$pkg\bin\Shell\docs\" }
else { Write-Host "[WARN] docs/metrics-catalog.json not found — Shell deploy-tab will fall back" }

## 3. INSTALL.txt (UTF-8 BOM, §35) — 45 / PG17 deploy steps
Write the deploy steps:
  SERVER 45 — in-place upgrade (PG17). PowerShell ADMIN, from this folder. NO DB restore / Install-RTMView / DROP DATABASE.
  STEP A — Compare-ToBaseline.ps1 -BaselineDir .\db -Database rtmviewdb -User ccdashboard_user -Password "<APP_PW>" -OutDir "C:\RTMView-Ops\output"
           Review the delta (especially [B] routine-kind direction; DON'T auto-apply align.sql). Determine -MigrationList from [D] unapplied.
  STEP B — .\Apply-Server45Upgrade.ps1 -PgVersion 17 -AutoRollback -ReleaseCommit "0ef423b" `
             -AppPassword "<APP_PW>" -SuperPassword "<PG_PW>" -InstallRoot "C:\RTMView" `
             -MigrationList "<from Compare [D] unapplied, comma-separated>" `
             -ShellPublish ".\bin\Shell" -RtmPublish ".\bin\RTM" -ApplyServicePublish ".\bin\ApplyService"
  STEP C — post-deploy (capture to C:\RTMView-Ops\output\):
     DG-1 Get-NetTCPConnection -State Listen -LocalPort 8088 -> LocalAddress 127.0.0.1 ONLY
     DG-2 Get-Service RTMApplyService=Running ; POST http://127.0.0.1:5099/apply-metrics (no token, json body) -> 401
     DG-3 deploy log shows "Verified RTM:TenantId = <uuid>" (A6 — NOT 00000000)
     DG-4 icacls C:\RTMView\Packages... shows NT SERVICE\RTMApplyService grant
     + Phase-7 e2e smoke checklist (45 = PROD).

## 4. Zip + self-tests (reuse the 234 pattern)
$ts = Get-Date -Format "yyyyMMdd-HHmm"; $zip = "D:\Claude\Projects\RTM View Shell\Installations\45_0ef423b_$ts.zip"
Compress-Archive -Path "$pkg\*" -DestinationPath $zip -Force
# assert: bin\ApplyService>0 ; Apply-Server45Upgrade.ps1 present and PARSES (no 1-line corruption):
$op="$pkg\Apply-Server45Upgrade.ps1"; $null=[System.Management.Automation.Language.Parser]::ParseFile($op,[ref]$null,[ref]$e=$null)
if ($e) { throw "Apply-Server45Upgrade.ps1 has parse errors (corruption?) — restore from HEAD and re-zip." }
"ZIP: $zip  $([math]::Round((Get-Item $zip).Length/1MB,1)) MB ; Shell/RTM/ApplyService bin counts + Apply-Server45Upgrade parse-OK"

## Report
ZIP path+size ; 3 bin counts (ApplyService>0) ; metrics-catalog shipped Y/N ; Apply-Server45Upgrade parse-OK ; tip=0ef423b. NO push.
Operator then: transfer to 45 -> Compare -> STEP B (-PgVersion 17, -MigrationList from delta) -> DG-1..4 + Phase-7 smoke.
