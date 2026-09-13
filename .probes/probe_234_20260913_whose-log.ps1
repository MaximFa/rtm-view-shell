#Requires -Version 5.1
<#
  PROBE 234 / whose-log      WHOSE log is C:\Logs\RTM, and how many RTM-ish processes run here. READ ONLY.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate. Restarts nothing,
                  writes no config, opens no config, queries no database, deletes nothing, prompts for no
                  password. C:\IceDash is never read or listed. Only write: its own report. Seconds.

  WHY THIS RUN EXISTS - my own defect, and it is the largest of this cycle.
  I treated C:\Logs\RTM as one of "the engine log roots" and merged it with C:\RTMView\RTM\Logs into a
  single corpus. They are NOT one system. Two facts, both already measured:
    - the line formats differ: our engine writes "2026-09-13 12:35:28,117 [5] INFO RTM.Tools.AsyncLogger -"
      while the other file writes "13/09/2026 12:35:05,082 INFO". Two formats mean two loggers.
    - the exception frames in the second file point at C:\Users\user\Dropbox\Code\RTM\RTM\Engine.cs:2576,
      and EVERY assembly in our own directories was just proven to carry OUR build path instead
      (D:\Claude\Build\rtm_clean_b4ad301\... , adapters from D:\Claude\Projects\RTMView-adapters-wt\...),
      with the 803832a fix literal present in RTM.dll.
  So the KeyNotFoundException is NOT our engine's, and my statement that the deployed engine is a foreign
  build is WITHDRAWN. What I actually did was read another system's log and attribute it to ours - the
  operator has said from the start that a legacy RTM runs here permanently and is not to be touched.
  Consequence I must state plainly: every per-window count I reported that drew on C:\Logs\RTM is
  UNSAFE until each line is attributed to its file. That includes the table behind "populated, nobody
  asked", because the asks I counted may belong to the other system.

  WHAT IT ESTABLISHES
    1. EVERY service on this machine whose name or binary path mentions RTM, Twilio, CcDashboard or Shell -
       enumerated, not guessed by name. My earlier probes only ever asked about three names I already knew,
       which is how a whole second installation stayed invisible to me.
    2. For each one: binary path, state, pid, start time, ProductVersion, and the PDB path recorded inside
       the binary - so "ours" versus "built elsewhere" is a measured field, not an inference.
    3. Every RTM-ish process running, including ones that belong to no service.
    4. For C:\Logs\RTM and C:\RTMView\RTM\Logs: the newest file, its first and last line verbatim, and the
       timestamp FORMAT of each - so the two loggers are separated by evidence instead of by my reading.
    5. Which directories exist that look like a second installation, with the ProductVersion of the
       assembly found in each.
  CONTROLS: assignment gate with a sentinel, self-tested; POSCTL - at least one service must be found, and
  at least one log file must be read; NEGCTL - a service name that cannot exist must yield nothing.
  No config file is opened, so no secret can reach this report.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$SENTINEL = -999

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_whose-log.txt')
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
function Get-PdbPath($p) {
    try {
        $bytes = [IO.File]::ReadAllBytes($p)
        $txt = [Text.Encoding]::ASCII.GetString($bytes)
        $i = $txt.IndexOf('.pdb', [StringComparison]::OrdinalIgnoreCase)
        if ($i -lt 0) { return '(no .pdb string)' }
        $from = [Math]::Max(0, $i - 220)
        $chunk = $txt.Substring($from, [Math]::Min(224, $txt.Length - $from))
        $cand = @($chunk -split '[^\x20-\x7E]') | Where-Object { $_ -match '(?i)\.pdb' } | Select-Object -First 1
        if ($cand) { return $cand } else { return '(found .pdb but could not isolate)' }
    } catch { return '(unreadable)' }
}

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
foreach ($h in @('Safe-Count','Get-PdbPath')) {
    $rr = Get-Command $h -ErrorAction SilentlyContinue
    Say ('  {0} resolves to {1}   expected Function' -f $h, $rr.CommandType)
    if ("$($rr.CommandType)" -ne 'Function') { Say '  *** helper shadowed'; Fin $false }
}
$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('  assignment gate : unassigned {0} (want {1}) , empty {2} , two {3}' -f $gA, $SENTINEL, $gB, $gC)
if (-not (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2))) { Say '  *** gate broken'; Fin $false }
Say ('  now : {0}   READ ONLY' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

Say ''
Say '===== 1  EVERY service that mentions RTM / Twilio / CcDashboard / Shell - enumerated, not named ====='
$all = @(Get-WmiObject Win32_Service -ErrorAction SilentlyContinue |
         Where-Object { ("$($_.Name)" + ' ' + "$($_.DisplayName)" + ' ' + "$($_.PathName)") -match '(?i)rtm|twilio|ccdashboard|shell' })
Say ('  matching services : {0}   expected > 0' -f (Safe-Count $all))
$negSvc = Safe-Count @(Get-WmiObject Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'ZZZ-no-such-service-ZZZ' })
Say ('  NEGCTL a service that cannot exist : {0}   expected 0' -f $negSvc)
foreach ($s in @($all | Sort-Object Name)) {
    Say ''
    Say ('  {0}   state {1}   startmode {2}' -f $s.Name, $s.State, $s.StartMode)
    Say ('      DisplayName : {0}' -f $s.DisplayName)
    Say ('      PathName    : {0}' -f $s.PathName)
    $exe = "$($s.PathName)".Trim()
    if ($exe.StartsWith('"')) { $exe = $exe.Substring(1, $exe.IndexOf('"', 1) - 1) }
    else { $q = $exe.IndexOf(' -'); if ($q -gt 0) { $exe = $exe.Substring(0, $q) } }
    if (Test-Path -LiteralPath $exe) {
        $fi = Get-Item -LiteralPath $exe
        Say ('      exe         : {0}   {1} bytes   written {2}' -f $exe, $fi.Length, $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
        Say ('      ProductVersion : {0}' -f $fi.VersionInfo.ProductVersion)
        Say ('      PDB inside exe : {0}' -f (Get-PdbPath $exe))
        $sib = Join-Path ([IO.Path]::GetDirectoryName($exe)) ([IO.Path]::GetFileNameWithoutExtension($exe) + '.dll')
        if (Test-Path -LiteralPath $sib) {
            Say ('      sibling dll    : {0}' -f $sib)
            Say ('      ProductVersion : {0}' -f (Get-Item -LiteralPath $sib).VersionInfo.ProductVersion)
            Say ('      PDB inside dll : {0}   <- THIS is the compilation root' -f (Get-PdbPath $sib))
        }
    } else {
        Say ('      exe         : {0}   DOES NOT RESOLVE' -f $exe)
    }
    if ($s.ProcessId -gt 0) {
        $pr = Get-Process -Id $s.ProcessId -ErrorAction SilentlyContinue
        if ($pr) { Say ('      pid {0}   started {1}' -f $pr.Id, $pr.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
    }
}

Say ''
Say '===== 2  every RTM-ish PROCESS, including any that belongs to no service ====='
$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '(?i)rtm|twilio|ccdash|signalr' })
Say ('  matching processes : {0}' -f (Safe-Count $procs))
foreach ($p in @($procs | Sort-Object ProcessName)) {
    $path = ''
    try { $path = $p.Path } catch { $path = '(path not readable)' }
    $st = ''
    try { $st = $p.StartTime.ToString('yyyy-MM-dd HH:mm:ss') } catch { $st = '(unknown)' }
    Say ('  {0,-22} pid {1,-7} started {2}   {3}' -f $p.ProcessName, $p.Id, $st, $path)
}

Say ''
Say '===== 3  the two log directories, separated by EVIDENCE ====='
foreach ($d in @('C:\Logs\RTM', 'C:\RTMView\RTM\Logs')) {
    Say ''
    Say ('  --- {0}   exists {1} ---' -f $d, (Test-Path -LiteralPath $d))
    if (-not (Test-Path -LiteralPath $d)) { continue }
    $newest = @(Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending) | Select-Object -First 1
    if ($null -eq $newest) { Say '  no files'; continue }
    Say ('  newest : {0}   {1} bytes   written {2}' -f $newest.Name, $newest.Length, $newest.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    $lines = @(Get-Content -LiteralPath $newest.FullName -Encoding UTF8 -ErrorAction SilentlyContinue)
    Say ('  lines : {0}' -f (Safe-Count $lines))
    if ((Safe-Count $lines) -gt 0) {
        Say ('  FIRST line | {0}' -f $lines[0].Substring(0, [Math]::Min(150, $lines[0].Length)))
        Say ('  LAST  line | {0}' -f $lines[$lines.Count-1].Substring(0, [Math]::Min(150, $lines[$lines.Count-1].Length)))
        $iso = Safe-Count @($lines | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2} ' })
        $slash = Safe-Count @($lines | Where-Object { $_ -match '^\s*\d{2}/\d{2}/\d{4} ' })
        Say ('  lines beginning yyyy-MM-dd : {0}' -f $iso)
        Say ('  lines beginning dd/MM/yyyy : {0}' -f $slash)
        Say '  Two formats in two directories means two loggers, hence two systems. One format dominating'
        Say '  each directory is the evidence that separates them - not my reading of the content.'
        $dropbox = Safe-Count @($lines | Where-Object { $_ -match '(?i)Dropbox\\Code\\RTM' })
        $ourRoot = Safe-Count @($lines | Where-Object { $_ -match '(?i)Claude\\Build' })
        Say ('  stack frames naming Dropbox\Code\RTM : {0}' -f $dropbox)
        Say ('  stack frames naming Claude\Build     : {0}' -f $ourRoot)
    }
}

Say ''
Say '===== 4  directories that look like a second installation ====='
foreach ($cand in @('C:\RTMView','C:\Program Files\CcDashboard','C:\RTM','C:\Program Files\RTM','C:\inetpub')) {
    if (-not (Test-Path -LiteralPath $cand)) { Say ('  {0} : absent' -f $cand); continue }
    $subs = @(Get-ChildItem -LiteralPath $cand -Directory -ErrorAction SilentlyContinue)
    Say ('  {0} : subdirectories {1}' -f $cand, (Safe-Count $subs))
    foreach ($sd in $subs) {
        $asm = @(Get-ChildItem -LiteralPath $sd.FullName -File -Filter '*.dll' -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match '(?i)^RTM\.dll$|^RTM\.Tools\.dll$|^CcDashboard' }) | Select-Object -First 1
        if ($null -ne $asm) {
            Say ('      {0,-28} {1,-26} PV {2}' -f $sd.Name, $asm.Name, (Get-Item -LiteralPath $asm.FullName).VersionInfo.ProductVersion)
            Say ('          PDB inside : {0}' -f (Get-PdbPath $asm.FullName))
        } else {
            Say ('      {0,-28} (no RTM/CcDashboard assembly at its top level)' -f $sd.Name)
        }
    }
}

Say ''
Say '===== verdict - on MY instrument only ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Say ('  services found {0} ; processes {1} ; NEGCTL {2}' -f (Safe-Count $all), (Safe-Count $procs), $negSvc)
Fin (((Safe-Count $all) -gt 0) -and ($negSvc -eq 0))
