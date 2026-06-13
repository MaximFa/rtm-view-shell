# CC Task — REPACKAGE server-45 from HEAD 3db705d (dba functions regen) + content-verify + cc-binding

> Coordinator GO 2026-06-13T10:37Z. dba regen 3db705d landed (db/functions/01+02 reconciled: 42883 arity + 42809
> kind-agnostic DROP + 42703 CreatedDatetime). HEAD 01=835L / 02=496L. 🔴 WORKING TREE of both files is TRUNCATED
> (01=667 / 02=470, PD-007 cache write-back) — so SOURCE FUNCTIONS FROM HEAD, never the working copy.
> Build-only repackage, NO code change, NO push. Native Windows build (CC).

## 0. Integrity (PD-007 active) — SELF-HEAL from HEAD, do not ask the operator
cd "D:\Claude\Projects\RTM View Shell"
if (Test-Path ".git\index.lock") { Remove-Item ".git\index.lock" -Force -ErrorAction SilentlyContinue }
git checkout HEAD -- deploy/ src/ RTM/ db/ tools/ wireframes/
# Per-file fallback if any stayed truncated (lock held): restore from HEAD object store
foreach ($f in @("db/functions/01_ngc_functions.sql","db/functions/02_rtsdata_functions.sql","deploy/Apply-Server45Upgrade.ps1","src/CcDashboard.ApplyService/Program.cs")) {
  $w = $f -replace '/','\'
  $lines = (Get-Content $w -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
  if ($lines -lt 50) { git show ("HEAD:"+$f) | Set-Content $w -Encoding UTF8 }
}
$tip = git rev-parse HEAD
if ($tip -notmatch "^3db705d") { Write-Host "[WARN] HEAD=$tip (expected 3db705d...). Confirm dba regen is the tip before continuing." }
# HARD gate: working-tree functions MUST equal HEAD line counts after restore
$l01 = (Get-Content "db\functions\01_ngc_functions.sql" | Measure-Object -Line).Lines
$l02 = (Get-Content "db\functions\02_rtsdata_functions.sql" | Measure-Object -Line).Lines
if ($l01 -ne 835) { throw "01_ngc_functions.sql = $l01 lines (expected 835 from HEAD) — restore failed, do NOT package truncated SQL." }
if ($l02 -ne 496) { throw "02_rtsdata_functions.sql = $l02 lines (expected 496 from HEAD) — restore failed." }
"Functions restored from HEAD: 01=$l01, 02=$l02"

## 1. Publish THREE binaries (self-contained win-x64, fixed dirs §27)
# 3db705d changed only db/functions (no C#) — binaries identical to f7fab95, but re-publish cleanly from HEAD.
$R = "D:\Claude\Projects\RTM View Shell"
dotnet publish "$R\src\CcDashboard.Web"           -c Release -r win-x64 --self-contained -o "$R\publish\shell"
dotnet publish "$R\RTM\RTM"                        -c Release -r win-x64 --self-contained -o "$R\publish\rtm"
dotnet publish "$R\src\CcDashboard.ApplyService"   -c Release -r win-x64 --self-contained -o "$R\publish\applysvc"
foreach ($p in @("shell\CcDashboard.Web.dll","applysvc\CcDashboard.ApplyService.dll")) { if (-not (Test-Path "$R\publish\$p")) { throw "publish missing: $p" } }
if (-not (Test-Path "$R\publish\rtm\*.exe")) { throw "RTM publish failed." }

## 2. Assemble package (orchestrator layout — same as build_45 §2)
$pkg = "D:\Claude\_build\pkg45_3db705d"
Remove-Item -Recurse -Force $pkg -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $pkg | Out-Null
Copy-Item "$R\deploy\Apply-Server45Upgrade.ps1"      $pkg\
Copy-Item "$R\staging\server45_dependency_probe.sql" $pkg\ -ErrorAction SilentlyContinue
Copy-Item "$R\db\tools\Compare-ToBaseline.ps1"       $pkg\        # FIX: db/tools shipped (was missing in f7fab95 pkg)
New-Item -ItemType Directory -Force "$pkg\functions"  | Out-Null; Copy-Item "$R\db\functions\*.sql"  "$pkg\functions\"
New-Item -ItemType Directory -Force "$pkg\migrations" | Out-Null; Copy-Item "$R\db\migrations\*.sql" "$pkg\migrations\"
$repoMig = (Get-ChildItem "$R\db\migrations" -Filter *.sql).Count
$pkgMig  = (Get-ChildItem "$pkg\migrations" -Filter *.sql).Count
if ($pkgMig -ne $repoMig) { throw "Migration count mismatch: package $pkgMig vs repo $repoMig." }
New-Item -ItemType Directory -Force "$pkg\db\setup" | Out-Null; Copy-Item "$R\db\setup\*.sql" "$pkg\db\setup\"
New-Item -ItemType Directory -Force "$pkg\db" | Out-Null
Copy-Item "$R\db\schema.sql" "$pkg\db\" -ErrorAction SilentlyContinue
Copy-Item -Recurse "$R\db\functions" "$pkg\db\"; Copy-Item -Recurse "$R\db\data" "$pkg\db\"; Copy-Item -Recurse "$R\db\migrations" "$pkg\db\"
New-Item -ItemType Directory -Force "$pkg\bin\Shell"        | Out-Null; Copy-Item -Recurse "$R\publish\shell\*"    "$pkg\bin\Shell\"
New-Item -ItemType Directory -Force "$pkg\bin\RTM"          | Out-Null; Copy-Item -Recurse "$R\publish\rtm\*"      "$pkg\bin\RTM\"
New-Item -ItemType Directory -Force "$pkg\bin\ApplyService" | Out-Null; Copy-Item -Recurse "$R\publish\applysvc\*" "$pkg\bin\ApplyService\"
if (Test-Path "$R\docs\metrics-catalog.json") { New-Item -ItemType Directory -Force "$pkg\bin\Shell\docs" | Out-Null; Copy-Item "$R\docs\metrics-catalog.json" "$pkg\bin\Shell\docs\" }

## 3. CONTENT VERIFY (coordinator 10:37Z) — the dba regen MUST be in the package, BOTH files
foreach ($sub in @("functions","db\functions")) {
  $f01 = "$pkg\$sub\01_ngc_functions.sql"; $f02 = "$pkg\$sub\02_rtsdata_functions.sql"
  if (-not (Test-Path $f01)) { throw "package missing $sub\01_ngc_functions.sql" }
  if (-not (Test-Path $f02)) { throw "package missing $sub\02_rtsdata_functions.sql" }
  $c01 = (Get-Content $f01 | Measure-Object -Line).Lines; $c02 = (Get-Content $f02 | Measure-Object -Line).Lines
  if ($c01 -ne 835) { throw "$sub\01 = $c01 lines (expected 835) — truncated SQL in package." }
  if ($c02 -ne 496) { throw "$sub\02 = $c02 lines (expected 496) — truncated SQL in package." }
  $t01 = Get-Content $f01 -Raw
  # 42703: GetOrCreate Queue/AgentGroup INSERT must NOT reference CreatedDatetime
  if ($t01 -match 'NGC_Queues"[\s\S]{0,200}CreatedDatetime' -or $t01 -match 'NGC_AgentGroups"[\s\S]{0,200}CreatedDatetime') { throw "$sub\01 still inserts CreatedDatetime into NGC_Queues/AgentGroups (42703 not fixed)." }
  # 42809: kind-agnostic DROP guards present (>=14)
  $guards = ([regex]::Matches($t01, 'FROM pg_proc WHERE proname')).Count
  if ($guards -lt 14) { throw "$sub\01 has $guards kind-agnostic DROP guards (expected >=14, E-016)." }
  # 42883: NGC_CreateBusinessUnit 5-param + SAGmapping arity-4 present
  if ($t01 -notmatch 'NGC_CreateBusinessUnit"\(\s*p_business_unit_name text,\s*p_description text,\s*p_site_id text,\s*p_created_by text,\s*p_tenant_id uuid') { throw "$sub\01 missing 5-param NGC_CreateBusinessUnit (text,text,text,text,uuid)." }
  $t02 = Get-Content $f02 -Raw
  # 42883: RTSData_get* arity-2 (text,uuid) present
  if ($t02 -notmatch 'RTSData_getInteractions"\([^)]*text[^)]*uuid') { throw "$sub\02 missing RTSData_getInteractions(text,uuid)." }
  if ($t02 -notmatch 'RTSData_getUsersStatuses"\([^)]*text[^)]*uuid') { throw "$sub\02 missing RTSData_getUsersStatuses(text,uuid)." }
  Write-Host "[VERIFY $sub] 01=$c01 02=$c02 ; CreatedDatetime removed ; DROP-guards=$guards ; CreateBU-5p OK ; RTSData_get arity-2 OK"
}
# Orchestrator .ps1 BOM (EF BB BF, §35) + parse
$op = "$pkg\Apply-Server45Upgrade.ps1"
$b = [System.IO.File]::ReadAllBytes($op)[0..2]
if (-not ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)) { throw "Apply-Server45Upgrade.ps1 missing UTF-8 BOM." }
$null=[System.Management.Automation.Language.Parser]::ParseFile($op,[ref]$null,[ref]$e=$null); if ($e) { throw "Apply-Server45Upgrade.ps1 parse errors." }

## 4. Zip
$ts = Get-Date -Format "yyyyMMdd-HHmm"; $zip = "$R\Installations\45_3db705d_$ts.zip"
Compress-Archive -Path "$pkg\*" -DestinationPath $zip -Force
"ZIP: $zip  $([math]::Round((Get-Item $zip).Length/1MB,1)) MB"

## 5. cc-binding (NORM-CUR-07) — write RESULT to .coord/cc/devops.md (Python+os.fsync; append-only)
Append a binding block to .coord/cc/devops.md:
  ## <UTC> | binding: devops <-> CC | directive: tools/cc_prompt_repackage45_3db705d.md | status: open
  ### DIRECTIVE (spec->CC): repackage 45 from HEAD 3db705d (dba functions regen), content-verify, no push.
  ### RESULT (by CC): status: done
  - Package: Installations/45_3db705d_<ts>.zip (<size> MB)
  - Verify: functions/01=835 02=496 (both pkg\functions + pkg\db\functions); CreatedDatetime removed; DROP-guards=<n>; CreateBU 5-param OK; RTSData_get arity-2 OK; Apply-Server45Upgrade.ps1 BOM+parse OK; migrations=<n>==repo; bin Shell/RTM/ApplyService counts.
  - HEAD tip = <git rev-parse HEAD>. NO push.
(Write with: python3 -c with open(...,'a') + f.flush()+os.fsync. If .coord/cc/devops.md does not exist, create it.)

## Report (chat)
ZIP path+size ; functions verify line (01=835/02=496, CreatedDatetime removed, DROP-guards count, CreateBU-5p, RTSData arity-2) ; bin counts ; BOM+parse OK ; tip=3db705d. NO push.
Operator then re-applies on 45: transfer pkg -> STEP-0 (Set-ExecutionPolicy Bypass + Unblock-File) -> Apply-Server45Upgrade.ps1 -PgVersion 15 -ReleaseCommit 3db705d -MigrationList "20260604_001_add_agent_state_pct_metrics.sql,20260605_004_metrics_dedup.sql,20260606_005_history_unavailable_metrics.sql,20260606_008_daytrend_fn_bu_scope.sql" ... (functions re-apply step closes 42883/42703/42809) -> RTM log clean -> NGC discovery creates BU/Queue/AgentGroup.
