#Requires -Version 5.1
<#
  PROBE 234 / consumer      PRODUCER versus CONSUMER, per engine-start window.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate. READ ONLY.
  Starts nothing, stops nothing, restarts nothing, writes no config, touches no service, queries NO
  database, prompts for no password. C:\IceDash is never read or listed. Only write: its report.

  WHY THIS RUN EXISTS - I RETRACT the previous one, and the reason is mine, not the system's.
  234_20260913_102412_who-asked.txt printed "getUsers 0, count= 0, PUSH 0" in every window and then
  concluded, in its own words, that the consumer never asked. That conclusion is VOID:
    - I patched that probe by TEXT REPLACEMENT and the assignment line I was targeting did not exist,
      so $asks / $counts / $pushes / $gridConn were NEVER ASSIGNED;
    - in PowerShell $null.Count evaluates to 0 with no error, so four unassigned variables printed as
      four honest-looking zeros;
    - and the earlier run (234_20260913_024657_two-windows.txt) had already measured count = 35 at
      02:40:03 in that same window. Two of my own measurements contradicted each other and the OLDER
      one was right.
  This is exactly the family of failure I spent the night gating against - a zero that means "I did not
  look" wearing the clothes of a zero that means "it did not happen". So this probe carries a gate for
  precisely that, described below, and it is written as a whole file rather than patched.

  THE ASSIGNMENT GATE (new, and the point of this run). Every needle is counted through ONE helper that
  REFUSES a null input: it returns a sentinel instead of 0, and the sentinel is checked. Plus a POSCTL
  on each needle family over the WHOLE log: a needle that never matches anywhere is reported as
  "matcher suspect" rather than as a finding, because a string the engine never writes cannot tell us
  anything by being absent.

  WHAT IS BEING SEPARATED:
    PRODUCER : refreshUnions Add / MISS  -> did union.Users get filled in this window?
    CONSUMER : getUsers unionId= , ChangedUnionUsersData count= , PUSH updateUserGrid , AddGridConnection
               -> did anything ASK, and what did it get?
  A window with Add > 0 and zero asks means the grid was empty because nothing asked - a consumer
  failure. A window with Add = 0 means the producer failed. A window with asks and count=0 means the
  producer was empty AT ASK TIME, which is a third thing again.
  [operator, 2026-09-13] the second restart included the SHELL service (RTMViewShell,
  C:\RTMView\Shell\CcDashboard.Web.exe, pid 7128 started 02:39:14) - so the consumer side changed
  exactly once, and that is why the per-window consumer numbers decide this.

  ALSO FIXED HERE: the load interval. In windows 1 and 2 the previous probe reported a load interval of
  4194 s and 749 s, because LoadData rows are re-logged on periodic reloads, so "arrivals inside the
  interval" covered the whole window and meant nothing. Here the load interval is the INITIAL burst
  only - rows within 60 s of the first row after the start - and the full row timeline is printed so
  the choice can be checked rather than trusted.

  EXPECTATIONS:
     assignment gate : every needle family assigned, no sentinel -> else the run FAILS and measures nothing
     POSCTL per family : a family with zero matches anywhere in the log is flagged matcher-suspect
     NEGCTL : an impossible string -> 0
     windows : >= 2
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$SENTINEL = -999

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_consumer.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function SayFileOnly($text) { [void]$Report.Add($text) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound - nothing here is evidence)' }))
    [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
# the assignment gate: a null collection returns the sentinel, never 0
function Safe-Count($collection) {
    if ($null -eq $collection) { return $SENTINEL }
    return @($collection).Count
}
$FORMATS = @('yyyy-MM-dd HH:mm:ss,fff','dd/MM/yyyy HH:mm:ss,fff','yyyy-MM-dd HH:mm:ss','dd/MM/yyyy HH:mm:ss')
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

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to measure'; Fin $false }
foreach ($h in @('Get-LineTime','Safe-Count')) {
    $rr = Get-Command $h -ErrorAction SilentlyContinue
    Say ('  {0} resolves to {1}   expected Function' -f $h, $rr.CommandType)
    if ("$($rr.CommandType)" -ne 'Function') { Say '  *** helper shadowed - stop'; Fin $false }
}
Say ('  now : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

Say ''
Say '===== G1  the ASSIGNMENT GATE, self-test - this is what the last run lacked ====='
$neverAssigned = $null
$gateA = Safe-Count $neverAssigned
$gateB = Safe-Count @()
$gateC = Safe-Count @('x','y')
Say ('  Safe-Count on an UNASSIGNED variable : {0}   expected {1} (the sentinel, NOT 0)' -f $gateA, $SENTINEL)
Say ('  Safe-Count on an empty collection    : {0}   expected 0' -f $gateB)
Say ('  Safe-Count on two items              : {0}   expected 2' -f $gateC)
$gateOk = (($gateA -eq $SENTINEL) -and ($gateB -eq 0) -and ($gateC -eq 2))
Say ('  assignment gate : {0}   expected True' -f $gateOk)
if (-not $gateOk) { Say '  *** the gate itself is broken - refusing to measure'; Fin $false }

$ctlMark = [datetime]'2026-09-13 12:00:00'
$ctlOk = $true
foreach ($c in @(@{T='2026-09-13 11:00:00,001 [5] INFO x';W='BEFORE'},@{T='2026-09-13 13:00:00,001 [5] INFO x';W='AFTER'},
                 @{T=' 13/09/2026 11:00:00,002 INFO x';W='BEFORE'},@{T=' 13/09/2026 13:00:00,002 INFO x';W='AFTER'})) {
    $tm = Get-LineTime $c.T
    $got = $(if ($null -eq $tm) { 'UNPARSED' } elseif ($tm -gt $ctlMark) { 'AFTER' } else { 'BEFORE' })
    if ($got -ne $c.W) { $ctlOk = $false }
}
Say ('  parser control (4 synthetic lines, both formats) : {0}   expected True' -f $ctlOk)
if (-not $ctlOk) { Say '  *** slicing broken - refusing to measure'; Fin $false }

Say ''
Say '===== 1  the consumer service and the logs, both DISCOVERED ====='
$shellSvc = @(Get-WmiObject Win32_Service -ErrorAction SilentlyContinue |
              Where-Object { $_.PathName -match '(?i)CcDashboard|RTMView\\Shell' })
Say ('  consumer services found : {0}' -f (Safe-Count $shellSvc))
foreach ($s in $shellSvc) {
    Say ('    {0} : {1} , {2}' -f $s.Name, $s.State, $s.PathName)
    $ps = Get-Process -Id $s.ProcessId -ErrorAction SilentlyContinue
    if ($ps) { Say ('        pid {0} started {1}' -f $ps.Id, $ps.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
}
$svcEngine = Get-WmiObject Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
if (-not $svcEngine) { Say '  *** RTMService not found'; Fin $false }
$exe = "$($svcEngine.PathName)".Trim()
if ($exe.StartsWith('"')) { $exe = $exe.Substring(1, $exe.IndexOf('"', 1) - 1) }
else { $sp = $exe.IndexOf(' -'); if ($sp -gt 0) { $exe = $exe.Substring(0, $sp) } }
$engineDir = [IO.Path]::GetDirectoryName($exe)
$pEng = Get-Process -Id $svcEngine.ProcessId -ErrorAction SilentlyContinue
if ($pEng) { Say ('  RTMService pid {0} started {1}' -f $pEng.Id, $pEng.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }

$all = New-Object System.Collections.ArrayList
$negCtl = 0
$unparsed = 0
foreach ($root in @((Join-Path $engineDir 'Logs'), 'C:\Logs\RTM', 'C:\Logs\RTMViewShell', 'C:\RTMView\Shell\logs')) {
    if (-not (Test-Path -LiteralPath $root)) { Say ('  {0} : absent' -f $root); continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match '(?i)^RTM\.log$|^log\.txt$|^log-2026' } |
                     Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-12) } | Sort-Object LastWriteTime)) {
        $lines = @(Get-Content -LiteralPath $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue)
        Say ('  {0}   lines {1}' -f $f.FullName, $lines.Count)
        foreach ($line in $lines) {
            if ($line.Contains('ZZZ-cannot-occur-ZZZ')) { $negCtl++ }
            $tm = Get-LineTime $line
            if ($null -eq $tm) { $unparsed++; continue }
            [void]$all.Add([pscustomobject]@{ Time = $tm; Text = $line })
        }
    }
}
$all = @($all | Sort-Object Time)
Say ('  timed lines {0} , unparsed {1} , NEGCTL {2}   expected NEGCTL 0' -f (Safe-Count $all), $unparsed, $negCtl)
if ((Safe-Count $all) -lt 1) { Say '  *** nothing to read'; Fin $false }

Say ''
Say '===== 2  POSCTL per needle family, over the WHOLE log ====='
$families = @(
    @{ Key='ADD';    Needle='refreshUnions Add' },
    @{ Key='MISS';   Needle='refreshUnions MISS' },
    @{ Key='LOAD';   Needle='LoadData union=' },
    @{ Key='RECV';   Needle='RECV userWorkgroupActivation' },
    @{ Key='ASK';    Needle='getUsers unionId=' },
    @{ Key='COUNT';  Needle='ChangedUnionUsersData count=' },
    @{ Key='PUSH';   Needle='PUSH updateUserGrid' },
    @{ Key='GRIDCN'; Needle='GridConnection' }
)
$suspect = New-Object System.Collections.ArrayList
foreach ($fam in $families) {
    $hits = @($all | Where-Object { $_.Text.Contains($fam.Needle) })
    $n = Safe-Count $hits
    if ($n -eq $SENTINEL) { Say ('  *** {0} came back UNASSIGNED - stop' -f $fam.Key); Fin $false }
    $flag = ''
    if ($n -eq 0) { $flag = '   <- MATCHER SUSPECT: absent everywhere, so its absence proves nothing'; [void]$suspect.Add($fam.Key) }
    Say ('  {0,-7} "{1}" : {2}{3}' -f $fam.Key, $fam.Needle, $n, $flag)
    if ($n -gt 0) {
        $lastHit = $hits[$hits.Count-1]
        Say ('          latest {0}  | {1}' -f $lastHit.Time.ToString('MM-dd HH:mm:ss.fff'), $lastHit.Text.Trim().Substring(0, [Math]::Min(120, $lastHit.Text.Trim().Length)))
    }
}
Say ('  families absent everywhere : {0} - their per-window zeros are NOT findings' -f (Safe-Count $suspect))

$markers = @($all | Where-Object { $_.Text.Contains('RTM Start') })
$starts = New-Object System.Collections.ArrayList
foreach ($m in $markers) {
    if ((Safe-Count $starts) -eq 0) { [void]$starts.Add($m.Time); continue }
    if (($m.Time - $starts[$starts.Count-1]).TotalSeconds -gt 60) { [void]$starts.Add($m.Time) }
}
$take = @($starts | Select-Object -Last 4)
Say ''
Say ('  "RTM Start" markers {0} , distinct starts {1}' -f (Safe-Count $markers), (Safe-Count $take))
if ((Safe-Count $take) -lt 2) { Say '  *** fewer than two starts - UNDECIDABLE'; Fin $true }

Say ''
Say '===== 3  per window: PRODUCER versus CONSUMER ====='
$rows = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt (Safe-Count $take); $i++) {
    $from = $take[$i]
    $to = $(if ($i -lt (Safe-Count $take) - 1) { $take[$i+1] } else { [datetime]::MaxValue })
    $win = @($all | Where-Object { $_.Time -ge $from -and $_.Time -lt $to })

    $wAdd    = @($win | Where-Object { $_.Text.Contains('refreshUnions Add') })
    $wMiss   = @($win | Where-Object { $_.Text.Contains('refreshUnions MISS') })
    $wLoad   = @($win | Where-Object { $_.Text.Contains('LoadData union=') })
    $wRecv   = @($win | Where-Object { $_.Text.Contains('RECV userWorkgroupActivation') })
    $wAsk    = @($win | Where-Object { $_.Text.Contains('getUsers unionId=') })
    $wCount  = @($win | Where-Object { $_.Text.Contains('ChangedUnionUsersData count=') })
    $wPush   = @($win | Where-Object { $_.Text.Contains('PUSH updateUserGrid') })
    $wGrid   = @($win | Where-Object { $_.Text.Contains('GridConnection') })

    foreach ($pair in @(@('wAdd',$wAdd),@('wMiss',$wMiss),@('wLoad',$wLoad),@('wRecv',$wRecv),
                        @('wAsk',$wAsk),@('wCount',$wCount),@('wPush',$wPush),@('wGrid',$wGrid))) {
        if ((Safe-Count $pair[1]) -eq $SENTINEL) { Say ('  *** {0} UNASSIGNED in window {1} - stop' -f $pair[0], ($i+1)); Fin $false }
    }

    # load interval = the INITIAL burst only: rows within 60 s of the first row in this window
    $loadFirst = $null; $burstLast = $null; $burstRows = 0
    if ((Safe-Count $wLoad) -gt 0) {
        $loadFirst = $wLoad[0].Time
        foreach ($l in $wLoad) { if (($l.Time - $loadFirst).TotalSeconds -le 60) { $burstLast = $l.Time; $burstRows++ } }
    }
    $insideBurst = 0
    if ($loadFirst -and $burstLast) { $insideBurst = @($wRecv | Where-Object { $_.Time -ge $loadFirst -and $_.Time -le $burstLast }).Count }

    Say ''
    Say ('  --- window {0} : {1} -> {2} ---' -f ($i+1), $from.ToString('MM-dd HH:mm:ss'),
         $(if ($to -eq [datetime]::MaxValue) { 'now' } else { $to.ToString('HH:mm:ss') }))
    Say ('      PRODUCER : Add {0} , MISS {1}' -f (Safe-Count $wAdd), (Safe-Count $wMiss))
    Say ('      CONSUMER : ask {0} , count= {1} , PUSH {2} , GridConnection {3}' -f `
         (Safe-Count $wAsk), (Safe-Count $wCount), (Safe-Count $wPush), (Safe-Count $wGrid))
    foreach ($c in $wCount) {
        $cm = [regex]::Match($c.Text, 'count=(\d+)')
        Say ('          {0}  count = {1}' -f $c.Time.ToString('HH:mm:ss.fff'), $cm.Groups[1].Value)
    }
    foreach ($a in @($wAsk | Select-Object -First 8)) {
        Say ('          ask {0}  | {1}' -f $a.Time.ToString('HH:mm:ss.fff'), $a.Text.Trim().Substring(0, [Math]::Min(110, $a.Text.Trim().Length)))
    }
    Say ('      mapping  : rows {0} , initial burst {1} rows ending {2} , arrivals inside the burst {3}' -f `
         (Safe-Count $wLoad), $burstRows, $(if ($burstLast) { $burstLast.ToString('HH:mm:ss.fff') } else { 'none' }), $insideBurst)
    Say ('      arrivals : {0}' -f (Safe-Count $wRecv))
    foreach ($l in @($wLoad | Select-Object -First 40)) { SayFileOnly ('          load | ' + $l.Text.Trim()) }

    $verdict = 'see numbers'
    if ((Safe-Count $wAdd) -gt 0 -and (Safe-Count $wAsk) -eq 0 -and -not $suspect.Contains('ASK')) {
        $verdict = 'POPULATED, NOBODY ASKED -> consumer'
    } elseif ((Safe-Count $wAdd) -eq 0) {
        $verdict = 'NOT POPULATED -> producer'
    } elseif ((Safe-Count $wAsk) -gt 0 -and (Safe-Count $wCount) -gt 0) {
        $verdict = 'asked and answered'
    }
    Say ('      -> {0}' -f $verdict)
    [void]$rows.Add([pscustomobject]@{ N=$i+1; From=$from; Add=(Safe-Count $wAdd); Miss=(Safe-Count $wMiss)
        Ask=(Safe-Count $wAsk); Count=(Safe-Count $wCount); Push=(Safe-Count $wPush); Grid=(Safe-Count $wGrid)
        Load=(Safe-Count $wLoad); Recv=(Safe-Count $wRecv); Verdict=$verdict })
}

Say ''
Say '===== 4  the table ====='
Say '  win  start           Add    MISS    ask  count  PUSH  gridCn  load  recv  verdict'
foreach ($r in $rows) {
    Say ('  {0,-4} {1,-15} {2,-6} {3,-7} {4,-4} {5,-6} {6,-5} {7,-7} {8,-5} {9,-5} {10}' -f `
         $r.N, $r.From.ToString('MM-dd HH:mm:ss'), $r.Add, $r.Miss, $r.Ask, $r.Count, $r.Push, $r.Grid, $r.Load, $r.Recv, $r.Verdict)
}
if ($suspect.Contains('ASK') -or $suspect.Contains('COUNT')) {
    Say ''
    Say '  *** the ASK or COUNT matcher is absent from the whole log, so no consumer conclusion can be'
    Say '      drawn from their zeros. I say so instead of repeating the retracted claim.'
}

Say ''
Say '===== verdict - on MY instrument ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Say ('  assignment gate {0} ; parser {1} ; windows {2} ; NEGCTL {3} ; suspect families {4}' -f `
     $gateOk, $ctlOk, (Safe-Count $rows), $negCtl, (Safe-Count $suspect))
Fin ($gateOk -and $ctlOk -and ($negCtl -eq 0) -and ((Safe-Count $rows) -ge 2))
