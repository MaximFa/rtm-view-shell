<#
  PROBE  probe_234_20261014_acceptance-2324894.ps1
  READ-ONLY. Nothing is installed, started, stopped or configured by this run. It is the trace a
         reader who is not the author can check: the install already compared disk with staging,
         so this run asks the different questions - what reaches a browser, and what the running
         process says about itself in its log.
  STEP 3 of flight 2324894. Decides acceptance on the file and log side. The behavioural half
         (the widget counting agents once the operator re-picks the groups) belongs to shell.
  THE LOG IS THE POINT OF THIS FLIGHT, and it is read in a bounded window, not "lately": the
         probe records the log file length, waits out a 130 s window, then reads ONLY the bytes
         appended past that offset. So every count below is of lines born inside the window.
         The sink was located by measurement, not memory: appsettings Serilog writes to
         C:\Logs\RTMViewShell\log-.txt, daily rolling, MinimumLevel Default=Information. The
         stale C:\RTMView\Shell\logs\log-20260908.txt is a leftover of an older config and is
         deliberately NOT what this probe reads.
  THE WARNING IS EXPECTED, AND THAT IS THE NEGATIVE HALF: "N=0 ... configured groups ... absent"
         must appear, because the tenant map still holds the mixed-case names while the data
         stores StatusGroup uppercase. A warning that fires on a real misconfiguration is a
         warning that is not blind. Its ABSENCE here would be the finding.
  EVERY NEEDLE CARRIES A POSITIVE CONTROL: a count of lines in the same window by a needle that
         cannot fail. Without it a zero means only that I searched with the wrong reader.
  THE ASSEMBLIES are judged only by equality with the staging this flight unpacked. A rebuilt
         assembly sha changes by itself, so "differs from before" is not a predicate.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR  = 'C:\RTMView\Shell'
$STAGING    = 'C:\RTMView-Ops\incoming\pkg_2324894_20261014_094641'
$LOG_DIR    = 'C:\Logs\RTMViewShell'
$PinnedCommit = '2324894'
$PinnedZipSha = 'BB226218B2289ED5FF34CA705F3B4D53E409C1E846B7B02356C8E0C1AB4A52B6'
# handed out by the install run at 09:46, report 234_20261014_094641_install-2324894.txt
$BUNDLE_HANDED_OUT = '081F52CCBDEC1AD4DCB57DFC9471450C2B4F68C08A08CE08B5256C4C45908DD5'
$WEBDLL_HANDED_OUT = 'E58AAA86E0A332E61EFFB62A11A36293F9666B17A69F59ED17E37B9FA04069C5'
$PidsAfterInstall = @{ 'RTMService' = 8948 ; 'RTMViewShell' = 8876 ; 'RTMTwilio_1' = 9348 }
$WINDOW_SECONDS = 130
$RunStart = Get-Date
$StaleFloor = $RunStart.AddMinutes(-10)

Start-Probe -Name 'acceptance-2324894' -Title 'STEP 3  ACCEPTANCE  flight 2324894 (Wfm counts agents again)'
Say ('PS version : ' + $PSVersionTable.PSVersion.ToString())
Say  'READ-ONLY. Nothing is installed, started, stopped or configured by this run.'
Rule
Assert-Machine

function Count-In([string[]]$lines, [string]$needle) {
  $hits = 0
  foreach ($line in $lines) { if ("$line".Contains($needle)) { $hits++ } }
  return $hits
}
function Count-Regex([string[]]$lines, [string]$pattern) {
  $hits = 0
  foreach ($line in $lines) { if ("$line" -match $pattern) { $hits++ } }
  return $hits
}

Say '1  THE PACKAGE SIDE THIS PROBE READS FROM'
Say ('  staging : ' + $STAGING)
$stagingPresent = Test-Path -LiteralPath $STAGING
Say ('  present : ' + $stagingPresent + '   (False means the file half below is NOT MEASURED, not that it passed)')
if (-not $stagingPresent) { Say '  *** the staging the install left is gone. STOP and report.' ; Finish $false }
$stagedShellDir = Join-Path $STAGING 'Shell'
Say ('  files in the staged Shell tree : ' + @(Get-ChildItem -LiteralPath $stagedShellDir -Recurse -File -ErrorAction SilentlyContinue).Count + '   (POSCTL - a zero means the walk reads nothing)')
Rule

Say '2  THE LEDGER - the only build-to-commit link, since the installer writes no manifest'
$ledgerPath = 'C:\RTMView-Ops\applied\_ledger.txt'
$ledgerLines = @(Get-Content -LiteralPath $ledgerPath -ErrorAction SilentlyContinue)
Say ('  lines : ' + $ledgerLines.Count)
$ledgerOk = $false
if ($ledgerLines.Count -gt 0) {
  $lastLedger = $ledgerLines[-1]
  Say ('  last  : ' + $lastLedger)
  $commitHit = $lastLedger.Contains('commit=' + $PinnedCommit)
  $zipHit    = $lastLedger.Contains($PinnedZipSha)
  $webHit    = $lastLedger.Contains($WEBDLL_HANDED_OUT)
  Say ('  names commit ' + $PinnedCommit + ' : ' + $commitHit + '    names this package sha : ' + $zipHit + '    names the web.dll the install measured : ' + $webHit)
  $negLedger = $lastLedger.Contains('commit=0000000')
  Say ('  NEGCTL a commit that cannot be there : ' + $negLedger + '   (must be False)')
  $ledgerOk = ($commitHit -and $zipHit -and $webHit -and (-not $negLedger))
}
Say ('  LEDGER : ' + $ledgerOk)
Rule

Say '3  THE SERVICES - all three must be up, and their pids are the ones the install left'
$servicesOk = $true
foreach ($serviceName in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $serviceState = StateOf $serviceName
  $samePid = ([string]$serviceState.ProcessId -eq [string]$PidsAfterInstall[$serviceName])
  Say ('  ' + $serviceName.PadRight(14) + ' ' + ([string]$serviceState.State).PadRight(9) + ' pid ' + ([string]$serviceState.ProcessId).PadRight(6) + ' install left pid ' + $PidsAfterInstall[$serviceName] + '   same process : ' + $samePid)
  if ($serviceState.State -ne 'Running') { $servicesOk = $false }
  if (-not $samePid) { Say ('      the pid moved since the install - it restarted on its own, which is a finding whatever else is green') }
}
$legacyState = StateOf 'RTM'
Say ('  legacy service RTM : ' + $legacyState.State + '   - never ours, printed so a change by someone else is not read as this flight')
Say ('  SERVICES UP : ' + $servicesOk)
Rule

Say '4  WHAT THE SHELL ACTUALLY SERVES - fetched over HTTP, not read off the disk'
Say  '  The nine assets and their versions are read out of the served page itself, not typed here.'
Say  '  Only the scoped bundle is blessed to move, 10 -> 11. The other eight moving is a finding.'
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
  'app.css' = '36' ; 'CcDashboard.Web.styles.css' = '11' ; 'js/daytrendChart.js' = '14'
  'js/agentStateDistributionChart.js' = '16' ; 'js/reportDistributionChart.js' = '6'
  'js/widget-resize.js' = '3' ; 'css/tokens.css' = '3' ; 'css/widgets/wallboard-skin.css' = '3'
  'js/app.js' = '2'
}
$servedOk = $fetchOk
if ($fetchOk) {
  $assetRows = @()
  foreach ($assetMatch in [regex]::Matches($html, '(?:href|src)="([^":]+?)\?v=(\d+)"')) {
    $assetRows += ,@($assetMatch.Groups[1].Value, $assetMatch.Groups[2].Value)
  }
  Say ('  assets declared in the served page : ' + $assetRows.Count + '   (expected 9 - the count is its own control)')
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
    $verdictWord = 'MOVED  '
    if ($versionAgrees) { $verdictWord = 'agrees ' }
    Say ('    ' + $assetPath.PadRight(36) + ' v=' + $assetVersion.PadRight(3) + ' expected v=' + $expectedVersion.PadRight(3) + ' ' + $verdictWord + ' served ' + ([string]$servedBytes).PadLeft(7) + ' B  body == package: ' + $bodyAgrees)
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

Say '5  THE SCOPED BUNDLE, ON ITS OWN - the one asset the blessing stops the flight on'
$bundleDiskSha = ShaOf (Join-Path $SHELL_DIR 'wwwroot\CcDashboard.Web.styles.css')
$bundleStagedSha = ShaOf (Join-Path $STAGING 'Shell\wwwroot\CcDashboard.Web.styles.css')
Say ('  expected : ' + $BUNDLE_HANDED_OUT + '   (handed out by the install run)')
Say ('  on disk  : ' + $bundleDiskSha)
Say ('  package  : ' + $bundleStagedSha)
$bundleOk = (($bundleDiskSha -eq $BUNDLE_HANDED_OUT) -and ($bundleStagedSha -eq $BUNDLE_HANDED_OUT))
Say ('  BUNDLE : ' + $bundleOk + '   (False is a STOP and a letter to the coordinator, not a note)')
Rule

Say '6  THE ASSEMBLIES AND THE DICTIONARIES - equal to the package, read again by this run'
$assembliesOk = $true
foreach ($assemblyName in @('CcDashboard.Web.dll','CcDashboard.Application.dll','CcDashboard.Contracts.dll')) {
  $diskSha = ShaOf (Join-Path $SHELL_DIR $assemblyName)
  $stagedSha = ShaOf (Join-Path $STAGING ('Shell\' + $assemblyName))
  $agrees = (($stagedSha -ne 'ABSENT') -and ($diskSha -eq $stagedSha))
  Say ('  ' + $assemblyName.PadRight(30) + ' equals the package : ' + $agrees)
  if (-not $agrees) { $assembliesOk = $false }
}
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $diskSha = ShaOf (Join-Path $SHELL_DIR ($culture + '\CcDashboard.Web.resources.dll'))
  $stagedSha = ShaOf (Join-Path $STAGING ('Shell\' + $culture + '\CcDashboard.Web.resources.dll'))
  $agrees = (($stagedSha -ne 'ABSENT') -and ($diskSha -eq $stagedSha))
  Say ('  satellite ' + $culture.PadRight(8) + ' equals the package : ' + $agrees)
  if (-not $agrees) { $assembliesOk = $false }
}
$webDiskSha = ShaOf (Join-Path $SHELL_DIR 'CcDashboard.Web.dll')
Say ('  web.dll on disk : ' + $webDiskSha)
Say ('  the install wrote this same value into the ledger : ' + ($webDiskSha -eq $WEBDLL_HANDED_OUT))
Say  '  Only equality with the package is asserted - a rebuilt assembly sha changes by itself.'
Rule

Say '7  THE LOG, IN A BOUNDED WINDOW - what the running process says about the Wfm loop'
Write-Report
$logDirPresent = Test-Path -LiteralPath $LOG_DIR
Say ('  sink directory (measured from appsettings Serilog, not remembered) : ' + $LOG_DIR)
Say ('  present : ' + $logDirPresent)
$logOk = $false
$warningCount = -1
$loopCount = -1
if (-not $logDirPresent) { Say '  *** the sink directory does not exist - the log half is NOT MEASURED. Report it; do not call it green or red.' }
else {
  $logFiles = @(Get-ChildItem -LiteralPath $LOG_DIR -File -Filter 'log-*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  Say ('  files in the sink : ' + $logFiles.Count + '   (POSCTL - a zero means the filter is wrong, not that the shell is silent)')
  if ($logFiles.Count -eq 0) { Say '  *** no log file at all - NOT MEASURED, and itself a finding' }
  else {
    $logFile = $logFiles[0].FullName
    $offsetBefore = $logFiles[0].Length
    $logWritten = $logFiles[0].LastWriteTime
    Say ('  newest file : ' + $logFile)
    Say ('  length now  : ' + $offsetBefore + ' B    last written ' + $logWritten.ToString('yyyy-MM-dd HH:mm:ss'))
    Say ('  THE FILE MUST BE NEWER THAN THIS RUN, or a leftover from another day reads as today:')
    Say ('    this run started      ' + $RunStart.ToString('yyyy-MM-dd HH:mm:ss'))
    Say ('    refuse anything older than ' + $StaleFloor.ToString('yyyy-MM-dd HH:mm:ss'))
    $logFresh = ($logFiles[0].LastWriteTime -ge $StaleFloor)
    $nameCarriesToday = $logFiles[0].Name.Contains($RunStart.ToString('yyyyMMdd'))
    Say ('    fresh enough : ' + $logFresh + '    name carries today date : ' + $nameCarriesToday)
    if (-not $logFresh) {
      Say ('  *** the newest file in the sink predates this run - the log half is NOT MEASURED, and a')
      Say ('      silent sink is itself a finding. Reported, not called green and not called red.')
      Say ('  LOG : NOT MEASURED')
      Write-Report
      Rule
      Finish $false
    }
    Say ('  WINDOW OPENS. Waiting ' + $WINDOW_SECONDS + ' s, then reading ONLY the bytes appended past ' + $offsetBefore + '.')
    Say  '  That is what makes the counts below "in two minutes" rather than "at some point".'
    Start-Sleep -Seconds $WINDOW_SECONDS
    $offsetAfter = (Get-Item -LiteralPath $logFile).Length
    $grewBy = $offsetAfter - $offsetBefore
    Say ('  length after : ' + $offsetAfter + ' B    grew by ' + $grewBy + ' B')
    Say  '  THE GROWTH IS THE LIVENESS PROOF: a log that did not grow cannot tell "the loop is silent"'
    Say  '  from "the process is dead or writing elsewhere", and the two are different findings.'
    $windowLines = @()
    if ($grewBy -gt 0) {
      $stream = [IO.File]::Open($logFile, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
      try {
        [void]$stream.Seek($offsetBefore, [IO.SeekOrigin]::Begin)
        $buffer = New-Object byte[] $grewBy
        [void]$stream.Read($buffer, 0, $grewBy)
        $windowLines = @([Text.Encoding]::UTF8.GetString($buffer) -split "`r?`n" | Where-Object { "$_".Trim() -ne '' })
      } finally { $stream.Dispose() }
    }
    Say ('  lines born inside the window : ' + $windowLines.Count + '   (POSCTL for every count below)')
    $sampleCount = [math]::Min(3, $windowLines.Count)
    for ($sampleIndex = 0; $sampleIndex -lt $sampleCount; $sampleIndex++) { Say ('    sample | ' + $windowLines[$sampleIndex]) }
    Say  '  The samples are printed so the reader can check the level token and timestamp shape'
    Say  '  that the counters below rely on, instead of trusting my parse.'
    $loopCount = Count-In $windowLines 'WfmRealtimeLoop: processed'
    $loopWithQueues = Count-Regex $windowLines 'WfmRealtimeLoop: processed .* queues'
    $loopInformation = Count-Regex $windowLines '\[INF\].*WfmRealtimeLoop: processed'
    Say ('  "WfmRealtimeLoop: processed"            : ' + $loopCount + '   (expected 1 or more - these lines did not exist before this flight)')
    Say ('  same line with "... queues"             : ' + $loopWithQueues)
    Say ('  same line carrying the [INF] level token: ' + $loopInformation + '   (the blessing asks for Information)')
    $warningCount = Count-Regex $windowLines '\[WRN\].*N=0'
    $warningAbsent = Count-Regex $windowLines 'configured groups.*absent'
    Say ('  Warning lines with "N=0"                : ' + $warningCount)
    Say ('  lines naming "configured groups ... absent" : ' + $warningAbsent)
    Say  '  THIS WARNING IS EXPECTED AND IS THE NEGATIVE HALF. The tenant map still holds the'
    Say  '  mixed-case names while the data stores StatusGroup uppercase, so N=0 is the truth right'
    Say  '  now. A warning that fires on a real misconfiguration is not blind. Its ABSENCE would be'
    Say  '  the finding, and the widget staying at zeros after the operator re-picks the groups is'
    Say  '  the behavioural half, which belongs to shell and not to this probe.'
    $negNeedle = Count-In $windowLines 'ZzzNoSuchLogLineCouldEverExist'
    Say ('  NEGCTL a needle that cannot be there    : ' + $negNeedle + '   (must be 0, and the counts above prove the reader finds real lines)')
    $logOk = (($grewBy -gt 0) -and ($windowLines.Count -gt 0) -and ($loopCount -ge 1) -and ($loopInformation -ge 1) -and ($negNeedle -eq 0))
  }
}
Say ('  LOG : ' + $logOk)
Write-Report
Rule

Say '8  WHAT THE BEHAVIOURAL HALF NEEDS - handed to shell, asserted by nobody here'
Say  '  Read-only context so shell does not have to re-measure it: the cause found yesterday was'
Say  '  that StatusGroup is stored UPPERCASE (ONPHONE, PAPERWORK, AVAILABLE and three more) while'
Say  '  the tenant serving map holds Available / "On Phone" / Paperwork and the comparison is exact.'
Say  '  Until the operator re-picks the groups in the tenant settings, N stays 0 by design and the'
Say  '  widget keeps showing zeros. That is NOT a defect of this flight and NOT a reason to fail'
Say  '  this acceptance - it is the state the new Warning now reports out loud instead of silently.'
Rule

Say 'FILE AND LOG VERDICT OF THE ACCEPTANCE'
Say ('  trap fired during the run : ' + (Test-TrapFired) + '   (True means a section was SKIPPED, not passed)')
Say ('  ledger names this build   : ' + $ledgerOk)
Say ('  services up, same pids    : ' + $servicesOk)
Say ('  served versions and bodies: ' + $servedOk)
Say ('  scoped bundle             : ' + $bundleOk)
Say ('  assemblies == package     : ' + $assembliesOk)
Say ('  log, bounded window       : ' + $logOk)
$stepOk = ($ledgerOk -and $servicesOk -and $servedOk -and $bundleOk -and $assembliesOk -and $logOk -and (-not (Test-TrapFired)))
Say ('  STEP 3 : ' + $(if ($stepOk) { 'ACCEPTED ON THE FILE AND LOG SIDE - the behavioural half is shells to close' } else { 'NOT ACCEPTED - report the rows above; the rollback floor is the 2d75b01 package on disk' }))
Say  '  No unit is closed by this report. Closing is the operator word, and the coordinator accepts.'
Say '===== END-OF-RUN MARKER: ACCEPTANCE-2324894-COMPLETE ====='
Finish $stepOk
