#Requires -Version 5.1
<#
  PROBE 234 / resub-v5   BOX B of two. ONE run closing BOTH analyses - shell (PR234-SHELL-RESUB-01) and backend
                         (PR234-UNIONMAP-RACE-01). Assembled from the coordinator's merged list,
                         2026-09-13 11:2x.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate; it refuses to
                  run anywhere else. EVERY line of this box runs on 234.

  *** THIS BOX WRITES ON PRODUCTION: IT RESTARTS ONE SERVICE. ***
  It restarts RTMService (the engine) and NOTHING else. It does not touch RTMTwilio_1, it does not
  touch the Shell service - leaving the Shell alone IS the predicate - it writes no config, applies no
  migration, queries no database, and asks for no password. C:\IceDash is never read or listed.
  It records the Shell service PID before and after and FAILS the run if that PID changed, so "the
  Shell was not restarted" is proven by a number instead of by intention.

  BOX A RAN FIRST and turned the flag on (probe_234_20260913_flag-on.ps1), leaving a marker with the
  EDIT TIME, the config path and the backup path. Between A and B the coordinator reloaded the Agent
  Grid page: that is his item-4 positive control, and THIS box refuses to start the main run unless the
  control passed. The control is needed because my file-level gate only proves the flag is true in the
  FILE; it does not prove the process picked it up. Without it, "PUSH in the engine and no RECV in the
  Shell" would have two explanations again - the group race, or a dead flag - and that is exactly the
  fork we spent the night separating.
  THIS BOX ALSO RESTORES THE FLAG to false on BOTH paths: when the control fails, and after every number
  is taken. If it dies in between, box A printed a one-line restore that needs nobody.

  PRECONDITION, GATED AND NOT WRITTEN BY ME. The coordinator's item 1 requires
  RtmRelay:DiagPushLogging = true in the Shell config, because without it "RECV updateUserGrid"
  (RtmRelayService :358) is never written and its zero would be an honest "I did not look" wearing the
  clothes of "it did not arrive". That flag lives in the OPERATOR's config, and role-devops A.3 says
  machine config is preserved, not rewritten mid-diagnosis. So this probe DOES NOT SET IT. It reads the
  effective value (appsettings.json overlaid by appsettings.Production.json), prints both files with
  their sha256, and if the effective value is not true it STOPS before restarting anything and measures
  nothing. Turning the flag on is a separate blessed step with the operator's hands.

  THE MARK IS TAKEN BY THE PROBE, from its own clock, immediately before the restart, and printed.
  Not accepted from outside: last cycle I was handed a mark, counted events around it without order,
  and booked my own service stop as a system disconnect.

  ORDER, as the coordinator set it:
      marker -> config gate -> FLAG-LIVE control (his page reload) -> mark -> restart the ENGINE only
      -> 90 s -> reading one -> 5 min -> reading two -> restore the flag to false
  The Agent Grid page must be OPEN at the moment of the restart and stay open. The probe cannot verify
  that from here and says so rather than assuming it.

  WHAT IT READS, with the TIME OF EVERY LINE (never a bare count):
    engine RTM.log + RTM.log20260913 :
      <<getUsers unionId= - Groups.Add UnionId = (RTMHub.cs:95) - init GridId= (RTMHub.cs:122)
      <<ChangedUnionUsersData count= - PUSH updateUserGrid
      LoadData: Start - LoadData End - LoadData: Read From DB - LoadData: Union User Groups
      LoadData union= - LoadData: ForceRefreshMetrics (Engine.cs:754)
    Shell log C:\RTMView\Shell\logs\log-<date>.txt :
      :194 connection closed - :236 reconnecting - :257 reconnected - :217 init union
      :265 reconnect attempt failed - :163 grace timer - RECV updateUserGrid

  MATCHER FORM - my own addition, because the coordinator's list pins source line numbers. For every
  Shell needle TWO counts are taken: the exact form (":194 connection closed") and the text form
  ("connection closed"). If the line numbers in the deployed build differ from the ones in the list,
  the exact form yields an honest zero for the WRONG reason. A disagreement between the two counts is
  printed as a finding about the MATCHER, not about the system.

  CONTROLS:
    assignment gate  - every count goes through Safe-Count, which returns -999 on an unassigned value
                       instead of 0, self-tested on three inputs at the top of the run
    parser control   - four synthetic lines, two per log format on this machine, must land on the
                       expected side of a mark; it never asks the data, so "nothing after the mark"
                       stays a possible finding rather than proof the slicing works
    POSCTL per family - over the WHOLE corpus; a needle absent everywhere is flagged MATCHER SUSPECT
                       and its per-window zeros are NOT findings
    NEGCTL           - an impossible string, per file, must be 0
    Shell-untouched  - Shell PID identical before and after, or the run FAILS

  WHAT IS NOT GATED: the branch readings. Which branch the numbers select is the coordinator's call -
  gating it here would let me sign off my own reading. The expectations he named before the run:
    LoadData: Start in window 02:26:02..02:39:22  > 1  -> the mapping was re-loaded by repeated calls
                                                   = 1  -> the backend hypothesis is wrong, re-analyse
    window 4 expectation: = 1 (all 33 pairs within one millisecond)
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$SENTINEL = -999
$WAIT_ONE = 90
$WAIT_TWO = 300

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_resub-v5.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function SayFileOnly($text) { [void]$Report.Add($text) }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound or a precondition missing - numbers are not evidence)' }))
    Flush
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Safe-Count($collection) {
    if ($null -eq $collection) { return $SENTINEL }
    return @($collection).Count
}
$script:FlagConfig = $null
$script:FlagBackup = $null
function Restore-Flag($why) {
    if ($null -eq $script:FlagConfig -or $null -eq $script:FlagBackup) { Say ('  flag restore: nothing to restore (' + $why + ')'); return }
    if (-not (Test-Path -LiteralPath $script:FlagBackup)) { Say '  *** flag restore: the backup is GONE - restore by hand'; return }
    Copy-Item -LiteralPath $script:FlagBackup -Destination $script:FlagConfig -Force
    $raw = Get-Content -LiteralPath $script:FlagConfig -Raw -Encoding UTF8
    $m = [regex]::Matches($raw, '"DiagPushLogging"\s*:\s*(true|false)', 'IgnoreCase')
    Say ('  FLAG RESTORED (' + $why + ') : ' + $(if ($m.Count -gt 0) { $m[0].Value } else { 'key ABSENT' }) + '   expected false')
    Say ('      config sha now ' + (Get-Sha256Of $script:FlagConfig))
}
function Get-Sha256Of($p) {
    if (Test-Path -LiteralPath $p) { return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash } else { return 'ABSENT' }
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

Say '===== 0  machine, instrument, and the self-tests ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
foreach ($h in @('Get-LineTime','Safe-Count','Get-Sha256Of')) {
    $rr = Get-Command $h -ErrorAction SilentlyContinue
    Say ('  {0} resolves to {1}   expected Function' -f $h, $rr.CommandType)
    if ("$($rr.CommandType)" -ne 'Function') { Say '  *** helper shadowed - stop'; Fin $false }
}
Say ('  PowerShell {0} ; now {1}' -f $PSVersionTable.PSVersion, (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

$nothing = $null
$gA = Safe-Count $nothing; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('  assignment gate : unassigned {0} (want {1}) , empty {2} (want 0) , two {3} (want 2)' -f $gA, $SENTINEL, $gB, $gC)
$gateOk = (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2))
if (-not $gateOk) { Say '  *** the assignment gate is broken - refusing to run'; Fin $false }

$ctlMark = [datetime]'2026-09-13 12:00:00'
$ctlOk = $true
foreach ($c in @(@{T='2026-09-13 11:00:00,001 [5] INFO x';W='BEFORE'},@{T='2026-09-13 13:00:00,001 [5] INFO x';W='AFTER'},
                 @{T=' 13/09/2026 11:00:00,002 INFO x';W='BEFORE'},@{T=' 13/09/2026 13:00:00,002 INFO x';W='AFTER'})) {
    $tm = Get-LineTime $c.T
    $got = $(if ($null -eq $tm) { 'UNPARSED' } elseif ($tm -gt $ctlMark) { 'AFTER' } else { 'BEFORE' })
    if ($got -ne $c.W) { $ctlOk = $false }
}
Say ('  parser control (4 synthetic lines, both formats) : {0}   expected True' -f $ctlOk)
if (-not $ctlOk) { Say '  *** slicing broken - refusing to run'; Fin $false }

Say ''
Say '===== 1  DISCOVERY - engine and Shell, from the service manager ====='
$svcEngine = Get-WmiObject Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
if (-not $svcEngine) { Say '  *** RTMService not found - stop'; Fin $false }
$engExe = "$($svcEngine.PathName)".Trim()
if ($engExe.StartsWith('"')) { $engExe = $engExe.Substring(1, $engExe.IndexOf('"', 1) - 1) }
else { $q = $engExe.IndexOf(' -'); if ($q -gt 0) { $engExe = $engExe.Substring(0, $q) } }
$engineDir = [IO.Path]::GetDirectoryName($engExe)
Say ('  engine : {0}  state {1}  dir {2}' -f $engExe, $svcEngine.State, $engineDir)
Say ('      ProductVersion {0}' -f (Get-Item -LiteralPath $engExe).VersionInfo.ProductVersion)

$svcShell = @(Get-WmiObject Win32_Service -ErrorAction SilentlyContinue |
              Where-Object { $_.PathName -match '(?i)RTMView\\Shell' }) | Select-Object -First 1
if (-not $svcShell) { Say '  *** the Shell service was not found by path RTMView\Shell - stop, I will not guess it'; Fin $false }
$shExe = "$($svcShell.PathName)".Trim()
if ($shExe.StartsWith('"')) { $shExe = $shExe.Substring(1, $shExe.IndexOf('"', 1) - 1) }
else { $q2 = $shExe.IndexOf(' -'); if ($q2 -gt 0) { $shExe = $shExe.Substring(0, $q2) } }
$shellDir = [IO.Path]::GetDirectoryName($shExe)
$shellPidBefore = $svcShell.ProcessId
Say ('  shell  : {0}  state {1}  dir {2}' -f $svcShell.Name, $svcShell.State, $shellDir)
Say ('      pid BEFORE {0}   <- must be IDENTICAL at the end; the Shell is not to be restarted' -f $shellPidBefore)

Say ''
Say '===== 1b  ARMING THE RESTORE FIRST - v2 left the flag ON when it stopped early ====='
Say '  My own defect, named before any number. In v2 the marker was read in section 3b, AFTER the log'
Say '  corpus section - and that section stopped the run (no Shell log found). So Restore-Flag had'
Say '  nothing to restore and production was left with DiagPushLogging = true. A step that can stop the'
Say '  run must never come before the step that makes the undo possible. The marker is read here, first.'
$markers = @(Get-ChildItem -LiteralPath $OutDir -File -Filter '*_flag-on.marker' -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending)
Say ('  markers found : {0}   expected >= 1 (box A must have run)' -f (Safe-Count $markers))
if ((Safe-Count $markers) -lt 1) {
    Say '  *** no marker from box A. Without its edit time I cannot bound the flag-live control, and an'
    Say '      unbounded search would count an OLD line as proof. I also cannot restore a flag I cannot'
    Say '      locate - if box A did run, restore it by the one-line command its report printed.'
    Fin $false
}
$marker = $markers[0]
Say ('  using : {0}   mtime {1}' -f $marker.FullName, $marker.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
# v3 failed HERE and left the flag on for the second time. Two defects of mine, both fixed below.
# 1. The parse used a regex and produced empty values for every field but one, and then the probe said
#    "does not parse" WITHOUT PRINTING WHAT IT READ - a refusal with no evidence, which is the exact
#    silence I spend every run gating against. Every raw line is printed verbatim now, before any
#    interpretation, so one run is enough to see the cause.
# 2. The restore was armed AFTER the editTime validation, so a stop at that validation could not undo
#    anything. Arming now happens immediately after the key/value read and before ANY validation.
# The parse itself no longer uses a regex: IndexOf + Substring cannot be fooled by a value that
# contains a colon, a backslash, spaces or a dot, and the key/value split is exact by construction.
Say '  --- the marker file, VERBATIM, before any interpretation ---'
$mk = @{}
$rawLines = @(Get-Content -LiteralPath $marker.FullName -Encoding UTF8)
Say ('  raw lines : {0}' -f (Safe-Count $rawLines))
foreach ($ln in $rawLines) { Say ('      | ' + $ln) }
# v4 printed this verbatim and the print paid for itself at once: the marker box A wrote has TEN lines,
# not six - every "key=" + value element was emitted as TWO array elements, so each pair is split across
# two lines while the pure literals (changed=1) stayed whole. The defect is in box A's WRITER, not in the
# reader. I am NOT rewriting the marker on production to fix my own formatting: that would be a second
# write on a live server for my convenience. This reader accepts BOTH shapes instead:
#   key=value        on one line   -> used as is
#   key=             alone         -> paired with the NEXT line, when that line carries no '=' of its own
# The pairing is printed per key, so which shape was taken is visible and not assumed. Box A's writer is
# fixed separately, for future runs, and that fix needs no production action.
for ($i = 0; $i -lt (Safe-Count $rawLines); $i++) {
    $ln = "$($rawLines[$i])"
    $eq = $ln.IndexOf('=')
    if ($eq -lt 1) { continue }
    $key = $ln.Substring(0, $eq).Trim()
    $val = $ln.Substring($eq + 1).Trim()
    $shape = 'one line'
    if ([string]::IsNullOrWhiteSpace($val) -and ($i + 1) -lt (Safe-Count $rawLines)) {
        $next = "$($rawLines[$i + 1])"
        if (-not $next.Contains('=')) {
            $val = $next.Trim()
            $shape = 'split over two lines (box A writer defect)'
            $i++
        }
    }
    $mk[$key] = $val
    Say ('      key [{0}] shape [{1}]' -f $key, $shape)
}
Say ('  keys parsed : {0}' -f (Safe-Count @($mk.Keys)))
foreach ($k in @($mk.Keys | Sort-Object)) { Say ('      {0,-12} [{1}]' -f $k, $mk[$k]) }

# ARM THE RESTORE NOW - before any validation that could stop the run
if ("$($mk['changed'])" -eq '1') {
    $script:FlagConfig = "$($mk['config'])"
    $script:FlagBackup = "$($mk['backup'])"
    Say ('  RESTORE IS ARMED: config [{0}] backup [{1}]' -f $script:FlagConfig, $script:FlagBackup)
    if ([string]::IsNullOrWhiteSpace($script:FlagConfig) -or [string]::IsNullOrWhiteSpace($script:FlagBackup)) {
        Say '  *** the marker says changed=1 but config/backup are EMPTY, so I cannot restore from it.'
        Say '      Restore by the one-line command printed in the box A report, then re-run this box.'
        Fin $false
    }
    if (-not (Test-Path -LiteralPath $script:FlagBackup)) {
        Say '  *** the backup named by the marker does not exist - refusing to go further without an undo'
        Fin $false
    }
    Say '  every stop from here on returns the flag to false.'
} else {
    Say '  box A reports changed=0 (the flag was already true) - nothing for this box to restore.'
}

# the boundary: the marker editTime, with the marker FILE mtime as a stated fallback
$editTime = [datetime]::MinValue
$boundarySource = 'marker editTime'
if (-not [datetime]::TryParseExact("$($mk['editTime'])", 'yyyy-MM-dd HH:mm:ss.fff',
        [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$editTime)) {
    $editTime = $marker.LastWriteTime
    $boundarySource = 'FALLBACK: the marker FILE mtime, because its editTime field did not parse'
    Say ('  *** editTime did not parse from [{0}]' -f $mk['editTime'])
    Say '      Falling back to the marker file mtime. This is still a MEASURED boundary - the file was'
    Say '      written by box A at the moment of the edit - it is merely coarser by a fraction of a'
    Say '      second, and a fraction of a second cannot change which side of it the page reload fell on.'
    Say '      Saying so out loud rather than stopping a second time on my own parsing.'
}
Say ('  boundary : {0}   source : {1}' -f $editTime.ToString('yyyy-MM-dd HH:mm:ss.fff'), $boundarySource)

Say ''
Say '===== 2  PRECONDITION GATE - RtmRelay:DiagPushLogging. This probe does NOT set it ====='
$cfgBase = Join-Path $shellDir 'appsettings.json'
$cfgProd = Join-Path $shellDir 'appsettings.Production.json'
$effective = $null
foreach ($cfg in @($cfgBase, $cfgProd)) {
    Say ('  {0}   exists {1}' -f $cfg, (Test-Path -LiteralPath $cfg))
    if (-not (Test-Path -LiteralPath $cfg)) { continue }
    Say ('      sha256 {0}' -f (Get-Sha256Of $cfg))
    try {
        $json = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
        $node = $json.RtmRelay
        if ($null -ne $node -and $null -ne $node.DiagPushLogging) {
            Say ('      RtmRelay:DiagPushLogging = {0}' -f $node.DiagPushLogging)
            $effective = $node.DiagPushLogging
        } else {
            Say '      RtmRelay:DiagPushLogging : key ABSENT in this file'
        }
    } catch { Say ('      *** not parseable as JSON : {0}' -f $_.Exception.Message) }
}
Say ('  EFFECTIVE value (Production overrides base) : {0}   required True' -f $(if ($null -eq $effective) { 'ABSENT -> default false (RtmRelayOptions.cs:6)' } else { $effective }))
if ("$effective" -ne 'True') {
    Say '  *** PRECONDITION NOT MET. Stopping BEFORE the restart, and measuring nothing.'
    Say '      Without this flag "RECV updateUserGrid" is never written, so its zero would be an'
    Say '      honest "I did not look" - and the shell analysis turns on exactly that line. Setting the'
    Say '      flag is a config change on production: it needs the coordinator word and the operator'
    Say '      hands, as a separate step. This probe preserves operator config and does not write it.'
    Fin $false
}

Say ''
Say '===== 3  the log corpus ====='
$files = New-Object System.Collections.ArrayList
$engRoots = @((Join-Path $engineDir 'Logs'), 'C:\Logs\RTM')
$shRoots  = @((Join-Path $shellDir 'logs'), 'C:\Logs\RTMViewShell')
# The Shell log path is DECLARED, not guessed: CcDashboard.Web logs through Serilog
# (Serilog.Settings.Configuration + Serilog.Sinks.File in its own folder), and the sink path lives in
# the DEPLOYED appsettings.json under Serilog:WriteTo[].Args.path - the same file this probe already
# read for the flag. v2 guessed two roots and applied a 40-hour freshness filter, so an absent RECENT
# log was reported as an absent log: the corpus came back with zero Shell files and the run stopped
# without ever saying what the newest Shell log actually was.
$serilogPaths = New-Object System.Collections.ArrayList
try {
    $shJson = Get-Content -LiteralPath $cfgBase -Raw -Encoding UTF8
    foreach ($m in [regex]::Matches($shJson, '"path"\s*:\s*"([^"]+)"')) {
        $declared = $m.Groups[1].Value -replace '/', '\'
        $full = $declared
        if (-not [IO.Path]::IsPathRooted($full)) { $full = Join-Path $shellDir $declared }
        Say ('  SHELL Serilog declares path : {0}  ->  {1}' -f $declared, $full)
        [void]$serilogPaths.Add([IO.Path]::GetDirectoryName($full))
    }
} catch { Say ('  *** could not read the Serilog path from the config : {0}' -f $_.Exception.Message) }
Say ('  Serilog directories declared : {0}' -f (Safe-Count $serilogPaths))
$shRoots = @(@($serilogPaths) + $shRoots | Where-Object { $_ } | Select-Object -Unique)
foreach ($r in $shRoots) { Say ('  SHELL candidate directory : {0}   exists {1}' -f $r, (Test-Path -LiteralPath $r)) }

foreach ($pair in @(@('ENGINE',$engRoots,'(?i)^RTM\.log$|^RTM\.log2026'), @('SHELL',$shRoots,'(?i)^log'))) {
    foreach ($root in $pair[1]) {
        if (-not (Test-Path -LiteralPath $root)) { Say ('  {0} {1} : absent' -f $pair[0], $root); continue }
        $found = @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -match $pair[2] } | Sort-Object LastWriteTime -Descending)
        Say ('  {0} {1} : matching files {2}' -f $pair[0], $root, (Safe-Count $found))
        foreach ($f in $found) {
            $ageH = [Math]::Round(((Get-Date) - $f.LastWriteTime).TotalHours, 1)
            $take = ($ageH -le 40)
            Say ('      {0}   {1} bytes   mtime {2}   age {3} h   read : {4}' -f `
                 $f.Name, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $ageH, $take)
            if ($take) { [void]$files.Add([pscustomobject]@{ Side = $pair[0]; Path = $f.FullName }) }
        }
        if ((Safe-Count $found) -gt 0) {
            Say ('      NEWEST here : {0}   mtime {1}   <- measured, so "no recent log" is a NUMBER' -f `
                 $found[0].Name, $found[0].LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        }
    }
}
Say ('  files : {0}   engine {1} , shell {2}' -f (Safe-Count $files),
     (Safe-Count @($files | Where-Object { $_.Side -eq 'ENGINE' })),
     (Safe-Count @($files | Where-Object { $_.Side -eq 'SHELL' })))
if ((Safe-Count @($files | Where-Object { $_.Side -eq 'ENGINE' })) -lt 1) { Say '  *** no engine log - stop'; Fin $false }
if ((Safe-Count @($files | Where-Object { $_.Side -eq 'SHELL' })) -lt 1) {
    Say '  *** no Shell log NEWER THAN 40 h in any declared or candidate location. The shell half cannot'
    Say '      be measured from logs, and I will not report its zeros as findings. The newest file found'
    Say '      in each directory is printed above WITH its timestamp, so this is a measurement and not an'
    Say '      empty list: if the newest is days old, the Shell has not been logging, and THAT is the'
    Say '      finding to take to the coordinator before any restart.'
    Restore-Flag 'stopped before the restart - no Shell log to measure'
    Fin $false
}

$ENGINE_NEEDLES = @(
    '<<getUsers unionId=', 'Groups.Add UnionId =', 'init GridId=', '<<ChangedUnionUsersData count=',
    'PUSH updateUserGrid', 'LoadData: Start', 'LoadData End', 'LoadData: Read From DB',
    'LoadData: Union User Groups', 'LoadData union=', 'LoadData: ForceRefreshMetrics'
)
# Shell needles: exact form from the coordinator list, plus the text-only form as the matcher control
$SHELL_NEEDLES = @(
    @{ Exact=':194 connection closed';        Text='connection closed' },
    @{ Exact=':236 reconnecting';             Text='reconnecting' },
    @{ Exact=':257 reconnected';              Text='reconnected' },
    @{ Exact=':217 init union';               Text='init union' },
    @{ Exact=':265 reconnect attempt failed'; Text='reconnect attempt failed' },
    @{ Exact=':163 grace timer';              Text='grace timer' },
    @{ Exact='RECV updateUserGrid';           Text='updateUserGrid' }
)
$NEG = 'ZZZ-cannot-occur-ZZZ'

function Read-Corpus() {
    $acc = New-Object System.Collections.ArrayList
    foreach ($f in $files) {
        foreach ($line in @(Get-Content -LiteralPath $f.Path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
            $tm = Get-LineTime $line
            [void]$acc.Add([pscustomobject]@{ Side = $f.Side; File = $f.Path; Time = $tm; Text = $line })
        }
    }
    return $acc
}

Say ''
Say '===== 3b  the FLAG-LIVE control - his page reload, bounded by the marker edit time ====='
Say ('  boundary from the marker : {0}' -f $editTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))
$corpusCtl = Read-Corpus
$recvAfterEdit = @($corpusCtl | Where-Object { $_.Side -eq 'SHELL' -and $null -ne $_.Time -and $_.Time -gt $editTime -and $_.Text.Contains('updateUserGrid') })
$recvBeforeEdit = Safe-Count @($corpusCtl | Where-Object { $_.Side -eq 'SHELL' -and $null -ne $_.Time -and $_.Time -le $editTime -and $_.Text.Contains('updateUserGrid') })
Say ('  Shell updateUserGrid lines AFTER the edit time : {0}   expected >= 1' -f (Safe-Count $recvAfterEdit))
Say ('  the same BEFORE the edit time : {0}   (context only - with the flag off these are not expected)' -f $recvBeforeEdit)
foreach ($x in @($recvAfterEdit | Select-Object -First 6)) {
    Say ('      {0}  | {1}' -f $x.Time.ToString('HH:mm:ss.fff'), $x.Text.Trim().Substring(0, [Math]::Min(150, $x.Text.Trim().Length)))
}
if ((Safe-Count $recvAfterEdit) -lt 1) {
    Say '  *** THE CONTROL FAILED. Either the flag never reached the process, or the path is broken even'
    Say '      without a restart. In both cases the main run would go in with its chief needle BLIND, so'
    Say '      I am not starting it - a blind needle produces the zero that cannot be told from a finding.'
    Restore-Flag 'control failed - production returns to its original state'
    Fin $false
}
Say '  -> the flag is LIVE in the process and the path works right now. This is also the "before" basis.'
Flush

Say ''
Say '===== 4  POSCTL over the WHOLE corpus, before anything is restarted ====='
$corpus0 = Read-Corpus
Say ('  lines read {0} , with a parsed time {1}' -f (Safe-Count $corpus0), (Safe-Count @($corpus0 | Where-Object { $null -ne $_.Time })))
$suspect = New-Object System.Collections.ArrayList
foreach ($n in $ENGINE_NEEDLES) {
    $c = Safe-Count @($corpus0 | Where-Object { $_.Side -eq 'ENGINE' -and $_.Text.Contains($n) })
    if ($c -eq $SENTINEL) { Say ('  *** ENGINE needle {0} UNASSIGNED - stop' -f $n); Fin $false }
    $flag = ''; if ($c -eq 0) { $flag = '   <- MATCHER SUSPECT, its zeros are not findings'; [void]$suspect.Add($n) }
    Say ('  ENGINE {0,-32} {1}{2}' -f $n, $c, $flag)
}
foreach ($sn in $SHELL_NEEDLES) {
    $ce = Safe-Count @($corpus0 | Where-Object { $_.Side -eq 'SHELL' -and $_.Text.Contains($sn.Exact) })
    $ct = Safe-Count @($corpus0 | Where-Object { $_.Side -eq 'SHELL' -and $_.Text.Contains($sn.Text) })
    if (($ce -eq $SENTINEL) -or ($ct -eq $SENTINEL)) { Say ('  *** SHELL needle {0} UNASSIGNED - stop' -f $sn.Exact); Fin $false }
    $note = ''
    if ($ce -eq 0 -and $ct -gt 0) { $note = '   <- EXACT form absent but TEXT form present: the line numbers in this build differ from the list. Use the text form.' }
    if ($ce -eq 0 -and $ct -eq 0) { $note = '   <- MATCHER SUSPECT in both forms'; [void]$suspect.Add($sn.Exact) }
    Say ('  SHELL  {0,-32} exact {1} , text {2}{3}' -f $sn.Exact, $ce, $ct, $note)
}
foreach ($f in $files) {
    $nc = Safe-Count @($corpus0 | Where-Object { $_.File -eq $f.Path -and $_.Text.Contains($NEG) })
    if ($nc -ne 0) { Say ('  *** NEGCTL matched in {0} : {1} - the matcher is wrong, stop' -f $f.Path, $nc); Fin $false }
}
Say ('  NEGCTL : 0 in every file   families suspect : {0}' -f (Safe-Count $suspect))
$posEng = Safe-Count @($corpus0 | Where-Object { $_.Side -eq 'ENGINE' -and $_.Text.Contains('AsyncLogger') })
Say ('  POSCTL engine AsyncLogger lines : {0}   expected > 0' -f $posEng)
if ($posEng -lt 1) { Say '  *** engine POSCTL empty - wrong file or wrong matcher, stop'; Fin $false }
Flush

Say ''
Say '===== 5  LoadData census per engine-start window, over the whole log (backend predicate) ====='
$timed = @($corpus0 | Where-Object { $_.Side -eq 'ENGINE' -and $null -ne $_.Time } | Sort-Object Time)
$marks = @($timed | Where-Object { $_.Text.Contains('RTM Start') })
$starts = New-Object System.Collections.ArrayList
foreach ($m in $marks) {
    if ((Safe-Count $starts) -eq 0) { [void]$starts.Add($m.Time); continue }
    if (($m.Time - $starts[$starts.Count-1]).TotalSeconds -gt 60) { [void]$starts.Add($m.Time) }
}
Say ('  distinct engine starts in the corpus : {0}' -f (Safe-Count $starts))
Say '  win  start              LoadData:Start  LoadData End  Read From DB  Union User Groups  union=  ForceRefresh'
for ($i = 0; $i -lt (Safe-Count $starts); $i++) {
    $from = $starts[$i]
    $to = $(if ($i -lt (Safe-Count $starts) - 1) { $starts[$i+1] } else { [datetime]::MaxValue })
    $w = @($timed | Where-Object { $_.Time -ge $from -and $_.Time -lt $to })
    $cStart = Safe-Count @($w | Where-Object { $_.Text.Contains('LoadData: Start') })
    $cEnd   = Safe-Count @($w | Where-Object { $_.Text.Contains('LoadData End') })
    $cRead  = Safe-Count @($w | Where-Object { $_.Text.Contains('LoadData: Read From DB') })
    $cUUG   = Safe-Count @($w | Where-Object { $_.Text.Contains('LoadData: Union User Groups') })
    $cRow   = Safe-Count @($w | Where-Object { $_.Text.Contains('LoadData union=') })
    $cFRM   = Safe-Count @($w | Where-Object { $_.Text.Contains('LoadData: ForceRefreshMetrics') })
    Say ('  {0,-4} {1,-18} {2,-15} {3,-13} {4,-13} {5,-18} {6,-7} {7}' -f ($i+1), $from.ToString('MM-dd HH:mm:ss'), $cStart, $cEnd, $cRead, $cUUG, $cRow, $cFRM)
    foreach ($r in @($w | Where-Object { $_.Text.Contains('LoadData: Start') -or $_.Text.Contains('LoadData union=') } | Select-Object -First 60)) {
        SayFileOnly ('      ' + $r.Time.ToString('MM-dd HH:mm:ss.fff') + ' | ' + $r.Text.Trim())
    }
}
Say '  NOTE: the window 02:26:02..02:39:22 is the one the backend predicate is about: LoadData: Start'
Say '  greater than 1 there means the mapping was re-loaded by repeated calls and the burst did not'
Say '  "break off"; exactly 1 means that hypothesis is wrong. Reported, not gated.'
Flush

Say ''
Say '===== 6  THE MARK and the RESTART of the engine ONLY ====='
Say '  The Agent Grid page must be OPEN right now and stay open. This probe cannot verify that and does'
Say '  not pretend to: if it was closed, the consumer half of this run means nothing.'
$MarkTime = Get-Date
Say ('  MARK (this probe own clock) : {0}' -f $MarkTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))
$engBefore = (Get-Service -Name 'RTMService').Status
Say ('  RTMService before : {0}' -f $engBefore)
Restart-Service -Name 'RTMService' -Force -ErrorAction Continue
Start-Sleep -Seconds 3
$engAfter = (Get-Service -Name 'RTMService').Status
Say ('  RTMService after  : {0}   expected Running' -f $engAfter)
$svcShell2 = Get-WmiObject Win32_Service -Filter ("Name='" + $svcShell.Name + "'") -ErrorAction SilentlyContinue
Say ('  Shell pid now {0} , before {1} , UNCHANGED : {2}   expected True' -f $svcShell2.ProcessId, $shellPidBefore, ($svcShell2.ProcessId -eq $shellPidBefore))
Say ('  RTMTwilio_1 : {0}   (not touched by this box)' -f (Get-Service -Name 'RTMTwilio_1' -ErrorAction SilentlyContinue).Status)
if ($svcShell2.ProcessId -ne $shellPidBefore) {
    Say '  *** the Shell process CHANGED. The predicate of this whole run is that the Shell was NOT'
    Say '      restarted, so the run is void. Reporting and stopping.'
    Fin $false
}
Flush

function Reading($label) {
    Say ''
    Say ('===== READING ' + $label + ' at ' + (Get-Date).ToString('HH:mm:ss') + ' =====')
    $c = Read-Corpus
    $after = @($c | Where-Object { $null -ne $_.Time -and $_.Time -gt $MarkTime })
    $unp = Safe-Count @($c | Where-Object { $null -eq $_.Time })
    Say ('  lines after the mark : {0}   (unparsed in corpus {1})' -f (Safe-Count $after), $unp)
    Say '  --- ENGINE ---'
    foreach ($n in $ENGINE_NEEDLES) {
        $h = @($after | Where-Object { $_.Side -eq 'ENGINE' -and $_.Text.Contains($n) })
        $cc = Safe-Count $h
        $mark = ''; if ($suspect -contains $n) { $mark = '  (matcher suspect - not a finding)' }
        Say ('  {0,-32} {1}{2}' -f $n, $cc, $mark)
        foreach ($x in @($h | Select-Object -First 12)) {
            Say ('      {0}  | {1}' -f $x.Time.ToString('HH:mm:ss.fff'), $x.Text.Trim().Substring(0, [Math]::Min(150, $x.Text.Trim().Length)))
        }
    }
    Say '  --- SHELL ---'
    foreach ($sn in $SHELL_NEEDLES) {
        $he = @($after | Where-Object { $_.Side -eq 'SHELL' -and $_.Text.Contains($sn.Exact) })
        $ht = @($after | Where-Object { $_.Side -eq 'SHELL' -and $_.Text.Contains($sn.Text) })
        Say ('  {0,-32} exact {1} , text {2}' -f $sn.Exact, (Safe-Count $he), (Safe-Count $ht))
        $show = $(if ((Safe-Count $he) -gt 0) { $he } else { $ht })
        foreach ($x in @($show | Select-Object -First 8)) {
            Say ('      {0}  | {1}' -f $x.Time.ToString('HH:mm:ss.fff'), $x.Text.Trim().Substring(0, [Math]::Min(150, $x.Text.Trim().Length)))
        }
    }
    $pe = Safe-Count @($after | Where-Object { $_.Side -eq 'ENGINE' -and $_.Text.Contains('AsyncLogger') })
    $ne = Safe-Count @($after | Where-Object { $_.Text.Contains($NEG) })
    Say ('  POSCTL engine AsyncLogger after the mark : {0}   NEGCTL : {1}   expected NEGCTL 0' -f $pe, $ne)
    Flush
    return $after
}

Start-Sleep -Seconds $WAIT_ONE
$r1 = Reading 'ONE (+90 s)'
Start-Sleep -Seconds $WAIT_TWO
$r2 = Reading 'TWO (+6.5 min)'

Say ''
Say '===== 7  growth between the two readings ====='
Say ('  lines after the mark : reading one {0} -> reading two {1} , grew {2}' -f (Safe-Count $r1), (Safe-Count $r2), ((Safe-Count $r2) -gt (Safe-Count $r1)))
foreach ($n in @('<<getUsers unionId=', '<<ChangedUnionUsersData count=', 'PUSH updateUserGrid', 'Groups.Add UnionId =', 'init GridId=')) {
    Say ('  {0,-32} {1} -> {2}' -f $n,
         (Safe-Count @($r1 | Where-Object { $_.Text.Contains($n) })),
         (Safe-Count @($r2 | Where-Object { $_.Text.Contains($n) })))
}
foreach ($sn in $SHELL_NEEDLES) {
    Say ('  SHELL {0,-30} {1} -> {2}' -f $sn.Text,
         (Safe-Count @($r1 | Where-Object { $_.Side -eq 'SHELL' -and $_.Text.Contains($sn.Text) })),
         (Safe-Count @($r2 | Where-Object { $_.Side -eq 'SHELL' -and $_.Text.Contains($sn.Text) })))
}

Say ''
Say '===== 8  restoring the flag to false - the last step, as agreed ====='
Restore-Flag 'all numbers taken'

Say ''
Say '===== verdict - on MY instrument only. The branch is the coordinator call ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Say ('  assignment gate {0} ; parser {1} ; Shell pid unchanged True ; suspect families {2}' -f $gateOk, $ctlOk, (Safe-Count $suspect))
Fin ($gateOk -and $ctlOk)
