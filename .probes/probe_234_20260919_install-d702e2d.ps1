<#
  PROBE  probe_234_20260919_install-d702e2d.ps1
  BASED  ON probe_234_20260919_install-934a1c5.ps1 - the run that installed 934a1c5 earlier today and
         went through without a surprise. Shape kept; only the pins, the rollback FLOOR and the
         satellite EXPECTATION change.
  UNIT   second Shell package - install 19092026.1544_Shell.zip, built from d702e2d.
  WHAT   The delta to what runs here is FOUR product files: App.razor, the two grid widgets and
         wwwroot/js/app.js - the filter popup fit. NO .resx in this delta, so the three language
         satellites MUST NOT move. A moved satellite here is a finding, not a detail.
  OUTAGE THIS IS A TWO-SERVICE OUTAGE. The updater stops and starts BOTH the engine and the adapter
         regardless of -Skip flags. The operator is told this in plain words before he runs it.
  ADAPTER The engine raises RTMTwilio_1 itself, and it took 16 s this morning (234-lab.md section 2).
         A snapshot taken right after the installer exits is NOT a verdict, and is labelled as such.
  PASSWORD Asked with Read-Host -AsSecureString. Never printed, never written to the report.
  WHERE  SERVER 234. THIS RUN WRITES: it installs. Everything before the install is read-only, and any
         gate that fails stops the run BEFORE the first write.
#>

param(
  [string]$PackagePath = 'C:\RTMView-Ops\incoming\19092026.1544_Shell.zip'
)

$ErrorActionPreference = 'Continue'
$PinnedZipSha  = 'A40603C2C94485185AACE346E4514F922900464345F0FC81D75105B0437D7AA9'
$PinnedWebDll  = '2D342BE2E2A6BBCF7BE0DA0CA1D65237122AC5D3DC61858CABBBC5EBF395D531'
$PinnedDataSys = '24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43'
$PinnedCommit  = 'd702e2d'
# the floor we fall back to: the package this machine runs today, and the proof it is physically here
$RollbackZip    = 'C:\RTMView-Ops\incoming\19092026.1236_Shell.zip'
$RollbackZipSha = 'C3DEAEFF8A2158B3AA7FA457B3401F678F746071AA8C3A8E5382EDC575087BB0'
$RollbackWebDll = '639D048A7EC65C31555EB1F414FF899A1719AC9DC43DEC932DD02E9F9D75A157'
# what the acceptance stands on: the sizes running here now AND the sizes measured inside this
# package at 15:45. EXPECTATION, stated before the run: all three UNCHANGED - no .resx in the delta.
$SatelliteExpect = @{
  'he-IL' = 73728
  'ru-RU' = 83968
  'en-US' = 67584
}
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
$AppliedDir = 'C:\RTMView-Ops\applied'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $AppliedDir | Out-Null
$ReportPath = Join-Path $OutputDir ("234_{0}_install-d702e2d.txt" -f $RunStamp)
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
Say ("  RTM\data.sys              BEFORE : " + (Get-Sha256Of 'C:\RTMView\RTM\data.sys'))
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
Say "  GATE GREEN - the bytes on this server are the bytes built from d702e2d"
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
Say  "  expected (v1 measured it from this same package) : EB1142FA2A6D204855A5F70E84307DF04B6A15981DE7998ABB9D5444A1B74A0D"
Say ("  package Shell\CcDashboard.Web.dll sha256 : " + (Get-Sha256Of (Join-Path $stagingDir 'Shell\CcDashboard.Web.dll')))
Rule

Say "MIGRATIONS - why the parameter is absent from the command below"
Say  "  The plan requires an EMPTY migration list. The installer declares [string]$MigrationList = \"\" as its"
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
Say ("      expected UNCHANGED          : " + $PinnedDataSys + "   match: " + ($dataSysAfter -eq $PinnedDataSys))
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
Say "  SATELLITES - the acceptance of the translations, by SIZE. Byte equality between different builds"
Say "  is not used anywhere: a .NET assembly carries a fresh MVID and timestamp on every build."
$satellitesOk = $true
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satellitePath = 'C:\RTMView\Shell\' + $culture + '\CcDashboard.Web.resources.dll'
  $expectSize = $SatelliteExpect[$culture]
  if (-not (Test-Path -LiteralPath $satellitePath)) { Say ("    " + $culture.PadRight(6) + " ABSENT after the install - RED") ; $satellitesOk = $false ; continue }
  $actualSize = (Get-Item -LiteralPath $satellitePath).Length
  $sizeMatches = ($actualSize -eq $expectSize)
  if (-not $sizeMatches) { $satellitesOk = $false }
  Say ("    " + $culture.PadRight(6) + " before " + $satelliteBefore[$culture] + " B -> after " + $actualSize + " B   expected " + $expectSize + " B   match " + $sizeMatches)
}
Say ("  SATELLITES : " + $(if ($satellitesOk) { 'GREEN - all three sizes are what the package carried' } else { 'RED - report, do not roll back on your own' }))
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
Say "===== END-OF-RUN MARKER: INSTALL-D702E2D-COMPLETE ====="
Finish $stepOk
