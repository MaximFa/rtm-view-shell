#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Idempotent installer for RTM View Shell on Windows Server / IIS [DEPLOY-14].
.DESCRIPTION
    Creates IIS sites, application pools, HTTPS bindings, unpacks the publish zip,
    sets NTFS ACLs, and runs EF Core migrations.
.PARAMETER ZipPath
    Path to the self-contained publish zip (e.g. web-publish.zip).
.PARAMETER SiteName
    IIS site name (default: CcDashboard.Web).
.PARAMETER AppPath
    Installation directory (default: C:\Program Files\CcDashboard\web).
.PARAMETER HostHeader
    Hostname for IIS binding (e.g. *.cc-dashboard.local).
.PARAMETER CertThumbprint
    Thumbprint of the TLS certificate in LocalMachine\My.
.PARAMETER Port
    HTTPS port (default: 443).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ZipPath,

    [string]$SiteName       = "CcDashboard.Web",
    [string]$AppPath        = "C:\Program Files\CcDashboard\web",
    [string]$HostHeader     = "*.cc-dashboard.local",
    [string]$CertThumbprint = "",
    [int]$Port              = 443
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== RTM View Shell Installer ===" -ForegroundColor Cyan

# 1. Prerequisites
Write-Host "[1/7] Checking prerequisites..."
Import-Module WebAdministration -ErrorAction Stop

# 2. Create service account if needed
$svcUser = "IIS AppPool\CcDashboard"
Write-Host "[2/7] Service account: $svcUser (uses AppPool identity)"

# 3. Unpack application
Write-Host "[3/7] Unpacking to $AppPath..."
if (-not (Test-Path $AppPath)) { New-Item -ItemType Directory -Path $AppPath -Force | Out-Null }
Expand-Archive -Path $ZipPath -DestinationPath $AppPath -Force
Write-Host "      Unpacked OK"

# 4. Set NTFS ACLs
Write-Host "[4/7] Setting NTFS permissions..."
$acl = Get-Acl $AppPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $svcUser, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.SetAccessRule($rule)
# Allow write to logs subdirectory
$logsPath = Join-Path $AppPath "logs"
if (-not (Test-Path $logsPath)) { New-Item -ItemType Directory -Path $logsPath -Force | Out-Null }
$logAcl = Get-Acl $logsPath
$writeRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $svcUser, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
$logAcl.SetAccessRule($writeRule)
Set-Acl $logsPath $logAcl

# 5. Create/update IIS Application Pool
Write-Host "[5/7] Configuring IIS Application Pool..."
$poolName = $SiteName
if (-not (Test-Path "IIS:\AppPools\$poolName"))
{
    New-WebAppPool -Name $poolName
    Write-Host "      Created pool: $poolName"
}
Set-ItemProperty "IIS:\AppPools\$poolName" -Name managedRuntimeVersion -Value ""
Set-ItemProperty "IIS:\AppPools\$poolName" -Name startMode -Value "AlwaysRunning"
Set-ItemProperty "IIS:\AppPools\$poolName" -Name autoStart -Value $true
Set-ItemProperty "IIS:\AppPools\$poolName" processModel.idleTimeout -Value "00:00:00"
Write-Host "      Pool configured (No Managed Code, idle timeout = 0)"

# 6. Create/update IIS Site
Write-Host "[6/7] Configuring IIS Site..."
if (-not (Test-Path "IIS:\Sites\$SiteName"))
{
    if ($CertThumbprint)
    {
        New-Website -Name $SiteName -PhysicalPath $AppPath -ApplicationPool $poolName `
            -Ssl -Port $Port -HostHeader $HostHeader
        $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $CertThumbprint }
        if ($cert)
        {
            New-WebBinding -Name $SiteName -Protocol "https" -Port $Port -HostHeader $HostHeader -SslFlags 1
            $binding = Get-WebBinding -Name $SiteName -Protocol "https"
            $binding.AddSslCertificate($CertThumbprint, "My")
        }
    }
    else
    {
        New-Website -Name $SiteName -PhysicalPath $AppPath -ApplicationPool $poolName -Port $Port
    }
    Write-Host "      Created site: $SiteName"
}
else
{
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $AppPath
    Write-Host "      Updated site physical path"
}

# Enable WebSocket protocol (required for SignalR/Blazor)
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebSockets -NoRestart -ErrorAction SilentlyContinue

# 7. Apply EF Core migrations
Write-Host "[7/7] Applying database migrations..."
$exe = Join-Path $AppPath "CcDashboard.Web.exe"
if (Test-Path $exe)
{
    & $exe migrate
    if ($LASTEXITCODE -ne 0) { Write-Error "Migration failed (exit code $LASTEXITCODE)" }
    else { Write-Host "      Migrations applied OK" }
}
else
{
    Write-Warning "      Executable not found at $exe — run migrations manually."
}

Write-Host ""
Write-Host "=== Installation complete ===" -ForegroundColor Green
Write-Host "Start the site: Start-Website '$SiteName'"
