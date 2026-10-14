<#
  PROBE  probe_234_20261014_tzgate.ps1
  READ-ONLY. Nothing is restarted, started, stopped or configured.
  THE QUESTION, from coordinator 2026-10-14T11:46:52Z, and he is right against my own two attempts:
    the 21 "mixed TimeZones" lines in the first 310 s after the restart are 21 queues x 1 - the
    one-time burst of a gate that lives in process memory. My first predicate compared a 5-minute
    count with an hourly ceiling (too weak). My "fix" multiplied those same 5 minutes by 12 (wrong
    in the other direction: it extrapolates a startup burst). Neither answers the question.
  THE PREDICATE THAT DOES: in the window that starts 5 minutes after the process start, a line is a
    VIOLATION unless the dominant zone it names DIFFERS from the one last seen for that same queue.
    A queue whose dominant zone genuinely changed is expected to write again; a queue repeating the
    same zone is the gate failing. So this probe does not count lines - it classifies them.
  THE WINDOW IS NAMED, NOT ASSUMED. The coordinator asked for start+5min to start+65min, "or
    however much has passed - name it". The process start is MEASURED here, and the steady window
    runs from start+5min to the moment this probe reads the file. Its length is printed, and every
    rate is printed with its window, because a rate without its window is a number without a path.
  THE NEGATIVE HALF: the same shape measured over the 60 minutes BEFORE the install, where the rate
    was 42 per minute. If that window comes out small, MY READER is wrong and nothing below counts -
    which is why it is measured rather than quoted.
  THE STAMP FORM is the shell Serilog default, yyyy-MM-dd HH:mm:ss.fff zzz, and the count of lines
    whose stamp parsed is the positive control for every number here.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$LOG_DIR = 'C:\Logs\RTMViewShell'
$BurstMinutes = 5
$PreWindowMinutes = 60
$TzRateBeforeKnown = 42

$RunStartedAt = Get-Date
Start-Probe -Name 'tzgate' -Title 'READING on 234: does WfmLogGate hold after the startup burst'
Say 'READ-ONLY. Nothing is restarted, started, stopped or configured by this run.'
Rule
Assert-Machine

function Stamp-OfLine([string]$line) {
  if ("$line" -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') {
    try { return [datetime]::ParseExact("$line".Substring(0,19), 'yyyy-MM-dd HH:mm:ss', $null) } catch { return $null }
  }
  return $null
}
function Queue-OfLine([string]$line) {
  $match = [regex]::Match("$line", 'workgroup (.+?) has mixed TimeZones')
  if ($match.Success) { return $match.Groups[1].Value }
  return ''
}
function Zone-OfLine([string]$line) {
  $match = [regex]::Match("$line", 'using dominant (\S+)')
  if ($match.Success) { return $match.Groups[1].Value }
  return ''
}

Say '1  WHEN THE SHELL PROCESS STARTED - measured, because every window below hangs off it'
# The 14:54 run of this probe died inside this section and left 20 lines without a cause, because
# the report was only flushed at the next explicit call. Two fixes: _core.ps1 now flushes on every
# Rule, and this section reports WHY it cannot read a value instead of throwing.
$shellPid = 0
$processStart = $null
try {
  $shellService = Get-CimInstance Win32_Service -Filter "Name='RTMViewShell'" -ErrorAction Stop
  if ($null -ne $shellService) { $shellPid = [int]$shellService.ProcessId }
  Say ('  RTMViewShell pid : ' + $shellPid)
} catch { Say ('  *** cannot read the service: ' + $_.Exception.Message) }
if ($shellPid -gt 0) {
  try {
    $processRow = Get-CimInstance Win32_Process -Filter ("ProcessId=" + $shellPid) -ErrorAction Stop
    if ($null -ne $processRow) { $processStart = $processRow.CreationDate }
    Say ('  read through Win32_Process.CreationDate, not Get-Process.StartTime - the latter can be')
    Say ('  refused for a LocalSystem service even to an administrator')
  } catch { Say ('  *** cannot read the process row: ' + $_.Exception.Message) }
}
if ($null -eq $processStart) { Say '  *** cannot read the process start time - every window below would be guesswork. STOP.' ; Finish $false }
Say ('  process started  : ' + $processStart.ToString('yyyy-MM-dd HH:mm:ss') + ' local')
Say  '  context, not the anchor: the install wrote its ledger line at 11:27:04Z = 14:27:04 local.'
$burstFrom = $processStart
$burstTo = $processStart.AddMinutes($BurstMinutes)
$steadyFrom = $burstTo
$steadyTo = $RunStartedAt
$preTo = $processStart.AddMinutes(-5)
$preFrom = $preTo.AddMinutes(-1 * $PreWindowMinutes)
$steadyMinutes = [math]::Round(($steadyTo - $steadyFrom).TotalMinutes, 2)
Say ''
Say  '  THE THREE WINDOWS, printed before the file is read:'
Say ('    PRE    ' + $preFrom.ToString('HH:mm:ss') + ' -> ' + $preTo.ToString('HH:mm:ss') + '   (' + $PreWindowMinutes + ' min, ending 5 min before the restart to keep the shutdown out)')
Say ('    BURST  ' + $burstFrom.ToString('HH:mm:ss') + ' -> ' + $burstTo.ToString('HH:mm:ss') + '   (' + $BurstMinutes + ' min - here one line per queue is EXPECTED)')
Say ('    STEADY ' + $steadyFrom.ToString('HH:mm:ss') + ' -> ' + $steadyTo.ToString('HH:mm:ss') + '   (' + $steadyMinutes + ' min - this is the window that answers the question)')
Say ('  The coordinator asked for start+5 to start+65. Only ' + $steadyMinutes + ' min have passed since start+5,')
Say  '  so that is the window measured, and it is named here rather than reported as an hour.'
if ($steadyMinutes -lt 5) { Say '  *** less than 5 minutes of steady window exist yet - the answer would be thin. Reported as such.' }
Rule

Say '2  READING THE FILE ONCE, classifying every TZ line'
$logFiles = @(Get-ChildItem -LiteralPath $LOG_DIR -File -Filter 'log-*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
Say ('  files in the sink : ' + $logFiles.Count + '   (POSCTL - a zero means the filter is wrong)')
if ($logFiles.Count -eq 0) { Say '  *** no log file - NOT MEASURED' ; Finish $false }
$logFile = $logFiles[0].FullName
Say ('  reading : ' + $logFile + '   ' + (Get-Item -LiteralPath $logFile).Length + ' B')

$totalLines = 0
$stampedLines = 0
$tzPre = 0
$tzBurst = 0
$tzSteady = 0
$burstQueues = @{}
$lastZoneSeen = @{}
$steadySameZone = @()
$steadyChangedZone = @()
# Read-SharedLines, not [IO.File]::ReadLines: the 15:02 run died here because the shell holds this
# file open with FileShare.ReadWrite and ReadLines asks for FileShare.Read only. The helper now
# lives in _core.ps1, so no probe has to rediscover this.
foreach ($line in (Read-SharedLines $logFile)) {
  $totalLines++
  $stamp = Stamp-OfLine $line
  if ($null -eq $stamp) { continue }
  $stampedLines++
  if (-not ("$line".Contains('mixed TimeZones'))) { continue }
  $queue = Queue-OfLine $line
  $zone = Zone-OfLine $line
  if (($stamp -ge $preFrom) -and ($stamp -le $preTo)) { $tzPre++ ; continue }
  if (($stamp -ge $burstFrom) -and ($stamp -lt $burstTo)) {
    $tzBurst++
    if ($queue -ne '') { $burstQueues[$queue] = $zone ; $lastZoneSeen[$queue] = $zone }
    continue
  }
  if (($stamp -ge $steadyFrom) -and ($stamp -le $steadyTo)) {
    $tzSteady++
    $knownZone = ''
    if ($lastZoneSeen.ContainsKey($queue)) { $knownZone = $lastZoneSeen[$queue] }
    if (($knownZone -ne '') -and ($knownZone -eq $zone)) { $steadySameZone += "$line" }
    else { $steadyChangedZone += ("$line" + '   [previous zone for this queue: ' + $(if ($knownZone -eq '') { 'none seen in the burst' } else { $knownZone }) + ']') }
    if ($queue -ne '') { $lastZoneSeen[$queue] = $zone }
  }
}
Say ('  lines read : ' + $totalLines + '    with a parsed stamp : ' + $stampedLines + '   (POSCTL - a zero here voids everything)')
Rule

Say '3  THE NEGATIVE HALF FIRST - the 60 minutes BEFORE the install'
Say ('  "mixed TimeZones" in PRE : ' + $tzPre + '   = ' + [math]::Round($tzPre / [double]$PreWindowMinutes, 2) + ' per minute')
Say ('  known from my 11:43 reading : about ' + $TzRateBeforeKnown + ' per minute')
$preLooksRight = ($tzPre -gt (10 * $PreWindowMinutes))
Say ('  the pre-window looks like the old flood : ' + $preLooksRight)
Say  '  If that is False, MY READER is wrong and nothing below counts. It is measured here and not'
Say  '  quoted from the earlier run for exactly that reason.'
Rule

Say '4  THE BURST - one line per queue is expected here, and it is not a defect'
Say ('  "mixed TimeZones" in BURST : ' + $tzBurst)
Say ('  distinct queues in the burst : ' + $burstQueues.Count)
Say ('  lines per queue : ' + $(if ($burstQueues.Count -gt 0) { [math]::Round($tzBurst / [double]$burstQueues.Count, 2) } else { 'n/a' }) + '   (1.0 means exactly once per queue, which is the design)')
Rule

Say '5  THE STEADY WINDOW - the answer. A line here is a VIOLATION unless the zone changed.'
Say ('  "mixed TimeZones" in STEADY : ' + $tzSteady + '   over ' + $steadyMinutes + ' min')
Say ('  of them REPEATING a zone already seen for that queue : ' + $steadySameZone.Count + '   <- these are the violations')
Say ('  of them naming a DIFFERENT zone than before          : ' + $steadyChangedZone.Count + '   <- expected, the queue dominant zone moved')
$showCount = [math]::Min(10, $steadySameZone.Count)
if ($showCount -gt 0) { Say '  the repeating lines themselves, up to ten:' }
for ($sameIndex = 0; $sameIndex -lt $showCount; $sameIndex++) { Say ('    | ' + $steadySameZone[$sameIndex]) }
if ($steadySameZone.Count -gt $showCount) { Say ('    ... and ' + ($steadySameZone.Count - $showCount) + ' more') }
$changedShow = [math]::Min(10, $steadyChangedZone.Count)
if ($changedShow -gt 0) { Say '  the zone-change lines, up to ten (these are allowed):' }
for ($changedIndex = 0; $changedIndex -lt $changedShow; $changedIndex++) { Say ('    | ' + $steadyChangedZone[$changedIndex]) }
if ($steadyChangedZone.Count -gt $changedShow) { Say ('    ... and ' + ($steadyChangedZone.Count - $changedShow) + ' more') }
$gateHolds = ($steadySameZone.Count -eq 0)
Say ''
Say ('  GATE HOLDS : ' + $gateHolds)
if (-not $gateHolds) {
  Say  '  A repeat with the same dominant zone after the burst means the gate did not remember, and'
  Say  '  that is a defect of WfmLogGate - the coordinator says it would then be his to backend.'
}
Say ('  NEGCTL, so a zero above cannot mean a blind reader: the same reader, the same needle and the')
Say ('  same parse found ' + $tzPre + ' lines in PRE and ' + $tzBurst + ' in BURST.')
Rule

Say 'WHAT THIS READING SAYS'
Say ('  trap fired during the run : ' + (Test-TrapFired))
Say ('  PRE   ' + $preFrom.ToString('HH:mm') + '-' + $preTo.ToString('HH:mm') + ' : ' + $tzPre + ' lines, ' + [math]::Round($tzPre / [double]$PreWindowMinutes, 2) + '/min   (the flood before the flight)')
Say ('  BURST ' + $burstFrom.ToString('HH:mm') + '-' + $burstTo.ToString('HH:mm') + ' : ' + $tzBurst + ' lines over ' + $burstQueues.Count + ' queues   (expected, by design)')
Say ('  STEADY ' + $steadyFrom.ToString('HH:mm') + '-' + $steadyTo.ToString('HH:mm') + ' (' + $steadyMinutes + ' min) : ' + $tzSteady + ' lines, of which ' + $steadySameZone.Count + ' repeat a known zone')
Say ('  the window is ' + $steadyMinutes + ' min, NOT an hour, and no number here is multiplied up to one')
Say ('  GATE HOLDS IN THE MEASURED WINDOW : ' + $gateHolds)
Say '===== END-OF-RUN MARKER: TZGATE-COMPLETE ====='
Finish ($stampedLines -gt 0)
