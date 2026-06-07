#Requires -Version 5.1
<#
.SYNOPSIS
    Compare-ToBaseline.ps1 -- READ-ONLY DB drift comparator: installed server vs repo baseline.
    Outputs (1) human-readable delta report and (2) idempotent alignment SQL.

.DESCRIPTION
    Compares live PostgreSQL server against the repo baseline (db/schema.sql, db/functions/*.sql,
    db/data/*.sql, db/migrations/*.sql) and emits:
    - baseline_delta_<Database>_<timestamp>.txt -- human-readable delta report
    - align_<Database>_<timestamp>.sql -- idempotent alignment script (run as postgres)

    This script NEVER writes to the target DB. It only runs SELECT / pg_dump queries.

    Dimension D uses a HYBRID approach:
    - If `public.db_patch_history` ledger exists: exact (reads applied migration names directly)
    - For migrations not in the ledger: heuristic (per-migration object-presence probes)
    This provides exact tracking for new migrations while maintaining backwards compatibility
    with pre-ledger migrations. See CLAUDE.md §38a.

.PARAMETER DBHost
    PostgreSQL host (default: localhost)
.PARAMETER DBPort
    PostgreSQL port (default: 5432)
.PARAMETER Database
    Database name (default: rtmviewdb)
.PARAMETER User
    Database user (default: ccdashboard_user) -- read-only role is sufficient
.PARAMETER Password
    Database password
.PARAMETER OutDir
    Output directory (default: current directory if BaselineDir used, else <repo>/Installations)
.PARAMETER BaselineDir
    Path to the repo 'db' folder containing schema.sql, functions/, data/, migrations/.
    Use when running the script standalone (not from the repo structure).

.EXAMPLE
    .\Compare-ToBaseline.ps1 -Password "pw" -BaselineDir "C:\Temp\db" -OutDir "C:\Temp\Out"
.EXAMPLE
    .\Compare-ToBaseline.ps1 -Password "pw"
    .\Compare-ToBaseline.ps1 -DBHost "192.168.1.10" -Password "pw" -OutDir "C:\Temp"
#>
[CmdletBinding()]
param(
    [string]$DBHost      = "localhost",
    [string]$DBPort      = "5432",
    [string]$Database    = "rtmviewdb",
    [string]$User        = "ccdashboard_user",
    [string]$Password    = "",
    [string]$OutDir      = "",
    [string]$BaselineDir = ""
)
$ErrorActionPreference = "Stop"

# -- Derive paths (robust: handles standalone script or -BaselineDir override) --
if ($BaselineDir) {
    $DbDir = (Resolve-Path $BaselineDir -ErrorAction Stop).Path
} else {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if ($ScriptDir) {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
        if ($RepoRoot) {
            $DbDir = Join-Path $RepoRoot "db"
        } else {
            throw "Cannot derive repo root from script path. Use -BaselineDir <path to repo db/ folder>."
        }
    } else {
        throw "Cannot determine script directory. Use -BaselineDir <path to repo db/ folder>."
    }
}
# Validate baseline folder
$schemaFile = Join-Path $DbDir "schema.sql"
if (-not (Test-Path $schemaFile)) {
    throw "Baseline db/ folder not found or invalid. Pass -BaselineDir <path to the repo 'db' folder> (must contain schema.sql, functions/, data/, migrations/)."
}
# Output directory
if (-not $OutDir) {
    if ($BaselineDir) {
        $OutDir = $PWD.Path
    } elseif ($RepoRoot) {
        $OutDir = Join-Path $RepoRoot "Installations"
    } else {
        $OutDir = $PWD.Path
    }
}
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

# -- Find PostgreSQL tools --
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

$psql   = Find-PGTool "psql"
$pgdump = Find-PGTool "pg_dump"
if (-not $psql)   { throw "psql not found. Install PostgreSQL or add to PATH." }
if (-not $pgdump) { throw "pg_dump not found. Install PostgreSQL or add to PATH." }
if ($Password) { $env:PGPASSWORD = $Password }

# -- Helper: Run SQL query --
$TmpSql = [System.IO.Path]::GetTempFileName() + ".sql"

function Run-SQL([string]$sql) {
    [System.IO.File]::WriteAllText($TmpSql, $sql, [System.Text.UTF8Encoding]::new($false))
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # psql ERROR on stderr must NOT abort the script
    try {
        $result = (& $psql -h $DBHost -p $DBPort -U $User -d $Database -t -A -F '|' -f $TmpSql 2>&1)
    } finally {
        $ErrorActionPreference = $prev
    }
    return $result | Where-Object { $_ -and $_ -notmatch "^(ERROR|psql:)" }
}

# -- Helper: Write UTF-8 without BOM --
function Write-NoBom([string]$path, [string]$content) {
    [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
}

# -- Migration ledger: define probes for heuristic detection --
$MigrationProbes = @{
    "20260604_001_add_agent_state_pct_metrics" = 'SELECT 1 FROM "RTSGrid_Metric" WHERE "MetricId"=''TotalStatusGroupPercent'' LIMIT 1'
    "20260605_001_add_missing_metrics" = 'SELECT 1 FROM "RTSGrid_Metric" WHERE "MetricId"=''QueueNumAbandonedCalls'' LIMIT 1'
    "20260605_002_fix_daytrendinteractions" = "SELECT 1 FROM pg_proc WHERE proname='fn_daytrendinteractions' LIMIT 1"
    "20260605_003_add_user_widget_settings" = "SELECT 1 FROM information_schema.tables WHERE table_name='user_widget_settings' LIMIT 1"
    "20260605_004_metrics_dedup" = $null
    "20260606_002_fix_userstatuslog_write" = "SELECT 1 FROM pg_proc WHERE proname='RTSData_SetUserStatus' AND prokind='p' LIMIT 1"
    "20260606_003_catalog_backfill" = 'SELECT 1 FROM "RTSGrid_Metric" WHERE "CatalogCategory" IS NOT NULL LIMIT 1'
    "20260606_004_userstatuslog_statusgroup" = "SELECT 1 FROM information_schema.columns WHERE table_name='RTSData_UserStatusLog' AND column_name='StatusGroup' LIMIT 1"
    "20260606_005_history_unavailable_metrics" = 'SELECT 1 FROM "RTSGrid_Metric" WHERE "MetricFunction"=''HistoryUnavailableCount'' LIMIT 1'
    "20260606_006_unavailable_rtsgrid_metrics" = 'SELECT 1 FROM "RTSGrid_Metric" WHERE "MetricParameter"=''UNAVAILABLE'' LIMIT 1'
    "20260606_007_ngc_useragentgroup" = "SELECT 1 FROM information_schema.tables WHERE table_name='NGC_UserAgentgroup' LIMIT 1"
    "20260606_008_daytrend_fn_bu_scope" = $null
    "20260606_009_ngc_useragentgroup_procedures" = "SELECT 1 FROM pg_proc WHERE proname='NGC_SetUserAgentgroup' AND prokind='p' LIMIT 1"
    "20260607_001_add_metric_translation_table" = "SELECT 1 FROM information_schema.tables WHERE table_name='RTSGrid_MetricTranslation' LIMIT 1"
}

# -- Output containers --
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$DeltaFile = Join-Path $OutDir "baseline_delta_${Database}_${Timestamp}.txt"
$AlignFile = Join-Path $OutDir "align_${Database}_${Timestamp}.sql"

$DeltaLines = [System.Collections.ArrayList]@()
$AlignLines = [System.Collections.ArrayList]@()

[void]$DeltaLines.Add(("=" * 80))
[void]$DeltaLines.Add("BASELINE DELTA REPORT")
[void]$DeltaLines.Add("Target: ${User}@${DBHost}:${DBPort}/${Database}")
[void]$DeltaLines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$DeltaLines.Add(("=" * 80))
[void]$DeltaLines.Add("")

[void]$AlignLines.Add("-- ==============================================================================")
[void]$AlignLines.Add("-- ALIGNMENT SCRIPT -- Bring server up to baseline")
[void]$AlignLines.Add("-- Target: ${Database}@${DBHost}:${DBPort}")
[void]$AlignLines.Add("-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$AlignLines.Add("-- Run as: psql -h $DBHost -U postgres -d $Database -v ON_ERROR_STOP=1 -f <thisfile>")
[void]$AlignLines.Add("-- ==============================================================================")
[void]$AlignLines.Add("\set ON_ERROR_STOP on")
[void]$AlignLines.Add("")

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host " Compare-ToBaseline: ${User}@${DBHost}:${DBPort}/${Database}" -ForegroundColor Cyan
Write-Host ('=' * 60) -ForegroundColor Cyan

$SchemaDiffLines = 0
$RoutineFlags = 0
$MetricDrift = 0
$UnappliedMigrationCount = 0

# ====== DIMENSION A: SCHEMA ======
Write-Host "`n[A] SCHEMA COMPARISON" -ForegroundColor Yellow
[void]$DeltaLines.Add("-" * 40)
[void]$DeltaLines.Add("DIMENSION A: SCHEMA")
[void]$DeltaLines.Add("-" * 40)

$ServerSchemaFile = [System.IO.Path]::GetTempFileName() + ".sql"
& $pgdump -h $DBHost -p $DBPort -U $User -d $Database --schema-only --no-owner --no-acl --schema=public --schema=identity --schema=audit -f $ServerSchemaFile 2>$null

$BaselineSchemaFile = Join-Path $DbDir "schema.sql"

function Normalize-Schema([string]$path) {
    $lines = Get-Content $path -ErrorAction SilentlyContinue
    return $lines | Where-Object {
        $_ -notmatch "^--" -and $_ -notmatch "^SET " -and $_ -notmatch "^SELECT " -and
        $_ -notmatch "^\s*$" -and $_ -notmatch "OWNER TO" -and $_ -notmatch "^\\connect" -and
        $_ -notmatch "Dumped from" -and $_ -notmatch "Dumped by"
    } | ForEach-Object { $_.TrimEnd() }
}

$ServerNorm   = Normalize-Schema $ServerSchemaFile
$BaselineNorm = Normalize-Schema $BaselineSchemaFile

$ServerSet   = [System.Collections.Generic.HashSet[string]]::new([string[]]$ServerNorm)
$BaselineSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$BaselineNorm)

$MissingOnServer = $BaselineNorm | Where-Object { -not $ServerSet.Contains($_) }
$ExtraOnServer   = $ServerNorm | Where-Object { -not $BaselineSet.Contains($_) }

$SchemaDiffLines = @($MissingOnServer).Count + @($ExtraOnServer).Count

if ($SchemaDiffLines -eq 0) {
    Write-Host "  Schema matches baseline." -ForegroundColor Green
    [void]$DeltaLines.Add("Schema matches baseline (no drift detected).")
} else {
    Write-Host "  Schema drift: $(@($MissingOnServer).Count) lines missing, $(@($ExtraOnServer).Count) lines extra" -ForegroundColor Red
    [void]$DeltaLines.Add("Schema drift detected:")
    [void]$DeltaLines.Add("  Lines missing on server: $(@($MissingOnServer).Count)")
    [void]$DeltaLines.Add("  Lines extra on server:   $(@($ExtraOnServer).Count)")
    
    [void]$AlignLines.Add("-- ===== DIMENSION A: SCHEMA =====")
    [void]$AlignLines.Add("-- MANUAL REVIEW: Schema drift detected but not auto-fixed.")
    [void]$AlignLines.Add("-- Apply unapplied migrations below. For remaining drift, review manually.")
    [void]$AlignLines.Add("")
}
[void]$DeltaLines.Add("")
Remove-Item $ServerSchemaFile -ErrorAction SilentlyContinue

# ====== DIMENSION B: ROUTINE KIND ======
Write-Host "`n[B] ROUTINE KIND (prokind) -- CRITICAL" -ForegroundColor Yellow
[void]$DeltaLines.Add("-" * 40)
[void]$DeltaLines.Add("DIMENSION B: ROUTINE KIND (prokind) [RTM-SEC-002]")
[void]$DeltaLines.Add("-" * 40)

$ExpectedRoutines = @{}
Get-ChildItem (Join-Path $DbDir "functions") -Filter "*.sql" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $pattern = 'CREATE\s+(?:OR\s+REPLACE\s+)?(PROCEDURE|FUNCTION)\s+"?(\w+)"?\s*\(([^)]*)\)'
    $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($m in $matches) {
        $kind = $m.Groups[1].Value.ToUpper()
        $name = $m.Groups[2].Value
        $prokind = if ($kind -eq "PROCEDURE") { "p" } else { "f" }
        $ExpectedRoutines[$name] = @{ Kind = $prokind; Source = $_.Name }
    }
}

$routineSql = "SELECT n.nspname, p.proname, p.prokind, p.pronargs FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname IN ('public','identity','audit') ORDER BY 1,2;"
$serverRoutines = Run-SQL $routineSql

$ServerRoutineMap = @{}
foreach ($row in $serverRoutines) {
    $parts = $row -split '\|'
    if ($parts.Count -ge 4) {
        $ServerRoutineMap[$parts[1]] = @{ Schema = $parts[0]; Kind = $parts[2]; ArgCount = [int]$parts[3] }
    }
}

$RoutineMismatches = @()
$RoutineMissing = @()

foreach ($routineName in $ExpectedRoutines.Keys) {
    $expected = $ExpectedRoutines[$routineName]
    if (-not $ServerRoutineMap.ContainsKey($routineName)) {
        $RoutineMissing += $routineName
        $RoutineFlags++
    } else {
        $actual = $ServerRoutineMap[$routineName]
        if ($actual.Kind -ne $expected.Kind) {
            $RoutineMismatches += @{ Name = $routineName; ExpectedKind = $expected.Kind; ActualKind = $actual.Kind; Source = $expected.Source }
            $RoutineFlags++
        }
    }
}

if ($RoutineFlags -eq 0) {
    Write-Host "  All routines match expected kind." -ForegroundColor Green
    [void]$DeltaLines.Add("All routines match expected kind (no prokind drift).")
} else {
    Write-Host "  Routine issues: $($RoutineMissing.Count) missing, $($RoutineMismatches.Count) kind mismatches" -ForegroundColor Red
    if ($RoutineMissing.Count -gt 0) {
        [void]$DeltaLines.Add("Missing routines:")
        $RoutineMissing | ForEach-Object { [void]$DeltaLines.Add("  - $_ (expected in $($ExpectedRoutines[$_].Source))") }
    }
    if ($RoutineMismatches.Count -gt 0) {
        [void]$DeltaLines.Add("Kind mismatches (RTM-SEC-002):")
        foreach ($mm in $RoutineMismatches) {
            $expLabel = if ($mm.ExpectedKind -eq "p") { "PROCEDURE" } else { "FUNCTION" }
            $actLabel = if ($mm.ActualKind -eq "p") { "PROCEDURE" } else { "FUNCTION" }
            [void]$DeltaLines.Add("  - $($mm.Name): expected $expLabel, server has $actLabel")
        }
        [void]$AlignLines.Add("-- ===== DIMENSION B: ROUTINE KIND FIXES =====")
        foreach ($mm in $RoutineMismatches) {
            [void]$AlignLines.Add("-- Fix $($mm.Name): see db/functions/$($mm.Source)")
        }
        [void]$AlignLines.Add("")
    }
}
[void]$DeltaLines.Add("")

# ====== DIMENSION C: DATA ======
Write-Host "`n[C] DATA COMPARISON (metrics)" -ForegroundColor Yellow
[void]$DeltaLines.Add("-" * 40)
[void]$DeltaLines.Add("DIMENSION C: DATA (RTSGrid_Metric)")
[void]$DeltaLines.Add("-" * 40)

$MetricsFile = Join-Path (Join-Path $DbDir "data") "02_metrics.sql"
$ExpectedMetrics = @{}

if (Test-Path $MetricsFile) {
    $metricsContent = Get-Content $MetricsFile -Raw
    $inCopy = $false
    $metricsContent -split "`n" | ForEach-Object {
        $line = $_.TrimEnd()
        if ($line -match "^COPY.*RTSGrid_Metric.*FROM stdin") { $inCopy = $true }
        elseif ($line -eq '\.') { $inCopy = $false }
        elseif ($inCopy -and $line -and $line -notmatch "^--") {
            $fields = $line -split "`t"
            if ($fields.Count -ge 4) {
                $ExpectedMetrics[$fields[0]] = @{ MetricFunction = $fields[1]; MetricParameter = $fields[2]; MetricType = $fields[3] }
            }
        }
    }
}

$metricSql = 'SELECT "MetricId", "MetricFunction", "MetricParameter", "MetricType" FROM "RTSGrid_Metric" ORDER BY "MetricId";'
$serverMetrics = Run-SQL $metricSql

$ServerMetricMap = @{}
foreach ($row in $serverMetrics) {
    $parts = $row -split '\|'
    if ($parts.Count -ge 4) {
        $ServerMetricMap[$parts[0]] = @{ MetricFunction = $parts[1]; MetricParameter = $parts[2]; MetricType = $parts[3] }
    }
}

$MetricsMissing = @()
$MetricsExtra = @()

foreach ($mid in $ExpectedMetrics.Keys) {
    if (-not $ServerMetricMap.ContainsKey($mid)) {
        $MetricsMissing += $mid
        $MetricDrift++
    }
}
foreach ($mid in $ServerMetricMap.Keys) {
    if (-not $ExpectedMetrics.ContainsKey($mid)) { $MetricsExtra += $mid }
}

if ($MetricDrift -eq 0 -and $MetricsExtra.Count -eq 0) {
    Write-Host "  Metrics match baseline." -ForegroundColor Green
    [void]$DeltaLines.Add("Metrics match baseline (no drift).")
} else {
    Write-Host "  Metric drift: $($MetricsMissing.Count) missing, $($MetricsExtra.Count) extra" -ForegroundColor Red
    if ($MetricsMissing.Count -gt 0) {
        [void]$DeltaLines.Add("Missing metrics on server:")
        $MetricsMissing | ForEach-Object { [void]$DeltaLines.Add("  - $_") }
        [void]$AlignLines.Add("-- ===== DIMENSION C: MISSING METRICS =====")
        [void]$AlignLines.Add("-- Run db/data/02_metrics.sql to restore missing metrics")
        [void]$AlignLines.Add("")
    }
    if ($MetricsExtra.Count -gt 0) {
        [void]$DeltaLines.Add("Extra metrics on server (not in baseline):")
        $MetricsExtra | ForEach-Object { [void]$DeltaLines.Add("  + $_ (not in baseline)") }
    }
}
[void]$DeltaLines.Add("")

# ====== DIMENSION D: MIGRATION LEDGER (HYBRID) ======
Write-Host "`n[D] MIGRATION LEDGER" -ForegroundColor Yellow
[void]$DeltaLines.Add("-" * 40)
[void]$DeltaLines.Add("DIMENSION D: MIGRATION LEDGER")

# Check if ledger table exists
$ledgerExists = $false
$ledgerApplied = @{}
$ledgerCheckResult = Run-SQL "SELECT to_regclass('public.db_patch_history');"
if ($ledgerCheckResult -and $ledgerCheckResult -notmatch "^\s*$" -and $ledgerCheckResult -notmatch "^$") {
    $ledgerExists = $true
    $ledgerRows = Run-SQL "SELECT migration_name FROM public.db_patch_history;"
    foreach ($row in $ledgerRows) {
        $name = ($row -split '\|')[0].Trim()
        if ($name) { $ledgerApplied[$name] = $true }
    }
    Write-Host "  Ledger table found ($($ledgerApplied.Count) entries)" -ForegroundColor Green
} else {
    Write-Host "  No ledger table (all heuristic)" -ForegroundColor Yellow
}

$AppliedLedger = @()      # exact from ledger
$AppliedProbe = @()       # heuristic from probe
$UnappliedMigrations = @()
$UnknownMigrations = @()

$migrationFiles = Get-ChildItem (Join-Path $DbDir "migrations") -Filter "*.sql" -ErrorAction SilentlyContinue | Sort-Object Name
foreach ($mig in $migrationFiles) {
    $migName = $mig.BaseName
    if ($ledgerApplied.ContainsKey($migName)) {
        $AppliedLedger += $migName
    } elseif ($MigrationProbes.ContainsKey($migName)) {
        $probe = $MigrationProbes[$migName]
        if ($probe) {
            $result = Run-SQL $probe
            if ($result -match "1") { $AppliedProbe += $migName }
            else { $UnappliedMigrations += $migName }
        } else { $UnknownMigrations += $migName }
    } else { $UnknownMigrations += $migName }
}

$UnappliedMigrationCount = $UnappliedMigrations.Count

# Summary line for report
if ($ledgerExists) {
    [void]$DeltaLines.Add("(ledger present: $($AppliedLedger.Count) exact, $($AppliedProbe.Count) probed, $($UnknownMigrations.Count) unknown)")
} else {
    [void]$DeltaLines.Add("(no ledger -- all heuristic)")
}
[void]$DeltaLines.Add("-" * 40)

if ($UnappliedMigrationCount -eq 0 -and $UnknownMigrations.Count -eq 0) {
    Write-Host "  All migrations appear applied." -ForegroundColor Green
    [void]$DeltaLines.Add("All migrations appear applied.")
} else {
    if ($AppliedLedger.Count -gt 0) {
        [void]$DeltaLines.Add("Applied migrations (source: ledger):")
        $AppliedLedger | ForEach-Object { [void]$DeltaLines.Add("  [OK] $_") }
    }
    if ($AppliedProbe.Count -gt 0) {
        [void]$DeltaLines.Add("Applied migrations (source: probe):")
        $AppliedProbe | ForEach-Object { [void]$DeltaLines.Add("  [OK] $_") }
    }
    if ($UnappliedMigrationCount -gt 0) {
        Write-Host "  Unapplied migrations: $UnappliedMigrationCount" -ForegroundColor Red
        [void]$DeltaLines.Add("Unapplied migrations:")
        $UnappliedMigrations | ForEach-Object { [void]$DeltaLines.Add("  [MISSING] $_") }
        [void]$AlignLines.Add("-- ===== DIMENSION D: UNAPPLIED MIGRATIONS =====")
        foreach ($migName in $UnappliedMigrations) {
            $migFile = Join-Path (Join-Path $DbDir "migrations") "$migName.sql"
            if (Test-Path $migFile) {
                [void]$AlignLines.Add("")
                [void]$AlignLines.Add("-- ===== migration $migName =====")
                [void]$AlignLines.Add((Get-Content $migFile -Raw))
            }
        }
    }
    if ($UnknownMigrations.Count -gt 0) {
        Write-Host "  Unknown migrations (no ledger, no probe): $($UnknownMigrations.Count)" -ForegroundColor Yellow
        [void]$DeltaLines.Add("Unknown migrations (no ledger entry, no probe):")
        $UnknownMigrations | ForEach-Object {
            [void]$DeltaLines.Add("  [???] $_")
            [void]$AlignLines.Add("-- UNKNOWN (no ledger entry, probe absent) -- operator verify: $_")
        }
    }
}
[void]$DeltaLines.Add("")

# ====== FINALIZE OUTPUT ======
[void]$DeltaLines.Add("=" * 80)
[void]$DeltaLines.Add("SUMMARY")
[void]$DeltaLines.Add("=" * 80)
[void]$DeltaLines.Add("A. Schema drift lines:     $SchemaDiffLines")
[void]$DeltaLines.Add("B. Routine kind issues:    $RoutineFlags")
[void]$DeltaLines.Add("C. Metric drift:           $MetricDrift")
[void]$DeltaLines.Add("D. Unapplied migrations:   $UnappliedMigrationCount")
[void]$DeltaLines.Add("")

$totalIssues = $SchemaDiffLines + $RoutineFlags + $MetricDrift + $UnappliedMigrationCount
if ($totalIssues -eq 0) {
    [void]$DeltaLines.Add("*** NO DRIFT DETECTED. Server matches baseline. ***")
    $AlignLines.Clear()
    [void]$AlignLines.Add("-- ==============================================================================")
    [void]$AlignLines.Add("-- No drift detected. Server matches baseline.")
    [void]$AlignLines.Add("-- ==============================================================================")
}

Write-NoBom $DeltaFile ($DeltaLines -join "`r`n")
Write-NoBom $AlignFile ($AlignLines -join "`r`n")

Remove-Item $TmpSql -ErrorAction SilentlyContinue
$env:PGPASSWORD = ""

# Console summary
Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host " COMPARISON COMPLETE" -ForegroundColor Cyan
Write-Host ('=' * 60) -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor White
Write-Host "  A. Schema drift lines:    " -NoNewline
if ($SchemaDiffLines -eq 0) { Write-Host "0" -ForegroundColor Green } else { Write-Host $SchemaDiffLines -ForegroundColor Red }
Write-Host "  B. Routine kind issues:   " -NoNewline
if ($RoutineFlags -eq 0) { Write-Host "0" -ForegroundColor Green } else { Write-Host $RoutineFlags -ForegroundColor Red }
Write-Host "  C. Metric drift:          " -NoNewline
if ($MetricDrift -eq 0) { Write-Host "0" -ForegroundColor Green } else { Write-Host $MetricDrift -ForegroundColor Red }
Write-Host "  D. Unapplied migrations:  " -NoNewline
if ($UnappliedMigrationCount -eq 0) { Write-Host "0" -ForegroundColor Green } else { Write-Host $UnappliedMigrationCount -ForegroundColor Red }
Write-Host ""
Write-Host "Output files:" -ForegroundColor White
Write-Host "  Delta report: $DeltaFile" -ForegroundColor Cyan
Write-Host "  Alignment SQL: $AlignFile" -ForegroundColor Cyan
Write-Host ""
if ($totalIssues -eq 0) {
    Write-Host "No drift detected. Server matches baseline." -ForegroundColor Green
} else {
    Write-Host "Drift detected. Review delta report and run alignment SQL as postgres." -ForegroundColor Yellow
}
