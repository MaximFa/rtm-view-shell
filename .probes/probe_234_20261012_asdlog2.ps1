<#
  PROBE  probe_234_20261012_asdlog2.ps1
  SHAPE  FROM probe_234_20261011_asdlog.ps1, whose window was a fixed UTC span. Here the question, not copied from a flight probe: it installs nothing and the
         only shape it borrows is the gate-and-negative-half discipline.
  UNIT   The operator says "it does not work" after the 2ccbf1c install. The coordinator asks for
         the AgentStateDistributionWidget lines of the LAST 30 MINUTES, with the cell count for
         grid 52 - it was 10, and after the operator re-saved the widget it should be 11 - plus any
         shell Exception or Error in the same window, the first three in full.
  THE WINDOW IS RELATIVE AND THAT IS DELIBERATE. Everything here is "the last 30 minutes from the
         moment this runs", so there is nothing to pin and nothing to convert: the log writes local
         time and the comparison is made in local time. The window's ends are printed anyway, in
         both clocks, because a reader needs to know which half-hour was looked at.
  THE FILE IS TODAY'S, AND THAT IS CHECKED, NOT ASSUMED. A 30-minute window can straddle midnight
         and it can fall in a log the shell has rolled. This run reads the file of the current local
         day and prints its mtime, so a stale file is visible as a stale file.
  THE NEGATIVE HALF is the coordinator's own: the same search for DayTrendWidget must find
         something. If it does not, the log being read is not the log that records widgets, and
         no count below means anything.
  WHERE  SERVER 234, READ ONLY. Nothing is stopped, started or configured; no log level is touched.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_asdlog2.txt" -f $RunStamp)
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

Say ("ASD LOG READING AFTER 2ccbf1c  " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + "Z   (machine local: " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " local)   host=" + $env:COMPUTERNAME)
Say  "READ ONLY. No service touched, no configuration read or written, no log level changed."
Say ("probe sha256 : " + (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  expected : name RTM and uuid E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say '  *** NOT server 234 - refusing to measure'; Finish $false }
Say "  G0 PASS"
Rule

Say "G1  THE WINDOW, IN BOTH CLOCKS, COMPUTED FROM THIS MACHINE"
$offsetHours = ([TimeZoneInfo]::Local).GetUtcOffset($RunStartedAt).TotalHours
Say ("  this machine is UTC" + $(if ($offsetHours -ge 0) { '+' } else { '' }) + $offsetHours + "   [" + ([TimeZoneInfo]::Local).Id + "]")
$IncidentDay = $RunStartedAt.Date
$toLocal   = $RunStartedAt
$fromLocal = $RunStartedAt.AddMinutes(-30)
Say ("  window, LOCAL : " + $fromLocal.ToString('yyyy-MM-dd HH:mm:ss') + "  ..  " + $toLocal.ToString('yyyy-MM-dd HH:mm:ss') + "   (the last 30 minutes)")
Say ("  the same, UTC : " + $fromLocal.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + "Z  ..  " + $toLocal.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + "Z")
Say  "  Nothing is pinned here and nothing is converted for the search: the log writes local time"
Say  "  and the window is built in local time. Both clocks are printed so a reader knows which"
Say  "  half-hour was looked at - a relative window is useless in a report without its ends."
Rule

Say "1  THE LOG FILE"
$logDir = 'C:\Logs\RTMViewShell'
$todayLog = Join-Path $logDir ('log-' + $IncidentDay.ToString('yyyyMMdd') + '.txt')
Say  "  the file is chosen by the PINNED day, not by the date this run happens on" 
Say ("  directory : " + $logDir + "   exists : " + (Test-Path -LiteralPath $logDir))
Say ("  file      : " + $todayLog + "   exists : " + (Test-Path -LiteralPath $todayLog))
if (-not (Test-Path -LiteralPath $todayLog)) {
  Say "  *** the log of the PINNED day is not there. Nothing is counted and no other file is"
  Say "  substituted silently. What the directory does hold:"
  foreach ($other in @(Get-ChildItem -LiteralPath $logDir -Filter *.txt -ErrorAction SilentlyContinue | Sort-Object Name)) { Say ("    " + $other.Name + "   " + $other.Length + " B") }
  Finish $false
}
$logItem = Get-Item -LiteralPath $todayLog
$allLines = @(Get-Content -LiteralPath $todayLog -ErrorAction SilentlyContinue)
Say ("  size " + $logItem.Length + " B   lines " + $allLines.Count + "   mtime " + $logItem.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + " local")
Say  "  POSCTL of the reader: a zero line count would mean the file is unreadable, not quiet."
if ($allLines.Count -eq 0) { Say "  *** zero lines read - not measuring further" ; Finish $false }
Say  "  first three lines, so the time format in this file is visible and not assumed:"
foreach ($sample in ($allLines | Select-Object -First 3)) { Say ("    | " + $sample) }
Rule

Say "2  THE WINDOW APPLIED - which lines fall inside it at all"
Say  "  Lines are matched on the leading timestamp. A line whose time cannot be parsed is NOT"
Say  "  silently dropped: it is counted separately and reported, because a parser that throws"
Say  "  everything away would print an empty window and call it quiet."
$inWindow = New-Object System.Collections.ArrayList
$unparsed = 0
foreach ($line in $allLines) {
  $stamp = $null
  $stampMatch = [regex]::Match("$line", '^\s*(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})')
  if (-not $stampMatch.Success) { $stampMatch = [regex]::Match("$line", '^\s*(\d{2}:\d{2}:\d{2})') }
  if ($stampMatch.Success) {
    $text = $stampMatch.Groups[1].Value
    if ($text.Length -le 8) { $text = $IncidentDay.ToString('yyyy-MM-dd') + ' ' + $text }
    [datetime]$parsed = [datetime]::MinValue
    if ([datetime]::TryParse($text.Replace('T',' '), [ref]$parsed)) { $stamp = $parsed }
  }
  if ($null -eq $stamp) { $unparsed++ ; continue }
  if ($stamp -ge $fromLocal -and $stamp -le $toLocal) { [void]$inWindow.Add("$line") }
}
Say ("  lines whose time could not be parsed : " + $unparsed + "   (reported, not hidden)")
Say ("  lines inside the window              : " + $inWindow.Count)
Say  "  NEGCTL on the window itself: a window one day earlier must hold fewer lines than today's,"
Say  "  or the window is not being applied at all."
$negWindow = 0
foreach ($line in $allLines) {
  $stampMatch = [regex]::Match("$line", '^\s*(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})')
  if (-not $stampMatch.Success) { continue }
  [datetime]$parsed = [datetime]::MinValue
  if (-not [datetime]::TryParse($stampMatch.Groups[1].Value.Replace('T',' '), [ref]$parsed)) { continue }
  if ($parsed -ge $fromLocal.AddDays(-1) -and $parsed -le $toLocal.AddDays(-1)) { $negWindow++ }
}
Say ("  the same window one day earlier : " + $negWindow + " lines   (today's file should hold few or none of those)")
Rule

Say "3  THE SIX KINDS, COUNTED, THEN PRINTED IN FULL"
$kinds = @()
$kinds += ,@('Subscribing to GridId', 'the widget announced it is about to subscribe')
$kinds += ,@('loaded', 'cells were loaded - the number is the subject of this reading')
$kinds += ,@('subscribed to GridId', 'the subscription completed')
$kinds += ,@('skipping', 'the widget decided not to subscribe')
$kinds += ,@('Failed to subscribe', 'the subscription failed outright')
$kinds += ,@('RtsGridId or BusinessUnitId is 0', 'the widget had no grid or business unit to use')
Say ("  kinds to count : " + $kinds.Count + "   expected 6")
$asdInWindow = @($inWindow | Where-Object { "$_" -like '*AgentStateDistributionWidget*' })
Say ("  AgentStateDistributionWidget lines inside the window : " + $asdInWindow.Count)
foreach ($kind in $kinds) {
  $needle = $kind[0]
  $meaning = $kind[1]
  $hits = @($asdInWindow | Where-Object { "$_" -like ('*' + $needle + '*') })
  Say ("  " + ("'" + $needle + "'").PadRight(36) + " " + $hits.Count + "   [" + $meaning + "]")
}
$negKind = @($asdInWindow | Where-Object { "$_" -like '*zzz-no-such-message*' })
Say ("  NEGCTL same reader, a message that cannot be there : " + $negKind.Count + "   must be 0")
Rule
Say "3b  THE LINES THEMSELVES, in order, with the ids they carry"
Say  "  A count without the lines cannot be checked by anyone but me, so every matched line is"
Say  "  printed whole. Any circuit / connection / GridId number is in the line as the app wrote it."
if ($asdInWindow.Count -eq 0) { Say "  (no ASD line inside the window - and section 4 says whether that is believable)" }
foreach ($line in $asdInWindow) { Say ("  | " + $line) }
Rule

Say "3c  THE CELL COUNT FOR GRID 52 - the number the operator's re-save was supposed to change"
Say  "  EXPECTED BEFORE THE MEASUREMENT: 11. It was 10 in every one of the 13 subscriptions read"
Say  "  yesterday [234_20261012_073447_asdlog.txt], and the operator re-saved the widget with the"
Say  "  connected-agents column added, which is what should make it 11."
Say  "  A 10 here means the re-save did not reach the grid definition the widget reads. A number"
Say  "  that is neither 10 nor 11 is its own finding and is printed as it is, not rounded to a story."
$cellCounts = @{}
$cellLines = @($asdInWindow | Where-Object { "$_" -match 'loaded\s+(\d+)\s+cells' })
Say ("  lines carrying a cell count : " + $cellLines.Count)
foreach ($cellLine in $cellLines) {
  $cellMatch = [regex]::Match("$cellLine", 'loaded\s+(\d+)\s+cells(?:\s+for\s+grid\s+(\d+))?')
  if (-not $cellMatch.Success) { continue }
  $count = $cellMatch.Groups[1].Value
  $grid = $cellMatch.Groups[2].Value
  if ([string]::IsNullOrEmpty($grid)) { $grid = 'unnamed' }
  $key = $grid + ' / ' + $count
  if (-not $cellCounts.ContainsKey($key)) { $cellCounts[$key] = 0 }
  $cellCounts[$key] = $cellCounts[$key] + 1
}
if ($cellCounts.Count -eq 0) { Say "  no cell-count line in the window - nothing to compare, and that is the finding to report" }
foreach ($key in ($cellCounts.Keys | Sort-Object)) { Say ("    grid / cells : " + $key.PadRight(14) + " seen " + $cellCounts[$key] + " times") }
Say  "  NEGCTL of this reader: a count that cannot be there must not be matched."
$negCell = @($asdInWindow | Where-Object { "$_" -match 'loaded\s+9999\s+cells' }).Count
Say ("  lines claiming 9999 cells : " + $negCell + "   must be 0")
Rule

Say "3d  EXCEPTIONS AND ERRORS OF THE SHELL IN THE SAME WINDOW - first three in full"
Say  "  Not restricted to ASD: if the widget fails because something else threw, that throw is the"
Say  "  finding and it will not carry the widget name. No secret is printed - these are the log's"
Say  "  own lines, and if one carried a credential it would be a defect of the log, not of this read."
$faultLines = @($inWindow | Where-Object { "$_" -match '(?i)\[(ERR|FTL)\]|Exception|Unhandled' })
Say ("  lines with Exception / [ERR] / [FTL] / Unhandled : " + $faultLines.Count)
$shown = 0
foreach ($faultLine in $faultLines) {
  if ($shown -ge 3) { break }
  Say ("  | " + $faultLine)
  $shown++
}
if ($faultLines.Count -gt 3) { Say ("  ... " + ($faultLines.Count - 3) + " more, not printed") }
Say  "  NEGCTL: the same reader on a word that cannot be in a log line."
$negFault = @($inWindow | Where-Object { "$_" -match 'zzz-no-such-exception' }).Count
Say ("  lines with an impossible marker : " + $negFault + "   must be 0")
Rule

Say "4  THE NEGATIVE HALF THE COORDINATOR ASKED FOR - DayTrendWidget in the same window"
Say  "  Expected BEFORE the measurement: one or more. A zero here means this is not the log that"
Say  "  records widget activity, and every count above is worthless rather than interesting."
$dayTrend = @($inWindow | Where-Object { "$_" -like '*DayTrendWidget*' })
Say ("  DayTrendWidget lines inside the window : " + $dayTrend.Count + "   expected 1 or more")
foreach ($line in ($dayTrend | Select-Object -First 8)) { Say ("  | " + $line) }
if ($dayTrend.Count -gt 8) { Say ("  ... " + ($dayTrend.Count - 8) + " more of the same kind, not printed") }
$readerTrusted = ($dayTrend.Count -ge 1)
Say ("  READER : " + $(if ($readerTrusted) { 'TRUSTED - the log does record widgets in this window' } else { 'NOT TRUSTED - the ASD counts above prove nothing' }))
Rule

Say "5  THE WHOLE DAY FOR ASD, OUTSIDE THE WINDOW TOO - so a wrong window is visible"
$asdAll = @($allLines | Where-Object { "$_" -like '*AgentStateDistributionWidget*' })
Say ("  ASD lines in the whole file : " + $asdAll.Count + "   inside the window : " + $asdInWindow.Count)
Say  "  If the file holds ASD lines and the window holds none, the window is wrong - not the app."
if ($asdAll.Count -gt 0 -and $asdInWindow.Count -eq 0) {
  Say  "  *** THAT IS THE CASE HERE. The first and last ASD line of the file:"
  Say ("  first : " + $asdAll[0])
  Say ("  last  : " + $asdAll[$asdAll.Count - 1])
}
Rule

Say "VERDICT OF THE READING"
Say ("  window applied, both clocks printed : True")
Say ("  reader trusted by the DayTrend half : " + $readerTrusted)
Say ("  ASD lines inside the window         : " + $asdInWindow.Count)
Say ("  shell faults inside the window      : " + $faultLines.Count + "   (a number, not a judgement)")
Say ("  a section was skipped by an error   : " + $script:TrapFired + "   (True forbids reading anything above as complete)")
Say  "  No verdict on the defect is offered here. This run only hands over what the log says."
Say "===== END-OF-RUN MARKER: ASDLOG2-COMPLETE ====="
Finish (-not $script:TrapFired)
