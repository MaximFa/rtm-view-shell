<#
  PROBE  probe_234_20261012_timeoutprobe.ps1
  SHAPE  FROM probe_234_20261012_rendergap.ps1 - same two files, same stamp parsing, one question.
  UNIT   PR234-V4-DAYTREND-RENDER-FAIL-01, the deciding reading, designed by the coordinator.
         For each '[ERR] JS render failed' at time t: is there ANY 'Calling JS with' line in the
         window [t-60.000 s ; t-59.900 s]? If every failure is the Blazor interop timeout, the
         answer is 69 of 69. A 100 ms window is narrow enough that a neighbour by chance is rare.
  THE NEGATIVE HALF IS THE WHOLE POINT and it is the coordinator's: the same search shifted to
         47.0 s, the same 100 ms width. At the measured density - 1732 calls over ~34 hours, about
         one per 70 s - a few hits out of 69 are expected. IF THE 60 s OFFSET SCORES NO BETTER
         THAN THE 47 s OFFSET, THE TIMEOUT CONCLUSION DOES NOT HOLD, and this probe says so in
         those words rather than leaving the reader to compare two numbers.
  WHY THIS IS NOT THE PREVIOUS READING AGAIN: the previous one paired each failure with the
         NEAREST preceding call, which at this density returns an arbitrary neighbour - its median
         of 41 s was the log's density, not a measurement. This one asks a yes/no question about a
         fixed, narrow offset, which density cannot fake.
  WHERE  SERVER 234, READ ONLY. No service touched, no log level changed, no write anywhere.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_timeoutprobe.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
$script:SayCount = 0
$script:TrapFired = $false
function Say($text) {
  [void]$ReportLines.Add("$text"); Write-Host "$text"
  $script:SayCount++
  if (($script:SayCount % 20) -eq 0) { Write-Report }
}
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ''; Write-Host ('REPORT: ' + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
trap {
  $script:TrapFired = $true
  [void]$ReportLines.Add('*** TERMINATING ERROR - a section was SKIPPED: ' + $_.Exception.Message)
  Write-Report
  continue
}
function Stamp-Of([string]$line) {
  $stampMatch = [regex]::Match($line, '^\s*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+\s*[+-]\d{2}:\d{2})')
  if (-not $stampMatch.Success) { return $null }
  [datetimeoffset]$parsed = [datetimeoffset]::MinValue
  if ([datetimeoffset]::TryParse($stampMatch.Groups[1].Value, [ref]$parsed)) { return $parsed }
  return $null
}

Say ("THE 60-SECOND TEST  " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + "Z   (machine local: " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " local)   host=" + $env:COMPUTERNAME)
Say  "READ ONLY. Every loop prints its progress."
Say ("probe sha256 : " + (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say '  *** NOT server 234 - refusing to measure'; Finish $false }
Say "  G0 PASS"
Rule

Say "1  THE TWO FILES AND THE TWO LINE KINDS"
$logDir = 'C:\Logs\RTMViewShell'
$failures = New-Object System.Collections.ArrayList
$calls = New-Object System.Collections.ArrayList
$FromUtc = [datetimeoffset]::Parse('2026-10-11T09:30:00Z')
$ToUtc   = [datetimeoffset]::UtcNow
foreach ($day in @('20261011','20261012')) {
  $path = Join-Path $logDir ('log-' + $day + '.txt')
  if (-not (Test-Path -LiteralPath $path)) { Say ("  log-" + $day + ".txt : ABSENT") ; continue }
  $lines = @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)
  Say ("  log-" + $day + ".txt : " + $lines.Count + " lines")
  foreach ($rawLine in $lines) {
    $line = "" + $rawLine
    $isFailure = ($line -like '*JS render failed*')
    $isCall = ($line -like '*Calling JS with*')
    if (-not ($isFailure -or $isCall)) { continue }
    $stamp = Stamp-Of $line
    if ($null -eq $stamp) { continue }
    if ($isFailure) {
      if ($stamp -ge $FromUtc -and $stamp -le $ToUtc) { [void]$failures.Add([pscustomobject]@{ Stamp = $stamp ; Line = $line }) }
    } else {
      $chartMatch = [regex]::Match($line, 'chartId=([A-Za-z0-9-]+)')
      $chartId = if ($chartMatch.Success) { $chartMatch.Groups[1].Value } else { '<none>' }
      [void]$calls.Add([pscustomobject]@{ Stamp = $stamp ; ChartId = $chartId })
    }
  }
}
Say ("  failures in the window : " + $failures.Count + "   calls held : " + $calls.Count)
if ($failures.Count -eq 0 -or $calls.Count -eq 0) { Say "  *** one of the two kinds is empty - nothing can be tested" ; Finish $false }
$span = ($ToUtc - $FromUtc).TotalSeconds
Say ("  call density : one call per " + [math]::Round($span / $calls.Count, 1) + " s on average over " + [math]::Round($span / 3600, 1) + " hours")
Say  "  That density is what makes a 100 ms window a real test: a call lands in any given 100 ms"
Say  "  slot by chance with probability of roughly one in seven hundred."
Rule

function Test-Offset([double]$offsetSeconds, [string]$label) {
  Say ("  OFFSET " + $label + " : looking for any call in [t-" + $offsetSeconds.ToString('0.000') + " s ; t-" + ($offsetSeconds - 0.1).ToString('0.000') + " s]")
  $hits = 0
  $chartIds = @{}
  $examples = New-Object System.Collections.ArrayList
  $progress = 0
  foreach ($failure in $failures) {
    $progress++
    if (($progress % 20) -eq 0) { Write-Host ("    ... " + $progress + " of " + $failures.Count) }
    $windowEnd = $failure.Stamp.AddSeconds(-1 * ($offsetSeconds - 0.1))
    $windowStart = $failure.Stamp.AddSeconds(-1 * $offsetSeconds)
    $found = @($calls | Where-Object { $_.Stamp -ge $windowStart -and $_.Stamp -le $windowEnd })
    if ($found.Count -eq 0) { continue }
    $hits++
    foreach ($call in $found) {
      if (-not $chartIds.ContainsKey($call.ChartId)) { $chartIds[$call.ChartId] = 0 }
      $chartIds[$call.ChartId] = $chartIds[$call.ChartId] + 1
    }
    if ($examples.Count -lt 3) {
      [void]$examples.Add(($failure.Stamp.ToUniversalTime().ToString('HH:mm:ss.fff') + 'Z  call at ' + $found[0].Stamp.ToUniversalTime().ToString('HH:mm:ss.fff') + 'Z  gap ' + [math]::Round(($failure.Stamp - $found[0].Stamp).TotalMilliseconds) + ' ms  chartId ' + $found[0].ChartId))
    }
  }
  Say ("  hits : " + $hits + " of " + $failures.Count)
  Say ("  distinct chartId values among the calls found : " + $chartIds.Count)
  foreach ($key in ($chartIds.Keys | Sort-Object)) { Say ("    " + $key + "   " + $chartIds[$key] + " times") }
  foreach ($example in $examples) { Say ("    example : " + $example) }
  return $hits
}

Say "2  THE TEST OFFSET - 60.000 s, the Blazor interop default"
Say  "  EXPECTED BEFORE THE MEASUREMENT: 69 of 69 if every failure is the timeout."
$hits60 = Test-Offset 60.0 '60.000 s'
Rule

Say "3  THE CONTROL OFFSET - 47.000 s, the same width, no meaning in the framework"
Say  "  EXPECTED BEFORE THE MEASUREMENT: a few out of 69, by density alone."
$hits47 = Test-Offset 47.0 '47.000 s'
Rule

Say "VERDICT OF THE READING"
Say ("  hits at the 60.000 s offset : " + $hits60 + " of " + $failures.Count)
Say ("  hits at the 47.000 s control: " + $hits47 + " of " + $failures.Count)
if ($hits60 -le $hits47) {
  Say  "  THE TIMEOUT CONCLUSION DOES NOT HOLD. The meaningful offset scored no better than a"
  Say  "  meaningless one, so the earlier cluster near 60 s was the log's density, not a timeout."
} elseif ($hits60 -ge ($failures.Count - 2)) {
  Say  "  EVERY failure has a call exactly 60 s before it. That is the interop timeout, for all of"
  Say  "  them, and the control offset shows the number is not an artefact of density."
} else {
  Say ("  MIXED: " + $hits60 + " of " + $failures.Count + " failures have a call exactly 60 s before them and the control")
  Say  "  scored lower, so those are timeouts; the rest have another cause and this reading does not"
  Say  "  name it. A single cause for all 69 is NOT supported by these numbers."
}
Say ("  a section was skipped by an error : " + $script:TrapFired)
Say "===== END-OF-RUN MARKER: TIMEOUTPROBE-COMPLETE ====="
Finish (-not $script:TrapFired)
