<#
  PROBE  probe_234_20261014_install-2324894.ps1
  ON THE CORE. THIS RUN WRITES: it installs on production 234.
  UNIT   install 14102026.0928_Shell.zip, built from v4 head 2324894, -Mode Shell -SkipDB.
         Blessing 2026-10-14T06:18:42Z with the operator word in it. G-BUS below re-reads my inbox
         before anything is written and stops on a stop word - a blessing is a gate at the moment of
         the write, not a permission granted earlier in the day.
  THE NEEDLES RUN BOTH WAYS THIS TIME, and the before-half of each was measured on this machine at
         09:35 [234_20261014_093552_predeploy-2324894.txt]:
           web.dll "[PROBE" utf16   5  ->  must be 0     a DISAPPEARING needle
           bundle "1fr auto 38px"   0  ->  must be >= 1
           Application.dll "GetTenantStatusGroupsQuery"  0 -> >= 1
           key TenantSettings_WfmGroupNotInData in web.dll, he-IL, ru-RU   0 -> >= 1
         The disappearing one is why the before-half mattered: a zero after the install proves
         nothing unless it was non-zero before, and it was five.
  THE DISK GATE, re-measured here rather than trusted from the pre-deploy run 20 minutes ago: the
         updater copies Shell AND RTM whatever the mode, and yesterday that ran C: out of space at
         step 2 of 5. Below two backup sets this probe stops BEFORE the install.
  EXACTLY ONE ASSET VERSION MOVES: the scoped bundle, 10 -> 11. The other eight must come out of
         this install reading what they read at 09:35.
  NOT A PREDICATE: the sha of a rebuilt assembly, in either direction. Every assembly is judged
         only by equality with THIS package, read from the staging this run unpacks on this disk,
         so both halves of every comparison are measured in one run by one instrument.
  THE LEGACY C:\IceDash\RTM\RTM.exe IS NEVER RESTARTED, under any circumstance.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$PackagePath   = 'C:\RTMView-Ops\incoming\14102026.0928_Shell.zip'
$PinnedZipSha  = 'BB226218B2289ED5FF34CA705F3B4D53E409C1E846B7B02356C8E0C1AB4A52B6'
$PinnedCommit  = '2324894'
$RollbackZip    = 'C:\RTMView-Ops\incoming\13102026.1353_Shell.zip'
$RollbackZipSha = '8E2652AE40C3F8B53635FCA8D9F480218D04DECF8573DC56D24FAE783D2ED0D6'
$SHELL_DIR  = 'C:\RTMView\Shell'
$AppliedDir = 'C:\RTMView-Ops\applied'
$InboxPath  = '\\tsclient\D\Claude\Projects\RTM View Shell\.coord\inbox\devops.md'
# measured on THIS machine at 09:35 today, not carried from another day
$WebDllBefore   = '23BC7CAF17557959CA44A6F0FD27A28AD27837B1DEC4CD6636B41CA215DB18AF'
$AppDllBefore   = 'DBD8188521BA47E6086A4B7EF00D5DC5E6A482733858BCB5156F8703FA05F982'
$BundleBefore   = 'D2F85CB1B8ADFFE53D5583342B0D17806AC1CB7537D6A2EC75DEDF9057D5972E'
$ProbeNeedleBefore = 5
$PidsBefore = @{ 'RTMViewShell' = 7140 ; 'RTMService' = 3732 ; 'RTMTwilio_1' = 3124 }

$RunStamp = Get-Date -Format yyyyMMdd_HHmmss
New-Item -ItemType Directory -Force -Path $AppliedDir | Out-Null
Start-Probe -Name 'install-2324894' -Title 'STEP 2  INSTALL  flight 2324894 (Wfm counts agents again)'
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

Say 'G-BUS  THE LAST LETTER IN MY INBOX - read BEFORE anything is written'
Say ('  inbox : ' + $InboxPath)
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

Say 'ROLLBACK, PRINTED BEFORE THE FIRST WRITE'
Say ('  the floor is the package this machine runs now: ' + $RollbackZip)
$floorSha = ShaOf $RollbackZip
Say ('  expected sha256 : ' + $RollbackZipSha)
Say ('  measured sha256 : ' + $floorSha)
if ($floorSha -ne $RollbackZipSha) { Say '  *** the floor package is not the bytes it should be. STOP - nothing written.' ; Finish $false }
Say  '  To roll back: install that package again with the same updater. It is physically on this disk.'
Rule

Say 'DISK GATE - re-measured here, not trusted from the pre-deploy run'
$shellSize  = Size-Of $SHELL_DIR
$engineSize = Size-Of 'C:\RTMView\RTM'
$oneSet = $shellSize + $engineSize
$driveBefore = (Get-PSDrive -Name C).Free
Say ('  one backup set : ' + [math]::Round($oneSet/1MB,1) + ' MB (Shell + RTM, both copied whatever the mode)')
Say ('  expected : free >= ' + [math]::Round(2*$oneSet/1MB,1) + ' MB    measured : ' + [math]::Round($driveBefore/1MB,1) + ' MB')
$diskOk = ($driveBefore -ge (2 * $oneSet))
Say ('  DISK GATE : ' + $(if ($diskOk) { 'PASS' } else { 'STOP - below two sets, nothing is installed, the list goes to the coordinator' }))
if (-not $diskOk) { Finish $false }
Rule

Say 'PRE-STATE, taken again here so this report stands alone'
$serviceStateBefore = @{}
foreach ($serviceName in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $serviceState = StateOf $serviceName
  $serviceStateBefore[$serviceName] = $serviceState.State
  Say ('  ' + $serviceName.PadRight(14) + ' ' + ([string]$serviceState.State).PadRight(9) + ' pid ' + $serviceState.ProcessId + '   (09:35 pid ' + $PidsBefore[$serviceName] + ')')
}
$backupCountBefore = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue).Count
Say ('  backup directories BEFORE : ' + $backupCountBefore + '   (the acceptance expects exactly ' + ($backupCountBefore + 1) + ')')
$dataSysBefore  = ShaOf 'C:\RTMView\RTM\data.sys'
$engineBefore   = ShaOf 'C:\RTMView\RTM\RTM.dll'
$shellCfgBefore = ShaOf (Join-Path $SHELL_DIR 'appsettings.json')
$log4netBefore  = ShaOf 'C:\RTMView\RTM.Twilio\log4net.config'
Say ('  data.sys BEFORE   : ' + $dataSysBefore)
Say ('  RTM.dll  BEFORE   : ' + $engineBefore + '   (measured by THIS run, so the engine check rests on no carried number)')
$legacyBefore = StateOf 'RTM'
Say ('  legacy service RTM BEFORE : ' + $legacyBefore.State + '   - we never touch it; printed so a change by someone else is not read as ours')
Rule

Say 'PACKAGE GATE'
if (-not (Test-Path -LiteralPath $PackagePath)) { Say '  *** NOT FOUND. Nothing was written. STOP.' ; Finish $false }
$packageSha = ShaOf $PackagePath
Say ('  sha256 expected : ' + $PinnedZipSha + '   (taken on the workstation when the package was built)')
Say ('  sha256 measured : ' + $packageSha)
if ($packageSha -ne $PinnedZipSha) { Say '  *** MISMATCH - not the package step 0 built. Nothing written. STOP.' ; Finish $false }
Rule

Say 'EXTRACT - the package is unpacked on THIS disk, so both halves of every later comparison are measured here'
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
Say ('  Shell folder present : ' + $shellPresent + '    RTM folder present : ' + $rtmPresent + ' (expected False for Mode Shell)')
if ($rtmPresent) { Say '  *** an RTM folder came out of a Shell package. STOP - the server is not yet changed.' ; Finish $false }
if (-not $shellPresent) { Say '  *** no Shell folder in the staged tree. STOP - nothing installed.' ; Finish $false }
if (-not (Test-Path -LiteralPath $updaterPath)) { Say '  *** Update-RTMView.ps1 missing. Nothing installed. STOP.' ; Finish $false }
Say ('  Update-RTMView.ps1 sha256 : ' + (ShaOf $updaterPath))
Rule

Say 'PASSWORD'
$securePassword = Read-Host -Prompt '  DB password for the updater' -AsSecureString
if ($null -eq $securePassword -or $securePassword.Length -eq 0) { Say '  nothing supplied - STOP before the install' ; Finish $false }
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))
Say ('  supplied : length ' + $plainPassword.Length + ' , sha256 ' + ([BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($plainPassword))).Replace('-','')).Substring(0,16) + '...')
Say  '  The value itself is never printed and never written to this report.'
Rule

Write-Report   # flush: everything up to the gates is on disk BEFORE the installer runs, so a crash inside it still leaves the operator a readable report
Say 'THE INSTALL - this is the moment the server changes'
Say  '  Update-RTMView.ps1 -DBPort 5433 -SkipDrift -SkipCacheMigration -KeepBackups 50 -DBPassword <hidden>'
$outputLines = @()
Push-Location $stagingDir
try {
  $outputLines = @(Invoke-Native { & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $updaterPath -DBPort 5433 -SkipDrift -SkipCacheMigration -KeepBackups 50 -DBPassword $plainPassword 2>&1 })
  $installerExit = $LASTEXITCODE
} finally { Pop-Location }
$plainPassword = $null
foreach ($outputLine in $outputLines) { Say ('  | ' + $outputLine) }
Say ('  installer exit code : ' + $installerExit)
Write-Report   # flush: the installer own output is on disk before the long adapter wait
Rule

Say 'ASSERTIONS ON THE INSTALLER OWN WORDS (counted occurrences, not a glance)'
$joinedOutput = ($outputLines -join "`n")
$countMigrations = ([regex]::Matches($joinedOutput, [regex]::Escape('No migrations specified'))).Count
$countSkipped    = ([regex]::Matches($joinedOutput, [regex]::Escape('Drift gate SKIPPED'))).Count
$countSkipFlag   = ([regex]::Matches($joinedOutput, [regex]::Escape('-SkipDrift'))).Count
$countForce      = ([regex]::Matches($joinedOutput, [regex]::Escape('-ForceDeploy'))).Count
Say ('  "No migrations specified" : ' + $countMigrations + '   (expected 1 - this flight changes no schema)')
Say ('  "Drift gate SKIPPED"      : ' + $countSkipped + '   (expected 1)')
Say ('  "-SkipDrift" named there  : ' + $countSkipFlag + '   (expected 1 or more)')
Say ('  NEGCTL "-ForceDeploy"     : ' + $countForce + '   (must be 0 - it was not passed)')
$assertionsOk = (($countMigrations -eq 1) -and ($countSkipped -eq 1) -and ($countSkipFlag -ge 1) -and ($countForce -eq 0))
Say ('  ASSERTIONS : ' + $(if ($assertionsOk) { 'GREEN' } else { 'RED - report it, do not re-run the installer' }))
Rule

Say 'POST-STATE - services, then the adapter polled to a deadline'
foreach ($serviceName in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $serviceState = StateOf $serviceName
  Say ('  ' + $serviceName.PadRight(14) + ' ' + ([string]$serviceState.State).PadRight(9) + ' pid ' + $serviceState.ProcessId + '   (was ' + $serviceStateBefore[$serviceName] + ', pid ' + $PidsBefore[$serviceName] + ')')
}
$adapterDeadline = (Get-Date).AddSeconds(420)
$adapterPollStart = Get-Date
$adapterBackAt = $null
Say  '  POLLING THE ADAPTER UNTIL A 420 s DEADLINE, not for a fixed number of samples: it returned at'
Say  '  278 s once, and a window narrower than the slowest measured return cannot tell "never came up"'
Say  '  from "slower than I watched". The engine raises it; this run never starts it by hand.'
while ((Get-Date) -lt $adapterDeadline) {
  $adapter = StateOf 'RTMTwilio_1'
  $elapsedSeconds = [math]::Round(((Get-Date) - $adapterPollStart).TotalSeconds, 0)
  Say ('    +' + $elapsedSeconds + ' s : RTMTwilio_1 ' + $adapter.State + '   pid ' + $adapter.ProcessId)
  if ($adapter.State -eq 'Running') { $adapterBackAt = $elapsedSeconds ; break }
  Start-Sleep -Seconds 15
}
if ($null -eq $adapterBackAt) { Say '    THE ADAPTER DID NOT COME BACK INSIDE 420 s - a measured absence with its window named, and still NOT a reason to start it by hand.' }
else { Say ('    came back at +' + $adapterBackAt + ' s from the first poll.') }
$backupCountAfter = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue).Count
Say ('  backup directories : ' + $backupCountBefore + ' -> ' + $backupCountAfter + '   (no new one means the installer never reached its backup step)')
$driveAfter = (Get-PSDrive -Name C).Free
Say ('  C: free ' + [math]::Round($driveBefore/1MB,1) + ' -> ' + [math]::Round($driveAfter/1MB,1) + ' MB   (a pair, because one number proves nothing)')
Rule

Say 'THE NEEDLES, AFTER - each against the count measured at 09:35'
$webAfter = Read-File (Join-Path $SHELL_DIR 'CcDashboard.Web.dll')
$appAfter = Read-File (Join-Path $SHELL_DIR 'CcDashboard.Application.dll')
$bundleAfter = Read-File (Join-Path $SHELL_DIR 'wwwroot\CcDashboard.Web.styles.css')
$needlesOk = $true
if ($null -eq $webAfter) { Say '  web.dll ABSENT after the install - RED' ; $needlesOk = $false }
else {
  $probe16 = Count-Needle $webAfter '[PROBE' 'utf16'
  $probe8  = Count-Needle $webAfter '[PROBE' 'utf8'
  Say ('  web.dll "[PROBE" : utf16 ' + $probe16 + ' (was ' + $ProbeNeedleBefore + ') , utf8 ' + $probe8)
  Say  '  THE DISAPPEARING NEEDLE. Both encodings are printed so a zero cannot mean "I looked wrong",'
  Say  '  and the before-count of 5 is what makes this zero mean anything at all.'
  if (($probe16 + $probe8) -ne 0) { $needlesOk = $false }
  $key16 = Count-Needle $webAfter 'TenantSettings_WfmGroupNotInData' 'utf16'
  $key8  = Count-Needle $webAfter 'TenantSettings_WfmGroupNotInData' 'utf8'
  Say ('  web.dll key "TenantSettings_WfmGroupNotInData" : utf16 ' + $key16 + ' , utf8 ' + $key8 + '   (was 0 / 0, expected 1 or more)')
  if (($key16 + $key8) -lt 1) { $needlesOk = $false }
  $negKey = Count-Needle $webAfter 'TenantSettings_ZzzNoSuchKey' 'utf16'
  Say ('  NEGCTL a key that cannot be there : ' + $negKey + '   must be 0')
  if ($negKey -ne 0) { $needlesOk = $false }
}
if ($null -eq $appAfter) { Say '  Application.dll ABSENT after the install - RED' ; $needlesOk = $false }
else {
  $query16 = Count-Needle $appAfter 'GetTenantStatusGroupsQuery' 'utf16'
  $query8  = Count-Needle $appAfter 'GetTenantStatusGroupsQuery' 'utf8'
  Say ('  Application.dll "GetTenantStatusGroupsQuery" : utf16 ' + $query16 + ' , utf8 ' + $query8 + '   (was 0 / 0, expected 1 or more)')
  if (($query16 + $query8) -lt 1) { $needlesOk = $false }
}
if ($null -eq $bundleAfter) { Say '  the bundle is ABSENT after the install - RED' ; $needlesOk = $false }
else {
  $grid = Count-Needle $bundleAfter '1fr auto 38px' 'utf8'
  $negGrid = Count-Needle $bundleAfter '1fr auto 999px' 'utf8'
  Say ('  bundle "1fr auto 38px" : ' + $grid + '   (was 0, expected 1 or more)    NEGCTL : ' + $negGrid + ' (must be 0)')
  if (($grid -lt 1) -or ($negGrid -ne 0)) { $needlesOk = $false }
  Say ('  bundle sha : ' + (ShaOf (Join-Path $SHELL_DIR 'wwwroot\CcDashboard.Web.styles.css')) + '   (was ' + $BundleBefore.Substring(0,16) + '...)')
}
foreach ($culture in @('he-IL','ru-RU')) {
  $satelliteBytes = Read-File (Join-Path $SHELL_DIR ($culture + '\CcDashboard.Web.resources.dll'))
  if ($null -eq $satelliteBytes) { Say ('  ' + $culture + ' satellite ABSENT - RED') ; $needlesOk = $false ; continue }
  $satKey = Count-Needle $satelliteBytes 'TenantSettings_WfmGroupNotInData' 'utf16'
  Say ('  ' + $culture.PadRight(6) + ' key "TenantSettings_WfmGroupNotInData" : ' + $satKey + '   (was 0, expected 1 or more)')
  if ($satKey -lt 1) { $needlesOk = $false }
}
Say ('  NEEDLES : ' + $needlesOk)
Rule

Say 'THE WHOLE STATIC TREE AND THE ASSEMBLIES, AGAINST THE STAGING THIS RUN UNPACKED'
$stagedWwwroot = Join-Path $stagingDir 'Shell\wwwroot'
$liveWwwroot   = Join-Path $SHELL_DIR 'wwwroot'
$staticOk = $true
$comparedCount = 0
$mismatchCount = 0
$missingCount = 0
if (-not (Test-Path -LiteralPath $stagedWwwroot)) { Say ('  *** the staged wwwroot is not there - the walk is NOT MEASURED') ; $staticOk = $false }
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
$assembliesOk = $true
foreach ($assemblyName in @('CcDashboard.Web.dll','CcDashboard.Application.dll','CcDashboard.Contracts.dll')) {
  $diskSha = ShaOf (Join-Path $SHELL_DIR $assemblyName)
  $stagedSha = ShaOf (Join-Path $stagingDir ('Shell\' + $assemblyName))
  $agrees = (($stagedSha -ne 'ABSENT') -and ($diskSha -eq $stagedSha))
  Say ('  ' + $assemblyName.PadRight(30) + ' equals the package : ' + $agrees)
  if (-not $agrees) { $assembliesOk = $false }
}
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $diskSha = ShaOf (Join-Path $SHELL_DIR ($culture + '\CcDashboard.Web.resources.dll'))
  $stagedSha = ShaOf (Join-Path $stagingDir ('Shell\' + $culture + '\CcDashboard.Web.resources.dll'))
  $agrees = (($stagedSha -ne 'ABSENT') -and ($diskSha -eq $stagedSha))
  Say ('  satellite ' + $culture.PadRight(8) + ' equals the package : ' + $agrees)
  if (-not $agrees) { $assembliesOk = $false }
}
Say  '  Only equality with THIS package is asserted. A rebuilt assembly sha changes by itself, so'
Say  '  neither "unchanged" nor "differs" against what the machine ran before is a lawful row.'
Rule

Say 'WHAT MUST NOT HAVE MOVED'
$engineAfter = ShaOf 'C:\RTMView\RTM\RTM.dll'
$dataSysAfter = ShaOf 'C:\RTMView\RTM\data.sys'
$shellCfgAfter = ShaOf (Join-Path $SHELL_DIR 'appsettings.json')
$log4netAfter = ShaOf 'C:\RTMView\RTM.Twilio\log4net.config'
$engineOk = ($engineAfter -eq $engineBefore)
$dataOk = ($dataSysAfter -eq $dataSysBefore)
$configOk = (($shellCfgAfter -eq $shellCfgBefore) -and ($log4netAfter -eq $log4netBefore))
Say ('  RTM.dll unchanged              : ' + $engineOk + '   (Mode Shell carries no RTM folder at all)')
Say ('  data.sys unchanged             : ' + $dataOk)
Say ('  machine config preserved       : ' + $configOk)
$legacyAfter = StateOf 'RTM'
Say ('  legacy service RTM : ' + $legacyBefore.State + ' -> ' + $legacyAfter.State + ' (not ours either way)')
if (-not $configOk) { Say '  *** MACHINE CONFIG CHANGED - stop and report to the coordinator, even if everything else is green' }
Rule

Say 'LEDGER - the build-to-commit link, because our installer writes no manifest of its own'
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

Say 'VERDICT OF THE INSTALL (acceptance of the product is the next, reading step)'
Say ('  trap fired during the run : ' + (Test-TrapFired) + '   (True means a section was SKIPPED, not passed)')
Say ('  installer exit            : ' + $installerExit)
Say ('  installer own words       : ' + $assertionsOk)
Say ('  needles, both directions  : ' + $needlesOk)
Say ('  static tree == package    : ' + $staticOk)
Say ('  assemblies == package     : ' + $assembliesOk)
Say ('  engine / data.sys / config: ' + $engineOk + ' / ' + $dataOk + ' / ' + $configOk)
Say ('  staging kept at: ' + $stagingDir + '   (the acceptance reads it; delete after the flight is accepted)')
$stepOk = (($installerExit -eq 0) -and $assertionsOk -and $needlesOk -and $staticOk -and $assembliesOk -and $engineOk -and $dataOk -and $configOk -and (-not (Test-TrapFired)))
Say ('  STEP 2 : ' + $(if ($stepOk) { 'DONE - go to step 3, which decides whether this flight is accepted' } else { 'PROBLEM - stop and report; the rollback block is at the top of this report' }))
Say '===== END-OF-RUN MARKER: INSTALL-2324894-COMPLETE ====='
Finish $stepOk
