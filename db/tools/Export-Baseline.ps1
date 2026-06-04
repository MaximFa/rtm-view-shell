#Requires -Version 5.1
param(
    [string]$DBHost     = "localhost",
    [string]$DBPort     = "5432",
    [string]$Database   = "rtmviewdb",
    [string]$DBUser     = "ccdashboard_user",
    [string]$Password   = "",
    [string]$CommitMessage = "",
    [switch]$DryRun
)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$OutFile   = Join-Path $RepoRoot "db\baseline.sql"
$TmpSql    = [System.IO.Path]::GetTempFileName() + ".sql"

function Find-PGTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($ver in @("18","17","16","15")) {
        foreach ($base in @("C:\Program Files\PostgreSQL","C:\Program Files (x86)\PostgreSQL")) {
            $p = "$base\$ver\bin\$Name.exe"
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

$psql = Find-PGTool "psql"
if (-not $psql) { throw "psql not found." }
if ($Password) { $env:PGPASSWORD = $Password }
Write-Host "Export-Baseline: ${DBUser}@${DBHost}:${DBPort}/${Database}" -ForegroundColor Cyan

function Run-SQL([string]$sql) {
    Set-Content -Path $TmpSql -Value $sql -Encoding UTF8
    return (& $psql -h $DBHost -p $DBPort -U $DBUser -d $Database -t -A -f $TmpSql 2>&1)
}

function Export-Table([string]$table, [string]$where = "") {
    $cond = if ($where) { " WHERE $where" } else { "" }
    # Handle schema.table — quote schema and table separately
    $ref = if ($table -match "^(.+)\.(.+)$") {
        "$($Matches[1]).`"$($Matches[2])`""
    } else {
        "`"$table`""
    }
    $copySql = "COPY (SELECT * FROM $ref$cond) TO STDOUT WITH (FORMAT text)"
    Set-Content -Path $TmpSql -Value $copySql -Encoding UTF8
    $rows = (& $psql -h $DBHost -p $DBPort -U $DBUser -d $Database -t -A -f $TmpSql 2>&1)
    $dataRows = @($rows | Where-Object { $_ -and $_ -notmatch "^(ERROR|psql:)" })
    if ($dataRows.Count -gt 0) {
        $script:out += "-- $table"
        $script:out += "TRUNCATE TABLE `"$table`" RESTART IDENTITY CASCADE;"
        $script:out += "COPY `"$table`" FROM stdin;"
        $script:out += $dataRows
        $script:out += "\."
        $script:out += ""
        Write-Host "  Exported: $table ($($dataRows.Count) rows)" -ForegroundColor Gray
    } else {
        $err = @($rows | Where-Object { $_ -match "^(ERROR|psql:)" })
        if ($err) { Write-Host "  WARN $table : $($err[0])" -ForegroundColor Yellow }
        else       { Write-Host "  Empty:    $table" -ForegroundColor DarkGray }
    }
}

# Platform tenant ID (all columns PascalCase)
$r = Run-SQL "SELECT `"Id`" FROM tenants WHERE `"Slug`" = 'platform' LIMIT 1;"
$platformId = ($r | Where-Object { $_ -match "^[0-9a-f-]{36}$" } | Select-Object -First 1)
if (-not $platformId) { throw "Platform tenant not found. Raw: $r" }
$platformId = $platformId.Trim()
Write-Host "Platform tenant: $platformId" -ForegroundColor Gray

# Superadmin user ID (identity tables: PascalCase columns)
$saSql = @"
SELECT u."Id"
FROM identity.users u
JOIN identity.user_roles ur ON u."Id" = ur."UserId"
JOIN identity.roles r ON ur."RoleId" = r."Id"
WHERE r."NormalizedName" = 'SUPERADMIN'
LIMIT 1;
"@
$saRows = Run-SQL $saSql
$saId = ($saRows | Where-Object { $_ -match "^[0-9a-f-]{36}$" } | Select-Object -First 1)
if ($saId) { $saId = $saId.Trim(); Write-Host "Superadmin: $saId" -ForegroundColor Gray }
else { Write-Host "  Superadmin not found" -ForegroundColor Yellow }

$out = @()
$out += "-- RTM View Shell - Database Baseline"
$out += "-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$out += "-- Restore: psql -U ccdashboard_user -d rtmviewdb -f baseline.sql"
$out += ""
$out += "SET session_replication_role = replica;"
$out += ""

Export-Table "tenants"         "`"Slug`" = 'platform'"
Export-Table "tenant_settings" "`"TenantId`" = '$platformId'"
Export-Table "identity.roles"
if ($saId) {
    Export-Table "identity.users"       "`"Id`" = '$saId'"
    Export-Table "identity.user_roles"  "`"UserId`" = '$saId'"
}
Export-Table "widget_catalog"
Export-Table "RTSGrid_Metric"
Export-Table "RTSGrid_Statistic"
Export-Table "RTSGrid_Grid"
Export-Table "RTSGrid_Row"
Export-Table "RTSGrid_Column"
Export-Table "RTSGrid_Cell"
Export-Table "RTSUserGrid_ColumnsSet"
Export-Table "RTSUserGrid_Grid"
Export-Table "RTSUserGrid_Column"
Export-Table "NGC_Site"

$out += "SET session_replication_role = DEFAULT;"

$content = $out -join "`r`n"
$bytes = [System.Text.Encoding]::UTF8.GetPreamble() + [System.Text.Encoding]::UTF8.GetBytes($content)
[System.IO.File]::WriteAllBytes($OutFile, $bytes)
Remove-Item $TmpSql -ErrorAction SilentlyContinue
Write-Host "" ; Write-Host "Written: $OutFile" -ForegroundColor Green

if ($DryRun) { Write-Host "DryRun -- skipping git commit." -ForegroundColor Yellow; exit 0 }

& git -C $RepoRoot add "db/baseline.sql"
$diff = & git -C $RepoRoot diff --cached --stat "db/baseline.sql"
if (-not $diff) { Write-Host "No changes -- nothing to commit." -ForegroundColor Gray; exit 0 }
Write-Host $diff
if (-not $CommitMessage) { $CommitMessage = Read-Host "Commit message" }
if (-not $CommitMessage) { $CommitMessage = "update baseline snapshot" }
& git -C $RepoRoot commit -m "db: $CommitMessage"
Write-Host "Committed. Run: git push origin v2" -ForegroundColor Green
$env:PGPASSWORD = ""
