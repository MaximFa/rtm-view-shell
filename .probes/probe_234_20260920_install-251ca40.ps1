<#
  PROBE  probe_234_20260920_install-251ca40.ps1
  BASED  ON probe_234_20260920_install-0f969d8.ps1 - the run that installed 0f969d8 without a surprise.
  UNIT   install 20092026.2047_Shell.zip, built from 251ca40: filter popup closes on a dashboard
         click (CLOSE-SCOPE-01) and the screen editor localised, 19 keys into three dictionaries.
  WHAT   THE SATELLITES MUST MOVE, AND MOVE UPWARDS. Measured on this machine at 20:32 and inside the
         package at 20:48, the expected steps are +2048 / +1536 / +1536. A satellite still equal to its
         BEFORE size means the translations did not install; a SMALLER one means keys were lost.
  OUTAGE TWO-SERVICE OUTAGE. The updater stops and starts BOTH the engine and the adapter regardless
         of -Skip flags. The previous install on this machine measured 45.1 s [234_20260920_112957],
         plus ~16 s until the engine raises the adapter. Named in the box before the click.
  PASSWORD Read-Host -AsSecureString. Never printed, never written to the report.
  WHERE  SERVER 234. THIS RUN WRITES: it installs. Every gate before the install is read-only and any
         failing gate stops the run BEFORE the first write.
#>

param(
  [string]$PackagePath = 'C:\RTMView-Ops\incoming\20092026.2047_Shell.zip'
)

$ErrorActionPreference = 'Continue'
$PinnedZipSha  = '05F109BCE77BA876A784D8E1FEEFD61609781C1F9268E9709F768E6BBFDF95A6'
$PinnedWebDll  = '76C00DBCAA2E7A06F960E724BC8FD9A31FF9C22D8827A55BFFD815937B066115'
# data.sys is NOT judged against this constant. The AFTER value is compared to the BEFORE value
# measured by THIS run, so the check survives a licence file the operator legitimately replaced.
# The constant is kept only as a cross-check and is labelled as carried, not as the expectation.
$CarriedDataSys = '24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43'  # measured 2026-09-20 11:29
$PinnedCommit  = '251ca40'
# the floor we fall back to: the package this machine runs today, and the proof it is physically here
$RollbackZip    = 'C:\RTMView-Ops\incoming\20092026.1110_Shell.zip'
$RollbackZipSha = '85A6F2706D62C51E8486DFB9E7E93538E65EB7960FF17B65FA2991761A60903D'
$RollbackWebDll = 'E9D27996B41BB797A1C67EA3DEEE1BAEF46A0D5029E9E904792E07BF67973560'
# Measured ON THIS MACHINE at 20:32 today, before the install (234_20260920_203215_predeploy-state-pkg4):
$SatelliteBeforeBytes  = @{ 'he-IL' = 74752 ; 'ru-RU' = 84992 ; 'en-US' = 68096 }
# Measured INSIDE THE PACKAGE on the station during the build at 20:48 (WS_20260920_204252_shellpkg-step4):
$SatellitePackageBytes = @{ 'he-IL' = 76800 ; 'ru-RU' = 86528 ; 'en-US' = 69632 }
# Both rows were RE-MEASURED for this flight. The previous flight's 73728/83968/67584 describe a
# package that is no longer installed; carrying them over would compare against a machine state
# that no longer exists and would print RED on a correct install.
# EXPECTATION, PRINTED BEFORE THE MEASUREMENT: after the install each satellite DIFFERS from the
# before column AND EQUALS the package column. Equality with 'before' is RED, not a detail.
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
$AppliedDir = 'C:\RTMView-Ops\applied'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $AppliedDir | Out-Null
$ReportPath = Join-Path $OutputDir ("234_{0}_install-251ca40.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList

function Write-Report() {
  [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false)))
}
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) {
  Write-Report
  Write-Host ""
  Write-Host ("REPORT: " + $ReportPath)
  if ($passed) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($target) {
  if (-not (Test-Path -LiteralPath $target)) { return 'ABSENT' }
  try { return (Get-FileHash -LiteralPath $target -Algorithm SHA256 -ErrorAction Stop).Hash }
  catch { return ('HASH-FAILED: ' + $_.Exception.GetType().Name + ': ' + $_.Exception.Message) }
}

Say ("STEP 2  INSTALL  " + (Get-Date -Format u) + "   host=" + $env:COMPUTERNAME)
Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
Rule

Say "SELF-TEST of the hash instrument, before it gates anything"
$selfTestFile = Join-Path $env:TEMP ("sha_selftest_{0}.txt" -f $RunStamp)
[IO.File]::WriteAllText($selfTestFile, 'abc', (New-Object System.Text.UTF8Encoding($false)))
$selfTestGot = Get-Sha256Of $selfTestFile
Remove-Item -LiteralPath $selfTestFile -Force -ErrorAction SilentlyContinue
$selfTestOk = ($selfTestGot -eq 'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD')
Say ("  sha256('abc') -> " + $selfTestGot)
Say ("  SELF-TEST : " + $selfTestOk)
if (-not $selfTestOk) { Say "  the package gate below would be meaningless. STOP."; Finish $false }
Rule

Say "SELF-TEST of the report itself - the 3-byte file must not happen twice"
Say ("  report line count so far : " + $ReportLines.Count + "   (a number here means the list is still a list)")
Write-Report
$earlyBytes = (Get-Item -LiteralPath $ReportPath).Length
Say ("  report written to disk already, " + $earlyBytes + " bytes. It is rewritten before and after the install.")
Rule

Say "G0  machine identity"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing"; Finish $false }
Say "  G0 PASS"
Rule

Say "ROLLBACK, PRINTED BEFORE THE FIRST WRITE"
Say "  R1 services down and staying down:"
Say "       Start-Service RTMService ; wait for pipe rtmpipe_v3 and a reply on 8089 ; Start-Service RTMViewShell ;"
Say "       wait for https://127.0.0.1:8444/health = 200.  RTMTwilio_1 is NEVER started by hand - the engine raises it."
Say "  R2 binaries wrong after the install:"
Say "       the installer takes its own pre-install backup under C:\RTMView\Backup\<stamp>\ ."
Say "       Stop the services, copy that directory back over C:\RTMView\Shell and \RTM, then R1."
Say "  R3 database (NOT expected - this flight runs no migrations):"
Say "       pg_restore -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb --clean --if-exists <the step-1 dump>"
Say "       C:\RTMView-Ops\backup\rtmviewdb_pre0ae2102_20260918_224006.dump  sha256 FCFCB9C35CCAE21BEAB3E34EFE9D3E90E1533289703CD164F18B30B8139610C1"
Say "       then re-check F0 = 411B2F16944EA5297CE679B0B544CCD0E3C91532F1F3CCF26A4372216C7CB135, then R1."
Say "       R3 needs the operator's word at the moment; it is not automatic."
Say "  R4 C:\RTMView\Backup\rtmtwilio_aa19743_20260913_011524 (357 files) is NOT touched by this flight;"
Say "       -KeepBackups 50 is what keeps the installer from deleting it."
Rule

Say "ROLLBACK FLOOR - the artefact we would return to, proven present BEFORE anything is written"
Say  "  A plan to rebuild from the branch is NOT a floor. The floor is a package that exists on this disk."
Say ("  expected : " + $RollbackZip)
Say ("  expected sha256 : " + $RollbackZipSha)
if (-not (Test-Path -LiteralPath $RollbackZip)) {
  Say "  *** the package this machine runs today is NOT on this disk. There is no floor. STOP - nothing written."
  Finish $false
}
$floorSha = Get-Sha256Of $RollbackZip
Say ("  measured sha256 : " + $floorSha)
if ($floorSha -ne $RollbackZipSha) {
  Say "  *** the floor package is not the bytes it should be. STOP - nothing written."
  Finish $false
}
Say ("  floor GREEN - to undo this flight: extract " + $RollbackZip + " and run its Update-RTMView.ps1 the same way,")
Say ("  which restores Shell\CcDashboard.Web.dll to " + $RollbackWebDll)
Rule

Say "PRE-STATE, taken again here so this report stands alone"
$serviceStateBefore = @{}
foreach ($serviceName in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $service = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $serviceName) -ErrorAction SilentlyContinue
  if ($null -eq $service) { Say ("  {0,-14} ABSENT" -f $serviceName); $serviceStateBefore[$serviceName] = 'ABSENT' }
  else { $serviceStateBefore[$serviceName] = $service.State; Say ("  {0,-14} {1,-9} pid {2}" -f $service.Name, $service.State, $service.ProcessId) }
}
$backupCountBefore = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue).Count
Say ("  backup directories BEFORE : " + $backupCountBefore + "   (step 3 expects exactly " + ($backupCountBefore + 1) + ")")
Say ("  Shell\CcDashboard.Web.dll BEFORE : " + (Get-Sha256Of 'C:\RTMView\Shell\CcDashboard.Web.dll'))
$dataSysBefore = Get-Sha256Of 'C:\RTMView\RTM\data.sys'
Say ("  RTM\data.sys              BEFORE : " + $dataSysBefore)
$shellCfgBefore = Get-Sha256Of 'C:\RTMView\Shell\appsettings.json'
$log4netBefore  = Get-Sha256Of 'C:\RTMView\RTM.Twilio\log4net.config'
Say ("  Shell\appsettings.json    BEFORE : " + $shellCfgBefore + "   (must be IDENTICAL after - this is the preserve)")
Say ("  RTM.Twilio\log4net.config BEFORE : " + $log4netBefore + "   (must be IDENTICAL after)")
$legacyBefore = (Get-CimInstance Win32_Service -Filter "Name='RTM'" -ErrorAction SilentlyContinue)
$legacyStateBefore = $(if ($null -eq $legacyBefore) { 'ABSENT' } else { $legacyBefore.State })
Say ("  legacy service RTM        BEFORE : " + $legacyStateBefore + "   (not ours, never touched - read so that someone else's change is not blamed on this flight)")
$satelliteBefore = @{}
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satellitePath = 'C:\RTMView\Shell\' + $culture + '\CcDashboard.Web.resources.dll'
  if (Test-Path -LiteralPath $satellitePath) {
    $satelliteBefore[$culture] = (Get-Item -LiteralPath $satellitePath).Length
    Say ("  satellite " + $culture.PadRight(6) + " BEFORE : " + $satelliteBefore[$culture] + " B   " + (Get-Sha256Of $satellitePath))
  } else { $satelliteBefore[$culture] = -999 ; Say ("  satellite " + $culture.PadRight(6) + " BEFORE : ABSENT") }
}
Rule

Say "PACKAGE GATE"
Say ("  package : " + $PackagePath)
if (-not (Test-Path -LiteralPath $PackagePath)) { Say "  *** NOT FOUND. Nothing was written. STOP."; Finish $false }
$packageSha = Get-Sha256Of $PackagePath
Say ("  sha256 here     : " + $packageSha)
Say ("  sha256 expected : " + $PinnedZipSha + "   (taken on the workstation when the package was built)")
if ($packageSha -ne $PinnedZipSha) { Say "  *** MISMATCH - not the package step 0 built. Nothing written. STOP."; Finish $false }
Say "  GATE GREEN - the bytes on this server are the bytes built from 251ca40"
Unblock-File -LiteralPath $PackagePath -ErrorAction SilentlyContinue
Rule

Say "EXTRACT (entry by entry: this package writes its entry names with backslashes)"
$stagingDir = Join-Path 'C:\RTMView-Ops\incoming' ("pkg_{0}_{1}" -f $PinnedCommit, $RunStamp)
if (Test-Path -LiteralPath $stagingDir) { Say ("  *** staging dir already exists: " + $stagingDir + " - STOP"); Finish $false }
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($PackagePath)
$extractedCount = 0
try {
  foreach ($entry in $archive.Entries) {
    if ([string]::IsNullOrEmpty($entry.Name)) { continue }
    $relative = $entry.FullName.Replace('/', '\')
    $destination = Join-Path $stagingDir $relative
    $destinationDir = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDir)) { New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
    $extractedCount++
  }
} finally { $archive.Dispose() }
Say ("  extracted files : " + $extractedCount + "   into " + $stagingDir)
$updaterPath = Join-Path $stagingDir 'Update-RTMView.ps1'
foreach ($required in @($updaterPath, (Join-Path $stagingDir 'Shell'), (Join-Path $stagingDir 'RTM'))) {
  Say ("  present: " + $required + " -> " + (Test-Path -LiteralPath $required))
}
if (-not (Test-Path -LiteralPath $updaterPath)) { Say "  *** Update-RTMView.ps1 missing. Nothing installed. STOP."; Finish $false }
Get-ChildItem -LiteralPath $stagingDir -Recurse -Include *.ps1 | ForEach-Object { Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue }
$updaterSha = Get-Sha256Of $updaterPath
Say ("  Update-RTMView.ps1 sha256 : " + $updaterSha)
Say  "  expected : EB1142FA2A6D204855A5F70E84307DF04B6A15981DE7998ABB9D5444A1B74A0D"
Say  "  Source of that number, and it is NOT carried over blindly: the delta between the revision this machine runs and the one being installed contains ZERO files under deploy/ [measured on the station: 0 files, with POSCTL 6 files under src/], so the updater shipped inside this package must be byte-identical to the one shipped in the previous package."
Say  "  A DIFFERENT hash here means something reached deploy/ that this flight did not account for."
Say ("  package Shell\CcDashboard.Web.dll sha256 : " + (Get-Sha256Of (Join-Path $stagingDir 'Shell\CcDashboard.Web.dll')))
Rule

Say "MIGRATIONS - why the parameter is absent from the command below"
Say  '  The plan requires an EMPTY migration list. The installer declares [string]$MigrationList = "" as its'
Say  '  (single-quoted here on purpose: in the double-quoted form this line printed  = \  and swallowed the'
Say  '  variable name, because a backslash does not escape a quote in PowerShell. Measured 2026-09-20.)'
Say  "  default, so NOT passing it is exactly that empty value - and cannot be mangled by quoting, which is"
Say  "  what broke v1. The expectation is unchanged and is checked after the run: 'No migrations specified'."
$migrationDefault = (Select-String -LiteralPath $updaterPath -Pattern 'MigrationList\s*=\s*""' -SimpleMatch:$false | Select-Object -First 1)
if ($migrationDefault) { Say ("  proof from the shipped installer, line " + $migrationDefault.LineNumber + " : " + $migrationDefault.Line.Trim()) }
else { Say "  *** the default could not be found in the shipped installer - STOP, do not assume it"; Finish $false }
Rule

Say "PASSWORD"
$securePassword = Read-Host -Prompt 'Password for ccdashboard_user@127.0.0.1:5433/rtmviewdb' -AsSecureString
$plainPassword = $null
if ($securePassword -and $securePassword.Length -gt 0) {
  $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
  try { $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer) }
  Say ("  supplied, " + $plainPassword.Length + " characters (NOT printed, NOT in this report)")
} else { Say "  nothing supplied - STOP before the install"; Finish $false }
Rule

Say "THE INSTALL - this is the moment the server changes"
Say  "  TWO SERVICES GO DOWN AND COME BACK: the updater stops and starts BOTH the engine and the adapter,"
Say  "  regardless of any -Skip flag (runbook 3.2). This is a two-service window, not a Shell-only one."
Say  "  The package carries Shell only; the updater will print a WARN about RTM and leave those binaries alone."
Say  "  Update-RTMView.ps1 -DBPort 5433 -SkipDrift -SkipCacheMigration -KeepBackups 50 -DBPassword <hidden>"
Say  "  -ForceDeploy is deliberately NOT passed; -MigrationList is deliberately left at its empty default."
Write-Report
$installStart = Get-Date
$installerOutput = & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $updaterPath -DBPort 5433 -SkipDrift -SkipCacheMigration -KeepBackups 50 -DBPassword $plainPassword 2>&1
$installerExit = $LASTEXITCODE
$plainPassword = $null
$outputLines = @($installerOutput | ForEach-Object { "$_" })
foreach ($outputLine in $outputLines) { Say ("  | " + $outputLine) }
Say ("  installer exit code : " + $installerExit)
Say ("  elapsed : " + [math]::Round(((Get-Date) - $installStart).TotalSeconds, 1) + " s")
Write-Report
Rule

Say "ASSERTIONS ON THE INSTALLER'S OWN WORDS (counted occurrences, not a glance)"
$joinedOutput = ($outputLines -join "`n")
$countMigrations = ([regex]::Matches($joinedOutput, [regex]::Escape('No migrations specified'))).Count
$countSkipped    = ([regex]::Matches($joinedOutput, [regex]::Escape('Drift gate SKIPPED'))).Count
$countSkipFlag   = ([regex]::Matches($joinedOutput, [regex]::Escape('-SkipDrift'))).Count
$countForce      = ([regex]::Matches($joinedOutput, [regex]::Escape('-ForceDeploy'))).Count
Say ("  'No migrations specified' : " + $countMigrations + "   (expected 1 - this flight changes no schema)")
Say ("  'Drift gate SKIPPED'      : " + $countSkipped + "   (expected 1)")
Say ("  '-SkipDrift' named there  : " + $countSkipFlag + "   (expected 1 or more - INST-14 prints the flag actually passed)")
Say ("  NEGCTL '-ForceDeploy'     : " + $countForce + "   (must be 0 - it was not passed)")
$assertionsOk = (($countMigrations -eq 1) -and ($countSkipped -eq 1) -and ($countSkipFlag -ge 1) -and ($countForce -eq 0))
Say ("  ASSERTIONS : " + $(if ($assertionsOk) { 'GREEN' } else { 'RED - report it, do not re-run the installer' }))
Rule

Say "POST-STATE, a first glance only. STEP 3 IS THE ACCEPTANCE, NOT THIS."
Say  "  RTMTwilio_1 BELOW IS READ INSIDE THE RAISE WINDOW. The engine raises the adapter itself and took"
Say  "  16 s to do it this morning; whatever state prints here is a snapshot, not a verdict, and this run"
Say  "  never starts the adapter by hand. Three samples 20 s apart follow so the line has a shape."
foreach ($serviceName in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $service = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $serviceName) -ErrorAction SilentlyContinue
  Say ("  {0,-14} {1}   (was {2})" -f $serviceName, $(if ($null -eq $service) { 'ABSENT' } else { $service.State }), $serviceStateBefore[$serviceName])
}
for ($sample = 1; $sample -le 3; $sample++) {
  $adapter = Get-CimInstance Win32_Service -Filter "Name='RTMTwilio_1'" -ErrorAction SilentlyContinue
  Say ("    RTMTwilio_1 sample " + $sample + " at +" + (20 * ($sample - 1)) + " s : " + $(if ($null -eq $adapter) { 'ABSENT' } else { $adapter.State }))
  if ($sample -lt 3) { Start-Sleep -Seconds 20 }
}
Say  "    Still Stopped at the third sample is a finding for the coordinator - not a reason to start it."
$backupCountAfter = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue).Count
Say ("  backup directories : " + $backupCountBefore + " -> " + $backupCountAfter + "   (no new one means the installer never reached its backup step)")
$webDllAfter = Get-Sha256Of 'C:\RTMView\Shell\CcDashboard.Web.dll'
$dataSysAfter = Get-Sha256Of 'C:\RTMView\RTM\data.sys'
Say ("  Shell\CcDashboard.Web.dll AFTER : " + $webDllAfter)
Say ("      expected from the package   : " + $PinnedWebDll + "   match: " + ($webDllAfter -eq $PinnedWebDll))
Say ("  RTM\data.sys              AFTER : " + $dataSysAfter)
Say ("      expected UNCHANGED from the BEFORE this run took : " + $dataSysBefore + "   match: " + ($dataSysAfter -eq $dataSysBefore))
Say ("      cross-check, carried from 2026-09-20 11:29        : " + $CarriedDataSys + "   same: " + ($dataSysAfter -eq $CarriedDataSys))
Say  "      The verdict stands on the first line. The second only says whether the licence file has"
Say  "      changed since this morning by some other hand - a finding to report, not a failure of this run."
Say  "      data.sys must be untouched: this package carries no RTM folder at all, so nothing could overwrite it."
$shellCfgAfter = Get-Sha256Of 'C:\RTMView\Shell\appsettings.json'
$log4netAfter  = Get-Sha256Of 'C:\RTMView\RTM.Twilio\log4net.config'
Say ("  Shell\appsettings.json    AFTER : " + $shellCfgAfter + "   unchanged: " + ($shellCfgAfter -eq $shellCfgBefore))
Say ("  RTM.Twilio\log4net.config AFTER : " + $log4netAfter  + "   unchanged: " + ($log4netAfter  -eq $log4netBefore))
$configPreserved = (($shellCfgAfter -eq $shellCfgBefore) -and ($log4netAfter -eq $log4netBefore))
if (-not $configPreserved) { Say "  *** MACHINE CONFIG CHANGED - stop and report to the coordinator, even if everything else is green" }
$legacyAfter = (Get-CimInstance Win32_Service -Filter "Name='RTM'" -ErrorAction SilentlyContinue)
$legacyStateAfter = $(if ($null -eq $legacyAfter) { 'ABSENT' } else { $legacyAfter.State })
Say ("  legacy service RTM        AFTER : " + $legacyStateAfter + "   (was " + $legacyStateBefore + ") - we never touch it; printed so a change of someone else is not read as ours")
Say ""
Say  "  SATELLITES - the acceptance of this flight, compared TWICE: against the before measured on"
Say  "  this machine at 11:26, and against what the package carries."
$satellitesOk = $true
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satellitePath = 'C:\RTMView\Shell\' + $culture + '\CcDashboard.Web.resources.dll'
  $beforeSize  = $SatelliteBeforeBytes[$culture]
  $packageSize = $SatellitePackageBytes[$culture]
  if (-not (Test-Path -LiteralPath $satellitePath)) { Say ("    " + $culture.PadRight(6) + " ABSENT after the install - RED") ; $satellitesOk = $false ; continue }
  $actualSize = (Get-Item -LiteralPath $satellitePath).Length
  $movedFromBefore = ($actualSize -ne $beforeSize)
  $matchesPackage  = ($actualSize -eq $packageSize)
  if (-not ($movedFromBefore -and $matchesPackage)) { $satellitesOk = $false }
  Say ("    " + $culture.PadRight(6) + " before " + $beforeSize + " -> after " + $actualSize + "   package " + $packageSize)
  Say ("    " + '      ' + " moved: " + $movedFromBefore + "   equals package: " + $matchesPackage)
}
Say ("  SATELLITES : " + $(if ($satellitesOk) { 'GREEN - all three moved and equal the package' } else { 'RED - report, do not roll back on your own' }))
Rule

Say "LEDGER - the build-to-commit link, because our installer writes no manifest of its own"
$ledgerPath = Join-Path $AppliedDir '_ledger.txt'
$manifestLine = ('{0} | MANIFEST | commit={1} package={2} package_sha256={3} web.dll_sha256={4} installer_exit={5} by=devops-0919' -f (Get-Date -Format u), $PinnedCommit, (Split-Path -Leaf $PackagePath), $packageSha, $webDllAfter, $installerExit)
try {
  Add-Content -LiteralPath $ledgerPath -Value $manifestLine -Encoding UTF8 -ErrorAction Stop
  Say ("  written to " + $ledgerPath)
  Say ("  " + $manifestLine)
  Say ("  ledger now has " + (@(Get-Content -LiteralPath $ledgerPath)).Count + " lines")
} catch { Say ("  *** could not write the ledger: " + $_.Exception.Message) }
Rule

Say "VERDICT OF THE INSTALL (acceptance of the product is the next, reading step)"
Say ("  installer exit : " + $installerExit)
Say ("  assertions     : " + $assertionsOk)
Say ("  staging kept at: " + $stagingDir + "   (step 3 reads Compare-ToBaseline from here; delete after step 4)")
$stepOk = (($installerExit -eq 0) -and $assertionsOk -and $configPreserved -and $satellitesOk)
Say ("  machine config preserved : " + $configPreserved)
Say ("  satellites by size       : " + $satellitesOk)
Say ("  legacy RTM " + $legacyStateBefore + " -> " + $legacyStateAfter + " (not ours either way)")
Say ("  STEP 2 : " + $(if ($stepOk) { 'DONE - go to step 3, which decides whether this flight is accepted' } else { 'PROBLEM - stop and report; the rollback block is at the top of this report' }))
Say "===== END-OF-RUN MARKER: INSTALL-251CA40-COMPLETE ====="
Finish $stepOk
