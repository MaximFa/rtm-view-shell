<#
  PROBE  probe_234_20261012_daytrendfail.ps1
  SHAPE  FROM probe_234_20261012_asdlog2.ps1 - same reading discipline, different subject and a
         window that spans two log files.
  UNIT   PR234-V4-DAYTREND-RENDER-FAIL-01. The shell found the browser console empty for
         10:05-10:16Z on a clean tab, with its needle control passing, so the text of the error
         can only be in the server log. Asked: every '[ERR] DayTrendWidget: JS render failed'
         from 2026-10-11 09:30Z to now, counted per hour in UTC, the full exception text and stack
         of one or two records with their neighbouring 'Calling JS with' / 'JS render completed'
         lines, whether an ERR falls inside 10:05-10:16Z today, and the circuit id if the lines
         carry one.
  THE LOG WRITES LOCAL TIME WITH AN EXPLICIT OFFSET (+03:00) and the question is in UTC. Every
         line's own offset is parsed, not assumed: DateTimeOffset.TryParse keeps the +03:00 the
         app wrote, so the conversion cannot be off by the server's current setting.
  TWO FILES, NOT ONE. The window starts yesterday, so log-20261011 and log-20261012 are both read
         and each is named with its line count. A window that silently covered one file would
         undercount and the undercount would read as 'it got better'.
  THE EXCEPTION MAY NOT BE ON THE ERR LINE. If the logger writes the message and the stack as
         following lines, printing only the matched line would hand over nothing. So the lines
         AFTER each match are printed too, up to the next timestamped line.
  SECRETS: a connection string or credential in a stack is NOT copied. Any line that looks like a
         connection string is replaced by its name, length and sha256, as the standard requires.
  WHERE  SERVER 234, READ ONLY. Nothing is stopped, started or configured; no log level is touched.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_daytrendfail.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
$script:SayCount = 0
$script:TrapFired = $false
function Say($text) {
  [void]$ReportLines.Add("$text"); Write-Host "$text"
  $script:SayCount++
  if (($script:SayCount % 25) -eq 0) { Write-Report }
}
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ''; Write-Host ('REPORT: ' + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
trap {
  $script:TrapFired = $true
  [void]$ReportLines.Add('*** TERMINATING ERROR - a section was SKIPPED, not failed:')
  [void]$ReportLines.Add('    message : ' + $_.Exception.Message)
  [void]$ReportLines.Add('    at line : ' + $_.InvocationInfo.ScriptLineNumber)
  Write-Report
  continue
}
# A line that smells of a connection string never reaches the report as itself.
function Protect-Line([string]$line) {
  if ($line -match '(?i)(password|pwd|secret|connectionstring|user id=|uid=|token=)') {
    $bytes = [Text.Encoding]::UTF8.GetBytes($line)
    $sha = [BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash($bytes)).Replace('-','')
    return '*** line withheld: it matches a credential pattern. length ' + $line.Length + ' chars, sha256 ' + $sha
  }
  return $line
}

Say ("DAYTREND JS RENDER FAILURES  " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + "Z   (machine local: " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " local)   host=" + $env:COMPUTERNAME)
Say  "READ ONLY. No service touched, no configuration read or written, no log level changed."
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

Say "G1  THE CLOCK THE LOG WRITES IN, read off the log itself"
$logDir = 'C:\Logs\RTMViewShell'
$logFiles = @()
foreach ($day in @('20261011','20261012')) {
  $path = Join-Path $logDir ('log-' + $day + '.txt')
  if (Test-Path -LiteralPath $path) { $logFiles += ,@($day, $path) }
  else { Say ("  log-" + $day + ".txt : ABSENT - and the window needs it, so say so rather than count less") }
}
Say ("  files to read : " + $logFiles.Count + "   expected 2")
if ($logFiles.Count -eq 0) { Say "  *** no log file at all - nothing is counted" ; Finish $false }
$machineOffset = ([TimeZoneInfo]::Local).GetUtcOffset($RunStartedAt).TotalHours
Say ("  this machine is UTC+" + $machineOffset + "   [" + ([TimeZoneInfo]::Local).Id + "]")
Say  "  The log writes its OWN offset on every line (the +03:00 in the samples below), and this run"
Say  "  parses that offset rather than applying the machine's current setting. The two agree today;"
Say  "  they would not agree across a daylight-saving change, and the line's own offset is the truth."
$FromUtc = [datetimeoffset]::Parse('2026-10-11T09:30:00Z')
$ToUtc   = [datetimeoffset]::UtcNow
Say ("  window, UTC : " + $FromUtc.ToString('yyyy-MM-dd HH:mm') + "Z  ..  " + $ToUtc.ToString('yyyy-MM-dd HH:mm') + "Z   (now)")
Rule

Say "1  EVERY FAILURE IN THE WINDOW, COUNTED PER HOUR IN UTC"
Say  "  EXPECTED BEFORE THE MEASUREMENT: an ERR roughly every 5 minutes, carrying a text like"
Say  "  JSException, TaskCanceled or JSDisconnected. A count of zero would contradict yesterday's"
Say  "  reading of 15 and today's of 57, and would mean this reader is broken, not the log quiet."
$needle = 'JS render failed'
$hourCount = @{}
$allHits = New-Object System.Collections.ArrayList
$perFile = @{}
foreach ($entry in $logFiles) {
  $day = $entry[0]
  $path = $entry[1]
  $lines = @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)
  $perFile[$day] = $lines.Count
  Say ("  log-" + $day + ".txt : " + $lines.Count + " lines")
  for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = "" + $lines[$index]
    if ($line -notlike ('*' + $needle + '*')) { continue }
    $stampMatch = [regex]::Match($line, '^\s*(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+\s*[+-]\d{2}:\d{2})')
    $stamp = $null
    if ($stampMatch.Success) {
      [datetimeoffset]$parsed = [datetimeoffset]::MinValue
      if ([datetimeoffset]::TryParse($stampMatch.Groups[1].Value, [ref]$parsed)) { $stamp = $parsed }
    }
    if ($null -eq $stamp) { continue }
    if ($stamp -lt $FromUtc -or $stamp -gt $ToUtc) { continue }
    $key = $stamp.ToUniversalTime().ToString('yyyy-MM-dd HH') + 'Z'
    if (-not $hourCount.ContainsKey($key)) { $hourCount[$key] = 0 }
    $hourCount[$key] = $hourCount[$key] + 1
    [void]$allHits.Add([pscustomobject]@{ Day = $day ; Index = $index ; Stamp = $stamp ; Line = $line })
  }
}
Say ("  failures inside the window : " + $allHits.Count)
foreach ($key in ($hourCount.Keys | Sort-Object)) { Say ("    " + $key + "  " + $hourCount[$key]) }
Say  "  NEGCTL, the coordinator's own: the same reader on a line known to exist."
$completedCount = 0
foreach ($entry in $logFiles) {
  $completedCount += @(Get-Content -LiteralPath $entry[1] -ErrorAction SilentlyContinue | Where-Object { "$_" -like '*JS render completed*' }).Count
}
Say ("  'JS render completed' in the same files : " + $completedCount + "   must be greater than 0")
$negNeedle = 0
foreach ($entry in $logFiles) {
  $negNeedle += @(Get-Content -LiteralPath $entry[1] -ErrorAction SilentlyContinue | Where-Object { "$_" -like '*zzz-no-such-failure*' }).Count
}
Say ("  an impossible marker in the same files : " + $negNeedle + "   must be 0")
$readerOk = (($completedCount -gt 0) -and ($negNeedle -eq 0))
Say ("  READER : " + $(if ($readerOk) { 'TRUSTED' } else { 'NOT TRUSTED - nothing below counts' }))
Rule

Say "2  THE WINDOW THE SHELL ASKED ABOUT - 10:05-10:16Z TODAY"
Say  "  This is the question that decides what the empty browser console means: an ERR inside this"
Say  "  window means the browser stayed silent while the server logged; no ERR means there was"
Say  "  simply nothing to see, and the console proves nothing either way."
$shellFrom = [datetimeoffset]::Parse('2026-10-12T10:05:00Z')
$shellTo   = [datetimeoffset]::Parse('2026-10-12T10:16:00Z')
$inShellWindow = @($allHits | Where-Object { $_.Stamp -ge $shellFrom -and $_.Stamp -le $shellTo })
Say ("  failures between 10:05Z and 10:16Z : " + $inShellWindow.Count)
foreach ($hit in $inShellWindow) { Say ("  | " + (Protect-Line $hit.Line)) }
if ($inShellWindow.Count -eq 0) {
  Say  "  NONE. So the empty console says nothing about this defect - the shell watched a quiet"
  Say  "  stretch. The nearest failures on either side, for the record:"
  $before = @($allHits | Where-Object { $_.Stamp -lt $shellFrom } | Select-Object -Last 1)
  $after  = @($allHits | Where-Object { $_.Stamp -gt $shellTo } | Select-Object -First 1)
  foreach ($hit in $before) { Say ("  before : " + (Protect-Line $hit.Line)) }
  foreach ($hit in $after)  { Say ("  after  : " + (Protect-Line $hit.Line)) }
}
Rule

Say "3  THE FULL RECORD OF TWO FAILURES, with the lines that follow and surround them"
Say  "  The matched line may be only the headline: if the logger puts the message and the stack on"
Say  "  following lines, they are printed here up to the next timestamped line. The neighbouring"
Say  "  'Calling JS with' and 'JS render completed' lines are printed so the attempt can be seen."
$samples = @($allHits | Select-Object -Last 2)
Say ("  records to print : " + $samples.Count + "   expected 2 (or fewer if the window holds fewer)")
foreach ($hit in $samples) {
  Rule
  Say ("  RECORD at " + $hit.Stamp.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + "Z  (" + $hit.Stamp.ToString('HH:mm:ss') + " local, offset " + $hit.Stamp.Offset + ")  from log-" + $hit.Day + ".txt line " + ($hit.Index + 1))
  $lines = @(Get-Content -LiteralPath (Join-Path $logDir ('log-' + $hit.Day + '.txt')) -ErrorAction SilentlyContinue)
  $start = [math]::Max(0, $hit.Index - 4)
  $stop  = [math]::Min($lines.Count - 1, $hit.Index + 25)
  $printed = 0
  for ($index = $start; $index -le $stop; $index++) {
    $line = "" + $lines[$index]
    $isNewRecord = ($index -gt $hit.Index) -and ($line -match '^\s*\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')
    $marker = if ($index -eq $hit.Index) { '>>' } else { '  ' }
    Say ("  " + $marker + " | " + (Protect-Line $line))
    $printed++
    if ($isNewRecord -and $printed -gt 6) { break }
  }
}
Rule

Say "4  THE CIRCUIT / CONNECTION ID - one tab or all of them"
Say  "  If the lines carry no id, say so: that is a property of the logging, and inventing a"
Say  "  conclusion about 'one tab' from lines that cannot show it would be worse than no answer."
$idPattern = '(?i)(circuit|connection|chartId|CircuitId|ConnectionId)\s*[=:]\s*([A-Za-z0-9_-]+)'
$idSeen = @{}
foreach ($hit in $allHits) {
  foreach ($idMatch in [regex]::Matches($hit.Line, $idPattern)) {
    $key = $idMatch.Groups[1].Value + '=' + $idMatch.Groups[2].Value
    if (-not $idSeen.ContainsKey($key)) { $idSeen[$key] = 0 }
    $idSeen[$key] = $idSeen[$key] + 1
  }
}
Say ("  distinct ids found on the ERR lines : " + $idSeen.Count)
foreach ($key in ($idSeen.Keys | Sort-Object)) { Say ("    " + $key + "   seen " + $idSeen[$key] + " times") }
if ($idSeen.Count -eq 0) { Say "  NONE - the ERR line carries no circuit or connection id at all, so this reading cannot tell one tab from many." }
Say  "  For comparison, the chartId on the neighbouring 'Calling JS with' lines, which DO carry one:"
$chartIds = @{}
foreach ($entry in $logFiles) {
  foreach ($line in @(Get-Content -LiteralPath $entry[1] -ErrorAction SilentlyContinue | Where-Object { "$_" -like '*Calling JS with*' })) {
    $chartMatch = [regex]::Match("$line", 'chartId=([A-Za-z0-9-]+)')
    if (-not $chartMatch.Success) { continue }
    $key = $chartMatch.Groups[1].Value
    if (-not $chartIds.ContainsKey($key)) { $chartIds[$key] = 0 }
    $chartIds[$key] = $chartIds[$key] + 1
  }
}
Say ("  distinct chartId values in these two files : " + $chartIds.Count + "   (a count, not a conclusion about tabs)")
Rule

Say "VERDICT OF THE READING"
Say ("  reader trusted by the 'completed' half : " + $readerOk)
Say  "  failures in the window, per hour       : see section 1"
Say  "  the 10:05-10:16Z question              : see section 2"
Say  "  exception text                         : see section 3, printed from the log as it stands"
Say ("  a section was skipped by an error      : " + $script:TrapFired)
Say  "  No verdict on the defect is offered here. This run hands over what the log says."
Say "===== END-OF-RUN MARKER: DAYTRENDFAIL-COMPLETE ====="
Finish (-not $script:TrapFired)
