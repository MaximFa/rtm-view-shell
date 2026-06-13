# CC Task — iter-1c: ensure Phase-5c B2 quoted identifiers + REPACKAGE server-45 from HEAD (ONE pass)

> Coordinator 10:51Z: fold the B2 quoting fix + the dba functions regen (3db705d) into ONE package, operator re-applies ONCE.
> dba regen already committed (db/functions/01=835L, 02=496L at HEAD). This task: (1) ENSURE Phase-5c B2 uses quoted
> identifiers (idempotent — fix+commit only if needed), (2) repackage 45 from the CURRENT HEAD with full content-verify.
> deploy: commit only if B2 changed. NO push. Native Windows build (CC).
>
> ⚠ The Cowork bash-mount that drafted this is BLIND/STALE for git+fs — do NOT trust any commit hash quoted here from chat.
> Determine HEAD and all line counts with NATIVE git/PowerShell on Windows. The CONTENT verify gates are the source of truth.

## 0. Integrity (PD-007) — SELF-HEAL from HEAD (native git), do not ask operator
cd "D:\Claude\Projects\RTM View Shell"
if (Test-Path ".git\index.lock") { Remove-Item ".git\index.lock" -Force -ErrorAction SilentlyContinue }
git checkout HEAD -- deploy/ src/ RTM/ db/ tools/ wireframes/
foreach ($f in @("db/functions/01_ngc_functions.sql","db/functions/02_rtsdata_functions.sql","deploy/Apply-Server45Upgrade.ps1","src/CcDashboard.ApplyService/Program.cs")) {
  $w = $f -replace '/','\'
  if (((Get-Content $w -ErrorAction SilentlyContinue) | Measure-Object -Line).Lines -lt 50) { git show ("HEAD:"+$f) | Set-Content $w -Encoding UTF8 }
}
$tip = git rev-parse HEAD; "HEAD = $tip"
# HARD gate: dba regen must be present at HEAD (release-blocker fix)
$l01 = (Get-Content "db\functions\01_ngc_functions.sql" | Measure-Object -Line).Lines
$l02 = (Get-Content "db\functions\02_rtsdata_functions.sql" | Measure-Object -Line).Lines
if ($l01 -ne 835) { throw "01_ngc_functions.sql = $l01 (expected 835 — dba regen 3db705d not at HEAD or truncated). STOP." }
if ($l02 -ne 496) { throw "02_rtsdata_functions.sql = $l02 (expected 496). STOP." }
"Functions OK at HEAD: 01=$l01 02=$l02"

## 1. ENSURE Phase-5c B2 quoted identifiers (idempotent) + scan for other unquoted PascalCase in psql
$op = "deploy\Apply-Server45Upgrade.ps1"; $t = Get-Content $op -Raw
# Target B2 UPDATE — must use `"SignalRConnectionUrl"` and `"TenantId"` (PowerShell escaped: `"...`").
# CORRECT form (already in HEAD per working-tree read, but VERIFY): 
#   UPDATE tenant_settings SET `"SignalRConnectionUrl`" = '...' WHERE `"TenantId`" = '...'
$b2ok = ($t -match 'SET\s+`?"SignalRConnectionUrl`?"\s*=' -and $t -match 'WHERE\s+`?"TenantId`?"\s*=')
$b2bad = ($t -match 'SET\s+SignalRConnectionUrl\s*=' -or $t -match 'WHERE\s+TenantId\s*=')   # unquoted occurrence
if ($b2bad -and -not $b2ok) {
    # Fix the unquoted B2 UPDATE -> quoted. (Use a precise replace on the $updateSql assignment line.)
    $t = $t -replace 'SET\s+SignalRConnectionUrl\s*=', 'SET `"SignalRConnectionUrl`" ='
    $t = $t -replace 'WHERE\s+TenantId\s*=', 'WHERE `"TenantId`" ='
    [System.IO.File]::WriteAllText((Resolve-Path $op), $t, (New-Object System.Text.UTF8Encoding($true)))  # UTF-8 BOM (§35)
    $b2fixed = $true
} else { $b2fixed = $false }
# Scan whole orchestrator for OTHER unquoted PascalCase identifiers inside psql -c / here-strings (coordinator ask).
# Report any `SET <Pascal> =` / `WHERE <Pascal> =` / `INTO "Tbl" (<Pascal>` lacking surrounding `" "`. Manual-review list:
$susp = Select-String -Path $op -Pattern '(SET|WHERE)\s+[A-Z][A-Za-z]+\s*=' | Where-Object { $_.Line -notmatch '`"' }
if ($susp) { "⚠ OTHER unquoted PascalCase candidates (review):"; $susp | ForEach-Object { "  L$($_.LineNumber): $($_.Line.Trim())" } }
else { "No other unquoted PascalCase identifiers found in psql statements." }
# Re-verify B2 now quoted (post-fix or already-ok):
$t2 = Get-Content $op -Raw
if (-not ($t2 -match 'SET\s+`?"SignalRConnectionUrl`?"\s*=' -and $t2 -match 'WHERE\s+`?"TenantId`?"\s*=')) { throw "B2 still not quoted after step 1 — STOP." }
"B2 quoted: OK (changed this run = $b2fixed)"

## 2. Commit (deploy:) ONLY if B2 changed — NO push
if ($b2fixed) {
    bash tools/pre-commit-check.sh deploy/Apply-Server45Upgrade.ps1   # if not on PATH, run the §0.5 checks inline
    git add deploy/Apply-Server45Upgrade.ps1
    git commit -m "deploy: iter-1c Phase 5c B2 quote tenant_settings identifiers (\"TenantId\"/\"SignalRConnectionUrl\") + scan psql for unquoted PascalCase"
    git show HEAD --stat | Select-Object -First 5
} else { "B2 already quoted in HEAD — no commit needed." }
$tip = git rev-parse HEAD; "Repackage tip = $tip"

## 3. Publish THREE binaries (self-contained win-x64, §27)
$R = "D:\Claude\Projects\RTM View Shell"
dotnet publish "$R\src\CcDashboard.Web"          -c Release -r win-x64 --self-contained -o "$R\publish\shell"
dotnet publish "$R\RTM\RTM"                       -c Release -r win-x64 --self-contained -o "$R\publish\rtm"
dotnet publish "$R\src\CcDashboard.ApplyService" -c Release -r win-x64 --self-contained -o "$R\publish\applysvc"
foreach ($p in @("shell\CcDashboard.Web.dll","applysvc\CcDashboard.ApplyService.dll")) { if (-not (Test-Path "$R\publish\$p")) { throw "publish missing: $p" } }
if (-not (Test-Path "$R\publish\rtm\*.exe")) { throw "RTM publish failed." }

## 4. Assemble package (build_45 §2 layout) + ship db/tools (closes f7fab95 Compare gap)
$pkg = "D:\Claude\_build\pkg45_iter1c"
Remove-Item -Recurse -Force $pkg -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $pkg | Out-Null
Copy-Item "$R\deploy\Apply-Server45Upgrade.ps1"      $pkg\
Copy-Item "$R\staging\server45_dependency_probe.sql" $pkg\ -ErrorAction SilentlyContinue
Copy-Item "$R\db\tools\Compare-ToBaseline.ps1"       $pkg\
New-Item -ItemType Directory -Force "$pkg\functions"  | Out-Null; Copy-Item "$R\db\functions\*.sql"  "$pkg\functions\"
New-Item -ItemType Directory -Force "$pkg\migrations" | Out-Null; Copy-Item "$R\db\migrations\*.sql" "$pkg\migrations\"
$repoMig=(Get-ChildItem "$R\db\migrations" -Filter *.sql).Count; $pkgMig=(Get-ChildItem "$pkg\migrations" -Filter *.sql).Count
if ($pkgMig -ne $repoMig) { throw "Migration count mismatch: pkg $pkgMig vs repo $repoMig." }
New-Item -ItemType Directory -Force "$pkg\db\setup" | Out-Null; Copy-Item "$R\db\setup\*.sql" "$pkg\db\setup\"
New-Item -ItemType Directory -Force "$pkg\db" | Out-Null
Copy-Item "$R\db\schema.sql" "$pkg\db\" -ErrorAction SilentlyContinue
Copy-Item -Recurse "$R\db\functions" "$pkg\db\"; Copy-Item -Recurse "$R\db\data" "$pkg\db\"; Copy-Item -Recurse "$R\db\migrations" "$pkg\db\"
New-Item -ItemType Directory -Force "$pkg\bin\Shell"        | Out-Null; Copy-Item -Recurse "$R\publish\shell\*"    "$pkg\bin\Shell\"
New-Item -ItemType Directory -Force "$pkg\bin\RTM"          | Out-Null; Copy-Item -Recurse "$R\publish\rtm\*"      "$pkg\bin\RTM\"
New-Item -ItemType Directory -Force "$pkg\bin\ApplyService" | Out-Null; Copy-Item -Recurse "$R\publish\applysvc\*" "$pkg\bin\ApplyService\"
if (Test-Path "$R\docs\metrics-catalog.json") { New-Item -ItemType Directory -Force "$pkg\bin\Shell\docs" | Out-Null; Copy-Item "$R\docs\metrics-catalog.json" "$pkg\bin\Shell\docs\" }

## 5. CONTENT VERIFY (gates = source of truth) — BOTH function copies + B2 + BOM
foreach ($sub in @("functions","db\functions")) {
  $f01="$pkg\$sub\01_ngc_functions.sql"; $f02="$pkg\$sub\02_rtsdata_functions.sql"
  if (-not (Test-Path $f01) -or -not (Test-Path $f02)) { throw "package missing $sub 01/02." }
  $c01=(Get-Content $f01|Measure-Object -Line).Lines; $c02=(Get-Content $f02|Measure-Object -Line).Lines
  if ($c01 -ne 835) { throw "$sub\01=$c01 (expected 835)." }; if ($c02 -ne 496) { throw "$sub\02=$c02 (expected 496)." }
  $x01=Get-Content $f01 -Raw
  if ($x01 -match 'NGC_Queues"[\s\S]{0,200}CreatedDatetime' -or $x01 -match 'NGC_AgentGroups"[\s\S]{0,200}CreatedDatetime') { throw "$sub\01 still inserts CreatedDatetime (42703)." }
  $g=([regex]::Matches($x01,'FROM pg_proc WHERE proname')).Count; if ($g -lt 14) { throw "$sub\01 DROP guards=$g (<14)." }
  if ($x01 -notmatch 'NGC_CreateBusinessUnit"\(\s*p_business_unit_name text,\s*p_description text,\s*p_site_id text,\s*p_created_by text,\s*p_tenant_id uuid') { throw "$sub\01 missing 5-param NGC_CreateBusinessUnit." }
  $x02=Get-Content $f02 -Raw
  if ($x02 -notmatch 'RTSData_getInteractions"\([^)]*text[^)]*uuid') { throw "$sub\02 missing RTSData_getInteractions(text,uuid)." }
  if ($x02 -notmatch 'RTSData_getUsersStatuses"\([^)]*text[^)]*uuid') { throw "$sub\02 missing RTSData_getUsersStatuses(text,uuid)." }
  "[VERIFY $sub] 01=$c01 02=$c02 ; no CreatedDatetime ; DROP-guards=$g ; CreateBU-5p OK ; RTSData arity-2 OK"
}
$op2="$pkg\Apply-Server45Upgrade.ps1"
$b=[System.IO.File]::ReadAllBytes($op2)[0..2]; if (-not ($b[0]-eq0xEF -and $b[1]-eq0xBB -and $b[2]-eq0xBF)) { throw "orchestrator missing UTF-8 BOM." }
$ot=Get-Content $op2 -Raw
if (-not ($ot -match 'SET\s+`?"SignalRConnectionUrl`?"\s*=' -and $ot -match 'WHERE\s+`?"TenantId`?"\s*=')) { throw "packaged orchestrator B2 NOT quoted." }
$null=[System.Management.Automation.Language.Parser]::ParseFile($op2,[ref]$null,[ref]$e=$null); if ($e) { throw "orchestrator parse errors." }
"[VERIFY] orchestrator BOM+parse OK ; B2 quoted OK"

## 6. Zip
$ts=Get-Date -Format "yyyyMMdd-HHmm"; $short=$tip.Substring(0,7); $zip="$R\Installations\45_${short}_$ts.zip"
Compress-Archive -Path "$pkg\*" -DestinationPath $zip -Force
"ZIP: $zip  $([math]::Round((Get-Item $zip).Length/1MB,1)) MB"

## 7. cc-binding (NORM-CUR-07) -> append RESULT to .coord/cc/devops.md (Python+os.fsync, append; create if absent)
Block:
  ## <UTC> | binding: devops <-> CC | directive: tools/cc_prompt_iter1c_b2_repack45.md | status: open
  ### DIRECTIVE (spec->CC): ensure Phase-5c B2 quoted + repackage 45 from HEAD (dba regen 3db705d + B2 fix), one pass, no push.
  ### RESULT (by CC): status: done
  - HEAD tip = <rev-parse>; B2 changed this run = <true/false> (commit <hash or none>).
  - Package: Installations/45_<short>_<ts>.zip (<size> MB).
  - Verify: functions 01=835/02=496 (pkg\functions + pkg\db\functions); no CreatedDatetime; DROP-guards=<n>; CreateBU 5-param; RTSData arity-2; orchestrator B2 quoted; BOM+parse OK; migrations=<n>==repo; bin Shell/RTM/ApplyService counts.
  - NO push.

## Report (chat)
HEAD tip ; B2 changed Y/N (+commit) ; ZIP path+size ; verify line (functions 835/496, no CreatedDatetime, DROP-guards, CreateBU-5p, RTSData arity-2, B2 quoted, BOM) ; bin counts. NO push.
Operator then re-applies on 45 ONCE: transfer -> STEP-0 (Set-ExecutionPolicy -Scope Process Bypass -Force ; Get-ChildItem -Recurse -Filter *.ps1 | Unblock-File) -> .\Apply-Server45Upgrade.ps1 -PgVersion 15 -AutoRollback -ReleaseCommit "<tip>" -AppPassword .. -SuperPassword .. -InstallRoot C:\RTMView -MigrationList "20260604_001_add_agent_state_pct_metrics.sql,20260605_004_metrics_dedup.sql,20260606_005_history_unavailable_metrics.sql,20260606_008_daytrend_fn_bu_scope.sql" -ShellPublish .\bin\Shell -RtmPublish .\bin\RTM -ApplyServicePublish .\bin\ApplyService
Then: RTM log clean (no 42883/42703/42809) + NGC discovery creates BU/Queue/AgentGroup + DG-1/DG-2 + B2 confirm (tenant_settings."SignalRConnectionUrl" written, no [WARN] B2) + Phase-7.
