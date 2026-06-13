# CC Task — REPACKAGE server-45 from HEAD d18c79d (functions 3db705d + migration _011 table-drift fix + B2-quoted orchestrator)

> Coordinator GO 2026-06-13T13:01Z. Root of the 02:335 failure was TABLE drift (45's RTSData_Interaction missing CustomCallData1..20),
> NOT a function bug — functions 3db705d are CORRECT (do NOT strip). dba added migration 20260613_011 (idempotent ADD COLUMN, 23 cols,
> completeness cross-check clean). HEAD now = d18c79d. SUPERSEDES cc_prompt_iter1c_b2_repack45.md / cc_prompt_repackage45_3db705d.md.
> Build-only, NO push, native Windows (CC).
>
> 🔴 PD-007: WORKING TREE is truncated (_011 WT 43L vs HEAD 54L; functions 01/02 also). SOURCE EVERYTHING FROM HEAD (committed tree).
> ⚠ The Cowork bash that drafted this is STALE for git (reads HEAD=7a9a70d/May). Determine HEAD/line-counts with NATIVE git. Content gates = truth.

## 0. Integrity (PD-007) — SELF-HEAL from HEAD (native git)
cd "D:\Claude\Projects\RTM View Shell"
if (Test-Path ".git\index.lock") { Remove-Item ".git\index.lock" -Force -ErrorAction SilentlyContinue }
git checkout HEAD -- deploy/ src/ RTM/ db/ tools/ wireframes/
foreach ($f in @("db/functions/01_ngc_functions.sql","db/functions/02_rtsdata_functions.sql","deploy/Apply-Server45Upgrade.ps1","src/CcDashboard.ApplyService/Program.cs")) {
  $w=$f -replace '/','\'; if (((Get-Content $w -ErrorAction SilentlyContinue)|Measure-Object -Line).Lines -lt 50){ git show ("HEAD:"+$f)|Set-Content $w -Encoding UTF8 }
}
# _011 migration — restore from HEAD too (WT truncated 43L vs HEAD 54L). Resolve its exact filename from HEAD:
$mig011 = (git show HEAD --name-only --pretty=format: 2>$null | Select-String '20260613_011') ; if (-not $mig011) { $mig011 = (git ls-tree -r --name-only HEAD db/migrations | Select-String '20260613_011') }
$mig011 = "$mig011".Trim()
if (-not $mig011) { throw "20260613_011 not found in HEAD db/migrations — wrong tip? STOP." }
$mig011w = $mig011 -replace '/','\'
git show ("HEAD:"+$mig011) | Set-Content $mig011w -Encoding UTF8
$tip = git rev-parse HEAD; "HEAD = $tip ; _011 = $mig011"
# HARD gates (HEAD content):
$l01=(Get-Content "db\functions\01_ngc_functions.sql"|Measure-Object -Line).Lines
$l02=(Get-Content "db\functions\02_rtsdata_functions.sql"|Measure-Object -Line).Lines
$l11=(Get-Content $mig011w|Measure-Object -Line).Lines
if ($l01 -ne 835){throw "01=$l01 (exp 835)."}; if ($l02 -ne 496){throw "02=$l02 (exp 496)."}; if ($l11 -lt 54){throw "_011=$l11 (exp >=54, truncated)."}
$addcols=([regex]::Matches((Get-Content $mig011w -Raw),'ADD COLUMN')).Count
if ($addcols -lt 23){throw "_011 has $addcols ADD COLUMN (exp >=23, incomplete)."}
"HEAD OK: 01=$l01 02=$l02 _011=$l11 (ADD COLUMN x$addcols)"

## 1. ENSURE Phase-5c B2 quoted (idempotent — already quoted in HEAD, expect no-op)
$op="deploy\Apply-Server45Upgrade.ps1"; $t=Get-Content $op -Raw
if (($t -match 'SET\s+SignalRConnectionUrl\s*=' -or $t -match 'WHERE\s+TenantId\s*=') -and -not ($t -match 'SET\s+`?"SignalRConnectionUrl`?"\s*=' -and $t -match 'WHERE\s+`?"TenantId`?"\s*=')) {
  $t=$t -replace 'SET\s+SignalRConnectionUrl\s*=','SET `"SignalRConnectionUrl`" =' -replace 'WHERE\s+TenantId\s*=','WHERE `"TenantId`" ='
  [System.IO.File]::WriteAllText((Resolve-Path $op),$t,(New-Object System.Text.UTF8Encoding($true))); $b2fixed=$true
} else { $b2fixed=$false }
if (-not ((Get-Content $op -Raw) -match 'SET\s+`?"SignalRConnectionUrl`?"\s*=' -and (Get-Content $op -Raw) -match 'WHERE\s+`?"TenantId`?"\s*=')) { throw "B2 not quoted — STOP." }
if ($b2fixed) { git add $op; git commit -m "deploy: iter-1c Phase 5c B2 quote tenant_settings identifiers"; } else { "B2 already quoted — no commit." }
$tip = git rev-parse HEAD; "Repackage tip = $tip"

## 2. Publish 3 binaries + assemble (build_45 §2 layout, ship db/tools)
$R="D:\Claude\Projects\RTM View Shell"
dotnet publish "$R\src\CcDashboard.Web"          -c Release -r win-x64 --self-contained -o "$R\publish\shell"
dotnet publish "$R\RTM\RTM"                       -c Release -r win-x64 --self-contained -o "$R\publish\rtm"
dotnet publish "$R\src\CcDashboard.ApplyService" -c Release -r win-x64 --self-contained -o "$R\publish\applysvc"
foreach ($p in @("shell\CcDashboard.Web.dll","applysvc\CcDashboard.ApplyService.dll")){ if(-not(Test-Path "$R\publish\$p")){throw "publish missing $p"} }
if(-not(Test-Path "$R\publish\rtm\*.exe")){throw "RTM publish failed"}
$pkg="D:\Claude\_build\pkg45_d18c79d"; Remove-Item -Recurse -Force $pkg -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force $pkg|Out-Null
Copy-Item "$R\deploy\Apply-Server45Upgrade.ps1" $pkg\
Copy-Item "$R\staging\server45_dependency_probe.sql" $pkg\ -ErrorAction SilentlyContinue
Copy-Item "$R\db\tools\Compare-ToBaseline.ps1" $pkg\
New-Item -ItemType Directory -Force "$pkg\functions" |Out-Null; Copy-Item "$R\db\functions\*.sql"  "$pkg\functions\"
New-Item -ItemType Directory -Force "$pkg\migrations"|Out-Null; Copy-Item "$R\db\migrations\*.sql" "$pkg\migrations\"
$repoMig=(Get-ChildItem "$R\db\migrations" -Filter *.sql).Count; $pkgMig=(Get-ChildItem "$pkg\migrations" -Filter *.sql).Count
if($pkgMig -ne $repoMig){throw "migration count mismatch pkg $pkgMig vs repo $repoMig"}
New-Item -ItemType Directory -Force "$pkg\db\setup"|Out-Null; Copy-Item "$R\db\setup\*.sql" "$pkg\db\setup\"
New-Item -ItemType Directory -Force "$pkg\db"|Out-Null; Copy-Item "$R\db\schema.sql" "$pkg\db\" -ErrorAction SilentlyContinue
Copy-Item -Recurse "$R\db\functions" "$pkg\db\"; Copy-Item -Recurse "$R\db\data" "$pkg\db\"; Copy-Item -Recurse "$R\db\migrations" "$pkg\db\"
New-Item -ItemType Directory -Force "$pkg\bin\Shell"|Out-Null; Copy-Item -Recurse "$R\publish\shell\*" "$pkg\bin\Shell\"
New-Item -ItemType Directory -Force "$pkg\bin\RTM"|Out-Null; Copy-Item -Recurse "$R\publish\rtm\*" "$pkg\bin\RTM\"
New-Item -ItemType Directory -Force "$pkg\bin\ApplyService"|Out-Null; Copy-Item -Recurse "$R\publish\applysvc\*" "$pkg\bin\ApplyService\"
if(Test-Path "$R\docs\metrics-catalog.json"){New-Item -ItemType Directory -Force "$pkg\bin\Shell\docs"|Out-Null; Copy-Item "$R\docs\metrics-catalog.json" "$pkg\bin\Shell\docs\"}

## 3. CONTENT VERIFY (gates = truth) — functions + _011 + B2 + BOM, in BOTH function copies
$m11name=Split-Path $mig011 -Leaf
foreach($sub in @("functions","db\functions")){
  $f01="$pkg\$sub\01_ngc_functions.sql"; $f02="$pkg\$sub\02_rtsdata_functions.sql"
  if(-not(Test-Path $f01)-or-not(Test-Path $f02)){throw "pkg missing $sub 01/02"}
  $c1=(Get-Content $f01|Measure-Object -Line).Lines; $c2=(Get-Content $f02|Measure-Object -Line).Lines
  if($c1 -ne 835){throw "$sub\01=$c1 (exp 835)"}; if($c2 -ne 496){throw "$sub\02=$c2 (exp 496)"}
  $x1=Get-Content $f01 -Raw
  if($x1 -match 'NGC_Queues"[\s\S]{0,200}CreatedDatetime' -or $x1 -match 'NGC_AgentGroups"[\s\S]{0,200}CreatedDatetime'){throw "$sub\01 CreatedDatetime (42703)"}
  $g=([regex]::Matches($x1,'FROM pg_proc WHERE proname')).Count; if($g -lt 14){throw "$sub\01 DROP guards=$g (<14)"}
}
foreach($sub in @("migrations","db\migrations")){
  $m="$pkg\$sub\$m11name"; if(-not(Test-Path $m)){throw "pkg missing $sub\$m11name"}
  $ml=(Get-Content $m|Measure-Object -Line).Lines; $ma=([regex]::Matches((Get-Content $m -Raw),'ADD COLUMN')).Count
  if($ml -lt 54){throw "$sub\$m11name=$ml lines (truncated)"}; if($ma -lt 23){throw "$sub\$m11name ADD COLUMN x$ma (<23)"}
  "[VERIFY $sub] $m11name = $ml lines, ADD COLUMN x$ma"
}
$op2="$pkg\Apply-Server45Upgrade.ps1"; $b=[System.IO.File]::ReadAllBytes($op2)[0..2]
if(-not($b[0]-eq0xEF -and $b[1]-eq0xBB -and $b[2]-eq0xBF)){throw "orchestrator no BOM"}
$ot=Get-Content $op2 -Raw; if(-not($ot -match 'SET\s+`?"SignalRConnectionUrl`?"\s*=' -and $ot -match 'WHERE\s+`?"TenantId`?"\s*=')){throw "pkg orchestrator B2 not quoted"}
$null=[System.Management.Automation.Language.Parser]::ParseFile($op2,[ref]$null,[ref]$e=$null); if($e){throw "orchestrator parse err"}
"[VERIFY] functions 835/496 ; _011 23 ADD COLUMN ; B2 quoted ; BOM+parse OK ; migrations=$pkgMig==repo"

## 4. Zip
$ts=Get-Date -Format "yyyyMMdd-HHmm"; $short=$tip.Substring(0,7); $zip="$R\Installations\45_${short}_$ts.zip"
Compress-Archive -Path "$pkg\*" -DestinationPath $zip -Force
"ZIP: $zip  $([math]::Round((Get-Item $zip).Length/1MB,1)) MB"

## 5. cc-binding (NORM-CUR-07) — append RESULT to .coord/cc/devops.md (Python+os.fsync, append; create if absent)
  ## <UTC> | binding: devops <-> CC | directive: tools/cc_prompt_repack45_d18c79d_011.md | status: done
  ### RESULT (by CC): pkg Installations/45_<short>_<ts>.zip ; tip <rev-parse> ; B2 changed=<t/f> ; functions 01=835/02=496 ; _011=<m11name> <lines>L ADD COLUMN x<n> ; B2 quoted ; BOM+parse OK ; migrations=<n>==repo ; bin counts. NO push.

## Report (chat)
HEAD tip ; ZIP path+size ; verify line (835/496, _011 23 ADD COLUMN, B2 quoted, BOM, migrations==repo) ; bin counts ; B2 changed Y/N. NO push.
Operator re-applies on 45 ONCE: transfer -> STEP-0 (Set-ExecutionPolicy -Scope Process Bypass -Force ; Get-ChildItem -Recurse -Filter *.ps1 | Unblock-File) ->
.\Apply-Server45Upgrade.ps1 -PgVersion 15 -AutoRollback -ReleaseCommit "<tip>" -AppPassword .. -SuperPassword .. -InstallRoot C:\RTMView -MigrationList "20260604_001_add_agent_state_pct_metrics.sql,20260605_004_metrics_dedup.sql,20260606_005_history_unavailable_metrics.sql,20260606_008_daytrend_fn_bu_scope.sql,<_011 filename>.sql" -ShellPublish .\bin\Shell -RtmPublish .\bin\RTM -ApplyServicePublish .\bin\ApplyService
(Phase-4 applies _011 ADD COLUMN BEFORE Phase-5 functions re-apply -> 02:335 resolves.) Then: RTM log clean (no 42883/42703/42809), NGC discovery creates BU/Queue/AgentGroup, DG-1/DG-2, B2 relay-URL written, re-run 45 cross-check = ZERO rows (final proof), Phase-7.
