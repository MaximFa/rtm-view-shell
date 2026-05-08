#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Idempotent installer for RTM View Shell on Windows Server (Kestrel + Windows Service) [DEPLOY-14].
.DESCRIPTION
    Creates a dedicated service account, unpacks the publish zip, sets NTFS ACLs,
    configures Kestrel HTTPS, registers a Windows Service, opens firewall ports,
    and runs EF Core migrations.
.PARAMETER ZipPath
    Path to the self-contained publish zip (e.g. web-publish.zip).
.PARAMETER AppPath
    Installation directory (default: C:\Program Files\CcDashboard\web).
.PARAMETER ServiceName
    Windows Service name (default: CcDashboard).
.PARAMETER Domain
    Base domain, e.g. cc-dashboard.local — used only in configuration hints.
.PARAMETER CertSubject
    Subject (CN) of the wildcard TLS certificate in LocalMachine\My, e.g. *.cc-dashboard.local
.PARAMETER Port
    HTTPS port (default: 443).
.PARAMETER HttpPort
    HTTP port for redirect (default: 80).
.PARAMETER SvcPassword
    Password for the CcDashboardSvc local account. If empty, a random one is generated.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ZipPath,

    [string]$AppPath       = "C:\Program Files\CcDashboard\web",
    [string]$ServiceName   = "CcDashboard",
    [string]$Domain        = "cc-dashboard.local",
    [string]$CertSubject    = "",
    [int]$Port             = 443,
    [int]$HttpPort         = 80,
    [string]$SvcPassword   = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== RTM View Shell Installer (Kestrel + Windows Service) ===" -ForegroundColor Cyan

# ── 1. Prerequisites ──────────────────────────────────────────────────────────
Write-Host "[1/8] Checking prerequisites..."
$dotnetVersion = & dotnet --version 2>$null
if (-not $dotnetVersion) { Write-Error ".NET Runtime not found. Install the .NET 8 Hosting Bundle." }
Write-Host "      .NET $dotnetVersion found"

# ── 2. Service account ────────────────────────────────────────────────────────
Write-Host "[2/8] Configuring service account..."
$svcUser = "CcDashboardSvc"
if (-not (Get-LocalUser -Name $svcUser -ErrorAction SilentlyContinue))
{
    if (-not $SvcPassword)
    {
        $SvcPassword = [System.Web.Security.Membership]::GeneratePassword(20, 4)
        Write-Host "      Generated service account password (save this): $SvcPassword"
    }
    $secPwd = ConvertTo-SecureString $SvcPassword -AsPlainText -Force
    New-LocalUser -Name $svcUser -Password $secPwd -PasswordNeverExpires -UserMayNotChangePassword `
        -Description "RTM View Shell service account" | Out-Null
    Write-Host "      Created local account: $svcUser"
}
else
{
    Write-Host "      Account $svcUser already exists"
}

# Grant "Log on as a service" right
$tempInf = [System.IO.Path]::GetTempFileName() + ".inf"
$tempDb  = [System.IO.Path]::GetTempFileName() + ".sdb"
@"
[Unicode]
Unicode=yes
[Version]
signature=`"`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeServiceLogonRight = *S-1-5-32-544,$svcUser
"@ | Set-Content $tempInf -Encoding Unicode
secedit /import /cfg $tempInf /db $tempDb /quiet | Out-Null
secedit /configure /db $tempDb /quiet | Out-Null
Remove-Item $tempInf, $tempDb -ErrorAction SilentlyContinue
Write-Host "      'Log on as a service' right granted"

# ── 3. Unpack application ──────────────────────────────────────────────────────
Write-Host "[3/8] Unpacking to $AppPath..."
if (-not (Test-Path $AppPath)) { New-Item -ItemType Directory -Path $AppPath -Force | Out-Null }
Expand-Archive -Path $ZipPath -DestinationPath $AppPath -Force
Write-Host "      Unpacked OK"

# ── 4. NTFS permissions ────────────────────────────────────────────────────────
Write-Host "[4/8] Setting NTFS permissions..."
$logsPath = Join-Path $AppPath "logs"
if (-not (Test-Path $logsPath)) { New-Item -ItemType Directory -Path $logsPath -Force | Out-Null }

foreach ($path in @($AppPath, $logsPath))
{
    $acl = Get-Acl $path
    $rights = if ($path -eq $logsPath) { "Modify" } else { "ReadAndExecute" }
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $svcUser, $rights, "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($rule)
    Set-Acl $path $acl
}
Write-Host "      Permissions set"

# ── 5. Kestrel HTTPS configuration ────────────────────────────────────────────
Write-Host "[5/8] Writing Kestrel HTTPS configuration..."
$kestrelConfig = @"
{
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://*:$HttpPort"
      },
      "Https": {
        "Url": "https://*:$Port",
        "Certificate": {
          "Store": "My",
          "Location": "LocalMachine",
          "Subject": "$CertSubject",
          "AllowInvalid": false
        }
      }
    }
  },
  "DefaultTenantSlug": "platform"
}
"@
$prodConfig = Join-Path $AppPath "appsettings.Production.json"
if (-not (Test-Path $prodConfig))
{
    $kestrelConfig | Set-Content $prodConfig -Encoding UTF8
    Write-Host "      Created appsettings.Production.json"
    Write-Host "      *** Fill in ConnectionStrings, Seed, Jwt, Redis, Email sections ***"
}
else
{
    Write-Host "      appsettings.Production.json already exists — not overwritten"
}

# Allow service account to read the private key of the certificate
if ($CertSubject)
{
    $cert = Get-ChildItem Cert:\LocalMachine\My |
        Where-Object { $_.Subject -like "*$CertSubject*" -or $_.GetNameInfo('SimpleName','') -like $CertSubject } |
        Sort-Object NotAfter -Descending | Select-Object -First 1

    if ($cert)
    {
        $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
        $uniqueName = $rsa?.Key?.UniqueName
        if ($uniqueName)
        {
            $keyFile = Get-ChildItem "$env:ProgramData\Microsoft\Crypto\RSA\MachineKeys" |
                Where-Object { $_.Name -eq $uniqueName } | Select-Object -First 1
            if ($keyFile)
            {
                $acl = Get-Acl $keyFile.FullName
                $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $svcUser, "Read", "None", "None", "Allow")))
                Set-Acl $keyFile.FullName $acl
                Write-Host "      Private key ACL set for $svcUser (cert: $($cert.Subject))"
            }
        }
    }
    else
    {
        Write-Warning "      Certificate with Subject '$CertSubject' not found in LocalMachine\My"
    }
}

# ── 6. EF Core migrations ──────────────────────────────────────────────────────
Write-Host "[6/8] Applying database migrations..."
$exe = Join-Path $AppPath "CcDashboard.Web.exe"
if (Test-Path $exe)
{
    $env:ASPNETCORE_ENVIRONMENT = "Production"
    & $exe migrate
    if ($LASTEXITCODE -ne 0) { Write-Error "Migration failed (exit code $LASTEXITCODE)" }
    Write-Host "      Migrations applied OK"
}
else
{
    Write-Warning "      Executable not found at $exe — run migrations manually: CcDashboard.Web.exe migrate"
}

# ── 7. Windows Service ─────────────────────────────────────────────────────────
Write-Host "[7/8] Registering Windows Service '$ServiceName'..."
$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if (-not $svc)
{
    $svcDomain = $env:COMPUTERNAME + "\" + $svcUser
    New-Service -Name $ServiceName `
        -DisplayName "RTM View Shell" `
        -Description "Contact-centre dashboard web shell (Blazor Server)" `
        -BinaryPathName "`"$exe`"" `
        -StartupType Automatic `
        -Credential (New-Object PSCredential($svcDomain, (ConvertTo-SecureString $SvcPassword -AsPlainText -Force)))
    Write-Host "      Service created"
}
else
{
    Write-Host "      Service already exists — updating binary path"
    & sc.exe config $ServiceName binpath= "`"$exe`"" | Out-Null
}

# Set service to restart on failure (3 times, 60s delay)
& sc.exe failure $ServiceName reset= 86400 actions= restart/60000/restart/60000/restart/60000 | Out-Null
Write-Host "      Failure recovery configured (restart x3)"

# ── 8. Firewall rules ──────────────────────────────────────────────────────────
Write-Host "[8/8] Configuring Windows Firewall..."
foreach ($p in @($Port, $HttpPort))
{
    $ruleName = "CcDashboard TCP $p"
    if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue))
    {
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP `
            -LocalPort $p -Action Allow -Profile Any | Out-Null
        Write-Host "      Opened port $p"
    }
    else
    {
        Write-Host "      Port $p rule already exists"
    }
}

Write-Host ""
Write-Host "=== Installation complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Edit $prodConfig — add ConnectionStrings, Jwt:SecretKey, Redis, Email, Seed passwords"
Write-Host "  2. Verify wildcard DNS: *.${Domain} -> $($(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } | Select-Object -First 1).IPAddress)"
Write-Host "  3. Start service:  Start-Service $ServiceName"
Write-Host "  4. Check status:   Get-Service $ServiceName"
Write-Host "  5. View logs:      Get-Content '$logsPath\*.json' -Wait"
