#Requires -Version 5.1
# PROBE DEV / parse-check backup-inventory  -  READ ONLY, local machine.
$ErrorActionPreference = "Continue"
if ($PSVersionTable.PSVersion.Major -ne 5) { Write-Host "STOP: run with powershell.exe."; exit 1 }
$target = "D:\Claude\Projects\RTM View Shell\.probes\probe_234_20260906_backup-inventory.ps1"
$bad = Join-Path $env:TEMP ("pc_{0}.ps1" -f [guid]::NewGuid().ToString("N"))
[IO.File]::WriteAllText($bad, "if (`$true) { 'x'`r`n", (New-Object System.Text.UTF8Encoding($true)))
$be = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($bad, [ref]$null, [ref]$be)
$negOk = (@($be).Count -gt 0)
Remove-Item $bad -ErrorAction SilentlyContinue
Write-Host ("negative control - broken fragment fails to parse : {0}   (must be True)" -f $negOk)
$b = [IO.File]::ReadAllBytes($target)
$bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
$nul = @($b | Where-Object { $_ -eq 0 }).Count
$sha = (Get-FileHash $target -Algorithm SHA256).Hash
$hashOk = ($sha -eq "1C8DD130AE1AED59BD15CC7ADE569661C91429A46313A905C747D9B373C9DF97")
Write-Host ("bytes {0} (expect 7886)   BOM {1}   NUL {2}   hash matches {3}" -f $b.Length, $bom, $nul, $hashOk)
$txt = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
$readOnly = -not ($txt.Contains('Remove-Item -LiteralPath') -or $txt.Contains('Copy-Item') -or $txt.Contains('Move-Item') -or $txt.Contains('Stop-Service') -or $txt.Contains('sc.exe delete'))
$hasG0 = $txt.Contains('G0 which machine is this')
Write-Host ("read-only (no copy, move, delete, service action) : {0}   (must be True)" -f $readOnly)
Write-Host ("G0 present : {0}   (must be True)" -f $hasG0)
$e = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($target, [ref]$null, [ref]$e)
$errs = @($e)
if ($errs.Count -eq 0) { Write-Host "PARSE OK" } else { foreach ($er in $errs) { Write-Host ("  line {0}: {1}" -f $er.Extent.StartLineNumber, $er.Message) } }
Write-Host ""
if ($negOk -and $bom -and $nul -eq 0 -and $hashOk -and $readOnly -and $hasG0 -and $errs.Count -eq 0) { Write-Host "VERDICT: PASS - safe to copy to 234 and run" } else { Write-Host "VERDICT: FAIL" }
