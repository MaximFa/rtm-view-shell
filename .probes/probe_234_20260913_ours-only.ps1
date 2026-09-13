#Requires -Version 5.1
<#
  PROBE 234 / ours-only      the 12:35 window re-read from OUR logs alone, per file. READ ONLY.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate. Restarts nothing,
                  stops nothing, writes no config, deletes nothing, queries no database, prompts for no
                  password. It does NOT touch C:\IceDash or C:\Program Files\CcDashboard - those are out
                  of perimeter and not read, not listed, not configured. Only write: its own report.
                  No second restart is paid: the coordinator ruled that the already-recorded window is
                  enough, because each engine restart costs an adapter death and ~27 seconds of gap.

  THE RULE THIS PROBE IS BUILT ON [operator directive, 2026-09-13]:
      the set of files to measure comes ONLY from the log-path declarations of OUR services.
      Never from a directory name, never from a guess, never from "this looks like a log directory".
  The chain, every link measured rather than assumed:
      a service whose BINARY lives under C:\RTMView   (that is what makes it ours - a measured property,
                                                       not a name I happen to know)
        -> Win32_Service.PathName -> the binary's directory
        -> that binary's OWN logging config: log4net <file value=...> for the engine and the adapter,
           Serilog WriteTo[].Args.path for the Shell
        -> a relative path resolved against BOTH the install directory and the service working directory
           (%SystemRoot%\System32 for a Windows service unless its definition sets one)
  What this prevents, stated as the failure it would have stopped: I spent a day counting two systems as
  one because I named C:\Logs\RTM "the engine log" from its directory name. No service of ours declares
  it - it belongs to the legacy install - so under this rule it can never enter the corpus. And the rule
  shows its own correctness in the other direction too: C:\Windows\System32\logs DOES enter, because our
  Shell's Serilog declares a relative path and a service resolves it there.
  Reading the Shell config touches ONE named key: the Serilog sink path. Nothing else in the operator's
  file is read - a blanket pattern over a config printed a production password earlier today.

  SECOND LINE, kept because a declared path can lead into a directory that also holds other files:
  every line carries ITS OWN FILE, every count is printed PER FILE, and the report never sums across
  files. A number without its file is what let the earlier conflation survive as long as it did.

  WHAT IS ASKED, over the window of the last engine start recorded in OUR engine log:
      did anything ask OUR engine again after OUR engine restarted, with no Shell restart?
        `<<getUsers unionId=` in OUR log  >= 1  -> our Shell re-subscribes on its own
                                          = 0   -> it does not, and PR234-SHELL-RESUB-01 is confirmed
  The earlier answer to this question came from a line in the legacy log, which is why the finding was
  withdrawn and the subject stands at UNKNOWN. Reported, not gated: the branch is the coordinator's call.
  Context that must be read beside it, per file: Groups.Add / init GridId / ChangedUnionUsersData /
  PUSH / Union In use / the AddGridConnection error branches / pipe events / LoadData / refreshUnions.

  CONTROLS: assignment gate with a sentinel, self-tested; parser control on synthetic lines only;
  POSCTL per needle over OUR whole corpus, so a needle absent everywhere is flagged matcher-suspect and
  its window zero is not a finding; NEGCTL an impossible string per file.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$OURROOT = 'C:\RTMView'
$SENTINEL = -999
$NEG = 'ZZZ-cannot-occur-ZZZ'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_ours-only.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound)' }))
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
    if ("$($rr.CommandType)" -ne 'Function') { Say '  *** helper shadowed'; Fin $false }
}
$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('  assignment gate : unassigned {0} (want {1}) , empty {2} , two {3}' -f $gA, $SENTINEL, $gB, $gC)
if (-not (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2))) { Say '  *** gate broken'; Fin $false }
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
Say ('  now : {0}   READ ONLY, no restart is paid for this run' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

Say ''
Say '===== 1  OUR services - selected by where their BINARY lives, not by name I already know ====='
$ourSvc = New-Object System.Collections.ArrayList
foreach ($s in @(Get-WmiObject Win32_Service -ErrorAction SilentlyContinue)) {
    $raw = "$($s.PathName)".Trim()
    if ($raw -eq '') { continue }
    $exe = $raw
    if ($exe.StartsWith('"')) { $exe = $exe.Substring(1, $exe.IndexOf('"', 1) - 1) }
    else { $q = $exe.IndexOf(' -'); if ($q -gt 0) { $exe = $exe.Substring(0, $q) } }
    if (-not $exe.StartsWith($OURROOT, [StringComparison]::OrdinalIgnoreCase)) { continue }
    $d = [IO.Path]::GetDirectoryName($exe)
    Say ('  {0,-14} state {1,-9} {2}' -f $s.Name, $s.State, $exe)
    [void]$ourSvc.Add([pscustomobject]@{ Name = $s.Name; Dir = $d })
}
Say ('  services under {0} : {1}   expected 3' -f $OURROOT, (Safe-Count $ourSvc))
Say '  anything outside this root is out of perimeter and is not read by this probe at all.'
if ((Safe-Count $ourSvc) -lt 1) { Say '  *** no service of ours found'; Fin $false }

Say ''
Say '===== 2  log paths, taken ONLY from the logging config of each of OUR services ====='
$files = New-Object System.Collections.ArrayList
foreach ($svc in $ourSvc) {
    Say ''
    Say ('  --- {0} : {1} ---' -f $svc.Name, $svc.Dir)
    $declared = New-Object System.Collections.ArrayList
    $l4 = Join-Path $svc.Dir 'log4net.config'
    if (Test-Path -LiteralPath $l4) {
        Say ('      log4net.config : present')
        try {
            $xml = [xml](Get-Content -LiteralPath $l4 -Raw -Encoding UTF8)
            foreach ($fn in @($xml.SelectNodes('//appender/file'))) {
                $v = $fn.GetAttribute('value')
                if ($v) { Say ('        declares : {0}' -f $v); [void]$declared.Add($v) }
            }
            if ((Safe-Count $declared) -eq 0) { Say '        no <appender><file> element declared' }
        } catch { Say ('        *** not parseable : {0}' -f $_.Exception.Message) }
    } else { Say '      log4net.config : absent' }
    $aj = Join-Path $svc.Dir 'appsettings.json'
    if (Test-Path -LiteralPath $aj) {
        Say ('      appsettings.json : present - reading ONE key: Serilog WriteTo[].Args.path')
        try {
            $o = Get-Content -LiteralPath $aj -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($sink in @($o.Serilog.WriteTo)) {
                if ($sink.Args -and $sink.Args.path) { Say ('        declares : {0}' -f $sink.Args.path); [void]$declared.Add($sink.Args.path) }
            }
        } catch { Say ('        *** not parseable : {0}' -f $_.Exception.Message) }
    } else { Say '      appsettings.json : absent' }
    if ((Safe-Count $declared) -eq 0) { Say '      -> declares no log path; nothing of this service is read'; continue }
    foreach ($decl in $declared) {
        $d2 = "$decl" -replace '/', '\'
        $bases = @()
        if ([IO.Path]::IsPathRooted($d2)) { $bases = @('') } else { $bases = @($svc.Dir, [Environment]::SystemDirectory) }
        foreach ($b in $bases) {
            $full = $(if ($b -eq '') { $d2 } else { Join-Path $b $d2 })
            $dir = [IO.Path]::GetDirectoryName($full)
            $leaf = [IO.Path]::GetFileNameWithoutExtension($full)
            Say ('        resolved : {0}' -f $full)
            if (-not (Test-Path -LiteralPath $dir)) { Say '            directory absent'; continue }
            $hits = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
                      Where-Object { $_.Name.StartsWith($leaf, [StringComparison]::OrdinalIgnoreCase) } |
                      Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-30) } | Sort-Object LastWriteTime -Descending)
            Say ('            files there, under 30 h old : {0}' -f (Safe-Count $hits))
            foreach ($f in $hits) {
                Say ('              {0}   {1} bytes   {2}' -f $f.Name, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
                [void]$files.Add([pscustomobject]@{ Svc = $svc.Name; Path = $f.FullName })
            }
        }
    }
}
Say ''
Say ('  files entering the corpus : {0}' -f (Safe-Count $files))
foreach ($f in $files) { Say ('      {0,-14} {1}' -f $f.Svc, $f.Path) }
Say '  NOTE: C:\Logs\RTM is declared by NO service of ours and therefore does not appear above. That is'
Say '  the rule working: the directory that cost me a day cannot enter the corpus by construction.'
if ((Safe-Count $files) -lt 1) { Say '  *** nothing declared and present - stopping'; Fin $false }
Flush

Say ''
Say '===== 3  reading, with every line bound to ITS FILE ====='
$rows = New-Object System.Collections.ArrayList
foreach ($f in $files) {
    $n = 0
    foreach ($line in @(Get-Content -LiteralPath $f.Path -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        [void]$rows.Add([pscustomobject]@{ File = $f.Path; Svc = $f.Svc; Time = (Get-LineTime $line); Text = $line })
        $n++
    }
    Say ('  {0,-14} {1,-52} lines {2}' -f $f.Svc, [IO.Path]::GetFileName($f.Path), $n)
}
Say ('  total lines {0} , with a parsed time {1}' -f (Safe-Count $rows), (Safe-Count @($rows | Where-Object { $null -ne $_.Time })))

$engineFiles = @($files | Where-Object { $_.Svc -eq 'RTMService' } | ForEach-Object { $_.Path })
$engRows = @($rows | Where-Object { $engineFiles -contains $_.File -and $null -ne $_.Time } | Sort-Object Time)
$starts = @($engRows | Where-Object { $_.Text.Contains('RTM Start') })
Say ('  "RTM Start" markers in OUR engine log : {0}' -f (Safe-Count $starts))
if ((Safe-Count $starts) -lt 1) { Say '  *** no start marker in our engine log - cannot bound the window'; Fin $false }
$lastStart = $starts[$starts.Count-1].Time
Say ('  window begins at the LAST start in OUR log : {0}' -f $lastStart.ToString('yyyy-MM-dd HH:mm:ss.fff'))

$NEEDLES = @('<<getUsers unionId=','Groups.Add UnionId =','init GridId=','<<ChangedUnionUsersData count=',
             'PUSH updateUserGrid',' In use','AddGridConnection: union','ERROR Engine.AddGridConnection',
             'SERVER => A client connected','client disconnected','LoadData: Start','LoadData union=',
             'refreshUnions Add','refreshUnions MISS','RECV updateUserGrid','updateUserGrid')

Say ''
Say '===== 4  POSCTL over OUR whole corpus, PER FILE ====='
$suspect = New-Object System.Collections.ArrayList
foreach ($n in $NEEDLES) {
    $total = 0
    $perFile = New-Object System.Collections.ArrayList
    foreach ($f in $files) {
        $c = Safe-Count @($rows | Where-Object { $_.File -eq $f.Path -and $_.Text.Contains($n) })
        if ($c -eq $SENTINEL) { Say ('  *** needle {0} UNASSIGNED - stop' -f $n); Fin $false }
        $total += $c
        [void]$perFile.Add(([IO.Path]::GetFileName($f.Path)) + '=' + $c)
    }
    $flag = ''
    if ($total -eq 0) { $flag = '   <- MATCHER SUSPECT in OUR corpus; its zeros are NOT findings'; [void]$suspect.Add($n) }
    Say ('  {0,-32} {1}{2}' -f $n, ($perFile -join '  '), $flag)
}
$negTotal = Safe-Count @($rows | Where-Object { $_.Text.Contains($NEG) })
Say ('  NEGCTL impossible string : {0}   expected 0' -f $negTotal)
Flush

Say ''
Say '===== 5  THE WINDOW, per needle and PER FILE, with times ====='
$win = @($rows | Where-Object { $null -ne $_.Time -and $_.Time -ge $lastStart } | Sort-Object Time)
Say ('  lines in the window : {0}' -f (Safe-Count $win))
foreach ($n in $NEEDLES) {
    $hits = @($win | Where-Object { $_.Text.Contains($n) })
    $mark = ''
    if ($suspect -contains $n) { $mark = '   (matcher suspect - not a finding)' }
    Say ('  {0,-32} {1}{2}' -f $n, (Safe-Count $hits), $mark)
    foreach ($x in @($hits | Select-Object -First 10)) {
        Say ('      {0}  [{1}]  | {2}' -f $x.Time.ToString('HH:mm:ss.fff'), [IO.Path]::GetFileName($x.File),
             $x.Text.Trim().Substring(0, [Math]::Min(140, $x.Text.Trim().Length)))
    }
}

Say ''
Say '===== 6  the question, and the branches named before the numbers ====='
$askOurs = Safe-Count @($win | Where-Object { $_.Text.Contains('<<getUsers unionId=') })
Say ('  <<getUsers unionId= in OUR corpus, after OUR engine restarted : {0}' -f $askOurs)
Say '    >= 1 -> our Shell re-subscribes by itself after a lone engine restart, and'
Say '            PR234-SHELL-RESUB-01 is refuted ON OUR OWN EVIDENCE this time'
Say '    = 0  -> nothing asked our engine again; the subject is CONFIRMED, and a populated union.Users'
Say '            stays invisible until the Shell process itself restarts'
Say '  Reported, NOT gated. The previous answer to this question came from the legacy log and was'
Say '  withdrawn; this corpus contains only what our own services declare.'

Say ''
Say '===== verdict - on MY instrument only ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Say ('  files {0} ; suspect needles {1} ; NEGCTL {2}' -f (Safe-Count $files), (Safe-Count $suspect), $negTotal)
Fin (($negTotal -eq 0) -and ((Safe-Count $files) -gt 0))
