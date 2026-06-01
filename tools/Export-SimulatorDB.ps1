# Export-SimulatorDB.ps1
# Dumps the current development database into a custom-format pg_dump file
# for inclusion in the simulator installation package.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools\Export-SimulatorDB.ps1 -DBPassword "yourpwd"
#
# If pg_dump is not on PATH, specify its directory explicitly:
#   powershell -ExecutionPolicy Bypass -File tools\Export-SimulatorDB.ps1 `
#       -DBPassword "yourpwd" -PGBinPath "C:\Program Files\PostgreSQL\17\bin"

[CmdletBinding()]
param(
    [string]$DBHost     = "localhost",
    [int]   $DBPort     = 5432,
    [string]$DBName     = "rtmviewdb",
    [string]$DBUser     = "ccdashboard_user",
    [string]$DBPassword = "",

    # Explicit path to PostgreSQL bin directory (e.g. "C:\Program Files\PostgreSQL\17\bin")
    # Leave empty to auto-detect.
    [string]$PGBinPath  = "",

    [string]$OutputFile = ""   # default: tools\simulator_db.dump
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ToolsDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($OutputFile)) {
    $OutputFile = Join-Path $ToolsDir "simulator_db.dump"
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  RTM View Shell -- Export Simulator DB"           -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# ---- 1. Locate pg_dump ------------------------------------------------------
function Find-PGDump {
    # 1a. Explicit parameter wins
    if (-not [string]::IsNullOrWhiteSpace($PGBinPath)) {
        $p = Join-Path $PGBinPath "pg_dump.exe"
        if (Test-Path $p) { return $p }
        Write-Error "pg_dump.exe not found in -PGBinPath '$PGBinPath'"
    }

    # 1b. Already on PATH
    $cmd = Get-Command pg_dump -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # 1c. Common install locations (versions 12-18, both Program Files variants)
    $candidates = @()
    foreach ($ver in 18, 17, 16, 15, 14, 13, 12) {
        $candidates += "C:\Program Files\PostgreSQL\$ver\bin\pg_dump.exe"
        $candidates += "C:\Program Files (x86)\PostgreSQL\$ver\bin\pg_dump.exe"
    }
    # Also check EDB default location under ProgramData
    $candidates += "C:\edb\pg16\bin\pg_dump.exe"
    $candidates += "C:\edb\pg15\bin\pg_dump.exe"

    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }

    # 1d. Search registry for PostgreSQL installation
    $regRoots = @(
        "HKLM:\SOFTWARE\PostgreSQL\Installations",
        "HKLM:\SOFTWARE\WOW6432Node\PostgreSQL\Installations"
    )
    foreach ($root in $regRoots) {
        if (Test-Path $root) {
            Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
                $base = (Get-ItemProperty $_.PSPath -Name "Base Directory" -ErrorAction SilentlyContinue)."Base Directory"
                if ($base) {
                    $p = Join-Path $base "bin\pg_dump.exe"
                    if (Test-Path $p) { return $p }
                }
            }
        }
    }

    # 1e. Filesystem search under Program Files (slow, last resort)
    Write-Host "Searching filesystem for pg_dump.exe (this may take a moment)..." -ForegroundColor Yellow
    $found = Get-ChildItem "C:\Program Files\PostgreSQL" -Filter "pg_dump.exe" `
                -Recurse -ErrorAction SilentlyContinue |
             Select-Object -First 1 -ExpandProperty FullName
    if ($found) { return $found }

    return $null
}

$pgDump = Find-PGDump
if (-not $pgDump) {
    Write-Host ""
    Write-Host "pg_dump.exe was not found automatically." -ForegroundColor Red
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  1. Add PostgreSQL bin to PATH, then re-run this script."
    Write-Host "  2. Pass the bin directory explicitly:"
    Write-Host '     -PGBinPath "C:\Program Files\PostgreSQL\<version>\bin"'
    Write-Host ""
    Write-Host "To find your PostgreSQL installation:"
    Write-Host '  Get-ChildItem "C:\Program Files\PostgreSQL" -Recurse -Filter pg_dump.exe'
    Write-Host ""
    exit 1
}
Write-Host "pg_dump: $pgDump" -ForegroundColor Gray

# ---- 2. Password ------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($DBPassword)) {
    $secPwd = Read-Host "Enter PostgreSQL password for user '$DBUser'" -AsSecureString
    $DBPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPwd))
}

# ---- 3. Run pg_dump (custom format) -----------------------------------------
# -F c : custom format (compressed, supports pg_restore -j parallel)
# --no-owner : omit ALTER OWNER statements
# --no-acl   : omit GRANT/REVOKE statements
# -v         : verbose output

Write-Host "Dumping '$DBName' from ${DBHost}:${DBPort} as '$DBUser'..."

$env:PGPASSWORD = $DBPassword
try {
    & $pgDump `
        -h $DBHost `
        -p $DBPort `
        -U $DBUser `
        -d $DBName `
        -F c `
        --no-owner `
        --no-acl `
        -v `
        -f $OutputFile

    if ($LASTEXITCODE -ne 0) {
        Write-Error "pg_dump failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}

$sizeMB = [math]::Round((Get-Item $OutputFile).Length / 1MB, 2)
Write-Host ""
Write-Host "Dump complete: $OutputFile ($sizeMB MB)" -ForegroundColor Green
Write-Host ""
Write-Host "Next: run Build-SimulatorPackage.ps1 to include this dump in the ZIP." -ForegroundColor White
Write-Host ""
