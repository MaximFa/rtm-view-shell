#Requires -Version 5.1
# PROBE DEV / parse-check install  -  READ ONLY, local machine. Server 234 not contacted.
$ErrorActionPreference = "Continue"
if ($PSVersionTable.PSVersion.Major -ne 5) { Write-Host "STOP: run with powershell.exe."; exit 1 }
$target = "D:\Claude\Projects\RTM View Shell\.probes\probe_234_20260908_install.ps1"
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
$hashOk = ($sha -eq "AE650CAD74F3B238E45CFADB68346427BFAEF3788F4FCCAEE8466567B95607C7")
Write-Host ("bytes {0} (expect 12335)   BOM {1}   NUL {2}   hash matches {3}" -f $b.Length, $bom, $nul, $hashOk)
$txt = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
$freshDb  = $txt.Contains('"-FreshDb"')
$port     = $txt.Contains('"-DBPort","5433"')
$no5432   = -not ($txt -match '"-DBPort"\s*,\s*"5432"')
$oneShot  = $txt.Contains('5.0 data.sys AS THE INSTALLER LEFT IT')
$noReturn = -not ($txt -match 'Copy-Item.*data\.sys')
$dumpByExt= $txt.Contains("Extension -in @('.dump','.backup')")
$noPrint  = -not ($txt -match 'Say.*\$suPwd\b(?!\.Length)')
Write-Host ("  -FreshDb passed to the installer      : {0}   (must be True)" -f $freshDb)
Write-Host ("  -DBPort 5433 passed                   : {0}   (must be True)" -f $port)
Write-Host ("  never passes 5432                     : {0}   (must be True)" -f $no5432)
Write-Host ("  one-shot data.sys measurement present : {0}   (must be True)" -f $oneShot)
Write-Host ("  does NOT return data.sys in this box   : {0}   (must be True)" -f $noReturn)
Write-Host ("  dumps found by EXTENSION, not by name : {0}   (must be True)" -f $dumpByExt)
$e = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($target, [ref]$null, [ref]$e)
$errs = @($e)
if ($errs.Count -eq 0) { Write-Host "PARSE OK" } else { foreach ($er in $errs) { Write-Host ("  line {0}: {1}" -f $er.Extent.StartLineNumber, $er.Message) } }
Write-Host ""
if ($negOk -and $bom -and $nul -eq 0 -and $hashOk -and $freshDb -and $port -and $no5432 -and $oneShot -and $noReturn -and $dumpByExt -and $errs.Count -eq 0) {
    Write-Host "VERDICT: PASS - safe to copy to 234 and run"
} else { Write-Host "VERDICT: FAIL" }
