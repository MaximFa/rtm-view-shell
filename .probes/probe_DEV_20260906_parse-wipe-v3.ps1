#Requires -Version 5.1
# PROBE DEV / parse-check wipe-step1-3-v3  -  READ ONLY, local machine.
#  Beyond parsing, this checks the guard that FAILED on 2026-09-06: the branch taken when
#  -Proceed is absent must actually END the script. A verdict printed is not a script ended.
$ErrorActionPreference = "Continue"
Write-Host ("PowerShell    : {0}   (must be 5.x)" -f $PSVersionTable.PSVersion)
if ($PSVersionTable.PSVersion.Major -ne 5) { Write-Host "STOP: run with powershell.exe, not pwsh."; exit 1 }

$target = "D:\Claude\Projects\RTM View Shell\.probes\probe_234_20260906_wipe-step1-3-v3.ps1"

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
Write-Host ("  bytes   : {0}   (expect 19088)" -f $b.Length)
Write-Host ("  BOM     : {0}   (must be True)" -f $bom)
Write-Host ("  NUL     : {0}   (must be 0)" -f $nul)
Write-Host ("  sha256  : {0}" -f $sha)
Write-Host  "  expected: CE58BC32BDB85D09F7C9D5F61BBA89411E543E04B5D328939598A06B31C2FF1B"
$hashOk = ($sha -eq "CE58BC32BDB85D09F7C9D5F61BBA89411E543E04B5D328939598A06B31C2FF1B")
Write-Host ("  hash matches : {0}" -f $hashOk)

$txt = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)

Write-Host ""
Write-Host "===== THE GUARD THAT FAILED ON 2026-09-06 - checked by machine, not by eye ====="
$finExits  = ($txt -match 'if\s*\(\s*\$pass\s*\)\s*\{\s*exit\s+0\s*\}\s*else\s*\{\s*exit\s+1\s*\}')
$sentinel  = $txt.Contains('SENTINEL: execution reached STEP 2 without -Proceed')
$sentBefore = $false
$iSent = $txt.IndexOf('SENTINEL: execution reached STEP 2')
$iStep2 = $txt.IndexOf('===== STEP 2 stop our four services')
if ($iSent -ge 0 -and $iStep2 -ge 0) { $sentBefore = ($iSent -lt $iStep2) }
Write-Host ("  LAYER 1  Fin() exits on BOTH outcomes              : {0}   (must be True)" -f $finExits)
Write-Host ("  LAYER 2  sentinel present                          : {0}   (must be True)" -f $sentinel)
Write-Host ("  LAYER 2  sentinel stands BEFORE step 2             : {0}   (must be True)" -f $sentBefore)
Write-Host ""
Write-Host "  POSITIVE CONTROL of this check - it must be able to say NO:"
$fake = "function Fin(`$pass) { if (-not `$pass) { exit 1 } }"
$fakeOk = ($fake -match 'if\s*\(\s*\$pass\s*\)\s*\{\s*exit\s+0\s*\}\s*else\s*\{\s*exit\s+1\s*\}')
Write-Host ("      the OLD broken Fin passes this check           : {0}   (must be False)" -f $fakeOk)

Write-Host ""
Write-Host "===== CONTENT GUARDS - what must and must not be in a steps 1-3 box ====="
$hasFour  = $txt.Contains("'RTMApplyService'")
$hasG7    = $txt.Contains("G7 ApplyService is preserved")
$noDelete = -not ($txt -match 'Remove-Item\s+.*C:\\RTMView[^-]' -or $txt.Contains('DROP DATABASE') -or $txt.Contains('dropdb'))
Write-Host ("  four services in scope (RTMApplyService named)  : {0}   (must be True)" -f $hasFour)
Write-Host ("  G7 preservation gate present                   : {0}   (must be True)" -f $hasG7)
Write-Host ("  NO deletion of C:\RTMView\ and NO database drop : {0}   (must be True)" -f $noDelete)

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
if ($negOk -and $bom -and $nul -eq 0 -and $hashOk -and $finExits -and $sentinel -and $sentBefore -and (-not $fakeOk) -and $hasFour -and $hasG7 -and $noDelete -and $errs.Count -eq 0) {
    Write-Host "VERDICT: PASS - the guard is real this time, and it was checked by machine"
} else { Write-Host "VERDICT: FAIL - do NOT copy it to 234." }
