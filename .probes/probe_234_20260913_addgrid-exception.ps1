#Requires -Version 5.1
<#
  PROBE 234 / addgrid-exception      WHAT exception kills Engine.AddGridConnection. READ ONLY.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate; it refuses to run
                  anywhere else. Restarts nothing, stops nothing, writes no config, queries no database,
                  reads no config key at all, prompts for no password. C:\IceDash is never touched.
                  Its only write is its own report.

  WHY THIS RUN EXISTS, and the defect in MY OWN previous probe that made it necessary.
  The early-ask run found the cause of the empty grid: at 12:35:05.082 the engine logged
      ERROR Engine.AddGridConnection gridId=u21
  and the same for gridId 5, 6, 7, 8, plus ERROR refreshCells - every subscription registration threw.
  That is why "Union 21 In use" (Engine.cs:2122) never appeared although "Groups.Add UnionId = u21" did,
  and why the POSCTL separated them honestly: the needle has 10 hits in the corpus and 0 in the window,
  so its zero IS a finding rather than a blind spot.
  But the exception TEXT did not reach me, and that was my fault, not the log's: log4net writes the stack
  trace on CONTINUATION lines that carry NO timestamp, and my probe kept only lines whose time parsed.
  The same family I have been fighting all cycle - unparsed lines dropped silently. So this probe reads by
  LINE INDEX, not by time: for every matching ERROR it prints that line and the following lines verbatim
  until the next timestamped line, which is exactly one exception block and nothing else.

  WHAT IS NOT ASSUMED. I had a mechanism in mind - the engine's collections not being ready at 12:35:05,
  since LoadData only finished at 12:35:27 - and I checked it in the object store before bringing it:
      v3:RTM/RTM/Engine.cs:28   public UnionList UnionList { get; set; } = new UnionList();
      v3:RTM/RTM/Engine.cs:31   private GridList _gridList = new GridList();
      v3:RTM/RTM/Union.cs:36    public ConcurrentDictionary<string,int> Connections = new ...();
  All three are initialised at their declaration, so none of them can be null, and a
  NullReferenceException on those is NOT the explanation. I am therefore carrying no hypothesis into this
  run: the exception type and its stack are what the log says, and the log is what this probe prints.
  Also established from the code, so the report can be read without it:
      v3:RTM/RTM/Engine.cs:2108-2155  the whole body sits in try/catch, and the catch logs
            AsyncLogger.Error("Engine.AddGridConnection gridId=" + gridId, ex)
        -> the throw is SWALLOWED: the caller never learns, the client stays in the SignalR group, the
           engine never records the connection, and union.InUse is never set to true
      v3:RTM/RTM/RTMHub.cs:87-101     the hub logs Groups.Add, calls the engine, then getUsers, then
           SendAsync to the group UNCONDITIONALLY - so the client gets answered regardless

  WHAT IT PRINTS
    1. every "ERROR Engine.AddGridConnection" block in the last engine-start window, with its stack
    2. every "ERROR refreshCells" block in the same window, for comparison - if both carry the same
       exception type, the cause is shared and not specific to the union path
    3. the count of those errors across the WHOLE corpus, per grid id, with the earliest and latest time -
       this says whether the defect is new or has been there all along
    4. POSCTL "Union <N> In use" over the corpus (must be > 0, else the success line is matcher-suspect)
       and NEGCTL an impossible string (must be 0)
  No secrets can reach this report: it reads LOG files only, never a config, and prints no key or value.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$SENTINEL = -999
$NEG = 'ZZZ-cannot-occur-ZZZ'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_addgrid-exception.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound)' }))
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

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
foreach ($h in @('Get-LineTime','Safe-Count')) {
    $rr = Get-Command $h -ErrorAction SilentlyContinue
    Say ('  {0} resolves to {1}   expected Function' -f $h, $rr.CommandType)
    if ("$($rr.CommandType)" -ne 'Function') { Say '  *** helper shadowed'; Fin $false }
}
$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('  assignment gate : unassigned {0} (want {1}) , empty {2} , two {3}' -f $gA, $SENTINEL, $gB, $gC)
if (-not (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2))) { Say '  *** gate broken'; Fin $false }
Say ('  now : {0}   READ ONLY, logs only, no config is opened' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

Say ''
Say '===== 1  the log files, discovered from the service manager ====='
$svcEngine = Get-WmiObject Win32_Service -Filter "Name='RTMService'" -ErrorAction SilentlyContinue
if (-not $svcEngine) { Say '  *** RTMService not found'; Fin $false }
$engExe = "$($svcEngine.PathName)".Trim()
if ($engExe.StartsWith('"')) { $engExe = $engExe.Substring(1, $engExe.IndexOf('"', 1) - 1) }
else { $q = $engExe.IndexOf(' -'); if ($q -gt 0) { $engExe = $engExe.Substring(0, $q) } }
$engineDir = [IO.Path]::GetDirectoryName($engExe)
$files = New-Object System.Collections.ArrayList
foreach ($root in @((Join-Path $engineDir 'Logs'), 'C:\Logs\RTM')) {
    if (-not (Test-Path -LiteralPath $root)) { Say ('  {0} : absent' -f $root); continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match '(?i)^RTM\.log$|^log\.txt$' } | Sort-Object LastWriteTime -Descending)) {
        Say ('  {0}   {1} bytes   mtime {2}' -f $f.FullName, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        [void]$files.Add($f.FullName)
    }
}
if ((Safe-Count $files) -lt 1) { Say '  *** no engine log'; Fin $false }

$MARKERS = @('ERROR Engine.AddGridConnection', 'ERROR refreshCells')
$totalBlocks = 0
$perGrid = @{}
$firstSeen = @{}
$lastSeen = @{}
$posctl = 0
$negctl = 0

foreach ($p in $files) {
    $lines = @(Get-Content -LiteralPath $p -Encoding UTF8 -ErrorAction SilentlyContinue)
    Say ''
    Say ('===== 2  ' + $p + '   lines ' + (Safe-Count $lines) + ' =====')
    # the window: from the LAST "RTM Start" in this file, by index, so untimed lines are kept
    $startIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Contains('RTM Start')) { $startIdx = $i } }
    Say ('  last "RTM Start" at line index : {0}   (-1 means this file has none; then the whole file is read)' -f $startIdx)
    $from = $(if ($startIdx -ge 0) { $startIdx } else { 0 })

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Contains($NEG)) { $negctl++ }
        if ($lines[$i] -match 'Union \d+ In use') { $posctl++ }
        $isMarker = $false
        foreach ($m in $MARKERS) { if ($lines[$i].Contains($m)) { $isMarker = $true } }
        if (-not $isMarker) { continue }
        $tm = Get-LineTime $lines[$i]
        $gid = 'n/a'
        $gm = [regex]::Match($lines[$i], 'gridId=([A-Za-z0-9]+)')
        if ($gm.Success) { $gid = $gm.Groups[1].Value }
        if (-not $perGrid.ContainsKey($gid)) { $perGrid[$gid] = 0 }
        $perGrid[$gid] = $perGrid[$gid] + 1
        if ($tm) {
            if (-not $firstSeen.ContainsKey($gid)) { $firstSeen[$gid] = $tm }
            $lastSeen[$gid] = $tm
        }
        if ($i -lt $from) { continue }      # count everywhere, PRINT only inside the window
        $totalBlocks++
        if ($totalBlocks -gt 12) { continue }
        Say ''
        Say ('  --- block {0} at line {1} ---' -f $totalBlocks, $i)
        Say ('      | ' + $lines[$i])
        # print continuation lines: everything until the next line that carries a timestamp
        $j = $i + 1
        $printed = 0
        while ($j -lt $lines.Count -and $printed -lt 14) {
            if ($null -ne (Get-LineTime $lines[$j])) { break }
            Say ('      | ' + $lines[$j])
            $printed++
            $j++
        }
        Say ('      (continuation lines printed : {0})' -f $printed)
        if ($printed -eq 0) {
            Say '      *** no continuation line: this log4net appender does not write the stack for this'
            Say '          entry, so the exception TYPE is not in this file. Saying so rather than guessing.'
        }
    }
}

Say ''
Say '===== 3  how long this has been happening, per grid id, over the WHOLE corpus ====='
Say '  gridId   occurrences   earliest              latest'
foreach ($k in @($perGrid.Keys | Sort-Object)) {
    $fs = $(if ($firstSeen.ContainsKey($k)) { $firstSeen[$k].ToString('MM-dd HH:mm:ss') } else { 'untimed' })
    $ls = $(if ($lastSeen.ContainsKey($k))  { $lastSeen[$k].ToString('MM-dd HH:mm:ss') }  else { 'untimed' })
    Say ('  {0,-8} {1,-13} {2,-21} {3}' -f $k, $perGrid[$k], $fs, $ls)
}
Say '  An earliest date well before this cycle means the defect is OLD and not something we introduced.'

Say ''
Say '===== 4  controls ====='
Say ('  POSCTL "Union <N> In use" over the corpus : {0}   expected > 0, else the success line is suspect' -f $posctl)
Say ('  NEGCTL impossible string                 : {0}   expected 0' -f $negctl)
Say ('  error blocks printed (window only)       : {0}' -f $totalBlocks)
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Fin (($negctl -eq 0) -and ($posctl -gt 0))
