#Requires -Version 5.1
<#
.SYNOPSIS
    Builds a production release package for RTM service.
.DESCRIPTION
    Publishes RTM as self-contained win-x64, copies config files,
    and creates a versioned ZIP package.
.EXAMPLE
    .\Publish-RTM.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RTMRoot = Split-Path -Parent $ScriptDir
$ProjectPath = Join-Path $RTMRoot "RTM\RTM.csproj"
$PublishDir = Join-Path $ScriptDir "publish"

# Get version from csproj
[xml]$csproj = Get-Content $ProjectPath
$version = $csproj.Project.PropertyGroup.AssemblyVersion
if (-not $version) { $version = "1.0.0" }

$date = Get-Date -Format "yyyyMMdd"
$zipName = "RTM_v${version}_${date}.zip"

Write-Host "=== RTM Production Build ===" -ForegroundColor Cyan
Write-Host "Version: $version"
Write-Host "Output: $PublishDir"

# Clean publish directory
if (Test-Path $PublishDir) {
    Write-Host "Cleaning previous publish..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $PublishDir
}

# Publish
Write-Host "Publishing RTM (self-contained, win-x64)..." -ForegroundColor Green
dotnet publish $ProjectPath -c Release -r win-x64 --self-contained true -o $PublishDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "Publish failed with exit code $LASTEXITCODE"
    exit 1
}

# Copy config files (excluding secrets)
$configFiles = @("appsettings.json", "log4net.config")
foreach ($cfg in $configFiles) {
    $src = Join-Path $RTMRoot "RTM\$cfg"
    if (Test-Path $src) {
        Copy-Item $src -Destination $PublishDir -Force
        Write-Host "Copied: $cfg" -ForegroundColor Gray
    }
}

# Create ZIP
$zipPath = Join-Path $ScriptDir $zipName
Write-Host "Creating package: $zipName" -ForegroundColor Green
Compress-Archive -Path "$PublishDir\*" -DestinationPath $zipPath -Force

$zipSize = (Get-Item $zipPath).Length / 1MB
Write-Host ""
Write-Host "=== Build Complete ===" -ForegroundColor Cyan
Write-Host "Package: $zipPath"
Write-Host "Size: $([math]::Round($zipSize, 2)) MB"
Write-Host ""
Write-Host "=== MANUAL FILES REQUIRED ===" -ForegroundColor Yellow
Write-Host "The following files contain secrets and must be provided manually:"
Write-Host "  - app.dat      (encrypted configuration)"
Write-Host "  - data.sys     (license/encryption data)"
Write-Host ""
Write-Host "Copy these files to the target server's install directory."
