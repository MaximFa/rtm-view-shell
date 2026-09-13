#Requires -Version 5.1
# PROBE DEV / parse-check wipe-step1-3-v2  -  READ ONLY, local machine.
$ErrorActionPreference = "Continue"
Write-Host ("PowerShell    : {0}   (must be 5.x)" -f $PSVersionTable.PSVersion)
if ($PSVersionTable.PSVersion.Major -ne 5) { Write-Host "STOP: run with powershell.exe, not pwsh."; exit 1 }

$target = "D:\Claude\Projects\RTM View Shell\.probes\probe_234_20260906_wipe-step1-3-v2.ps1"

Write-Host ""
Write-Host "===== NEGATIVE CONTROL - a broken fragment must NOT parse ====="
$bad = Join-Path $env:TEMP ("parsecheck_bad_{0}.ps1" -f [guid]::NewGuid().ToString("N"))
[IO.File]::WriteAllText($bad, "if (`$true) { 'x'`r`n", (New-Object System.Text.UTF8Encoding($true)))
$be = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($bad, [ref]$null, [ref]$be)
$negOk = (@($be).Count -gt 0)
Remove-Item $bad -ErrorAction SilentlyContinue
Write-Host ("  broken fragment produced {0} error(s)   -> checker can fail : {1}   (must be True)" -f @($be).Count, $negOk)

Write-Host ""
Write-Host "===== BYTES ====="
if (-not (Test-Path $target)) { Write-Host "STOP: file not found: $target"; exit 1 }
$b = [IO.File]::ReadAllBytes($target)
$bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
$nul = @($b | Where-Object { $_ -eq 0 }).Count
$sha = (Get-FileHash $target -Algorithm SHA256).Hash
Write-Host ("  bytes   : {0}   (expect 18003)" -f $b.Length)
Write-Host ("  BOM     : {0}   (must be True)" -f $bom)
Write-Host ("  NUL     : {0}   (must be 0)" -f $nul)
Write-Host ("  sha256  : {0}" -f $sha)
Write-Host  "  expected: 1FD9C57B50A8FE017CE0159C391CF4F64A516C874032CE05099ED7E87393D053"
$hashOk = ($sha -eq "1FD9C57B50A8FE017CE0159C391CF4F64A516C874032CE05099ED7E87393D053")
Write-Host ("  hash matches : {0}" -f $hashOk)

Write-Host ""
Write-Host "===== CONTENT GUARDS - what must and must not be in a steps 1-3 box ====="
$txt = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
$hasFour   = $txt.Contains("'RTMApplyService'")
$hasG7     = $txt.Contains("G7 ApplyService is preserved")
$noDelete  = -not ($txt -match 'Remove-Item\s+.*C:\\RTMView[^-]' -or $txt.Contains('DROP DATABASE') -or $txt.Contains('dropdb'))
Write-Host ("  four services in scope (RTMApplyService named) : {0}   (must be True)" -f $hasFour)
Write-Host ("  G7 preservation gate present                   : {0}   (must be True)" -f $hasG7)
Write-Host ("  NO deletion of C:\RTMView\ and NO database drop : {0}   (must be True - step 4 is not in this box)" -f $noDelete)

Write-Host ""
Write-Host "===== PARSE ====="
$e = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($target, [ref]$null, [ref]$e)
$errs = @($e)
if ($errs.Count -eq 0) { Write-Host "  PARSE OK - no syntax errors" }
else {
    Write-Host ("  PARSE FAILED - {0} error(s):" -f $errs.Count)
    foreach ($er in $errs) { Write-Host ("    line {0} col {1} : {2}" -f $er.Extent.StartLineNumber, $er.Extent.StartColumnNumber, $er.Message) }
}

Write-Host ""
if ($negOk -and $bom -and $nul -eq 0 -and $hashOk -and $hasFour -and $hasG7 -and $noDelete -and $errs.Count -eq 0) {
    Write-Host "VERDICT: PASS - safe to copy to 234 and run"
} else { Write-Host "VERDICT: FAIL - do NOT copy it to 234." }
