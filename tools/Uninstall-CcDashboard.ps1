# Uninstall-CcDashboard.ps1
# Stops and removes both CcDashboard Windows Services.
# Must be run as Administrator.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File Uninstall-CcDashboard.ps1
#   powershell -ExecutionPolicy Bypass -File Uninstall-CcDashboard.ps1 -RemoveFiles -RemoveData

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ServiceName         = "CcDashboard",
    [string]$SignalRServiceName  = "CcDashboardSignalR",
    [string]$InstallPath         = "C:\Program Files\CcDashboard",

    # Deletes the installation directory after removing the services.
    [switch]$RemoveFiles,

    # Drops the PostgreSQL database (requires psql on PATH).
    [switch]$RemoveData,
    [string]$DBHost = "localhost",
    [int]   $DBPort = 5432,
    [string]$DBName = "rtmviewdb",
    [string]$DBUser = "postgres"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Yellow
Write-Host "  RTM View Shell -- Uninstall"                    -ForegroundColor Yellow
Write-Host "=================================================" -ForegroundColor Yellow
Write-Host ""

# ---- Stop and remove services -----------------------------------------------
foreach ($svcName in @($ServiceName, $SignalRServiceName)) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -ne 'Stopped') {
            Write-Host "Stopping '$svcName'..." -ForegroundColor Yellow
            Stop-Service -Name $svcName -Force
            Start-Sleep 3
        }
        Write-Host "Removing service '$svcName'..."
        sc.exe delete $svcName | Out-Null
        Write-Host "  removed." -ForegroundColor Green
    } else {
        Write-Host "Service '$svcName' not found -- skipping." -ForegroundColor Gray
    }
}

# ---- Remove files -----------------------------------------------------------
if ($RemoveFiles) {
    if (Test-Path $InstallPath) {
        if ($PSCmdlet.ShouldProcess($InstallPath, "Remove installation directory")) {
            Write-Host "Removing: $InstallPath"
            Remove-Item $InstallPath -Recurse -Force
            Write-Host "Files removed." -ForegroundColor Green
        }
    } else {
        Write-Host "Path '$InstallPath' not found -- skipping." -ForegroundColor Gray
    }
} else {
    Write-Host ""
    Write-Host "Files kept at: $InstallPath" -ForegroundColor Gray
    Write-Host "To remove: Uninstall-CcDashboard.ps1 -RemoveFiles" -ForegroundColor Gray
}

# ---- Drop database ----------------------------------------------------------
if ($RemoveData) {
    Write-Host ""
    Write-Warning "About to DROP database '$DBName'. This is irreversible."
    $confirm = Read-Host "Type 'yes' to confirm"
    if ($confirm -eq 'yes') {
        $psql = Get-Command psql -ErrorAction SilentlyContinue
        if ($psql) {
            psql -h $DBHost -p $DBPort -U $DBUser -c "DROP DATABASE IF EXISTS `"$DBName`";"
            Write-Host "Database dropped." -ForegroundColor Green
        } else {
            Write-Warning "psql not found. Drop manually:"
            Write-Host "  psql -U postgres -c `"DROP DATABASE IF EXISTS \`"$DBName\`";\`"" -ForegroundColor Gray
        }
    } else {
        Write-Host "Database removal cancelled." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Uninstall complete." -ForegroundColor Green
Write-Host ""
