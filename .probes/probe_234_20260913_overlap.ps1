#Requires -Version 5.1
<#
  PROBE 234 / overlap      my race hypothesis was DISPROVED. This measures what actually differed.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate. READ ONLY.
  Starts nothing, stops nothing, restarts nothing, writes no config, touches no service, queries NO
  database, prompts for no password. C:\IceDash is never read or listed. Only write: its report.

  WHAT THE PREVIOUS RUN SETTLED, AND WHAT IT KILLED [measured: 234_20260913_024657_two-windows.txt]:
      win  start          order           Add   MISS    LoadRows  RECV
      1    01:15:29       mapping FIRST   1     418     2         430
      2    02:26:02       mapping FIRST   36    686     33        430
      3    02:39:22       mapping FIRST   423   12664   33        430
  The order is "mapping FIRST" in ALL THREE windows, so my hypothesis - that a failing start processed
  the activation snapshot before the mapping was in memory - is WRONG as stated. I say so here rather
  than quietly reshaping it: the probe refused to confirm it and it was right to refuse.

  WHAT THE SAME TABLE SHOWS INSTEAD. Windows 2 and 3 had the IDENTICAL mapping (33 rows, same union
  ids) and the IDENTICAL number of arrivals (430), yet window 2 produced 36 Add and window 3 produced
  423. So the difference is neither the mapping nor the coarse order. Two candidates remain, and they
  are distinguishable:
    OVERLAP  - I printed only the FIRST LoadData row time. If the 33 rows were still being loaded while
               the arrivals were already being evaluated, the users processed in that gap were compared
               against an INCOMPLETE mapping. Window 2 logged its first row at 02:26:29 and its first
               arrival at 02:26:32 - three seconds apart, so an overlap is physically possible.
    TRUNCATION - window 2 lived 13 minutes and was restarted. If the population is simply SLOW, it was
               interrupted mid-work, and the grid looked empty because the work had not finished, not
               because anything compared wrongly.
  These two have different fixes and must not be merged. OVERLAP is fixed by an order or by re-running
  refreshUnions after a mapping load; TRUNCATION is fixed by waiting, or by making the population fast.

  HOW THIS PROBE SEPARATES THEM, stated before the numbers:
   1. for each window: FIRST and LAST LoadData row time, so the load DURATION is visible, not just its
      start - this is the measurement I omitted last time and the reason that run was undecidable
   2. how many arrivals fell INSIDE the load interval (first row .. last row) - these are the ones that
      could have seen an incomplete mapping. Zero such arrivals kills OVERLAP outright.
   3. the TIME PROFILE of refreshUnions work: first and last Add/MISS time per window, and how much of
      the window had elapsed when the last one was written. If window 3 kept producing lines for many
      minutes, the work is slow and window 2 was simply cut off -> TRUNCATION.
   4. the distinct users added per window, and whether window 2's added set is a SUBSET of window 3's.
      A subset is the signature of interrupted-but-correct work; a different set is not.
   5. the arrival profile: first and last arrival time per window - 430 arrivals in one burst or spread.

  EXPECTATIONS:
     windows found : >= 2 (POSCTL); parser control must pass or nothing is measured
     NEGCTL : an impossible string -> 0
  No verdict on the cause is gated: both candidates are reported with their numbers, and if the numbers
  do not separate them the probe says so instead of choosing.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_overlap.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function SayFileOnly($text) { [void]$Report.Add($text) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound)' }))
    [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
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
$r = Get-Command Get-LineTime -ErrorAction SilentlyContinue
if ("$($r.CommandType)" -ne 'Function') { Say '  *** helper shadowed - stop'; Fin $false }
Say ('  Get-LineTime resolves to Function : True')
Say ('  now : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

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
Say '===== 1  logs, discovered from the SERVICE MANAGER ====='
$svcEngine = Get-WmiObject Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
if (-not $svcEngine) { Say '  *** RTMService not found'; Fin $false }
$exe = "$($svcEngine.PathName)".Trim()
if ($exe.StartsWith('"')) { $exe = $exe.Substring(1, $exe.IndexOf('"', 1) - 1) }
else { $sp = $exe.IndexOf(' -'); if ($sp -gt 0) { $exe = $exe.Substring(0, $sp) } }
$engineDir = [IO.Path]::GetDirectoryName($exe)
Say ('  engine directory : {0}' -f $engineDir)
$all = New-Object System.Collections.ArrayList
$negCtl = 0
$unparsed = 0
foreach ($root in @((Join-Path $engineDir 'Logs'), 'C:\Logs\RTM')) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match '(?i)^RTM\.log$|^log\.txt$' } | Sort-Object LastWriteTime)) {
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
Say ('  timed lines {0} , unparsed {1} , NEGCTL {2}' -f $all.Count, $unparsed, $negCtl)
if ($all.Count -lt 1) { Say '  *** nothing to read'; Fin $false }

$markers = @($all | Where-Object { $_.Text.Contains('RTM Start') })
Say ('  "RTM Start" markers : {0}' -f $markers.Count)
$starts = New-Object System.Collections.ArrayList
foreach ($m in $markers) {
    if ($starts.Count -eq 0) { [void]$starts.Add($m.Time); continue }
    if (($m.Time - $starts[$starts.Count - 1]).TotalSeconds -gt 60) { [void]$starts.Add($m.Time) }
}
$take = @($starts | Select-Object -Last 3)
Say ('  distinct starts used : {0}' -f $take.Count)
if ($take.Count -lt 2) { Say '  *** fewer than two starts - UNDECIDABLE'; Fin $true }

$addedSets = @{}
$summ = New-Object System.Collections.ArrayList
Say ''
Say '===== 2  per window: the LOAD INTERVAL, the ARRIVAL PROFILE, the WORK PROFILE ====='
for ($i = 0; $i -lt $take.Count; $i++) {
    $from = $take[$i]
    $to = $(if ($i -lt $take.Count - 1) { $take[$i + 1] } else { [datetime]::MaxValue })
    $win = @($all | Where-Object { $_.Time -ge $from -and $_.Time -lt $to })
    $loads = @($win | Where-Object { $_.Text.Contains('LoadData union=') })
    $recvs = @($win | Where-Object { $_.Text.Contains('RECV userWorkgroupActivation') })
    $adds = @($win | Where-Object { $_.Text.Contains('refreshUnions Add') })
    $misses = @($win | Where-Object { $_.Text.Contains('refreshUnions MISS') })
    $work = @($win | Where-Object { $_.Text.Contains('refreshUnions') })
    $winEnd = $(if ($to -eq [datetime]::MaxValue) { $win[$win.Count-1].Time } else { $to })

    Say ''
    Say ('  --- window {0} : {1} -> {2} , length {3:N1} min ---' -f ($i+1), $from.ToString('MM-dd HH:mm:ss'),
         $(if ($to -eq [datetime]::MaxValue) { 'now' } else { $to.ToString('HH:mm:ss') }), ($winEnd - $from).TotalMinutes)

    $loadFirst = $null; $loadLast = $null
    if ($loads.Count -gt 0) { $loadFirst = $loads[0].Time; $loadLast = $loads[$loads.Count-1].Time }
    Say ('      1 LOAD   rows {0} , first {1} , last {2} , duration {3:N3} s' -f $loads.Count,
         $(if ($loadFirst) { $loadFirst.ToString('HH:mm:ss.fff') } else { 'none' }),
         $(if ($loadLast) { $loadLast.ToString('HH:mm:ss.fff') } else { 'none' }),
         $(if ($loadFirst) { ($loadLast - $loadFirst).TotalSeconds } else { 0 }))

    $recvFirst = $null; $recvLast = $null
    if ($recvs.Count -gt 0) { $recvFirst = $recvs[0].Time; $recvLast = $recvs[$recvs.Count-1].Time }
    Say ('      5 ARRIVE  {0} , first {1} , last {2} , spread {3:N3} s' -f $recvs.Count,
         $(if ($recvFirst) { $recvFirst.ToString('HH:mm:ss.fff') } else { 'none' }),
         $(if ($recvLast) { $recvLast.ToString('HH:mm:ss.fff') } else { 'none' }),
         $(if ($recvFirst) { ($recvLast - $recvFirst).TotalSeconds } else { 0 }))

    $inside = 0
    if ($loadFirst -and $loadLast) {
        $inside = @($recvs | Where-Object { $_.Time -ge $loadFirst -and $_.Time -le $loadLast }).Count
    }
    Say ('      2 OVERLAP arrivals inside the load interval : {0}   0 KILLS the overlap candidate' -f $inside)

    $workFirst = $null; $workLast = $null
    if ($work.Count -gt 0) { $workFirst = $work[0].Time; $workLast = $work[$work.Count-1].Time }
    Say ('      3 WORK   refreshUnions lines {0} , first {1} , last {2} , span {3:N1} s' -f $work.Count,
         $(if ($workFirst) { $workFirst.ToString('HH:mm:ss.fff') } else { 'none' }),
         $(if ($workLast) { $workLast.ToString('HH:mm:ss.fff') } else { 'none' }),
         $(if ($workFirst) { ($workLast - $workFirst).TotalSeconds } else { 0 }))
    if ($workLast) {
        Say ('        the window still had {0:N1} s left after the LAST refreshUnions line' -f ($winEnd - $workLast).TotalSeconds)
        Say '        a large remainder means the work FINISHED inside the window; a near-zero one means'
        Say '        it was still going when the window ended -> TRUNCATION'
    }
    Say ('      Add {0} , MISS {1}' -f $adds.Count, $misses.Count)

    $users = New-Object System.Collections.ArrayList
    foreach ($a in $adds) {
        $um = [regex]::Match($a.Text, 'Add User=([^\s]+) to Union=(\d+)')
        if ($um.Success) {
            $key = $um.Groups[1].Value + '->' + $um.Groups[2].Value
            if (-not $users.Contains($key)) { [void]$users.Add($key) }
        }
    }
    Say ('      4 distinct user->union pairs added : {0}' -f $users.Count)
    $addedSets[($i+1)] = $users
    foreach ($u in ($users | Select-Object -First 40)) { SayFileOnly ('          + ' + $u) }

    [void]$summ.Add([pscustomobject]@{ N=$i+1; From=$from; Loads=$loads.Count; Inside=$inside
        Adds=$adds.Count; Misses=$misses.Count; Pairs=$users.Count
        WorkSpan=$(if ($workFirst) { ($workLast - $workFirst).TotalSeconds } else { 0 })
        TailSec=$(if ($workLast) { ($winEnd - $workLast).TotalSeconds } else { 0 }) })
}

Say ''
Say '===== 3  comparison ====='
Say '  win  start           LoadRows  inLoad  Add    MISS    pairs  workSpan_s  tailAfterWork_s'
foreach ($s in $summ) {
    Say ('  {0,-4} {1,-15} {2,-9} {3,-7} {4,-6} {5,-7} {6,-6} {7,-11:N1} {8:N1}' -f `
         $s.N, $s.From.ToString('MM-dd HH:mm:ss'), $s.Loads, $s.Inside, $s.Adds, $s.Misses, $s.Pairs, $s.WorkSpan, $s.TailSec)
}

Say ''
Say '===== 4  which candidate the numbers support ====='
$anyOverlap = @($summ | Where-Object { $_.Inside -gt 0 }).Count
Say ('  windows with arrivals inside the load interval : {0}' -f $anyOverlap)
if ($anyOverlap -eq 0) {
    Say '  -> OVERLAP is DEAD: in no window did an arrival fall while the mapping was still loading.'
    Say '     Whatever differed, it is not an incomplete mapping at evaluation time.'
} else {
    Say '  -> OVERLAP is possible in the windows marked above; the count says how many users could have'
    Say '     been evaluated against a partial mapping.'
}
if ($summ.Count -ge 2) {
    $last = $summ[$summ.Count-1]
    $prev = $summ[$summ.Count-2]
    Say ('  previous window: work span {0:N1} s, tail after work {1:N1} s, Add {2}' -f $prev.WorkSpan, $prev.TailSec, $prev.Adds)
    Say ('  current  window: work span {0:N1} s, tail after work {1:N1} s, Add {2}' -f $last.WorkSpan, $last.TailSec, $last.Adds)
    if ($prev.TailSec -lt 60 -and $last.Adds -gt $prev.Adds) {
        Say '  -> TRUNCATION is supported: the earlier window was still producing refreshUnions lines when'
        Say '     it ended, and the later window - same mapping, same arrivals - produced far more. The'
        Say '     population is SLOW, and the first restart was interrupted before it finished.'
    } elseif ($prev.TailSec -ge 60) {
        Say '  -> TRUNCATION is NOT supported: the earlier window fell silent well before it ended, so it'
        Say '     was not cut off mid-work. Something else stopped it, and I do not name it from here.'
    }
    $setPrev = $addedSets[$prev.N]; $setLast = $addedSets[$last.N]
    if ($setPrev -and $setLast) {
        $notIn = @($setPrev | Where-Object { -not $setLast.Contains($_) })
        Say ('  pairs added in the earlier window but NOT in the later : {0}   0 = earlier is a SUBSET' -f $notIn.Count)
        Say '    a subset is the signature of interrupted-but-correct work; a non-subset is not'
        foreach ($n in ($notIn | Select-Object -First 10)) { SayFileOnly ('          ! only-earlier ' + $n) }
    }
}

Say ''
Say '===== verdict - on MY instrument ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Fin ($ctlOk -and ($negCtl -eq 0) -and ($summ.Count -ge 2))
