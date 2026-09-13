#Requires -Version 5.1
<#
  PROBE 234 / two-windows      the mapping was added; after the FIRST restart the grid stayed empty,
                               after the SECOND restart the agents appeared. Both windows are in the
                               log. This compares them and says WHAT DIFFERED - an order, not a count.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate. READ ONLY.
  Starts nothing, stops nothing, restarts nothing, writes no config, touches no service, queries NO
  database, prompts for no password. C:\IceDash is never read or listed. Only write: its report.

  WHY THIS MATTERS MORE THAN THE GOOD NEWS. The screen works, so the contractor can work. But "restart
  twice and it comes up" is a symptom, not an explanation, and it will be paid for again on the next
  deploy, by someone who does not know to restart twice. Either the log shows a mechanism, or we admit
  we do not know why it works - and the second honest answer is still better than a guess dressed up.

  THE MECHANISM UNDER TEST [re-read in the object store on v3, not guessed]:
    UserManager.cs:665,677  refreshUnions() runs ONLY inside the workgroupActivation handler; never on
                            a timer, and never because a mapping was loaded
    UserManager.cs:570-593  foreach (wgArr in union.UserGroups.Values) { Add, else log MISS need/have }
    Engine.cs:549-555       union.UserGroups is filled ONLY from RTSGrid_GetAllUnionUserGroups rows,
                            each logged "LoadData union=<N> sg=<S> needGroups=[...]"
    RTMAdapter.cs:278       every arrival logged "RECV userWorkgroupActivation workgroup=... active=[...]"
  [operator, 2026-09-13]: on engine startup an API request fetches agents, their membership and the
  queues - so the data arrives without traffic. Then the ONLY thing that can differ between a failing
  and a succeeding start is WHICH CAME FIRST: the mapping row, or the activation it had to be compared
  against. If the activation lands first, UserGroups is still empty, the loop iterates zero times, and
  NEITHER Add NOR MISS is logged - silence indistinguishable from "no mapping".

  WHAT IT DOES. It finds the engine start markers in the logs, takes the last three, and for EACH
  window reports, with times: the mapping rows loaded, the first activation received, how many Add and
  MISS, the count= values, and whether mapping-before-activation held. Then it compares the windows.

  THE OUTCOMES, named before the numbers:
    RACE CONFIRMED : in the window with Add=0 the first activation precedes the first mapping row, and
                     in the window with Add>0 the mapping row precedes it. Then the defect is an order
                     at startup, the fix is deterministic (load the mapping before accepting the
                     snapshot, or re-run refreshUnions after a mapping load), and "restart twice" stops
                     being folklore.
    NOT A RACE      : the order is the same in both windows. Then my hypothesis is WRONG, I say so, and
                     the difference is elsewhere - most likely the mapping was not yet visible to the
                     engine's query at the first start. That is a different fix and must not be
                     smuggled in under the same name.
    UNDECIDABLE     : fewer than two start windows are in the retained logs, or a window has neither
                     Add nor MISS nor activations. Then the probe says undecidable rather than picking
                     the convenient reading.

  EXPECTATIONS:
     start markers found : >= 2   (POSCTL - with fewer, the comparison cannot be made and I say so)
     NEGCTL : an impossible string -> 0
  Hebrew goes to the FILE only; reads are -Encoding UTF8 so names are the real names.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_two-windows.txt')
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
Say ('  Get-LineTime resolves to : {0}   expected Function' -f $r.CommandType)
if ("$($r.CommandType)" -ne 'Function') { Say '  *** helper shadowed - stop'; Fin $false }
Say ('  now : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

Say ''
Say '===== G1  parser control - synthetic lines, both formats, never asks the data ====='
$ctlMark = [datetime]'2026-09-13 12:00:00'
$ctls = @(
    @{ T = '2026-09-13 11:00:00,001 [5] INFO  x'; W = 'BEFORE' },
    @{ T = '2026-09-13 13:00:00,001 [5] INFO  x'; W = 'AFTER'  },
    @{ T = ' 13/09/2026 11:00:00,002 INFO  x';    W = 'BEFORE' },
    @{ T = ' 13/09/2026 13:00:00,002 INFO  x';    W = 'AFTER'  }
)
$ctlOk = $true
foreach ($c in $ctls) {
    $tm = Get-LineTime $c.T
    $got = $(if ($null -eq $tm) { 'UNPARSED' } elseif ($tm -gt $ctlMark) { 'AFTER' } else { 'BEFORE' })
    if ($got -ne $c.W) { $ctlOk = $false }
    Say ('  want {0,-6} got {1,-8} -> {2}' -f $c.W, $got, ($got -eq $c.W))
}
Say ('  parser control : {0}   expected True' -f $ctlOk)
if (-not $ctlOk) { Say '  *** slicing broken - refusing to compare windows'; Fin $false }

Say ''
Say '===== 1  engine log files, discovered from the SERVICE MANAGER ====='
$svcEngine = Get-WmiObject Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
if (-not $svcEngine) { Say '  *** RTMService not found'; Fin $false }
$exe = "$($svcEngine.PathName)".Trim()
if ($exe.StartsWith('"')) { $exe = $exe.Substring(1, $exe.IndexOf('"', 1) - 1) }
else { $sp = $exe.IndexOf(' -'); if ($sp -gt 0) { $exe = $exe.Substring(0, $sp) } }
$engineDir = [IO.Path]::GetDirectoryName($exe)
Say ('  engine directory : {0}' -f $engineDir)
$pEngine = Get-Process -Id $svcEngine.ProcessId -ErrorAction SilentlyContinue
if ($pEngine) { Say ('  RTMService pid {0} started {1}  <- the CURRENT (succeeding) start' -f $pEngine.Id, $pEngine.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
$svcAdapter = Get-WmiObject Win32_Service -Filter "Name='RTMTwilio_1'" -ErrorAction SilentlyContinue
if ($svcAdapter) {
    $pAd = Get-Process -Id $svcAdapter.ProcessId -ErrorAction SilentlyContinue
    if ($pAd) { Say ('  RTMTwilio_1 pid {0} started {1}' -f $pAd.Id, $pAd.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
}

$all = New-Object System.Collections.ArrayList
$unparsed = 0
$negCtl = 0
foreach ($root in @((Join-Path $engineDir 'Logs'), 'C:\Logs\RTM')) {
    if (-not (Test-Path -LiteralPath $root)) { Say ('  {0} : absent' -f $root); continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match '(?i)^RTM\.log$|^RTM\.log2026|^log\.txt$' } |
                     Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-30) } | Sort-Object LastWriteTime)) {
        $lines = @(Get-Content -LiteralPath $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue)
        Say ('  {0}   {1} bytes   lines {2}' -f $f.FullName, $f.Length, $lines.Count)
        foreach ($line in $lines) {
            if ($line.Contains('ZZZ-cannot-occur-ZZZ')) { $negCtl++ }
            $tm = Get-LineTime $line
            if ($null -eq $tm) { $unparsed++; continue }
            [void]$all.Add([pscustomobject]@{ Time = $tm; Text = $line })
        }
    }
}
$all = @($all | Sort-Object Time)
Say ('  timed lines collected : {0} , unparsed (stack traces etc) : {1}' -f $all.Count, $unparsed)
Say ('  NEGCTL impossible string : {0}   expected 0' -f $negCtl)
if ($all.Count -lt 1) { Say '  *** nothing timed to read'; Fin $false }

Say ''
Say '===== 2  engine START markers - the window boundaries ====='
$startNeedles = @('RTM Start', 'LoadData: Union User Groups')
$marks = $null
foreach ($needle in $startNeedles) {
    $cand = @($all | Where-Object { $_.Text.Contains($needle) })
    Say ('  marker "{0}" : {1} occurrences' -f $needle, $cand.Count)
    if (($null -eq $marks) -and ($cand.Count -ge 2)) { $marks = $cand; $chosen = $needle }
}
if ($null -eq $marks) { Say '  *** fewer than two start markers - the comparison is UNDECIDABLE. Stopping.'; Fin $true }
Say ('  using marker : "{0}"' -f $chosen)
# collapse markers that are seconds apart - one start can print the banner more than once
$starts = New-Object System.Collections.ArrayList
foreach ($m in $marks) {
    if ($starts.Count -eq 0) { [void]$starts.Add($m.Time); continue }
    $last = $starts[$starts.Count - 1]
    if (($m.Time - $last).TotalSeconds -gt 60) { [void]$starts.Add($m.Time) }
}
Say ('  distinct starts (markers closer than 60 s collapsed) : {0}' -f $starts.Count)
$take = @($starts | Select-Object -Last 3)
foreach ($s in $take) { Say ('      start at {0}' -f $s.ToString('yyyy-MM-dd HH:mm:ss')) }
if ($take.Count -lt 2) { Say '  *** fewer than two distinct starts retained - UNDECIDABLE. Stopping.'; Fin $true }

Say ''
Say '===== 3  each window, measured separately ====='
$summaries = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $take.Count; $i++) {
    $from = $take[$i]
    $to = $(if ($i -lt $take.Count - 1) { $take[$i + 1] } else { [datetime]::MaxValue })
    $win = @($all | Where-Object { $_.Time -ge $from -and $_.Time -lt $to })
    $loads = @($win | Where-Object { $_.Text.Contains('LoadData union=') })
    $recvs = @($win | Where-Object { $_.Text.Contains('RECV userWorkgroupActivation') })
    $actsAny = @($win | Where-Object { $_.Text.Contains('workgroupActivation') })
    $adds = @($win | Where-Object { $_.Text.Contains('refreshUnions Add') })
    $misses = @($win | Where-Object { $_.Text.Contains('refreshUnions MISS') })
    $counts = @($win | Where-Object { $_.Text.Contains('ChangedUnionUsersData count=') })
    $pushes = @($win | Where-Object { $_.Text.Contains('PUSH updateUserGrid') })
    $firstLoad = $(if ($loads.Count -gt 0) { $loads[0].Time } else { $null })
    $firstAct  = $(if ($recvs.Count -gt 0) { $recvs[0].Time } elseif ($actsAny.Count -gt 0) { $actsAny[0].Time } else { $null })
    $order = 'undecidable'
    if ($firstLoad -and $firstAct) { $order = $(if ($firstLoad -lt $firstAct) { 'mapping FIRST' } else { 'activation FIRST' }) }
    Say ''
    Say ('  --- window {0} : {1}  ->  {2} ---' -f ($i + 1), $from.ToString('MM-dd HH:mm:ss'), $(if ($to -eq [datetime]::MaxValue) { 'now' } else { $to.ToString('MM-dd HH:mm:ss') }))
    Say ('      lines in window        : {0}' -f $win.Count)
    Say ('      LoadData union= rows   : {0}   first at {1}' -f $loads.Count, $(if ($firstLoad) { $firstLoad.ToString('HH:mm:ss.fff') } else { 'none' }))
    $ids = New-Object System.Collections.ArrayList
    foreach ($l in $loads) {
        $mm = [regex]::Match($l.Text, 'LoadData union=(\d+)\s+sg=(\d+)')
        if ($mm.Success) { $uid = [int]$mm.Groups[1].Value; if (-not $ids.Contains($uid)) { [void]$ids.Add($uid) } }
        SayFileOnly ('          | ' + $l.Text.Trim())
    }
    Say ('      unions in mapping      : ' + (@($ids | Sort-Object) -join ', '))
    Say ('      RECV activations       : {0}   first at {1}' -f $recvs.Count, $(if ($firstAct) { $firstAct.ToString('HH:mm:ss.fff') } else { 'none' }))
    Say ('      refreshUnions Add      : {0}' -f $adds.Count)
    Say ('      refreshUnions MISS     : {0}' -f $misses.Count)
    Say ('      ChangedUnionUsersData  : {0}' -f $counts.Count)
    foreach ($c in $counts) {
        $cm = [regex]::Match($c.Text, 'count=(\d+)')
        Say ('          {0}  count = {1}' -f $c.Time.ToString('HH:mm:ss.fff'), $cm.Groups[1].Value)
    }
    Say ('      PUSH updateUserGrid    : {0}' -f $pushes.Count)
    Say ('      ORDER                  : {0}' -f $order)
    foreach ($a in @($adds | Select-Object -First 30)) { SayFileOnly ('          + ' + $a.Text.Trim()) }
    foreach ($ms in @($misses | Select-Object -First 15)) { SayFileOnly ('          - ' + $ms.Text.Trim()) }
    [void]$summaries.Add([pscustomobject]@{
        N = $i + 1; From = $from; Order = $order; Adds = $adds.Count; Misses = $misses.Count
        Loads = $loads.Count; Recvs = $recvs.Count; Counts = $counts.Count; Pushes = $pushes.Count
        FirstLoad = $firstLoad; FirstAct = $firstAct
    })
}

Say ''
Say '===== 4  THE COMPARISON - what differed between a failing and a succeeding start ====='
Say '  win  start              order              Add   MISS  LoadRows  RECV   count=  PUSH'
foreach ($s in $summaries) {
    Say ('  {0,-4} {1,-18} {2,-18} {3,-5} {4,-5} {5,-9} {6,-6} {7,-7} {8}' -f `
         $s.N, $s.From.ToString('MM-dd HH:mm:ss'), $s.Order, $s.Adds, $s.Misses, $s.Loads, $s.Recvs, $s.Counts, $s.Pushes)
}
$withAdds = @($summaries | Where-Object { $_.Adds -gt 0 })
$withoutAdds = @($summaries | Where-Object { $_.Adds -eq 0 -and $_.Recvs -gt 0 })
Say ''
Say ('  windows that DID populate (Add > 0)            : {0}' -f $withAdds.Count)
Say ('  windows with activations but NO Add and NO MISS : {0}' -f @($summaries | Where-Object { $_.Adds -eq 0 -and $_.Misses -eq 0 -and $_.Recvs -gt 0 }).Count)
if ($withAdds.Count -gt 0 -and $withoutAdds.Count -gt 0) {
    $ordersGood = @($withAdds | ForEach-Object { $_.Order } | Sort-Object -Unique)
    $ordersBad  = @($withoutAdds | ForEach-Object { $_.Order } | Sort-Object -Unique)
    Say ('  order in populating windows    : ' + ($ordersGood -join ' / '))
    Say ('  order in non-populating windows : ' + ($ordersBad -join ' / '))
    if (($ordersGood -contains 'mapping FIRST') -and ($ordersBad -contains 'activation FIRST')) {
        Say '  -> RACE CONFIRMED by the logs: the populating start had the mapping in memory before the'
        Say '     first activation arrived; the failing one did not. "Restart twice" is this race, and the'
        Say '     fix is deterministic rather than folklore.'
    } elseif ($ordersGood -eq $ordersBad) {
        Say '  -> NOT A RACE: the order is the SAME in both. My hypothesis is wrong and I say so. The'
        Say '     difference lies elsewhere - most likely the mapping was not yet visible to the engine'
        Say '     query at the earlier start. That is a different fix and must not borrow this name.'
    } else {
        Say '  -> MIXED: the orders do not separate the two groups cleanly. Undecidable from this data;'
        Say '     I will not pick the convenient reading.'
    }
} else {
    Say '  -> cannot compare: the retained windows do not include both a populating and a'
    Say '     non-populating start. UNDECIDABLE, and I say so rather than inferring.'
}

Say ''
Say '===== verdict - on MY instrument ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Say ('  parser control {0} ; windows compared {1} ; NEGCTL {2}' -f $ctlOk, $summaries.Count, $negCtl)
Fin ($ctlOk -and ($negCtl -eq 0) -and ($summaries.Count -ge 2))
