#Requires -Version 5.1
# ============================================================================
#  PROBE DEV / parse-check roles-control   -   READ ONLY
#  WHERE IT RUNS : the local machine, against the repo clone. Server 234 NOT touched.
#  WRITES        : nothing. One throwaway file under $env:TEMP, deleted at the end.
#  NEGATIVE CTRL : a deliberately broken fragment MUST fail to parse.
# ============================================================================

$ErrorActionPreference = "Continue"

Write-Host ("PowerShell    : {0}   (must be 5.x)" -f $PSVersionTable.PSVersion)
if ($PSVersionTable.PSVersion.Major -ne 5) { Write-Host "STOP: run with powershell.exe, not pwsh."; exit 1 }

$target = "D:\Claude\Projects\RTM View Shell\.probes\probe_234_20260906_roles-control.ps1"

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
Write-Host ("  bytes   : {0}   (expect 5997)" -f $b.Length)
Write-Host ("  BOM     : {0}   (must be True)" -f $bom)
Write-Host ("  NUL     : {0}   (must be 0)" -f $nul)
Write-Host ("  sha256  : {0}" -f $sha)
Write-Host  "  expected: 3F90C14A755A7B61A8F5C5F27C0A65453F2839C4DEDB99DB4CAE4DA8763BE9F6"
$hashOk = ($sha -eq "3F90C14A755A7B61A8F5C5F27C0A65453F2839C4DEDB99DB4CAE4DA8763BE9F6")
Write-Host ("  hash matches : {0}" -f $hashOk)

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
if ($negOk -and $bom -and $nul -eq 0 -and $hashOk -and $errs.Count -eq 0) { Write-Host "VERDICT: PASS - safe to copy to 234 and run" }
else { Write-Host "VERDICT: FAIL - do NOT copy it to 234." }
