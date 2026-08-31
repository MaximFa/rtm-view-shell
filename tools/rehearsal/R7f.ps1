#Requires -Version 5.1
<#  R7f - two facts, read-only:
      1) which tenant slugs exist in the rehearsal DB, and what DefaultTenantSlug the deployed Shell uses
      2) whether the DEPLOYED binaries really are the package build (hash comparison, not dates)
    Authored by devops-0829, 2026-08-30.
#>
$ErrorActionPreference = "Continue"
chcp 65001 > $null
$pg    = "C:\Program Files\PostgreSQL\18\bin"
$shell = "C:\RTMView\Shell"
$rtm   = "C:\RTMView\RTM"
$pkg   = "D:\RTMView-Ops\rehearsal\pkg"

Write-Host "===== 1a. DefaultTenantSlug in the deployed config =====" -ForegroundColor Cyan
foreach ($f in @("$shell\appsettings.json","$shell\appsettings.Production.json")) {
    if (Test-Path $f) {
        $hit = Select-String -Path $f -Pattern "DefaultTenantSlug|TenantSlug"
        if ($hit) { $hit | ForEach-Object { "{0}: {1}" -f (Split-Path $f -Leaf), $_.Line.Trim() } }
        else { "{0}: no DefaultTenantSlug key" -f (Split-Path $f -Leaf) }
    }
}

Write-Host "===== 1b. tenants + users in the rehearsal DB =====" -ForegroundColor Cyan
$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
$env:PGCLIENTENCODING = "UTF8"
$q = @'
\echo --- tenants ---
SELECT "Id", "Slug", "Name", "IsActive" FROM public.tenants ORDER BY "Slug";
\echo --- users per tenant (no secrets shown) ---
SELECT t."Slug", u."UserName", u."IsActive", u."LockoutEnd" IS NOT NULL AS locked
  FROM identity.users u LEFT JOIN public.tenants t ON t."Id" = u."TenantId"
 ORDER BY 1,2 LIMIT 30;
'@
$f1 = Join-Path $env:TEMP "r7f.sql"
[System.IO.File]::WriteAllText($f1, $q, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d rtmviewdb_reh -f $f1
$env:PGPASSWORD = ""

Write-Host "===== 2. deployed vs package - by HASH, not by date =====" -ForegroundColor Cyan
$pairs = @(
  @{ n="Shell\CcDashboard.Web.dll"; a="$shell\CcDashboard.Web.dll";              b="$pkg\Shell\CcDashboard.Web.dll" },
  @{ n="Shell\CcDashboard.Web.exe"; a="$shell\CcDashboard.Web.exe";              b="$pkg\Shell\CcDashboard.Web.exe" },
  @{ n="Shell\CcDashboard.Infrastructure.dll"; a="$shell\CcDashboard.Infrastructure.dll"; b="$pkg\Shell\CcDashboard.Infrastructure.dll" },
  @{ n="RTM\RTM.exe";               a="$rtm\RTM.exe";                            b="$pkg\RTM\RTM.exe" }
)
foreach ($p in $pairs) {
    if ((Test-Path $p.a) -and (Test-Path $p.b)) {
        $ha = (Get-FileHash $p.a -Algorithm SHA256).Hash
        $hb = (Get-FileHash $p.b -Algorithm SHA256).Hash
        "{0,-40} {1}" -f $p.n, $(if ($ha -eq $hb) { "IDENTICAL to package" } else { "DIFFERS from package" })
    } else { "{0,-40} missing on one side (deployed:{1} package:{2})" -f $p.n, (Test-Path $p.a), (Test-Path $p.b) }
}
Write-Host "--- what the package actually contains at top level ---"
Get-ChildItem $pkg | Select-Object Name | Format-Table -AutoSize
Write-Host "===== R7f done (nothing changed) ====="
