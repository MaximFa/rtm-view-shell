#Requires -Version 5.1
<#
  BOX LOCAL / package-gate-v2
  WHERE IT RUNS : the LOCAL workstation (host name is a gate). NO server, NO database, NO deploy.
  WHAT IT WRITES: nothing but its own report under D:\Claude\Build. It does not build, does not unpack to
                  disk, does not delete. Both packages are opened READ-ONLY.
  WHAT IT DOES  : re-runs the ORIGIN GATE of the build box against the two packages already built, with a
                  matcher that does not depend on the path separator.

  WHY A V2, stated as the defect it is. In the build box I asked for the entry named exactly
  db/tools/Provision-FreshDb.ps1 with a FORWARD slash. ZipFile.CreateFromDirectory on .NET Framework writes
  entry names with a BACKSLASH: measured, 497 of 501 entries in the RTM package and 435 of 439 in the Shell
  package carry one, and zero carry a forward slash. So the four reported ABSENT were two false reds: the
  files are in both packages (Provision-FreshDb.ps1 15613 B, Restore-All.ps1 10601 B). The two that passed
  passed only because they sit at the archive ROOT, where there is no separator at all - that is, the green
  half of that gate was green for a reason unrelated to its correctness. The predicate here matches on the
  entry LEAF name plus its parent segment, with both separators accepted, and it is proven on a known case
  before it is trusted.

  NOTHING IS REBUILT. The packages are identified by the sha256 named below, measured in the build run, so
  this box judges exactly the artifacts that were measured then - not whatever happens to carry that name.
#>

$ErrorActionPreference = 'Continue'

$HOSTGATE = 'LAPTOP-M4B1MKEC'
$PIN      = 'b4ad3014805ef647fc2e551357955d644a2298aa'
$ZIPRTM   = 'D:\Claude\Build\rtm_clean_b4ad301\Installations\12092026.2109_RTM.zip'
$ZIPSHELL = 'D:\Claude\Build\rtm_clean_b4ad301\Installations\12092026.2110_Shell.zip'
$SHARTM   = '9504A166274A7496F11A4CAA01BF3386EB31F709C22C0B8F22707A479E0F5C8F'
$SHASHELL = '622975701B9C6214810B6ED8046AB772F77323C1E38AC14FCF5E64F232C18FC2'
$OutDir   = 'D:\Claude\Build'

$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('LOCAL_' + $stamp + '_package-gate-v2.txt')
$ProbeLines = New-Object System.Collections.ArrayList
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$ProbeLines.Add('')
    [void]$ProbeLines.Add($(if ($pass) { 'VERDICT: PASS' } else { 'VERDICT: FAIL' }))
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($path) { if (Test-Path $path) { (Get-FileHash $path -Algorithm SHA256).Hash } else { 'ABSENT' } }
function Get-Sha256OfBytes($bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))) -replace '-', '' } finally { $sha.Dispose() }
}
function To-LfBytes($bytes) {
    $out = New-Object System.Collections.Generic.List[byte]
    for ($i = 0; $i -lt $bytes.Length; $i++) { if ($bytes[$i] -ne 13) { $out.Add($bytes[$i]) } }
    return $out.ToArray()
}
function Normalise-EntryName($name) { return ($name -replace [regex]::Escape([string][char]92), '/') }

Say '===== G1  the machine, the instrument and the NEW matcher are checked first ====='
Say ('  host is {0} , expected {1}' -f $env:COMPUTERNAME, $HOSTGATE)
if ($env:COMPUTERNAME -ne $HOSTGATE) { Say '  *** wrong machine - stop'; Fin $false }
Say ('  PowerShell {0}' -f $PSVersionTable.PSVersion)
Say ('  this box   : {0}' -f $MyInvocation.MyCommand.Path)
Say ('  its sha256 : {0}   compare with the number named BEFORE the run' -f (Get-Sha256Of $MyInvocation.MyCommand.Path))
Say ('  NEGCTL sha of a missing path : {0}   expected ABSENT' -f (Get-Sha256Of 'C:\zzz-no-such-file.bin'))
if ((Get-Sha256Of 'C:\zzz-no-such-file.bin') -ne 'ABSENT') { Say '  *** cannot report absence - stop'; Fin $false }
Say ''
Say '  --- the separator-agnostic matcher is proven on the exact case that fooled v1 ---'
$backName = 'db' + [string][char]92 + 'tools' + [string][char]92 + 'Provision-FreshDb.ps1'
$fwdName  = 'db/tools/Provision-FreshDb.ps1'
$target   = 'db/tools/Provision-FreshDb.ps1'
Say ('  a BACKSLASH entry name normalises to the target : {0}   expected True' -f ((Normalise-EntryName $backName) -eq $target))
Say ('  a FORWARD-slash entry name still matches        : {0}   expected True' -f ((Normalise-EntryName $fwdName) -eq $target))
Say ('  an unrelated name does NOT match                : {0}   expected False' -f ((Normalise-EntryName 'db/tools/Other.ps1') -eq $target))
Say ('  the OLD v1 predicate on the backslash name      : {0}   expected False - this is the defect being fixed' -f ($backName -eq $target))
if (((Normalise-EntryName $backName) -ne $target) -or ((Normalise-EntryName $fwdName) -ne $target) -or ((Normalise-EntryName 'db/tools/Other.ps1') -eq $target)) {
    Say '  *** the new matcher does not do what it claims - refusing to judge packages'; Fin $false
}
Say ''
Say '  --- the line-ending normaliser, proven again in this run ---'
$crlfSample = [System.Text.Encoding]::UTF8.GetBytes("a`r`nb")
$lfSample   = [System.Text.Encoding]::UTF8.GetBytes("a`nb")
Say ('  normalised CRLF equals LF : {0}   expected True' -f ((Get-Sha256OfBytes (To-LfBytes $crlfSample)) -eq (Get-Sha256OfBytes $lfSample)))
Say ('  raw CRLF equals LF        : {0}   expected False' -f ((Get-Sha256OfBytes $crlfSample) -eq (Get-Sha256OfBytes $lfSample)))
if ((Get-Sha256OfBytes (To-LfBytes $crlfSample)) -ne (Get-Sha256OfBytes $lfSample)) { Say '  *** normaliser blind - stop'; Fin $false }
if ((Get-Sha256OfBytes $crlfSample) -eq (Get-Sha256OfBytes $lfSample)) { Say '  *** hasher blind - stop'; Fin $false }
Say '  G1 PASS'
Say ''

Say '===== G2  the packages under test are the ones the build run measured ====='
foreach ($pair in @(@($ZIPRTM, $SHARTM), @($ZIPSHELL, $SHASHELL))) {
    $z = $pair[0]; $exp = $pair[1]
    Say ('  {0}' -f $z)
    Say ('      exists {0}' -f (Test-Path $z))
    if (-not (Test-Path $z)) { Say '      *** package gone - stop'; Fin $false }
    $got = Get-Sha256Of $z
    Say ('      sha256 expected {0}' -f $exp)
    Say ('      sha256 actual   {0}' -f $got)
    if ($got -ne $exp) { Say '      *** this is not the package that was built and measured - stop'; Fin $false }
}
Say '  G2 PASS'
Say ''

$fails = 0
Add-Type -AssemblyName System.IO.Compression.FileSystem

Say '===== 1  ORIGIN GATE, re-run with the corrected matcher ====='
Say '  Expected NORMALISED (CR stripped) sha256, named BEFORE this run - same four numbers as in the build box:'
Say '    Install-RTMView.ps1            BBB7223E37538FEF28A0F4A51725302AD82703D995848E8A8F9EE585C67C30D1'
Say '    Update-RTMView.ps1             29F139FB4EB5C7ACE972D9135ABFAF7A3A802D7F32D8D2451C6731AD12A9406E'
Say '    db/tools/Provision-FreshDb.ps1 4FCCB5F80D5D479F623093CA58D6EF2025E9BF17660FA6E2D6BE30AC2EF80177'
Say '    db/tools/Restore-All.ps1       0F01D7F1425B2C9319D920243FA6FAD9A63CE0C63801C44DF5D6A1C7D50F9DE6'
Say '  NEGATIVE HALF - none of the four may equal its pre-edit revision:'
Say '    Install old 4DF06439...  / Update old A88453E0...  / Provision old 931B563F...  / Restore-All old E9C4AF40...'
Say ''
$wanted = @(
    @('Install-RTMView.ps1',            'BBB7223E37538FEF28A0F4A51725302AD82703D995848E8A8F9EE585C67C30D1', '4DF064394CBFEB033C4DFB1613957D88F464F4BF250CCA62A056B87AB697B9AA'),
    @('Update-RTMView.ps1',             '29F139FB4EB5C7ACE972D9135ABFAF7A3A802D7F32D8D2451C6731AD12A9406E', 'A88453E0B4A45F193FA643C5E5A5C1B0A8486D5B875BF27C3B08434ED90ACF03'),
    @('db/tools/Provision-FreshDb.ps1', '4FCCB5F80D5D479F623093CA58D6EF2025E9BF17660FA6E2D6BE30AC2EF80177', '931B563FA6569021B7010402362E81CD067086D0AD2A87740DD270F85B2EE66E'),
    @('db/tools/Restore-All.ps1',       '0F01D7F1425B2C9319D920243FA6FAD9A63CE0C63801C44DF5D6A1C7D50F9DE6', 'E9C4AF40A79EDDD29AB31CA15C67844B0A3B626603337787184D049D873C58A7')
)
foreach ($z in @($ZIPRTM, $ZIPSHELL)) {
    Say ('  --- package {0} ---' -f (Split-Path $z -Leaf))
    $zip = [System.IO.Compression.ZipFile]::OpenRead($z)
    try {
        $names = @($zip.Entries | ForEach-Object { Normalise-EntryName $_.FullName })
        Say ('      entries {0} , of them carrying a backslash BEFORE normalising : {1}' -f $zip.Entries.Count, @($zip.Entries | Where-Object { $_.FullName.Contains([string][char]92) }).Count)
        Say ('      after normalising, names containing a backslash : {0}   expected 0' -f @($names | Where-Object { $_.Contains([string][char]92) }).Count)
        if (@($names | Where-Object { $_.Contains([string][char]92) }).Count -ne 0) { Say '      *** normalising left separators behind - stop'; $zip.Dispose(); Fin $false }
        Say ('      NEGCTL normalised names equal to an impossible entry : {0}   expected 0' -f @($names | Where-Object { $_ -eq 'db/tools/ZzzNoSuch.ps1' }).Count)
        Say ('      POSCTL normalised names equal to db/schema.sql : {0}   expected 1 - proves the matcher finds a nested file' -f @($names | Where-Object { $_ -eq 'db/schema.sql' }).Count)
        if (@($names | Where-Object { $_ -eq 'db/schema.sql' }).Count -lt 1) { Say '      *** the matcher cannot find a nested file known to ship - stop'; $zip.Dispose(); Fin $false }
        foreach ($w in $wanted) {
            $name = $w[0]; $expNew = $w[1]; $expOld = $w[2]
            $hits = @($zip.Entries | Where-Object { (Normalise-EntryName $_.FullName) -eq $name })
            Say ('      {0}' -f $name)
            Say ('          copies in the package : {0}   membership is the question, not the count' -f $hits.Count)
            if ($hits.Count -lt 1) { Say '          -> FAIL  genuinely ABSENT from this package'; $fails++; continue }
            foreach ($h in $hits) {
                Say ('          entry name as stored : {0}' -f $h.FullName)
                $ms = New-Object System.IO.MemoryStream
                $es = $h.Open()
                try { $es.CopyTo($ms) } finally { $es.Dispose() }
                $raw = $ms.ToArray(); $ms.Dispose()
                $hasBom = ($raw.Length -ge 3 -and $raw[0] -eq 239 -and $raw[1] -eq 187 -and $raw[2] -eq 191)
                $crCount = @($raw | Where-Object { $_ -eq 13 }).Count
                $nrmSha = Get-Sha256OfBytes (To-LfBytes $raw)
                Say ('          bytes {0} , BOM {1} , CR bytes {2}' -f $raw.Length, $hasBom, $crCount)
                Say ('          raw sha256        {0}' -f (Get-Sha256OfBytes $raw))
                Say ('          normalised sha256 {0}' -f $nrmSha)
                Say ('          equals the b4ad301 content  : {0}   expected True' -f ($nrmSha -eq $expNew))
                if ($nrmSha -ne $expNew) { Say '          -> FAIL  this is NOT the file we committed'; $fails++ }
                Say ('          equals the PRE-EDIT content : {0}   expected False' -f ($nrmSha -eq $expOld))
                if ($nrmSha -eq $expOld) { Say '          -> FAIL  the old revision travelled'; $fails++ }
                if (-not $hasBom) { Say '          -> FAIL  no BOM: Windows PowerShell 5.1 would fail to parse this on the server'; $fails++ }
                if ($crCount -lt 1) { Say '          -> FAIL  no CR bytes: the zipping step did not apply CRLF'; $fails++ }
            }
        }
    } finally { $zip.Dispose() }
    Say ''
}

Say '===== 2  what is still NOT proven - unchanged by this re-run ====='
Say '  db/tools/Provision-FreshDb.ps1 travels as a PASSENGER: Update-RTMView.ps1 never calls it, so its'
Say '  presence says nothing about the sequence resync working. PR234-INST-11 stays OPEN and closes only on'
Say '  a fresh install where step 7 runs and prints a processed count greater than zero.'
Say '  The adapter package is a separate artifact and is not touched here.'
Say ''

Say '===== SUMMARY ====='
Say ('  v3 revision built : {0}' -f $PIN)
Say ('  RTM   package sha : {0}' -f $SHARTM)
Say ('  Shell package sha : {0}' -f $SHASHELL)
Say ('  failures          : {0}   anything above zero means DO NOT SEND THESE PACKAGES ANYWHERE' -f $fails)
Say ('  collector still intact : {0}   expected ArrayList' -f $ProbeLines.GetType().Name)
Say '  NOTHING WAS BUILT, UNPACKED TO DISK, INSTALLED, SENT, RESTARTED OR DELETED. NO SERVER, NO DATABASE.'
Say '===== END-OF-RUN MARKER: PACKAGE-GATE-V2-COMPLETE ====='
Fin ($fails -eq 0)
