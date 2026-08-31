#Requires -Version 5.1
<#  R7h - probe (b) evidence: find every log the service may write to, show marker lines WITH timestamps,
    so "fired" is judged by when the lines appeared, not by a before/after counter that may have been
    started too late. Read-only.
#>
$ErrorActionPreference = "Continue"
chcp 65001 > $null
$marker = "PROBE PR234-1a"

Write-Host "===== candidate log locations (service CWD is System32 - lesson 2026-07-13) =====" -ForegroundColor Cyan
$dirs = @("C:\RTMView\Shell\logs","C:\Windows\System32\logs","C:\RTMView\Shell","C:\RTMView\RTM\logs")
$files = @()
foreach ($d in $dirs) {
    if (Test-Path $d) {
        Get-ChildItem $d -Filter *.txt -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending | Select-Object -First 3 | ForEach-Object {
            "{0,-52} {1}" -f $_.FullName, $_.LastWriteTime
            $files += $_.FullName
          }
    }
}
if (-not $files) { Write-Host "no logs found at all" -ForegroundColor Red }

Write-Host ""
Write-Host "===== probe (b): marker lines WITH timestamps =====" -ForegroundColor Cyan
$any = $false
foreach ($f in $files) {
    $hits = Select-String -Path $f -Pattern $marker -ErrorAction SilentlyContinue
    if ($hits) {
        $any = $true
        "--- {0}  ({1} line(s))" -f $f, $hits.Count
        $hits | Select-Object -Last 6 | ForEach-Object { "    " + $_.Line }
    }
}
if (-not $any) { Write-Host "no marker lines in any log" -ForegroundColor Yellow }

Write-Host ""
Write-Host "===== last 25 lines of the freshest log (context: what the screen render actually did) =====" -ForegroundColor Cyan
$newest = Get-ChildItem $files -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Desc | Select-Object -First 1
if ($newest) { "log: {0}" -f $newest.FullName; Get-Content $newest.FullName -Tail 25 }

Write-Host ""
Write-Host "===== errors/warnings during the screen render =====" -ForegroundColor Cyan
if ($newest) {
    Get-Content $newest.FullName -Tail 200 |
        Select-String -Pattern "\[ERR\]|\[FTL\]|\[WRN\]|Exception" | Select-Object -Last 12 |
        ForEach-Object { "  " + $_.Line }
}
Write-Host "===== R7h done ====="
