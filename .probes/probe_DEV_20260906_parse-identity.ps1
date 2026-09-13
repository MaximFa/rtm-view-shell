#Requires -Version 5.1
# PROBE DEV / parse-check identity  -  READ ONLY, local machine.
$ErrorActionPreference = "Continue"
Write-Host ("PowerShell : {0}   (must be 5.x)" -f $PSVersionTable.PSVersion)
if ($PSVersionTable.PSVersion.Major -ne 5) { Write-Host "STOP: run with powershell.exe."; exit 1 }
$target = "D:\Claude\Projects\RTM View Shell\.probes\probe_234_20260906_identity.ps1"
$bad = Join-Path $env:TEMP ("pc_{0}.ps1" -f [guid]::NewGuid().ToString("N"))
[IO.File]::WriteAllText($bad, "if (`$true) { 'x'`r`n", (New-Object System.Text.UTF8Encoding($true)))
$be = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($bad, [ref]$null, [ref]$be)
$negOk = (@($be).Count -gt 0)
Remove-Item $bad -ErrorAction SilentlyContinue
Write-Host ("negative control - broken fragment fails to parse : {0}   (must be True)" -f $negOk)
if (-not (Test-Path $target)) { Write-Host "STOP: not found"; exit 1 }
$b = [IO.File]::ReadAllBytes($target)
$bom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
$nul = @($b | Where-Object { $_ -eq 0 }).Count
$sha = (Get-FileHash $target -Algorithm SHA256).Hash
Write-Host ("bytes  : {0}   (expect 5504)" -f $b.Length)
Write-Host ("BOM    : {0}   (must be True)" -f $bom)
Write-Host ("NUL    : {0}   (must be 0)" -f $nul)
Write-Host ("sha256 : {0}" -f $sha)
Write-Host  "expect : 5A7338B63FDF09766C2915E58F8DAC557788D13CE2B3FAE2C1EA7B5DCDDD471D"
$hashOk = ($sha -eq "5A7338B63FDF09766C2915E58F8DAC557788D13CE2B3FAE2C1EA7B5DCDDD471D")
$txt = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
$readOnly = -not ($txt.Contains('Stop-Service') -or $txt.Contains('sc.exe delete') -or ($txt -match 'Remove-Item\s+.*C:\\RTMView[^-]'))
Write-Host ("hash matches : {0}" -f $hashOk)
Write-Host ("read-only (no stop, no delete, no removal) : {0}   (must be True)" -f $readOnly)
$e = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($target, [ref]$null, [ref]$e)
$errs = @($e)
if ($errs.Count -eq 0) { Write-Host "PARSE OK" } else { foreach ($er in $errs) { Write-Host ("  line {0}: {1}" -f $er.Extent.StartLineNumber, $er.Message) } }
Write-Host ""
if ($negOk -and $bom -and $nul -eq 0 -and $hashOk -and $readOnly -and $errs.Count -eq 0) { Write-Host "VERDICT: PASS - safe to copy to 234 and run" }
else { Write-Host "VERDICT: FAIL" }
