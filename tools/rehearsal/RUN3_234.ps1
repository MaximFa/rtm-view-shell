#Requires -Version 5.1
#Requires -RunAsAdministrator
<#  RUN 3 on server 234 - CLEAN INSTALL from the package, exactly as a new server would get,
    pointed at the ALREADY-PREPARED database on port 5433.
    - Does NOT touch: PostgreSQL 15 on 5432 (rollback), Garnet, RTM.Twilio, legacy.
    - Does NOT create/modify any database (-SkipDB): rtmviewdb on 5433 is ready from RUN 1/2.
    - Secrets are read from the CURRENT on-box config and never printed.
    Authored by devops-0829, 2026-08-30.
#>
$ErrorActionPreference = "Stop"
chcp 65001 > $null
$pkg   = "C:\Temp\conv234"
$shell = "C:\RTMView\Shell"
$rtm   = "C:\RTMView\RTM"
$ts    = Get-Date -Format "yyyyMMdd_HHmmss"
$bak   = "C:\RTMView\Backup\preinstall_$ts"

Write-Host "===== 1. read CURRENT parameters from the box (nothing printed) =====" -ForegroundColor Cyan
$sJson = Get-Content "$shell\appsettings.json" -Raw
$rJson = Get-Content "$rtm\appsettings.json"   -Raw
$dbPw    = ([regex]::Match($sJson,'Password=([^;"]+)')).Groups[1].Value
$redisPw = ([regex]::Match($sJson,'(?i)localhost:6379,\s*password=([^"]+)')).Groups[1].Value
$superPw = ([regex]::Match($sJson,'(?i)"SuperadminPassword"\s*:\s*"([^"]*)"')).Groups[1].Value
$tenant  = ([regex]::Match($rJson,'"TenantId"\s*:\s*"([^"]+)"')).Groups[1].Value
$pipe    = ([regex]::Match($rJson,'"PipeName"\s*:\s*"([^"]+)"')).Groups[1].Value
$adaptor = ([regex]::Match($rJson,'"AdaptorServiceName"\s*:\s*"([^"]+)"')).Groups[1].Value
"  db password      : {0} chars" -f $dbPw.Length
"  redis password   : {0} chars" -f $redisPw.Length
"  superadmin pw    : {0} chars" -f $superPw.Length
"  tenant / pipe    : {0} / {1}" -f $tenant, $pipe
"  adaptor service  : {0}" -f $adaptor
if (-not $dbPw)    { Write-Host "STOP: DB password not found in config" -ForegroundColor Red; exit 1 }
if (-not $redisPw) { Write-Host "STOP: Redis password not found in config" -ForegroundColor Red; exit 1 }
if (-not $tenant -or -not $pipe) { Write-Host "STOP: RTM TenantId/PipeName not found" -ForegroundColor Red; exit 1 }

Write-Host "===== 2. backup current install (binaries + configs) =====" -ForegroundColor Cyan
New-Item -ItemType Directory $bak -Force | Out-Null
Copy-Item $shell "$bak\Shell" -Recurse -Force
Copy-Item $rtm   "$bak\RTM"   -Recurse -Force
"  backup: $bak  (Shell {0} files, RTM {1} files)" -f (Get-ChildItem "$bak\Shell" -Recurse -File).Count, (Get-ChildItem "$bak\RTM" -Recurse -File).Count

Write-Host "===== 3. CLEAN INSTALL from package -> DB on 5433 =====" -ForegroundColor Yellow
Write-Host "      Garnet: NOT touched (-SkipRedis).  DB: NOT touched (-SkipDB).  5432: untouched." -ForegroundColor Yellow
$startedAt = Get-Date
& powershell -ExecutionPolicy Bypass -File "$pkg\Install-RTMView.ps1" `
    -Mode Full `
    -SkipDB -SkipRedis `
    -InstallRoot "C:\RTMView" `
    -DBHost "localhost" -DBPort 5433 -DBName "rtmviewdb" `
    -DBAppUser "ccdashboard_user" -DBAppPassword $dbPw `
    -RedisPassword $redisPw `
    -SuperadminPassword $superPw `
    -ShellPort 5000 -RTMPort 8089 -ShellHttpsPort 8444 `
    -Fqdn "insightense.com" -CertSubject "insightense.com" `
    -RTMPipeName $pipe -RTMTenantId $tenant -AdaptorServiceName $adaptor
"install exit code: $LASTEXITCODE"

Write-Host "===== 4. what the installed config actually says =====" -ForegroundColor Cyan
(Get-Content "$shell\appsettings.json" -Raw) -split "`n" | Select-String -Pattern 'Port=|Url|Subject|DefaultTenantSlug|REPLACE_' |
    ForEach-Object { "  " + (($_ -replace 'Password=[^;"]*','Password=***').Trim()) }
(Get-Content "$rtm\appsettings.json" -Raw) -split "`n" | Select-String -Pattern 'Port=|PipeName|TenantId|REPLACE_' |
    ForEach-Object { "  " + (($_ -replace 'Password=[^;"]*','Password=***').Trim()) }
if ((Get-Content "$shell\appsettings.json" -Raw) -match 'REPLACE_') { Write-Host "  ⛔ REPLACE_ placeholder left in Shell config - STOP" -ForegroundColor Red }

Write-Host "===== 5. services =====" -ForegroundColor Cyan
Get-Service RTMViewShell,RTMService,'RTM.Twilio',Garnet -ErrorAction SilentlyContinue |
    Select-Object Name,Status,StartType | Format-Table -AutoSize
"FREE-ROLLBACK BOUNDARY (services started against 5433): {0:yyyy-MM-dd HH:mm:ss}" -f $startedAt

Write-Host "===== 6. which DB the app is attached to (expect 5433) =====" -ForegroundColor Cyan
$p18 = "C:\Program Files\PostgreSQL\18\bin"
$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
Start-Sleep -Seconds 15
& "$p18\psql.exe" -U postgres -h localhost -p 5433 -d postgres -c "SELECT datname, usename, state, count(*) FROM pg_stat_activity WHERE datname='rtmviewdb' GROUP BY 1,2,3;"
& "$p18\psql.exe" -U postgres -h localhost -p 5432 -d postgres -c "SELECT datname, usename, state, count(*) FROM pg_stat_activity WHERE datname='rtmviewdb' GROUP BY 1,2,3;"
$env:PGPASSWORD = ""

Write-Host "===== 7. /health =====" -ForegroundColor Cyan
add-type @"
using System.Net; using System.Security.Cryptography.X509Certificates;
public class TrustAll2 : ICertificatePolicy { public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; } }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
foreach ($u in @("https://localhost:8444/health","http://localhost:5000/health")) {
    try { $r = Invoke-WebRequest -Uri $u -TimeoutSec 25 -UseBasicParsing; "{0} -> HTTP {1} : {2}" -f $u, $r.StatusCode, $r.Content }
    catch { "{0} -> {1}" -f $u, $_.Exception.Message }
}

Write-Host "===== 8. probe (a): UTF-16LE marker in the deployed build =====" -ForegroundColor Cyan
$hits = 0
foreach ($f in (Get-ChildItem $shell -Recurse -Include CcDashboard*.dll -ErrorAction SilentlyContinue)) {
    $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::Unicode)
    $n = 0; $i = $text.IndexOf("PROBE PR234-1a")
    while ($i -ge 0) { $n++; $i = $text.IndexOf("PROBE PR234-1a", $i + 14) }
    if ($n -gt 0) { "  {0}: {1}" -f $f.Name, $n; $hits += $n }
}
"probe (a): $hits occurrence(s) - expect > 0"
Write-Host "===== RUN 3 done =====" -ForegroundColor Green
