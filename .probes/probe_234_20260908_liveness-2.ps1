#Requires -Version 5.1
<#
  PROBE 234 / liveness-2   -   READ ONLY. Starts nothing, stops nothing, changes nothing.
  WHY A SECOND ONE : the first liveness probe measured half the pair and blinded itself on the rest.
    (a) /health was requested at http://127.0.0.1:5000 and died on "could not establish trust
        relationship": the app redirects to HTTPS and the certificate is for insightense.com,
        which 127.0.0.1 is not. The app was not refusing - the probe was knocking at the wrong door.
        Fixed: ask BOTH the plain http endpoint without following the redirect, AND the real
        https url with the name the certificate carries.
    (b) the log search returned 0 for the predicted failure - but its POSITIVE control ("INF"
        must appear) also returned 0. A search that finds nothing at all cannot prove an absence.
        Fixed: list the log files first, with sizes; only then search, and say plainly when there
        is nothing to search.
  RULE THIS COMES FROM : a zero from an instrument whose positive control is also zero is not
        evidence of absence. It is evidence the instrument is blind.
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_liveness-2.txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}

Say "===== G0 ====="
$n = ($env:COMPUTERNAME -eq "RTM")
$u = ("$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper() -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  name {0} / uuid {1}" -f $n, $u)
if (-not ($n -and $u)) { Say "  *** not server 234"; Fin $false }
Say "  G0 PASS"

Say ""
Say "===== 1  what the deployed config says the app listens on - read FROM DISK ====="
$shellCfg = "C:\RTMView\Shell\appsettings.json"
$raw = [IO.File]::ReadAllText($shellCfg)
$urls = @([regex]::Matches($raw, '"Url"\s*:\s*"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
foreach ($u2 in $urls) { Say ("      {0}" -f $u2) }
$httpUrl = @($urls | Where-Object { $_ -like 'http://*' })[0]
$httpsUrl = @($urls | Where-Object { $_ -like 'https://*' })[0]

Say ""
Say "===== 2  which ports are actually listened on ====="
foreach ($p in @(5000, 8444, 8088)) {
    $c = @(Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue)
    if ($c.Count -eq 0) { Say ("  port {0} : nobody listening" -f $p) }
    else {
        foreach ($cn in $c) {
            $pr = Get-Process -Id $cn.OwningProcess -ErrorAction SilentlyContinue
            Say ("  port {0} : LISTEN {1} by {2}" -f $p, $cn.LocalAddress, $(if ($pr) { $pr.Path } else { "<pid gone>" }))
        }
    }
}
Say ("  NEGCTL a port nobody should hold (5098) : {0}   (must be 0)" -f @(Get-NetTCPConnection -State Listen -LocalPort 5098 -ErrorAction SilentlyContinue).Count)

Say ""
Say "===== 3  /health - asked properly this time ====="
# 3a: plain http, WITHOUT following the redirect - we want to see the redirect itself, not die on it
try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:5000/health" -UseBasicParsing -TimeoutSec 15 -MaximumRedirection 0 -ErrorAction Stop
    Say ("  http://127.0.0.1:5000/health -> HTTP {0}" -f $r.StatusCode)
} catch {
    $resp = $_.Exception.Response
    if ($resp) {
        $code = [int]$resp.StatusCode
        $loc  = $resp.Headers['Location']
        Say ("  http://127.0.0.1:5000/health -> HTTP {0}   Location: {1}" -f $code, $loc)
        Say  "      (a redirect here is the app working as configured, not a failure)"
    } else { Say ("  http://127.0.0.1:5000/health -> {0}" -f $_.Exception.Message) }
}

# 3b: the real https url, with the name the certificate carries
if ($httpsUrl) {
    $target = ($httpsUrl.TrimEnd('/')) + "/health"
    Say ("  asking {0}" -f $target)
    # accept the certificate only for THIS call, and say so out loud
    $old = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    try {
        $r2 = Invoke-WebRequest -Uri $target -UseBasicParsing -TimeoutSec 20
        $body = "$($r2.Content)".Trim()
        Say ("      HTTP {0}   body: {1}" -f $r2.StatusCode, $body.Substring(0, [Math]::Min(80, $body.Length)))
        $healthOk = ($r2.StatusCode -eq 200)
    } catch {
        Say ("      FAILED: {0}" -f $_.Exception.Message)
        $healthOk = $false
    }
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $old
    Say  "      (certificate validation was bypassed for this one request only - we are testing"
    Say  "       whether the app answers, not whether the certificate chains from this machine)"
} else { Say "  no https url in the config"; $healthOk = $false }

Say ""
Say "  NEGCTL a path that must NOT answer 200:"
$old2 = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
try {
    $r3 = Invoke-WebRequest -Uri (($httpsUrl.TrimEnd('/')) + "/zzz-no-such-endpoint") -UseBasicParsing -TimeoutSec 15
    Say ("      -> HTTP {0}   (200 here would mean the check cannot fail)" -f $r3.StatusCode)
} catch {
    $c2 = $_.Exception.Response
    Say ("      -> {0} as it should" -f $(if ($c2) { "HTTP " + [int]$c2.StatusCode } else { $_.Exception.Message }))
}
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $old2

Say ""
Say "===== 4  the pipe, again - the other half of the pair ====="
$rtmCfg = "C:\RTMView\RTM\appsettings.json"
$pipeName = ([regex]::Match([IO.File]::ReadAllText($rtmCfg), '"PipeName"\s*:\s*"([^"]*)"')).Groups[1].Value
$pipes = @([System.IO.Directory]::GetFiles("\\.\pipe\"))
$pipeOk = (@($pipes | Where-Object { $_ -like "*$pipeName*" }).Count -gt 0)
Say ("  PipeName from disk : {0}" -f $pipeName)
Say ("  served             : {0}" -f $pipeOk)
Say ("  NEGCTL impossible pipe : {0}   (must be 0)" -f @($pipes | Where-Object { $_ -like "*zzz_no_such_pipe*" }).Count)

Say ""
Say "===== 5  logs - listed BEFORE they are searched ====="
$logDirs = @("C:\RTMView\Logs","C:\RTMView\Shell\Logs","C:\RTMView\RTM\Logs","C:\RTMView\RTM.Twilio\Logs")
$all = @()
foreach ($d in $logDirs) {
    if (-not (Test-Path $d)) { Say ("  {0} : does not exist" -f $d); continue }
    $fs = @(Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue)
    Say ("  {0} : {1} files" -f $d, $fs.Count)
    foreach ($f in ($fs | Sort-Object LastWriteTime -Descending | Select-Object -First 5)) {
        Say ("      {0,-40} {1,10} bytes   {2}" -f $f.Name, $f.Length, $f.LastWriteTime)
    }
    $all += $fs
}
Say ("  log files found in total : {0}" -f $all.Count)
if ($all.Count -eq 0) {
    Say "  *** THERE ARE NO LOGS TO SEARCH. Any 'zero occurrences' below would be meaningless,"
    Say "      so nothing is searched and nothing is concluded. The engine may simply not have"
    Say "      written yet, or logs go elsewhere - that is the next question, not an answer."
} else {
    $posCtl = @($all | Select-String -Pattern 'INF|ERROR|WARN|Information' -List -ErrorAction SilentlyContinue).Count
    Say ("  POSITIVE control - files containing any log level word : {0}   (must be > 0)" -f $posCtl)
    if ($posCtl -eq 0) {
        Say "  *** the search finds nothing at all - it is BLIND. No absence is concluded from it."
    } else {
        Say ("  KeyNotFoundException          : {0}   (prediction says 0)" -f @($all | Select-String -Pattern 'KeyNotFoundException' -List -ErrorAction SilentlyContinue).Count)
        Say ("  QueueNumberOfLoggedAgents     : {0}   (removed metric; 0 expected)" -f @($all | Select-String -Pattern 'QueueNumberOfLoggedAgents' -List -ErrorAction SilentlyContinue).Count)
        Say  "  --- last 12 lines of the newest log ---"
        $newest = ($all | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
        foreach ($t in @(Get-Content $newest.FullName -Tail 12 -ErrorAction SilentlyContinue)) { Say ("      {0}" -f $t) }
    }
}

Say ""
Say "===== 6  the verdict, as a pair ====="
Say ("  /health 200 : {0}" -f $healthOk)
Say ("  pipe served : {0}" -f $pipeOk)
Say ("  LIVENESS    : {0}   (both, or it is not liveness)" -f ($healthOk -and $pipeOk))

Say ""
Say "===== END-OF-RUN MARKER: LIVENESS-2-COMPLETE ====="
Say ""
Say "NOTHING WAS STARTED, STOPPED OR CHANGED."
Fin ($healthOk -and $pipeOk)
