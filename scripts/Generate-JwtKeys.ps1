<#
.SYNOPSIS
    Generates RSA-2048 key pair for JWT signing [AUTH-API-02].

.DESCRIPTION
    Creates private and public PEM keys for RS256 JWT signing.
    Private key should be stored securely (Key Vault, DPAPI, or file with restricted ACL).
    Public key can be distributed for token verification.

.PARAMETER OutputPath
    Directory where keys will be saved. Default: current directory.

.PARAMETER KeySize
    RSA key size in bits. Default: 2048 (minimum for production).

.EXAMPLE
    .\Generate-JwtKeys.ps1 -OutputPath "C:\ProgramData\CcDashboard\keys"
#>
param(
    [string]$OutputPath = ".",
    [int]$KeySize = 2048
)

$ErrorActionPreference = "Stop"

Write-Host "Generating RSA-$KeySize key pair for JWT signing..." -ForegroundColor Cyan

# Ensure output directory exists
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$privateKeyPath = Join-Path $OutputPath "jwt-private.pem"
$publicKeyPath = Join-Path $OutputPath "jwt-public.pem"

# Check if keys already exist
if ((Test-Path $privateKeyPath) -or (Test-Path $publicKeyPath)) {
    $confirm = Read-Host "Keys already exist at $OutputPath. Overwrite? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

# Generate RSA key pair using .NET
$rsa = [System.Security.Cryptography.RSA]::Create($KeySize)

# Export private key (PKCS#8 PEM format)
$privateKeyPem = $rsa.ExportPkcs8PrivateKeyPem()
[System.IO.File]::WriteAllText($privateKeyPath, $privateKeyPem)

# Export public key (SPKI PEM format)
$publicKeyPem = $rsa.ExportSubjectPublicKeyInfoPem()
[System.IO.File]::WriteAllText($publicKeyPath, $publicKeyPem)

# Set restrictive ACL on private key (Windows)
$acl = Get-Acl $privateKeyPath
$acl.SetAccessRuleProtection($true, $false)  # Disable inheritance
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) } | Out-Null

# Allow only current user and SYSTEM
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$userRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $currentUser, "FullControl", "Allow")
$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "NT AUTHORITY\SYSTEM", "FullControl", "Allow")

$acl.AddAccessRule($userRule)
$acl.AddAccessRule($systemRule)
Set-Acl $privateKeyPath $acl

Write-Host ""
Write-Host "Keys generated successfully:" -ForegroundColor Green
Write-Host "  Private key: $privateKeyPath" -ForegroundColor White
Write-Host "  Public key:  $publicKeyPath" -ForegroundColor White
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host @"
  Add to appsettings.Production.json or User Secrets:

  "Jwt": {
    "PrivateKeyPath": "$($privateKeyPath -replace '\\', '\\\\')",
    "PublicKeyPath": "$($publicKeyPath -replace '\\', '\\\\')"
  }
"@
Write-Host ""
Write-Host "Security notes:" -ForegroundColor Yellow
Write-Host "  - Private key ACL restricted to current user and SYSTEM"
Write-Host "  - For IIS: grant read permission to app pool identity"
Write-Host "  - Rotate keys annually; maintain old public key for verification"
Write-Host "  - Consider Azure Key Vault for production key storage"
