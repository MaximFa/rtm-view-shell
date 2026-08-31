#Requires -Version 5.1
<#  R7a - READ-ONLY reconnaissance of the DEV stand before any service work.
    Answers: what the services actually run, from where, on which ports, which build,
    and what the current connection strings are (to be restored later, verbatim).
    Changes NOTHING. Authored by devops-0829, 2026-08-30.
#>
$ErrorActionPreference = "Continue"
chcp 65001 > $null

Write-Host "===== services =====" -ForegroundColor Cyan
Get-Service RTMViewShell,RTMService,'RTM.Twilio' -ErrorAction SilentlyContinue |
    Select-Object Name,Status,StartType | Format-Table -AutoSize

Write-Host "===== service binaries (binPath) =====" -ForegroundColor Cyan
foreach ($svc in @("RTMViewShell","RTMService")) {
    $p = (Get-CimInstance Win32_Service -Filter "Name='$svc'" -ErrorAction SilentlyContinue).PathName
    "{0,-14} {1}" -f $svc, $p
}

Write-Host "===== deployed build vs package build =====" -ForegroundColor Cyan
foreach ($f in @("C:\RTMView\Shell\CcDashboard.Web.exe","D:\RTMView-Ops\rehearsal\pkg\Shell\CcDashboard.Web.exe")) {
    if (Test-Path $f) {
        $i = Get-Item $f
        "{0}`n    size {1}  modified {2}  version {3}" -f $f, $i.Length, $i.LastWriteTime, $i.VersionInfo.FileVersion
    } else { "$f : NOT FOUND" }
}

Write-Host "===== connection strings (to be restored verbatim later; password masked) =====" -ForegroundColor Cyan
foreach ($f in @("C:\RTMView\Shell\appsettings.json","C:\RTMView\RTM\appsettings.json")) {
    if (Test-Path $f) {
        "--- $f"
        (Get-Content $f -Raw) -split "`n" | Select-String -Pattern 'Host=' |
            ForEach-Object { ($_ -replace 'Password=[^;"]*','Password=***').Trim() }
    } else { "$f : NOT FOUND" }
}

Write-Host "===== listening ports / Kestrel config =====" -ForegroundColor Cyan
foreach ($f in @("C:\RTMView\Shell\appsettings.json")) {
    if (Test-Path $f) {
        $j = Get-Content $f -Raw | ConvertFrom-Json
        if ($j.Kestrel) { $j.Kestrel | ConvertTo-Json -Depth 6 }
        if ($j.Urls)    { "Urls: " + $j.Urls }
    }
}
Write-Host "--- actual listeners of the shell process ---"
$pid1 = (Get-CimInstance Win32_Service -Filter "Name='RTMViewShell'" -ErrorAction SilentlyContinue).ProcessId
if ($pid1) { Get-NetTCPConnection -State Listen -OwningProcess $pid1 -ErrorAction SilentlyContinue |
             Select-Object LocalAddress,LocalPort | Format-Table -AutoSize }
else { "RTMViewShell has no running process id" }

Write-Host "===== probe (a): [PROBE PR234-1a] markers in the DEPLOYED tree and in the PACKAGE =====" -ForegroundColor Cyan
foreach ($d in @("C:\RTMView\Shell","D:\RTMView-Ops\rehearsal\pkg\Shell")) {
    if (Test-Path $d) {
        $n = (Get-ChildItem $d -Recurse -Include *.dll,*.exe -ErrorAction SilentlyContinue |
              Select-String -Pattern "PROBE PR234-1a" -List -ErrorAction SilentlyContinue).Count
        "{0,-45} markers: {1}" -f $d, $n
    }
}
Write-Host "===== R7a done (nothing changed) ====="
