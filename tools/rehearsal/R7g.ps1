#Requires -Version 5.1
<#  R7g - add DefaultTenantSlug=platform to the DEV Shell config so the tenant resolves on bare localhost,
    restart the service, confirm health. Config is restored wholesale from the stand backup later.
    Authored by devops-0829, 2026-08-30.
#>
$ErrorActionPreference = "Continue"
chcp 65001 > $null
$f = "C:\RTMView\Shell\appsettings.json"

Write-Host "===== before =====" -ForegroundColor Cyan
if (Select-String -Path $f -Pattern "DefaultTenantSlug") { "key already present:"; Select-String -Path $f -Pattern "DefaultTenantSlug" | ForEach-Object { "  " + $_.Line.Trim() } }
else { "DefaultTenantSlug: absent" }

$txt = [System.IO.File]::ReadAllText($f)
if ($txt -notmatch '"DefaultTenantSlug"') {
    $i = $txt.IndexOf("{")
    if ($i -lt 0) { Write-Host "STOP: not a JSON object" -ForegroundColor Red; exit 1 }
    $new = $txt.Insert($i + 1, "`r`n  ""DefaultTenantSlug"": ""platform"",")
    [System.IO.File]::WriteAllText($f, $new, (New-Object System.Text.UTF8Encoding($false)))
    "inserted DefaultTenantSlug = platform"
} else { "already set - not touching" }

Write-Host "===== JSON must still parse (a broken config would fail the service silently at start) =====" -ForegroundColor Cyan
try { $null = Get-Content $f -Raw | ConvertFrom-Json; "JSON parses OK" }
catch { Write-Host "STOP: JSON broken: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
Get-Content $f -TotalCount 4

Write-Host "===== restart Shell =====" -ForegroundColor Cyan
Restart-Service RTMViewShell -Force
Start-Sleep -Seconds 20
Get-Service RTMViewShell | Select-Object Name,Status | Format-Table -AutoSize

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
try { $r = Invoke-WebRequest -Uri "https://localhost:5239/health" -TimeoutSec 20 -UseBasicParsing
      "health -> HTTP {0} : {1}" -f $r.StatusCode, $r.Content }
catch { "health FAILED: {0}" -f $_.Exception.Message }

Write-Host ""
Write-Host "Now open  https://localhost:5239  and sign in as  admin  (tenant platform)." -ForegroundColor Yellow
Write-Host "If the password is unknown, say so - I can reset it IN THE REHEARSAL COPY only." -ForegroundColor Yellow
Write-Host "===== R7g done ====="
