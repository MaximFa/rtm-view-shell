#Requires -Version 5.1
<#
  PROBE 234 / health-local   -   READ ONLY. Starts nothing, stops nothing, changes nothing.
  WHY : /health is still unmeasured. Two attempts failed for reasons that were about the ROUTE,
        not about the application:
          - http://127.0.0.1:5000/health answered HTTP 307 - a redirect to https, i.e. the app
            is alive and doing what it is configured to do;
          - https://insightense.com:8444/health timed out - from this machine that name resolves
            outward and does not come back in. A network fact, not an application fact.
        So we ask locally, several ways, and report each attempt separately. A red light from an
        instrument pointed at the wrong door is not a red light for the application.
  CERTIFICATE : validation is bypassed for these requests and that is stated in the report. We
        are asking whether the app ANSWERS, not whether the chain validates from here.
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_health-local.txt"
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
Say "===== how the name resolves from HERE - the reason the last attempt timed out ====="
try {
    $dns = @([System.Net.Dns]::GetHostAddresses("insightense.com") | ForEach-Object { $_.IPAddressToString })
    Say ("  insightense.com -> {0}" -f ($dns -join ", "))
    Say  "  (the machine's own address is 10.0.0.4 - if the name points elsewhere, a request to it"
    Say  "   leaves the host and does not come back)"
} catch { Say ("  resolution failed: {0}" -f $_.Exception.Message) }

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$old = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
Say ""
Say "  NOTE: certificate validation is bypassed for every request below, deliberately."

$results = @{}
function Try-Url([string]$label, [string]$url, [hashtable]$headers) {
    Say ""
    Say ("  --- {0} ---" -f $label)
    Say ("      {0}" -f $url)
    try {
        if ($headers) { $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -Headers $headers }
        else          { $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 }
        $body = "$($r.Content)".Trim()
        Say ("      HTTP {0}" -f $r.StatusCode)
        Say ("      body : {0}" -f $body.Substring(0, [Math]::Min(120, $body.Length)))
        $script:results[$label] = [int]$r.StatusCode
        return [int]$r.StatusCode
    } catch {
        $resp = $_.Exception.Response
        if ($resp) {
            Say ("      HTTP {0}" -f [int]$resp.StatusCode)
            $script:results[$label] = [int]$resp.StatusCode
            return [int]$resp.StatusCode
        }
        Say ("      FAILED: {0}" -f $_.Exception.Message)
        $script:results[$label] = -1
        return -1
    }
}

Say ""
Say "===== /health, asked locally, several ways ====="
[void](Try-Url "https loopback"      "https://127.0.0.1:8444/health" $null)
[void](Try-Url "https localhost"     "https://localhost:8444/health" $null)
[void](Try-Url "https own address"   "https://10.0.0.4:8444/health"  $null)
[void](Try-Url "https loopback, Host header of the real name" "https://127.0.0.1:8444/health" @{ Host = "insightense.com" })
[void](Try-Url "http loopback (expect a redirect, that is fine)" "http://127.0.0.1:5000/health" $null)

Say ""
Say "===== NEGATIVE CONTROL - a path that must NOT return 200 ====="
[void](Try-Url "nonexistent path" "https://127.0.0.1:8444/zzz-no-such-endpoint" $null)

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $old

Say ""
Say "===== verdict ====="
$ok200 = @($results.GetEnumerator() | Where-Object { $_.Value -eq 200 -and $_.Key -ne 'nonexistent path' })
Say ("  attempts answering 200 : {0}" -f $ok200.Count)
foreach ($k in $ok200) { Say ("      {0}" -f $k.Key) }
$negVal = $results['nonexistent path']
Say ("  the nonexistent path returned : {0}   (200 here would void every result above)" -f $negVal)
$healthOk = ($ok200.Count -gt 0 -and $negVal -ne 200)

$rtmCfg = "C:\RTMView\RTM\appsettings.json"
$pipeName = ([regex]::Match([IO.File]::ReadAllText($rtmCfg), '"PipeName"\s*:\s*"([^"]*)"')).Groups[1].Value
$pipeOk = (@([System.IO.Directory]::GetFiles("\\.\pipe\") | Where-Object { $_ -like "*$pipeName*" }).Count -gt 0)
Say ""
Say ("  /health 200 (locally) : {0}" -f $healthOk)
Say ("  pipe '{0}' served     : {1}" -f $pipeName, $pipeOk)
Say ("  LIVENESS (the pair)   : {0}" -f ($healthOk -and $pipeOk))

Say ""
Say "===== END-OF-RUN MARKER: HEALTH-LOCAL-COMPLETE ====="
Say ""
Say "NOTHING WAS STARTED, STOPPED OR CHANGED."
Fin ($healthOk -and $pipeOk)
