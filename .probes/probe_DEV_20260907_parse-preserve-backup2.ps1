#Requires -Version 5.1
# PROBE DEV / parse-check preserve-backup2  -  READ ONLY, local machine.
$ErrorActionPreference = "Continue"
if ($PSVersionTable.PSVersion.Major -ne 5) { Write-Host "STOP: run with powershell.exe."; exit 1 }
$target = "D:\Claude\Projects\RTM View Shell\.probes\probe_234_20260907_preserve-backup2.ps1"
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
$hashOk = ($sha -eq "DEC604C48B48B39B60AD6E5DA5383A69667985C7B65ED9A84B7ACD35AD68607E")
Write-Host ("bytes {0} (expect 9510)   BOM {1}   NUL {2}   hash matches {3}" -f $b.Length, $bom, $nul, $hashOk)
$txt = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
$noDestroy = -not ($txt.Contains('Remove-Item') -or $txt.Contains('Move-Item') -or $txt.Contains('sc.exe delete') -or $txt.Contains('Stop-Service'))
$hasG0     = $txt.Contains('G0 which machine is this')
$hasComplete = $txt.Contains('COMPLETENESS - the gate we did not have')
$verifyByHash = $txt.Contains('Get-FileHash $to')
Write-Host ("no delete / move / service action : {0}   (must be True)" -f $noDestroy)
Write-Host ("G0 present                        : {0}   (must be True)" -f $hasG0)
Write-Host ("completeness gate present         : {0}   (must be True)" -f $hasComplete)
Write-Host ("copies verified by hash read-back : {0}   (must be True)" -f $verifyByHash)
$e = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($target, [ref]$null, [ref]$e)
$errs = @($e)
if ($errs.Count -eq 0) { Write-Host "PARSE OK" } else { foreach ($er in $errs) { Write-Host ("  line {0}: {1}" -f $er.Extent.StartLineNumber, $er.Message) } }
Write-Host ""
if ($negOk -and $bom -and $nul -eq 0 -and $hashOk -and $noDestroy -and $hasG0 -and $hasComplete -and $verifyByHash -and $errs.Count -eq 0) { Write-Host "VERDICT: PASS - safe to copy to 234 and run" } else { Write-Host "VERDICT: FAIL" }
