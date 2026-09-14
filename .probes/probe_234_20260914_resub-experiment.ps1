#Requires -Version 5.1
<#
  PROBE 234 / RESUB EXPERIMENT on the FIXED wiring. WRITES: one service restart (RTMService only)
  and four report files. Nothing else.
  WHERE IT RUNS : server 234 (machine RTM). Name and hardware UUID are a gate.
  BOUNDARIES    : it restarts ONLY RTMService. It does NOT touch the adapter - the ENGINE owns the
                  adapter's lifecycle through RTM:AdaptorServiceName and brings it up itself when it is
                  ready [operator, 2026-09-14]; the old "always restart the adapter too" rule is
                  WITHDRAWN. It does NOT touch the Shell, does not close the operator's tab, does not
                  write configs, does not touch the database, C:\IceDash, the production RTM.Twilio,
                  legacy RTM or C:\Program Files\CcDashboard.
  THE QUESTION  : does OUR Shell re-subscribe by itself after OUR engine restarts - now that the two are
                  actually connected to each other. Everything measured before the port move was taken
                  against an engine the Shell was never talking to.
  PRECONDITIONS, checked BEFORE the restart and fatal if missing:
      P1  the Shell logged `AgentGridWidget: subscribed to union <N>` - there IS a subscription
      P2  a socket from the Shell to 8089 whose SERVER end is our engine pid - it is OUR engine
      Either one missing -> STOP, no restart. Without both, the run would measure an empty room again,
      which is exactly how the last two attempts were spent.
  READINESS is polled as a SIGNAL (listener on 8089 + the pipe) until it appears or a stated timeout -
      not a fixed sleep. Calling the engine dead at sixteen seconds was a false red once already today.
  ROLLOVER: the engine log rolls BY DATE (log4net rollingStyle=Date). If the window crosses midnight the
      slice takes BOTH files. Every slice prints its CORPUS BOUNDARY - the first and last timestamp of
      the source - as its first lines, so "the window is empty" can never be confused with "the window
      is in another file".
  NUMBERS ARE NOT INTERPRETED HERE. The verdict on PR234-SHELL-RESUB-01 belongs to shell-0912.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir   = 'C:\RTMView-Ops\output'
$SENTINEL = -999
$ENGDIR   = 'C:\RTMView\RTM\Logs'
$ENGLOG   = 'C:\RTMView\RTM\Logs\RTM.log'
$SHELLCFG = 'C:\RTMView\Shell\appsettings.json'
$PORT     = 8089
$OLDPORT  = 8088
$READYMAX = 180
$SETTLE   = 90

$ENGNEEDLES = @('<<getUsers unionId=','Groups.Add UnionId','init GridId=','<<ChangedUnionUsersData count=',
                'SERVER => A client connected','client disconnected','RTM Start',' In use','ZZZ-marker-negctl')
$SHNEEDLES  = @('AgentGridWidget: subscribed to union','connection closed','reconnecting tenant',
                'reconnected tenant','init union','no subscribers, dead connection released',
                'replacing a disconnected connection on subscribe','ZZZ-marker-negctl')

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf     = Join-Path $OutDir ('234_' + $stamp + '_resub-experiment.txt')
$sockOut  = Join-Path $OutDir ('234_' + $stamp + '_sockets-before.txt')
$engOut   = Join-Path $OutDir ('234_' + $stamp + '_engine-window.txt')
$shOut    = Join-Path $OutDir ('234_' + $stamp + '_shell-window.txt')
$posOut   = Join-Path $OutDir ('234_' + $stamp + '_posctl.txt')

$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (corpus written; numbers NOT interpreted here)' }
                       else        { 'VERDICT: FAIL (see the stop above; nothing was restarted unless stated)' }))
    Flush
    Write-Host ''
    Write-Host ('REPORT : ' + $outf)
    foreach ($f in @($sockOut, $engOut, $shOut, $posOut)) {
        if (Test-Path -LiteralPath $f) { Write-Host ('WRITTEN: ' + $f) }
        else { Write-Host ('NOT WRITTEN: ' + [IO.Path]::GetFileName($f)) }
    }
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
function Svc-Pid($name) {
    foreach ($pr in @(Get-WmiObject Win32_Service -Filter ("Name='" + $name + "'") -ErrorAction SilentlyContinue)) {
        if ($pr.ProcessId -gt 0) { return [int]$pr.ProcessId }
    }
    return -1
}
function Read-AllLines($path) {
    $fs = $null
    try { $fs = New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite) }
    catch { return $null }
    if ($null -eq $fs) { return $null }
    $sr = New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8)
    $out = New-Object System.Collections.ArrayList
    while ($null -ne ($line = $sr.ReadLine())) { [void]$out.Add($line) }
    $sr.Close(); $fs.Close()
    return $out
}

Say '===== 0  machine, instrument, controls ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
Say ('  assignment gate : unassigned {0} (want {1})' -f (Safe-Count $null), $SENTINEL)
$ctlT = Get-Date
$ctlOk = $true
foreach ($c in @(@{T=($ctlT.AddMinutes(-1).ToString('yyyy-MM-dd HH:mm:ss') + ',001 x'); W='BEFORE'},
                 @{T=($ctlT.AddMinutes(1).ToString('yyyy-MM-dd HH:mm:ss')  + ',001 x'); W='AFTER'},
                 @{T=($ctlT.AddMinutes(-1).ToString('yyyy-MM-dd HH:mm:ss') + '.001 +03:00 x'); W='BEFORE'},
                 @{T=($ctlT.AddMinutes(1).ToString('yyyy-MM-dd HH:mm:ss')  + '.001 +03:00 x'); W='AFTER'})) {
    $tm = Get-LineTime $c.T
    $got = $(if ($null -eq $tm) { 'UNPARSED' } elseif ($tm -ge $ctlT) { 'AFTER' } else { 'BEFORE' })
    if ($got -ne $c.W) { $ctlOk = $false; Say ('  parser control FAILED: {0} -> {1}' -f $c.T, $got) }
}
Say ('  parser control, both log formats : {0}   expected True' -f $ctlOk)
if (-not $ctlOk) { Say '  *** slicing broken - stopping before anything is restarted'; Fin $false }

Say ''
Say '===== 1  P1 - is there a subscription AT ALL, by the log path the Shell DECLARES ====='
$declared = @()
try {
    $o = Get-Content -LiteralPath $SHELLCFG -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($sink in @($o.Serilog.WriteTo)) { if ($sink.Args -and $sink.Args.path) { $declared += "$($sink.Args.path)" } }
} catch { Say ('  *** cannot read the Shell config : {0}' -f $_.Exception.Message); Fin $false }
Say ('  Serilog sink paths declared by the Shell : {0}' -f (Safe-Count $declared))
foreach ($d in $declared) { Say ('      {0}' -f $d) }
$shellLog = $null
foreach ($d in $declared) {
    $d2 = "$d" -replace '/', '\'
    $bases = @()
    if ([IO.Path]::IsPathRooted($d2)) { $bases = @('') } else { $bases = @('C:\RTMView\Shell', [Environment]::SystemDirectory) }
    foreach ($b in $bases) {
        $full = $(if ($b -eq '') { $d2 } else { Join-Path $b $d2 })
        $dir  = [IO.Path]::GetDirectoryName($full)
        $leaf = [IO.Path]::GetFileNameWithoutExtension($full)
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        $hits = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name.StartsWith($leaf, [StringComparison]::OrdinalIgnoreCase) } |
                  Sort-Object LastWriteTime -Descending)
        foreach ($h in @($hits | Select-Object -First 1)) {
            if ($null -eq $shellLog) { $shellLog = $h.FullName; Say ('  newest declared Shell log : {0}   {1} bytes   {2}' -f $h.FullName, $h.Length, $h.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) }
        }
    }
}
if ($null -eq $shellLog) { Say '  *** no Shell log found at any declared path - STOP, nothing restarted'; Fin $false }
$shLines = Read-AllLines $shellLog
if ($null -eq $shLines) { Say '  *** cannot open the Shell log - STOP'; Fin $false }
Say ('  lines in the Shell log : {0}' -f (Safe-Count $shLines))
$subs = @($shLines | Where-Object { $_.Contains('AgentGridWidget: subscribed to union') })
Say ('  P1  "AgentGridWidget: subscribed to union" : {0}   expected >= 1' -f (Safe-Count $subs))
foreach ($s in @($subs | Select-Object -Last 3)) { Say ('      | ' + $s.Trim().Substring(0, [Math]::Min(140, $s.Trim().Length))) }
if ((Safe-Count $subs) -lt 1) {
    Say '  *** NO SUBSCRIPTION. Restarting now would measure an empty room, which is how the last two'
    Say '  *** attempts were spent. STOP - ask the operator to open the Agent Grid tab and re-run.'
    Fin $false
}

Say ''
Say '===== 2  P2 - is the Shell talking to OUR engine, and the socket snapshot as an ARTIFACT ====='
$enginePid = Svc-Pid 'RTMService'
$shellPid  = Svc-Pid 'RTMViewShell'
Say ('  our engine pid {0} ; our Shell pid {1}' -f $enginePid, $shellPid)
$snap = New-Object System.Collections.ArrayList
[void]$snap.Add('SOCKET SNAPSHOT taken ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + ' BEFORE any restart')
[void]$snap.Add('our engine pid ' + $enginePid + ' ; our Shell pid ' + $shellPid)
$p2 = $false
foreach ($port in @($PORT, $OLDPORT)) {
    $l = @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
    [void]$snap.Add(('LISTEN ' + $port + ' : ' + (Safe-Count $l)))
    Say ('  LISTEN {0} : {1}' -f $port, (Safe-Count $l))
    foreach ($x in $l) {
        $pr = Get-Process -Id $x.OwningProcess -ErrorAction SilentlyContinue
        $line = '    ' + $x.LocalAddress + ' pid ' + $x.OwningProcess + ' : ' + $(if ($pr) { $pr.Path } else { '(gone)' })
        [void]$snap.Add($line); Say ('  ' + $line)
    }
    $cl = @(Get-NetTCPConnection -RemotePort $port -State Established -ErrorAction SilentlyContinue)
    $sv = @(Get-NetTCPConnection -LocalPort $port -State Established -ErrorAction SilentlyContinue)
    [void]$snap.Add(('CLIENT end to ' + $port + ' : ' + (Safe-Count $cl) + ' ; SERVER end on ' + $port + ' : ' + (Safe-Count $sv)))
    Say ('  CLIENT end to {0} : {1} ; SERVER end on {0} : {2}' -f $port, (Safe-Count $cl), (Safe-Count $sv))
    foreach ($x in $cl) {
        $pr = Get-Process -Id $x.OwningProcess -ErrorAction SilentlyContinue
        $line = '    client ' + $x.LocalAddress + ':' + $x.LocalPort + ' pid ' + $x.OwningProcess + ' : ' + $(if ($pr) { $pr.Path } else { '(gone)' }) + ' created ' + $x.CreationTime
        [void]$snap.Add($line); Say ('  ' + $line)
        if (($port -eq $PORT) -and ($x.OwningProcess -eq $shellPid)) {
            foreach ($y in $sv) {
                if (($y.RemotePort -eq $x.LocalPort) -and ($y.OwningProcess -eq $enginePid)) { $p2 = $true }
            }
        }
    }
    foreach ($x in $sv) {
        $pr = Get-Process -Id $x.OwningProcess -ErrorAction SilentlyContinue
        $line = '    server ->' + $x.RemotePort + ' pid ' + $x.OwningProcess + ' : ' + $(if ($pr) { $pr.Path } else { '(gone)' }) + ' created ' + $x.CreationTime
        [void]$snap.Add($line); Say ('  ' + $line)
    }
}
$pos8444 = Safe-Count @(Get-NetTCPConnection -LocalPort 8444 -State Established -ErrorAction SilentlyContinue)
$neg = Safe-Count @(Get-NetTCPConnection -LocalPort 65123 -State Established -ErrorAction SilentlyContinue)
[void]$snap.Add('POSCTL 8444 established : ' + $pos8444 + '   expected >= 1')
[void]$snap.Add('NEGCTL 65123 established : ' + $neg + '   expected 0')
[void]$snap.Add('P2 (Shell socket whose SERVER end is our engine pid, matched by port number) : ' + $p2)
Say ('  POSCTL 8444 : {0}   expected >= 1' -f $pos8444)
Say ('  NEGCTL 65123 : {0}   expected 0' -f $neg)
Say ('  P2 matched by socket number, both ends ours : {0}   expected True' -f $p2)
[IO.File]::WriteAllLines($sockOut, $snap, (New-Object Text.UTF8Encoding($false)))
Say ('  socket snapshot -> {0}' -f $sockOut)
if ($pos8444 -lt 1) { Say '  *** the connection query returns nothing on a port known to be alive - the instrument is suspect'; Fin $false }
if ($neg -ne 0) { Say '  *** the instrument reports connections that cannot exist'; Fin $false }
if (-not $p2) {
    Say '  *** P2 FAILED: no Shell socket on 8089 whose server end is our engine. Restarting now would'
    Say '  *** repeat the earlier empty runs. STOP - nothing was restarted.'
    Fin $false
}
Flush

Say ''
Say '===== 3  THE RESTART - engine only, and readiness is POLLED ====='
$engBefore = $enginePid
Say ('  engine pid before : {0}' -f $engBefore)
Say '  restarting RTMService. The ADAPTER IS NOT TOUCHED - the engine owns its lifecycle.'
Restart-Service -Name 'RTMService' -ErrorAction SilentlyContinue
$t0 = Get-Date
$ready = $false
$waited = 0
while ($waited -lt $READYMAX) {
    Start-Sleep -Seconds 5
    $waited = [int]((Get-Date) - $t0).TotalSeconds
    $lst = @(Get-NetTCPConnection -LocalPort $PORT -State Listen -ErrorAction SilentlyContinue)
    $pipes = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) })
    $hasPipe = ($pipes -contains 'rtmpipe_v3')
    if (((Safe-Count $lst) -ge 1) -and $hasPipe) { $ready = $true; break }
}
Say ('  readiness polled every 5 s: listener on {0} AND pipe rtmpipe_v3' -f $PORT)
Say ('  ready after {0} seconds : {1}   (timeout would be {2} s, and "not ready after N" is an honest result)' -f $waited, $ready, $READYMAX)
$engAfter = Svc-Pid 'RTMService'
$adAfter  = Svc-Pid 'RTMTwilio_1'
$shAfter  = Svc-Pid 'RTMViewShell'
$engStart = (Get-Process -Id $engAfter -ErrorAction SilentlyContinue).StartTime
Say ('  engine pid after {0} started {1}' -f $engAfter, $(if ($engStart) { $engStart.ToString('yyyy-MM-dd HH:mm:ss.fff') } else { '(unknown)' }))
Say ('  adapter pid {0} (brought up by the engine, NOT by this run)' -f $adAfter)
Say ('  Shell pid {0} - must be unchanged: {1}' -f $shAfter, ($shAfter -eq $shellPid))
if (-not $ready) { Say '  *** the engine did not become ready within the timeout - reporting, not iterating on a live server' }
if ($null -eq $engStart) { Say '  *** cannot read the engine start time - cannot bound the window'; Fin $false }
$WINSTART = $engStart
Say ('  WINDOW starts at {0}' -f $WINSTART.ToString('yyyy-MM-dd HH:mm:ss.fff'))
Say ('  settling {0} seconds before the slice, so a late re-subscription is inside the corpus' -f $SETTLE)
Start-Sleep -Seconds $SETTLE
Flush

Say ''
Say '===== 4  THE CORPUS - both sides, rollover-aware, boundary printed ====='
$engFiles = @()
$engFiles += $ENGLOG
foreach ($f in @(Get-ChildItem -LiteralPath $ENGDIR -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match '^RTM\.log\d{8}$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1)) {
    if ($f.LastWriteTime -ge $WINSTART.AddHours(-1)) { $engFiles += $f.FullName }
}
Say ('  engine files entering the corpus : {0}' -f (Safe-Count $engFiles))
foreach ($f in $engFiles) { Say ('      {0}' -f $f) }
Say ('  shell file : {0}' -f $shellLog)
Say '  NOT read: C:\Windows\System32\logs (foreign Shell) , C:\Logs\RTM (legacy)'

$total = @{}; $inwin = @{}
function Slice-File($path, $needles, $outfile, $tag) {
    $lines = Read-AllLines $path
    if ($null -eq $lines) { Say ('  *** cannot open {0}' -f $path); return $false }
    $n = Safe-Count $lines
    $first = $null; $last = $null; $win = 0
    $keep = New-Object System.Collections.ArrayList
    $inWindow = $false
    foreach ($line in $lines) {
        $t = Get-LineTime $line
        if ($null -ne $t) {
            if ($null -eq $first) { $script:tmpFirst = $t; $first = $t }
            $last = $t
            $inWindow = ($t -ge $WINSTART)
        }
        if ($inWindow) { [void]$keep.Add($line); $win++ }
        foreach ($needle in $needles) {
            $key = $tag + '|' + $needle
            if (-not $total.ContainsKey($key)) { $total[$key] = 0; $inwin[$key] = 0 }
            if ($line.Contains($needle)) { $total[$key] = $total[$key] + 1; if ($inWindow) { $inwin[$key] = $inwin[$key] + 1 } }
        }
    }
    $b1 = $(if ($first) { $first.ToString('yyyy-MM-dd HH:mm:ss.fff') } else { '(none)' })
    $b2 = $(if ($last)  { $last.ToString('yyyy-MM-dd HH:mm:ss.fff') }  else { '(none)' })
    Say ('  {0,-10} {1,-34} lines {2,7}  in window {3,6}  boundary {4} .. {5}' -f $tag, [IO.Path]::GetFileName($path), $n, $win, $b1, $b2)
    $head = New-Object System.Collections.ArrayList
    [void]$head.Add('SLICE of ' + $path)
    [void]$head.Add('CORPUS BOUNDARY of the SOURCE : first ' + $b1 + '   last ' + $b2)
    [void]$head.Add('WINDOW kept : from ' + $WINSTART.ToString('yyyy-MM-dd HH:mm:ss.fff') + ' to end of file')
    [void]$head.Add('lines in source ' + $n + ' , kept ' + $win + ' , NOT filtered by content')
    [void]$head.Add('--------------------------------------------------------------------------------')
    foreach ($l in $keep) { [void]$head.Add($l) }
    if (Test-Path -LiteralPath $outfile) {
        $existing = [IO.File]::ReadAllLines($outfile)
        $merged = New-Object System.Collections.ArrayList
        foreach ($l in $existing) { [void]$merged.Add($l) }
        [void]$merged.Add('')
        foreach ($l in $head) { [void]$merged.Add($l) }
        [IO.File]::WriteAllLines($outfile, $merged, (New-Object Text.UTF8Encoding($false)))
    } else {
        [IO.File]::WriteAllLines($outfile, $head, (New-Object Text.UTF8Encoding($false)))
    }
    return $true
}
foreach ($f in $engFiles) { [void](Slice-File $f $ENGNEEDLES $engOut ('engine')) }
[void](Slice-File $shellLog $SHNEEDLES $shOut ('shell'))

Say ''
Say '===== 5  POSCTL - every needle, whole file AND window, per side ====='
$pos = New-Object System.Collections.ArrayList
[void]$pos.Add('POSCTL for the window starting ' + $WINSTART.ToString('yyyy-MM-dd HH:mm:ss.fff'))
[void]$pos.Add('side       needle                                            total   in-window')
[void]$pos.Add('---------------------------------------------------------------------------------')
foreach ($key in ($total.Keys | Sort-Object)) {
    $parts = $key.Split('|')
    $line = ('{0,-10} {1,-48} {2,7} {3,11}' -f $parts[0], $parts[1], $total[$key], $inwin[$key])
    [void]$pos.Add($line); Say ('  ' + $line)
}
[void]$pos.Add('')
[void]$pos.Add('READING RULE:')
[void]$pos.Add('  total 0 and window 0  -> MATCHER SUSPECT; its zero is not a finding')
[void]$pos.Add('  total >0, window 0    -> a finding: it happens, but not after this restart')
[void]$pos.Add('  window >0             -> it happened after the engine-only restart')
[void]$pos.Add('  ZZZ-marker-negctl must be 0 everywhere, or the whole run is void')
[IO.File]::WriteAllLines($posOut, $pos, (New-Object Text.UTF8Encoding($false)))
Say ('  written -> {0}' -f $posOut)

Say ''
Say '===== 6  sockets AFTER, same predicate as before ====='
$engPidNow = Svc-Pid 'RTMService'
$cl = @(Get-NetTCPConnection -RemotePort $PORT -State Established -ErrorAction SilentlyContinue)
$sv = @(Get-NetTCPConnection -LocalPort $PORT -State Established -ErrorAction SilentlyContinue)
Say ('  CLIENT end to {0} : {1} ; SERVER end on {0} : {2}' -f $PORT, (Safe-Count $cl), (Safe-Count $sv))
foreach ($x in $cl) { Say ('      client {0}:{1} pid {2} created {3}' -f $x.LocalAddress, $x.LocalPort, $x.OwningProcess, $x.CreationTime) }
foreach ($x in $sv) { Say ('      server ->{0} pid {1} created {2}' -f $x.RemotePort, $x.OwningProcess, $x.CreationTime) }
Say ('  our engine pid now {0} ; Shell pid {1} (unchanged from {2} -> {3})' -f $engPidNow, (Svc-Pid 'RTMViewShell'), $shellPid, ((Svc-Pid 'RTMViewShell') -eq $shellPid))
Say ''
Say '  Numbers are not interpreted here. The verdict belongs to shell-0912.'
Fin $true
