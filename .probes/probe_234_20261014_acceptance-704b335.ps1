<#
  PROBE  probe_234_20261014_acceptance-704b335.ps1
  READ-ONLY. Nothing is restarted, started, stopped or configured. This is the trace a reader who
         is not the author can check, and the last box of flight 704b335.
  WHAT THE BLESSING ASKS, 2026-10-14T11:01:23Z, and what each row answers:
    "служба жива, версия/коммит сборки на сервере = 704b335"  -> sections 2 and 3
    "в логе за первые 5 минут - строки цикла Wfm"              -> section 5, in a bounded window
    "mixed TimeZones <= 21 за первый час, не 42/мин"           -> section 5, AND THIS IS THE POINT:
         before this flight that warning ran at 42 lines per MINUTE - 1260 of them in a 30-minute
         window, measured by me at 11:43 today. WfmLogGate is supposed to make it once per queue
         per hour. So the predicate is a RATE, measured in this run, against a rate measured
         before it - not a yes/no on the word.
    "строки N unknown для BU 22 - ожидаемы"                    -> section 5, counted, not required:
         they are the new no-data path, and their presence is information, their absence is too.
  WHAT MUST NOT BE EXPECTED ANY MORE, and I say it before measuring: the warning "N=0 ... configured
         groups ... absent" that the last flight treated as its negative half. Its test file
         WfmN0WarningTests.cs is DELETED in this delta - measured by me from the object store - so
         the build no longer carries that path. A probe that waited for it would go red on correct
         software.
  THE LOG IS READ IN A BOUNDED WINDOW and freshness is judged by the timestamp INSIDE the newest
         line plus growth of the length, never by the directory time: a file a service holds open
         does not get its directory time written on every append, and that cost me a false red at
         10:04 today.
  NOT A PREDICATE: the sha of a rebuilt assembly. Everything is judged against the staging this
         flight unpacked, which the install left at the path pinned below.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$SHELL_DIR = 'C:\RTMView\Shell'
$STAGING   = 'C:\RTMView-Ops\incoming\pkg_704b335_20261014_142353'
$LOG_DIR   = 'C:\Logs\RTMViewShell'
$PinnedCommit = '704b335'
$PinnedZipSha = 'CF004840E25D58616DE4B779842F8DC4661FA413B515F18F2DCDF04D1B41B9AD'
$WebDllFromInstall = '545230FBD7B17F5439DDE43BF08497CBA7EF1138C32A257DC29940AD4760C5EF'
$PidsAfterInstall = @{ 'RTMService' = 3896 ; 'RTMViewShell' = 12200 ; 'RTMTwilio_1' = 4748 }
$TzRateBefore = 42          # lines per minute, measured 2026-10-14 11:13-11:43 (1260 in 30 min)
$TzExpectedPerHour = 21     # one per queue per hour, per the blessing
$WINDOW_SECONDS = 310       # a little over the five minutes the blessing names

$RunStartedAt = Get-Date
$StaleFloor = $RunStartedAt.AddMinutes(-15)
Start-Probe -Name 'acceptance-704b335' -Title 'ACCEPTANCE  flight 704b335 (N from the engine by skill)'
Say 'READ-ONLY. Nothing is restarted, started, stopped or configured by this run.'
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
function Stamp-Head([string]$line) {
  if ("$line" -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') { return "$line".Substring(0,19) }
  return ''
}

Say '1  THE PACKAGE SIDE THIS PROBE READS FROM'
Say ('  staging : ' + $STAGING)
$stagingPresent = Test-Path -LiteralPath $STAGING
Say ('  present : ' + $stagingPresent + '   (False means the file half is NOT MEASURED, not that it passed)')
if (-not $stagingPresent) { Say '  *** the staging the install left is gone. STOP and report.' ; Finish $false }
Say ('  files in the staged Shell tree : ' + @(Get-ChildItem -LiteralPath (Join-Path $STAGING 'Shell') -Recurse -File -ErrorAction SilentlyContinue).Count + '   (POSCTL - a zero means the walk reads nothing)')
Rule

Say '2  THE LEDGER - the only build-to-commit link, since the installer writes no manifest'
$ledgerLines = @(Get-Content -LiteralPath 'C:\RTMView-Ops\applied\_ledger.txt' -ErrorAction SilentlyContinue)
Say ('  lines : ' + $ledgerLines.Count)
$ledgerOk = $false
if ($ledgerLines.Count -gt 0) {
  $lastLedger = $ledgerLines[-1]
  Say ('  last  : ' + $lastLedger)
  $commitHit = $lastLedger.Contains('commit=' + $PinnedCommit)
  $zipHit    = $lastLedger.Contains($PinnedZipSha)
  $webHit    = $lastLedger.Contains($WebDllFromInstall)
  Say ('  names commit ' + $PinnedCommit + ' : ' + $commitHit + '    names this package : ' + $zipHit + '    names the web.dll the install measured : ' + $webHit)
  $negLedger = $lastLedger.Contains('commit=2324894')
  Say ('  NEGCTL names the PREVIOUS commit : ' + $negLedger + '   (must be False - that would mean the line did not move)')
  $ledgerOk = ($commitHit -and $zipHit -and $webHit -and (-not $negLedger))
}
Say ('  LEDGER : ' + $ledgerOk)
Rule

Say '3  THE SERVICES - alive, and on the pids the install left'
$servicesOk = $true
foreach ($serviceName in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $serviceState = StateOf $serviceName
  $samePid = ([string]$serviceState.ProcessId -eq [string]$PidsAfterInstall[$serviceName])
  Say ('  ' + $serviceName.PadRight(14) + ' ' + ([string]$serviceState.State).PadRight(9) + ' pid ' + ([string]$serviceState.ProcessId).PadRight(6) + ' install left ' + $PidsAfterInstall[$serviceName] + '   same process : ' + $samePid)
  if ($serviceState.State -ne 'Running') { $servicesOk = $false }
  if (-not $samePid) { Say '      the pid moved since the install - it restarted on its own, a finding whatever else is green' }
}
Say ('  legacy service RTM : ' + (StateOf 'RTM').State + '   - never ours')
Say ('  SERVICES : ' + $servicesOk)
Rule

Say '4  WHAT THE SHELL SERVES - fetched over HTTP, not read off the disk'
Say  '  The nine assets and their versions are read out of the served page itself. Only'
Say  '  js/widget-resize.js is blessed to move, 3 -> 4. Any other version moving is the finding.'
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
  Say ('  fetch usable as evidence : ' + $fetchOk)
  $negCode = (& $curl -k -s -o NUL -w '%{http_code}' --max-time 20 ($base + '/zzz-no-such-endpoint')) 2>$null
  Say ('  NEGCTL /zzz-no-such-endpoint -> ' + $negCode + '   (must be neither 200 nor 000)')
}
$blessedVersions = @{
  'app.css' = '36' ; 'CcDashboard.Web.styles.css' = '11' ; 'js/daytrendChart.js' = '14'
  'js/agentStateDistributionChart.js' = '16' ; 'js/reportDistributionChart.js' = '6'
  'js/widget-resize.js' = '4' ; 'css/tokens.css' = '3' ; 'css/widgets/wallboard-skin.css' = '3'
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
    $note = ''
    if ($assetPath -eq 'js/widget-resize.js') { $note = '  <- the ONE that must move, 3 -> 4' }
    Say ('    ' + $assetPath.PadRight(36) + ' v=' + $assetVersion.PadRight(3) + ' expected v=' + $expectedVersion.PadRight(3) + ' ' + $verdictWord + ' served ' + ([string]$servedBytes).PadLeft(7) + ' B  body == package: ' + $bodyAgrees + $note)
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
Say ('  SERVED : ' + $servedOk)
Write-Report
Rule

Say '5  THE LOG IN A BOUNDED WINDOW - the loop, the TZ rate, and the new no-data path'
$logOk = $false
$tzRateOk = $false
$loopOk = $false
$logFiles = @()
if (Test-Path -LiteralPath $LOG_DIR) { $logFiles = @(Get-ChildItem -LiteralPath $LOG_DIR -File -Filter 'log-*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending) }
Say ('  files in the sink : ' + $logFiles.Count + '   (POSCTL - a zero means the filter is wrong, not that the shell is silent)')
if ($logFiles.Count -eq 0) { Say '  *** no log file - NOT MEASURED' }
else {
  $logFile = $logFiles[0].FullName
  $offsetBefore = $logFiles[0].Length
  Say ('  newest file : ' + $logFile + '    ' + $offsetBefore + ' B')
  Say ('  file time (context only, NOT the predicate) : ' + $logFiles[0].LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
  Say  '  CONTEXT OVER THE WHOLE FILE - so a zero inside the window can be told from a needle that'
  Say  '  matches nothing anywhere. These are NOT the window counts.'
  $wholeFile = @(Get-Content -LiteralPath $logFile -Encoding UTF8 -ErrorAction SilentlyContinue)
  Say ('    lines in the file today                  : ' + $wholeFile.Count)
  Say ('    "WfmRealtimeLoop: processed" anywhere     : ' + (Count-In $wholeFile 'WfmRealtimeLoop: processed'))
  Say ('    "mixed TimeZones" anywhere today         : ' + (Count-In $wholeFile 'mixed TimeZones'))
  Say ('    "N unknown" anywhere today               : ' + (Count-In $wholeFile 'N unknown'))
  Say ('    the OLD N=0 warning anywhere today       : ' + (Count-Regex $wholeFile '\[WRN\].*N=0') + '   (its test is deleted in this delta; this is context, not a requirement)')
  Say ('  WINDOW OPENS. Waiting ' + $WINDOW_SECONDS + ' s, then reading ONLY the bytes appended past ' + $offsetBefore + '.')
  Start-Sleep -Seconds $WINDOW_SECONDS
  $offsetAfter = (Get-Item -LiteralPath $logFile).Length
  $grewBy = $offsetAfter - $offsetBefore
  Say ('  length after : ' + $offsetAfter + ' B    grew by ' + $grewBy + ' B')
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
  $windowMinutes = [math]::Round($WINDOW_SECONDS / 60.0, 2)
  Say ('  lines born inside the window : ' + $windowLines.Count + '   (POSCTL for every count below)')
  $sampleCount = [math]::Min(3, $windowLines.Count)
  for ($sampleIndex = 0; $sampleIndex -lt $sampleCount; $sampleIndex++) { Say ('    sample | ' + $windowLines[$sampleIndex]) }
  $lastStamped = ''
  foreach ($windowLine in $windowLines) { if ((Stamp-Head $windowLine) -ne '') { $lastStamped = "$windowLine" } }
  $contentFresh = $false
  if ($lastStamped -ne '') {
    $lineStamp = [datetime]::ParseExact((Stamp-Head $lastStamped), 'yyyy-MM-dd HH:mm:ss', $null)
    Say ('  newest line timestamp, out of the line itself : ' + $lineStamp.ToString('yyyy-MM-dd HH:mm:ss'))
    $contentFresh = ($lineStamp -ge $StaleFloor)
    Say ('  newer than the stale floor : ' + $contentFresh + '   <- THIS is the freshness predicate, not the file time')
  }
  $loopQueues = Count-Regex $windowLines 'WfmRealtimeLoop: processed .* queues'
  $loopBu     = Count-Regex $windowLines 'WfmRealtimeLoop: processed .* BU'
  $loopInf    = Count-Regex $windowLines '\[INF\].*WfmRealtimeLoop: processed'
  Say ('  loop "processed ... queues" : ' + $loopQueues + '    "processed ... BU" : ' + $loopBu + '    carrying [INF] : ' + $loopInf)
  Say ('  expected 1 or more of each - the loop steps every 30 s, so about ' + [math]::Floor($WINDOW_SECONDS / 30) + ' of each in this window')
  $loopOk = (($loopQueues -ge 1) -and ($loopInf -ge 1))

  $tzInWindow = Count-In $windowLines 'mixed TimeZones'
  $tzPerMinute = [math]::Round($tzInWindow / $windowMinutes, 2)
  Say ''
  Say ('  "mixed TimeZones" inside the window : ' + $tzInWindow + '   = ' + $tzPerMinute + ' per minute')
  Say ('  BEFORE THIS FLIGHT that rate was ' + $TzRateBefore + ' per minute - 1260 lines in a 30-minute window,')
  Say  '  measured by me at 11:43 today. That is the before-half of this needle, and without it a'
  Say  '  small number here would prove nothing.'
  Say ('  the blessing asks for at most ' + $TzExpectedPerHour + ' in the first HOUR, one per queue, so in a window of')
  Say ('  ' + $windowMinutes + ' min the expectation is at most ' + $TzExpectedPerHour + ' and the rate must be far below ' + $TzRateBefore + '.')
  # CORRECTED 2026-10-14 14:35, by me, after this probe printed True on 21 lines in 5.17 minutes.
  # The blessing asks for at most 21 in an HOUR. Comparing a FIVE-MINUTE count with an HOURLY
  # ceiling is a predicate weaker than the question, and a predicate weaker than the question is a
  # false green - the same defect I spent today rooting, committed here by me.
  # The lawful predicate is the rate carried to the same unit as the ceiling.
  $tzPerHour = [math]::Round($tzInWindow / $windowMinutes * 60.0, 1)
  Say ('  carried to the ceiling unit : ' + $tzPerHour + ' per HOUR against a ceiling of ' + $TzExpectedPerHour + ' per hour')
  $tzImprovement = 0
  if ($tzPerMinute -gt 0) { $tzImprovement = [math]::Round($TzRateBefore / $tzPerMinute, 1) }
  Say ('  improvement over the pre-flight rate : ' + $tzImprovement + ' x   (real, and separate from the ceiling question)')
  $tzRateOk = ($tzPerHour -le $TzExpectedPerHour)
  Say ('  TZ GATE MEETS THE BLESSING : ' + $tzRateOk)
  if (-not $tzRateOk) {
    Say  '  NOT met. The flood is an order of magnitude smaller than before and that is a real gain,'
    Say  '  but the gate the blessing describes - one line per queue per hour - is not what this'
    Say  '  build does. That is a finding for the coordinator, not a reason to call the row green.'
  }

  $nUnknown = Count-In $windowLines 'N unknown'
  $nUnknownBu22 = Count-Regex $windowLines '(?i)N unknown.*(22|הובלה)'
  Say ''
  Say ('  "N unknown" inside the window : ' + $nUnknown + '    of them naming BU 22 or its queue : ' + $nUnknownBu22)
  Say  '  These are EXPECTED and counted, not required: the blessing says one per hour until the'
  Say  '  operator re-picks the groups. Their presence shows the new no-data path is live; their'
  Say  '  absence in a five-minute window is not a defect, because the gate is hourly.'
  $oldWarningInWindow = Count-Regex $windowLines '\[WRN\].*N=0'
  Say ('  the OLD N=0 warning inside the window : ' + $oldWarningInWindow + '   (its test is deleted; a non-zero here would be the surprise)')
  $negNeedle = Count-In $windowLines 'ZzzNoSuchLogLineCouldEverExist'
  Say ('  NEGCTL a needle that cannot be there : ' + $negNeedle + '   (must be 0, and the counts above prove the reader finds real lines)')
  $logOk = (($grewBy -gt 0) -and ($windowLines.Count -gt 0) -and $contentFresh -and $loopOk -and ($negNeedle -eq 0))
}
Say ('  LOG : ' + $logOk)
Write-Report
Rule

Say '6  THE ASSEMBLIES AND DICTIONARIES - equal to the package, read again by this run'
$assembliesOk = $true
foreach ($assemblyName in @('CcDashboard.Web.dll','CcDashboard.Application.dll','CcDashboard.Infrastructure.dll','CcDashboard.Contracts.dll')) {
  $diskSha = ShaOf (Join-Path $SHELL_DIR $assemblyName)
  $stagedSha = ShaOf (Join-Path $STAGING ('Shell\' + $assemblyName))
  $agrees = (($stagedSha -ne 'ABSENT') -and ($diskSha -eq $stagedSha))
  Say ('  ' + $assemblyName.PadRight(32) + ' equals the package : ' + $agrees)
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
Say ('  the install wrote this same value into the ledger : ' + ($webDiskSha -eq $WebDllFromInstall))
Say  '  Only equality with the package is asserted - a rebuilt assembly sha changes by itself.'
Rule

Say 'VERDICT OF THE ACCEPTANCE'
Say ('  trap fired during the run : ' + (Test-TrapFired) + '   (True means a section was SKIPPED, not passed)')
Say ('  ledger names this build   : ' + $ledgerOk)
Say ('  services up, same pids    : ' + $servicesOk)
Say ('  served versions and bodies: ' + $servedOk)
Say ('  log, bounded window       : ' + $logOk)
Say ('  the TZ rate gate works    : ' + $tzRateOk)
Say ('  assemblies == package     : ' + $assembliesOk)
$stepOk = ($ledgerOk -and $servicesOk -and $servedOk -and $logOk -and $tzRateOk -and $assembliesOk -and (-not (Test-TrapFired)))
Say ('  ACCEPTANCE : ' + $(if ($stepOk) { 'GREEN on files, service and log' } else { 'NOT GREEN - see which row is False above' }))
Say  '  No unit is closed by this report. Closing is the operator word, and the coordinator accepts.'
Say  '  The behavioural half - the widget showing a number once the operator re-picks the groups -'
Say  '  belongs to shell and is asserted by nobody here.'
Say '===== END-OF-RUN MARKER: ACCEPTANCE-704B335-COMPLETE ====='
Finish $stepOk
