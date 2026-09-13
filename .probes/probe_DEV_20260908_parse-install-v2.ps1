#Requires -Version 5.1
# PROBE DEV / parse-check install v2  -  READ ONLY, local machine.
#  Beyond parsing: proves the box cannot print a secret, and that the masking function itself
#  is able to mask - checked on a deliberately secret-bearing string, not on faith.
$ErrorActionPreference = "Continue"
if ($PSVersionTable.PSVersion.Major -ne 5) { Write-Host "STOP: run with powershell.exe."; exit 1 }
$target = "D:\Claude\Projects\RTM View Shell\.probes\probe_234_20260908_install-v2.ps1"

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
$hashOk = ($sha -eq "BC74745350DDF8EE0FAB122A0478A20DBDA22A16FDE54C856B92BABD3DEAF676")
Write-Host ("bytes {0} (expect 16169)   BOM {1}   NUL {2}   hash matches {3}" -f $b.Length, $bom, $nul, $hashOk)

$txt = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
$freshDb   = $txt.Contains('"-FreshDb"')
$port      = $txt.Contains('"-DBPort","5433"')
$no5432    = -not ($txt -match '"-DBPort"\s*,\s*"5432"')
$oneShot   = $txt.Contains('5.0 data.sys AS THE INSTALLER LEFT IT')
$noReturn  = -not ($txt -match 'Copy-Item.*data\.sys')
$dumpByExt = $txt.Contains("Extension -in @('.dump','.backup')")
$redisPass = $txt.Contains('$args += @("-RedisPassword",$redisPwd)')
$masked    = $txt.Contains('(MaskConn $redisCs)')
$noRawPrint= -not ($txt -match 'Say.*-f\s+\$redisCs\b')
$redact    = $txt.Contains('P0 redacting the password this probe printed')
Write-Host ""
Write-Host "===== the box's behaviour, checked in its text ====="
Write-Host ("  -FreshDb passed                        : {0}   (must be True)" -f $freshDb)
Write-Host ("  -DBPort 5433 passed, 5432 never        : {0} / {1}" -f $port, $no5432)
Write-Host ("  one-shot data.sys measurement present  : {0}   (must be True)" -f $oneShot)
Write-Host ("  does NOT return data.sys here          : {0}   (must be True)" -f $noReturn)
Write-Host ("  dumps found by EXTENSION               : {0}   (must be True)" -f $dumpByExt)
Write-Host ("  -RedisPassword actually PASSED         : {0}   (must be True - it was only printed before)" -f $redisPass)
Write-Host ("  Redis string printed through MaskConn  : {0}   (must be True)" -f $masked)
Write-Host ("  raw Redis string never printed         : {0}   (must be True)" -f $noRawPrint)
Write-Host ("  redacts the earlier leaked report      : {0}   (must be True)" -f $redact)

Write-Host ""
Write-Host "===== does the masking function actually mask? checked, not assumed ====="
# lift MaskConn out of the box and run it on a string that certainly carries a secret
$src = [regex]::Match($txt, '(?s)function MaskConn.*?\r?\n\}').Value
if (-not $src) { Write-Host "  *** could not lift MaskConn from the box"; $maskWorks = $false }
else {
    Invoke-Expression $src
    $sample = 'localhost:6379,password=SuperSecret123,ssl=False'
    $res = MaskConn $sample
    $hidesSecret = -not $res.Contains('SuperSecret123')
    $keepsRest   = $res.Contains('localhost:6379') -and $res.Contains('ssl=False')
    $saysLength  = $res.Contains('length 14')
    Write-Host ("  input  : {0}" -f $sample)
    Write-Host ("  output : {0}" -f $res)
    Write-Host ("  secret hidden        : {0}   (must be True)" -f $hidesSecret)
    Write-Host ("  non-secrets kept     : {0}   (must be True - masking everything is not masking)" -f $keepsRest)
    Write-Host ("  reports its length   : {0}   (must be True)" -f $saysLength)
    $maskWorks = ($hidesSecret -and $keepsRest -and $saysLength)
}

$e = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($target, [ref]$null, [ref]$e)
$errs = @($e)
Write-Host ""
if ($errs.Count -eq 0) { Write-Host "PARSE OK" } else { foreach ($er in $errs) { Write-Host ("  line {0}: {1}" -f $er.Extent.StartLineNumber, $er.Message) } }
Write-Host ""
if ($negOk -and $bom -and $nul -eq 0 -and $hashOk -and $freshDb -and $port -and $no5432 -and $oneShot -and $noReturn -and $dumpByExt -and $redisPass -and $masked -and $noRawPrint -and $redact -and $maskWorks -and $errs.Count -eq 0) {
    Write-Host "VERDICT: PASS - safe to copy to 234 and run"
} else { Write-Host "VERDICT: FAIL" }
