#Requires -Version 5.1
<#  R7e - fix the DEV localhost certificate so the UI is reachable (probe (b) is blocked by it).
    Reversible: every existing localhost cert is listed with its thumbprint BEFORE anything is added,
    and the new one is printed so it can be removed later.
    MUST run in an ELEVATED PowerShell (writes to LocalMachine stores).
    Authored by devops-0829, 2026-08-30.
#>
$ErrorActionPreference = "Continue"
chcp 65001 > $null

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Host "STOP: run this in an ELEVATED PowerShell (Run as administrator)" -ForegroundColor Red; exit 1 }

Write-Host "===== BEFORE: localhost certificates already present (record for rollback) =====" -ForegroundColor Cyan
foreach ($store in @("Cert:\LocalMachine\My","Cert:\LocalMachine\Root")) {
    "--- $store"
    Get-ChildItem $store | Where-Object { $_.Subject -like "*CN=localhost*" } |
        Select-Object Thumbprint, Subject, NotAfter, @{n='HasPrivateKey';e={$_.HasPrivateKey}} | Format-Table -AutoSize
}

Write-Host "===== CREATE a fresh self-signed cert for localhost =====" -ForegroundColor Cyan
$cert = New-SelfSignedCertificate -DnsName "localhost" -CertStoreLocation "Cert:\LocalMachine\My" `
        -FriendlyName "RTMView DEV localhost (rehearsal 2026-08-30)" -NotAfter (Get-Date).AddYears(2) `
        -KeyExportPolicy Exportable -KeyUsage DigitalSignature,KeyEncipherment `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1")
"new thumbprint: {0}" -f $cert.Thumbprint

Write-Host "===== TRUST it (LocalMachine\Root) so Chrome accepts it =====" -ForegroundColor Cyan
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
$store.Open("ReadWrite"); $store.Add($cert); $store.Close()
"added to LocalMachine\Root"

Write-Host "===== restart the Shell service so Kestrel picks the cert up =====" -ForegroundColor Cyan
Restart-Service RTMViewShell -Force
Start-Sleep -Seconds 20
Get-Service RTMViewShell | Select-Object Name,Status | Format-Table -AutoSize

Write-Host "===== verify HTTPS now completes a real handshake (no trust-all callback this time) =====" -ForegroundColor Cyan
[System.Net.ServicePointManager]::CertificatePolicy = $null
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
try { $r = Invoke-WebRequest -Uri "https://localhost:5239/health" -TimeoutSec 20 -UseBasicParsing
      "https /health -> HTTP {0} : {1}   (validated, not bypassed)" -f $r.StatusCode, $r.Content }
catch { "https /health FAILED: {0}" -f $_.Exception.Message }

Write-Host ""
Write-Host "ROLLBACK, if ever needed:" -ForegroundColor Yellow
"  Remove-Item Cert:\LocalMachine\My\{0} -Force" -f $cert.Thumbprint
"  Remove-Item Cert:\LocalMachine\Root\{0} -Force" -f $cert.Thumbprint
Write-Host "===== R7e done ====="
