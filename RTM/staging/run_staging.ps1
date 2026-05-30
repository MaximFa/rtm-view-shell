<#
.SYNOPSIS
    RTM Backend PostgreSQL Staging Deployment Script

.DESCRIPTION
    Automates the full staging setup for RTM PostgreSQL migration:
    1. Tests PostgreSQL connectivity
    2. Runs EF migrations (BackendEmulationDbContext)
    3. Deploys PL/pgSQL functions
    4. Runs pgloader for data migration
    5. Runs verification queries
    6. Prints summary

.PARAMETER PgHost
    PostgreSQL host (default: localhost)

.PARAMETER PgPort
    PostgreSQL port (default: 5432)

.PARAMETER PgDb
    PostgreSQL database name (default: cc_rtm_staging)

.PARAMETER PgUser
    PostgreSQL user (default: cc_rtm_app)

.PARAMETER PgPassword
    PostgreSQL password (required)

.PARAMETER MssqlConn
    SQL Server connection string for pgloader (e.g., mssql://sa:password@localhost/H_RTM)

.PARAMETER PgloaderPath
    Path to pgloader executable (default: pgloader in PATH)

.PARAMETER SkipEfMigrations
    Skip EF migrations step (use if already applied)

.PARAMETER SkipPgloader
    Skip pgloader data migration step

.EXAMPLE
    .\run_staging.ps1 -PgPassword "changeme" -MssqlConn "mssql://sa:SqlPass123@localhost/H_RTM"
#>

[CmdletBinding()]
param(
    [string]$PgHost = "localhost",
    [int]$PgPort = 5432,
    [string]$PgDb = "cc_rtm_staging",
    [string]$PgUser = "cc_rtm_app",
    [Parameter(Mandatory=$true)]
    [string]$PgPassword,
    [string]$MssqlConn = "",
    [string]$PgloaderPath = "pgloader",
    [switch]$SkipEfMigrations,
    [switch]$SkipPgloader
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ResultsDir = Join-Path $ScriptDir "results"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmm"

# Ensure results directory exists
if (-not (Test-Path $ResultsDir)) {
    New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n>>> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "    OK: $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "    FAIL: $Message" -ForegroundColor Red
}

function Exit-WithError {
    param([string]$Message)
    Write-Fail $Message
    Write-Host "`nStaging deployment FAILED. Check output above for details." -ForegroundColor Red
    exit 1
}

# Build PostgreSQL connection string for psql
$env:PGPASSWORD = $PgPassword
$PsqlArgs = @("-h", $PgHost, "-p", $PgPort, "-U", $PgUser, "-d", $PgDb)

Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "RTM Backend PostgreSQL Staging Deployment" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "PostgreSQL: ${PgUser}@${PgHost}:${PgPort}/${PgDb}"
Write-Host "Project Root: $ProjectRoot"
Write-Host "Timestamp: $Timestamp"

# ============================================================================
# STEP 1: Test PostgreSQL connectivity
# ============================================================================
Write-Step "Step 1: Testing PostgreSQL connectivity"

try {
    $testResult = & psql @PsqlArgs -c "SELECT 1 AS connectivity_test;" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Cannot connect to PostgreSQL: $testResult"
    }
    Write-Success "PostgreSQL connection successful"
}
catch {
    Exit-WithError "psql not found or connection failed: $_"
}

# ============================================================================
# STEP 2: Run EF migrations
# ============================================================================
if (-not $SkipEfMigrations) {
    Write-Step "Step 2: Running EF migrations (BackendEmulationDbContext)"

    # Build connection string for EF
    $EfConnString = "Host=$PgHost;Port=$PgPort;Database=$PgDb;Username=$PgUser;Password=$PgPassword"
    $env:ASPNETCORE_ConnectionStrings__BackendEmulation = $EfConnString

    Push-Location $ProjectRoot
    try {
        $efResult = & dotnet ef database update `
            --context BackendEmulationDbContext `
            --project src/CcDashboard.Infrastructure `
            --startup-project src/CcDashboard.Web 2>&1

        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Exit-WithError "EF migrations failed: $efResult"
        }
        Write-Success "EF migrations applied successfully"
    }
    catch {
        Pop-Location
        Exit-WithError "EF migrations failed: $_"
    }
    Pop-Location
}
else {
    Write-Step "Step 2: Skipping EF migrations (--SkipEfMigrations)"
}

# ============================================================================
# STEP 3: Deploy PL/pgSQL functions
# ============================================================================
Write-Step "Step 3: Deploying PL/pgSQL functions"

$FunctionsScript = Join-Path $ScriptDir "00_deploy_all_functions.sql"
if (-not (Test-Path $FunctionsScript)) {
    Exit-WithError "Functions script not found: $FunctionsScript"
}

try {
    $deployResult = & psql @PsqlArgs -f $FunctionsScript 2>&1
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError "Function deployment failed: $deployResult"
    }

    # Verify function count
    $countResult = & psql @PsqlArgs -t -c "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname LIKE ANY(ARRAY['ngc_%', 'rts%']);"
    $funcCount = [int]$countResult.Trim()

    if ($funcCount -ge 37) {
        Write-Success "37 functions deployed (verified: $funcCount)"
    }
    else {
        Write-Fail "Expected 37 functions, found $funcCount"
    }
}
catch {
    Exit-WithError "Function deployment failed: $_"
}

# ============================================================================
# STEP 4: Run pgloader (data migration)
# ============================================================================
if (-not $SkipPgloader) {
    if ([string]::IsNullOrEmpty($MssqlConn)) {
        Write-Step "Step 4: Skipping pgloader (no -MssqlConn provided)"
        Write-Host "    To run data migration, provide: -MssqlConn 'mssql://sa:password@host/database'" -ForegroundColor Yellow
    }
    else {
        Write-Step "Step 4: Running pgloader data migration"

        # Create temp copy of pgloader config with actual credentials
        $PgloaderSource = Join-Path (Split-Path -Parent $ScriptDir) "sql\pgloader\rtm_staging.load"
        $PgloaderTemp = Join-Path $env:TEMP "rtm_staging_run.load"

        if (-not (Test-Path $PgloaderSource)) {
            Exit-WithError "pgloader config not found: $PgloaderSource"
        }

        # Read and replace placeholders
        $pgloaderContent = Get-Content $PgloaderSource -Raw
        $pgloaderContent = $pgloaderContent -replace 'mssql://sa:YOUR_SQL_SERVER_PASSWORD@localhost/H_RTM', $MssqlConn
        $pgloaderContent = $pgloaderContent -replace 'postgresql://cc_rtm_app:changeme@localhost/cc_rtm_staging', "postgresql://${PgUser}:${PgPassword}@${PgHost}:${PgPort}/${PgDb}"
        $pgloaderContent | Set-Content $PgloaderTemp -Encoding UTF8

        try {
            $pgloaderResult = & $PgloaderPath $PgloaderTemp 2>&1
            if ($LASTEXITCODE -ne 0) {
                Exit-WithError "pgloader failed: $pgloaderResult"
            }
            Write-Success "pgloader completed"
        }
        catch {
            Exit-WithError "pgloader failed: $_"
        }
        finally {
            # Clean up temp file
            if (Test-Path $PgloaderTemp) {
                Remove-Item $PgloaderTemp -Force
            }
        }
    }
}
else {
    Write-Step "Step 4: Skipping pgloader (--SkipPgloader)"
}

# ============================================================================
# STEP 5: Run verification queries
# ============================================================================
Write-Step "Step 5: Running verification queries"

$VerifyScript = Join-Path (Split-Path -Parent $ScriptDir) "sql\pgloader\verify_migration.sql"
$VerifyOutput = Join-Path $ResultsDir "verify_${Timestamp}.txt"

if (-not (Test-Path $VerifyScript)) {
    Write-Fail "Verification script not found: $VerifyScript"
    Write-Host "    Skipping verification step" -ForegroundColor Yellow
}
else {
    try {
        & psql @PsqlArgs -f $VerifyScript 2>&1 | Tee-Object -FilePath $VerifyOutput
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Verification queries had errors"
        }
        else {
            Write-Success "Verification complete. Results saved to: $VerifyOutput"
        }
    }
    catch {
        Write-Fail "Verification failed: $_"
    }
}

# ============================================================================
# STEP 6: Print summary
# ============================================================================
Write-Step "Step 6: Summary"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "STAGING DEPLOYMENT SUMMARY" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

# Get row counts for key tables
$tables = @("NGC_Site", "NGC_BusinessUnit", "RTSGrid_Grid", "RTSGrid_Metric", "RTSData_Interaction", "RTSData_UserStatus")
Write-Host "`nTable Row Counts:" -ForegroundColor Cyan

foreach ($table in $tables) {
    try {
        $count = & psql @PsqlArgs -t -c "SELECT COUNT(*) FROM `"$table`";" 2>$null
        $count = if ($count) { $count.Trim() } else { "ERROR" }
        Write-Host "    $table : $count"
    }
    catch {
        Write-Host "    $table : ERROR" -ForegroundColor Red
    }
}

# Function count
Write-Host "`nFunction Count:" -ForegroundColor Cyan
try {
    $funcCount = & psql @PsqlArgs -t -c "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname LIKE ANY(ARRAY['ngc_%', 'rts%']);"
    Write-Host "    PL/pgSQL functions: $($funcCount.Trim())"
}
catch {
    Write-Host "    PL/pgSQL functions: ERROR" -ForegroundColor Red
}

Write-Host ""
Write-Host "Results file: $VerifyOutput" -ForegroundColor Cyan
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "STAGING DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

# Clean up
$env:PGPASSWORD = ""
$env:ASPNETCORE_ConnectionStrings__BackendEmulation = ""
