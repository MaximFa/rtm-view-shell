<#
  PROBE  probe_234_20261011_asdlog.ps1
  SHAPE  written for this question, not copied from a flight probe: it installs nothing and the
         only shape it borrows is the gate-and-negative-half discipline.
  UNIT   PR234-V4-ASD-VIEWER-CONNECT-01. The coordinator asks for the shell log lines about
         AgentStateDistributionWidget in the window 09:58-10:25Z, counted by kind, with the
         circuit/connection id where the line carries one.
  THE DAY IS PINNED, NOT TAKEN FROM THE CLOCK. The viewer sessions were on 2026-10-11 and this
         probe may run on a later day. A probe that reads "today" would open the wrong file, find an
         empty window and hand that emptiness over as a finding. Measured on myself 2026-10-05: the
         startspan probe read the wrong day and reported 9415 lines of the wrong evening.
  THE CLOCK IS THE SECOND TRAP. The log writes MACHINE-LOCAL time and the question is in UTC.
         This probe computes the offset from the machine itself and prints the window in both,
         rather than assuming +3. A window converted the wrong way would return nothing and the
         nothing would look like a finding.
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
$ReportPath = Join-Path $OutputDir ("234_{0}_asdlog.txt" -f $RunStamp)
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

Say ("ASD VIEWER LOG READING  " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + "Z   (machine local: " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " local)   host=" + $env:COMPUTERNAME)
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
# THE PINNED DAY of the viewer sessions. Never $RunStartedAt.Date - see the header.
$IncidentDay = [datetime]::ParseExact('20261011', 'yyyyMMdd', $null)
Say ("  incident day, PINNED : " + $IncidentDay.ToString('yyyy-MM-dd') + "   (this run happens on " + $RunStartedAt.ToString('yyyy-MM-dd') + " local)")
$fromUtc = [datetime]::SpecifyKind($IncidentDay.AddHours(9).AddMinutes(58), 'Utc')
$toUtc   = [datetime]::SpecifyKind($IncidentDay.AddHours(10).AddMinutes(25), 'Utc')
$fromLocal = $fromUtc.ToLocalTime()
$toLocal   = $toUtc.ToLocalTime()
Say ("  asked, UTC   : " + $fromUtc.ToString('yyyy-MM-dd HH:mm') + "Z  ..  " + $toUtc.ToString('yyyy-MM-dd HH:mm') + "Z")
Say ("  the log writes LOCAL time, so the window to look for is:")
Say ("  to search for : " + $fromLocal.ToString('yyyy-MM-dd HH:mm') + " local  ..  " + $toLocal.ToString('yyyy-MM-dd HH:mm') + " local")
Say  "  A window converted the wrong way returns nothing, and that nothing looks exactly like a"
Say  "  finding. This is why the conversion is printed before anything is counted."
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
$kinds += ,@('loaded', 'cells were loaded')
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
Say ("  a section was skipped by an error   : " + $script:TrapFired + "   (True forbids reading anything above as complete)")
Say  "  No verdict on the defect is offered here. This run only hands over what the log says."
Say "===== END-OF-RUN MARKER: ASDLOG-COMPLETE ====="
Finish (-not $script:TrapFired)
