#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs RTM as a Windows Service.
.DESCRIPTION
    Idempotent installation script for RTM on Windows Server.
    Creates directories, registers service, configures recovery.
.PARAMETER InstallPath
    Installation directory (default: C:\Program Files\RTM)
.PARAMETER ServiceName
    Windows Service name (default: RTMService)
.PARAMETER Port
    HTTP port for RTM API (default: 8088)
.EXAMPLE
    .\Install-RTM.ps1 -InstallPath "D:\RTM" -ServiceName "RTM" -Port 8080
#>

[CmdletBinding()]
param(
    [string]$InstallPath = "C:\Program Files\RTM",
    [string]$ServiceName = "RTMService",
    [int]$Port = 8088
)

$ErrorActionPreference = 'Stop'

Write-Host "=== RTM Service Installation ===" -ForegroundColor Cyan
Write-Host "Install Path: $InstallPath"
Write-Host "Service Name: $ServiceName"
Write-Host "Port: $Port"
Write-Host ""

# Check Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator. Right-click PowerShell and select 'Run as Administrator'."
    exit 1
}

# Check .NET Runtime (informational for self-contained)
$dotnetInfo = dotnet --list-runtimes 2>$null | Select-String "Microsoft.AspNetCore.App 8"
if (-not $dotnetInfo) {
    Write-Host "WARNING: .NET 8 ASP.NET Core Runtime not detected." -ForegroundColor Yellow
    Write-Host "         Self-contained deployment will still work." -ForegroundColor Yellow
}

# Create log directory
$LogPath = "D:\IceDash\Logs\RTMLogs\Logs"
if (-not (Test-Path $LogPath)) {
    Write-Host "Creating log directory: $LogPath" -ForegroundColor Green
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

# Create install directory
if (-not (Test-Path $InstallPath)) {
    Write-Host "Creating install directory: $InstallPath" -ForegroundColor Green
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}

# Copy published files (assumes publish folder exists in same directory as script)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PublishDir = Join-Path $ScriptDir "publish"

if (-not (Test-Path $PublishDir)) {
    Write-Error "Publish directory not found: $PublishDir`nRun Publish-RTM.ps1 first."
    exit 1
}

Write-Host "Copying files to $InstallPath..." -ForegroundColor Green
Copy-Item -Path "$PublishDir\*" -Destination $InstallPath -Recurse -Force

# Check required secret files
$requiredFiles = @("app.dat", "data.sys")
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $InstallPath $file
    if (-not (Test-Path $filePath)) {
        Write-Error "Required file missing: $file`nCopy $file to $InstallPath before installation."
        exit 1
    }
}
Write-Host "Secret files verified: app.dat, data.sys" -ForegroundColor Green

# Stop existing service if running
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Stopping existing service..." -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Remove existing service registration
if ($existingService) {
    Write-Host "Removing existing service registration..." -ForegroundColor Yellow
    sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

# Register Windows Service
$exePath = Join-Path $InstallPath "RTM.exe"
Write-Host "Registering Windows Service..." -ForegroundColor Green

sc.exe create $ServiceName binPath= "`"$exePath`"" start= auto | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create service. Exit code: $LASTEXITCODE"
    exit 1
}

sc.exe description $ServiceName "RTM Real-Time Monitoring Service" | Out-Null

# Configure service recovery (restart on failure)
Write-Host "Configuring service recovery..." -ForegroundColor Green
sc.exe failure $ServiceName reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null

# Start service
Write-Host "Starting service..." -ForegroundColor Green
Start-Service -Name $ServiceName

# Wait and check status
Write-Host "Waiting for service to start..." -ForegroundColor Gray
Start-Sleep -Seconds 10

$service = Get-Service -Name $ServiceName
$status = $service.Status

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Cyan
Write-Host "Install Path:  $InstallPath"
Write-Host "Service Name:  $ServiceName"
Write-Host "Service Status: $status"
Write-Host "Port:          $Port"
Write-Host "Log Path:      $LogPath"
Write-Host ""

if ($status -eq "Running") {
    Write-Host "RTM Service is running successfully!" -ForegroundColor Green
} else {
    Write-Host "WARNING: Service is not running. Check logs at $LogPath" -ForegroundColor Yellow
}
