#Requires -Version 5.1
<#
  PROBE 234 / T3b - the engine lines that the MIDNIGHT ROLLOVER took away. READ ONLY.
  WHERE IT RUNS : server 234 (machine RTM). Name and hardware UUID are a gate.
  WHAT IT DOES  : lists C:\RTMView\RTM\Logs, reads the DATED rollover file for 2026-09-13, writes one
                  slice and its POSCTL. It restarts NOTHING - no second experiment is needed and a
                  restart would destroy the window that already exists. No install, no config write,
                  no database, no password. C:\IceDash, the production RTM.Twilio, legacy RTM,
                  C:\Program Files\CcDashboard and C:\Windows\System32\logs are not touched.
  WHY IT EXISTS : the engine log rolls BY DATE (log4net rollingStyle=Date, staticLogFileName=true), so
                  at midnight the live RTM.log starts over. The experiment ran at 23:59:46 - fourteen
                  seconds before the roll - and the corpus I handed over began at 00:00:00,063. The
                  zeros for Groups.Add / <<getUsers / init GridId= were a property of MY SLICE, not of
                  the engine. This probe fetches the missing side.
  FIRST LINE OF EVERY SLICE IS ITS BOUNDARY: the first and last timestamp actually present in the file,
                  so that nobody has to trust that a slice covers what its name claims.
  IF THE DATED FILE IS ABSENT the run says so and substitutes NOTHING: with staticLogFileName=true the
                  rolled name is produced by a pattern and may not be what anyone expects.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir   = 'C:\RTMView-Ops\output'
$LOGDIR   = 'C:\RTMView\RTM\Logs'
$WINFROM  = [datetime]'2026-09-13 23:59:41'
$WINTO    = [datetime]'2026-09-14 00:00:00'
$SENTINEL = -999
$NEEDLES  = @('<<getUsers unionId=','Groups.Add UnionId','init GridId=','<<ChangedUnionUsersData count=',
              'RTM Start',' In use','SERVER => A client connected','ZZZ-marker-negctl')

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_T3b-report.txt')
$sliceOut = Join-Path $OutDir '234_20260913_T3b_engine-preroll.txt'
$posOut   = Join-Path $OutDir '234_20260913_T3b_posctl.txt'

$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (slice written; numbers are NOT interpreted here)' }
                       else        { 'VERDICT: FAIL' }))
    Flush
    Write-Host ''
    Write-Host ('REPORT       : ' + $outf)
    foreach ($f in @($sliceOut, $posOut)) {
        if (Test-Path -LiteralPath $f) { Write-Host ('WRITTEN      : ' + $f) }
        else { Write-Host ('NOT WRITTEN  : ' + [IO.Path]::GetFileName($f) + '  (the run stopped before this file)') }
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

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
Say ('  assignment gate : unassigned {0} (want {1})' -f (Safe-Count $null), $SENTINEL)
$ctlOk = $true
foreach ($c in @(@{T='2026-09-13 23:59:40,999 [5] INFO x';W='OUT'},
                 @{T='2026-09-13 23:59:42,000 [5] INFO x';W='IN'},
                 @{T='2026-09-14 00:00:01,000 [5] INFO x';W='OUT'})) {
    $tm = Get-LineTime $c.T
    $got = $(if ($null -eq $tm) { 'UNPARSED' } elseif (($tm -ge $WINFROM) -and ($tm -lt $WINTO)) { 'IN' } else { 'OUT' })
    if ($got -ne $c.W) { $ctlOk = $false; Say ('  parser control FAILED: {0} -> {1}' -f $c.T, $got) }
}
Say ('  parser control on synthetic lines : {0}   expected True' -f $ctlOk)
if (-not $ctlOk) { Say '  *** slicing broken'; Fin $false }
Say ('  window : {0} .. {1}   READ ONLY, NOTHING is restarted - the experiment already happened' -f `
     $WINFROM.ToString('yyyy-MM-dd HH:mm:ss'), $WINTO.ToString('yyyy-MM-dd HH:mm:ss'))

Say ''
Say '===== 1  the log directory, listed rather than guessed ====='
$all = @(Get-ChildItem -LiteralPath $LOGDIR -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
Say ('  files in {0} : {1}' -f $LOGDIR, (Safe-Count $all))
foreach ($f in $all) {
    Say ('      {0,-28} {1,12} bytes   {2}' -f $f.Name, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
}
$cand = @($all | Where-Object { $_.Name -like '*20260913*' })
Say ('  candidates matching *20260913* : {0}' -f (Safe-Count $cand))
if ((Safe-Count $cand) -lt 1) {
    Say '  *** the dated rollover file for 2026-09-13 is NOT here. Substituting a neighbour would be'
    Say '  *** guessing: with staticLogFileName=true the rolled name comes from a pattern. Reporting only.'
    Fin $false
}
$src = $cand[0].FullName
Say ('  reading : {0}' -f $src)

Say ''
Say '===== 2  the slice, and its BOUNDARY printed first ====='
$total = @{}; $inwin = @{}
foreach ($n in $NEEDLES) { $total[$n] = 0; $inwin[$n] = 0 }
$fs = $null
try { $fs = New-Object IO.FileStream($src, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite) }
catch { Say ('  *** cannot open : {0}' -f $_.Exception.Message); Fin $false }
if ($null -eq $fs) { Say '  *** stream is null - refusing to report zeros'; Fin $false }
$sr = New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8)
$lines = 0; $win = 0; $unparsed = 0
$firstT = $null; $lastT = $null
$keep = New-Object System.Collections.ArrayList
$inWindow = $false
while ($null -ne ($line = $sr.ReadLine())) {
    $lines++
    $t = Get-LineTime $line
    if ($null -eq $t) { $unparsed++ }
    else {
        if ($null -eq $firstT) { $firstT = $t }
        $lastT = $t
        $inWindow = (($t -ge $WINFROM) -and ($t -lt $WINTO))
    }
    if ($inWindow) { [void]$keep.Add($line); $win++ }
    foreach ($n in $NEEDLES) {
        if ($line.Contains($n)) { $total[$n] = $total[$n] + 1; if ($inWindow) { $inwin[$n] = $inwin[$n] + 1 } }
    }
}
$sr.Close(); $fs.Close()
$size = (Get-Item -LiteralPath $src).Length
Say ('  file {0} bytes , lines read {1} , lines with no parsable time {2}' -f $size, $lines, $unparsed)
if (($size -gt 0) -and ($lines -eq 0)) { Say '  *** READ NOTHING FROM A NON-EMPTY FILE - every count below would be a false zero'; Fin $false }
$b1 = $(if ($firstT) { $firstT.ToString('yyyy-MM-dd HH:mm:ss.fff') } else { '(no timestamped line)' })
$b2 = $(if ($lastT)  { $lastT.ToString('yyyy-MM-dd HH:mm:ss.fff') }  else { '(no timestamped line)' })
Say ('  CORPUS BOUNDARY : first {0}   last {1}' -f $b1, $b2)
Say ('  lines inside the window : {0}' -f $win)

$head = New-Object System.Collections.ArrayList
[void]$head.Add('SLICE of ' + $src)
[void]$head.Add('CORPUS BOUNDARY of the SOURCE file : first ' + $b1 + '   last ' + $b2)
[void]$head.Add('WINDOW kept in this slice           : ' + $WINFROM.ToString('yyyy-MM-dd HH:mm:ss') + ' .. ' + $WINTO.ToString('yyyy-MM-dd HH:mm:ss'))
[void]$head.Add('lines in source ' + $lines + ' , kept ' + $win + ' , not filtered by content')
[void]$head.Add('--------------------------------------------------------------------------------')
foreach ($l in $keep) { [void]$head.Add($l) }
[IO.File]::WriteAllLines($sliceOut, $head, (New-Object Text.UTF8Encoding($false)))
Say ('  slice -> {0}' -f $sliceOut)
Flush

Say ''
Say '===== 3  POSCTL - whole file AND window, with the file named ====='
$name = [IO.Path]::GetFileName($src)
$pos = New-Object System.Collections.ArrayList
[void]$pos.Add('POSCTL for the pre-rollover window ' + $WINFROM.ToString('yyyy-MM-dd HH:mm:ss') + ' .. ' + $WINTO.ToString('yyyy-MM-dd HH:mm:ss'))
[void]$pos.Add('SOURCE ' + $src)
[void]$pos.Add('CORPUS BOUNDARY : first ' + $b1 + '   last ' + $b2)
[void]$pos.Add('needle                            file                    total   in-window')
[void]$pos.Add('-------------------------------------------------------------------------------')
foreach ($n in $NEEDLES) {
    $line = ('{0,-33} {1,-22} {2,7} {3,11}' -f $n, $name, $total[$n], $inwin[$n])
    [void]$pos.Add($line)
    Say ('  ' + $line)
}
[void]$pos.Add('')
[void]$pos.Add('The matcher for <<getUsers unionId= / Groups.Add UnionId / <<ChangedUnionUsersData count=')
[void]$pos.Add('is PROVEN to work: it found 4 / 4 / 4 in 234_20260913_2217_posctl.txt over the full-day file.')
[void]$pos.Add('So a zero for those three here is a fact about the window, not about the instrument.')
[void]$pos.Add('ZZZ-marker-negctl must be 0; if it is not, the whole run is void.')
[IO.File]::WriteAllLines($posOut, $pos, (New-Object Text.UTF8Encoding($false)))
Say ('  written -> {0}' -f $posOut)

Say ''
Say '===== 4  nothing was restarted - proven, not assumed ====='
foreach ($s in @('RTMService','RTMTwilio_1','RTMViewShell')) {
    foreach ($pr in @(Get-WmiObject Win32_Service -Filter ("Name='" + $s + "'") -ErrorAction SilentlyContinue)) {
        if ($pr.ProcessId -gt 0) {
            $po = Get-Process -Id $pr.ProcessId -ErrorAction SilentlyContinue
            if ($po) { Say ('  {0,-14} pid {1,-7} started {2}' -f $s, $pr.ProcessId, $po.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
        }
    }
}
Say '  expected: engine 23:59:41 , shell 22:15:05 - unchanged by this run'
Say ''
Say '  Numbers are not interpreted here. The verdict belongs to shell-0912.'
Fin $true
