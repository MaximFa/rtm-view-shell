#Requires -Version 5.1
<#
  PROBE 234 / early-ask      which branch swallowed the 12:35:05 question: was the union missing, or
                             present but empty? READ ONLY.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate; it refuses to run
                  anywhere else. EVERY line of this box runs on 234.
  It restarts NOTHING, stops nothing, writes no config, applies no migration, queries no database, and
  prompts for no password. It reads the engine log that is already on disk plus ONE named key from the
  engine config. C:\IceDash is never read or listed. Only write: its own report.

  WHY THIS RUN EXISTS. The previous run refuted my hypothesis: the Shell DOES re-subscribe after a lone
  engine restart - `<<getUsers unionId=21` at 12:35:05.082 with the Shell PID unchanged. But the engine
  logged no `<<ChangedUnionUsersData count=` for that question, which it normally does, so getUsers
  returned before reaching that line. Two code facts from the coordinator, BOTH re-measured by me in the
  object store rather than taken on trust:
    v3:RTM/RTM/Engine.cs:2115-2122  AddGridConnection sets union.InUse = true ITSELF and logs
        "Union <N> In use"; if the union is absent from UnionList it logs a WARN
        "AddGridConnection: union <N> not found; connection ... not registered" and RETURNS.
        So `!union.InUse` cannot have fired on this question - the same call is what sets InUse.
        The remaining branch is "the union did not exist yet", and we never had a needle for that line.
    v3:RTM/RTM/RTMAdapter.cs:528 + RTM/RTM.Configuration/AppConfig.cs:41,59
        "PUSH updateUserGrid" is written only when AppConfig.DiagPushLogging is true, and that flag reads
        RTM:DiagPushLogging from the ENGINE config - a DIFFERENT key in a DIFFERENT file from the Shell's
        RtmRelay:DiagPushLogging we spent the cycle switching. Two flags, one name, two configs.
        The SendAsync itself sits OUTSIDE the flag, so zero PUSH lines never meant "nothing is pushed".
        A third site under the same engine flag: RTMAdapter.cs:504. Engine appsettings.json:18 ships it
        false. I therefore read that one key here and print it, so the meaning of a PUSH count of zero is
        settled by the config rather than by assumption.
  And one more thing the code settles, which sharpens the subject (v3:RTM/RTM/RTMHub.cs:87-101): the hub
  logs "Groups.Add UnionId =", then calls Engine.AddGridConnection, then getUsers, then sends the result
  to the group UNCONDITIONALLY. So the Shell was ANSWERED at 12:35:05 - with whatever getUsers returned,
  possibly null - and nothing ever corrects that answer afterwards.

  WHAT IT MEASURES, over the window of the last engine start already on disk:
    1. "AddGridConnection: union"        -> present means the union was NOT in UnionList at that moment
    2. "In use"                          -> present means the subscription WAS registered
    3. "getUsers: union" / "returning null" -> the other null branch
    4. "!union.InUse"                    -> must be EMPTY by the mechanism above; if it is not, the
                                            mechanism is not what we think and I say so
    5. every engine line in the 12:35:04..12:35:08 cluster, VERBATIM and in order, so the sequence
       Groups.Add -> AddGridConnection result -> getUsers is read rather than inferred
  CONTROLS: assignment gate with a sentinel, self-tested; parser control on synthetic lines only;
  POSCTL "In use" over the WHOLE corpus must exceed 0, otherwise that needle is matcher-suspect and its
  absence in the window proves nothing; NEGCTL an impossible string must be 0.
  Nothing about the branch is gated - which branch the numbers select is the coordinator's call.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$SENTINEL = -999
$NEG = 'ZZZ-cannot-occur-ZZZ'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_early-ask.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound - numbers are not evidence)' }))
    [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false)))
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
Say ('  now : {0}   READ ONLY - nothing is restarted, nothing is written' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('  assignment gate : unassigned {0} (want {1}) , empty {2} (want 0) , two {3} (want 2)' -f $gA, $SENTINEL, $gB, $gC)
if (-not (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2))) { Say '  *** assignment gate broken'; Fin $false }
$ctlMark = [datetime]'2026-09-13 12:00:00'
$ctlOk = $true
foreach ($c in @(@{T='2026-09-13 11:00:00,001 [5] INFO x';W='BEFORE'},@{T='2026-09-13 13:00:00,001 [5] INFO x';W='AFTER'},
                 @{T=' 13/09/2026 11:00:00,002 INFO x';W='BEFORE'},@{T=' 13/09/2026 13:00:00,002 INFO x';W='AFTER'})) {
    $tm = Get-LineTime $c.T
    $got = $(if ($null -eq $tm) { 'UNPARSED' } elseif ($tm -gt $ctlMark) { 'AFTER' } else { 'BEFORE' })
    if ($got -ne $c.W) { $ctlOk = $false }
}
Say ('  parser control : {0}   expected True' -f $ctlOk)
if (-not $ctlOk) { Say '  *** slicing broken'; Fin $false }

Say ''
Say '===== 1  the ENGINE flag that governs the PUSH line - ONE named key, nothing else read ====='
$svcEngine = Get-WmiObject Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
if (-not $svcEngine) { Say '  *** RTMService not found'; Fin $false }
$engExe = "$($svcEngine.PathName)".Trim()
if ($engExe.StartsWith('"')) { $engExe = $engExe.Substring(1, $engExe.IndexOf('"', 1) - 1) }
else { $q = $engExe.IndexOf(' -'); if ($q -gt 0) { $engExe = $engExe.Substring(0, $q) } }
$engineDir = [IO.Path]::GetDirectoryName($engExe)
Say ('  engine dir {0}   state {1}' -f $engineDir, $svcEngine.State)
$engCfg = Join-Path $engineDir 'appsettings.json'
Say ('  config {0}   exists {1}' -f $engCfg, (Test-Path -LiteralPath $engCfg))
Say '  ONE key is read and printed: RTM:DiagPushLogging. It is a boolean and not a secret. Nothing else'
Say '  in the operator config is read out - the last time I scanned a config with a blanket pattern it'
Say '  printed a password, and a predicate that cannot say in advance what it will print must not print.'
if (Test-Path -LiteralPath $engCfg) {
    try {
        $engObj = Get-Content -LiteralPath $engCfg -Raw -Encoding UTF8 | ConvertFrom-Json
        $node = $engObj.RTM
        if ($null -ne $node -and $null -ne $node.DiagPushLogging) {
            Say ('  RTM:DiagPushLogging = {0}' -f $node.DiagPushLogging)
        } else {
            Say '  RTM:DiagPushLogging : key ABSENT -> default false (AppConfig.cs:59 TryParse of a missing value)'
        }
    } catch { Say ('  *** config not parseable : {0}' -f $_.Exception.Message) }
}
Say '  MEANING, fixed before the numbers: if this is false then a PUSH count of zero says NOTHING about'
Say '  whether the engine pushes - the SendAsync at RTMAdapter.cs:534 is outside the flag. My earlier'
Say '  "nobody pushes" is withdrawn as unverified either way.'

Say ''
Say '===== 2  the engine log, and the window of the last start ====='
$files = New-Object System.Collections.ArrayList
foreach ($root in @((Join-Path $engineDir 'Logs'), 'C:\Logs\RTM')) {
    if (-not (Test-Path -LiteralPath $root)) { Say ('  {0} : absent' -f $root); continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match '(?i)^RTM\.log$|^log\.txt$' } | Sort-Object LastWriteTime -Descending)) {
        Say ('  {0}   {1} bytes   mtime {2}' -f $f.FullName, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        [void]$files.Add($f.FullName)
    }
}
Say ('  files : {0}   expected >= 1' -f (Safe-Count $files))
if ((Safe-Count $files) -lt 1) { Say '  *** no engine log'; Fin $false }
$all = New-Object System.Collections.ArrayList
foreach ($p in $files) {
    foreach ($line in @(Get-Content -LiteralPath $p -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        [void]$all.Add([pscustomobject]@{ Time = (Get-LineTime $line); Text = $line })
    }
}
$timed = @($all | Where-Object { $null -ne $_.Time } | Sort-Object Time)
Say ('  lines {0} , timed {1}' -f (Safe-Count $all), (Safe-Count $timed))
$starts = @($timed | Where-Object { $_.Text.Contains('RTM Start') })
if ((Safe-Count $starts) -lt 1) { Say '  *** no "RTM Start" marker - cannot bound a window'; Fin $false }
$lastStart = $starts[$starts.Count-1].Time
Say ('  last engine start in the log : {0}   <- window begins here' -f $lastStart.ToString('yyyy-MM-dd HH:mm:ss.fff'))
$win = @($timed | Where-Object { $_.Time -ge $lastStart })
Say ('  lines in the window : {0}' -f (Safe-Count $win))

Say ''
Say '===== 3  the four branch needles, over the window ====='
$NEEDLES = @(
    @{ Key='AddGridConnection: union'; Note='WARN - the union was NOT in UnionList at that moment' },
    @{ Key='In use';                   Note='INFO Engine.cs:2122 - the subscription WAS registered' },
    @{ Key='getUsers: union';          Note='the other null branch' },
    @{ Key='returning null';           Note='same branch, text form' },
    @{ Key='!union.InUse';             Note='MUST be empty by mechanism; if not, the mechanism is not this' },
    @{ Key='<<getUsers unionId=';      Note='the question itself' },
    @{ Key='<<ChangedUnionUsersData count='; Note='the answer; absent at 12:35:05, which is the puzzle' },
    @{ Key='Groups.Add UnionId =';     Note='hub logged the group add BEFORE calling the engine' },
    @{ Key='PUSH updateUserGrid';      Note='meaningless unless the engine flag above is true' }
)
$suspect = New-Object System.Collections.ArrayList
foreach ($n in $NEEDLES) {
    $inWin = Safe-Count @($win | Where-Object { $_.Text.Contains($n.Key) })
    $inAll = Safe-Count @($timed | Where-Object { $_.Text.Contains($n.Key) })
    if ($inWin -eq $SENTINEL -or $inAll -eq $SENTINEL) { Say ('  *** needle {0} UNASSIGNED - stop' -f $n.Key); Fin $false }
    $flag = ''
    if ($inAll -eq 0) { $flag = '   <- MATCHER SUSPECT: absent in the whole corpus, its zeros are NOT findings'; [void]$suspect.Add($n.Key) }
    Say ('  {0,-34} window {1,-5} corpus {2,-6}{3}' -f $n.Key, $inWin, $inAll, $flag)
    Say ('      ({0})' -f $n.Note)
    foreach ($x in @($win | Where-Object { $_.Text.Contains($n.Key) } | Select-Object -First 8)) {
        Say ('      {0}  | {1}' -f $x.Time.ToString('HH:mm:ss.fff'), $x.Text.Trim().Substring(0, [Math]::Min(160, $x.Text.Trim().Length)))
    }
}

Say ''
Say '===== 4  POSCTL / NEGCTL ====='
$pos = Safe-Count @($timed | Where-Object { $_.Text.Contains('In use') })
$neg = Safe-Count @($all | Where-Object { $_.Text.Contains($NEG) })
Say ('  POSCTL "In use" over the whole corpus : {0}   expected > 0, else its window zero proves nothing' -f $pos)
Say ('  NEGCTL impossible string              : {0}   expected 0' -f $neg)
$posAsync = Safe-Count @($win | Where-Object { $_.Text.Contains('AsyncLogger') })
Say ('  POSCTL AsyncLogger in the window      : {0}   expected > 0' -f $posAsync)

Say ''
Say '===== 5  the cluster around the question, VERBATIM and in order ====='
$from = $lastStart
$clusterStart = $null
$ask = @($win | Where-Object { $_.Text.Contains('<<getUsers unionId=') })
if ((Safe-Count $ask) -gt 0) { $clusterStart = $ask[0].Time.AddSeconds(-3) } else { $clusterStart = $from }
$clusterEnd = $clusterStart.AddSeconds(8)
Say ('  window {0} .. {1}   - read the ORDER, do not infer it' -f $clusterStart.ToString('HH:mm:ss.fff'), $clusterEnd.ToString('HH:mm:ss.fff'))
$cluster = @($win | Where-Object { $_.Time -ge $clusterStart -and $_.Time -le $clusterEnd })
Say ('  lines in the cluster : {0}' -f (Safe-Count $cluster))
foreach ($x in @($cluster | Select-Object -First 120)) {
    Say ('      {0}  | {1}' -f $x.Time.ToString('HH:mm:ss.fff'), $x.Text.Trim().Substring(0, [Math]::Min(170, $x.Text.Trim().Length)))
}

Say ''
Say '===== verdict - on MY instrument only. The branch is the coordinator call ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Say ('  suspect needles {0} ; NEGCTL {1} ; POSCTL In use {2}' -f (Safe-Count $suspect), $neg, $pos)
Fin (($neg -eq 0) -and ($posAsync -gt 0))
