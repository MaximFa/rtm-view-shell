#Requires -Version 5.1
<#  FULL REHEARSAL - Part A (rebuild from restore) then Part B (struct-diff, reload, resync, verify).
    Chained deliberately: Part B is only meaningful on a freshly rebuilt target (lesson 2026-08-29).
#>
chcp 65001 > $null   # console UTF-8 so Hebrew business-unit names render instead of mojibake
$root = "D:\Claude\Projects\RTM View Shell\tools\rehearsal"
Write-Host "########## PART A ##########" -ForegroundColor Magenta
& powershell -ExecutionPolicy Bypass -File "$root\PartA.ps1"
Write-Host ""
Write-Host "########## PART B ##########" -ForegroundColor Magenta
& powershell -ExecutionPolicy Bypass -File "$root\PartB3.ps1"
