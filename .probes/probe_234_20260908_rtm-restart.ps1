#Requires -Version 5.1
<#
  PROBE 234 / rtm-restart   -   restarts RTMService so it picks up the adapter.
  WHERE IT RUNS : server 234 (G0 exits, it does not warn).
  SAFETY        : without -Proceed it ONLY reads and prints.
  WHY           : RTM started 02:20:38 and logged
                    "Service 'RTMTwilio_1' not found on this machine - skipped (non-fatal)"
                  The adapter was registered at 02:32:13 - eleven minutes later. Both services
                  are Running, but "running" and "connected" are different facts. The engine
                  raises the adapter itself at startup, so restarting RTM should establish it.
  THE PREDICATE : the line about RTMTwilio_1 in the engine log MUST BECOME DIFFERENT.
                  If it stays "not found", the restart did not solve the task - that is a
                  finding, not a failure of the probe, and it is reported as such.
  NEVER TOUCHED : production RTM.Twilio and legacy RTM - recorded before and after, compared.
#>
param([switch]$Proceed)

$ErrorActionPreference = "Continue"
$OutDir  = "C:\RTMView-Ops\output"
$RtmLog  = "C:\RTMView\RTM\Logs\RTM.log"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_rtm-restart.txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function CurlGet([string]$url, [string]$extra) {
    $curl = "$env:SystemRoot\System32\curl.exe"
    if (-not (Test-Path $curl)) { return "<curl absent>" }
    if ($extra -eq 'body') { $o = & $curl -s -k --max-time 15 $url 2>&1 }
    else { $o = & $curl -s -k -o NUL -w "%{http_code}" --max-time 15 $url 2>&1 }
    return (($o | ForEach-Object { "$_" }) -join " ").Trim()
}
function PipeServed([string]$name) {
    return (@([System.IO.Directory]::GetFiles("\\.\pipe\") | Where-Object { $_ -like "*$name*" }).Count -gt 0)
}

Say ("mode : {0}" -f $(if ($Proceed) { "RESTART (-Proceed given)" } else { "PREVIEW ONLY - nothing will be restarted" }))
Say ""
Say "===== G0 ====="
$n = ($env:COMPUTERNAME -eq "RTM")
$u = ("$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper() -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  name {0} / uuid {1}" -f $n, $u)
if (-not ($n -and $u)) { Say "  *** not server 234"; Fin $false }
Say "  G0 PASS"

$pipeName = ([regex]::Match([IO.File]::ReadAllText("C:\RTMView\RTM\appsettings.json"), '"PipeName"\s*:\s*"([^"]*)"')).Groups[1].Value

Say ""
Say "===== BEFORE ====="
$prodBefore = @{}
foreach ($nm in @('RTMViewShell','RTMService','RTMTwilio_1','RTM.Twilio','RTM')) {
    $s = Get-Service -Name $nm -ErrorAction SilentlyContinue
    $w = Get-WmiObject Win32_Service -Filter "Name='$nm'" -ErrorAction SilentlyContinue
    $st = $(if ($s) { "$($s.Status)" } else { "not registered" })
    $prodBefore[$nm] = $st
    Say ("  {0,-16} {1,-14} pid {2}" -f $nm, $st, $(if ($w -and $w.ProcessId) { $w.ProcessId } else { "-" }))
}
Say ("  pipe '{0}' served : {1}" -f $pipeName, (PipeServed $pipeName))
Say ("  /health : {0}" -f (CurlGet "https://127.0.0.1:8444/health" ""))

Say ""
Say "===== the line the restart must change ====="
if (-not (Test-Path $RtmLog)) { Say ("  *** log absent: {0}" -f $RtmLog); Fin $false }
$logSizeBefore = (Get-Item $RtmLog).Length
$adapterLines = @(Get-Content $RtmLog -ErrorAction SilentlyContinue | Where-Object { $_ -match 'RTMTwilio_1' })
Say ("  log size before : {0} bytes" -f $logSizeBefore)
Say ("  lines mentioning RTMTwilio_1 : {0}" -f $adapterLines.Count)
foreach ($ln in ($adapterLines | Select-Object -Last 5)) { Say ("      {0}" -f $ln) }
$notFoundBefore = @($adapterLines | Where-Object { $_ -match 'not found on this machine' }).Count
Say ("  of them, 'not found on this machine' : {0}" -f $notFoundBefore)
Say ("  NEGCTL lines mentioning a service that cannot exist : {0}   (must be 0)" -f @(Get-Content $RtmLog -ErrorAction SilentlyContinue | Where-Object { $_ -match 'ZZZNoSuchSvc' }).Count)

if (-not $Proceed) {
    Say ""
    Say "PREVIEW ONLY. Nothing was restarted. Run again with -Proceed."
    Fin $true
}
if (-not $Proceed) { Say "*** SENTINEL: reached the restart without -Proceed."; Fin $false }

Say ""
Say "===== RESTARTING RTMService - the engine raises the adapter itself at startup ====="
Stop-Service -Name RTMService -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 4
$s1 = Get-Service -Name RTMService -ErrorAction SilentlyContinue
Say ("  stopped : {0}" -f $s1.Status)
if ($s1.Status -ne 'Stopped') { Say "  *** did not stop - report"; Fin $false }
Start-Service -Name RTMService -ErrorAction SilentlyContinue
Say "  started, waiting 25s for the engine to come up and act on the adapter..."
Start-Sleep -Seconds 25
$s2 = Get-Service -Name RTMService -ErrorAction SilentlyContinue
Say ("  RTMService : {0}" -f $s2.Status)
if ($s2.Status -ne 'Running') { Say "  *** did not start - report, do not retry blindly" }

Say ""
Say "===== THE PREDICATE - what the engine says about the adapter NOW ====="
$logSizeAfter = (Get-Item $RtmLog).Length
Say ("  log size after : {0} bytes   (grew by {1})" -f $logSizeAfter, ($logSizeAfter - $logSizeBefore))
$after = @(Get-Content $RtmLog -ErrorAction SilentlyContinue | Where-Object { $_ -match 'RTMTwilio_1' })
$new = @($after | Select-Object -Skip $adapterLines.Count)
Say ("  NEW lines mentioning RTMTwilio_1 since the restart : {0}" -f $new.Count)
foreach ($ln in $new) { Say ("      {0}" -f $ln) }
$stillNotFound = @($new | Where-Object { $_ -match 'not found on this machine' }).Count
Say ""
Say ("  new lines saying 'not found on this machine' : {0}" -f $stillNotFound)
if ($new.Count -eq 0) {
    Say "  *** the engine said NOTHING about the adapter this time - the line did not change because"
    Say "      it was not written at all. That is a finding: report it, do not retry blindly."
} elseif ($stillNotFound -gt 0) {
    Say "  *** THE LINE IS STILL 'not found' - the restart did NOT solve the task."
    Say "      A finding, not a probe failure. Report it."
} else {
    Say "  the line CHANGED - the engine now sees the adapter."
}

Say ""
Say "===== AFTER - liveness re-taken, both halves ====="
Say ("  pipe '{0}' served : {1}" -f $pipeName, (PipeServed $pipeName))
Say ("  /health          : {0}" -f (CurlGet "https://127.0.0.1:8444/health" ""))
Say ("  /health body     : {0}" -f (CurlGet "https://127.0.0.1:8444/health" "body"))
Say ("  NEGCTL /zzz      : {0}   (must not be 200)" -f (CurlGet "https://127.0.0.1:8444/zzz-no-such-endpoint" ""))

Say ""
Say "===== the untouchables, compared ====="
foreach ($nm in @('RTMViewShell','RTMService','RTMTwilio_1','RTM.Twilio','RTM')) {
    $s = Get-Service -Name $nm -ErrorAction SilentlyContinue
    $st = $(if ($s) { "$($s.Status)" } else { "not registered" })
    $mark = ""
    if ($nm -in @('RTM.Twilio','RTM')) { $mark = $(if ($st -eq $prodBefore[$nm]) { "unchanged" } else { "*** CHANGED - report" }) }
    Say ("  {0,-16} before {1,-14} after {2,-14} {3}" -f $nm, $prodBefore[$nm], $st, $mark)
}

Say ""
Say "===== last 15 lines of the engine log ====="
foreach ($t in @(Get-Content $RtmLog -Tail 15 -ErrorAction SilentlyContinue)) { Say ("      {0}" -f $t) }

Say ""
Say "===== END-OF-RUN MARKER: RTM-RESTART-COMPLETE ====="
Fin $true
