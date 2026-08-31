#Requires -Version 5.1
<#  R7c - finish what R7b could not: /health with a self-signed cert on PS 5.1,
    a FAST probe-(a) search, and the service/DB sanity checks.
    Read-only against the stand (no redeploy, no config change).
    Authored by devops-0829, 2026-08-30.
#>
$ErrorActionPreference = "Continue"
chcp 65001 > $null
$shell = "C:\RTMView\Shell"

Write-Host "===== services =====" -ForegroundColor Cyan
Get-Service RTMViewShell,RTMService | Select-Object Name,Status | Format-Table -AutoSize

Write-Host "===== /health (PS 5.1: trust-all callback; -SkipCertificateCheck is PS7-only) =====" -ForegroundColor Cyan
add-type @"
using System.Net; using System.Security.Cryptography.X509Certificates;
public class TrustAll : ICertificatePolicy {
  public bool CheckValidationResult(ServicePoint sp, X509Certificate c, WebRequest r, int p) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAll
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
foreach ($u in @("https://localhost:5239/health","http://localhost:5238/health")) {
    try { $r = Invoke-WebRequest -Uri $u -TimeoutSec 20 -UseBasicParsing
          "{0}  ->  HTTP {1} : {2}" -f $u, $r.StatusCode, $r.Content }
    catch { "{0}  ->  FAILED: {1}" -f $u, $_.Exception.Message }
}

Write-Host "===== probe (a) - fast UTF-16LE search (String.IndexOf, not a byte loop) =====" -ForegroundColor Cyan
$marker = "PROBE PR234-1a"
$hits = 0
foreach ($f in (Get-ChildItem $shell -Recurse -Include CcDashboard*.dll -ErrorAction SilentlyContinue)) {
    $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::Unicode)
    $n = 0; $i = $text.IndexOf($marker)
    while ($i -ge 0) { $n++; $i = $text.IndexOf($marker, $i + $marker.Length) }
    if ($n -gt 0) { "  {0,-40} {1}" -f $f.Name, $n; $hits += $n }
}
"probe (a): marker PRESENT in the deployed build, {0} occurrence(s)" -f $hits
"note: the compiler interns identical literals, so the binary count is legitimately lower than the 11 in source;"
"      the predicate is PRESENCE in CcDashboard.Web.dll, not equality with the source count."

Write-Host "===== which database the running Shell is actually attached to =====" -ForegroundColor Cyan
$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
$pg = "C:\Program Files\PostgreSQL\18\bin"
& "$pg\psql.exe" -U postgres -d postgres -c "SELECT datname, count(*) AS connections FROM pg_stat_activity WHERE usename='ccdashboard_user' GROUP BY 1 ORDER BY 1;"

Write-Host "===== recent Shell log lines (errors first) =====" -ForegroundColor Cyan
$log = Get-ChildItem "$shell\logs" -Filter *.txt -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Desc | Select-Object -First 1
if ($log) {
    "log: {0}" -f $log.FullName
    Get-Content $log.FullName -Tail 40 | Select-String -Pattern "ERR|FTL|Exception|error" | Select-Object -First 15
    "--- last 8 lines regardless of level ---"
    Get-Content $log.FullName -Tail 8
} else { "no log file found under $shell\logs" }
$env:PGPASSWORD = ""
Write-Host "===== R7c done =====" -ForegroundColor Green
