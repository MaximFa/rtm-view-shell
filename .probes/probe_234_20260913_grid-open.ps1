#Requires -Version 5.1
<#
  PROBE 234 / grid-open      the coordinator opened the Agent Grid at 01:59:14 and holds it open.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate; it refuses
                  to run anywhere else. EVERY line of this box runs on 234. READ ONLY.
  Starts nothing, stops nothing, restarts nothing, writes no config, touches no service, queries no
  database. C:\IceDash is never read, listed or searched. Only output is its report.

  WHAT THIS RUN IS FOR. The screen shows Widget_NoAgents ("the source is empty"), and NoMatchingAgents
  is absent, so a filter is not the cause. Opening the grid is the only thing that raises
  RTMHub.AddGridConnection -> Engine.getUsers -> getUnionUserData() -> PUSH updateUserGrid, so the
  numbers after 01:59:14 answer the coordinator's three-way branch, named by him BEFORE these numbers:
    count > 0 and PUSH present, screen empty  -> the engine HAS the list; subject is between engine
                                                 and Shell (relay / hub / union group). Adapter cleared.
    count = 0 or no PUSH, getUsers present    -> the engine did not get the list: the pipe carried a
                                                 connection but not the data.
    no getUsers after the mark at all         -> the request never reached the engine; subject is in
                                                 Shell -> hub, again not the adapter.

  MY TWO DEFECTS FROM THE PREVIOUS PROBE, FIXED HERE - they are the subject, not a footnote:
   1. I printed count WITHOUT its timestamp, on exactly the line whose timestamp decides whether it
      belongs to this window. Here every matched line is printed VERBATIM, time included, and the
      parsed time is printed next to it.
   2. Sections 5/6 read the files WHOLE, with no cut at the mark, although the cut was the point.
      Here every line is assigned to AFTER / BEFORE / UNPARSED, the three buckets are counted, and
      UNPARSED is PRINTED, never silently dropped - a line whose time I cannot read must not be able
      to hide in either half.

  THE INSTRUMENT CONTROL, and why it is not circular. "Nothing after the mark" is a real possible
  finding here, so I cannot use "found something after the mark" as proof that the slicing works.
  Instead two SYNTHETIC lines, one clearly before and one clearly after the mark, are pushed through
  the SAME parser and the SAME comparison: the first must land BEFORE, the second AFTER. If that
  control fails, the probe stops and measures nothing. Two log formats live on this machine
  (`2026-09-13 00:52:31,531 [5] INFO ...` and ` 13/09/2026 00:52:36,502 INFO ...`), so both forms are
  fed through the control.

  EXPECTATIONS, NAMED BEFORE THE RUN:
     parser control : synthetic-before -> BEFORE , synthetic-after -> AFTER , both formats
     engine log files discovered from the SERVICE MANAGER, not written by me : >= 1
     NEGCTL : a string that cannot occur -> 0 in the after-mark window
     the seven content counts are PRINTED, NOT GATED - the branch is the coordinator's call
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$MarkTime = [datetime]'2026-09-13 01:59:14'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_grid-open.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound - numbers below are not evidence)' }))
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

Say '===== 0  machine identity and the instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq $UUIDGATE)
Say ('  name  expected {0} , actual {1} -> {2}' -f $NAMEGATE, $env:COMPUTERNAME, $nameOk)
Say ('  uuid  expected {0} , actual {1} -> {2}' -f $UUIDGATE, $uuid, $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say '  *** NOT server 234 - refusing to measure'; Fin $false }
Say ('  PowerShell {0}' -f $PSVersionTable.PSVersion)
$resolvedFn = Get-Command Get-LineTime -ErrorAction SilentlyContinue
Say ('  Get-LineTime resolves to : {0}   expected Function' -f $resolvedFn.CommandType)
if ("$($resolvedFn.CommandType)" -ne 'Function') { Say '  *** the time parser is shadowed - stop'; Fin $false }
Say ('  mark : {0}   (coordinator opened the Agent Grid at this local time)' -f $MarkTime.ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  now  : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

Say ''
Say '===== G1  PARSER CONTROL - synthetic lines, both formats. Not circular: it never asks the DATA ====='
$controls = @(
    @{ Text = '2026-09-13 01:00:00,001 [5] INFO  RTM.Tools.AsyncLogger - synthetic BEFORE'; Want = 'BEFORE' },
    @{ Text = '2026-09-13 02:30:00,001 [5] INFO  RTM.Tools.AsyncLogger - synthetic AFTER';  Want = 'AFTER'  },
    @{ Text = ' 13/09/2026 01:00:00,002 INFO  synthetic BEFORE slash-format';                Want = 'BEFORE' },
    @{ Text = ' 13/09/2026 02:30:00,002 INFO  synthetic AFTER slash-format';                 Want = 'AFTER'  }
)
$controlOk = $true
foreach ($c in $controls) {
    $tm = Get-LineTime $c.Text
    if ($null -eq $tm) { $verdict = 'UNPARSED' } elseif ($tm -gt $MarkTime) { $verdict = 'AFTER' } else { $verdict = 'BEFORE' }
    $ok = ($verdict -eq $c.Want)
    if (-not $ok) { $controlOk = $false }
    Say ('  want {0,-6} got {1,-8} parsed {2,-23} -> {3}   | {4}' -f `
         $c.Want, $verdict, $(if ($tm) { $tm.ToString('yyyy-MM-dd HH:mm:ss') } else { 'null' }), $ok, $c.Text.Trim())
}
Say ('  parser control : {0}   expected True' -f $controlOk)
if (-not $controlOk) { Say '  *** the slicing is broken - refusing to report counts that cannot be trusted'; Fin $false }

Say ''
Say '===== 1  DISCOVERY - engine log files, from the SERVICE MANAGER. No product path is written by me ====='
$wmi = Get-WmiObject Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
if (-not $wmi) { Say '  *** RTMService not found in the service manager'; Fin $false }
$exe = "$($wmi.PathName)".Trim()
if ($exe.StartsWith('"')) { $exe = $exe.Substring(1, $exe.IndexOf('"', 1) - 1) }
else { $sp = $exe.IndexOf(' -'); if ($sp -gt 0) { $exe = $exe.Substring(0, $sp) } }
$engineDir = [IO.Path]::GetDirectoryName($exe)
Say ('  RTMService state {0} , PathName {1}' -f $wmi.State, $wmi.PathName)
Say ('  engine directory : {0}   exists {1}' -f $engineDir, (Test-Path -LiteralPath $engineDir))
Say ('  ProductVersion   : {0}' -f (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion)

$files = New-Object System.Collections.ArrayList
foreach ($root in @((Join-Path $engineDir 'Logs'), 'C:\Logs\RTM')) {
    if (-not (Test-Path -LiteralPath $root)) { Say ('  {0} : absent' -f $root); continue }
    $found = @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '(?i)^RTM\.log|^log\.txt$' } |
               Where-Object { $_.LastWriteTime -gt $MarkTime.AddHours(-26) })
    foreach ($f in ($found | Sort-Object LastWriteTime)) {
        Say ('  {0}   {1} bytes   mtime {2}' -f $f.FullName, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        [void]$files.Add($f.FullName)
    }
}
Say ('  files to read : {0}   expected >= 1' -f $files.Count)
if ($files.Count -lt 1) { Say '  *** no engine log discovered - refusing to report zeros'; Fin $false }

Say ''
Say '===== 2  SLICING at the mark - three buckets, and UNPARSED is printed, never dropped ====='
$after = New-Object System.Collections.ArrayList
$cBefore = 0; $cUnparsed = 0
$unparsedSamples = New-Object System.Collections.ArrayList
foreach ($file in $files) {
    $lines = @(Get-Content -LiteralPath $file -ErrorAction SilentlyContinue)
    $fAfter = 0; $fBefore = 0; $fUnp = 0
    foreach ($line in $lines) {
        $tm = Get-LineTime $line
        if ($null -eq $tm) {
            $fUnp++; $cUnparsed++
            if ($unparsedSamples.Count -lt 8) { [void]$unparsedSamples.Add($line) }
        } elseif ($tm -gt $MarkTime) {
            $fAfter++
            [void]$after.Add([pscustomobject]@{ Time = $tm; Text = $line; File = $file })
        } else { $fBefore++; $cBefore++ }
    }
    Say ('  {0}' -f $file)
    Say ('      lines {0} : AFTER {1} , BEFORE {2} , UNPARSED {3}' -f $lines.Count, $fAfter, $fBefore, $fUnp)
}
Say ('  TOTAL after the mark : {0} , before : {1} , unparsed : {2}' -f $after.Count, $cBefore, $cUnparsed)
Say ('  unparsed samples (up to 8) - these are continuation lines of stack traces unless they look otherwise:')
foreach ($us in $unparsedSamples) { Say ('      ? ' + $us.Substring(0, [Math]::Min(140, $us.Length))) }
$afterSorted = @($after | Sort-Object Time)

Say ''
Say '===== 3  THE SEVEN, each line VERBATIM with its time. Printed, NOT gated ====='
$needles = @(
    @{ Label = '1 <<getUsers unionId=';             Needle = 'getUsers unionId=' },
    @{ Label = '2 isComplete=TRUE';                  Needle = 'isComplete=TRUE' },
    @{ Label = '3 <<ChangedUnionUsersData count=';   Needle = 'ChangedUnionUsersData count=' },
    @{ Label = '4 PUSH updateUserGrid';              Needle = 'PUSH updateUserGrid' },
    @{ Label = '5 not found; returning null';        Needle = 'not found; returning null' },
    @{ Label = '6 !union.InUse';                     Needle = '!union.InUse' },
    @{ Label = '7a SERVER => A client connected.';   Needle = 'A client connected' },
    @{ Label = '7b SERVER => A client disconnected.';Needle = 'client disconnected' }
)
foreach ($n in $needles) {
    $hits = @($afterSorted | Where-Object { $_.Text.Contains($n.Needle) })
    Say ('  {0} : {1} after the mark' -f $n.Label, $hits.Count)
    foreach ($h in ($hits | Select-Object -First 40)) {
        Say ('      {0}  | {1}' -f $h.Time.ToString('HH:mm:ss.fff'), $h.Text.Trim().Substring(0, [Math]::Min(170, $h.Text.Trim().Length)))
    }
}

Say ''
Say '===== 4  controls on the after-mark window itself ====='
$posctl = @($afterSorted | Where-Object { $_.Text.Contains('AsyncLogger') }).Count
$negctl = @($afterSorted | Where-Object { $_.Text.Contains('ZZZ-cannot-occur-ZZZ') }).Count
Say ('  POSCTL AsyncLogger lines in the window : {0}' -f $posctl)
Say ('  NEGCTL impossible string               : {0}   expected 0' -f $negctl)
Say '  NOTE: a POSCTL of 0 here does NOT mean the reader is blind - the parser control above already'
Say '  proved the slicing works. It would mean the engine wrote nothing at all after the mark, which'
Say '  is itself one of the three branches the coordinator named.'
if ($afterSorted.Count -gt 0) {
    Say ('  first line in the window : {0}  | {1}' -f $afterSorted[0].Time.ToString('HH:mm:ss.fff'), $afterSorted[0].Text.Trim().Substring(0, [Math]::Min(120, $afterSorted[0].Text.Trim().Length)))
    $lastOne = $afterSorted[$afterSorted.Count - 1]
    Say ('  last  line in the window : {0}  | {1}' -f $lastOne.Time.ToString('HH:mm:ss.fff'), $lastOne.Text.Trim().Substring(0, [Math]::Min(120, $lastOne.Text.Trim().Length)))
}
$pipes = @(Get-ChildItem '\\.\pipe\' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)rtm' })
Say ('  named pipes matching rtm : {0}' -f $pipes.Count)
foreach ($p in $pipes) { Say ('      | ' + $p.Name) }
foreach ($svcName in @('RTMService','RTMTwilio_1')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) { Say ('  {0} : {1}' -f $svcName, $svc.Status) }
}

Say ''
Say '===== verdict - about the INSTRUMENT. The branch is the coordinator call ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector was clobbered'; exit 1 }
Say ('  parser control passed : {0} ; engine files read : {1} ; NEGCTL : {2}' -f $controlOk, $files.Count, $negctl)
Fin ($controlOk -and ($negctl -eq 0))
