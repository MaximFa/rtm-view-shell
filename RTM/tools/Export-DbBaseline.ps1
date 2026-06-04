# Export-DbBaseline.ps1
# Exports a clean database baseline for git versioning.
# Includes: Platform tenant, superadmin, metrics, RTSGrid/RTSUserGrid definitions, NGC_Site.
# Excludes: dashboards, users, NGC configs, RTSData runtime, audit logs.
#
# Usage:
#   .\Export-DbBaseline.ps1 [-CommitMessage "describe change"]
#   .\Export-DbBaseline.ps1 -DryRun

[CmdletBinding()]
param(
    [string]$Host     = "localhost",
    [string]$Port     = "5432",
    [string]$Database = "rtmviewdb",
    [string]$User     = "ccdashboard_user",
    [string]$Password = "",
    [string]$CommitMessage = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Resolve paths
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptDir
$OutFile    = Join-Path $RepoRoot "sql\db_baseline.sql"

# Find psql
$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
    foreach ($base in @("C:\Program Files\PostgreSQL", "C:\Program Files (x86)\PostgreSQL")) {
        $found = Get-ChildItem "$base\*\bin\psql.exe" -ErrorAction SilentlyContinue | Sort-Object -Descending | Select-Object -First 1
        if ($found) { $psql = $found.FullName; break }
    }
}
if (-not $psql) { throw "psql not found. Add PostgreSQL bin to PATH." }

if ($Password) { $env:PGPASSWORD = $Password }

function Run-SQL([string]$sql) {
    $result = & $psql -h $Host -p $Port -U $User -d $Database -t -A -c $sql 2>&1
    return $result
}

Write-Host "Export-DbBaseline: connecting to $Database@$Host:$Port" -ForegroundColor Cyan

# ── 1. Get Platform tenant ID ─────────────────────────────────────────────
$platformId = Run-SQL "SELECT \"Id\" FROM tenants WHERE \"Slug\" = 'platform' LIMIT 1"
if (-not $platformId) { throw "Platform tenant not found." }
$platformId = $platformId.Trim()
Write-Host "Platform tenant: $platformId" -ForegroundColor Gray

# ── 2. Build SQL ──────────────────────────────────────────────────────────
$lines = @()
$lines += "-- RTM View Shell — Database Baseline"
$lines += "-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
$lines += "-- Contains: Platform tenant, Superadmin, Metrics, RTSGrid/RTSUserGrid definitions, NGC_Site"
$lines += "-- Apply:    psql -U ccdashboard_user -d rtmviewdb -f db_baseline.sql"
$lines += ""
$lines += "SET session_replication_role = replica; -- disable FK checks during restore"
$lines += ""

# Helper: export a table with optional WHERE
function Export-TableData([string]$table, [string]$where = "") {
    $whereClause = if ($where) { "WHERE $where" } else { "" }
    $sql = "SELECT * FROM \"$table\" $whereClause"
    # Use pg_dump COPY format for clean output
    $copyOut = Run-SQL "COPY ($sql) TO STDOUT WITH (FORMAT text)"
    if ($copyOut) {
        $script:lines += "-- Table: $table"
        $script:lines += "TRUNCATE TABLE \"$table\" RESTART IDENTITY CASCADE;"
        $script:lines += "COPY \"$table\" FROM stdin;"
        $script:lines += $copyOut
        $script:lines += "\."
        $script:lines += ""
    }
}

# ── Tables with data ──────────────────────────────────────────────────────

# Platform tenant
Export-TableData "tenants" "\"Slug\" = 'platform'"

# Tenant settings for Platform
Export-TableData "tenant_settings" "\"TenantId\" = '$platformId'"

# Identity roles (all 4 fixed roles)
Export-TableData "identity.AspNetRoles"

# Superadmin user only
$superadminId = Run-SQL "SELECT \"Id\" FROM identity.\"AspNetUsers\" u JOIN identity.\"AspNetUserRoles\" ur ON u.\"Id\" = ur.\"UserId\" JOIN identity.\"AspNetRoles\" r ON ur.\"RoleId\" = r.\"Id\" WHERE r.\"Name\" = 'Superadmin' LIMIT 1"
if ($superadminId) {
    $superadminId = $superadminId.Trim()
    Export-TableData "identity.AspNetUsers" "\"Id\" = '$superadminId'"
    Export-TableData "identity.AspNetUserRoles" "\"UserId\" = '$superadminId'"
}

# Widget catalog
Export-TableData "widget_catalog"

# RTSGrid definitions (metrics + grid structure)
Export-TableData "RTSGrid_Metric"
Export-TableData "RTSGrid_Statistic"
Export-TableData "RTSGrid_Grid"
Export-TableData "RTSGrid_Row"
Export-TableData "RTSGrid_Column"
Export-TableData "RTSGrid_Cell"

# RTSUserGrid definitions
Export-TableData "RTSUserGrid_ColumnsSet"
Export-TableData "RTSUserGrid_Grid"
Export-TableData "RTSUserGrid_Column"

# NGC_Site (timezone/clear time definitions)
Export-TableData "NGC_Site"

$lines += "SET session_replication_role = DEFAULT;"

# ── 3. Write file ─────────────────────────────────────────────────────────
$sqlDir = Split-Path -Parent $OutFile
if (-not (Test-Path $sqlDir)) { New-Item -ItemType Directory -Path $sqlDir -Force | Out-Null }

$output = $lines -join "`r`n"
$bom = [System.Text.Encoding]::UTF8.GetPreamble()
$bytes = $bom + [System.Text.Encoding]::UTF8.GetBytes($output)
[System.IO.File]::WriteAllBytes($OutFile, $bytes)

Write-Host "Written: $OutFile ($(($lines | Measure-Object).Count) lines)" -ForegroundColor Green

if ($DryRun) { Write-Host "DryRun — git commit skipped." -ForegroundColor Yellow; exit 0 }

# ── 4. Git commit ─────────────────────────────────────────────────────────
$gitRoot = & git -C $RepoRoot rev-parse --show-toplevel 2>$null
if (-not $gitRoot) { Write-Host "Not a git repo — skipping commit." -ForegroundColor Yellow; exit 0 }

$relPath = "RTM/sql/db_baseline.sql"
& git -C $RepoRoot add $relPath

$diff = & git -C $RepoRoot diff --cached --stat $relPath
if (-not $diff) { Write-Host "No changes in db_baseline.sql — nothing to commit." -ForegroundColor Gray; exit 0 }

Write-Host ""
Write-Host "Changes:" -ForegroundColor Cyan
Write-Host $diff

if (-not $CommitMessage) {
    $CommitMessage = Read-Host "Commit message (describe DB change)"
}
if (-not $CommitMessage) { $CommitMessage = "db: update baseline snapshot" }

& git -C $RepoRoot commit -m "db: $CommitMessage"
Write-Host "Committed." -ForegroundColor Green
Write-Host "Run 'git push origin v2' to push to remote." -ForegroundColor Yellow
