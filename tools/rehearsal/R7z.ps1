#Requires -Version 5.1
<#  R7z - RESTORE the DEV stand to exactly what it was before the rehearsal:
    original binaries and configs from the stand backup, services back on rtmviewdb.
    Authored by devops-0829, 2026-08-30.
#>
$ErrorActionPreference = "Continue"
chcp 65001 > $null
$bak   = "D:\RTMView-Ops\rehearsal\stand_backup_20260829_205420"
$shell = "C:\RTMView\Shell"
$rtm   = "C:\RTMView\RTM"

if (-not (Test-Path "$bak\Shell") -or -not (Test-Path "$bak\RTM")) {
    Write-Host "STOP: backup not found at $bak - do NOT proceed, report this" -ForegroundColor Red; exit 1 }
"backup found: {0}  (Shell {1} files, RTM {2} files)" -f $bak,
    (Get-ChildItem "$bak\Shell" -Recurse -File).Count, (Get-ChildItem "$bak\RTM" -Recurse -File).Count

Write-Host "===== stop services =====" -ForegroundColor Cyan
foreach ($s in @("RTMViewShell","RTMService")) { Stop-Service $s -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 3
$orph = Get-Process | Where-Object { $_.Path -like "C:\RTMView\*" }
if ($orph) { "killing orphans by path:"; $orph | Select-Object Id,Path | Format-Table -AutoSize; $orph | Stop-Process -Force; Start-Sleep 2 }
else { "no orphans under C:\RTMView" }

Write-Host "===== restore binaries + configs from backup =====" -ForegroundColor Cyan
Remove-Item "$shell\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$rtm\*"   -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item "$bak\Shell\*" $shell -Recurse -Force
Copy-Item "$bak\RTM\*"   $rtm   -Recurse -Force
"restored."

Write-Host "===== verify the restore BY HASH against the backup =====" -ForegroundColor Cyan
foreach ($p in @(@{a="$shell\CcDashboard.Web.dll"; b="$bak\Shell\CcDashboard.Web.dll"; n="Shell\CcDashboard.Web.dll"},
                 @{a="$rtm\RTM.exe";               b="$bak\RTM\RTM.exe";               n="RTM\RTM.exe"})) {
    if ((Test-Path $p.a) -and (Test-Path $p.b)) {
        $same = (Get-FileHash $p.a -Algorithm SHA256).Hash -eq (Get-FileHash $p.b -Algorithm SHA256).Hash
        "{0,-34} {1}" -f $p.n, $(if ($same) { "restored (hash matches backup)" } else { "MISMATCH - investigate" })
    }
}
Write-Host "--- connection strings must be back on rtmviewdb, and DefaultTenantSlug back to its original state ---"
foreach ($f in @("$shell\appsettings.json","$rtm\appsettings.json")) {
    (Get-Content $f -Raw) -split "`n" | Select-String -Pattern 'Host=|DefaultTenantSlug' |
        ForEach-Object { "  " + (($_ -replace 'Password=[^;"]*','Password=***').Trim()) }
}

Write-Host "===== start services =====" -ForegroundColor Cyan
foreach ($s in @("RTMService","RTMViewShell")) { Start-Service $s -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 20
Get-Service RTMViewShell,RTMService | Select-Object Name,Status | Format-Table -AutoSize

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
try { $r = Invoke-WebRequest -Uri "https://localhost:5239/health" -TimeoutSec 20 -UseBasicParsing
      "health -> HTTP {0} : {1}" -f $r.StatusCode, $r.Content } catch { "health: {0}" -f $_.Exception.Message }

Write-Host "===== which DB the restored stand is attached to (expect rtmviewdb) =====" -ForegroundColor Cyan
$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d postgres -c "SELECT datname, count(*) FROM pg_stat_activity WHERE usename='ccdashboard_user' GROUP BY 1 ORDER BY 1;"
$env:PGPASSWORD = ""

Write-Host ""
Write-Host "NOTE: the rehearsal DB rtmviewdb_reh is LEFT IN PLACE deliberately (evidence for the coordinator)." -ForegroundColor Yellow
Write-Host "      Drop it on his word:  dropdb -U postgres rtmviewdb_reh" -ForegroundColor Yellow
Write-Host "NOTE: the localhost certificate DF556BEF... stays - it fixes a real, previously parked defect." -ForegroundColor Yellow
Write-Host "===== R7z done ====="
