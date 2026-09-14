#Requires -Version 5.1
<#
  PROBE 234 / corpus for the acceptance measurement - SLICES plus POSCTL. READ ONLY.
  WHERE IT RUNS : server 234 (machine RTM). Name and hardware UUID are a gate.
  WHAT IT DOES  : reads two log files and writes three text files into C:\RTMView-Ops\output. It
                  restarts NOTHING - the window that starts at 22:17:52 dies at the first restart, and
                  this run must not be the one that kills it. No install, no config write, no database,
                  no password. C:\IceDash, the production RTM.Twilio, legacy RTM and
                  C:\Program Files\CcDashboard are not touched, and neither is C:\Windows\System32\logs
                  (the FOREIGN Shell writes there) nor C:\Logs\RTM (legacy).
  WHY POSCTL    : if only the window travelled, a needle absent from it would be indistinguishable from
                  a needle the matcher cannot find at all. That happened twice today. So each needle is
                  counted over the WHOLE file AND inside the window, with its file named on the line.
                  zero/zero -> matcher suspect, not a finding. zero-in-window/non-zero-outside -> finding.
  GATE ADDED IN v2 : a log that is open for writing by a live service cannot be read with a plain
                  StreamReader - the open is refused, and under ErrorActionPreference Continue the
                  refusal is silent, so the run prints a confident ZERO for every needle. v1 did exactly
                  that. Now the file is opened with FileShare.ReadWrite, and "non-empty file, zero lines
                  read" is a HARD FAIL instead of a report.
  WHAT IT DOES NOT DO : it does not filter the slices by content and it does not interpret the numbers.
                  A corpus I have already filtered is an interpretation, and the verdict on
                  PR234-SHELL-RESUB-01 belongs to shell, not to devops.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir   = 'C:\RTMView-Ops\output'
# The window start is MEASURED, not typed: it is the start time of the engine process itself.
# A hardcoded time silently measures the wrong window as soon as anything restarts again.
$WINSTART = $null
$SENTINEL = -999

$SHELLPIN = [datetime]'2026-09-13 22:15:05'   # the Shell must NOT have restarted since this
$ENGLOG = 'C:\RTMView\RTM\Logs\RTM.log'
$SHLOG  = 'C:\Logs\RTMViewShell\log-20260913.txt'

$NEEDLES = @(
    'AgentGridWidget: subscribed to union',
    'connection closed','reconnecting tenant','reconnected tenant','init union',
    'no subscribers, dead connection released',
    'replacing a disconnected connection on subscribe',
    '<<getUsers unionId=','Groups.Add UnionId','<<ChangedUnionUsersData count=',
    'refreshUnions Add','LoadData union=','init GridId=',' In use',
    'SERVER => A client connected','client disconnected','ZZZ-marker-negctl')

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_corpus-T3-report.txt')
$engOut = Join-Path $OutDir '234_20260913_T3_engine-window.txt'
$shOut  = Join-Path $OutDir '234_20260913_T3_shell-window.txt'
$posOut = Join-Path $OutDir '234_20260913_T3_posctl.txt'

$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (corpus written; numbers are NOT interpreted here)' }
                       else        { 'VERDICT: FAIL (instrument unsound)' }))
    Flush
    Write-Host ''
    Write-Host ('REPORT       : ' + $outf)
    Write-Host ('ENGINE WINDOW: ' + $engOut)
    Write-Host ('SHELL WINDOW : ' + $shOut)
    Write-Host ('POSCTL       : ' + $posOut)
    if ($pass) { exit 0 } else { exit 1 }
}
function Safe-Count($c) { if ($null -eq $c) { return $SENTINEL } return @($c).Count }

$FORMATS = @('yyyy-MM-dd HH:mm:ss,fff','yyyy-MM-dd HH:mm:ss.fff','yyyy-MM-dd HH:mm:ss')
function Get-LineTime($text) {
    $t = "$text".TrimStart()
    if ($t.Length -lt 19) { return $null }
    foreach ($len in @(23, 19)) {
        if ($t.Length -lt $len) { continue }
        $head = $t.Substring(0, $len)
        foreach ($fmt in $FORMATS) {
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParseExact($head, $fmt, [Globalization.CultureInfo]::InvariantCulture,
                                          [Globalization.DateTimeStyles]::None, [ref]$parsed)) { return $parsed }
        }
    }
    return $null
}

Say '===== 0  machine, instrument, parser control ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
Say ('  assignment gate : unassigned {0} (want {1})' -f (Safe-Count $null), $SENTINEL)

Say ''
Say '===== 0b  the window, MEASURED from the running processes ====='
$starts = @{}
foreach ($svc in @('RTMService','RTMTwilio_1','RTMViewShell')) {
    foreach ($pr in @(Get-WmiObject Win32_Service -Filter ("Name='" + $svc + "'") -ErrorAction SilentlyContinue)) {
        if ($pr.ProcessId -gt 0) {
            $po = Get-Process -Id $pr.ProcessId -ErrorAction SilentlyContinue
            if ($po) { $starts[$svc] = $po.StartTime; Say ('  {0,-14} pid {1,-7} started {2}' -f $svc, $pr.ProcessId, $po.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
        }
    }
}
if (-not $starts.ContainsKey('RTMService')) { Say '  *** engine process not found - cannot bound the window'; Fin $false }
$WINSTART = $starts['RTMService']
Say ('  window starts at the ENGINE start : {0}' -f $WINSTART.ToString('yyyy-MM-dd HH:mm:ss'))
if ($starts.ContainsKey('RTMViewShell')) {
    $shellMoved = ($starts['RTMViewShell'] -gt $SHELLPIN)
    Say ('  shell started {0} ; expected {1} ; MOVED -> {2}' -f $starts['RTMViewShell'].ToString('yyyy-MM-dd HH:mm:ss'), $SHELLPIN.ToString('yyyy-MM-dd HH:mm:ss'), $shellMoved)
    if ($shellMoved) {
        Say '  *** THE SHELL RESTARTED. The subscription under test no longer predates the engine restart,'
        Say '  *** so this corpus would measure a fresh subscription again - exactly the empty run we just had.'
        Fin $false
    }
}

$ctlOk = $true
$ctlBefore = $WINSTART.AddMinutes(-1)
$ctlAfter  = $WINSTART.AddMinutes(1)
foreach ($c in @(@{T=($ctlBefore.ToString('yyyy-MM-dd HH:mm:ss') + ',001 [5] INFO x'); W='BEFORE'},
                 @{T=($ctlAfter.ToString('yyyy-MM-dd HH:mm:ss')  + ',001 [5] INFO x'); W='AFTER'},
                 @{T=($ctlBefore.ToString('yyyy-MM-dd HH:mm:ss') + '.001 +03:00 [INF] x'); W='BEFORE'},
                 @{T=($ctlAfter.ToString('yyyy-MM-dd HH:mm:ss')  + '.001 +03:00 [INF] x'); W='AFTER'})) {
    $tm = Get-LineTime $c.T
    $got = $(if ($null -eq $tm) { 'UNPARSED' } elseif ($tm -ge $WINSTART) { 'AFTER' } else { 'BEFORE' })
    if ($got -ne $c.W) { $ctlOk = $false; Say ('  parser control FAILED on: {0} -> {1}' -f $c.T, $got) }
}
Say ('  parser control (both log formats, synthetic lines) : {0}   expected True' -f $ctlOk)
if (-not $ctlOk) { Say '  *** slicing broken - stopping before writing a corpus nobody can trust'; Fin $false }
Say ('  READ ONLY: nothing is restarted by this run; the window above was set by the restart, not by me')

Say ''
Say '===== 1  the two files, taken from the services own declarations (runbook 13.1) ====='
$files = @(
    [pscustomobject]@{ Tag='engine'; Path=$ENGLOG; Out=$engOut },
    [pscustomobject]@{ Tag='shell';  Path=$SHLOG;  Out=$shOut }
)
foreach ($f in $files) {
    if (Test-Path -LiteralPath $f.Path) {
        $fi = Get-Item -LiteralPath $f.Path
        Say ('  {0,-7} {1}   {2} bytes   mtime {3}' -f $f.Tag, $f.Path, $fi.Length, $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    } else { Say ('  {0,-7} {1}   *** NOT PRESENT' -f $f.Tag, $f.Path) }
}
Say '  NOT read by this probe: C:\Windows\System32\logs (foreign Shell) , C:\Logs\RTM (legacy install)'

$total = @{}
$inwin = @{}
foreach ($n in $NEEDLES) { $total[$n] = @{}; $inwin[$n] = @{} }

Say ''
Say '===== 2  reading, slicing, counting - one pass per file ====='
$ok = $true
foreach ($f in $files) {
    $name = [IO.Path]::GetFileName($f.Path)
    foreach ($n in $NEEDLES) { $total[$n][$name] = 0; $inwin[$n][$name] = 0 }
    if (-not (Test-Path -LiteralPath $f.Path)) { Say ('  {0} : absent, skipped' -f $f.Tag); $ok = $false; continue }
    $lines = 0; $win = 0; $unparsed = 0
    $sw = New-Object IO.StreamWriter($f.Out, $false, (New-Object Text.UTF8Encoding($false)))
    # The log is OPEN FOR WRITING by a live service. A plain StreamReader(path) asks for FileShare.Read
    # and is refused - and with ErrorActionPreference Continue that refusal is SILENT: $sr stays null,
    # ReadLine() on null returns null, and the run reports a confident ZERO for every needle.
    # That is exactly what happened on the first attempt. Share ReadWrite, and gate on the result.
    $fs = $null
    try { $fs = New-Object IO.FileStream($f.Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite) }
    catch { Say ('  *** cannot open {0} : {1}' -f $f.Path, $_.Exception.Message); $sw.Close(); $ok = $false; continue }
    if ($null -eq $fs) { Say '  *** file stream is null - refusing to report zeros'; $sw.Close(); $ok = $false; continue }
    $sr = New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8)
    $inWindow = $false
    while ($null -ne ($line = $sr.ReadLine())) {
        $lines++
        $t = Get-LineTime $line
        if ($null -eq $t) { $unparsed++ }
        else { $inWindow = ($t -ge $WINSTART) }
        if ($inWindow) { $sw.WriteLine($line); $win++ }
        foreach ($n in $NEEDLES) {
            if ($line.Contains($n)) {
                $total[$n][$name] = $total[$n][$name] + 1
                if ($inWindow) { $inwin[$n][$name] = $inwin[$n][$name] + 1 }
            }
        }
    }
    $sr.Close(); $fs.Close(); $sw.Close()
    Say ('  {0,-7} {1,-22} lines {2}   in window {3}   lines with no parsable time {4}' -f $f.Tag, $name, $lines, $win, $unparsed)
    $sizeOnDisk = (Get-Item -LiteralPath $f.Path).Length
    Say ('          gate: file is {0} bytes, lines read {1}' -f $sizeOnDisk, $lines)
    if (($sizeOnDisk -gt 0) -and ($lines -eq 0)) {
        Say '  *** READ NOTHING FROM A NON-EMPTY FILE. Every count below would be a false zero.'
        $ok = $false
    }
    Say ('          slice -> {0}' -f $f.Out)
    Say '          (a line without its own timestamp inherits the state of the last timestamped line -'
    Say '           that is how stack traces stay attached to the line that threw them)'
}
Flush

Say ''
Say '===== 3  POSCTL - every needle, whole file AND window, per file ====='
$pos = New-Object System.Collections.ArrayList
[void]$pos.Add('POSCTL for the acceptance window starting ' + $WINSTART.ToString('yyyy-MM-dd HH:mm:ss'))
[void]$pos.Add('needle                            file                    total   in-window')
[void]$pos.Add('-------------------------------------------------------------------------------')
foreach ($n in $NEEDLES) {
    foreach ($f in $files) {
        $name = [IO.Path]::GetFileName($f.Path)
        $line = ('{0,-33} {1,-22} {2,7} {3,11}' -f $n, $name, $total[$n][$name], $inwin[$n][$name])
        [void]$pos.Add($line)
        Say ('  ' + $line)
    }
}
[void]$pos.Add('')
[void]$pos.Add('READING RULE, stated so that no one has to guess it:')
[void]$pos.Add('  total 0 and window 0      -> MATCHER SUSPECT. Its zero is not a finding.')
[void]$pos.Add('  total >0 and window 0     -> a finding: the thing happens, but not in this window.')
[void]$pos.Add('  window >0                 -> it happened after the engine-only restart at 22:17:52.')
[void]$pos.Add('  ZZZ-marker-negctl must be 0 everywhere; if it is not, the whole instrument is void.')
[IO.File]::WriteAllLines($posOut, $pos, (New-Object Text.UTF8Encoding($false)))
Say ('  written -> {0}' -f $posOut)

Say ''
Say '===== 4  the window is still alive - proven, not assumed ====='
foreach ($s in @('RTMService','RTMTwilio_1','RTMViewShell')) {
    foreach ($pr in @(Get-WmiObject Win32_Service -Filter ("Name='" + $s + "'") -ErrorAction SilentlyContinue)) {
        if ($pr.ProcessId -gt 0) {
            $po = Get-Process -Id $pr.ProcessId -ErrorAction SilentlyContinue
            if ($po) { Say ('  {0,-14} pid {1,-7} started {2}' -f $s, $pr.ProcessId, $po.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
        }
    }
}
Say '  expected: engine 22:17:52 , adapter 22:18:01 , shell 22:15:05 (shell BEFORE the window, unchanged)'
Say '  if the shell start time has moved, the window is void and the measurement must be re-taken.'

Say ''
Say '===== what this run does NOT do ====='
Say '  It does not filter the slices by content, and it does not interpret a single number.'
Say '  The verdict on PR234-SHELL-RESUB-01 belongs to shell-0912.'
Fin $ok
