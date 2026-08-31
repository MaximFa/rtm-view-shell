#Requires -Version 5.1
<#  R7b - deploy the PACKAGE build into the DEV services, point them at rtmviewdb_reh, start, verify.
    Everything changed here is backed up first and restored by R7d.
    Mirrors the Phase-P swap step (P6), so the rehearsal covers it too.
    Authored by devops-0829, 2026-08-30.
#>
$ErrorActionPreference = "Continue"
chcp 65001 > $null
$ts   = Get-Date -Format "yyyyMMdd_HHmmss"
$bak  = "D:\RTMView-Ops\rehearsal\stand_backup_$ts"
$pkg  = "D:\RTMView-Ops\rehearsal\pkg"
$shell= "C:\RTMView\Shell"
$rtm  = "C:\RTMView\RTM"

Write-Host "===== 1. BACKUP the stand (binaries + configs) =====" -ForegroundColor Cyan
New-Item -ItemType Directory $bak -Force | Out-Null
Copy-Item $shell -Destination "$bak\Shell" -Recurse -Force
Copy-Item $rtm   -Destination "$bak\RTM"   -Recurse -Force
"backup at: $bak"
"Shell files backed up: {0}" -f (Get-ChildItem "$bak\Shell" -Recurse -File).Count
"RTM   files backed up: {0}" -f (Get-ChildItem "$bak\RTM" -Recurse -File).Count

Write-Host "===== 2. STOP services + verify no orphan holds the DLLs =====" -ForegroundColor Cyan
foreach ($s in @("RTMViewShell","RTMService")) { Stop-Service $s -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 3
Get-Service RTMViewShell,RTMService | Select-Object Name,Status | Format-Table -AutoSize
$orphans = Get-Process | Where-Object { $_.Path -like "C:\RTMView\*" }
if ($orphans) { Write-Host "ORPHANS still holding files (killing by PATH, not by service name):" -ForegroundColor Yellow
                $orphans | Select-Object Id,Path | Format-Table -AutoSize
                $orphans | Stop-Process -Force; Start-Sleep -Seconds 2 }
else { "no orphan processes under C:\RTMView" }

Write-Host "===== 3. DEPLOY package binaries, PRESERVING operator config =====" -ForegroundColor Cyan
$preserveShell = @("appsettings.json","appsettings.Production.json","nlog.config")
$preserveRtm   = @("appsettings.json","data.sys","app.dat")
foreach ($f in $preserveShell) { if (Test-Path "$shell\$f") { Copy-Item "$shell\$f" "$env:TEMP\keep_shell_$f" -Force } }
foreach ($f in $preserveRtm)   { if (Test-Path "$rtm\$f")   { Copy-Item "$rtm\$f"   "$env:TEMP\keep_rtm_$f"   -Force } }
Copy-Item "$pkg\Shell\*" $shell -Recurse -Force
if (Test-Path "$pkg\RTM") { Copy-Item "$pkg\RTM\*" $rtm -Recurse -Force }
foreach ($f in $preserveShell) { if (Test-Path "$env:TEMP\keep_shell_$f") { Copy-Item "$env:TEMP\keep_shell_$f" "$shell\$f" -Force } }
foreach ($f in $preserveRtm)   { if (Test-Path "$env:TEMP\keep_rtm_$f")   { Copy-Item "$env:TEMP\keep_rtm_$f"   "$rtm\$f"   -Force } }
"deployed exe date now: {0}" -f (Get-Item "$shell\CcDashboard.Web.exe").LastWriteTime

Write-Host "===== 4. POINT the services at rtmviewdb_reh (recorded; R7d restores) =====" -ForegroundColor Cyan
foreach ($f in @("$shell\appsettings.json","$rtm\appsettings.json")) {
    $txt = Get-Content $f -Raw
    $new = $txt -replace 'Database=rtmviewdb;', 'Database=rtmviewdb_reh;'
    [System.IO.File]::WriteAllText($f, $new, (New-Object System.Text.UTF8Encoding($false)))
    "{0} -> {1}" -f $f, (($new -split "`n" | Select-String -Pattern 'Database=' | Select-Object -First 1) -replace 'Password=[^;"]*','Password=***').Trim()
}

Write-Host "===== 5. START services (prod-identical model: Windows services) =====" -ForegroundColor Cyan
foreach ($s in @("RTMService","RTMViewShell")) { Start-Service $s -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 20
Get-Service RTMViewShell,RTMService | Select-Object Name,Status | Format-Table -AutoSize

Write-Host "===== 6. /health =====" -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "https://localhost:5239/health" -SkipCertificateCheck -TimeoutSec 20
    "HTTP {0} : {1}" -f $r.StatusCode, $r.Content
} catch {
    try { $r = Invoke-WebRequest -Uri "http://localhost:5238/health" -TimeoutSec 20; "HTTP {0} : {1}" -f $r.StatusCode, $r.Content }
    catch { "health FAILED: $($_.Exception.Message)" }
}

Write-Host "===== 7. probe (a) - UTF-16LE search, the way managed strings are actually stored =====" -ForegroundColor Cyan
$needle = [System.Text.Encoding]::Unicode.GetBytes("PROBE PR234-1a")
$total = 0
Get-ChildItem $shell -Recurse -Include *.dll -ErrorAction SilentlyContinue | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    $count = 0; $i = 0
    while ($i -le $bytes.Length - $needle.Length) {
        $match = $true
        for ($j = 0; $j -lt $needle.Length; $j++) { if ($bytes[$i+$j] -ne $needle[$j]) { $match = $false; break } }
        if ($match) { $count++; $i += $needle.Length } else { $i++ }
    }
    if ($count -gt 0) { "  {0}: {1}" -f $_.Name, $count; $total += $count }
}
"probe (a) markers found in the deployed tree: $total   (source carries 11)"

Write-Host ""
Write-Host "BACKUP PATH FOR RESTORE: $bak" -ForegroundColor Yellow
Write-Host "===== R7b done =====" -ForegroundColor Green
