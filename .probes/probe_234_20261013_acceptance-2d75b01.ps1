<#
  PROBE  probe_234_20261013_acceptance-2d75b01.ps1
  ON THE CORE. Every generic helper comes from .probes/_core.ps1, self-tested by Start-Probe before
  this file measures anything.
  STEP 3. READ-ONLY: nothing is installed, started, stopped or configured.
  UNIT   flight 2d75b01 (Wfm font sizes reach the widget), installed 2026-10-13 15:40-15:43 local,
         installer exit 0 [234_20261013_154037_install-2d75b01.txt]. Staging kept by that run at
         C:\RTMView-Ops\incoming\pkg_2d75b01_20261013_154037 - the package side is READ FROM THERE,
         so nothing is carried by hand.
  WHAT THIS STEP CAN AND CANNOT DECIDE - said first, because it is the whole shape of this flight
         The edit assigns four config properties that already existed. It adds no string to any
         served file, so THERE IS NO BYTE NEEDLE and no row here can say "the new code is in". What
         the files CAN prove: the bytes the shell serves are the bytes of the package whose sha the
         ledger records against commit 2d75b01, nothing that had to stay still has moved, and the
         services were actually restarted. The remaining half - that the four font sizes now reach
         the widget - is BEHAVIOURAL and is measured in the viewer, not here. This probe therefore
         ends with a FILE VERDICT and names the behavioural half as outstanding rather than
         quietly counting itself as the whole acceptance.
  EVERY ROW IS A MUST-STAY ROW except the three pids and the ledger line. The nine asset versions
         must read exactly what the blessing names, the bundle must equal what was handed out
         before the install, and the dictionaries must equal the package. A number that moved here
         is the finding.
  THE PIDS ARE THE ONE "MUST-CHANGE" HALF: before the install they were RTMViewShell 11604,
         RTMService 8848, RTMTwilio_1 12080 [234_20261013_140754_predeploy-2d75b01.txt]. A pid that
         did NOT change means the process was never restarted and is still running the old
         assemblies, whatever the files on disk say.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$STAGING   = 'C:\RTMView-Ops\incoming\pkg_2d75b01_20261013_154037'
$SHELL_DIR = 'C:\RTMView\Shell'
$LEDGER    = 'C:\RTMView-Ops\applied\_ledger.txt'
$PKG_SHA   = '8E2652AE40C3F8B53635FCA8D9F480218D04DECF8573DC56D24FAE783D2ED0D6'
$BUNDLE_HANDED_OUT = 'D2F85CB1B8ADFFE53D5583342B0D17806AC1CB7537D6A2EC75DEDF9057D5972E'
$PIDS_BEFORE = @{ 'RTMViewShell' = 11604 ; 'RTMService' = 8848 ; 'RTMTwilio_1' = 12080 }

Start-Probe -Name 'acceptance-2d75b01' -Title 'STEP 3  ACCEPTANCE  flight 2d75b01 (Wfm font sizes)'
Say 'READ-ONLY. Nothing is installed, started, stopped or configured by this run.'
Rule
Assert-Machine

Say '1  THE STAGING THIS PROBE READS THE PACKAGE SIDE FROM'
Say ('  ' + $STAGING)
$stagingPresent = Test-Path -LiteralPath $STAGING
Say ('  expected : present, left by the install of 15:40')
Say ('  measured : ' + $stagingPresent)
if (-not $stagingPresent) {
  Say '  *** without it every "equals the package" row below would be comparing against nothing.'
  Say '  STOP: re-run after the install, or point this probe at the staging that install kept.'
  Finish $false
}
Rule

Say '2  THE LEDGER - the build-to-commit link, which for this flight IS the proof of version'
$ledgerLines = @(Get-Content -LiteralPath $LEDGER -ErrorAction SilentlyContinue)
Say ('  ledger lines : ' + $ledgerLines.Count + '   (zero would mean the reader is wrong, not that nothing was installed)')
$manifestLines = @($ledgerLines | Where-Object { $_ -match 'MANIFEST' })
$lastManifest = $(if ($manifestLines.Count -gt 0) { $manifestLines[-1] } else { '' })
Say ('  last MANIFEST : ' + $lastManifest)
$ledgerHasCommit = $lastManifest.Contains('commit=2d75b01')
$ledgerHasSha    = $lastManifest.Contains($PKG_SHA)
$ledgerHasExit   = $lastManifest.Contains('installer_exit=0')
Say ('  carries commit=2d75b01     : ' + $ledgerHasCommit)
Say ('  carries the package sha    : ' + $ledgerHasSha + '   (' + $PKG_SHA.Substring(0,16) + '...)')
Say ('  carries installer_exit=0   : ' + $ledgerHasExit)
$negLedger = $lastManifest.Contains('commit=f333db5')
Say ('  NEGCTL the PREVIOUS commit in the same line : ' + $negLedger + '   (must be False; a True would mean I am reading an older line)')
$ledgerOk = ($ledgerHasCommit -and $ledgerHasSha -and $ledgerHasExit -and (-not $negLedger))
Say ('  LEDGER : ' + $ledgerOk)
Rule

Say '3  THE SERVICES - the ONE must-change half of this acceptance'
$pidsOk = $true
foreach ($serviceName in @('RTMViewShell','RTMService','RTMTwilio_1')) {
  $serviceState = StateOf $serviceName
  $pidBefore = $PIDS_BEFORE[$serviceName]
  $changed = (($serviceState.ProcessId -ne 0) -and ($serviceState.ProcessId -ne $pidBefore))
  $running = ($serviceState.State -eq 'Running')
  Say ('  ' + $serviceName.PadRight(14) + ' state ' + ([string]$serviceState.State).PadRight(9) + ' pid before ' + ([string]$pidBefore).PadLeft(6) + ' -> now ' + ([string]$serviceState.ProcessId).PadLeft(6) + '   restarted: ' + $changed + '   running: ' + $running)
  if (-not ($changed -and $running)) { $pidsOk = $false }
}
Say  '  A pid that did not change means the process was never restarted and is still running the'
Say  '  previous assemblies, whatever the files say. That is why this row is here and not a note.'
Say ('  SERVICES : ' + $pidsOk)
Rule

Say '4  WHAT THE SHELL ACTUALLY SERVES - fetched over HTTP, not read off the disk'
Say  '  The disk was already compared with the staging by the install. This section asks the'
Say  '  different question: do the bytes that reach a browser equal the bytes of this package. The'
Say  '  nine assets and their versions are read out of the served page itself, not typed here.'
$curl = "$env:SystemRoot\System32\curl.exe"
$base = 'https://127.0.0.1:8444'
$html = ''
$fetchOk = $false
if (-not (Test-Path -LiteralPath $curl)) { Say '  *** curl.exe ABSENT - this section is NOT MEASURED' }
else {
  $httpCode = (& $curl -k -s -L -o NUL -w '%{http_code}' --max-time 20 ($base + '/')) 2>$null
  $html     = (& $curl -k -s -L --max-time 20 ($base + '/')) 2>$null
  $bodyChars = ('' + $html).Length
  Say ('  http code : ' + $httpCode + '   body chars : ' + $bodyChars)
  $fetchOk = ((("$httpCode") -eq '200') -and ($bodyChars -ge 2000))
  Say ('  fetch usable as evidence : ' + $fetchOk + '   (under 2000 chars is a redirect wrapper, not a page)')
  $negCode = (& $curl -k -s -o NUL -w '%{http_code}' --max-time 20 ($base + '/zzz-no-such-endpoint')) 2>$null
  Say ('  NEGCTL /zzz-no-such-endpoint -> ' + $negCode + '   (must be neither 200 nor 000)')
}
$blessedVersions = @{
  'app.css' = '36' ; 'CcDashboard.Web.styles.css' = '10' ; 'js/daytrendChart.js' = '14'
  'js/agentStateDistributionChart.js' = '16' ; 'js/reportDistributionChart.js' = '6'
  'js/widget-resize.js' = '3' ; 'css/tokens.css' = '3' ; 'css/widgets/wallboard-skin.css' = '3'
  'js/app.js' = '2'
}
$servedOk = $fetchOk
$assetRows = @()
if ($fetchOk) {
  foreach ($assetMatch in [regex]::Matches($html, '(?:href|src)="([^":]+?)\?v=(\d+)"')) {
    $assetRows += ,@($assetMatch.Groups[1].Value, $assetMatch.Groups[2].Value)
  }
  Say ('  assets declared in the served page : ' + $assetRows.Count + '   (expected 9)')
  if ($assetRows.Count -ne 9) { $servedOk = $false }
  foreach ($assetRow in $assetRows) {
    $assetPath = $assetRow[0]
    $assetVersion = $assetRow[1]
    if (-not $blessedVersions.ContainsKey($assetPath)) { Say ('    ' + $assetPath + ' v=' + $assetVersion + '   NOT IN THE BLESSED LIST <- finding') ; $servedOk = $false ; continue }
    $expectedVersion = $blessedVersions[$assetPath]
    $versionAgrees = ($expectedVersion -eq $assetVersion)
    $stagedCopy = Join-Path $STAGING ('Shell\wwwroot\' + ($assetPath -replace '/','\'))
    $stagedSha = ShaOf $stagedCopy
    $tempFile = Join-Path $env:TEMP ('acc_' + [Guid]::NewGuid().ToString('N') + '.bin')
    $servedSha = 'NOT-FETCHED'
    $servedBytes = 0
    & $curl -k -s --max-time 20 -o $tempFile ($base + '/' + $assetPath + '?v=' + $assetVersion) 2>$null | Out-Null
    if (Test-Path -LiteralPath $tempFile) {
      $servedSha = ShaOf $tempFile
      $servedBytes = (Get-Item -LiteralPath $tempFile).Length
      Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
    $bodyAgrees = (($stagedSha -ne 'ABSENT') -and ($servedSha -eq $stagedSha))
    Say ('    ' + $assetPath.PadRight(36) + ' v=' + $assetVersion.PadRight(3) + ' expected v=' + $expectedVersion.PadRight(3) + ' ' + $(if ($versionAgrees) { 'agrees ' } else { 'MOVED  ' }) + ' served ' + ([string]$servedBytes).PadLeft(7) + ' B  body == package: ' + $bodyAgrees)
    if (-not ($versionAgrees -and $bodyAgrees)) {
      Say ('        served  ' + $servedSha)
      Say ('        package ' + $stagedSha)
      $servedOk = $false
    }
  }
  $negAsset = ([regex]::Matches($html, 'zzz-no-such-asset\.css\?v=\d+')).Count
  Say ('  NEGCTL an asset that cannot be served : ' + $negAsset + ' hits (expected 0; the nine above prove the regex finds real ones)')
  if ($negAsset -ne 0) { $servedOk = $false }
}
Say ('  SERVED BODIES AND VERSIONS : ' + $servedOk)
Rule

Say '5  THE SCOPED BUNDLE, ON ITS OWN - the blessing stops the flight on it'
$bundleDiskSha = ShaOf (Join-Path $SHELL_DIR 'wwwroot\CcDashboard.Web.styles.css')
$bundleStagedSha = ShaOf (Join-Path $STAGING 'Shell\wwwroot\CcDashboard.Web.styles.css')
Say ('  expected : ' + $BUNDLE_HANDED_OUT + '   (handed out before the install)')
Say ('  on disk  : ' + $bundleDiskSha)
Say ('  package  : ' + $bundleStagedSha)
$bundleOk = (($bundleDiskSha -eq $BUNDLE_HANDED_OUT) -and ($bundleStagedSha -eq $BUNDLE_HANDED_OUT))
Say ('  BUNDLE : ' + $bundleOk + '   (False is a STOP and a letter to the coordinator, not a note)')
Rule

Say '6  THE ASSEMBLIES AND THE DICTIONARIES - equal to the package, read from the staging'
$assembliesOk = $true
foreach ($assemblyName in @('CcDashboard.Web.dll','CcDashboard.Contracts.dll')) {
  $diskSha = ShaOf (Join-Path $SHELL_DIR $assemblyName)
  $stagedSha = ShaOf (Join-Path $STAGING ('Shell\' + $assemblyName))
  $agrees = (($stagedSha -ne 'ABSENT') -and ($diskSha -eq $stagedSha))
  Say ('  ' + $assemblyName.PadRight(28) + ' disk ' + $diskSha.Substring(0,16) + '...  package ' + $stagedSha.Substring(0,16) + '...  equal: ' + $agrees)
  if (-not $agrees) { $assembliesOk = $false }
}
Say  '  Only equality with the package is asserted. A rebuilt assembly sha changes by itself - two'
Say  '  builds of this very package today gave web.dll at 1361408 B with different sha - so neither'
Say  '  "unchanged" nor "differs" against what the machine ran before is a lawful row.'
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $diskPath = Join-Path $SHELL_DIR ($culture + '\CcDashboard.Web.resources.dll')
  $stagedPath = Join-Path $STAGING ('Shell\' + $culture + '\CcDashboard.Web.resources.dll')
  $diskSha = ShaOf $diskPath
  $stagedSha = ShaOf $stagedPath
  $agrees = (($stagedSha -ne 'ABSENT') -and ($diskSha -eq $stagedSha))
  $diskSize = $(if (Test-Path -LiteralPath $diskPath) { (Get-Item -LiteralPath $diskPath).Length } else { 0 })
  Say ('  ' + $culture.PadRight(8) + ([string]$diskSize).PadLeft(7) + ' B   equal to the package: ' + $agrees)
  if (-not $agrees) { $assembliesOk = $false }
}
$negAssembly = ShaOf (Join-Path $SHELL_DIR 'CcDashboard.NoSuchAssembly.dll')
Say ('  NEGCTL an assembly that cannot be there : ' + $negAssembly + '   (must read ABSENT)')
if ($negAssembly -ne 'ABSENT') { $assembliesOk = $false }
Say ('  ASSEMBLIES AND DICTIONARIES : ' + $assembliesOk)
Rule

Say '7  WHAT THE BEHAVIOURAL HALF NEEDS - is there a Wfm widget to look at, and is anything set'
Say  '  The pre-deploy probe could not answer this: I pinned psql at version 16 and the machine has'
Say  '  18, so the section printed NOT MEASURED. The path is resolved by searching here instead of'
Say  '  being pinned, and the version found is printed.'
$psql = $null
foreach ($pgVersion in @('18','17','16','15','14')) {
  $candidate = 'C:\Program Files\PostgreSQL\' + $pgVersion + '\bin\psql.exe'
  if (Test-Path -LiteralPath $candidate) { $psql = $candidate ; Say ('  psql found : ' + $candidate) ; break }
}
$dbRead = $false
if ($null -eq $psql) { Say '  psql not found under any of 18/17/16/15/14 - this section is NOT MEASURED' }
else {
  $sqlDir = 'C:\RTMView-Ops\probes'
  $sqlPath = Join-Path $sqlDir 'acceptance_2d75b01_wfm.sql'
  # NO GUESSED KEY NAMES. My first version of this query tested for 'wfmTileTitleFontSize' with
  # jsonb ?, having never measured how the config is serialised: a wrong case would have returned
  # false on all four rows and painted a correct install red - the same class of fault as the nine
  # typed asset paths earlier today. So the query LISTS the keys the widget's config actually has,
  # and the probe then counts the ones whose name contains fontsize, case-insensitively.
  $sqlText = @(
    "SELECT s.id AS screen_id,",
    "       (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(w -> 'config') AS k) AS config_keys",
    "FROM screen s, jsonb_array_elements(s.layout::jsonb -> 'widgets') w",
    "WHERE w ->> 'type' = 'wfm';"
  ) -join "`r`n"
  [IO.File]::WriteAllText($sqlPath, $sqlText + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
  Say  '  the query, printed back FROM DISK so what ran is what is shown:'
  foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath)) { Say ('    | ' + $sqlLine) }
  Say  '  NEGCTL FIRST, as the handoff requires: a deliberately broken query must give a non-zero rc,'
  Say  '  or a zero from the real one only means psql started.'
  $badSqlPath = Join-Path $sqlDir 'acceptance_2d75b01_bad.sql'
  [IO.File]::WriteAllText($badSqlPath, "SELECT * FROM zzz_no_such_table;`r`n", (New-Object System.Text.UTF8Encoding($false)))
  $badOutput = @(Invoke-Native { & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5433 -U ccdash -d ccdashboard -t -A -f $badSqlPath 2>&1 })
  $badExit = $LASTEXITCODE
  Say ('    broken query rc : ' + $badExit + '   (must be non-zero)')
  $goodOutput = @(Invoke-Native { & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p 5433 -U ccdash -d ccdashboard -t -A -f $sqlPath 2>&1 })
  $goodExit = $LASTEXITCODE
  Say ('    real query rc   : ' + $goodExit + '   (must be 0)')
  foreach ($outputLine in $goodOutput) { Say ('    ' + $outputLine) }
  $dataRows = Select-DataRows $goodOutput
  Say ('    Wfm widgets found : ' + $dataRows.Count)
  $dbRead = (($badExit -ne 0) -and ($goodExit -eq 0))
  Say ('    this read is usable as evidence : ' + $dbRead)
  $fontSizeKeys = @()
  foreach ($dataRow in $dataRows) {
    foreach ($keyMatch in [regex]::Matches("$dataRow", '(?i)[A-Za-z]*fontsize[A-Za-z]*')) { $fontSizeKeys += $keyMatch.Value }
  }
  $distinctKeys = @($fontSizeKeys | Sort-Object -Unique)
  Say ('    config keys containing "fontsize", case-insensitive : ' + $distinctKeys.Count)
  foreach ($distinctKey in $distinctKeys) { Say ('      ' + $distinctKey) }
  Say  '    NEGCTL for this matcher: it is run over a line that cannot contain such a key -'
  $negKeyHits = ([regex]::Matches('screen_id|type|queueId', '(?i)[A-Za-z]*fontsize[A-Za-z]*')).Count
  Say ('    ' + $negKeyHits + ' hits (expected 0, which proves the count above is not matching everything)')
  Say  '    Four such keys present means the editor saved them; none means nobody has set the sizes'
  Say  '    yet, and the behavioural half needs them set first. Neither outcome makes the files red.'
  if ($dataRows.Count -eq 0) {
    Say  '    NO Wfm widget on any screen. Then the behavioural half cannot be measured until one is'
    Say  '    placed and its four sizes are set - that is a question for the coordinator, not'
    Say  '    something this probe invents, and it does NOT make the file side red.'
  }
}
Rule

Say 'FILE VERDICT OF THE ACCEPTANCE'
Say ('  trap fired during the run      : ' + (Test-TrapFired) + '   (True means a section was SKIPPED, not passed)')
Say ('  section 2 ledger               : ' + $ledgerOk)
Say ('  section 3 services restarted   : ' + $pidsOk)
Say ('  section 4 served bodies and versions : ' + $servedOk)
Say ('  section 5 scoped bundle        : ' + $bundleOk)
Say ('  section 6 assemblies and dictionaries : ' + $assembliesOk)
Say ('  section 7 db read usable       : ' + $dbRead + '   (it sets up the behavioural half; it is not part of the file verdict)')
$fileOk = ($ledgerOk -and $pidsOk -and $servedOk -and $bundleOk -and $assembliesOk -and (-not (Test-TrapFired)))
Say ('  FILE SIDE : ' + $(if ($fileOk) { 'GREEN - the shell serves this package, and nothing that had to stay still has moved' } else { 'RED - see the False rows above' }))
Say  ''
Say  '  THE FLIGHT IS NOT YET ACCEPTED BY THIS REPORT ALONE, and that is deliberate. This edit'
Say  '  leaves no byte needle, so no file can show that the four Wfm font sizes now reach the'
Say  '  widget. That half is measured in the viewer: set the four sizes in the widget settings,'
Say  '  save, reopen, and read the COMPUTED font-size of the four roles - each must equal what was'
Say  '  chosen. Until that is done the honest statement is "delivered by files, behaviour'
Say  '  outstanding", not "accepted".'
Say '===== END-OF-RUN MARKER: ACCEPTANCE-2D75B01-FILES-COMPLETE ====='
Finish $fileOk
