#Requires -Version 5.1
<#
  PROBE 234 / r1-verify      did the R1 rollback report measure a LIVE file, or an abandoned one?
  WHERE IT RUNS : server 234 (machine RTM). It REFUSES to run anywhere else - machine name AND hardware
                  UUID are a gate. EVERY line of this box runs on 234.
  READ ONLY. Starts nothing, stops nothing, restarts nothing, writes no config, touches no service,
  queries no database. It only lists files, reads text logs and asks the service manager for status.

  WHY THIS RUN EXISTS - a hole in my own R1 report, named before any number. The rollback restored the
  OPERATOR's log4net.config (8abd19a carries NO log4net.config in the tree at all - checked in the object
  store, `git ls-tree -r --name-only 8abd19a` returns nothing for it; the restored file is the machine's
  own, sha 1D520F4D...13FA2). The R1 report then counted "ERROR SendToAllAsync after the mark : 0"
  against the file path the PREVIOUS build (aa19743) logged to. If the restored config points somewhere
  else, that 0 is not a pass - it is an empty file, and my main gate was vacuous. The same run printed
  "POSCTL INFO lines : 0", which is exactly the shape of that failure: a healthy adapter writes INFO.

  WHAT IT ANSWERS, in order:
   1. which file(s) the RESTORED config actually appends to - resolved from the config itself, not assumed
   2. whether ANY of them was written after the rollback began (01:15:24) - the POSITIVE control for
      "the adapter is logging at all"; if nothing was written anywhere, the adapter is mute and the
      R1 error count carries no information
   3. what those live files say since the mark: errors, connects, the reconnect flood signature
   4. the engine side since the mark, with TIMESTAMPS, not just counts - the R1 run reported
      connected 1 AND disconnected 1, and the order and spacing of those two decide whether the
      channel died at the restart or is dying repeatedly
   5. whether the adapter process is holding a pipe handle right now

  EXPECTATIONS, NAMED BEFORE THE RUN:
     the restored config declares at least 1 file appender          -> if 0, the config is not log4net-shaped
     at least one declared file was written after 01:15:24          -> POSCTL; 0 means the adapter is mute
     service RTMTwilio_1 Running , RTMService Running
     engine connected >= 1 since the mark                           (the R1 run saw 1)
     engine disconnected : the R1 run saw 1 - this probe does not expect a value, it TIMES it
     NEGCTL : a grep for a string that cannot occur must return 0
  A FAIL here does not mean the rollback failed - it means my R1 report overstated what it measured.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$AdapterDir = 'C:\RTMView\RTMTwilio_1'
$MarkTime = [datetime]'2026-09-13 01:15:24'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_r1-verify.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS' } else { 'VERDICT: FAIL' }))
    [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($targetPath) {
    if (Test-Path $targetPath) { return (Get-FileHash $targetPath -Algorithm SHA256).Hash } else { return 'ABSENT' }
}

Say '===== G0  machine identity and the instrument, proven before anything is measured ====='
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
Say ('  mark used as the time origin : {0}' -f $MarkTime.ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  now : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

$problems = New-Object System.Collections.ArrayList

Say ''
Say '===== 1  what the RESTORED config says - resolved from the file, not assumed ====='
$cfgPath = Join-Path $AdapterDir 'log4net.config'
Say ('  config : {0}   exists {1}' -f $cfgPath, (Test-Path $cfgPath))
Say ('  its sha : {0}   expected 1D520F4D7AD2451BBBA4BD6CB7BAAFD0BE3C06AB407C8DD1ACD86D7FAE613FA2' -f (Get-Sha256Of $cfgPath))
$declared = New-Object System.Collections.ArrayList
if (Test-Path $cfgPath) {
    try {
        $xml = [xml](Get-Content $cfgPath -Raw)
        foreach ($ap in $xml.SelectNodes('//appender')) {
            $fileNode = $ap.SelectSingleNode('file')
            $fileVal = $null
            if ($fileNode) { $fileVal = $fileNode.GetAttribute('value') }
            Say ('    appender name={0} type={1}' -f $ap.GetAttribute('name'), $ap.GetAttribute('type'))
            if ($fileVal) {
                $full = [Environment]::ExpandEnvironmentVariables($fileVal)
                if (-not [IO.Path]::IsPathRooted($full)) { $full = Join-Path $AdapterDir $full }
                Say ('      file value : {0}' -f $fileVal)
                Say ('      resolved   : {0}' -f $full)
                [void]$declared.Add($full)
            } else {
                Say '      (no <file> element - not a file appender)'
            }
        }
    } catch {
        Say ('  *** could not parse the config as XML : {0}' -f $_.Exception.Message)
        [void]$problems.Add('config unparseable')
    }
}
Say ('  file appenders declared : {0}   expected >= 1' -f $declared.Count)
if ($declared.Count -lt 1) { [void]$problems.Add('no file appender declared') }

Say ''
Say '===== 2  POSCTL: is the adapter logging AT ALL since the rollback began? ====='
$live = New-Object System.Collections.ArrayList
foreach ($cand in $declared) {
    $dir = Split-Path $cand -Parent
    $leaf = Split-Path $cand -Leaf
    $found = @()
    if (Test-Path $dir) {
        $found = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name.StartsWith($leaf, [StringComparison]::OrdinalIgnoreCase) })
    } else {
        Say ('  directory does not exist : {0}' -f $dir)
    }
    Say ('  declared {0} -> matching files on disk : {1}' -f $cand, $found.Count)
    foreach ($f in ($found | Sort-Object LastWriteTime -Descending)) {
        $fresh = ($f.LastWriteTime -gt $MarkTime)
        Say ('      {0}   {1} bytes   mtime {2}   written after the mark : {3}' -f `
             $f.Name, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $fresh)
        if ($fresh) { [void]$live.Add($f.FullName) }
    }
}
Say ('  files written after the mark : {0}   expected >= 1  (POSCTL - 0 means the adapter is MUTE)' -f $live.Count)
if ($live.Count -lt 1) { [void]$problems.Add('adapter wrote nothing anywhere after the rollback') }

Say ''
Say '===== 3  what the LIVE adapter files say since the mark ====='
if ($live.Count -eq 0) {
    Say '  nothing to read - the adapter produced no output; the R1 error count of 0 was VACUOUS'
} else {
    foreach ($lf in $live) {
        $lines = @(Get-Content -LiteralPath $lf -ErrorAction SilentlyContinue)
        Say ('  {0}   total lines {1}' -f $lf, $lines.Count)
        $errSend = @($lines | Where-Object { $_.Contains('SendToAllAsync') -and $_.Contains('ERROR') }).Count
        $notConn = @($lines | Where-Object { $_.Contains("hasn't been connected yet") }).Count
        $timeout = @($lines | Where-Object { $_.Contains('connect timeout') -or $_.Contains('TimeoutException') }).Count
        $infoCnt = @($lines | Where-Object { $_.Contains('INFO') }).Count
        $recon   = @($lines | Where-Object { $_.Contains('reconnecting in') }).Count
        Say ('      ERROR SendToAllAsync      : {0}   expected 0' -f $errSend)
        Say ("      Pipe hasn't been connected: {0}   expected 0   (the aa19743 flood signature, was 1048)" -f $notConn)
        Say ('      connect timeout           : {0}   expected 0' -f $timeout)
        Say ('      reconnecting in           : {0}   expected 0 on 8abd19a - it has NO supervisor loop' -f $recon)
        Say ('      POSCTL INFO lines         : {0}   expected >= 1' -f $infoCnt)
        $negCtl = @($lines | Where-Object { $_.Contains('ZZZ-this-string-cannot-occur-ZZZ') }).Count
        Say ('      NEGCTL impossible string  : {0}   expected 0' -f $negCtl)
        if ($errSend -gt 0) { [void]$problems.Add('adapter is erroring on SendToAllAsync') }
        if ($notConn -gt 0) { [void]$problems.Add('the not-connected flood is present on 8abd19a too') }
        if ($infoCnt -lt 1) { [void]$problems.Add('live file has no INFO lines') }
        if ($negCtl -ne 0) { [void]$problems.Add('NEGCTL matched - the matcher is wrong') }
        Say '      --- last 25 lines, verbatim ---'
        foreach ($tl in @($lines | Select-Object -Last 25)) { Say ('      | ' + $tl) }
    }
}

Say ''
Say '===== 4  the engine side since the mark, TIMED - one connect and one disconnect need an order ====='
$engineDir = 'C:\RTMView\RTMView_1\Logs'
if (-not (Test-Path $engineDir)) { $engineDir = 'C:\RTMView\RTMView_1' }
$engLogs = @(Get-ChildItem -LiteralPath $engineDir -File -Filter 'RTM.log*' -ErrorAction SilentlyContinue |
             Where-Object { $_.LastWriteTime -gt $MarkTime } | Sort-Object LastWriteTime)
Say ('  engine log directory : {0}' -f $engineDir)
Say ('  engine files written after the mark : {0}   expected >= 1' -f $engLogs.Count)
if ($engLogs.Count -lt 1) {
    [void]$problems.Add('no engine log written after the mark')
} else {
    foreach ($ef in $engLogs) {
        Say ('    {0}   {1} bytes   mtime {2}' -f $ef.Name, $ef.Length, $ef.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    }
    $allEng = New-Object System.Collections.ArrayList
    foreach ($ef in $engLogs) {
        foreach ($el in @(Get-Content -LiteralPath $ef.FullName -ErrorAction SilentlyContinue)) { [void]$allEng.Add($el) }
    }
    Say ('  engine lines read : {0}' -f $allEng.Count)
    $pipeEvents = @($allEng | Where-Object { $_.Contains('A client connected') -or $_.Contains('client disconnected') -or $_.Contains('=> disconnected') })
    Say ('  pipe events in those files : {0}' -f $pipeEvents.Count)
    Say '  --- every pipe event, verbatim and in file order - the ORDER is the finding ---'
    foreach ($pe in $pipeEvents) { Say ('      | ' + $pe) }
    $asyncCnt = @($allEng | Where-Object { $_.Contains('AsyncLogger') }).Count
    Say ('  POSCTL engine AsyncLogger lines : {0}   expected >= 1' -f $asyncCnt)
    if ($asyncCnt -lt 1) { [void]$problems.Add('engine log POSCTL empty - wrong file or wrong matcher') }

    Say ''
    Say '  --- 4b  THE AGENT COUNT - the coordinator 07:4x predicate, missing from my R1 report ---'
    Say '  this is the break point and it is visible WITHOUT traffic: the agent list comes from the'
    Say '  call centre through the adapter, never from the database, and no state filter is applied,'
    Say '  so SIGNOFF agents must appear. A count of 0, or no PUSH line at all, puts the subject in'
    Say '  the pipe; count > 0 with an empty screen puts it between the engine and the Shell.'
    $changed = @($allEng | Where-Object { $_.Contains('ChangedUnionUsersData count=') })
    $pushes  = @($allEng | Where-Object { $_.Contains('PUSH updateUserGrid') })
    $getUsrs = @($allEng | Where-Object { $_.Contains('<<getUsers unionId=') })
    $notFound= @($allEng | Where-Object { $_.Contains('not found; returning null') })
    $notInUse= @($allEng | Where-Object { $_.Contains('!union.InUse') })
    Say ('    ChangedUnionUsersData count= lines : {0}' -f $changed.Count)
    foreach ($cl in $changed) {
        $m = [regex]::Match($cl, 'count=(\d+)')
        Say ('      count = {0}   | {1}' -f $m.Groups[1].Value, $cl.Substring(0, [Math]::Min(160, $cl.Length)))
    }
    Say ('    PUSH updateUserGrid lines : {0}' -f $pushes.Count)
    foreach ($pl in $pushes) { Say ('      | ' + $pl.Substring(0, [Math]::Min(160, $pl.Length))) }
    Say ('    <<getUsers unionId= lines : {0}' -f $getUsrs.Count)
    foreach ($gl in $getUsrs) { Say ('      | ' + $gl.Substring(0, [Math]::Min(160, $gl.Length))) }
    Say ('    "not found; returning null" : {0}   expected 0 - second candidate: the union was never created' -f $notFound.Count)
    foreach ($nl in $notFound) { Say ('      | ' + $nl.Substring(0, [Math]::Min(160, $nl.Length))) }
    Say ('    "!union.InUse" : {0}   expected 0 - second candidate: union exists but is not InUse' -f $notInUse.Count)
    foreach ($ul in $notInUse) { Say ('      | ' + $ul.Substring(0, [Math]::Min(160, $ul.Length))) }
    $negEng = @($allEng | Where-Object { $_.Contains('ZZZ-this-string-cannot-occur-ZZZ') }).Count
    Say ('    NEGCTL impossible string in the engine stream : {0}   expected 0' -f $negEng)
    if ($negEng -ne 0) { [void]$problems.Add('engine NEGCTL matched - the matcher is wrong') }
    Say '    NOTE: these four counts are REPORTED, not gated. Which of them is a failure depends on'
    Say '    the branch, and naming a gate here would let me sign off my own reading. The coordinator'
    Say '    checks the Agent Grid screen himself.'
}

Say ''
Say '===== 5  services and whether the adapter holds a pipe handle right now ====='
foreach ($svcName in @('RTMService','RTMTwilio_1')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) { Say ('  {0} : {1}   expected Running' -f $svcName, $svc.Status) }
    else { Say ('  {0} : NOT FOUND' -f $svcName); [void]$problems.Add($svcName + ' not found') }
    if ($svc -and "$($svc.Status)" -ne 'Running') { [void]$problems.Add($svcName + ' is not Running') }
}
$pipes = @(Get-ChildItem '\\.\pipe\' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'RTM' })
Say ('  named pipes whose name contains RTM : {0}   expected >= 1' -f $pipes.Count)
foreach ($p in $pipes) { Say ('      | ' + $p.Name) }
if ($pipes.Count -lt 1) { [void]$problems.Add('no RTM named pipe present') }
$twProc = @(Get-Process -Name 'RTM.Twilio' -ErrorAction SilentlyContinue)
Say ('  RTM.Twilio processes : {0}   expected 1' -f $twProc.Count)
foreach ($tp in $twProc) {
    Say ('      pid {0}   started {1}   expected to be after the mark' -f $tp.Id, $tp.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))
}

Say ''
Say '===== verdict ====='
Say ('  problems recorded : {0}' -f $problems.Count)
foreach ($pr in $problems) { Say ('    - ' + $pr) }
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector was clobbered'; exit 1 }
Fin ($problems.Count -eq 0)
