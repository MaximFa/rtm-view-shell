#Requires -Version 5.1
<#  R7d - probe (b): does the marker FIRE on a production ConfigJson screen.
    Requires one manual action by the operator (opening a screen in the browser).
    Read-only; changes nothing on the stand.
    Authored by devops-0829, 2026-08-30.
#>
$ErrorActionPreference = "Continue"
chcp 65001 > $null
$marker = "PROBE PR234-1a"

Write-Host "===== where the SERVICE actually writes its log =====" -ForegroundColor Cyan
$cands = @("C:\RTMView\Shell\logs","C:\Windows\System32\logs","C:\RTMView\Shell")
$logs = @()
foreach ($d in $cands) {
    if (Test-Path $d) {
        $f = Get-ChildItem $d -Filter *.txt -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Desc | Select-Object -First 2
        foreach ($x in $f) { "{0,-42} {1}" -f $x.FullName, $x.LastWriteTime; $logs += $x.FullName }
    }
}
if (-not $logs) { Write-Host "no log files found - probe (b) cannot be evidenced" -ForegroundColor Red }

Write-Host ""
Write-Host "===== marker count BEFORE the manual step =====" -ForegroundColor Cyan
$before = @{}
foreach ($l in $logs) { $n = (Select-String -Path $l -Pattern $marker -ErrorAction SilentlyContinue).Count
                        $before[$l] = $n; "{0,-42} {1}" -f (Split-Path $l -Leaf), $n }

Write-Host ""
Write-Host "################ MANUAL STEP ################" -ForegroundColor Yellow
Write-Host "1. Open  https://localhost:5239  in a browser (accept the self-signed certificate warning)."
Write-Host "2. Log in and open ANY dashboard / screen that came from the 234 data."
Write-Host "3. Come back here and press Enter."
Write-Host "############################################" -ForegroundColor Yellow
Read-Host "press Enter once a screen has been opened"

Write-Host ""
Write-Host "===== marker count AFTER =====" -ForegroundColor Cyan
$fired = $false
foreach ($l in $logs) {
    $n = (Select-String -Path $l -Pattern $marker -ErrorAction SilentlyContinue).Count
    "{0,-42} before {1}  after {2}" -f (Split-Path $l -Leaf), $before[$l], $n
    if ($n -gt $before[$l]) {
        $fired = $true
        Write-Host "  --- new marker lines ---" -ForegroundColor Green
        Select-String -Path $l -Pattern $marker | Select-Object -Last 5 | ForEach-Object { "  " + $_.Line }
    }
}
Write-Host ""
if ($fired) { Write-Host "probe (b): FIRED - the marker appeared in the live log after opening a screen" -ForegroundColor Green }
else { Write-Host "probe (b): NOT observed. This is NOT a conclusion by itself - report which screen was opened and where the service log lives." -ForegroundColor Yellow }

Write-Host ""
Write-Host "===== errors in the log since the service started (context for the artifact) =====" -ForegroundColor Cyan
foreach ($l in $logs) {
    $e = Select-String -Path $l -Pattern "\[ERR\]|\[FTL\]|Exception" -ErrorAction SilentlyContinue | Select-Object -Last 8
    if ($e) { "--- $l"; $e | ForEach-Object { "  " + $_.Line } }
}
Write-Host "===== R7d done ====="
