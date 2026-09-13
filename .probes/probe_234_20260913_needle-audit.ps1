#Requires -Version 5.1
<#
  PROBE 234 / needle-audit      could any of the seven have HIDDEN in the unparsed bucket?
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate. READ ONLY.
  Starts nothing, stops nothing, restarts nothing, writes no config, touches no service, queries no
  database. C:\IceDash is never read or listed. Its only write is the report.

  WHY THIS RUN EXISTS - a hole in my own previous report, named before any number. The grid-open probe
  matched the seven needles ONLY inside the after-mark bucket, and its own slicing put 19278 lines into
  UNPARSED (stack traces and embedded source text). So "getUsers after the mark : 0" is sound only if
  no getUsers line can land in UNPARSED. I believe the engine stamps every line it writes - but belief
  is not a measurement, and the whole conclusion ("the request never reached the engine") rests on it.

  THIS PROBE IGNORES THE MARK ENTIRELY. For each needle it counts occurrences across ALL lines of the
  same three files, and for every hit it prints the line VERBATIM plus whether its own timestamp parsed.
  That answers two questions at once: can a needle appear in an unstamped line, and when did each of
  the seven last occur at all.

  EXPECTATIONS, NAMED BEFORE THE RUN:
     needles found in lines whose timestamp does NOT parse : 0
        -> if 0, "0 after the mark" in the grid-open report stands as measured
        -> if > 0, that report's seven counts are UNSAFE and I retract them
     POSCTL : at least one needle occurs SOMEWHERE in these files (getUsers did, at 00:16 and 00:52),
        so a total of 0 everywhere would mean the matcher is broken, not that the events never happened
     NEGCTL : an impossible string -> 0
  The numbers are reported, not gated on the system. The gate here is on MY instrument.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$MarkTime = [datetime]'2026-09-13 01:59:14'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_needle-audit.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (no needle can hide unstamped)' } else { 'VERDICT: FAIL (see problems)' }))
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
$fn = Get-Command Get-LineTime -ErrorAction SilentlyContinue
Say ('  Get-LineTime resolves to : {0}   expected Function' -f $fn.CommandType)
if ("$($fn.CommandType)" -ne 'Function') { Say '  *** parser shadowed - stop'; Fin $false }
Say ('  mark (for labelling only, NOT for filtering) : {0}' -f $MarkTime.ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  now : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

Say ''
Say '===== 1  the same three files, discovered the same way (service manager) ====='
$wmi = Get-WmiObject Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
if (-not $wmi) { Say '  *** RTMService not found'; Fin $false }
$exe = "$($wmi.PathName)".Trim()
if ($exe.StartsWith('"')) { $exe = $exe.Substring(1, $exe.IndexOf('"', 1) - 1) }
else { $sp = $exe.IndexOf(' -'); if ($sp -gt 0) { $exe = $exe.Substring(0, $sp) } }
$engineDir = [IO.Path]::GetDirectoryName($exe)
Say ('  engine directory : {0}' -f $engineDir)
$files = New-Object System.Collections.ArrayList
foreach ($root in @((Join-Path $engineDir 'Logs'), 'C:\Logs\RTM')) {
    if (-not (Test-Path -LiteralPath $root)) { Say ('  {0} : absent' -f $root); continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match '(?i)^RTM\.log|^log\.txt$' } |
                     Where-Object { $_.LastWriteTime -gt $MarkTime.AddHours(-26) } | Sort-Object LastWriteTime)) {
        Say ('  {0}   {1} bytes' -f $f.FullName, $f.Length)
        [void]$files.Add($f.FullName)
    }
}
Say ('  files : {0}   expected 3' -f $files.Count)
if ($files.Count -lt 1) { Say '  *** nothing discovered - refusing to report zeros'; Fin $false }

$needles = @(
    'getUsers unionId=', 'isComplete=TRUE', 'ChangedUnionUsersData count=', 'PUSH updateUserGrid',
    'not found; returning null', '!union.InUse', 'A client connected', 'client disconnected'
)
$tally = @{}
foreach ($nd in $needles) { $tally[$nd] = [pscustomobject]@{ Total = 0; Unstamped = 0; Last = $null; LastText = ''; UnstampedSamples = (New-Object System.Collections.ArrayList) } }
$negTotal = 0
$posTotal = 0

Say ''
Say '===== 2  every line of every file, NO mark filter ====='
foreach ($file in $files) {
    $lines = @(Get-Content -LiteralPath $file -ErrorAction SilentlyContinue)
    Say ('  {0} : {1} lines' -f $file, $lines.Count)
    foreach ($line in $lines) {
        if ($line.Contains('ZZZ-cannot-occur-ZZZ')) { $negTotal++ }
        foreach ($nd in $needles) {
            if (-not $line.Contains($nd)) { continue }
            $rec = $tally[$nd]
            $rec.Total++
            $posTotal++
            $tm = Get-LineTime $line
            if ($null -eq $tm) {
                $rec.Unstamped++
                if ($rec.UnstampedSamples.Count -lt 3) { [void]$rec.UnstampedSamples.Add($line) }
            } else {
                if (($null -eq $rec.Last) -or ($tm -gt $rec.Last)) { $rec.Last = $tm; $rec.LastText = $line }
            }
        }
    }
}

Say ''
Say '===== 3  per needle: total, how many were UNSTAMPED, and the latest stamped occurrence ====='
$hidden = 0
foreach ($nd in $needles) {
    $rec = $tally[$nd]
    $lastStr = $(if ($rec.Last) { $rec.Last.ToString('yyyy-MM-dd HH:mm:ss') } else { 'never (stamped)' })
    $side = 'n/a'
    if ($rec.Last) { $side = $(if ($rec.Last -gt $MarkTime) { 'AFTER the mark' } else { 'BEFORE the mark' }) }
    Say ('  {0,-32} total {1,5}   UNSTAMPED {2,4}   latest {3}   -> {4}' -f $nd, $rec.Total, $rec.Unstamped, $lastStr, $side)
    if ($rec.LastText) { Say ('      latest line | ' + $rec.LastText.Trim().Substring(0, [Math]::Min(165, $rec.LastText.Trim().Length))) }
    if ($rec.Unstamped -gt 0) {
        $hidden += $rec.Unstamped
        Say '      *** UNSTAMPED occurrences exist - these were INVISIBLE to the grid-open report:'
        foreach ($s in $rec.UnstampedSamples) { Say ('      !!! ' + $s.Trim().Substring(0, [Math]::Min(165, $s.Trim().Length))) }
    }
}

Say ''
Say '===== 4  controls ====='
Say ('  POSCTL total needle hits anywhere : {0}   expected >= 1 (0 would mean the matcher is broken)' -f $posTotal)
Say ('  NEGCTL impossible string          : {0}   expected 0' -f $negTotal)
Say ('  needle hits on UNSTAMPED lines    : {0}   expected 0 - THE GATE OF THIS RUN' -f $hidden)
if ($hidden -eq 0) {
    Say '  -> no needle can appear on a line whose time does not parse, so "0 after the mark" in the'
    Say '     grid-open report stands as measured, not as belief.'
} else {
    Say '  -> the grid-open seven counts are UNSAFE and I retract them; the slicing hid real events.'
}
if ($posTotal -lt 1) { Say '  *** POSCTL empty - the matcher is broken, nothing above is evidence' }

Say ''
Say '===== verdict - on MY instrument ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Fin (($hidden -eq 0) -and ($negTotal -eq 0) -and ($posTotal -ge 1))
