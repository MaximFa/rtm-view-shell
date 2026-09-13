#Requires -Version 5.1
<#
  PROBE 234 / health-local-2   -   READ ONLY. Starts nothing, stops nothing, changes nothing.
  WHY : the previous probe failed ALL six attempts with the same message, including the plain
        http request that had answered HTTP 307 seventeen minutes earlier. When a check suddenly
        stops seeing what it just saw, there are two possibilities and they must not be guessed
        between:
          (1) the machine changed - the app fell over;
          (2) the INSTRUMENT changed - that probe set TLS options globally on its own process,
              and those settings can break every request it then makes, http included.
        So this one measures in order of increasing assumption, and each layer stands alone:
          A. services and ports - is anything listening at all;
          B. a raw TCP connect - is the socket accepting, no TLS, no HTTP;
          C. HTTP by an EXTERNAL process (curl.exe) - not affected by anything this script sets;
          D. HTTP from PowerShell, LAST, and only in a child process so its settings die with it.
        A layer that fails tells you which layer broke. Six identical failures tell you nothing.
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_health-local-2.txt"
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
Say "===== A  services and processes - did anything fall over since 02:40 ====="
foreach ($nm in @('RTMViewShell','RTMService','RTMTwilio_1')) {
    $s = Get-Service -Name $nm -ErrorAction SilentlyContinue
    $w = Get-WmiObject Win32_Service -Filter "Name='$nm'" -ErrorAction SilentlyContinue
    Say ("  {0,-16} {1,-10} pid {2}" -f $nm, $(if ($s) { $s.Status } else { "not registered" }), $(if ($w) { $w.ProcessId } else { "-" }))
}
foreach ($pn in @('CcDashboard.Web','RTM','RTM.Twilio')) {
    $ps = @(Get-Process -Name $pn -ErrorAction SilentlyContinue)
    foreach ($p in $ps) {
        Say ("  process {0,-20} pid {1,-8} started {2}   path {3}" -f $p.ProcessName, $p.Id, $p.StartTime, $p.Path)
    }
}

Say ""
Say "===== B  raw TCP - is the socket accepting at all (no TLS, no HTTP) ====="
foreach ($p in @(5000, 8444, 8088)) {
    $listen = @(Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue)
    Say ("  port {0} : listeners {1}" -f $p, $listen.Count)
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $c.BeginConnect("127.0.0.1", $p, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(5000, $false)
        if ($ok -and $c.Connected) { Say ("      TCP connect to 127.0.0.1:{0} : OPEN" -f $p) }
        else { Say ("      TCP connect to 127.0.0.1:{0} : refused/timeout" -f $p) }
    } catch { Say ("      TCP connect to 127.0.0.1:{0} : {1}" -f $p, $_.Exception.Message) }
    finally { $c.Close() }
}
$cn = New-Object System.Net.Sockets.TcpClient
try {
    $iar2 = $cn.BeginConnect("127.0.0.1", 5098, $null, $null)
    $ok2 = $iar2.AsyncWaitHandle.WaitOne(3000, $false)
    Say ("  NEGCTL TCP connect to a free port 5098 : {0}   (must be closed)" -f $(if ($ok2 -and $cn.Connected) { "OPEN - unexpected" } else { "closed" }))
} catch { Say "  NEGCTL TCP connect to 5098 : closed" } finally { $cn.Close() }

Say ""
Say "===== C  HTTP by an EXTERNAL process - immune to anything this script sets ====="
$curl = "$env:SystemRoot\System32\curl.exe"
if (-not (Test-Path $curl)) { Say "  curl.exe not present - skipping this layer, and saying so rather than pretending" }
else {
    foreach ($t in @(
        @{ n='http  5000 /health';  a=@('-s','-o','NUL','-w','%{http_code}','--max-time','15','http://127.0.0.1:5000/health') },
        @{ n='https 8444 /health';  a=@('-s','-k','-o','NUL','-w','%{http_code}','--max-time','15','https://127.0.0.1:8444/health') },
        @{ n='https 8444 body';     a=@('-s','-k','--max-time','15','https://127.0.0.1:8444/health') },
        @{ n='NEGCTL https 8444 /zzz'; a=@('-s','-k','-o','NUL','-w','%{http_code}','--max-time','15','https://127.0.0.1:8444/zzz-no-such-endpoint') }
    )) {
        $out = & $curl @($t.a) 2>&1
        Say ("  {0,-24} -> {1}" -f $t.n, (($out | ForEach-Object { "$_" }) -join " ").Trim())
    }
}

Say ""
Say "===== D  HTTP from PowerShell, in a CHILD process so its settings cannot leak ====="
$child = @'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
try { $r = Invoke-WebRequest -Uri 'https://127.0.0.1:8444/health' -UseBasicParsing -TimeoutSec 20; "HTTP " + [int]$r.StatusCode + " | " + ("$($r.Content)").Trim() }
catch { if ($_.Exception.Response) { "HTTP " + [int]$_.Exception.Response.StatusCode } else { "FAILED: " + $_.Exception.Message } }
'@
$tmp = Join-Path $env:TEMP ("hc_" + [guid]::NewGuid().ToString("N") + ".ps1")
[IO.File]::WriteAllText($tmp, $child, (New-Object System.Text.UTF8Encoding($true)))
$res = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tmp 2>&1
Say ("  child process says : {0}" -f (($res | ForEach-Object { "$_" }) -join " ").Trim())
Remove-Item $tmp -ErrorAction SilentlyContinue

Say ""
Say "===== E  the log, to see whether the app complained in the meantime ====="
foreach ($d in @("C:\RTMView\Shell\Logs","C:\RTMView\RTM\Logs")) {
    if (-not (Test-Path $d)) { continue }
    foreach ($f in @(Get-ChildItem $d -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1)) {
        Say ("  --- {0}  ({1} bytes, {2}) ---" -f $f.Name, $f.Length, $f.LastWriteTime)
        foreach ($t in @(Get-Content $f.FullName -Tail 10 -ErrorAction SilentlyContinue)) { Say ("      {0}" -f $t) }
    }
}

Say ""
Say "===== END-OF-RUN MARKER: HEALTH-LOCAL-2-COMPLETE ====="
Say ""
Say "NOTHING WAS STARTED, STOPPED OR CHANGED."
Fin $true
