#Requires -Version 5.1
<#
  PROBE 234 / engine-predicate      PR234-SHELL-RESUB-01 measured from the ENGINE side only.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate; it refuses to run
                  anywhere else. EVERY line of this box runs on 234.

  *** THIS BOX WRITES ON PRODUCTION: it DELETES one of our own report files, and it RESTARTS ONE SERVICE. ***
  It restarts RTMService (the engine) and nothing else. It does not touch RTMTwilio_1. It does not touch
  the Shell service - leaving the Shell alone IS the predicate - and it records the Shell PID before and
  after, failing the run if that PID changed. It writes NO config: the diagnostic flag stays false, which
  is where the previous cycle left it. No database query, no password prompt. C:\IceDash is never read.

  WHY THIS REPLACES THE FLAG-AND-SHELL-LOG APPROACH [coordinator, 2026-09-13 12:3x, accepting my
  recommendation]. The Shell has written no log line anywhere since 02:38:58, which was the OLD process
  speaking 16 seconds before it stopped; the service restarted at 02:39:14 and has been silent in all
  three candidate directories for over ten hours. So the control that looked for RECV updateUserGrid in
  the Shell log would have returned zero whatever the flag was set to - the needle was blind for a reason
  that had nothing to do with the flag. The question itself, though, does not need the Shell's log at all:
      "does anything ask the engine again after ONLY the engine restarts?"
  is answered by the ENGINE's own log. `<<getUsers unionId=` is written when a Shell client registers its
  grid subscription (RTMHub.AddGridConnection -> Engine.getUsers), so its presence or absence after a
  lone engine restart IS the predicate. This costs one fewer production write - no flag to turn on - and
  does not depend on a component that currently cannot report anything.

  THE EXPECTATION, NAMED BEFORE THE RUN:
    `<<getUsers unionId=` after the mark, with NO Shell restart
        >= 1  -> the Shell DOES re-register after an engine restart. Then PR234-SHELL-RESUB-01 is wrong as
                 stated and the empty grid of windows 2 and 3 needs another explanation.
        = 0   -> confirmed: nothing asks the engine again, the consumer is stale, and a populated
                 union.Users is invisible until the Shell process is restarted.
  Reported, not gated: which branch the numbers select is the coordinator's call. The instrument is what
  this probe gates on.

  THE PAGE MUST BE OPEN. The coordinator keeps the Agent Grid open; a closed page would make the consumer
  half meaningless. This probe CANNOT verify that from here and says so rather than implying it.

  HYGIENE FIRST, AND IT IS FIRST FOR A REASON [coordinator, 12:4x]. My previous probe printed a
  connection string with a password into its own report. The local copy was redacted and that folder is
  git-ignored, but the copy in our ops output directory on this server still carries the value. Deleting
  it is step ONE here, before any measurement, and it is proven by a number: the file is gone, and no file
  left in that directory carries an unmasked password=. The scan COUNTS occurrences and never prints a
  value - the same form the coordinator used when he audited the bus.

  CONTROLS:
    assignment gate - every count goes through Safe-Count, which returns -999 for an unassigned value
                      instead of 0, self-tested on three inputs before anything is measured
    parser control  - four synthetic lines, two per log format on this machine, must fall on the expected
                      side of a boundary; it never consults the data
    POSCTL          - AsyncLogger lines in the engine log, before and after the mark
    NEGCTL          - an impossible string, per file, must be 0
    Shell-untouched - Shell PID identical before and after, or the run FAILS
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$LEAKFILE = 'C:\RTMView-Ops\output\234_20260913_121340_resub-v6.txt'
$SENTINEL = -999
$WAIT_ONE = 90
$WAIT_TWO = 300
$NEG = 'ZZZ-cannot-occur-ZZZ'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_engine-predicate.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound - numbers are not evidence)' }))
    Flush
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Safe-Count($collection) {
    if ($null -eq $collection) { return $SENTINEL }
    return @($collection).Count
}
$FORMATS = @('yyyy-MM-dd HH:mm:ss,fff','dd/MM/yyyy HH:mm:ss,fff','yyyy-MM-dd HH:mm:ss.fff','yyyy-MM-dd HH:mm:ss','dd/MM/yyyy HH:mm:ss')
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

Say '===== 0  machine, instrument, self-tests ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
foreach ($h in @('Get-LineTime','Safe-Count')) {
    $rr = Get-Command $h -ErrorAction SilentlyContinue
    Say ('  {0} resolves to {1}   expected Function' -f $h, $rr.CommandType)
    if ("$($rr.CommandType)" -ne 'Function') { Say '  *** helper shadowed - stop'; Fin $false }
}
Say ('  PowerShell {0} ; now {1}' -f $PSVersionTable.PSVersion, (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('  assignment gate : unassigned {0} (want {1}) , empty {2} (want 0) , two {3} (want 2)' -f $gA, $SENTINEL, $gB, $gC)
$gateOk = (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2))
if (-not $gateOk) { Say '  *** assignment gate broken - measuring nothing'; Fin $false }
$ctlMark = [datetime]'2026-09-13 12:00:00'
$ctlOk = $true
foreach ($c in @(@{T='2026-09-13 11:00:00,001 [5] INFO x';W='BEFORE'},@{T='2026-09-13 13:00:00,001 [5] INFO x';W='AFTER'},
                 @{T=' 13/09/2026 11:00:00,002 INFO x';W='BEFORE'},@{T=' 13/09/2026 13:00:00,002 INFO x';W='AFTER'})) {
    $tm = Get-LineTime $c.T
    $got = $(if ($null -eq $tm) { 'UNPARSED' } elseif ($tm -gt $ctlMark) { 'AFTER' } else { 'BEFORE' })
    if ($got -ne $c.W) { $ctlOk = $false }
}
Say ('  parser control (4 synthetic lines, both formats) : {0}   expected True' -f $ctlOk)
if (-not $ctlOk) { Say '  *** slicing broken - measuring nothing'; Fin $false }
Flush

Say ''
Say '===== 1  HYGIENE FIRST - removing the report that carries an unmasked value ====='
Say '  My own leak: a previous probe printed a connection string with a password into its report. The'
Say '  local copy is redacted and that folder is git-ignored; this is the copy on this server.'
Say ('  target : {0}   exists {1}' -f $LEAKFILE, (Test-Path -LiteralPath $LEAKFILE))
if (Test-Path -LiteralPath $LEAKFILE) {
    Remove-Item -LiteralPath $LEAKFILE -Force -ErrorAction Continue
}
Say ('  after the delete, exists : {0}   expected False' -f (Test-Path -LiteralPath $LEAKFILE))
if (Test-Path -LiteralPath $LEAKFILE) { Say '  *** could not delete it - stopping, hygiene comes before measurement'; Fin $false }

Say '  --- scanning the whole output directory. Occurrences are COUNTED; no value is ever printed ---'
$dirty = New-Object System.Collections.ArrayList
$scanned = 0
foreach ($f in @(Get-ChildItem -LiteralPath $OutDir -File -ErrorAction SilentlyContinue)) {
    $scanned++
    $hits = 0
    foreach ($line in @(Get-Content -LiteralPath $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        # count an unmasked assignment only: "password=" followed by something that is not a redaction marker
        if ($line -match '(?i)password\s*=\s*[^\s";<]') { $hits++ }
    }
    if ($hits -gt 0) { [void]$dirty.Add([pscustomobject]@{ Name = $f.Name; Hits = $hits }) }
}
Say ('  files scanned : {0}' -f $scanned)
Say ('  files still carrying an unmasked password= : {0}   expected 0' -f (Safe-Count $dirty))
foreach ($d in $dirty) { Say ('      {0}   occurrences {1}   <- NAME and COUNT only, by design' -f $d.Name, $d.Hits) }
if ((Safe-Count $dirty) -gt 0) {
    Say '  *** other files in our ops output still carry unmasked values. I delete ONLY the file I was'
    Say '      told to delete - removing someone else artifact on my own judgement is not my call. The'
    Say '      names and counts are above; taking them to the coordinator rather than acting.'
}
Flush

Say ''
Say '===== 2  DISCOVERY - the engine and the Shell, from the service manager ====='
$svcEngine = Get-WmiObject Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
if (-not $svcEngine) { Say '  *** RTMService not found - stop'; Fin $false }
$engExe = "$($svcEngine.PathName)".Trim()
if ($engExe.StartsWith('"')) { $engExe = $engExe.Substring(1, $engExe.IndexOf('"', 1) - 1) }
else { $q = $engExe.IndexOf(' -'); if ($q -gt 0) { $engExe = $engExe.Substring(0, $q) } }
$engineDir = [IO.Path]::GetDirectoryName($engExe)
Say ('  engine : {0}   state {1}' -f $engExe, $svcEngine.State)
Say ('      ProductVersion {0}' -f (Get-Item -LiteralPath $engExe).VersionInfo.ProductVersion)
$pEngBefore = Get-Process -Id $svcEngine.ProcessId -ErrorAction SilentlyContinue
if ($pEngBefore) { Say ('      pid {0}   started {1}' -f $pEngBefore.Id, $pEngBefore.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }

$svcShell = @(Get-WmiObject Win32_Service -ErrorAction SilentlyContinue |
              Where-Object { $_.PathName -match '(?i)RTMView\\Shell' }) | Select-Object -First 1
if (-not $svcShell) { Say '  *** the Shell service was not found by path RTMView\Shell - stop, I will not guess it'; Fin $false }
$shellPidBefore = $svcShell.ProcessId
Say ('  shell  : {0}   state {1}   pid BEFORE {2}   <- must be IDENTICAL at the end' -f $svcShell.Name, $svcShell.State, $shellPidBefore)
$svcAd = Get-Service -Name 'RTMTwilio_1' -ErrorAction SilentlyContinue
if ($svcAd) { Say ('  adapter: RTMTwilio_1 {0}   (not touched by this box)' -f $svcAd.Status) }

$engFiles = New-Object System.Collections.ArrayList
foreach ($root in @((Join-Path $engineDir 'Logs'), 'C:\Logs\RTM')) {
    if (-not (Test-Path -LiteralPath $root)) { Say ('  {0} : absent' -f $root); continue }
    $found = @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '(?i)^RTM\.log$|^RTM\.log2026|^log\.txt$' } | Sort-Object LastWriteTime -Descending)
    Say ('  {0} : matching files {1}' -f $root, (Safe-Count $found))
    foreach ($f in $found) {
        $ageH = [Math]::Round(((Get-Date) - $f.LastWriteTime).TotalHours, 1)
        $take = ($ageH -le 30)
        Say ('      {0}   {1} bytes   mtime {2}   age {3} h   read : {4}' -f `
             $f.Name, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $ageH, $take)
        if ($take) { [void]$engFiles.Add($f.FullName) }
    }
    if ((Safe-Count $found) -gt 0) { Say ('      NEWEST here : {0}   mtime {1}' -f $found[0].Name, $found[0].LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) }
}
Say ('  engine files to read : {0}   expected >= 1' -f (Safe-Count $engFiles))
if ((Safe-Count $engFiles) -lt 1) { Say '  *** no engine log to read - refusing to restart anything'; Fin $false }

$NEEDLES = @(
    '<<getUsers unionId=', 'Groups.Add UnionId =', 'init GridId=', '<<ChangedUnionUsersData count=',
    'PUSH updateUserGrid', 'SERVER => A client connected', 'client disconnected',
    'LoadData: Start', 'LoadData union=', 'isComplete=TRUE'
)
function Read-Engine() {
    $acc = New-Object System.Collections.ArrayList
    foreach ($p in $engFiles) {
        foreach ($line in @(Get-Content -LiteralPath $p -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            [void]$acc.Add([pscustomobject]@{ Time = (Get-LineTime $line); Text = $line })
        }
    }
    return $acc
}

Say ''
Say '===== 3  POSCTL over the whole engine corpus, BEFORE anything is restarted ====='
$corpus0 = Read-Engine
Say ('  lines {0} , with a parsed time {1}' -f (Safe-Count $corpus0), (Safe-Count @($corpus0 | Where-Object { $null -ne $_.Time })))
$suspect = New-Object System.Collections.ArrayList
foreach ($n in $NEEDLES) {
    $c = Safe-Count @($corpus0 | Where-Object { $_.Text.Contains($n) })
    if ($c -eq $SENTINEL) { Say ('  *** needle {0} UNASSIGNED - stop' -f $n); Fin $false }
    $flag = ''
    if ($c -eq 0) { $flag = '   <- MATCHER SUSPECT: absent in the whole corpus, so its zeros are NOT findings'; [void]$suspect.Add($n) }
    Say ('  {0,-32} {1}{2}' -f $n, $c, $flag)
    if ($c -gt 0) {
        $last = @($corpus0 | Where-Object { $_.Text.Contains($n) -and $null -ne $_.Time } | Sort-Object Time)
        if ((Safe-Count $last) -gt 0) {
            $l = $last[$last.Count-1]
            Say ('          latest {0}' -f $l.Time.ToString('MM-dd HH:mm:ss.fff'))
        }
    }
}
$posctl0 = Safe-Count @($corpus0 | Where-Object { $_.Text.Contains('AsyncLogger') })
$negctl0 = Safe-Count @($corpus0 | Where-Object { $_.Text.Contains($NEG) })
Say ('  POSCTL AsyncLogger : {0}   expected > 0' -f $posctl0)
Say ('  NEGCTL             : {0}   expected 0' -f $negctl0)
if ($posctl0 -lt 1 -or $negctl0 -ne 0) { Say '  *** controls failed - measuring nothing'; Fin $false }
if ($suspect -contains '<<getUsers unionId=') {
    Say '  *** the MAIN needle is absent from the entire corpus. Then its absence after the restart would'
    Say '      prove nothing at all, and I will not restart production to collect a meaningless zero.'
    Fin $false
}
Flush

Say ''
Say '===== 4  THE MARK and the restart of the ENGINE ONLY ====='
Say '  The Agent Grid page must be OPEN right now and stay open. This probe cannot verify that and does'
Say '  not pretend to: with the page closed, the consumer half of this run means nothing.'
Say '  The diagnostic flag stays FALSE - this run needs no config change at all.'
$MarkTime = Get-Date
Say ('  MARK (this probe own clock) : {0}' -f $MarkTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))
Flush
Restart-Service -Name 'RTMService' -Force -ErrorAction Continue
Start-Sleep -Seconds 3
$svcEngine2 = Get-WmiObject Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
Say ('  RTMService after restart : {0}   pid {1}   (was {2})' -f $svcEngine2.State, $svcEngine2.ProcessId, $svcEngine.ProcessId)
$svcShell2 = Get-WmiObject Win32_Service -Filter ("Name='" + $svcShell.Name + "'") -ErrorAction SilentlyContinue
Say ('  Shell pid now {0} , before {1} , UNCHANGED : {2}   expected True' -f $svcShell2.ProcessId, $shellPidBefore, ($svcShell2.ProcessId -eq $shellPidBefore))
if ($svcShell2.ProcessId -ne $shellPidBefore) {
    Say '  *** the Shell process CHANGED. The predicate of this run is that the Shell was NOT restarted,'
    Say '      so the run is void. Reporting and stopping.'
    Fin $false
}
$svcAd2 = Get-Service -Name 'RTMTwilio_1' -ErrorAction SilentlyContinue
if ($svcAd2) { Say ('  RTMTwilio_1 : {0}   (untouched)' -f $svcAd2.Status) }
Flush

function Reading($label) {
    Say ''
    Say ('===== READING ' + $label + ' at ' + (Get-Date).ToString('HH:mm:ss') + ' =====')
    $c = Read-Engine
    $after = @($c | Where-Object { $null -ne $_.Time -and $_.Time -gt $MarkTime } | Sort-Object Time)
    Say ('  engine lines after the mark : {0}' -f (Safe-Count $after))
    foreach ($n in $NEEDLES) {
        $h = @($after | Where-Object { $_.Text.Contains($n) })
        $mark = ''
        if ($suspect -contains $n) { $mark = '   (matcher suspect - not a finding)' }
        Say ('  {0,-32} {1}{2}' -f $n, (Safe-Count $h), $mark)
        foreach ($x in @($h | Select-Object -First 10)) {
            Say ('      {0}  | {1}' -f $x.Time.ToString('HH:mm:ss.fff'), $x.Text.Trim().Substring(0, [Math]::Min(150, $x.Text.Trim().Length)))
        }
    }
    Say ('  POSCTL AsyncLogger after the mark : {0}' -f (Safe-Count @($after | Where-Object { $_.Text.Contains('AsyncLogger') })))
    Say ('  NEGCTL                            : {0}   expected 0' -f (Safe-Count @($after | Where-Object { $_.Text.Contains($NEG) })))
    Flush
    return $after
}

Start-Sleep -Seconds $WAIT_ONE
$r1 = Reading 'ONE (+90 s)'
Start-Sleep -Seconds $WAIT_TWO
$r2 = Reading 'TWO (+6.5 min)'

Say ''
Say '===== 5  THE PREDICATE, and the growth between the two readings ====='
$ask1 = Safe-Count @($r1 | Where-Object { $_.Text.Contains('<<getUsers unionId=') })
$ask2 = Safe-Count @($r2 | Where-Object { $_.Text.Contains('<<getUsers unionId=') })
Say ('  <<getUsers unionId= after the mark : reading one {0} , reading two {1}' -f $ask1, $ask2)
Say '  expectation named BEFORE the run:'
Say '    >= 1 -> the Shell DOES re-register after a lone engine restart; PR234-SHELL-RESUB-01 is wrong'
Say '            as stated, and the empty grid of windows 2 and 3 needs another explanation'
Say '    = 0  -> confirmed: nothing asks the engine again; a populated union.Users stays invisible until'
Say '            the Shell process itself is restarted'
Say '  Reported, NOT gated: the branch is the coordinator call.'
foreach ($n in @('<<ChangedUnionUsersData count=','PUSH updateUserGrid','Groups.Add UnionId =','init GridId=','SERVER => A client connected')) {
    Say ('  {0,-32} {1} -> {2}' -f $n,
         (Safe-Count @($r1 | Where-Object { $_.Text.Contains($n) })),
         (Safe-Count @($r2 | Where-Object { $_.Text.Contains($n) })))
}
Say ('  lines after the mark : {0} -> {1} , grew {2}' -f (Safe-Count $r1), (Safe-Count $r2), ((Safe-Count $r2) -gt (Safe-Count $r1)))

Say ''
Say '===== verdict - on MY instrument only ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Say ('  assignment gate {0} ; parser {1} ; Shell pid unchanged True ; suspect needles {2} ; leak file removed True' -f `
     $gateOk, $ctlOk, (Safe-Count $suspect))
Fin ($gateOk -and $ctlOk)
