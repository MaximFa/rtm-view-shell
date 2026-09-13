#Requires -Version 5.1
<#
  PROBE 234 / r1-verify-v4      DISCOVERY FIRST. The previous run failed on MY paths, not on the system.
  WHERE IT RUNS : server 234 (machine RTM). It REFUSES to run anywhere else - machine name AND hardware
                  UUID are a gate. EVERY line of this box runs on 234.
  READ ONLY. Starts nothing, stops nothing, restarts nothing, writes no config, touches no service,
  queries no database. It asks the service manager and the process for paths, lists files, reads text.

  WHY v4 EXISTS - v3 discovered the paths correctly and then threw them away. `Split-Path -LiteralPath
  <x> -Parent` CANNOT bind on PS 5.1: -LiteralPath and -Parent live in different parameter sets, so every
  call raised AmbiguousParameterSet and both service directories came out EMPTY. Sections 2 and 5 then
  degraded and the coordinator's count= predicate went unmeasured for the second time. Fixed with
  [IO.Path]::GetDirectoryName, which is a pure string operation and binds nothing. Second fix: the
  adapter/engine split no longer tests a PREFIX that may be empty - the engine log turned out to live in
  C:\Logs\RTM\, not under the service directory at all - it classifies by whether the path names Twilio,
  which is what the two log trees actually differ by.
  WHAT v3 DID ESTABLISH, and v4 keeps: the adapter is NOT mute. C:\Logs\RTM.Twilio\log.txt carried 343
  lines, 0 ERROR SendToAllAsync, 0 flood signature, 342 INFO - so the main gate of the R1 report is real
  and my vacuum-retraction is withdrawn. The new finding is the mtime: 01:16:00 against a 01:15:56 start
  and a 01:50 clock. The adapter logged for four seconds and has been silent for half an hour, while the
  engine keeps writing. It is not flooding - it STOPPED.

  WHY v3 EXISTED - my own defect, named before any number. v2 returned FAIL on three items:
    C:\RTMView\RTMTwilio_1\log4net.config   exists False      <- a path I INVENTED
    engine log directory C:\RTMView\RTMView_1 , files 0       <- also invented; the real one, per my own
                                                                 earlier measurement, is C:\RTMView\RTM\Logs
  So v2 proved nothing about the adapter and nothing about the engine. "Adapter is mute" was NOT measured -
  I looked in the wrong place and my own verdict line said FAIL as if the system had failed. That is the
  same family as a check that goes green because its gate was skipped: a predicate pointed at a path that
  does not exist cannot fail for the right reason.

  THE RULE THIS PROBE FOLLOWS: not one product path is written by me. Every path comes from the machine:
    - the service binary path from Win32_Service.PathName, for RTMTwilio_1 and RTMService
    - the running image path from the process object
    - the log files by ENUMERATING the directories those two resolve to, plus log4net's own declaration
  Only the ops root (C:\RTMView-Ops\output) and the search root C:\RTMView are named, and the search root
  is verified to exist before it is used; if it does not, the probe says so and stops instead of reporting
  zeros. C:\IceDash is never read, listed or searched.

  WHAT IT ANSWERS, in order:
   0. machine and instrument
   1. DISCOVERY: where the two services actually live, from the service manager and the process
   2. the adapter's log4net config - found, not assumed - and the file paths it declares
   3. every log-shaped file under the discovered directories, with size and mtime, and which of them
      were written after the mark - this is the POSITIVE control for "the adapter is logging at all"
   4. what the live adapter file says after the mark: SendToAllAsync, the not-connected flood signature
      (1048 before the rollback), connect timeout, "reconnecting in" (8abd19a has no supervisor loop)
   5. the engine side after the mark, every pipe event verbatim IN FILE ORDER - a 1/1 pair needs an
      order and an interval, which a counter cannot give
   6. the agent count - the coordinator's 07:4x predicate: ChangedUnionUsersData count=, PUSH
      updateUserGrid, <<getUsers unionId=, plus both branches of the second candidate
   7. services, the named pipe, the process start time

  EXPECTATIONS, NAMED BEFORE THE RUN:
     both services resolve to an existing binary path                  -> if not, discovery failed, not the system
     at least one log-shaped file was written after the mark           -> POSCTL; 0 here is a real finding ONLY
                                                                          because the paths are now discovered
     NEGCTL : a string that cannot occur must return 0 in both streams
     the count= numbers are PRINTED, NOT GATED - which branch is a failure is the coordinator's call,
     and a gate there would let me sign off my own reading
  A FAIL line in this report means a DISCOVERY step failed. System findings are stated as numbers, not
  as a verdict.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$SearchRoot = 'C:\RTMView'
$MarkTime = [datetime]'2026-09-13 01:15:24'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_r1-verify-v4.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (discovery sound)' } else { 'VERDICT: FAIL (a discovery step failed)' }))
    [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($targetPath) {
    if (Test-Path -LiteralPath $targetPath) { return (Get-FileHash -LiteralPath $targetPath -Algorithm SHA256).Hash } else { return 'ABSENT' }
}

Say '===== 0  machine identity and the instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq $UUIDGATE)
Say ('  name  expected {0} , actual {1} -> {2}' -f $NAMEGATE, $env:COMPUTERNAME, $nameOk)
Say ('  uuid  expected {0} , actual {1} -> {2}' -f $UUIDGATE, $uuid, $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say '  *** NOT server 234 - refusing to measure'; Fin $false }
Say ('  PowerShell {0}' -f $PSVersionTable.PSVersion)
$resolvedHash = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ('  Get-Sha256Of resolves to : {0}   expected Function' -f $resolvedHash.CommandType)
if ("$($resolvedHash.CommandType)" -ne 'Function') { Say '  *** the hash helper is shadowed - stop'; Fin $false }
Say ('  mark (time origin) : {0}' -f $MarkTime.ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  now                : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  search root {0} exists : {1}   expected True' -f $SearchRoot, (Test-Path -LiteralPath $SearchRoot))
if (-not (Test-Path -LiteralPath $SearchRoot)) { Say '  *** the search root is absent - refusing to report zeros'; Fin $false }

$problems = New-Object System.Collections.ArrayList
$dirs = New-Object System.Collections.ArrayList

Say ''
Say '===== 1  DISCOVERY - where the services actually live. Not one of these paths is written by me ====='
foreach ($svcName in @('RTMTwilio_1','RTMService')) {
    $wmi = Get-WmiObject Win32_Service -Filter ("Name='" + $svcName + "'") -ErrorAction SilentlyContinue
    if (-not $wmi) { Say ('  {0} : NOT FOUND in the service manager' -f $svcName); [void]$problems.Add($svcName + ' not found'); continue }
    Say ('  {0} : state {1} , startmode {2}' -f $svcName, $wmi.State, $wmi.StartMode)
    Say ('      PathName : {0}' -f $wmi.PathName)
    $exe = "$($wmi.PathName)".Trim()
    if ($exe.StartsWith('"')) { $exe = $exe.Substring(1, $exe.IndexOf('"', 1) - 1) }
    else { $sp = $exe.IndexOf(' -'); if ($sp -gt 0) { $exe = $exe.Substring(0, $sp) } }
    Say ('      parsed exe : {0}   exists {1}' -f $exe, (Test-Path -LiteralPath $exe))
    if (-not (Test-Path -LiteralPath $exe)) { [void]$problems.Add($svcName + ' binary path does not resolve'); continue }
    $svcDir = [IO.Path]::GetDirectoryName($exe)
    Say ('      directory  : {0}' -f $svcDir)
    try {
        $vi = (Get-Item -LiteralPath $exe).VersionInfo
        Say ('      ProductVersion : {0}' -f $vi.ProductVersion)
    } catch { Say ('      ProductVersion : unreadable - {0}' -f $_.Exception.Message) }
    [void]$dirs.Add([pscustomobject]@{ Service = $svcName; Dir = $svcDir })
    $proc = Get-WmiObject Win32_Process -Filter ("ProcessId=" + $wmi.ProcessId) -ErrorAction SilentlyContinue
    if ($proc) {
        Say ('      running pid {0} , image {1}' -f $wmi.ProcessId, $proc.ExecutablePath)
        $p = Get-Process -Id $wmi.ProcessId -ErrorAction SilentlyContinue
        if ($p) { Say ('      started {0}   expected after the mark for the adapter' -f $p.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
    } else { Say ('      no live process for pid {0}' -f $wmi.ProcessId) }
}
Say ('  directories discovered : {0}   expected 2' -f $dirs.Count)
if ($dirs.Count -lt 2) { [void]$problems.Add('fewer than two service directories discovered') }

Say ''
Say '===== 2  the adapter log4net config - FOUND under the discovered directory, not assumed ====='
$declared = New-Object System.Collections.ArrayList
$adapterDir = ($dirs | Where-Object { $_.Service -eq 'RTMTwilio_1' } | Select-Object -First 1).Dir
Say ('  adapter directory as discovered : {0}' -f $adapterDir)
if ($adapterDir -and (Test-Path -LiteralPath $adapterDir)) {
    $cfgs = @(Get-ChildItem -LiteralPath $adapterDir -File -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -match '(?i)log4net.*\.config$|.*\.exe\.config$' })
    Say ('  config-shaped files in it : {0}' -f $cfgs.Count)
    foreach ($c in $cfgs) {
        Say ('    {0}   {1} bytes   mtime {2}' -f $c.Name, $c.Length, $c.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        Say ('      sha : {0}' -f (Get-Sha256Of $c.FullName))
        try {
            $xml = [xml](Get-Content -LiteralPath $c.FullName -Raw)
            $fileNodes = @($xml.SelectNodes('//appender/file'))
            Say ('      <appender><file> elements : {0}' -f $fileNodes.Count)
            foreach ($fn in $fileNodes) {
                $v = $fn.GetAttribute('value')
                if (-not $v) { continue }
                $full = [Environment]::ExpandEnvironmentVariables($v)
                if (-not [IO.Path]::IsPathRooted($full)) { $full = Join-Path $adapterDir $full }
                Say ('        value {0}  ->  {1}' -f $v, $full)
                [void]$declared.Add($full)
            }
        } catch { Say ('      not parseable as XML : {0}' -f $_.Exception.Message) }
    }
} else {
    Say '  *** the adapter directory did not resolve - nothing below this line is about the adapter'
    [void]$problems.Add('adapter directory did not resolve')
}
Say ('  file paths declared by config : {0}' -f $declared.Count)

Say ''
Say '===== 3  POSCTL - every log-shaped file under the DISCOVERED roots, and which moved after the mark ====='
$searchDirs = New-Object System.Collections.ArrayList
foreach ($d in $dirs) { [void]$searchDirs.Add($d.Dir) }
foreach ($dc in $declared) { [void]$searchDirs.Add([IO.Path]::GetDirectoryName($dc)) }
[void]$searchDirs.Add('C:\Logs')
$uniqueDirs = @($searchDirs | Where-Object { $_ } | Sort-Object -Unique)
$live = New-Object System.Collections.ArrayList
foreach ($sd in $uniqueDirs) {
    if (-not (Test-Path -LiteralPath $sd)) { Say ('  {0} : does not exist' -f $sd); continue }
    $logs = @(Get-ChildItem -LiteralPath $sd -File -Recurse -Depth 2 -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -match '(?i)\.log|\.txt$' } | Sort-Object LastWriteTime -Descending)
    Say ('  {0} : log-shaped files {1}' -f $sd, $logs.Count)
    foreach ($lg in ($logs | Select-Object -First 12)) {
        $fresh = ($lg.LastWriteTime -gt $MarkTime)
        Say ('      {0}   {1} bytes   mtime {2}   after the mark : {3}' -f `
             $lg.FullName, $lg.Length, $lg.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $fresh)
        if ($fresh) { [void]$live.Add($lg.FullName) }
    }
}
Say ('  files written after the mark : {0}   expected >= 1  (POSCTL; now the paths are DISCOVERED, so 0 is a real finding)' -f $live.Count)
if ($live.Count -lt 1) { [void]$problems.Add('nothing was written after the mark anywhere under the discovered roots') }

Say ''
Say '===== 4  what the live ADAPTER files say after the mark ====='
$adapterLive = @($live | Where-Object { $_ -match '(?i)twilio' })
Say ('  adapter-side live files : {0}' -f $adapterLive.Count)
if ($adapterLive.Count -eq 0) { Say '  none - the adapter produced no output under any discovered path' }
foreach ($af in $adapterLive) {
    $lines = @(Get-Content -LiteralPath $af -ErrorAction SilentlyContinue)
    Say ('  {0}   total lines {1}' -f $af, $lines.Count)
    $errSend = @($lines | Where-Object { $_.Contains('SendToAllAsync') -and $_.Contains('ERROR') }).Count
    $notConn = @($lines | Where-Object { $_.Contains("hasn't been connected yet") }).Count
    $timeout = @($lines | Where-Object { $_.Contains('connect timeout') -or $_.Contains('TimeoutException') }).Count
    $infoCnt = @($lines | Where-Object { $_.Contains('INFO') }).Count
    $recon   = @($lines | Where-Object { $_.Contains('reconnecting in') }).Count
    Say ('      ERROR SendToAllAsync       : {0}   expected 0 - THE MAIN GATE (was 1048 on aa19743)' -f $errSend)
    Say ("      Pipe hasn't been connected : {0}   expected 0 - the flood signature" -f $notConn)
    Say ('      connect timeout            : {0}   expected 0' -f $timeout)
    Say ('      reconnecting in            : {0}   expected 0 on 8abd19a - it has NO supervisor loop' -f $recon)
    Say ('      POSCTL INFO lines          : {0}   expected >= 1' -f $infoCnt)
    $negA = @($lines | Where-Object { $_.Contains('ZZZ-cannot-occur-ZZZ') }).Count
    Say ('      NEGCTL impossible string   : {0}   expected 0' -f $negA)
    if ($negA -ne 0) { [void]$problems.Add('adapter NEGCTL matched - the matcher is wrong') }
    Say '      --- last 20 lines, verbatim ---'
    foreach ($tl in @($lines | Select-Object -Last 20)) { Say ('      | ' + $tl) }
}

Say ''
Say '===== 5  the ENGINE side after the mark - every pipe event in FILE ORDER ====='
$engineDir = ($dirs | Where-Object { $_.Service -eq 'RTMService' } | Select-Object -First 1).Dir
Say ('  engine directory as discovered : {0}' -f $engineDir)
$engLive = @($live | Where-Object { $_ -notmatch '(?i)twilio' })
Say ('  engine-side live files : {0}' -f $engLive.Count)
if ($engLive.Count -eq 0) {
    Say '  none - nothing engine-side moved after the mark'
    [void]$problems.Add('no engine file written after the mark')
} else {
    $allEng = New-Object System.Collections.ArrayList
    foreach ($ef in $engLive) {
        Say ('    reading {0}' -f $ef)
        foreach ($el in @(Get-Content -LiteralPath $ef -ErrorAction SilentlyContinue)) { [void]$allEng.Add($el) }
    }
    Say ('  engine lines read : {0}' -f $allEng.Count)
    $pipeEvents = @($allEng | Where-Object { $_.Contains('A client connected') -or $_.Contains('client disconnected') -or $_.Contains('=> disconnected') })
    Say ('  pipe events : {0}   - the ORDER and the INTERVAL are the finding, not the count' -f $pipeEvents.Count)
    foreach ($pe in $pipeEvents) { Say ('      | ' + $pe) }
    $asyncCnt = @($allEng | Where-Object { $_.Contains('AsyncLogger') }).Count
    Say ('  POSCTL engine AsyncLogger lines : {0}   expected >= 1' -f $asyncCnt)
    if ($asyncCnt -lt 1) { [void]$problems.Add('engine POSCTL empty - wrong file or wrong matcher') }

    Say ''
    Say '  --- 6  THE AGENT COUNT - the coordinator 07:4x predicate, visible WITHOUT traffic ---'
    Say '  the agent list comes from the call centre through the adapter, never from the database, and'
    Say '  no state filter is applied, so SIGNOFF agents must appear. count = 0 or no PUSH at all puts'
    Say '  the subject in the pipe; count > 0 with an empty screen puts it between engine and Shell.'
    $changed  = @($allEng | Where-Object { $_.Contains('ChangedUnionUsersData count=') })
    $pushes   = @($allEng | Where-Object { $_.Contains('PUSH updateUserGrid') })
    $getUsrs  = @($allEng | Where-Object { $_.Contains('getUsers unionId=') })
    $notFound = @($allEng | Where-Object { $_.Contains('not found; returning null') })
    $notInUse = @($allEng | Where-Object { $_.Contains('!union.InUse') })
    Say ('    ChangedUnionUsersData count= lines : {0}' -f $changed.Count)
    foreach ($cl in $changed) {
        $m = [regex]::Match($cl, 'count=(\d+)')
        Say ('      count = {0}' -f $m.Groups[1].Value)
    }
    Say ('    PUSH updateUserGrid lines : {0}' -f $pushes.Count)
    foreach ($pl in $pushes) { Say ('      | ' + $pl.Substring(0, [Math]::Min(150, $pl.Length))) }
    Say ('    getUsers unionId= lines : {0}' -f $getUsrs.Count)
    foreach ($gl in ($getUsrs | Select-Object -First 10)) { Say ('      | ' + $gl.Substring(0, [Math]::Min(150, $gl.Length))) }
    Say ('    "not found; returning null" : {0}   second candidate: the union was never created' -f $notFound.Count)
    foreach ($nl in ($notFound | Select-Object -First 5)) { Say ('      | ' + $nl.Substring(0, [Math]::Min(150, $nl.Length))) }
    Say ('    "!union.InUse" : {0}   second candidate: union exists but is not InUse' -f $notInUse.Count)
    foreach ($ul in ($notInUse | Select-Object -First 5)) { Say ('      | ' + $ul.Substring(0, [Math]::Min(150, $ul.Length))) }
    $negE = @($allEng | Where-Object { $_.Contains('ZZZ-cannot-occur-ZZZ') }).Count
    Say ('    NEGCTL impossible string : {0}   expected 0' -f $negE)
    if ($negE -ne 0) { [void]$problems.Add('engine NEGCTL matched - the matcher is wrong') }
    Say '    NOTE: these five counts are REPORTED, NOT GATED - which branch is a failure is the'
    Say '    coordinator call, and a gate here would let me sign off my own reading.'
}

Say ''
Say '===== 7  services, the pipe, the process ====='
foreach ($svcName in @('RTMService','RTMTwilio_1')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) { Say ('  {0} : {1}   expected Running' -f $svcName, $svc.Status) }
}
$pipes = @(Get-ChildItem '\\.\pipe\' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)rtm' })
Say ('  named pipes matching rtm : {0}   expected >= 1' -f $pipes.Count)
foreach ($p in $pipes) { Say ('      | ' + $p.Name) }
if ($pipes.Count -lt 1) { [void]$problems.Add('no RTM named pipe present') }

Say ''
Say '===== verdict - about DISCOVERY, not about the system ====='
Say ('  problems recorded : {0}' -f $problems.Count)
foreach ($pr in $problems) { Say ('    - ' + $pr) }
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector was clobbered'; exit 1 }
Fin ($problems.Count -eq 0)
