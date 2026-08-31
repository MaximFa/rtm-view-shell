#Requires -Version 5.1
<#  R3b - pre-migrate reconnaissance. READ-ONLY against the DB; unpacks the release package on disk.
    1) reads the CONTENT of every EF-history table so the App ledger is identified by content, not by name
    2) unpacks Installations\29082026.1119.zip to D:\RTMView-Ops\rehearsal\pkg and clears mark-of-the-web
    Authored by devops-0829, 2026-08-29.
#>
$ErrorActionPreference = "Stop"
$pg   = "C:\Program Files\PostgreSQL\18\bin"
$zip  = "D:\Claude\Projects\RTM View Shell\Installations\29082026.1119.zip"
$dest = "D:\RTMView-Ops\rehearsal\pkg"

$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

$sql = @"
\echo === public."__EFMigrationsHistory" ===
SELECT * FROM public."__EFMigrationsHistory" ORDER BY 1;
\echo === public.__ef_migrations_history ===
SELECT * FROM public.__ef_migrations_history ORDER BY 1;
\echo === audit.__ef_migrations_history ===
SELECT * FROM audit.__ef_migrations_history ORDER BY 1;
\echo === public."__BackendEmulationMigrationsHistory" ===
SELECT * FROM public."__BackendEmulationMigrationsHistory" ORDER BY 1;
\echo === signature objects for the 3 pending migrations ===
SELECT indexname, indexdef FROM pg_indexes
 WHERE schemaname='identity' AND tablename='users' ORDER BY 1;
SELECT to_regclass('public."WfmTenantSettings"') AS wfm_tenant_settings;
"@
$f = Join-Path $env:TEMP "r3b_query.sql"
[System.IO.File]::WriteAllText($f, $sql, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("query first bytes: {0}" -f (((Get-Content $f -Encoding Byte -TotalCount 3)) -join " "))
& "$pg\psql.exe" -U postgres -d rtmviewdb_reh -f $f
$env:PGPASSWORD = ""

Write-Host "===== unpack package ====="
if (-not (Test-Path $zip)) { Write-Host "STOP: package missing at $zip" -ForegroundColor Red; exit 1 }
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
New-Item -ItemType Directory $dest -Force | Out-Null
Expand-Archive -Path $zip -DestinationPath $dest -Force
Get-ChildItem $dest -Recurse -Filter *.ps1 | Unblock-File
Write-Host "unpacked to $dest ; ps1 unblocked"
Get-ChildItem $dest | Select-Object Name, Length | Format-Table -AutoSize
Write-Host "--- migrate exe present? ---"
Get-ChildItem $dest -Recurse -Filter CcDashboard.Web.exe | Select-Object -First 3 FullName
Write-Host "--- db\tools shipped? (drift-gate reachability, role-devops sC item 6) ---"
Get-ChildItem $dest -Recurse -Filter Compare-ToBaseline.ps1 | Select-Object -First 3 FullName
Write-Host "===== R3b done ====="
