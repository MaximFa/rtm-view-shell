<#
  PROBE  probe_234_20261014_install-704b335.ps1
  ON THE CORE. THIS RUN WRITES: it installs on production 234.
  ONE PROBE FOR TWO STEPS, deliberately. The operator said the flight cost as much time as the
  development, and most of that time was his keystrokes. Pre-deploy and install are therefore one
  instrument with a gate between the phases: phase 1 measures and may STOP; phase 2 installs only
  if phase 1 passed. Nothing is carried between them by hand, so the before-half of every needle is
  measured in the same run that measures the after-half - which is stricter than the two-box form,
  not weaker.
  UNIT   v4 704b335 over the installed 2324894, -Mode Shell -SkipDB.
         Blessing: coordinator 2026-10-14T11:01:23Z, operator word quoted in it.
  PACKAGE 14102026.1416_Shell.zip, sha256 CF004840E25D58616DE4B779842F8DC4661FA413B515F18F2DCDF04D1B41B9AD,
         built and verified at 14:13 by probe_WS_20261014_shellpkg-704b335.ps1 - 17 witness blobs
         equal, 1 agreed absent (a deletion), 0 mismatched.
  THE NEEDLES RUN BOTH WAYS, before-halves taken in phase 1 of THIS run:
         Application.dll    GetTenantStatusGroupsQuery        >0 -> 0     DISAPPEARING
         Application.dll    GetWfmServingGroupCandidatesQuery  0 -> >=1
         Infrastructure.dll WfmEngineAgentCountProvider        0 -> >=1
         Infrastructure.dll WfmLogGate                         0 -> >=1
         web.dll + he-IL + ru-RU + en-US  key Wfm_NUnknown     0 -> >=1
         Both encodings on every needle, so a zero can never mean "wrong encoding".
  THE STATIC FILE: js/widget-resize.js is not compiled, so equality with the package copy is exact
         and lawful. The scoped bundle must come out equal to the package too - it did NOT move in
         this delta, and its sha is compared with the package, never with what the machine runs now.
  NOT A PREDICATE: the sha of a rebuilt assembly in either direction. Every assembly is judged only
         by equality with THIS package, unpacked by this run onto this disk.
  DISK: the updater copies Shell AND RTM whatever the mode. Below two measured backup sets this
         probe STOPS BEFORE the install and the list goes to the coordinator; I do not clean up.
  THE LEGACY C:\IceDash\RTM\RTM.exe IS NEVER RESTARTED, under any circumstance. The adapter is
         raised by the engine, never by hand.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$PackagePath   = 'C:\RTMView-Ops\incoming\14102026.1416_Shell.zip'
$PinnedZipSha  = 'CF004840E25D58616DE4B779842F8DC4661FA413B515F18F2DCDF04D1B41B9AD'
$PinnedCommit  = '704b335'
$RollbackZip    = 'C:\RTMView-Ops\incoming\14102026.0928_Shell.zip'
$RollbackZipSha = 'BB226218B2289ED5FF34CA705F3B4D53E409C1E846B7B02356C8E0C1AB4A52B6'
$SHELL_DIR  = 'C:\RTMView\Shell'
$AppliedDir = 'C:\RTMView-Ops\applied'
$InboxPath  = '\\tsclient\D\Claude\Projects\RTM View Shell\.coord\inbox\devops.md'

$RunStamp = Get-Date -Format yyyyMMdd_HHmmss
New-Item -ItemType Directory -Force -Path $AppliedDir | Out-Null
Start-Probe -Name 'install-704b335' -Title 'PRE-DEPLOY + INSTALL  flight 704b335 (N from the engine by skill)'
Say ('PS version : ' + $PSVersionTable.PSVersion.ToString())
Rule
Assert-Machine

function Count-Needle($haystack, [string]$text, [string]$encoding) {
  if ($null -eq $haystack) { return -1 }
  $needle = $(if ($encoding -eq 'utf16') { [Text.Encoding]::Unicode.GetBytes($text) } else { [Text.Encoding]::UTF8.GetBytes($text) })
  $count = 0
  $from = 0
  while ($from -le ($haystack.Length - $needle.Length)) {
    $slice = New-Object byte[] ($haystack.Length - $from)
    [Array]::Copy($haystack, $from, $slice, 0, $slice.Length)
    $foundAt = Find-ByteRun $slice $needle
    if ($foundAt -lt 0) { break }
    $count++
    $from = $from + $foundAt + $needle.Length
  }
  return $count
}
function Read-File([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  return ,[IO.File]::ReadAllBytes($path)
}
function Size-Of([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return -1 }
  $measured = Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum
  if ($null -eq $measured.Sum) { return 0 }
  return [int64]$measured.Sum
}
function Needle-Pair($bytes, [string]$text) {
  if ($null -eq $bytes) { return @(-1, -1) }
  return @((Count-Needle $bytes $text 'utf16'), (Count-Needle $bytes $text 'utf8'))
}

Say 'PHASE 1  PRE-DEPLOY. Nothing is written in this phase; it may STOP the run.'
Rule

Say '1a  G-BUS - the last letter in my inbox, read BEFORE anything is written'
if (-not (Test-Path -LiteralPath $InboxPath)) { Say '  *** THE INBOX CANNOT BE READ FROM HERE. I will not write to production blind. STOP.' ; Finish $false }
$headings = @(Select-String -LiteralPath $InboxPath -Pattern '^## ' -ErrorAction SilentlyContinue)
Say ('  letters in it : ' + $headings.Count + '   (zero would mean the reader is wrong, not that the bus is empty)')
if ($headings.Count -eq 0) { Say '  *** NO LETTERS FOUND - the reader is wrong. STOP.' ; Finish $false }
$lastLetter = $headings[-1].Line
Say ('  last letter   : ' + $lastLetter)
$stopHit = $false
foreach ($stopWord in @('СТОП','ОТОЗВА','STOP','ОТМЕН')) { if ($lastLetter.ToUpper().Contains($stopWord)) { $stopHit = $true } }
Say ('  stop word in the last letter : ' + $stopHit)
if ($stopHit) { Say '  *** A STOP IS STANDING. Nothing is installed.' ; Finish $false }
Rule

Say '1b  THE PACKAGE AND THE ROLLBACK FLOOR, both named before the first write'
if (-not (Test-Path -LiteralPath $PackagePath)) { Say ('  *** package NOT FOUND: ' + $PackagePath + '. STOP.') ; Finish $false }
$packageSha = ShaOf $PackagePath
Say ('  package  : ' + $PackagePath)
Say ('  expected : ' + $PinnedZipSha)
Say ('  measured : ' + $packageSha)
$packageOk = ($packageSha -eq $PinnedZipSha)
Say ('  package is the one built at 14:13 : ' + $packageOk)
$floorSha = ShaOf $RollbackZip
Say ('  rollback floor : ' + $RollbackZip)
Say ('  expected : ' + $RollbackZipSha + '    measured : ' + $floorSha)
$floorOk = ($floorSha -eq $RollbackZipSha)
Say ('  the floor is on this disk and is the package the machine runs now : ' + $floorOk)
Say  '  To roll back: install that package again with the same updater.'
Rule

Say '1c  DISK - one backup set is Shell + RTM, because the updater copies both whatever the mode'
$shellSize  = Size-Of $SHELL_DIR
$engineSize = Size-Of 'C:\RTMView\RTM'
$oneSet = $shellSize + $engineSize
$driveBefore = (Get-PSDrive -Name C).Free
Say ('  Shell ' + [math]::Round($shellSize/1MB,1) + ' MB + RTM ' + [math]::Round($engineSize/1MB,1) + ' MB = one set ' + [math]::Round($oneSet/1MB,1) + ' MB')
Say ('  expected : free >= ' + [math]::Round(2*$oneSet/1MB,1) + ' MB    measured : ' + [math]::Round($driveBefore/1MB,1) + ' MB')
$diskOk = ($driveBefore -ge (2 * $oneSet))
Say ('  DISK GATE : ' + $(if ($diskOk) { 'PASS' } else { 'STOP - below two sets; the list goes to the coordinator, I do not clean up myself' }))
Rule

Say '1d  THE BEFORE-HALF OF EVERY NEEDLE, measured now on what the machine runs'
$webBefore   = Read-File (Join-Path $SHELL_DIR 'CcDashboard.Web.dll')
$appBefore   = Read-File (Join-Path $SHELL_DIR 'CcDashboard.Application.dll')
$infraBefore = Read-File (Join-Path $SHELL_DIR 'CcDashboard.Infrastructure.dll')
$goneBefore = Needle-Pair $appBefore 'GetTenantStatusGroupsQuery'
$newQueryBefore = Needle-Pair $appBefore 'GetWfmServingGroupCandidatesQuery'
$providerBefore = Needle-Pair $infraBefore 'WfmEngineAgentCountProvider'
$gateBefore = Needle-Pair $infraBefore 'WfmLogGate'
$keyWebBefore = Needle-Pair $webBefore 'Wfm_NUnknown'
Say ('  Application.dll    GetTenantStatusGroupsQuery        : utf16 ' + $goneBefore[0] + ' , utf8 ' + $goneBefore[1] + '   MUST be non-zero now, or the zero after means nothing')
Say ('  Application.dll    GetWfmServingGroupCandidatesQuery : utf16 ' + $newQueryBefore[0] + ' , utf8 ' + $newQueryBefore[1] + '   expected 0')
Say ('  Infrastructure.dll WfmEngineAgentCountProvider       : utf16 ' + $providerBefore[0] + ' , utf8 ' + $providerBefore[1] + '   expected 0')
Say ('  Infrastructure.dll WfmLogGate                       : utf16 ' + $gateBefore[0] + ' , utf8 ' + $gateBefore[1] + '   expected 0')
Say ('  web.dll            key Wfm_NUnknown                 : utf16 ' + $keyWebBefore[0] + ' , utf8 ' + $keyWebBefore[1] + '   expected 0')
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satBytes = Read-File (Join-Path $SHELL_DIR ($culture + '\CcDashboard.Web.resources.dll'))
  $satPair = Needle-Pair $satBytes 'Wfm_NUnknown'
  Say ('  ' + $culture.PadRight(6) + '             key Wfm_NUnknown                 : utf16 ' + $satPair[0] + ' , utf8 ' + $satPair[1] + '   expected 0')
}
$disappearingIsProvable = (($goneBefore[0] + $goneBefore[1]) -gt 0)
Say ('  THE DISAPPEARING NEEDLE IS PROVABLE : ' + $disappearingIsProvable)
Say  '  If that is False the install may still be fine, but this probe could not prove the removal,'
Say  '  and it says so instead of printing a zero that would mean nothing.'
$resizeBeforeSha = ShaOf (Join-Path $SHELL_DIR 'wwwroot\js\widget-resize.js')
$bundleBeforeSha = ShaOf (Join-Path $SHELL_DIR 'wwwroot\CcDashboard.Web.styles.css')
Say ('  widget-resize.js before : ' + $resizeBeforeSha)
Say ('  bundle before           : ' + $bundleBeforeSha + '   (context; the lawful row is equality with the package)')
Rule

Say '1e  PRE-STATE of the services and the backups'
$serviceStateBefore = @{}
$pidsBefore = @{}
foreach ($serviceName in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $serviceState = StateOf $serviceName
  $serviceStateBefore[$serviceName] = $serviceState.State
  $pidsBefore[$serviceName] = $serviceState.ProcessId
  Say ('  ' + $serviceName.PadRight(14) + ' ' + ([string]$serviceState.State).PadRight(9) + ' pid ' + $serviceState.ProcessId)
}
$backupCountBefore = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue).Count
Say ('  backup directories BEFORE : ' + $backupCountBefore + '   (the install must leave exactly ' + ($backupCountBefore + 1) + ')')
$dataSysBefore  = ShaOf 'C:\RTMView\RTM\data.sys'
$engineBefore   = ShaOf 'C:\RTMView\RTM\RTM.dll'
$shellCfgBefore = ShaOf (Join-Path $SHELL_DIR 'appsettings.json')
$log4netBefore  = ShaOf 'C:\RTMView\RTM.Twilio\log4net.config'
Say ('  data.sys : ' + $dataSysBefore)
Say ('  RTM.dll  : ' + $engineBefore)
$legacyBefore = StateOf 'RTM'
Say ('  legacy service RTM : ' + $legacyBefore.State + '   - never ours, printed so a change by someone else is not read as ours')
Rule

Say 'THE GATE BETWEEN THE PHASES'
Say ('  package is the built one : ' + $packageOk)
Say ('  rollback floor present   : ' + $floorOk)
Say ('  disk                     : ' + $diskOk)
Say ('  trap fired so far        : ' + (Test-TrapFired))
$phase1Ok = ($packageOk -and $floorOk -and $diskOk -and (-not (Test-TrapFired)))
Say ('  PHASE 1 : ' + $(if ($phase1Ok) { 'PASS - phase 2 may write' } else { 'STOP - nothing is installed, the server is unchanged' }))
Write-Report
if (-not $phase1Ok) { Finish $false }
Rule

Say 'PHASE 2  INSTALL. From here the server changes.'
Rule

Say '2a  EXTRACT - the package is unpacked on THIS disk, so both halves of every comparison are measured here'
$stagingDir = Join-Path 'C:\RTMView-Ops\incoming' ('pkg_{0}_{1}' -f $PinnedCommit, $RunStamp)
if (Test-Path -LiteralPath $stagingDir) { Say ('  *** staging dir already exists: ' + $stagingDir + ' - STOP') ; Finish $false }
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($PackagePath)
try {
  foreach ($entry in $archive.Entries) {
    $relative = ($entry.FullName -replace '/', '\')
    $target = Join-Path $stagingDir $relative
    if ($entry.Length -eq 0 -and $entry.Name -eq '') { New-Item -ItemType Directory -Force -Path $target | Out-Null ; continue }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
  }
} finally { $archive.Dispose() }
$updaterPath = Join-Path $stagingDir 'Update-RTMView.ps1'
$rtmPresent   = Test-Path -LiteralPath (Join-Path $stagingDir 'RTM')
$shellPresent = Test-Path -LiteralPath (Join-Path $stagingDir 'Shell')
Say ('  staged to : ' + $stagingDir)
Say ('  Shell present : ' + $shellPresent + '    RTM present : ' + $rtmPresent + ' (expected False for Mode Shell)')
if ($rtmPresent) { Say '  *** an RTM folder came out of a Shell package. STOP - the server is not yet changed.' ; Finish $false }
if (-not $shellPresent) { Say '  *** no Shell folder in the staged tree. STOP - nothing installed.' ; Finish $false }
if (-not (Test-Path -LiteralPath $updaterPath)) { Say '  *** Update-RTMView.ps1 missing. STOP.' ; Finish $false }
Say ('  Update-RTMView.ps1 sha256 : ' + (ShaOf $updaterPath))
Rule

Say '2b  PASSWORD'
$securePassword = Read-Host -Prompt '  DB password for the updater' -AsSecureString
if ($null -eq $securePassword -or $securePassword.Length -eq 0) { Say '  nothing supplied - STOP before the install' ; Finish $false }
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
Say ('  supplied : length ' + $plainPassword.Length + ' , sha256 ' + ([BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($plainPassword))).Replace('-','')).Substring(0,16) + '...')
Say  '  The value itself is never printed and never written to this report.'
Write-Report
Rule

Say '2c  THE INSTALL - this is the moment the server changes'
Say  '  Update-RTMView.ps1 -DBPort 5433 -SkipDrift -SkipCacheMigration -KeepBackups 50 -DBPassword <hidden>'
$outputLines = @()
$installerExit = 1
Push-Location $stagingDir
try {
  $outputLines = @(Invoke-Native { & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $updaterPath -DBPort 5433 -SkipDrift -SkipCacheMigration -KeepBackups 50 -DBPassword $plainPassword 2>&1 })
  $installerExit = $LASTEXITCODE
} finally { Pop-Location }
$plainPassword = $null
foreach ($outputLine in $outputLines) { Say ('  | ' + $outputLine) }
Say ('  installer exit code : ' + $installerExit)
Write-Report
Rule

Say '2d  THE INSTALLER OWN WORDS, counted'
$joinedOutput = ($outputLines -join "`n")
$countMigrations = ([regex]::Matches($joinedOutput, [regex]::Escape('No migrations specified'))).Count
$countSkipped    = ([regex]::Matches($joinedOutput, [regex]::Escape('Drift gate SKIPPED'))).Count
$countForce      = ([regex]::Matches($joinedOutput, [regex]::Escape('-ForceDeploy'))).Count
Say ('  "No migrations specified" : ' + $countMigrations + '   (expected 1 - this flight changes no schema, and I checked the tree myself)')
Say ('  "Drift gate SKIPPED"      : ' + $countSkipped + '   (expected 1)')
Say ('  NEGCTL "-ForceDeploy"     : ' + $countForce + '   (must be 0 - it was not passed)')
$assertionsOk = (($countMigrations -eq 1) -and ($countSkipped -eq 1) -and ($countForce -eq 0))
Say ('  ASSERTIONS : ' + $assertionsOk)
Rule

Say '2e  POST-STATE - services, then the adapter polled to a deadline'
foreach ($serviceName in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $serviceState = StateOf $serviceName
  Say ('  ' + $serviceName.PadRight(14) + ' ' + ([string]$serviceState.State).PadRight(9) + ' pid ' + ([string]$serviceState.ProcessId).PadRight(6) + ' was pid ' + $pidsBefore[$serviceName])
}
$adapterDeadline = (Get-Date).AddSeconds(420)
$adapterPollStart = Get-Date
$adapterBackAt = $null
Say  '  POLLING THE ADAPTER TO A 420 s DEADLINE: it returned at 278 s once, and a window narrower'
Say  '  than the slowest measured return cannot tell "never came up" from "slower than I watched".'
while ((Get-Date) -lt $adapterDeadline) {
  $adapter = StateOf 'RTMTwilio_1'
  $elapsedSeconds = [math]::Round(((Get-Date) - $adapterPollStart).TotalSeconds, 0)
  Say ('    +' + $elapsedSeconds + ' s : RTMTwilio_1 ' + $adapter.State + '   pid ' + $adapter.ProcessId)
  if ($adapter.State -eq 'Running') { $adapterBackAt = $elapsedSeconds ; break }
  Start-Sleep -Seconds 15
}
if ($null -eq $adapterBackAt) { Say '    THE ADAPTER DID NOT COME BACK INSIDE 420 s - a measured absence with its window named, and still NOT a reason to start it by hand.' }
else { Say ('    came back at +' + $adapterBackAt + ' s') }
$backupCountAfter = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue).Count
Say ('  backup directories : ' + $backupCountBefore + ' -> ' + $backupCountAfter)
$driveAfter = (Get-PSDrive -Name C).Free
Say ('  C: free ' + [math]::Round($driveBefore/1MB,1) + ' -> ' + [math]::Round($driveAfter/1MB,1) + ' MB   (a pair, because one number proves nothing)')
Write-Report
Rule

Say '2f  THE NEEDLES, AFTER - each against the before-half measured in phase 1 of this same run'
$webAfter   = Read-File (Join-Path $SHELL_DIR 'CcDashboard.Web.dll')
$appAfter   = Read-File (Join-Path $SHELL_DIR 'CcDashboard.Application.dll')
$infraAfter = Read-File (Join-Path $SHELL_DIR 'CcDashboard.Infrastructure.dll')
$needlesOk = $true
if ($null -eq $appAfter) { Say '  Application.dll ABSENT after the install - RED' ; $needlesOk = $false }
else {
  $goneAfter = Needle-Pair $appAfter 'GetTenantStatusGroupsQuery'
  Say ('  DISAPPEARING GetTenantStatusGroupsQuery : utf16 ' + $goneAfter[0] + ' , utf8 ' + $goneAfter[1] + '   (before ' + $goneBefore[0] + ' / ' + $goneBefore[1] + ')   expected 0 / 0')
  if (($goneAfter[0] + $goneAfter[1]) -ne 0) { $needlesOk = $false }
  if (-not $disappearingIsProvable) { Say '      NOTE: the before-half was zero, so this zero proves nothing. Reported, not counted.' }
  $newQueryAfter = Needle-Pair $appAfter 'GetWfmServingGroupCandidatesQuery'
  Say ('  APPEARING GetWfmServingGroupCandidatesQuery : utf16 ' + $newQueryAfter[0] + ' , utf8 ' + $newQueryAfter[1] + '   (before ' + $newQueryBefore[0] + ' / ' + $newQueryBefore[1] + ')   expected 1 or more')
  if (($newQueryAfter[0] + $newQueryAfter[1]) -lt 1) { $needlesOk = $false }
  $negQuery = Count-Needle $appAfter 'GetWfmZzzNoSuchQuery' 'utf16'
  Say ('  NEGCTL a query that cannot be there : ' + $negQuery + '   must be 0')
  if ($negQuery -ne 0) { $needlesOk = $false }
}
if ($null -eq $infraAfter) { Say '  Infrastructure.dll ABSENT after the install - RED' ; $needlesOk = $false }
else {
  $providerAfter = Needle-Pair $infraAfter 'WfmEngineAgentCountProvider'
  $gateAfter = Needle-Pair $infraAfter 'WfmLogGate'
  Say ('  APPEARING WfmEngineAgentCountProvider : utf16 ' + $providerAfter[0] + ' , utf8 ' + $providerAfter[1] + '   (before ' + $providerBefore[0] + ' / ' + $providerBefore[1] + ')   expected 1 or more')
  Say ('  APPEARING WfmLogGate                  : utf16 ' + $gateAfter[0] + ' , utf8 ' + $gateAfter[1] + '   (before ' + $gateBefore[0] + ' / ' + $gateBefore[1] + ')   expected 1 or more')
  if ((($providerAfter[0] + $providerAfter[1]) -lt 1) -or (($gateAfter[0] + $gateAfter[1]) -lt 1)) { $needlesOk = $false }
}
if ($null -eq $webAfter) { Say '  web.dll ABSENT after the install - RED' ; $needlesOk = $false }
else {
  $keyWebAfter = Needle-Pair $webAfter 'Wfm_NUnknown'
  Say ('  web.dll key Wfm_NUnknown : utf16 ' + $keyWebAfter[0] + ' , utf8 ' + $keyWebAfter[1] + '   (before ' + $keyWebBefore[0] + ' / ' + $keyWebBefore[1] + ')   expected 1 or more')
  if (($keyWebAfter[0] + $keyWebAfter[1]) -lt 1) { $needlesOk = $false }
  $negKey = Count-Needle $webAfter 'Wfm_ZzzNoSuchKey' 'utf16'
  Say ('  NEGCTL a key that cannot be there : ' + $negKey + '   must be 0')
  if ($negKey -ne 0) { $needlesOk = $false }
}
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satAfter = Read-File (Join-Path $SHELL_DIR ($culture + '\CcDashboard.Web.resources.dll'))
  if ($null -eq $satAfter) { Say ('  ' + $culture + ' satellite ABSENT - RED') ; $needlesOk = $false ; continue }
  $satPair = Needle-Pair $satAfter 'Wfm_NUnknown'
  Say ('  ' + $culture.PadRight(6) + ' key Wfm_NUnknown : utf16 ' + $satPair[0] + ' , utf8 ' + $satPair[1] + '   expected 1 or more')
  if (($satPair[0] + $satPair[1]) -lt 1) { $needlesOk = $false }
}
Say ('  NEEDLES : ' + $needlesOk)
Write-Report
Rule

Say '2g  THE STATIC TREE AND THE ASSEMBLIES, against the staging THIS run unpacked'
$stagedWwwroot = Join-Path $stagingDir 'Shell\wwwroot'
$liveWwwroot   = Join-Path $SHELL_DIR 'wwwroot'
$staticOk = $true
$comparedCount = 0
$mismatchCount = 0
$missingCount = 0
if (-not (Test-Path -LiteralPath $stagedWwwroot)) { Say '  *** the staged wwwroot is not there - the walk is NOT MEASURED' ; $staticOk = $false }
else {
  foreach ($stagedFile in @(Get-ChildItem -LiteralPath $stagedWwwroot -Recurse -File -ErrorAction SilentlyContinue)) {
    $relative = $stagedFile.FullName.Substring($stagedWwwroot.Length).TrimStart('\')
    $liveFile = Join-Path $liveWwwroot $relative
    $comparedCount++
    if (-not (Test-Path -LiteralPath $liveFile)) { Say ('    MISSING ON DISK  ' + $relative) ; $missingCount++ ; $staticOk = $false ; continue }
    if ((ShaOf $stagedFile.FullName) -ne (ShaOf $liveFile)) { Say ('    DIFFERS          ' + $relative) ; $mismatchCount++ ; $staticOk = $false }
  }
  Say ('    files compared : ' + $comparedCount + '   (POSCTL - a zero means the walk measured nothing)')
  Say ('    differing : ' + $mismatchCount + '    missing : ' + $missingCount + '   both expected 0')
  $negStatic = ShaOf (Join-Path $liveWwwroot 'zzz-no-such-asset.css')
  Say ('    NEGCTL a file that cannot be there : ' + $negStatic + '   (must read ABSENT)')
  if (($comparedCount -le 0) -or ($negStatic -ne 'ABSENT')) { $staticOk = $false }
}
$resizeAfterSha = ShaOf (Join-Path $SHELL_DIR 'wwwroot\js\widget-resize.js')
Say ('  widget-resize.js : before ' + $resizeBeforeSha.Substring(0,16) + '...  after ' + $resizeAfterSha.Substring(0,16) + '...   changed : ' + ($resizeAfterSha -ne $resizeBeforeSha))
Say  '  It is a plain file, so the lawful row is the one above: equality with the package, checked in the walk.'
$assembliesOk = $true
foreach ($assemblyName in @('CcDashboard.Web.dll','CcDashboard.Application.dll','CcDashboard.Infrastructure.dll','CcDashboard.Contracts.dll')) {
  $diskSha = ShaOf (Join-Path $SHELL_DIR $assemblyName)
  $stagedSha = ShaOf (Join-Path $stagingDir ('Shell\' + $assemblyName))
  $agrees = (($stagedSha -ne 'ABSENT') -and ($diskSha -eq $stagedSha))
  Say ('  ' + $assemblyName.PadRight(32) + ' equals the package : ' + $agrees)
  if (-not $agrees) { $assembliesOk = $false }
}
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $diskSha = ShaOf (Join-Path $SHELL_DIR ($culture + '\CcDashboard.Web.resources.dll'))
  $stagedSha = ShaOf (Join-Path $stagingDir ('Shell\' + $culture + '\CcDashboard.Web.resources.dll'))
  $agrees = (($stagedSha -ne 'ABSENT') -and ($diskSha -eq $stagedSha))
  Say ('  satellite ' + $culture.PadRight(8) + ' equals the package : ' + $agrees)
  if (-not $agrees) { $assembliesOk = $false }
}
Say  '  Only equality with THIS package is asserted. A rebuilt assembly sha changes by itself.'
Rule

Say '2h  WHAT MUST NOT HAVE MOVED'
$engineAfter = ShaOf 'C:\RTMView\RTM\RTM.dll'
$dataSysAfter = ShaOf 'C:\RTMView\RTM\data.sys'
$shellCfgAfter = ShaOf (Join-Path $SHELL_DIR 'appsettings.json')
$log4netAfter = ShaOf 'C:\RTMView\RTM.Twilio\log4net.config'
$engineOk = ($engineAfter -eq $engineBefore)
$dataOk = ($dataSysAfter -eq $dataSysBefore)
$configOk = (($shellCfgAfter -eq $shellCfgBefore) -and ($log4netAfter -eq $log4netBefore))
Say ('  RTM.dll unchanged        : ' + $engineOk)
Say ('  data.sys unchanged       : ' + $dataOk)
Say ('  machine config preserved : ' + $configOk)
$legacyAfter = StateOf 'RTM'
Say ('  legacy service RTM : ' + $legacyBefore.State + ' -> ' + $legacyAfter.State + ' (not ours either way)')
Rule

Say '2i  LEDGER - the build-to-commit link, because the installer writes no manifest of its own'
$ledgerPath = Join-Path $AppliedDir '_ledger.txt'
$webDllAfter = ShaOf (Join-Path $SHELL_DIR 'CcDashboard.Web.dll')
$manifestLine = ('{0} | MANIFEST | commit={1} package={2} package_sha256={3} web.dll_sha256={4} installer_exit={5} by=devops-0919' -f ((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + 'Z'), $PinnedCommit, (Split-Path -Leaf $PackagePath), $packageSha, $webDllAfter, $installerExit)
try {
  Add-Content -LiteralPath $ledgerPath -Value $manifestLine -Encoding UTF8 -ErrorAction Stop
  Say ('  written to ' + $ledgerPath)
  Say ('  ' + $manifestLine)
  Say ('  ledger now has ' + (@(Get-Content -LiteralPath $ledgerPath)).Count + ' lines')
} catch { Say ('  *** could not write the ledger: ' + $_.Exception.Message) }
Rule

Say 'VERDICT OF PRE-DEPLOY AND INSTALL'
Say ('  trap fired during the run : ' + (Test-TrapFired) + '   (True means a section was SKIPPED, not passed)')
Say ('  phase 1 gate              : ' + $phase1Ok)
Say ('  installer exit            : ' + $installerExit)
Say ('  installer own words       : ' + $assertionsOk)
Say ('  needles, both directions  : ' + $needlesOk)
Say ('  static tree == package    : ' + $staticOk)
Say ('  assemblies == package     : ' + $assembliesOk)
Say ('  engine / data.sys / config: ' + $engineOk + ' / ' + $dataOk + ' / ' + $configOk)
Say ('  staging kept at: ' + $stagingDir + '   (the acceptance reads it)')
$stepOk = (($installerExit -eq 0) -and $assertionsOk -and $needlesOk -and $staticOk -and $assembliesOk -and $engineOk -and $dataOk -and $configOk -and (-not (Test-TrapFired)))
Say ('  INSTALL : ' + $(if ($stepOk) { 'DONE - the acceptance is the next and last box of this flight' } else { 'PROBLEM - stop and report; the rollback floor is named in 1b' }))
Say '===== END-OF-RUN MARKER: INSTALL-704B335-COMPLETE ====='
Finish $stepOk
