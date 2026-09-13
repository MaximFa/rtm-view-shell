#Requires -Version 5.1
<#
  PROBE 234 / loaddata-unions      does union 21 have a workgroup mapping at all?
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate. READ ONLY.
  Starts nothing, stops nothing, restarts nothing, writes no config, touches no service, and queries
  NO database - the engine already prints what it loaded from the database, so no password is needed
  and none is prompted. C:\IceDash is never read or listed. Its only write is its report.

  WHAT IT SETTLES. The Agent Grid was asked for unionId=21 and answered count=0 users=[]. For union 21
  there is not a single refreshUnions MISS line, while union 5 produced 1794 of them. By the code that
  means union 21's UserGroups dictionary is EMPTY, not that a comparison failed:
    UserManager.cs:570  foreach (List<string> wgArr in union.UserGroups.Values)
        an empty dictionary iterates zero times -> no Add, no MISS, total silence, Users stays empty
    Engine.cs:549-555   union.UserGroups.GetOrAdd(supergroupId, ...).Add(usergroupId)
        the ONLY filler, and it runs once per ROW of RTSGrid_GetAllUnionUserGroups (Engine.cs:377,
        RealtimeData.cs:177) - so a union with no rows in that mapping can never hold a user
  That was an inference from the loop structure, and I reported it as one. This probe turns it into a
  measurement WITHOUT touching the database, because Engine.cs:554 logs every row it loaded:
        LoadData union=<N> sg=<S> needGroups=[...]

  WHAT IT ANSWERS:
   1. every distinct unionId that appears in a LoadData line, with its supergroups and needGroups
   2. whether 21 is among them - the whole question in one line
   3. the same for 5, as a POSITIVE control: union 5 demonstrably has a mapping (it produced MISSes),
      so if 5 is absent from the LoadData lines, my reading of the log is wrong and NOTHING here is
      evidence - that is the control that keeps a silent log from looking like an empty mapping
   4. the last "LoadData: Union User Groups" banner, so we know which load the numbers belong to

  EXPECTATIONS, NAMED BEFORE THE RUN:
     union 5 present in LoadData lines  : YES  <- POSCTL. If NO, stop reading, the instrument lied.
     LoadData lines found               : >= 1
     union 21 present                   : THIS IS THE QUESTION. Absent -> no mapping -> an empty grid
                                          is guaranteed by data, independent of adapter, pipe, traffic.
                                          Present -> my inference was wrong and the subject moves again.
     NEGCTL : an impossible string -> 0
  Hebrew goes to the FILE only: the console cannot render it and a garbled console has swallowed
  following commands before. Reads are -Encoding UTF8 for the same reason as the previous probe.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$ASKED = 21
$POSCTL_UNION = 5

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_loaddata-unions.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function SayFileOnly($text) { [void]$Report.Add($text) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound - numbers are not evidence)' }))
    [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to measure'; Fin $false }
Say ('  now : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  the grid asked for union {0} ; union {1} is the positive control' -f $ASKED, $POSCTL_UNION)
Say '  NO database query, NO password. The engine prints what it loaded; that is the source here.'

Say ''
Say '===== 1  engine log files, discovered from the SERVICE MANAGER ====='
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
                     Where-Object { $_.Name -match '(?i)^RTM\.log|^log\.txt$' } | Sort-Object LastWriteTime)) {
        Say ('  {0}   {1} bytes   mtime {2}' -f $f.FullName, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        [void]$files.Add($f.FullName)
    }
}
Say ('  files : {0}   expected >= 1' -f $files.Count)
if ($files.Count -lt 1) { Say '  *** nothing discovered - refusing to report zeros'; Fin $false }

Say ''
Say '===== 2  LoadData lines ====='
$loadLines = New-Object System.Collections.ArrayList
$banners = New-Object System.Collections.ArrayList
$negCtl = 0
foreach ($file in $files) {
    $lines = @(Get-Content -LiteralPath $file -Encoding UTF8 -ErrorAction SilentlyContinue)
    $hits = @($lines | Where-Object { $_.Contains('LoadData union=') })
    $bans = @($lines | Where-Object { $_.Contains('LoadData: Union User Groups') })
    Say ('  {0} : LoadData union= lines {1} , banners {2}' -f $file, $hits.Count, $bans.Count)
    foreach ($h in $hits) { [void]$loadLines.Add($h) }
    foreach ($b in $bans) { [void]$banners.Add($b) }
    $negCtl += @($lines | Where-Object { $_.Contains('ZZZ-cannot-occur-ZZZ') }).Count
}
Say ('  total LoadData union= lines : {0}   expected >= 1' -f $loadLines.Count)
Say ('  total banners               : {0}' -f $banners.Count)
Say ('  NEGCTL impossible string    : {0}   expected 0' -f $negCtl)
if ($loadLines.Count -lt 1) {
    Say '  *** the engine never printed a LoadData union= line in these files. Then this probe cannot'
    Say '      answer the question, and the absence of union 21 below would prove NOTHING. Stopping.'
    Fin $false
}
Say '  --- the last 3 banners, so the numbers can be dated ---'
foreach ($b in @($banners | Select-Object -Last 3)) { Say ('      | ' + $b.Trim()) }

Say ''
Say '===== 3  distinct unions in the mapping, as the engine loaded it ====='
$unionIds = New-Object System.Collections.ArrayList
foreach ($line in $loadLines) {
    $m = [regex]::Match($line, 'LoadData union=(\d+)\s+sg=(\d+)')
    if ($m.Success) {
        $uid = [int]$m.Groups[1].Value
        if (-not $unionIds.Contains($uid)) { [void]$unionIds.Add($uid) }
    }
}
$sorted = @($unionIds | Sort-Object)
Say ('  distinct unions with a mapping : {0}' -f $sorted.Count)
Say ('  the ids : ' + ($sorted -join ', '))

$posOk = ($sorted -contains $POSCTL_UNION)
Say ('  POSCTL union {0} present : {1}   expected True' -f $POSCTL_UNION, $posOk)
if (-not $posOk) {
    Say '  *** the control union is MISSING from the lines I can read, although it demonstrably has a'
    Say '      mapping (it produced 1794 MISS lines). So my reading is wrong, and the answer below is'
    Say '      NOT evidence. Stopping rather than reporting a convenient absence.'
    Fin $false
}

$askedPresent = ($sorted -contains $ASKED)
Say ''
Say ('===== 4  THE ANSWER : union {0} present in the mapping : {1} =====' -f $ASKED, $askedPresent)
if ($askedPresent) {
    Say '  -> union 21 HAS a mapping. Then my inference from the loop was WRONG: the dictionary is not'
    Say '     empty, and the silence of refreshUnions for 21 needs another explanation. Its rows:'
    foreach ($line in @($loadLines | Where-Object { $_ -match ("LoadData union=" + $ASKED + "\s") })) {
        SayFileOnly ('      | ' + $line.Trim())
    }
    Say ('     rows for union {0} : {1} - see the file for the names' -f $ASKED, @($loadLines | Where-Object { $_ -match ("LoadData union=" + $ASKED + "\s") }).Count)
} else {
    Say '  -> union 21 has NO mapping row. Its UserGroups dictionary is empty, refreshUnions iterates'
    Say '     zero times, no user is ever added, and the Agent Grid for it is guaranteed empty by DATA -'
    Say '     independent of the adapter, the pipe and the traffic. This is measured, not inferred.'
}

Say ''
Say '===== 5  every mapping row, per union (names into the FILE) ====='
foreach ($uid in $sorted) {
    $rows = @($loadLines | Where-Object { $_ -match ("LoadData union=" + $uid + "\s") })
    Say ('  union {0,4} : rows {1}' -f $uid, $rows.Count)
    foreach ($r in ($rows | Select-Object -Last 8)) { SayFileOnly ('      | ' + $r.Trim()) }
}

Say ''
Say '===== verdict - on MY instrument ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Say ('  POSCTL passed : {0} ; LoadData lines : {1} ; NEGCTL : {2}' -f $posOk, $loadLines.Count, $negCtl)
Fin ($posOk -and ($negCtl -eq 0))
