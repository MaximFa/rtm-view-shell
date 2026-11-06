<#
  PROBE  probe_WS_20261106_fullpkg-cdb8316.ps1  - devops-1106, 2026-11-06. Derived by diff from probe_WS_20261106_fullpkg-aed65b1.ps1
  (READY on the operator's PS 5.1, report .coord/measure/pkg-aed65b1/WS_20261106_164527_fullpkg-aed65b1.txt).
  ONE package, engine + Shell + installer, from v4 cdb8316 (aed65b1 + shell 10caa3c + backend cdb8316), Build-ProdRelease -Mode Full -SkipDB.
  Installed on 234 now (install report .measurements/234_20261104_202729_install-e8e67a1.txt, MANIFEST): e8e67a1, package
  04112026.1455.zip 5651F471... = the floor and the "before" side of every needle. DELTA e8e67a1..cdb8316 (git, tree to tree):
  32 paths = src 22, tests 10; RTM 0, db 0, migrations 0 (EF and SQL), deploy 0; installer blob unchanged (e115b8c).
  Engine code unchanged, Full mode kept: the package stays the same shape as the floor it rolls back to, and the installer
  restarts the engine in any mode (INSTALLER-SHELL-MODE-RESTARTS-ENGINE-01).
  Clones live in D:\RTMView-Ops\clones\ and are removed at the start of the next box (rule); this probe does that first.
  Workstation only. 234 is not touched. No push. Writes: the clone, the copy into Installations, the report in .coord\measure.
#>
$ErrorActionPreference = 'Continue'
$WORK = 'D:\Claude\Projects\RTM View Shell'; $V4WT = 'D:\Claude\Projects\RTM-design'; $BUILDROOT = 'D:\RTMView-Ops\clones'
$BLESSED = 'cdb8316'; $DEPLOYED = 'e8e67a1'
$FLOOR = Join-Path $WORK 'Installations\04112026.1455.zip'; $FLOOR_SHA = '5651F47188BC5772B29BE3C1C815AE0662A9308EEE2BA5FD988EB8F6AD41996F'
$INSTALLER_BLOB = 'e115b8c32030e254390140439b8bce8ca2502171'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$repDir = Join-Path $WORK '.coord\measure\pkg-cdb8316'; New-Item -ItemType Directory -Force -Path $repDir | Out-Null
$rep = Join-Path $repDir ('WS_' + $stamp + '_fullpkg-cdb8316.txt')
$REPORT = New-Object System.Collections.ArrayList
function Say($t) { [void]$REPORT.Add($t); Write-Host $t }
function Flush { [IO.File]::WriteAllLines($rep, $REPORT, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($allOk) { Say ''; Say ('PACKAGE : ' + $(if ($allOk) { 'READY TO HAND OVER' } else { 'NOT READY - see the RED rows above' })); Say '===== END-OF-RUN MARKER: FULLPKG-CDB8316-COMPLETE ====='; Flush; Write-Host ('REPORT: ' + $rep); if ($allOk) { exit 0 } else { exit 1 } }
function Sha($p) { return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash }
function ShaB([byte[]]$b) { return [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($b)).Replace('-','') }
function NeedleB([byte[]]$b, [string]$needle) { if ($null -eq $b) { return -1 } return ([regex]::Matches([Text.Encoding]::UTF8.GetString($b), [regex]::Escape($needle))).Count + ([regex]::Matches([Text.Encoding]::Unicode.GetString($b), [regex]::Escape($needle))).Count }
Add-Type -AssemblyName System.IO.Compression.FileSystem
function ZipRead($zipPath, [string]$suffix) {
  $archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
  try { $entry = $archive.Entries | Where-Object { ($_.FullName -replace '\\','/') -like ('*' + $suffix) } | Select-Object -First 1
        if ($null -eq $entry) { return $null }; $memStream = New-Object IO.MemoryStream; $entryStream = $entry.Open(); try { $entryStream.CopyTo($memStream) } finally { $entryStream.Dispose() }; return ,$memStream.ToArray() }
  finally { $archive.Dispose() }
}
function ZipNames($zipPath) { $archive = [IO.Compression.ZipFile]::OpenRead($zipPath); try { return @($archive.Entries | ForEach-Object { $_.FullName -replace '\\','/' }) } finally { $archive.Dispose() } }
function Cnt($list, $pat) { return @($list | Where-Object { $_ -like $pat }).Count }

Say ('FULL PACKAGE  v4 ' + $BLESSED + '  (engine + Shell + installer)  ' + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + 'Z  host=' + $env:COMPUTERNAME)
Say ('PS ' + $PSVersionTable.PSVersion)
if ($env:COMPUTERNAME -eq 'RTM') { Say 'THIS IS SERVER 234 - nothing done'; Fin $false }

Say ''; Say 'G0  old clones in the clones folder are removed first (rule: removed at the start of the next box)'
New-Item -ItemType Directory -Force -Path $BUILDROOT | Out-Null
$old = @(Get-ChildItem -LiteralPath $BUILDROOT -Directory -ErrorAction SilentlyContinue)
Say ('  ' + $BUILDROOT + ' : ' + $old.Count + ' folder(s) before')
foreach ($oldClone in $old) { Remove-Item -LiteralPath $oldClone.FullName -Recurse -Force -ErrorAction SilentlyContinue; Say ('    ' + $oldClone.Name + ' removed ' + (-not (Test-Path -LiteralPath $oldClone.FullName))) }
$left = @(Get-ChildItem -LiteralPath $BUILDROOT -Directory -ErrorAction SilentlyContinue).Count
Say ('  folders left ' + $left + ' (expected 0)'); if ($left -ne 0) { Say '  RED - an old clone could not be removed; nothing built'; Fin $false }

Say ''; Say 'G1  head of v4 must be the blessed revision'
$pin = (git -C $V4WT rev-parse v4).Trim(); Say ('  expected ' + $BLESSED + '   measured ' + $pin)
if ($pin.Substring(0,7) -ne $BLESSED) { Say '  RED - nothing built'; Fin $false }
Say ('  floor ' + (Split-Path -Leaf $FLOOR) + ' present ' + (Test-Path $FLOOR)); if (-not (Test-Path $FLOOR)) { Fin $false }
$floorSha = Sha $FLOOR; Say ('  floor sha ' + $floorSha.Substring(0,16) + ' = e8e67a1 package 5651F471... : ' + ($floorSha -eq $FLOOR_SHA)); if ($floorSha -ne $FLOOR_SHA) { Fin $false }

Say ''; Say 'PIN 1-2  clean clone at the pin'
$CLONE = Join-Path $BUILDROOT ('rtm_v4f_' + $BLESSED + '_' + $stamp)
git clone --quiet --no-hardlinks --no-checkout $V4WT $CLONE; git -C $CLONE checkout --quiet --detach $pin
$cloneHead = (git -C $CLONE rev-parse HEAD).Trim(); $dirty = @(git -C $CLONE status --porcelain -uall).Count
Say ('  clone ' + $CLONE + '  HEAD == pin ' + ($cloneHead -eq $pin) + '  dirty ' + $dirty + ' (expected 0)')
if (($cloneHead -ne $pin) -or ($dirty -ne 0)) { Fin $false }

Say ''; Say 'PIN 3  the delta decides the mode and the needles'
$deltaPaths = @(git -C $V4WT diff --name-only ($DEPLOYED + '..' + $pin))
$rows = @(
  @('total', $deltaPaths.Count, 32), @('src/*', (Cnt $deltaPaths 'src/*'), 22), @('tests/*', (Cnt $deltaPaths 'tests/*'), 10), @('RTM/*', (Cnt $deltaPaths 'RTM/*'), 0),
  @('db/*', (Cnt $deltaPaths 'db/*'), 0), @('db/migrations/*', (Cnt $deltaPaths 'db/migrations/*'), 0), @('deploy/*', (Cnt $deltaPaths 'deploy/*'), 0),
  @('src/*/Migrations/*', (Cnt $deltaPaths 'src/*/Migrations/*'), 0))
$deltaOk = $true
foreach ($row in $rows) { $allOk = ($row[1] -eq $row[2]); if (-not $allOk) { $deltaOk = $false }; Say ('  {0,-22} expected {1,3}  measured {2,3}  {3}' -f $row[0], $row[2], $row[1], $(if ($allOk) {'ok'} else {'RED'})) }
$cacheBustLines = @(git -C $V4WT diff ($DEPLOYED + '..' + $pin) | Where-Object { $_ -match '^[+-][^+-]' -and $_ -match '\?v=' })
Say ('  "?v=" lines in the delta (information; cache-bust of changed assets): ' + $cacheBustLines.Count); foreach ($deltaLine in $cacheBustLines) { Say ('    ' + $deltaLine.Trim()) }
Say '  no DB migration in the delta: the install runs with -SkipDB and an empty migration list'
if (-not $deltaOk) { Say '  RED - the delta is not the one this probe was written for; nothing built'; Fin $false }
Flush

Say ''; $started = Get-Date
Say ('PIN 4  Build-ProdRelease -Mode Full -SkipDB in the clone, started ' + $started.ToString('HH:mm:ss'))
$builder = Join-Path $CLONE 'tools\Build-ProdRelease.ps1'; Say ('  builder sha256 ' + (Sha $builder))
$garnet = Join-Path $WORK 'tools\cache\garnet-1.1.10-win-x64-net8'; $nssm = Join-Path $WORK 'tools\cache\nssm'
Push-Location $CLONE
try { & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $builder -Mode Full -SkipDB -GarnetDir $garnet -NssmDir $nssm 2>&1 | ForEach-Object { Say ('  | ' + $_) }; $builderExit = $LASTEXITCODE } finally { Pop-Location }
Say ('  builder exit ' + $builderExit + ' (expected 0)'); if ($builderExit -ne 0) { Fin $false }

Say ''; Say 'PIN 5  the zip - fresh from THIS run'
$zip = Get-ChildItem -LiteralPath (Join-Path $CLONE 'Installations') -Filter *.zip | Where-Object { $_.LastWriteTime -ge $started } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $zip) { Say '  RED - no zip from this run'; Fin $false }
$zsha = Sha $zip.FullName
Say ('  ' + $zip.Name + '  ' + $zip.Length + ' B  sha256 ' + $zsha)

Say ''; Say 'PIN 6  inside the package (before side = the installed floors)'
$allOk = $true
$names = ZipNames $zip.FullName
$countRtm = Cnt $names 'RTM/*'; $countShell = Cnt $names 'Shell/*'
Say ('  entries ' + $names.Count + ' ; RTM/ ' + $countRtm + ' (expected > 0) ; Shell/ ' + $countShell + ' (expected > 0) ; DB/*.sql ' + (Cnt $names 'DB/*.sql') + ' (info; not applied)')
if (($countRtm -le 0) -or ($countShell -le 0)) { $allOk = $false }
$upd = ZipRead $zip.FullName 'Update-RTMView.ps1'
if ($null -eq $upd) { Say '  Update-RTMView.ps1 ABSENT'; $allOk = $false } else {
  $txt = [Text.Encoding]::UTF8.GetString($upd); if ($txt.Length -gt 0 -and $txt[0] -eq [char]0xFEFF) { $txt = $txt.Substring(1) }
  $norm = [Text.Encoding]::UTF8.GetBytes($txt.Replace("`r`n", "`n")); $hdr = [Text.Encoding]::ASCII.GetBytes('blob ' + $norm.Length + [char]0)
  $blob = [BitConverter]::ToString((New-Object Security.Cryptography.SHA1Managed).ComputeHash([byte[]]($hdr + $norm))).Replace('-','').ToLower()
  Say ('  Update-RTMView.ps1 in the zip: git blob after BOM/CRLF normalisation ' + $blob.Substring(0,12) + ' (expected e115b8c32030 = git blob of deploy/Update-RTMView.ps1 at cdb8316 and at e8e67a1, measured 2026-11-06) ; has Get-ServicesToCycle ' + $txt.Contains('Get-ServicesToCycle'))
  if (($blob -ne $INSTALLER_BLOB) -or -not $txt.Contains('Get-ServicesToCycle')) { $allOk = $false }
}
$full = (git -C $V4WT rev-parse $pin).Trim(); $fullDep = (git -C $V4WT rev-parse $DEPLOYED).Trim()
foreach ($dll in 'Shell/CcDashboard.Web.dll','RTM/RTM.dll') {
  $newBytes = ZipRead $zip.FullName $dll; $floorBytes = ZipRead $FLOOR $dll
  $changed = ($null -ne $newBytes) -and ($null -ne $floorBytes) -and ((ShaB $newBytes) -ne (ShaB $floorBytes))
  $verNew = NeedleB $newBytes ('+' + $full); $verOld = NeedleB $floorBytes ('+' + $fullDep); $verCross = NeedleB $newBytes ('+' + $fullDep)
  $good = $changed -and ($verNew -ge 1) -and ($verOld -ge 1) -and ($verCross -eq 0)
  Say ('  {0,-24} bytes changed vs floor {1} ; version stamp +{2} in new {3} ; +{4} in floor {5} ; old stamp in new {6} (expected True, >=1, >=1, 0)  {7}' -f $dll, $changed, $pin, $verNew, $DEPLOYED, $verOld, $verCross, $(if ($good) {'ok'} else {'RED'}))
  if (-not $good) { $allOk = $false } }
$needles = @(
  @('/CcDashboard.Web.dll', 'AgentPerformanceReportWidget', 'APPEARING'),
  @('/CcDashboard.Application.dll', 'GetScopedAgentsQuery', 'APPEARING'),
  @('/CcDashboard.Contracts.dll', 'AgentSummaryColumns', 'APPEARING'),
  @('/CcDashboard.Contracts.dll', 'ReportCaveat', 'APPEARING'),
  @('/CcDashboard.Contracts.dll', 'ReportDateFields', 'APPEARING'),
  @('/CcDashboard.Infrastructure.dll', 'AgentNameRule', 'APPEARING'),
  @('/CcDashboard.Web.dll', 'ReportWidget_AgentsAll', 'APPEARING'),
  @('/CcDashboard.Web.dll', 'EndOfShiftQueuesReportWidget', 'STAYS'),
  @('/CcDashboard.Web.dll', 'ReportViewPage', 'STAYS'),
  @('/CcDashboard.Contracts.dll', 'ZzzNoSuchNeedle', 'NEGCTL'),
  @('RTM/RTM.dll', 'ZzzNoSuchNeedle', 'NEGCTL'))
foreach ($needle in $needles) {
  $after = NeedleB (ZipRead $zip.FullName $needle[0]) $needle[1]; $before = NeedleB (ZipRead $FLOOR $needle[0]) $needle[1]
  $good = switch ($needle[2]) { 'APPEARING' { ($before -eq 0) -and ($after -ge 1) } 'STAYS' { ($before -ge 1) -and ($after -ge 1) } 'NEGCTL' { ($before -eq 0) -and ($after -eq 0) } }
  Say ('  {0,-9} {1,-28} "{2}"  before {3} -> after {4}  {5}' -f $needle[2], $needle[0].TrimStart('/'), $needle[1], $before, $after, $(if ($good) {'ok'} else {'RED'}))
  if (-not $good) { $allOk = $false } }
if (-not $allOk) { Fin $false }

Say ''; Say 'PIN 7  hand-over copy into Installations'
$dest = Join-Path $WORK ('Installations\' + $zip.Name); Copy-Item -LiteralPath $zip.FullName -Destination $dest -Force
$copySha = Sha $dest; Say ('  ' + $dest + '  sha equal ' + ($copySha -eq $zsha)); if ($copySha -ne $zsha) { Fin $false }
Say ('  commit ' + $pin + ' ; zip ' + $zip.Name + ' ; sha256 ' + $zsha)
Remove-Item -LiteralPath $CLONE -Recurse -Force -ErrorAction SilentlyContinue; Say ('  build clone removed (new clone rule): ' + (-not (Test-Path -LiteralPath $CLONE)) + ' ; kept only when NOT READY')
Fin $true
