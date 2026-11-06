<#
  PROBE  probe_234_20261106_install-b7ac9dd.ps1  - devops-1106, 2026-11-06. Derived by diff from probe_234_20261106_install-cdb8316.ps1 (ea4d0487),
  itself from probe_234_20261106_install-aed65b1.ps1
  (coordinator §4 2026-11-06T14:58:46Z), which was derived from probe_234_20261104_install-e8e67a1.ps1 (RESULT DONE on 234).
  ON THE CORE. THIS RUN WRITES: it installs v4 b7ac9dd (engine + Shell + installer) on production 234.
  Mechanism unchanged: bus gate, package and floor named before the first write, backup prune predicted by name, appearing
  needles that STOP phase 1, installer words counted, needles both ways, equality with the staged package, ledger.
  UNIT   v4 b7ac9dd over e8e67a1 (234 runs e8e67a1: MANIFEST of 2026-11-04 20:07:20Z, package 04112026.1455.zip 5651F471...).
         Delta e8e67a1..b7ac9dd: 32 paths = src 22, tests 10 (aed65b1 + shell 10caa3c + backend cdb8316 + TRIM b7ac9dd); RTM 0, db 0, deploy 0. EF migrations 0, SQL migrations 0.
         Head green from a clean clone 2026-11-06 (Arch 77, Unit 685, Engine 161, Integ 39, Sec 349) -
         .coord/measure/deploy-prep-1104/headgreen_20261106_192001.txt.
  PACKAGE 06112026.1925.zip  D7913AD0CBD4C39C8C5AE0701923BBEACEB99B79157B467696C9C284B4140A2B  129799148 B,
         built by probe_WS_20261106_fullpkg-b7ac9dd.ps1, READY TO HAND OVER (.coord/measure/pkg-b7ac9dd/WS_20261106_192432_fullpkg-b7ac9dd.txt).
  ROLLBACK FLOOR 04112026.1455.zip (5651F471..., v4 e8e67a1, engine + Shell), installed again with its own updater by
         probe_234_20261106_rollback-b7ac9dd-to-e8e67a1.ps1. No DB change in either direction (no migration in the delta).
  NEW IN THIS UNIT: RTM\app.dat. The installer does NOT preserve it, it lays the package copy ("{" LF "}", 3 B, 8EB95BCB...).
         Phase 1 STOPS if the machine's app.dat is anything else; after the install it must equal the package.
  ROLLBACK SIGN (named before the run): installer exit != 0 or [RECOVERY]/DEPLOY FAILED; any of the three services not Running
         with a new pid within 420 s; engine exceptions after the start > 0; the seed burst collapsing to one StatusChanged value
         (timers reset); status-log rows ahead of now() by more than 5 min (V0 > +00:05); the report page failing on screen (shell).
  THE LEGACY C:\IceDash\RTM\RTM.exe IS NEVER RESTARTED. The adapter is raised by the engine, never by hand.
#>
. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$PackagePath = 'C:\RTMView-Ops\incoming\06112026.1925.zip'; $PinnedZipSha = 'D7913AD0CBD4C39C8C5AE0701923BBEACEB99B79157B467696C9C284B4140A2B'
$PinnedCommit = 'b7ac9dd'; $BlessingStamp = 'b7ac9dd'; $BlessingWord = 'ВЫКАТ'
$Floors = @(
  @{ Path = 'C:\RTMView-Ops\incoming\04112026.1455.zip'; Sha = '5651F47188BC5772B29BE3C1C815AE0662A9308EEE2BA5FD988EB8F6AD41996F'; What = 'engine + Shell e8e67a1' })
$SHELL_DIR = 'C:\RTMView\Shell'; $RTM_DIR = 'C:\RTMView\RTM'
$AppliedDir = 'C:\RTMView-Ops\applied'; $InboxPath = '\\tsclient\D\Claude\Projects\RTM View Shell\.coord\inbox\devops.md'
$RunStamp = Get-Date -Format yyyyMMdd_HHmmss
New-Item -ItemType Directory -Force -Path $AppliedDir | Out-Null
Start-Probe -Name 'install-b7ac9dd' -Title 'PRE-DEPLOY + INSTALL: engine + Shell + installer from v4 b7ac9dd'
Say ('PS version : ' + $PSVersionTable.PSVersion.ToString() + '   edition ' + $PSVersionTable.PSEdition + '   host ' + $Host.Name + '   console encoding ' + [Console]::OutputEncoding.WebName)
Rule
Assert-Machine
function Read-File([string]$pair) { if (-not (Test-Path -LiteralPath $pair)) { return $null }; return ,[IO.File]::ReadAllBytes($pair) }
function Size-Of([string]$pair) { if (-not (Test-Path -LiteralPath $pair)) { return -1 }; $measure = Get-ChildItem -LiteralPath $pair -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum; if ($null -eq $measure.Sum) { return 0 }; return [int64]$measure.Sum }
function Pair-Sum($pair) { return ($pair[0] + $pair[1]) }
function Db-Probe([string]$label) {
  $conn = Get-MachineConnection (Join-Path $SHELL_DIR 'appsettings.json')
  if (($null -eq $conn) -or ($conn.Port -ne '5433')) { Say '    *** not the App DB on 5433 - NOT MEASURED'; return @() }
  $sql = @"
SELECT 'RO', current_setting('transaction_read_only');
SELECT 'HIST', count(*) FROM public.__ef_migrations_history;
SELECT 'V0', max("StartTime") FILTER (WHERE "StartTime" < now() + interval '1 year') - now() FROM public."RTSData_UserStatusLog";
SELECT 'V0I', max("UpdateTime") FILTER (WHERE "UpdateTime" < now() + interval '1 year') - now() FROM public."RTSData_Interaction";
"@
  $env:PGOPTIONS = '-c default_transaction_read_only=on'
  try { $rows = Invoke-Psql $conn $label $sql (Join-Path 'C:\RTMView-Ops\output' ('db_' + $RunStamp)) $true } finally { $env:PGOPTIONS = $null }
  return $rows
}

Say 'PHASE 1  PRE-DEPLOY. Nothing is written in this phase; it may STOP the run.'
Rule
Say '1a  G-BUS - every letter after the blessing, read BEFORE anything is written'
if (-not (Test-Path -LiteralPath $InboxPath)) { Say '  *** THE INBOX CANNOT BE READ FROM HERE. STOP.' ; Finish $false }
$headings = @(Select-String -LiteralPath $InboxPath -Pattern '^## ' -Encoding UTF8 -ErrorAction SilentlyContinue)
Say ('  letters : ' + $headings.Count)
if ($headings.Count -eq 0) { Say '  *** NO LETTERS - the reader is wrong. STOP.' ; Finish $false }
$blessingIndex = -1
for ($index = 0; $index -lt $headings.Count; $index++) { $heading = $headings[$index].Line; if ($heading.Contains($BlessingStamp) -and $heading.Contains('-> devops-1106') -and $heading.Contains('coordinator-') -and $heading.Contains('PASS') -and $heading.ToUpper().Contains($BlessingWord)) { $blessingIndex = $index } }
Say ('  blessing (coordinator-* to devops-1106, "PASS" + "' + $BlessingWord + '" + ' + $BlessingStamp + ', the LAST such) at letter ' + $blessingIndex + '   (-1 = not found)')
if ($blessingIndex -lt 0) { Say '  *** NO BLESSING (or Cyrillic not decoded). STOP.' ; Finish $false }
$stopWords = @('СТОП','ОТЗЫВА','STOP','ОТМЕН'); $stopHits = 0
for ($index = $blessingIndex + 1; $index -lt $headings.Count; $index++) { $heading = $headings[$index].Line; $hit = @($stopWords | Where-Object { $heading.ToUpper().Contains($_) }).Count; if ($hit) { $stopHits++ }; Say ('    after : ' + $heading.Substring(0, [math]::Min(150, $heading.Length)) + '   stop words ' + $hit) }
$stopControl = @($stopWords | Where-Object { 'ПРОБА: СТОП ВЫКАТА'.Contains($_) }).Count
Say ('  stop hits ' + $stopHits + ' ; POSCTL on "ПРОБА: СТОП ВЫКАТА" : ' + $stopControl + ' (must be >= 1)')
if ($stopControl -lt 1) { Say '  *** stop words blind. STOP.' ; Finish $false }
if ($stopHits -gt 0) { Say '  *** A STOP IS STANDING. Nothing installed.' ; Finish $false }
Rule

Say '1b  THE PACKAGE AND BOTH ROLLBACK FLOORS'
$packageSha = ShaOf $PackagePath
Say ('  package ' + $PackagePath + '  expected ' + $PinnedZipSha + '  measured ' + $packageSha)
$packageOk = ($packageSha -eq $PinnedZipSha)
$floorOk = $true
foreach ($fileItem in $Floors) { $subject = ShaOf $fileItem.Path; $isOk = ($subject -eq $fileItem.Sha); if (-not $isOk) { $floorOk = $false }; Say ('  floor ' + $fileItem.What + ' : ' + $fileItem.Path + '  equal to the package the machine runs : ' + $isOk) }
Say  '  The other direction = the same updater from the floor package (one package: engine + Shell). No DB step: no migration in between.'
Rule

Say '1c  DISK AND THE BACKUP PRUNE'
$shellSize = Size-Of $SHELL_DIR; $engineSize = Size-Of $RTM_DIR; $oneSet = $shellSize + $engineSize; $driveBefore = (Get-PSDrive -Name C).Free
$keepBackups = 2; $own = @()
foreach ($backupDir in @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue)) { $timeValue = [datetime]::MinValue
  if (($backupDir.Name -match '^\d{8}_\d{4}$') -and [datetime]::TryParseExact($backupDir.Name, 'ddMMyyyy_HHmm', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$timeValue)) { $own += [pscustomobject]@{ Name = $backupDir.Name; Taken = $timeValue; Bytes = (Size-Of $backupDir.FullName) } } else { Say ('    other directory, kept : ' + $backupDir.Name) } }
$own = @($own | Sort-Object Taken -Descending); $ownBefore = $own.Count
$keep = @($own | Select-Object -First ($keepBackups - 1)); $prune = @($own | Select-Object -Skip ($keepBackups - 1)); $pruneBytes = [int64](($prune | Measure-Object Bytes -Sum).Sum)
foreach ($keepItem in $keep) { Say ('    KEPT   ' + $keepItem.Name) }; foreach ($prunedItem in $prune) { Say ('    PRUNED ' + $prunedItem.Name + '  ' + [math]::Round($prunedItem.Bytes/1MB,1) + ' MB') }
$free2 = $driveBefore + $pruneBytes
Say ('  one set ' + [math]::Round($oneSet/1MB,1) + ' MB ; free ' + [math]::Round($driveBefore/1MB,1) + ' + pruned ' + [math]::Round($pruneBytes/1MB,1) + ' = ' + [math]::Round($free2/1MB,1) + ' MB ; need two sets ' + [math]::Round(2*$oneSet/1MB,1))
$diskOk = (($oneSet -gt 0) -and ($free2 -ge 2 * $oneSet))
Say ('  DISK GATE : ' + $diskOk)
Rule

Say '1d  BEFORE-HALF OF EVERY NEEDLE on what the machine runs now'
$STAMP_NEW = '+b7ac9dd84bcd0eaa9cb74da0a245323a7b7cfc19'; $STAMP_OLD = '+e8e67a1e76dc8085b285b8cd9da13ff23c3bca86'
$NEEDLES = @(
  @('Web',       (Join-Path $SHELL_DIR 'CcDashboard.Web.dll'),            'AgentPerformanceReportWidget',      'APPEARING'),
  @('App',       (Join-Path $SHELL_DIR 'CcDashboard.Application.dll'),    'GetScopedAgentsQuery',              'APPEARING'),
  @('Contracts', (Join-Path $SHELL_DIR 'CcDashboard.Contracts.dll'),      'ReportCaveat',                      'APPEARING'),
  @('Infra',     (Join-Path $SHELL_DIR 'CcDashboard.Infrastructure.dll'), 'AgentNameRule',                     'APPEARING'),
  @('Web',       (Join-Path $SHELL_DIR 'CcDashboard.Web.dll'),            'ReportWidget_AgentsAll',            'APPEARING'),
  @('Contracts', (Join-Path $SHELL_DIR 'CcDashboard.Contracts.dll'),      'ExportSkipReason',                  'STAYS'),
  @('Web',       (Join-Path $SHELL_DIR 'CcDashboard.Web.dll'),            'EndOfShiftQueuesReportWidget',      'STAYS'),
  @('Web',       (Join-Path $SHELL_DIR 'CcDashboard.Web.dll'),            $STAMP_NEW,                          'APPEARING'),
  @('Web',       (Join-Path $SHELL_DIR 'CcDashboard.Web.dll'),            $STAMP_OLD,                          'VANISHING'),
  @('Web',       (Join-Path $SHELL_DIR 'CcDashboard.Web.dll'),            'ReportViewPage',                    'STAYS'),
  @('RTM.dll',   (Join-Path $RTM_DIR 'RTM.dll'),                          $STAMP_NEW,                          'APPEARING'),
  @('RTM.dll',   (Join-Path $RTM_DIR 'RTM.dll'),                          $STAMP_OLD,                          'VANISHING'),
  @('RTM.dll',   (Join-Path $RTM_DIR 'RTM.dll'),                          'userStatusChanged',                 'STAYS'),
  @('Contracts', (Join-Path $SHELL_DIR 'CcDashboard.Contracts.dll'),      'ZzzNoSuchNeedle',                   'NEGCTL'))
$before = @{}; $provable = $true
foreach ($needle in $NEEDLES) { $pair = Needle-Pair (Read-File $needle[1]) $needle[2]; $before[$needle[0] + '|' + $needle[2]] = $pair
  $good = switch ($needle[3]) { 'APPEARING' { (Pair-Sum $pair) -eq 0 } 'VANISHING' { (Pair-Sum $pair) -ge 1 } 'STAYS' { (Pair-Sum $pair) -ge 1 } 'NEGCTL' { (Pair-Sum $pair) -eq 0 } }
  if (-not $good) { $provable = $false }
  Say ('  {0,-9} {1,-9} "{2}" : {3}/{4}  {5}' -f $needle[3], $needle[0], $needle[2], $pair[0], $pair[1], $(if ($good) {'ok'} else {'RED'})) }
Say ('  NEEDLES PROVABLE (appearing 0, vanishing >= 1, stays >= 1, reader sees the assemblies) : ' + $provable)
Rule

Say '1e  PRE-STATE: services, files that must not move, the DB before'
$pidsBefore = @{}
foreach ($subject in @('RTMService','RTMViewShell','RTMTwilio_1')) { $svcState = StateOf $subject; $pidsBefore[$subject] = $svcState.ProcessId; Say ('  ' + $subject.PadRight(14) + ' ' + ([string]$svcState.State).PadRight(9) + ' pid ' + $svcState.ProcessId) }
$keepFiles = @('C:\RTMView\RTM\data.sys', 'C:\RTMView\RTM\appsettings.json', 'C:\RTMView\RTM\log4net.config', (Join-Path $SHELL_DIR 'appsettings.json'), (Join-Path $SHELL_DIR 'appsettings.Production.json'), (Join-Path $SHELL_DIR 'nlog.config'), 'C:\RTMView\RTM.Twilio\appsettings.json', 'C:\RTMView\RTM.Twilio\log4net.config', 'C:\RTMView\RTM.Twilio\RTM.Twilio.exe')
$keepBefore = @{}; foreach ($keepItem in $keepFiles) { $keepBefore[$keepItem] = ShaOf $keepItem; Say ('  ' + $keepItem + ' : ' + $keepBefore[$keepItem].Substring(0, [math]::Min(16, $keepBefore[$keepItem].Length))) }
$APPDAT = 'C:\RTMView\RTM\app.dat'; $APPDAT_PKG = '8EB95BCBC154530931E15FC418C8B1FE991095671409552099EA1AA596999EDE'
$appDatBefore = ShaOf $APPDAT; $appDatOk = ($appDatBefore -eq $APPDAT_PKG)
Say ('  ' + $APPDAT + ' : expected ' + $APPDAT_PKG.Substring(0,16) + ' (the package copy, 3 B) measured ' + $appDatBefore.Substring(0, [math]::Min(16, $appDatBefore.Length)) + '  ' + $(if ($appDatOk) {'ok'} else {'RED - the installer would overwrite a machine value'}))
$backupCountBefore = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue).Count
$legacyBefore = StateOf 'RTM'; Say ('  legacy service RTM : ' + $legacyBefore.State + ' (never ours)')
$excBefore = 'NOT MEASURED'
try { $rtmConfig = [IO.File]::ReadAllText('C:\RTMView\RTM\appsettings.json') | ConvertFrom-Json; $logDirBefore = [string]$rtmConfig.RTM.LogConfig; $from = (Get-Date).AddMinutes(-60).ToString('yyyy-MM-dd HH:mm:ss'); $excCountBefore = 0; $linesBefore = 0
  foreach ($fileItem in @(Get-ChildItem -LiteralPath $logDirBefore -Filter 'RTM.log*' -ErrorAction Stop)) { foreach ($logLine in @(Read-SharedLines $fileItem.FullName)) { if ($logLine.Length -lt 19) { continue }; if ($logLine.Substring(0,19) -lt $from) { continue }; $linesBefore++; if ($logLine -match '(?i)exception') { $excCountBefore++ } } }
  $excBefore = ('' + $excCountBefore + ' exception lines in ' + $linesBefore + ' stamped lines of the last 60 min') } catch { }
Say ('  engine log BEFORE (the "before" number for the rollback sign): ' + $excBefore)
Say '  DB BEFORE (read-only):'
$dbBefore = Db-Probe 'db_before'
Rule

Say 'THE GATE BETWEEN THE PHASES'
$phase1Ok = ($packageOk -and $floorOk -and $diskOk -and $provable -and $appDatOk -and (-not (Test-TrapFired)))
Say ('  package ' + $packageOk + ' ; floors ' + $floorOk + ' ; disk ' + $diskOk + ' ; needles provable ' + $provable + ' ; app.dat ' + $appDatOk + ' ; trap ' + (Test-TrapFired))
Say ('  PHASE 1 : ' + $(if ($phase1Ok) { 'PASS - phase 2 may write' } else { 'STOP - nothing installed' }))
Write-Report
if (-not $phase1Ok) { Finish $false }
Rule

Say 'PHASE 2  INSTALL. From here the server changes.'
Say '2a  EXTRACT'
$stagingDir = Join-Path 'C:\RTMView-Ops\incoming' ('pkg_{0}_{1}' -f $PinnedCommit, $RunStamp)
if (Test-Path -LiteralPath $stagingDir) { Say '  *** staging exists - STOP'; Finish $false }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($PackagePath, $stagingDir)
$updaterPath = Join-Path $stagingDir 'Update-RTMView.ps1'
$rtmPresent = Test-Path -LiteralPath (Join-Path $stagingDir 'RTM'); $shellPresent = Test-Path -LiteralPath (Join-Path $stagingDir 'Shell')
Say ('  staged ' + $stagingDir + ' ; RTM ' + $rtmPresent + ' ; Shell ' + $shellPresent + ' (both expected True)')
if (-not ($rtmPresent -and $shellPresent -and (Test-Path -LiteralPath $updaterPath))) { Say '  *** staged tree incomplete - STOP, server unchanged'; Finish $false }
$updText = [IO.File]::ReadAllText($updaterPath)
Say ('  updater carries Get-ServicesToCycle : ' + $updText.Contains('Get-ServicesToCycle') + ' (expected True - the same installer the package probe measured inside 06112026.1925.zip on 2026-11-06)')
if (-not $updText.Contains('Get-ServicesToCycle')) { Finish $false }
Rule

Say '2b  PASSWORD for the updater'
$sec = Read-Host -Prompt '  DB password for the updater' -AsSecureString
if ($null -eq $sec -or $sec.Length -eq 0) { Say '  nothing supplied - STOP before the install'; Finish $false }
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec); $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
Say ('  supplied : length ' + $plain.Length + ' (value never printed)')
Write-Report
Rule

Say '2c  THE INSTALL'
Say  '  Update-RTMView.ps1 -DBPort 5433 -SkipDrift -SkipCacheMigration -DBPassword <hidden>   (no -MigrationList, KeepBackups default 2)'
$out = @(); $installerExit = 1
Push-Location $stagingDir
try { $out = @(Invoke-Native { & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $updaterPath -DBPort 5433 -SkipDrift -SkipCacheMigration -DBPassword $plain 2>&1 }); $installerExit = $LASTEXITCODE }
finally { Pop-Location; $plain = $null; [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
foreach ($logLine in $out) { Say-Guarded ('  | ' + $logLine) }
Say ('  installer exit code : ' + $installerExit)
Write-Report
Rule

Say '2d  THE INSTALLER OWN WORDS'
$joined = ($out -join "`n")
function Count-Words([string]$timeValue) { return ([regex]::Matches($joined, [regex]::Escape($timeValue))).Count }
$summaryWanted = ('Installer backups: {0} found, {1} kept, {2} pruned' -f $ownBefore, [math]::Min($ownBefore, $keepBackups - 1), $prune.Count)
$prunedNames = @([regex]::Matches($joined, 'Pruned old backup: (\d{8}_\d{4})') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
$namesAgree = (($prunedNames -join ',') -eq ((@($prune | ForEach-Object { $_.Name }) | Sort-Object) -join ','))
$words = @(
  @('Services cycled by this run: RTMService, RTMViewShell', 1),
  @('No migrations specified', 1), @('Drift gate SKIPPED', 1), @('-ForceDeploy', 0), @('Installer backups:', 1), @($summaryWanted, 1),
  @('RTM updated ->', 1), @('Shell updated ->', 1), @('DEPLOY FAILED', 0), @('[RECOVERY]', 0))
$assertionsOk = $namesAgree
foreach ($wordRow in $words) { $wordCount = Count-Words $wordRow[0]; $isOk = ($wordCount -eq $wordRow[1]); if (-not $isOk) { $assertionsOk = $false }; Say ('  "' + $wordRow[0] + '" : ' + $wordCount + '   (expected ' + $wordRow[1] + ')  ' + $(if ($isOk) {'ok'} else {'RED'})) }
Say ('  pruned names ' + ($prunedNames -join ', ') + ' ; predicted ' + ((@($prune | ForEach-Object { $_.Name })) -join ', ') + ' ; agree ' + $namesAgree)
Say ('  ASSERTIONS : ' + $assertionsOk)
Rule

Say '2e  POST-STATE - all three pids must CHANGE (engine and Shell updated; the engine raises the adapter)'
$deadline = (Get-Date).AddSeconds(420); $pollStart = Get-Date; $adapterBackAt = $null
while ((Get-Date) -lt $deadline) { $reading = StateOf 'RTMTwilio_1'; $elapsed = [math]::Round(((Get-Date) - $pollStart).TotalSeconds, 0); Say ('    +' + $elapsed + ' s : RTMTwilio_1 ' + $reading.State + ' pid ' + $reading.ProcessId)
  if (($reading.State -eq 'Running') -and ($reading.ProcessId -ne $pidsBefore['RTMTwilio_1'])) { $adapterBackAt = $elapsed; break }; Start-Sleep -Seconds 15 }
$pidsOk = $true
foreach ($subject in @('RTMService','RTMViewShell','RTMTwilio_1')) { $svcState = StateOf $subject; $changed = ($svcState.ProcessId -ne $pidsBefore[$subject]) -and ($svcState.State -eq 'Running'); if (-not $changed) { $pidsOk = $false }
  Say ('  ' + $subject.PadRight(14) + ' ' + ([string]$svcState.State).PadRight(9) + ' pid ' + ([string]$svcState.ProcessId).PadRight(6) + ' was ' + $pidsBefore[$subject] + '   new and Running : ' + $changed) }
Say ('  adapter back at : ' + $(if ($null -ne $adapterBackAt) { '+' + $adapterBackAt + ' s' } else { 'NOT within 420 s - measured absence; NOT started by hand' }))
$backupCountAfter = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue).Count
$ownAfter = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{8}_\d{4}$' } | ForEach-Object { $_.Name })
$backupsOk = ($backupCountAfter -eq ($backupCountBefore - $prune.Count + 1)) -and ($ownAfter.Count -eq $keepBackups)
Say ('  backups ' + $backupCountBefore + ' -> ' + $backupCountAfter + ' (expected ' + ($backupCountBefore - $prune.Count + 1) + ') ; installer backups ' + ($ownAfter -join ', ') + ' ; ok ' + $backupsOk)
Say ('  C: free ' + [math]::Round($driveBefore/1MB,1) + ' -> ' + [math]::Round((Get-PSDrive -Name C).Free/1MB,1) + ' MB')
Write-Report
Rule

Say '2f  NEEDLES AFTER, against the before-half of this run'
$needlesOk = $true
foreach ($needle in $NEEDLES) { $pair = Needle-Pair (Read-File $needle[1]) $needle[2]; $beforePair = $before[$needle[0] + '|' + $needle[2]]
  $good = switch ($needle[3]) { 'APPEARING' { (Pair-Sum $pair) -ge 1 } 'VANISHING' { (Pair-Sum $pair) -eq 0 } 'STAYS' { (Pair-Sum $pair) -ge 1 } 'NEGCTL' { (Pair-Sum $pair) -eq 0 } }
  if (-not $good) { $needlesOk = $false }
  Say ('  {0,-9} {1,-9} "{2}" : {3}/{4} -> {5}/{6}  {7}' -f $needle[3], $needle[0], $needle[2], $beforePair[0], $beforePair[1], $pair[0], $pair[1], $(if ($good) {'ok'} else {'RED'})) }
Say ('  NEEDLES : ' + $needlesOk)
Rule

Say '2g  EQUALITY WITH THE STAGED PACKAGE'
$eqOk = $true
foreach ($rel in @('Shell\CcDashboard.Web.dll','Shell\CcDashboard.Application.dll','Shell\CcDashboard.Infrastructure.dll','Shell\CcDashboard.Contracts.dll','Shell\he-IL\CcDashboard.Web.resources.dll','Shell\ru-RU\CcDashboard.Web.resources.dll','Shell\wwwroot\app.css','Shell\wwwroot\CcDashboard.Web.styles.css','RTM\RTM.dll','RTM\RTM.Configuration.dll','RTM\RTM.Types.dll','RTM\RTM.exe','RTM\app.dat')) {
  $live = Join-Path 'C:\RTMView' $rel; $stg = Join-Path $stagingDir $rel; $shaLive = ShaOf $live; $shaStaged = ShaOf $stg
  $isOk = ($shaStaged -ne 'ABSENT') -and ($shaLive -eq $shaStaged); if (-not $isOk) { $eqOk = $false }; Say ('  ' + $rel.PadRight(44) + ' equals the package : ' + $isOk) }
$negEq = ShaOf (Join-Path $SHELL_DIR 'wwwroot\zzz-no-such-asset.css'); Say ('  NEGCTL absent asset reads : ' + $negEq + ' (must be ABSENT)'); if ($negEq -ne 'ABSENT') { $eqOk = $false }
Rule

Say '2h  WHAT MUST NOT HAVE MOVED (machine config, data.sys, the adapter)'
$keepOk = $true
foreach ($keepItem in $keepFiles) { $reading = ShaOf $keepItem; $isOk = ($reading -eq $keepBefore[$keepItem]); if (-not $isOk) { $keepOk = $false }; Say ('  ' + $keepItem.PadRight(48) + ' unchanged : ' + $isOk) }
$legacyAfter = StateOf 'RTM'; Say ('  legacy RTM : ' + $legacyBefore.State + ' -> ' + $legacyAfter.State + ' (not ours)')
Rule

Say '2i  THE DATABASE AFTER (read-only) - the App migration applied by the new Shell, V0 on rows written after the start'
Say '  waiting 120 s so the engine writes rows under the new code'
Start-Sleep -Seconds 120
$dbAfter = Db-Probe 'db_after'
Say '  expected: HIST unchanged (no migration in the delta) ; V0 (status log) and V0I (interactions) about 0, not ahead by > 5 min'
Rule

Say '2j  ENGINE LOG since the engine start: exceptions, and the seed burst (counts only - lines carry logins)'
$eng = StateOf 'RTMService'; $engStart = $null
try { $engStart = (Get-Process -Id $eng.ProcessId -ErrorAction Stop).StartTime } catch { }
$cfgRtm = $null; try { $cfgRtm = [IO.File]::ReadAllText('C:\RTMView\RTM\appsettings.json') | ConvertFrom-Json } catch { }
$logDir = $(if ($cfgRtm) { [string]$cfgRtm.RTM.LogConfig } else { '' })
if ($engStart -and $logDir -and (Test-Path -LiteralPath $logDir)) {
  $since = $engStart.ToString('yyyy-MM-dd HH:mm:ss'); $seedEnd = $engStart.AddSeconds(90).ToString('yyyy-MM-dd HH:mm:ss')
  $usc = 0; $exc = 0; $seedVals = @{}; $total = 0
  foreach ($fileItem in @(Get-ChildItem -LiteralPath $logDir -Filter 'RTM.log*' | Where-Object { $_.LastWriteTime -ge $engStart })) {
    foreach ($logLine in @(Read-SharedLines $fileItem.FullName)) { if ($logLine.Length -lt 19) { continue }; $timeValue = $logLine.Substring(0,19); if ($timeValue -lt $since) { continue }; $total++
      if ($logLine -match '(?i)exception') { $exc++ }
      if ($logLine -match 'userStatusChanged: userId=(\S+) .*StatusChanged=(\S+ \S+)') { $usc++; if ($timeValue -le $seedEnd) { $seedVals[$Matches[1]] = $Matches[2] } } } }
  $distinct = @($seedVals.Values | Sort-Object -Unique).Count
  Say ('  engine started ' + $since + ' ; log lines since ' + $total + ' (POSCTL > 0) ; userStatusChanged ' + $usc)
  Say ('  lines with "exception" since the start : ' + $exc + '   (expected 0)')
  Say ('  seed burst (first 90 s): users ' + $seedVals.Count + ' ; distinct StatusChanged ' + $distinct + '   (expected many - the 22.10 failure was one value for everyone)')
} else { Say '  engine log NOT MEASURED (start time or log dir unknown)' }
Rule

Say '2k  LEDGER'
$ledger = Join-Path $AppliedDir '_ledger.txt'
$line = ('{0} | MANIFEST | commit={1} package={2} package_sha256={3} web.dll_sha256={4} rtm.dll_sha256={5} installer_exit={6} by=devops-1106' -f (Utc-Now), $PinnedCommit, (Split-Path -Leaf $PackagePath), $packageSha, (ShaOf (Join-Path $SHELL_DIR 'CcDashboard.Web.dll')), (ShaOf (Join-Path $RTM_DIR 'RTM.dll')), $installerExit)
try { Add-Content -LiteralPath $ledger -Value $line -Encoding UTF8 -ErrorAction Stop; Say ('  ' + $line) } catch { Say ('  *** ledger not written: ' + $_.Exception.Message) }
Rule

Say 'VERDICT'
Say ('  installer exit ' + $installerExit + ' ; own words ' + $assertionsOk + ' ; pids new ' + $pidsOk + ' ; backups ' + $backupsOk + ' ; needles ' + $needlesOk + ' ; equal to package ' + $eqOk + ' ; config/data/adapter unchanged ' + $keepOk + ' ; trap ' + (Test-TrapFired))
Say  '  The DB rows (2i) and the engine log (2j) are read by me against the expectations printed above them, in the report.'
$stepOk = (($installerExit -eq 0) -and $assertionsOk -and $pidsOk -and $backupsOk -and $needlesOk -and $eqOk -and $keepOk -and (-not (Test-TrapFired)))
Say ('  RESULT : ' + $(if ($stepOk) { 'DONE - the screen checks next (shell, he-IL)' } else { 'PROBLEM - stop and report; the other direction is named in 1b' }))
Say ('  staging kept at ' + $stagingDir)
Say '===== END-OF-RUN MARKER: INSTALL-B7AC9DD-COMPLETE ====='
Finish $stepOk
