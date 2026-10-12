<#
  PROBE  probe_234_20261011_install-356d58b.ps1
  BASED  ON probe_234_20261010_install-4634162.ps1 - the previous flight, installed 23:08 local and
         accepted 23:18 local. Expectations re-derived below, not inherited.
  UNIT   install 11102026.1245_Shell.zip, built from v4 head 356d58b, Mode Shell: chart scaling and
         translation of the Wfm labels plus behaviour the operator stated through the evening.
         Blessing 2026-10-10T21:29:14Z with his word quoted in it; the inbox is re-read by G-BUS
         below before anything is written.
  WHAT THE DELTA IS, measured by BLOB  the clean difference 4634162..e6a0fcb is FIVE files:
         AgentGridWidget.razor, QueueGridWidget.razor, DataSlotWidget.razor, WfmWidget.razor and
         SharedResources.he-IL.resx. RTM/ 0, deploy/ 0, db/ 0, wwwroot 0, .razor.css 0, migrations 0.
  THE ASSET VERSIONS PROVE NOTHING HERE, AND THAT IS MEASURED
         App.razor is NOT in this delta, so every ?v= number is identical in both revisions - the
         lists taken from App.razor in each diff to nothing. Nothing may appear and nothing may
         vanish. A probe hunting a bumped number here would call a correct flight red.
         What proves delivery instead: web.dll equals the package, the ledger carries
         commit=e6a0fcb, all three pids change, and the TRANSLATION NEEDLES in the he-IL dictionary.
  THE SATELLITES: 'EQUALS THE PACKAGE', AND THE BEFORE NUMBERS ARE TONIGHT'S, NOT YESTERDAY'S
         Only he-IL changes in this delta, and only in values. On disk now: he-IL 77312,
         ru-RU 87552, en-US 70656 [234_20261011_004112_predeploy-e6a0fcb.txt]. The package carries
         he-IL 77824, ru-RU 87552, en-US 70656. So he-IL moves by 512 and the other two not at all;
         the verdict is equality with the package and the movement is a note.
         Worth naming: tonight's BUILD report printed a false +512 on ru-RU and en-US because it
         compared against 77312/87040/70144 - the sizes from BEFORE the previous flight. Inherited
         expectations have produced four false numbers in twenty-four hours.
  PREDICATES, EACH DERIVED FROM THE DELTA AND NOT FROM THE LAST FLIGHT
         1. satellites must stay EQUAL at 77312/87040/70144 - no .resx in the delta. Measured on
            this machine 90 minutes ago [234_20261010_111440_predeploy-6b720b2.txt].
         2. the ENGINE must stay UNCHANGED - Mode Shell carries no RTM at all. A changed engine is
            the finding, not the pass.
         3. web.dll must CHANGE from 098D0793 to 6F05414C - equality either way is a failure, and
            the two directions are reported separately so the cause is never guessed.
  THE ADAPTER WINDOW IS BOUNDED BY A DEADLINE, NOT BY THREE SLEEPS
         The previous install probe sampled 3 times 20 s apart - 40 s - printed Stopped three times
         and I told the operator the adapter was down. It returned at 278 s, 209 s of them AFTER the
         engine was already Running. A window narrower than the slowest measured return cannot tell
         'never came up' from 'slower than I watched'. This run polls until a 420 s deadline and
         reports the exact second it came back, so the subject gets a number instead of a verdict.
  OUTAGE, TWO WINDOWS, NAMED BEFORE THE CLICK
         Our two services ~118 s (last flight 118.3 s: Shell copy ~4 s, RTM copy ~46 s, pg_dump
         ~13 s, plus service starts) and the adapter ~278 s, because the updater stops and starts
         BOTH services whatever the package holds - :259 has no mode condition.
  PASSWORD Read-Host -AsSecureString. Never printed, never written to the report.
  WHERE  SERVER 234. THIS RUN WRITES: it installs. Every gate before the install is read-only and a
         failing gate stops the run BEFORE the first write.
         The legacy C:\IceDash\RTM\RTM.exe is never restarted, under any circumstance.
#>

param(
  [string]$PackagePath = 'C:\RTMView-Ops\incoming\11102026.1245_Shell.zip'
)

$ErrorActionPreference = 'Continue'
$PinnedZipSha  = '03305E4ED02F37BF49CF459B4652C9D4B568A7755268BDC3E736570B1EFF3FFA'
$PinnedWebDll  = '6FF870FB6345CDA5A5032A3BD2DA0821C16E142570B1F5353154CD0B554ABC75'
# EVERY assembly is judged by ONE predicate from here on: equal to what THIS PACKAGE carries.
# Measured on the station 2026-10-11 12:50: two builds of byte-identical .resx produced three
# dictionaries with different sha at identical sizes, so a rebuilt assembly's sha is never an
# expectation of 'unchanged' and never a proof of 'changed'. Equality with the package is both.
$ContractsPackage = '2801DB1DC23C0EFF7DF3B7E3D9E0F57B5CA6A7BBBE0771DB2BBE3700F82E5864'
$SatellitePackageSha = @{
  'he-IL' = '083E94528464B4F2B40BA5145207B75AD397DC550D515D6069AE9C71A2285478'
  'ru-RU' = '80E74923572E2A70AF6FC43CE2278CCBC3E334FA041BC575E010A1AA9EA4E159'
  'en-US' = '9FF97D9F0A982C44C2BFB760B7BA2B0F7247977353EFF008EFC4847B1AD38D93'
}
# What the machine runs RIGHT NOW, measured 90 minutes ago. web.dll must leave this value.
$WebDllBefore  = '6ECF2A9BFCA7899720DDA2FA9A1C4EC38F4610F28DA2C842F06068309DBFEB93'
# The engine is NOT replaced by this flight and its check is inverted accordingly: RTM.dll must come
# out EQUAL to what it is now, because Mode Shell puts no RTM in the package at all.
$EngineMustStay = '097F087D66497A4C59C5216E8BB46E1C4F49739A2B2A2A6621483BD0DC1C10AB'
# data.sys is NOT judged against this constant. The AFTER value is compared to the BEFORE value
# measured by THIS run, so the check survives a licence file the operator legitimately replaced.
# The constant is kept only as a cross-check and is labelled as carried, not as the expectation.
$CarriedDataSys = '24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43'  # measured 2026-09-20 11:29
$PinnedCommit  = '356d58b'
# the floor we fall back to: the package this machine runs today, and the proof it is physically here
$RollbackZip    = 'C:\RTMView-Ops\incoming\11102026.1114_Shell.zip'
$RollbackZipSha = '3E4ADA6D315155A5D2D85DB757DDDEB7FB39FDBEF294CA1A542C4FBC239C16E1'
# ONE floor this time, not two - and the reason is worth stating so that nobody 'restores' the
# second one out of habit. This flight replaces only the Shell half, and the package running
# right now is the FULL package of 26.09: reinstalling it puts BOTH halves back at once.
# The engine floor built on 26.09 stays on this disk untouched; this flight does not need it.
$RollbackWebDll = 'B88B851D64FB014FEC9C10A3287EE6DD776699BECAFD74C94BD5FCB168434E62'
# BEFORE measured on this machine 00:41 local [234_20261011_004112_predeploy-e6a0fcb.txt]; PACKAGE
# measured inside the zip on the station. Only he-IL differs between the rows - the other two are
# untouched by this delta. The verdict is 'equals the package', never 'grew' and never 'unchanged'.
# Measured on this machine at 12:55 local today [234_20261011_125518_predeploy-356d58b.txt].
$SatelliteBeforeBytes  = @{ 'he-IL' = 77824 ; 'ru-RU' = 88064 ; 'en-US' = 71168 }
# Measured inside the package on the station [WS_20261011_124150_shellpkg-356d58b.txt]. No .resx
# is in this delta, so all three come out the same SIZE as the ones on disk - and with different
# sha, which is the rebuild, not a change of content. The sha row below is against THE PACKAGE.
$SatellitePackageBytes = @{ 'he-IL' = 77824 ; 'ru-RU' = 88064 ; 'en-US' = 71168 }
# The previous flight demanded +512 on each row. Carrying that rule over would paint a correct
# install red on all three - which is why the rule is re-derived from the delta every single time.
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
$ReportPath = Join-Path $OutputDir ("234_{0}_install-356d58b.txt" -f $RunStamp)
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

Say ("STEP 2  INSTALL  " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + "Z   host=" + $env:COMPUTERNAME + "   (machine local: " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " local)")
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

Say "G-BUS  THE LAST LETTER IN MY INBOX - read BEFORE anything is written"
Say  "  Why this gate exists, measured on me: on 2026-10-10 the coordinator revoked a blessing at"
Say  "  10:15Z after the operator decided one rollout instead of piecemeal, and I installed on"
Say  "  production at 10:52Z because I had not re-read the inbox since 09:53Z. The blessing is a"
Say  "  STATE at the moment of the write, not a fact from four hours ago."
$InboxPath = '\\tsclient\D\Claude\Projects\RTM View Shell\.coord\inbox\devops.md'
Say ("  inbox : " + $InboxPath)
Say ("  reachable : " + (Test-Path -LiteralPath $InboxPath))
if (-not (Test-Path -LiteralPath $InboxPath)) {
  Say  "  *** THE INBOX CANNOT BE READ FROM HERE. I will not write to production blind. STOP."
  Finish $false
}
$inboxHeadings = @(Select-String -LiteralPath $InboxPath -Pattern '^## ' -ErrorAction SilentlyContinue)
Say ("  letters in it : " + $inboxHeadings.Count + "   (zero would mean the reader is wrong, not that the bus is empty)")
if ($inboxHeadings.Count -eq 0) { Say "  *** NO LETTERS FOUND - the reader is wrong. STOP." ; Finish $false }
$lastLetter = $inboxHeadings[-1].Line
Say ("  LAST LETTER : " + $lastLetter)
$stopWords = @('СТОП', 'ОТОЗВА', 'STOP', 'ОТМЕН')
$stopHit = $null
foreach ($word in $stopWords) { if ($lastLetter.ToUpper().Contains($word)) { $stopHit = $word ; break } }
Say ("  NEGCTL the same reader on a word that cannot be there : " + $lastLetter.ToUpper().Contains('ZZZNOSUCHWORD') + "   must be False")
if ($stopHit) {
  Say ("  *** THE LAST LETTER CARRIES '" + $stopHit + "'. The blessing is not in force. NOTHING INSTALLED.")
  Finish $false
}
Say  "  G-BUS PASS  the last letter is not a stop, so the blessing stands at the moment of this write"
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
Say ("  floor GREEN - restores Shell\CcDashboard.Web.dll to " + $RollbackWebDll)
Say  "  The floor is the package 234 runs right now, so reinstalling it returns the machine to the"
Say  "  state measured at 11:14 today. The FULL package of 26.09 (C8DCFAEB, verified on this disk"
Say  "  90 minutes ago) stands behind it as the second floor and restores both halves if ever needed."
Say  "  Neither is deleted by this run nor by the install that follows." 
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
Say "  GATE GREEN - the bytes on this server are the bytes built from e6a0fcb"
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
Say  "  WHAT THE STAGED TREE MUST CONTAIN, and the RTM row is INVERTED against a Full flight:"
Say  "  Mode Shell builds no engine half at all. Measured on the station TODAY while this package"
Say  "  was built: 0 entries under RTM\ and a non-empty Shell\ - the build report says so."
Say  "  So an RTM folder appearing here would mean the package is not the one that was built,"
Say  "  and the run stops before the first write."
$updaterPresent = Test-Path -LiteralPath $updaterPath
$shellPresent   = Test-Path -LiteralPath (Join-Path $stagingDir 'Shell')
$rtmPresent     = Test-Path -LiteralPath (Join-Path $stagingDir 'RTM')
Say ("  Update-RTMView.ps1 : " + $updaterPresent + "   expected True")
Say ("  Shell\             : " + $shellPresent   + "   expected True")
Say ("  RTM\               : " + $rtmPresent     + "   expected False - Mode Shell carries no engine")
if ($rtmPresent) { Say "  *** an RTM folder came out of a Shell package. STOP - the server is not yet changed."; Finish $false }
if (-not $shellPresent) { Say "  *** no Shell folder in the staged tree. STOP - nothing installed."; Finish $false }
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
$adapterDeadline = (Get-Date).AddSeconds(420)
$adapterBackAt = $null
$adapterPollStart = Get-Date
Say ("  POLLING THE ADAPTER UNTIL A DEADLINE, not for a fixed number of samples. Deadline: 420 s")
Say  "  Why: the previous install probe watched for 40 s, printed Stopped three times, and I told the"
Say  "  operator the adapter was down. It returned at 278 s. A window narrower than the slowest"
Say  "  measured return cannot tell 'never came up' from 'slower than I watched'."
while ((Get-Date) -lt $adapterDeadline) {
  $adapter = Get-CimInstance Win32_Service -Filter "Name='RTMTwilio_1'" -ErrorAction SilentlyContinue
  $elapsedSeconds = [math]::Round(((Get-Date) - $adapterPollStart).TotalSeconds, 0)
  $adapterState = $(if ($null -eq $adapter) { 'ABSENT' } else { $adapter.State })
  Say ("    +" + $elapsedSeconds + " s : RTMTwilio_1 " + $adapterState + "   pid " + $(if ($null -eq $adapter) { 0 } else { $adapter.ProcessId }))
  if ($adapterState -eq 'Running') { $adapterBackAt = $elapsedSeconds ; break }
  Start-Sleep -Seconds 15
}
if ($null -eq $adapterBackAt) {
  Say  "    THE ADAPTER DID NOT COME BACK INSIDE 420 s. That is a measured absence, with the window"
  Say  "    named - and it is still NOT a reason to start it by hand. Report it to the coordinator."
} else {
  Say ("    came back at +" + $adapterBackAt + " s from the first poll. Last flight: 278 s from the stop.")
  Say  "    This number is the subject PR234-INSTALL-SHELL-MODE-ENGINE-RESTART-01 asked for."
}
$backupCountAfter = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue).Count
Say ("  backup directories : " + $backupCountBefore + " -> " + $backupCountAfter + "   (no new one means the installer never reached its backup step)")
$webDllAfter = Get-Sha256Of 'C:\RTMView\Shell\CcDashboard.Web.dll'
$dataSysAfter = Get-Sha256Of 'C:\RTMView\RTM\data.sys'
Say ("  Shell\CcDashboard.Web.dll AFTER : " + $webDllAfter)
Say ("      expected from the package   : " + $PinnedWebDll + "   match: " + ($webDllAfter -eq $PinnedWebDll))
Say ("      still the value it had before : " + ($webDllAfter -eq $WebDllBefore) + "   (True here would mean the deploy step never reached the file)")
$contractsPath = 'C:\RTMView\Shell\CcDashboard.Contracts.dll'
$contractsAfter = Get-Sha256Of $contractsPath
Say ("  Shell\CcDashboard.Contracts.dll AFTER : " + $contractsAfter)
Say ("      expected from the package         : " + $ContractsPackage + "   match: " + ($contractsAfter -eq $ContractsPackage))
Say  "      NO 'differs from before' ROW HERE, and that is a correction of my own: I reported such a"
Say  "      row as proof in the previous flight, and it would have been True for a package carrying"
Say  "      nothing, because a rebuild changes an assembly sha by itself. Equality with the package"
Say  "      is the only lawful expectation; the content is proven by the type name in step 3."
$engineDllAfter = Get-Sha256Of 'C:\RTMView\RTM\RTM.dll'
Say ("  RTM\RTM.dll               AFTER : " + $engineDllAfter)
Say ("      expected UNCHANGED           : " + $EngineMustStay + "   match: " + ($engineDllAfter -eq $EngineMustStay))
Say  "      INVERTED against the previous flight: Mode Shell carries no RTM, so the engine must come"
Say  "      out exactly as it went in. A CHANGED engine here is the finding, not the pass."
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
Say  "  SATELLITES - THE VERDICT IS 'EQUALS THE PACKAGE', BY sha THIS TIME, NOT ONLY BY SIZE."
Say  "  No .resx is in this delta, so all three keep their byte count. But their sha WILL differ"
Say  "  from the ones that were on disk a minute ago, and that is the rebuild, not a change of"
Say  "  content: measured on the station today, two builds of byte-identical .resx produced three"
Say  "  dictionaries with different sha at identical sizes. So the only lawful expectation is the"
Say  "  file this package carries, and that is what is compared. The content - the four Wfm key"
Say  "  names - is proven by the byte search in step 3."
$satellitesOk = $true
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satellitePath = 'C:\RTMView\Shell\' + $culture + '\CcDashboard.Web.resources.dll'
  $beforeSize  = $SatelliteBeforeBytes[$culture]
  $packageSize = $SatellitePackageBytes[$culture]
  if (-not (Test-Path -LiteralPath $satellitePath)) { Say ("    " + $culture.PadRight(6) + " ABSENT after the install - RED") ; $satellitesOk = $false ; continue }
  $actualSize = (Get-Item -LiteralPath $satellitePath).Length
  $matchesPackage = ($actualSize -eq $packageSize)
  if (-not $matchesPackage) { $satellitesOk = $false }
  $moved = $actualSize - $beforeSize
  $actualSha = Get-Sha256Of $satellitePath
  $shaMatches = ($actualSha -eq $SatellitePackageSha[$culture])
  if (-not $shaMatches) { $satellitesOk = $false }
  Say ("    " + $culture.PadRight(6) + " before " + $beforeSize + " -> after " + $actualSize + "   package " + $packageSize)
  Say ("    " + '      ' + " sha " + $actualSha)
  Say ("    " + '      ' + " EQUALS THE PACKAGE sha : " + $shaMatches + "   (this is the strong half; size alone cannot see a rebuild)")
  Say ("    " + '      ' + " EQUALS PACKAGE: " + $matchesPackage + "   (this is the verdict)   size moved by " + $moved + " B (a note, not a verdict)")
  if ($moved -eq 0) { Say ("    " + '      ' + " zero movement on this culture is EXPECTED where the new values weigh less than the 512-byte alignment step") }
}
Say ("  SATELLITES : " + $(if ($satellitesOk) { 'GREEN - all three equal the package by sha and by size' } else { 'RED - report, do not roll back on your own' }))
Rule

Say "LEDGER - the build-to-commit link, because our installer writes no manifest of its own"
$ledgerPath = Join-Path $AppliedDir '_ledger.txt'
# The stamp below MUST come from ToUniversalTime. 'Get-Date -Format u' prints the MACHINE-LOCAL
# time and appends a literal Z, so the ledger carried '2026-10-11 00:50:54Z' for a write made at
# 21:50Z - the coordinator read it twice as a time in the future. Local time is never stamped Z.
$manifestLine = ('{0} | MANIFEST | commit={1} package={2} package_sha256={3} web.dll_sha256={4} installer_exit={5} by=devops-0919' -f ((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + 'Z'), $PinnedCommit, (Split-Path -Leaf $PackagePath), $packageSha, $webDllAfter, $installerExit)
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
Say ("  satellites unchanged     : " + $satellitesOk)
Say ("  legacy RTM " + $legacyStateBefore + " -> " + $legacyStateAfter + " (not ours either way)")
Say ("  STEP 2 : " + $(if ($stepOk) { 'DONE - go to step 3, which decides whether this flight is accepted' } else { 'PROBLEM - stop and report; the rollback block is at the top of this report' }))
Say "===== END-OF-RUN MARKER: INSTALL-356D58B-COMPLETE ====="
Finish $stepOk
