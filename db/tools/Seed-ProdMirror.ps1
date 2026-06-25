<#
.SYNOPSIS
    One-time prod-mirror data-load tool for RTM View Shell.

.DESCRIPTION
    Loads production CC entity data (NGC_*, RTSData_*, permission_groups, pg_*)
    from a custom-format pg_dump into the working database, re-stamping all
    TenantId values to a dedicated prod-mirror tenant.

    Modes:
      - Inspect (default): Phases 0-3 only. Reads staging, reports counts, no writes.
      - Load: Phases 0-5. Backs up, restores staging, loads data, verifies.

    This script is RE-RUNNABLE: it truncates target-tenant rows before loading.

.PARAMETER PgBin
    PostgreSQL bin directory. Default: C:\Program Files\PostgreSQL\18\bin

.PARAMETER SuperUser
    Superuser for pg operations. Default: postgres

.PARAMETER SuperPassword
    Superuser password (required). Passed via PGPASSWORD env, never logged.

.PARAMETER DbName
    Our working database. Default: rtmviewdb

.PARAMETER StagingDb
    Throwaway staging database for restore. Default: rtmviewdb_prodstg

.PARAMETER DumpPath
    Path to production pg_dump custom-format backup. Default: Installations\prod-mirror\dump-rtmviewdb-202606252308.sql

.PARAMETER TargetTenantSlug
    Slug for the target tenant to load data into. Default: prod-mirror

.PARAMETER TargetTenantId
    Explicit target tenant UUID override. If omitted, resolved from TargetTenantSlug.

.PARAMETER Mode
    Inspect (default) = phases 0-3 only. Load = phases 0-5.

.EXAMPLE
    .\Seed-ProdMirror.ps1 -SuperPassword "pw" -Mode Inspect
    .\Seed-ProdMirror.ps1 -SuperPassword "pw" -Mode Load
#>

[CmdletBinding()]
param(
    [string]$PgBin = "C:\Program Files\PostgreSQL\18\bin",
    [string]$SuperUser = "postgres",
    [Parameter(Mandatory=$true)]
    [string]$SuperPassword,
    [string]$DbName = "rtmviewdb",
    [string]$StagingDb = "rtmviewdb_prodstg",
    [string]$DumpPath = "Installations\prod-mirror\dump-rtmviewdb-202606252308.sql",
    [string]$TargetTenantSlug = "prod-mirror",
    [string]$TargetTenantId = "",
    [ValidateSet("Inspect","Load")]
    [string]$Mode = "Inspect"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# --- Paths ---
$pgRestore = Join-Path $PgBin "pg_restore.exe"
$pgDump    = Join-Path $PgBin "pg_dump.exe"
$psql      = Join-Path $PgBin "psql.exe"
$dropdb    = Join-Path $PgBin "dropdb.exe"
$createdb  = Join-Path $PgBin "createdb.exe"

$prodMirrorDir = "Installations\prod-mirror"
if (-not (Test-Path $prodMirrorDir)) {
    New-Item -ItemType Directory -Path $prodMirrorDir -Force | Out-Null
}

$ts = (Get-Date).ToString("yyyyMMdd-HHmmss")

# --- Helper Functions ---
function Write-Banner {
    param([string]$Title)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Invoke-Psql {
    param(
        [string]$Database,
        [string]$Query,
        [switch]$TuplesOnly,
        [switch]$NoHeaders
    )
    $env:PGPASSWORD = $SuperPassword
    $args = @("-U", $SuperUser, "-d", $Database, "-c", $Query)
    if ($TuplesOnly) { $args += "-t" }
    if ($NoHeaders)  { $args += "--no-align" }
    $result = & $psql @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "psql failed: $result"
    }
    return $result
}

function Invoke-PsqlFile {
    param(
        [string]$Database,
        [string]$FilePath
    )
    $env:PGPASSWORD = $SuperPassword
    $result = & $psql -U $SuperUser -d $Database -f $FilePath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "psql -f failed: $result"
    }
    return $result
}


function Invoke-Native {
    param(
        [Parameter(Mandatory=$true)][string]$Exe,
        [string[]]$Arguments = @(),
        [string]$LogFile,
        [switch]$SoftFail   # log + return exit code; do NOT throw on non-zero
    )
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # native stderr must NOT terminate
    try {
        $out = & $Exe @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    if ($LogFile) { $out | Out-File -FilePath $LogFile -Encoding utf8 }
    if (($code -ne 0) -and (-not $SoftFail)) {
        throw ("{0} exited {1}: {2}" -f $Exe, $code, ($out -join [Environment]::NewLine))
    }
    return [pscustomobject]@{ Code = $code; Output = $out }
}

function Get-TableColumns {
    param([string]$Database, [string]$TableName)
    $schema = "public"
    if ($TableName -like "identity.*") {
        $schema = "identity"
        $TableName = $TableName.Substring(9)
    }
    $q = "SELECT column_name FROM information_schema.columns WHERE table_schema='$schema' AND table_name='$TableName' ORDER BY ordinal_position"
    $result = Invoke-Psql -Database $Database -Query $q -TuplesOnly -NoHeaders
    $cols = @($result | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() })
    return $cols
}

function Get-IntersectionColumns {
    param([string]$StagingDb, [string]$OurDb, [string]$TableName)
    $stagCols = Get-TableColumns -Database $StagingDb -TableName $TableName
    $ourCols  = Get-TableColumns -Database $OurDb     -TableName $TableName
    $intersection = @($stagCols | Where-Object { $ourCols -contains $_ })
    return $intersection
}

# --- Chain tables in FK load order ---
$ChainTables = @(
    "NGC_Site",
    "NGC_BusinessUnit",
    "NGC_Supergroup",
    "NGC_AgentGroups",
    "NGC_Queues",
    "queues",
    "NGC_BusinessUnitQueueClassification",
    "NGC_BusinessUnitSupergroup",
    "NGC_SupergroupAgentgroup",
    "NGC_UserAgentgroup",
    "permission_groups",
    "pg_business_units",
    "pg_queues",
    "pg_skills",
    "pg_agent_supergroups",
    "RTSData_Interaction",
    "RTSData_UserStatus",
    "RTSData_ChatMessage"
)

# Tables with TenantId column
$TenantIdTables = @(
    "NGC_Site",
    "NGC_BusinessUnit",
    "NGC_Supergroup",
    "NGC_AgentGroups",
    "NGC_Queues",
    "queues",
    "NGC_BusinessUnitQueueClassification",
    "NGC_BusinessUnitSupergroup",
    "NGC_SupergroupAgentgroup",
    "NGC_UserAgentgroup",
    "permission_groups",
    "pg_business_units",
    "pg_queues",
    "pg_skills",
    "pg_agent_supergroups",
    "RTSData_Interaction",
    "RTSData_UserStatus"
)
# RTSData_ChatMessage has NO TenantId

# =============================================================================
# PHASE 0 — Preflight
# =============================================================================
Write-Banner "PHASE 0 — Preflight"

# Verify tools exist
foreach ($tool in @($pgRestore, $pgDump, $psql, $dropdb, $createdb)) {
    if (-not (Test-Path $tool)) {
        throw "Tool not found: $tool"
    }
}

# Print versions
Write-Host "pg_restore version:"
$env:PGPASSWORD = $SuperPassword
& $pgRestore --version
Write-Host "pg_dump version:"
& $pgDump --version
Write-Host "psql version:"
& $psql --version

# Verify dump exists and is custom format
if (-not (Test-Path $DumpPath)) {
    throw "Dump file not found: $DumpPath"
}
$magic = [System.IO.File]::ReadAllBytes($DumpPath)[0..4]
$magicStr = [System.Text.Encoding]::ASCII.GetString($magic)
if ($magicStr -ne "PGDMP") {
    throw "Dump is not custom format (expected PGDMP magic, got: $magicStr). This tool requires custom-format dumps only."
}
Write-Host "Dump format: PGDMP (custom) - OK" -ForegroundColor Green

# Verify DbName is reachable
$testResult = Invoke-Psql -Database $DbName -Query "SELECT 1" -TuplesOnly -NoHeaders
if ($testResult.Trim() -ne "1") {
    throw "Cannot connect to database: $DbName"
}
Write-Host "Database $DbName is reachable - OK" -ForegroundColor Green

# Banner
Write-Host "`n--- Configuration ---" -ForegroundColor Yellow
Write-Host "Mode:             $Mode"
Write-Host "DbName:           $DbName"
Write-Host "StagingDb:        $StagingDb"
Write-Host "DumpPath:         $DumpPath"
Write-Host "TargetTenantSlug: $TargetTenantSlug"
if ($TargetTenantId) {
    Write-Host "TargetTenantId:   $TargetTenantId (explicit override)"
} else {
    Write-Host "TargetTenantId:   (will resolve from slug)"
}

# =============================================================================
# PHASE 1 — Backup OUR DB FIRST
# =============================================================================
Write-Banner "PHASE 1 — Backup OUR DB"

$backupPath = Join-Path $prodMirrorDir "our_pre_seed_$ts.dump"
Write-Host "Creating backup: $backupPath"

$env:PGPASSWORD = $SuperPassword
$backupArgs = @("-Fc", "-U", $SuperUser, "-d", $DbName, "-f", $backupPath)
$backup = Invoke-Native -Exe $pgDump -Arguments $backupArgs   # must succeed -> throws on non-zero
Write-Host "Backup created: $backupPath ($('{0:N2}' -f ((Get-Item $backupPath).Length / 1MB)) MB)" -ForegroundColor Green

# =============================================================================
# PHASE 2 — Restore prod backup into STAGING
# =============================================================================
Write-Banner "PHASE 2 — Restore to Staging"

# Drop existing staging DB
Write-Host "Dropping staging DB (if exists): $StagingDb"
$env:PGPASSWORD = $SuperPassword
$null = Invoke-Native -Exe $dropdb -Arguments @("-U", $SuperUser, "--if-exists", $StagingDb) -SoftFail

# Create staging DB
Write-Host "Creating staging DB: $StagingDb"
$null = Invoke-Native -Exe $createdb -Arguments @("-U", $SuperUser, "-O", $SuperUser, $StagingDb)  # must succeed

# Restore into staging
$restoreLog = Join-Path $prodMirrorDir "staging_restore_$ts.log"
Write-Host "Restoring dump into staging (this may take a while)..."
Write-Host "Log: $restoreLog"

$env:PGPASSWORD = $SuperPassword
$restoreArgs = @("--no-owner", "--no-privileges", "--no-acl", "-d", $StagingDb, $DumpPath)
$restore = Invoke-Native -Exe $pgRestore -Arguments (@("-U", $SuperUser) + $restoreArgs) -LogFile $restoreLog -SoftFail
$restoreExit = $restore.Code

# pg_restore returns non-zero on NOTICEs/role-missing but that's expected
# Check log for hard errors
$logContent = Get-Content $restoreLog -Raw -ErrorAction SilentlyContinue
if ($logContent -match "FATAL:|ERROR:.*(?<!role .* does not exist)") {
    Write-Warning "Restore log may contain hard errors. Review: $restoreLog"
}
Write-Host "Staging restore complete (exit code: $restoreExit)" -ForegroundColor Green

# =============================================================================
# PHASE 3 — Inspect
# =============================================================================
Write-Banner "PHASE 3 — Inspect Staging"

$inspectPath = Join-Path $prodMirrorDir "inspect_$ts.txt"
$inspectLines = @()
$inspectLines += "PROD-MIRROR INSPECT REPORT"
$inspectLines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$inspectLines += "Staging DB: $StagingDb"
$inspectLines += "Our DB: $DbName"
$inspectLines += "=" * 60
$inspectLines += ""

$srcTenantIds = @{}

foreach ($tbl in $ChainTables) {
    $inspectLines += "--- $tbl ---"

    # Check if table exists in staging
    $existsQ = "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '$tbl')"
    $existsResult = Invoke-Psql -Database $StagingDb -Query $existsQ -TuplesOnly -NoHeaders
    if ($existsResult.Trim() -ne "t") {
        $inspectLines += "  [TABLE NOT IN STAGING]"
        $inspectLines += ""
        continue
    }

    # Count
    $countResult = Invoke-Psql -Database $StagingDb -Query "SELECT count(*) FROM `"$tbl`"" -TuplesOnly -NoHeaders
    $count = $countResult.Trim()
    $inspectLines += "  Count: $count"

    # Distinct TenantIds (if applicable)
    if ($TenantIdTables -contains $tbl) {
        $tenantQ = "SELECT DISTINCT `"TenantId`" FROM `"$tbl`" WHERE `"TenantId`" IS NOT NULL"
        $tenantResult = Invoke-Psql -Database $StagingDb -Query $tenantQ -TuplesOnly -NoHeaders
        $tenants = @($tenantResult | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() })
        $inspectLines += "  Distinct TenantIds: $($tenants -join ', ')"
        foreach ($tid in $tenants) {
            if (-not $srcTenantIds.ContainsKey($tid)) {
                $srcTenantIds[$tid] = @()
            }
            $srcTenantIds[$tid] += $tbl
        }
    } else {
        $inspectLines += "  (no TenantId column)"
    }

    # Column drift
    $stagCols = Get-TableColumns -Database $StagingDb -TableName $tbl
    $ourCols  = Get-TableColumns -Database $DbName    -TableName $tbl
    if ($ourCols.Count -eq 0) {
        $inspectLines += "  [TABLE NOT IN OUR DB]"
    } else {
        $intersection = @($stagCols | Where-Object { $ourCols -contains $_ })
        $stagOnly = @($stagCols | Where-Object { $ourCols -notcontains $_ })
        $ourOnly  = @($ourCols  | Where-Object { $stagCols -notcontains $_ })
        $inspectLines += "  Columns intersection: $($intersection.Count)"
        if ($stagOnly.Count -gt 0) {
            $inspectLines += "  Staging-only cols: $($stagOnly -join ', ')"
        }
        if ($ourOnly.Count -gt 0) {
            $inspectLines += "  Our-only cols: $($ourOnly -join ', ')"
        }
    }
    $inspectLines += ""
}

# Determine source tenant
$inspectLines += "=" * 60
$inspectLines += "SOURCE TENANT ANALYSIS"
$inspectLines += ""

# Find tenant with RTSData_Interaction rows (the client tenant)
$clientTenant = $null
foreach ($tid in $srcTenantIds.Keys) {
    if ($srcTenantIds[$tid] -contains "RTSData_Interaction") {
        $clientTenant = $tid
        break
    }
}

if ($clientTenant) {
    $inspectLines += "CLIENT SOURCE TENANT: $clientTenant"
    $inspectLines += "  (has RTSData_Interaction rows)"
} else {
    $inspectLines += "WARNING: No tenant found with RTSData_Interaction rows"
    $inspectLines += "Available tenants: $($srcTenantIds.Keys -join ', ')"
}

$inspectLines += ""
$inspectLines += "All TenantIds found:"
foreach ($tid in $srcTenantIds.Keys) {
    $inspectLines += "  $tid : $($srcTenantIds[$tid] -join ', ')"
}

# RTSData_* timestamp ranges (for RTM backfill planning)
$inspectLines += ""
$inspectLines += "=" * 60
$inspectLines += "RTSDATA TIMESTAMP RANGES"
$inspectLines += ""

if ($clientTenant) {
    # Check if InQueueDateTime column exists
    $colCheckQ = "SELECT column_name FROM information_schema.columns WHERE table_name = 'RTSData_Interaction' AND column_name = 'InQueueDateTime'"
    $colCheckResult = Invoke-Psql -Database $StagingDb -Query $colCheckQ -TuplesOnly -NoHeaders
    $hasInQueueDateTime = ($colCheckResult | Where-Object { $_ -and $_.Trim() }).Count -gt 0

    if ($hasInQueueDateTime) {
        $tsQ = @"
SELECT
    min("InQueueDateTime"), max("InQueueDateTime"),
    min("AnsweredDateTime"), max("AnsweredDateTime"),
    min("UpdateTime"), max("UpdateTime")
FROM "RTSData_Interaction" WHERE "TenantId" = '$clientTenant'
"@
        $tsResult = Invoke-Psql -Database $StagingDb -Query $tsQ -TuplesOnly -NoHeaders
        $tsParts = ($tsResult | Where-Object { $_ -and $_.Trim() } | Select-Object -First 1)
        if ($tsParts) {
            $tsVals = $tsParts -split '\|'
            if ($tsVals.Count -ge 6) {
                $inspectLines += "RTSData_Interaction InQueueDateTime [min..max]: $($tsVals[0].Trim()) .. $($tsVals[1].Trim())"
                $inspectLines += "RTSData_Interaction AnsweredDateTime [min..max]: $($tsVals[2].Trim()) .. $($tsVals[3].Trim())"
                $inspectLines += "RTSData_Interaction UpdateTime [min..max]: $($tsVals[4].Trim()) .. $($tsVals[5].Trim())"
            }
        }
    } else {
        $inspectLines += "RTSData_Interaction: InQueueDateTime column not found"
    }

    # Check RTSData_UserStatus timestamp columns
    $usColCheckQ = "SELECT column_name FROM information_schema.columns WHERE table_name = 'RTSData_UserStatus' AND column_name IN ('CreatedAt', 'UpdatedAt', 'StatusTime')"
    $usColCheckResult = Invoke-Psql -Database $StagingDb -Query $usColCheckQ -TuplesOnly -NoHeaders
    $usTimestampCols = @($usColCheckResult | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() })
    if ($usTimestampCols.Count -gt 0) {
        foreach ($tsCol in $usTimestampCols) {
            $ustsQ = "SELECT min(`"$tsCol`"), max(`"$tsCol`") FROM `"RTSData_UserStatus`" WHERE `"TenantId`" = '$clientTenant'"
            $ustsResult = Invoke-Psql -Database $StagingDb -Query $ustsQ -TuplesOnly -NoHeaders
            $usParts = ($ustsResult | Where-Object { $_ -and $_.Trim() } | Select-Object -First 1)
            if ($usParts) {
                $usVals = $usParts -split '\|'
                if ($usVals.Count -ge 2) {
                    $inspectLines += "RTSData_UserStatus $tsCol [min..max]: $($usVals[0].Trim()) .. $($usVals[1].Trim())"
                }
            }
        }
    } else {
        $inspectLines += "RTSData_UserStatus: no timestamp columns found"
    }
} else {
    $inspectLines += "WARNING: No client tenant - cannot report timestamp ranges"
}

$inspectLines += ""
$inspectLines += "RE-STAMP POLICY: TenantId-ONLY -- business timestamps (InQueueDateTime/AnsweredDateTime/UpdateTime) are PRESERVED at their ORIGINAL historical values (NOT re-stamped). hist_* backfill must cover the [min,max] above (DEFAULT partition covers old months for the one-time proof)."

# Write inspect report
$inspectLines | Set-Content -Path $inspectPath -Encoding UTF8
Write-Host "Inspect report written: $inspectPath" -ForegroundColor Green

# Display summary
Write-Host "`n--- Inspect Summary ---" -ForegroundColor Yellow
if ($clientTenant) {
    Write-Host "Source client tenant: $clientTenant" -ForegroundColor Green
} else {
    Write-Host "WARNING: No client tenant found!" -ForegroundColor Red
}

if ($srcTenantIds.Keys.Count -gt 1) {
    Write-Host "WARNING: Multiple tenants found in staging ($($srcTenantIds.Keys.Count))." -ForegroundColor Yellow
    Write-Host "         Will use the one with RTSData_Interaction: $clientTenant" -ForegroundColor Yellow
}

# If Mode=Inspect, stop here
if ($Mode -eq "Inspect") {
    Write-Host "`n=== Mode=Inspect: Stopping after Phase 3 ===" -ForegroundColor Cyan
    Write-Host "Review inspect report: $inspectPath"
    Write-Host "To proceed with loading, run with -Mode Load"
    exit 0
}

# =============================================================================
# PHASE 4 — Selective DATA-ONLY Load (Mode=Load only)
# =============================================================================
Write-Banner "PHASE 4 — Load Data"

if (-not $clientTenant) {
    throw "Cannot proceed: no source client tenant identified in staging"
}
$srcTenant = $clientTenant

# Resolve target tenant
if ($TargetTenantId) {
    $targetTenant = $TargetTenantId
    Write-Host "Using explicit TargetTenantId: $targetTenant"
} else {
    # Try to find by slug
    $findQ = "SELECT `"Id`" FROM tenants WHERE `"Slug`" = '$TargetTenantSlug'"
    $findResult = Invoke-Psql -Database $DbName -Query $findQ -TuplesOnly -NoHeaders
    $foundId = ($findResult | Where-Object { $_ -and $_.Trim() } | Select-Object -First 1)
    if ($foundId) {
        $targetTenant = $foundId.Trim()
        Write-Host "Resolved tenant '$TargetTenantSlug' to: $targetTenant"
    } else {
        # Create the tenant
        Write-Host "Tenant '$TargetTenantSlug' not found. Creating..."
        $newTenantId = [guid]::NewGuid().ToString()
        $nowUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss.ffffff")
        $insertTenantQ = @"
INSERT INTO tenants ("Id", "Slug", "Name", "Status", "CreatedAt", "UpdatedAt")
VALUES ('$newTenantId', '$TargetTenantSlug', 'Prod Mirror', 'Active', '$nowUtc', '$nowUtc')
ON CONFLICT ("Slug") DO NOTHING;
"@
        Invoke-Psql -Database $DbName -Query $insertTenantQ | Out-Null

        # Also create tenant_settings
        $insertSettingsQ = @"
INSERT INTO tenant_settings ("TenantId", "PasswordMinLength", "PasswordExpireDays", "Require2faForAll", "AuditRetentionDays", "DefaultLocale", "SoftDeleteDashboards", "SoftDeleteRetentionDays")
VALUES ('$newTenantId', 12, 90, false, 365, 'en-US', true, 90)
ON CONFLICT ("TenantId") DO NOTHING;
"@
        Invoke-Psql -Database $DbName -Query $insertSettingsQ | Out-Null

        $targetTenant = $newTenantId
        Write-Host "Created tenant: $targetTenant"
    }
}

Write-Host "`nSource tenant:  $srcTenant"
Write-Host "Target tenant:  $targetTenant"
Write-Host ""

# Build load SQL
$tempDir = Join-Path $prodMirrorDir "tmp_csv"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Tables to load (exclude queues if not present, RTSData_ChatMessage if no TenantId)
$tablesToLoad = @()
foreach ($tbl in $ChainTables) {
    # Check if table exists in staging with data
    $existsQ = "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '$tbl')"
    $existsResult = Invoke-Psql -Database $StagingDb -Query $existsQ -TuplesOnly -NoHeaders
    if ($existsResult.Trim() -ne "t") {
        Write-Host "  Skipping $tbl (not in staging)" -ForegroundColor DarkGray
        continue
    }

    # Check count for this tenant (or all for non-tenant tables)
    if ($TenantIdTables -contains $tbl) {
        $countQ = "SELECT count(*) FROM `"$tbl`" WHERE `"TenantId`" = '$srcTenant'"
    } else {
        $countQ = "SELECT count(*) FROM `"$tbl`""
    }
    $countResult = Invoke-Psql -Database $StagingDb -Query $countQ -TuplesOnly -NoHeaders
    $count = [int]$countResult.Trim()
    if ($count -eq 0) {
        Write-Host "  Skipping $tbl (0 rows for source tenant)" -ForegroundColor DarkGray
        continue
    }

    $tablesToLoad += @{ Name = $tbl; Count = $count }
}

Write-Host "`nTables to load:"
foreach ($t in $tablesToLoad) {
    Write-Host "  $($t.Name): $($t.Count) rows"
}

# Start transaction SQL
$loadSqlPath = Join-Path $prodMirrorDir "load_$ts.sql"
$loadSql = @()
$loadSql += "-- Prod-Mirror Load SQL"
$loadSql += "-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$loadSql += "-- Source tenant: $srcTenant"
$loadSql += "-- Target tenant: $targetTenant"
$loadSql += ""
$loadSql += "BEGIN;"
$loadSql += "SET session_replication_role = replica;"
$loadSql += ""

# Truncate target rows first
$loadSql += "-- TRUNCATE target tenant rows"
foreach ($t in $tablesToLoad) {
    $tbl = $t.Name
    if ($TenantIdTables -contains $tbl) {
        $loadSql += "DELETE FROM `"$tbl`" WHERE `"TenantId`" = '$targetTenant';"
    } else {
        # Non-tenant table (RTSData_ChatMessage) - truncate all
        $loadSql += "TRUNCATE TABLE `"$tbl`";"
    }
}
$loadSql += ""

# Export CSVs from staging and build COPY commands
foreach ($t in $tablesToLoad) {
    $tbl = $t.Name
    $csvPath = Join-Path $tempDir "$tbl.csv"

    # Get intersection columns
    $intCols = Get-IntersectionColumns -StagingDb $StagingDb -OurDb $DbName -TableName $tbl
    if ($intCols.Count -eq 0) {
        Write-Host "  WARNING: No common columns for $tbl, skipping" -ForegroundColor Yellow
        continue
    }

    # Build SELECT with TenantId re-stamp
    if ($TenantIdTables -contains $tbl) {
        # Replace TenantId with target
        $selectCols = @()
        foreach ($col in $intCols) {
            if ($col -eq "TenantId") {
                $selectCols += "'$targetTenant'::uuid AS `"TenantId`""
            } else {
                $selectCols += "`"$col`""
            }
        }
        $selectExpr = $selectCols -join ", "
        $whereClause = "WHERE `"TenantId`" = '$srcTenant'"
    } else {
        # Non-tenant table - load as-is
        $selectExpr = @($intCols | ForEach-Object { "`"$_`"" }) -join ", "
        $whereClause = ""
    }

    # Export from staging
    $copyToQ = "\copy (SELECT $selectExpr FROM `"$tbl`" $whereClause) TO '$csvPath' WITH (FORMAT csv, HEADER false)"
    Write-Host "  Exporting $tbl..."

    $env:PGPASSWORD = $SuperPassword
    $copyResult = & $psql -U $SuperUser -d $StagingDb -c $copyToQ 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Export failed for $tbl : $copyResult"
    }

    # Build COPY FROM command
    $colList = @($intCols | ForEach-Object { "`"$_`"" }) -join ", "
    $loadSql += "-- Load $tbl"
    $loadSql += "\copy `"$tbl`" ($colList) FROM '$csvPath' WITH (FORMAT csv, HEADER false);"
    $loadSql += ""
}

# ClassificationId integrity check (warning in log, not in SQL)
# We'll check after load

$loadSql += "SET session_replication_role = origin;"
$loadSql += "COMMIT;"
$loadSql += ""
$loadSql += "-- NOTE: hist_* tables are NOT loaded; HistoricalAggregationService re-aggregates on app start"

# Write load SQL
$loadSql | Set-Content -Path $loadSqlPath -Encoding UTF8
Write-Host "`nLoad SQL written: $loadSqlPath"

# Execute load
Write-Host "`nExecuting load..."
Invoke-PsqlFile -Database $DbName -FilePath $loadSqlPath | Out-Null
Write-Host "Load complete!" -ForegroundColor Green

# ClassificationId integrity check
Write-Host "`nChecking ClassificationId integrity..."
$classQ = "SELECT count(*) FROM `"NGC_BusinessUnitQueueClassification`" WHERE `"TenantId`" = '$targetTenant' AND (`"ClassificationId`" IS NULL OR `"ClassificationId`" <> 'ALL')"
$badClassCount = Invoke-Psql -Database $DbName -Query $classQ -TuplesOnly -NoHeaders
$badClassCount = [int]$badClassCount.Trim()
if ($badClassCount -gt 0) {
    Write-Warning "$badClassCount rows in NGC_BusinessUnitQueueClassification do NOT have ClassificationId='ALL'"
    Write-Warning "This may break RTM Queue Grid data flow (CLAUDE.md section 36)"
} else {
    Write-Host "ClassificationId='ALL' integrity OK" -ForegroundColor Green
}

# Cleanup temp CSVs
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# =============================================================================
# PHASE 5 — Verify
# =============================================================================
Write-Banner "PHASE 5 — Verify"

$proofPath = Join-Path $prodMirrorDir "load_proof_$ts.txt"
$proofLines = @()
$proofLines += "PROD-MIRROR LOAD PROOF"
$proofLines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$proofLines += "Source tenant: $srcTenant"
$proofLines += "Target tenant: $targetTenant"
$proofLines += "=" * 60
$proofLines += ""

$allMatch = $true

foreach ($t in $tablesToLoad) {
    $tbl = $t.Name

    # Count in staging (source tenant)
    if ($TenantIdTables -contains $tbl) {
        $stagCountQ = "SELECT count(*) FROM `"$tbl`" WHERE `"TenantId`" = '$srcTenant'"
        $ourCountQ  = "SELECT count(*) FROM `"$tbl`" WHERE `"TenantId`" = '$targetTenant'"
    } else {
        $stagCountQ = "SELECT count(*) FROM `"$tbl`""
        $ourCountQ  = "SELECT count(*) FROM `"$tbl`""
    }

    $stagCount = [int](Invoke-Psql -Database $StagingDb -Query $stagCountQ -TuplesOnly -NoHeaders).Trim()
    $ourCount  = [int](Invoke-Psql -Database $DbName    -Query $ourCountQ  -TuplesOnly -NoHeaders).Trim()

    $match = if ($stagCount -eq $ourCount) { "OK" } else { "MISMATCH"; $allMatch = $false }
    $proofLines += "$tbl : staging=$stagCount, target=$ourCount [$match]"
}

$proofLines += ""
$proofLines += "=" * 60
$proofLines += "BU-PG SCOPE CHAIN VERIFICATION"
$proofLines += ""

# Pick one permission_group on target tenant
$pgQ = "SELECT `"Id`", `"Name`" FROM permission_groups WHERE `"TenantId`" = '$targetTenant' AND `"IsActive`" = true LIMIT 1"
$pgResult = Invoke-Psql -Database $DbName -Query $pgQ -TuplesOnly -NoHeaders
$pgLine = ($pgResult | Where-Object { $_ -and $_.Trim() } | Select-Object -First 1)

if ($pgLine) {
    $pgParts = $pgLine -split '\|'
    $pgId = $pgParts[0].Trim()
    $pgName = $pgParts[1].Trim()
    $proofLines += "Sample Permission Group: $pgName ($pgId)"

    # pg_business_units -> NGC_BusinessUnit
    $buQ = @"
SELECT bu."BusinessUnitId", bu."BusinessUnitName"
FROM pg_business_units pbu
JOIN "NGC_BusinessUnit" bu ON bu."BusinessUnitId" = pbu."BusinessUnitId" AND bu."TenantId" = pbu."TenantId"
WHERE pbu."PermissionGroupId" = '$pgId'
LIMIT 3
"@
    $buResult = Invoke-Psql -Database $DbName -Query $buQ -TuplesOnly -NoHeaders
    $bus = @($buResult | Where-Object { $_ -and $_.Trim() })
    $proofLines += "  BUs via pg_business_units: $($bus.Count)"

    if ($bus.Count -gt 0) {
        $buId = ($bus[0] -split '\|')[0].Trim()

        # NGC_BusinessUnitQueueClassification -> queues
        $qQ = @"
SELECT q."ExternalId", q."Name", (SELECT count(*) FROM "RTSData_Interaction" i WHERE i."Workgroup" = q."ExternalId") as interactions
FROM "NGC_BusinessUnitQueueClassification" bqc
JOIN "NGC_Queues" q ON q."QueueId" = bqc."QueueId" AND q."TenantId" = bqc."TenantId"
WHERE bqc."BusinessUnitId" = $buId AND bqc."TenantId" = '$targetTenant'
LIMIT 3
"@
        $qResult = Invoke-Psql -Database $DbName -Query $qQ -TuplesOnly -NoHeaders
        $qs = @($qResult | Where-Object { $_ -and $_.Trim() })
        $proofLines += "  Queues via BU $buId : $($qs.Count)"
        foreach ($qLine in $qs) {
            $proofLines += "    $qLine"
        }

        # NGC_BusinessUnitSupergroup -> NGC_SupergroupAgentgroup -> agents
        $agQ = @"
SELECT ag."AgentGroupId", ag."AgentGroupName",
       (SELECT count(*) FROM "NGC_UserAgentgroup" uag WHERE uag."AgentgroupId" = ag."AgentGroupId") as agents,
       (SELECT count(*) FROM "RTSData_UserStatus" us
        JOIN "NGC_UserAgentgroup" uag2 ON uag2."UserId" = us."UserId"
        WHERE uag2."AgentgroupId" = ag."AgentGroupId") as statuses
FROM "NGC_BusinessUnitSupergroup" bus
JOIN "NGC_SupergroupAgentgroup" sag ON sag."SupergroupId" = bus."SupergroupId"
JOIN "NGC_AgentGroups" ag ON ag."AgentGroupId" = sag."AgentgroupId" AND ag."TenantId" = bus."TenantId"
WHERE bus."BusinessUnitId" = $buId AND bus."TenantId" = '$targetTenant'
LIMIT 3
"@
        $agResult = Invoke-Psql -Database $DbName -Query $agQ -TuplesOnly -NoHeaders
        $ags = @($agResult | Where-Object { $_ -and $_.Trim() })
        $proofLines += "  AgentGroups via BU $buId : $($ags.Count)"
        foreach ($agLine in $ags) {
            $proofLines += "    $agLine"
        }
    }
} else {
    $proofLines += "WARNING: No active permission_group found on target tenant"
    $allMatch = $false
}

$proofLines += ""
$proofLines += "=" * 60
if ($allMatch) {
    $proofLines += "RESULT: ALL CHECKS PASSED"
} else {
    $proofLines += "RESULT: SOME CHECKS FAILED - REVIEW ABOVE"
}

# Write proof
$proofLines | Set-Content -Path $proofPath -Encoding UTF8
Write-Host "Proof report written: $proofPath"

if (-not $allMatch) {
    Write-Host "`nWARNING: Some verification checks failed!" -ForegroundColor Red
    Write-Host "Review: $proofPath"
    exit 1
}

Write-Host "`n=== LOAD COMPLETE ===" -ForegroundColor Green
Write-Host "Source: $srcTenant -> Target: $targetTenant"
Write-Host "Backup: $backupPath"
Write-Host "Proof:  $proofPath"
