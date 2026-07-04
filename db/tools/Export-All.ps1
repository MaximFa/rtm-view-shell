#Requires -Version 5.1
<#
.SYNOPSIS
    Exports complete DB state to git: schema + functions + data.
    Run after ANY DB change. Commit the result with a meaningful message.
.EXAMPLE
    .\Export-All.ps1 -Password "pw" -CommitMessage "add QueueSLAIn60sec metric"
    .\Export-All.ps1 -Password "pw" -DryRun
#>
[CmdletBinding()]
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
$DbDir     = Join-Path $RepoRoot "db"
$DataDir   = Join-Path $DbDir "data"
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
$psql    = Find-PGTool "psql"
$pgdump  = Find-PGTool "pg_dump"
if (-not $psql -or -not $pgdump)  { throw "psql/pg_dump not found." }
if ($Password) { $env:PGPASSWORD = $Password }
Write-Host "Export-All: ${DBUser}@${DBHost}:${DBPort}/${Database}" -ForegroundColor Cyan

function Write-UTF8([string]$path, [string[]]$lines) {
    $content = $lines -join "`r`n"
    # Write without BOM — psql does not handle UTF-8 BOM
    [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
}

function Run-SQL([string]$sql) {
    Set-Content -Path $TmpSql -Value $sql -Encoding UTF8
    return (& $psql -h $DBHost -p $DBPort -U $DBUser -d $Database -t -A -f $TmpSql 2>&1)
}

function Export-TableData([string]$table, [string]$where = "") {
    $cond = if ($where) { " WHERE $where" } else { "" }
    $ref = if ($table -match "^(.+)\.(.+)$") { "$($Matches[1]).`"$($Matches[2])`"" } else { "`"$table`"" }
    $copySql = "COPY (SELECT * FROM $ref$cond) TO STDOUT WITH (FORMAT text)"
    Set-Content -Path $TmpSql -Value $copySql -Encoding UTF8
    $rows = (& $psql -h $DBHost -p $DBPort -U $DBUser -d $Database -t -A -f $TmpSql 2>&1)
    $dataRows = @($rows | Where-Object { $_ -and $_ -notmatch "^(ERROR|psql:)" })
    $out = @()
    $out += "-- $table"
    $out += "TRUNCATE TABLE $ref RESTART IDENTITY CASCADE;"
    if ($dataRows.Count -gt 0) {
        $out += "COPY $ref FROM stdin;"
        $out += $dataRows
        $out += "\."
    }
    $out += ""
    Write-Host "  $table ($($dataRows.Count) rows)" -ForegroundColor Gray
    return $out
}

# ── 1. Schema (pg_dump --schema-only) ────────────────────────────────────
# R0b carve (2026-06-21): WHITELIST approach — only RTM-canonical tables.
# EF-app tables (dashboards, identity.*, audit.audit_logs, etc.) are NOT exported here.
# They are created by Web.exe migrate (App + Audit EF contexts).
# This prevents Export-All from re-introducing carved tables.
Write-Host "[ 1/3 ] Exporting schema (RTM-only whitelist)..." -ForegroundColor Cyan
$schemaFile = Join-Path $DbDir "schema.sql"
# Use RtmSchemaDump helper (single-source whitelist, version-independent full-dump+filter)
. (Join-Path $ScriptDir 'RtmSchemaDump.ps1')
Export-RtmSchema -PgDump $pgdump -DBHost $DBHost -DBPort $DBPort -DBUser $DBUser -Database $Database -OutFile $schemaFile
Write-Host "  schema.sql written (26 RTM tables)." -ForegroundColor Green
# R0d: Functions are sourced from db/functions/* (single-source §39.1), NOT from pg_dump.
# The -t whitelist exports tables only; functions are intentionally excluded from schema.sql.

# ── 2. Data by category ───────────────────────────────────────────────────
Write-Host "[ 2/3 ] Exporting data..." -ForegroundColor Cyan

# R0c (2026-06-21): 01_system.sql export removed.
# EF-app tables (tenants, identity.*, EF migration history) are now seeded by
# Web.exe migrate / DatabaseInitializer, NOT by psql db/data scripts.

# 02_metrics.sql — RTSGrid_Metric + Statistic
$metrics = @("-- 02_metrics.sql: RTSGrid metrics and statistics","SET session_replication_role = replica;","")
$metrics += Export-TableData "RTSGrid_Metric"
$metrics += Export-TableData "RTSGrid_Statistic"
$metrics += "SET session_replication_role = DEFAULT;"
$metrics += ''
$metrics += '-- metric_deploy_log baseline seed (ledger completeness, contract 3.0)'
$metrics += 'INSERT INTO public.metric_deploy_log ("MetricId","DeployedAt","SourceCommit")'
$metrics += 'SELECT "MetricId", now(), ''baseline'' FROM public."RTSGrid_Metric"'
$metrics += 'ON CONFLICT ("MetricId") DO NOTHING;'
Write-UTF8 (Join-Path $DataDir "02_metrics.sql") $metrics

# 03_rtsgrid.sql — RTSGrid structure (Grid/Row/Column/Cell) + RTSUserGrid
$rts = @("-- 03_rtsgrid.sql: RTSGrid and RTSUserGrid widget definitions","SET session_replication_role = replica;","")
$rts += Export-TableData "RTSGrid_Grid"
$rts += Export-TableData "RTSGrid_Row"
$rts += Export-TableData "RTSGrid_Column"
$rts += Export-TableData "RTSGrid_Cell"
$rts += Export-TableData "RTSUserGrid_ColumnsSet"
$rts += Export-TableData "RTSUserGrid_Grid"
$rts += Export-TableData "RTSUserGrid_Column"
$rts += "SET session_replication_role = DEFAULT;"
Write-UTF8 (Join-Path $DataDir "03_rtsgrid.sql") $rts

# 04_catalog.sql — NGC_Site only (widget_catalog is EF-managed)
$cat = @("-- 04_catalog.sql: NGC site definitions (RTM-only)","SET session_replication_role = replica;","")
$cat += Export-TableData "NGC_Site"
$cat += "SET session_replication_role = DEFAULT;"
Write-UTF8 (Join-Path $DataDir "04_catalog.sql") $cat

Remove-Item $TmpSql -ErrorAction SilentlyContinue
Write-Host "  Data files written to db/data/" -ForegroundColor Green

# ── 3. Git commit ─────────────────────────────────────────────────────────
Write-Host "[ 3/3 ] Git..." -ForegroundColor Cyan
if ($DryRun) { Write-Host "DryRun -- skipping commit." -ForegroundColor Yellow; exit 0 }

& git -C $RepoRoot add "db/schema.sql" "db/data/" "db/functions/"
$diff = & git -C $RepoRoot diff --cached --stat
if (-not $diff) { Write-Host "No changes." -ForegroundColor Gray; exit 0 }
Write-Host $diff
if (-not $CommitMessage) { $CommitMessage = Read-Host "Commit message (describe the DB change)" }
if (-not $CommitMessage) { $CommitMessage = "update DB snapshot" }
& git -C $RepoRoot commit -m "db: $CommitMessage"
Write-Host "Committed. Run: git push origin v2" -ForegroundColor Green
$env:PGPASSWORD = ""
