#Requires -Version 5.1
<#
  BOX LOCAL / build-b4ad301
  WHERE IT RUNS : the LOCAL workstation (the build machine), and it REFUSES to run anywhere else - the
                  host name is a gate. NO server is contacted, NO database, NO deploy, NO service touched.
                  234 is not addressed by a single command; PG15 on 5432 and PG18 on 5433 are not contacted.
  WHAT IT WRITES: two package .zip files inside the already-gated clone (its Installations folder), plus
                  its own report, the build console logs and one PACKAGE_SHA256 file under D:\Claude\Build.
                  The working repository is only READ. No index-touching git command runs against it.
  WHAT IT DOES  : builds -Mode RTM and -Mode Shell from the gated clone, then makes each package PROVE
                  its own contents by hash, then writes the numbers that will travel to the server.

  MODE. The coordinator decided: -Mode RTM plus -Mode Shell, NO -Mode Full and NO -FreshDb. Install on the
  server goes through Update-RTMView.ps1, which preserves the machine configuration. -SkipDB is mine and
  stated: the pg_dump DB/ folder is not needed for an Update-path deploy, and skipping it removes the
  database password from this run entirely. The db/ MODULE is copied by an unconditional block in the
  builder, so db/tools/ ships in both packages regardless of mode.

  WHAT THIS BOX DOES NOT PROVE, said before the numbers rather than after them: the fixed step 7 of
  Provision-FreshDb.ps1 travels as a PASSENGER. Update-RTMView never calls it. Its presence in the package
  is a fact about the package CONTENTS and says nothing about the resync working. PR234-INST-11 is NOT
  closed by this batch; it closes only on a fresh install where step 7 actually runs and prints a non-zero
  count of processed sequences.

  -GarnetDir and -NssmDir point at the WORKING TREE cache on purpose: tools/cache is gitignored, so a fresh
  clone never carries those third-party binaries. The first build attempt on 08.09 died in pre-flight for
  exactly this reason. The code still comes from the clone; only Garnet and NSSM come from the cache, and
  they are read, never written.

  EVERY expectation is printed BEFORE the measured value. Every negative control is a GATE: a control that
  must fail and does not stops the run instead of reporting green.
#>

$ErrorActionPreference = 'Continue'

$HOSTGATE   = 'LAPTOP-M4B1MKEC'
$PIN        = 'b4ad3014805ef647fc2e551357955d644a2298aa'
$UNACCEPTED = 'ce66691f599b43208e86e27ab870fccd24203365'
$ADAPTERREV = 'aa1974351c72cbba24f76216c8d17d12102c508f'
$CLONE      = 'D:\Claude\Build\rtm_clean_b4ad301'
$SRC        = 'D:\Claude\Projects\RTM View Shell'
$OutDir     = 'D:\Claude\Build'
$GARNETDIR  = 'D:\Claude\Projects\RTM View Shell\tools\cache\garnet-1.1.10-win-x64-net8'
$NSSMDIR    = 'D:\Claude\Projects\RTM View Shell\tools\cache\nssm'

$stamp    = Get-Date -Format yyyyMMdd_HHmmss
$outf     = Join-Path $OutDir ('LOCAL_' + $stamp + '_build-b4ad301.txt')
$logRTM   = Join-Path $OutDir ('LOCAL_' + $stamp + '_build-console-RTM.txt')
$logShell = Join-Path $OutDir ('LOCAL_' + $stamp + '_build-console-Shell.txt')
$shaFile  = Join-Path $OutDir ('PACKAGE_SHA256_' + $stamp + '.txt')

$ProbeLines = New-Object System.Collections.ArrayList
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$ProbeLines.Add('')
    [void]$ProbeLines.Add($(if ($pass) { 'VERDICT: PASS' } else { 'VERDICT: FAIL' }))
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT       : ' + $outf)
    Write-Host ('BUILD LOG RTM: ' + $logRTM)
    Write-Host ('BUILD LOG SHL: ' + $logShell)
    Write-Host ('SHA FILE     : ' + $shaFile)
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

Say '===== G1  the instrument and the machine are checked FIRST, each control a gate ====='
$self = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ('  Get-Sha256Of resolves to : {0}   expected Function' -f $self.CommandType)
if ("$($self.CommandType)" -ne 'Function') { Say '  *** shadowed helper - stop'; Fin $false }
Say ('  NEGCTL sha of a missing path : {0}   expected ABSENT' -f (Get-Sha256Of 'C:\zzz-no-such-file.bin'))
if ((Get-Sha256Of 'C:\zzz-no-such-file.bin') -ne 'ABSENT') { Say '  *** cannot report absence - stop'; Fin $false }
Say ('  this box   : {0}' -f $MyInvocation.MyCommand.Path)
Say ('  its sha256 : {0}   compare with the number named BEFORE the run' -f (Get-Sha256Of $MyInvocation.MyCommand.Path))
Say ('  host is {0} , expected {1}' -f $env:COMPUTERNAME, $HOSTGATE)
if ($env:COMPUTERNAME -ne $HOSTGATE) { Say '  *** this is not the build machine - refusing to build here'; Fin $false }
Say ('  PowerShell {0}' -f $PSVersionTable.PSVersion)
$git = Get-Command git.exe -ErrorAction SilentlyContinue
if ($null -eq $git) { Say '  *** git.exe NOT FOUND - stop'; Fin $false }
$dotnet = Get-Command dotnet.exe -ErrorAction SilentlyContinue
if ($null -eq $dotnet) { Say '  *** dotnet.exe NOT FOUND - the build cannot run'; Fin $false }
Say ('  git    : {0}' -f $git.Source)
Say ('  dotnet : {0}   version {1}' -f $dotnet.Source, ("$(& $dotnet.Source --version 2>&1)").Trim())
$freeGb = (Get-PSDrive D).Free / 1GB
Say ('  free space on D: {0:N1} GB   expected at least 10' -f $freeGb)
if ($freeGb -lt 10) { Say '  *** less than 10 GB free - refusing to build'; Fin $false }
Say ''
Say '  --- the line-ending normaliser is proven on a KNOWN case before any package is judged ---'
$crlfSample = [System.Text.Encoding]::UTF8.GetBytes("a`r`nb`r`nc")
$lfSample   = [System.Text.Encoding]::UTF8.GetBytes("a`nb`nc")
$shaCrlfRaw = Get-Sha256OfBytes $crlfSample
$shaCrlfNrm = Get-Sha256OfBytes (To-LfBytes $crlfSample)
$shaLfRaw   = Get-Sha256OfBytes $lfSample
Say ('  normalised CRLF sample equals the LF sample : {0}   expected True' -f ($shaCrlfNrm -eq $shaLfRaw))
Say ('  raw CRLF sample equals the LF sample        : {0}   expected False' -f ($shaCrlfRaw -eq $shaLfRaw))
if ($shaCrlfNrm -ne $shaLfRaw) { Say '  *** the normaliser does not normalise - refusing to judge packages'; Fin $false }
if ($shaCrlfRaw -eq $shaLfRaw) { Say '  *** raw and normalised cannot be equal - the hasher is blind'; Fin $false }
Say '  G1 PASS'
Say ''

Say '===== G2  the clone is still the gated one, and the cache is where the builder will look ====='
Say ('  clone : {0}   exists {1}' -f $CLONE, (Test-Path $CLONE))
if (-not (Test-Path $CLONE)) { Say '  *** the gated clone is gone - stop'; Fin $false }
$head = ("$(& $git.Source -C $CLONE rev-parse HEAD 2>&1)").Trim()
Say ('  HEAD expected {0}' -f $PIN)
Say ('  HEAD actual   {0}' -f $head)
if ($head -ne $PIN) { Say '  *** the clone moved since it was gated - stop'; Fin $false }
$dirty = @(& $git.Source -C $CLONE status --porcelain 2>&1)
Say ('  working tree entries expected 0 : {0}' -f $dirty.Count)
foreach ($dl in $dirty) { Say ('      ' + "$dl") }
if ($dirty.Count -ne 0) { Say '  *** the clone is no longer clean - stop'; Fin $false }
$null = & $git.Source -C $CLONE merge-base --is-ancestor $UNACCEPTED HEAD 2>&1
$rcAnc = $LASTEXITCODE
Say ('  unaccepted {0} an ancestor of HEAD ? exit {1}   expected non-zero, i.e. NO' -f $UNACCEPTED, $rcAnc)
if ($rcAnc -eq 0) { Say '  *** the unaccepted commit is inside what we would build - stop'; Fin $false }
$garnetExe = Join-Path $GARNETDIR 'GarnetServer.exe'
$nssmExe   = Join-Path $NSSMDIR 'nssm.exe'
Say ('  GarnetServer.exe in the working-tree cache : {0}' -f (Test-Path $garnetExe))
Say ('  nssm.exe in the working-tree cache         : {0}' -f (Test-Path $nssmExe))
Say ('  NEGCTL an exe that cannot be there : {0}   expected False' -f (Test-Path (Join-Path $GARNETDIR 'ZzzNoSuch.exe')))
if (-not (Test-Path $garnetExe)) { Say '  *** Garnet binaries missing - the build would die in pre-flight'; Fin $false }
if (-not (Test-Path $nssmExe))   { Say '  *** nssm missing - the build would die in pre-flight'; Fin $false }
$zipsBefore = @(Get-ChildItem (Join-Path $CLONE 'Installations') -File -Filter '*.zip' -ErrorAction SilentlyContinue)
Say ('  packages already in the clone BEFORE this build : {0}' -f $zipsBefore.Count)
foreach ($zb in $zipsBefore) { Say ('      ' + $zb.Name) }
Say '  G2 PASS'
Say ''

$builder = Join-Path $CLONE 'tools\Build-ProdRelease.ps1'

Say '===== 1  BUILD  -Mode RTM   (long step; console goes to its own log) ====='
Say '  command : tools\Build-ProdRelease.ps1 -Mode RTM -SkipDB -GarnetDir <worktree cache> -NssmDir <worktree cache>'
$t0 = Get-Date
Push-Location $CLONE
$outRTM = & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $builder -Mode RTM -SkipDB -GarnetDir $GARNETDIR -NssmDir $NSSMDIR 2>&1
$rcRTM = $LASTEXITCODE
Pop-Location
[IO.File]::WriteAllLines($logRTM, @($outRTM | ForEach-Object { "$_" }), (New-Object System.Text.UTF8Encoding($false)))
Say ('  exit code {0}   expected 0 ; elapsed {1:N0} s ; console lines {2}' -f $rcRTM, ((Get-Date) - $t0).TotalSeconds, @($outRTM).Count)
if ($rcRTM -ne 0) {
    Say '  *** BUILD FAILED - last 30 console lines:'
    foreach ($bl in (@($outRTM) | Select-Object -Last 30)) { Say ('      ' + "$bl") }
    Fin $false
}
foreach ($bl in (@($outRTM) | Select-Object -Last 8)) { Say ('      ' + "$bl") }
Say ''

Say '===== 2  BUILD  -Mode Shell   (long step; console goes to its own log) ====='
Say '  command : tools\Build-ProdRelease.ps1 -Mode Shell -SkipDB -GarnetDir <worktree cache> -NssmDir <worktree cache>'
$t1 = Get-Date
Push-Location $CLONE
$outShell = & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $builder -Mode Shell -SkipDB -GarnetDir $GARNETDIR -NssmDir $NSSMDIR 2>&1
$rcShell = $LASTEXITCODE
Pop-Location
[IO.File]::WriteAllLines($logShell, @($outShell | ForEach-Object { "$_" }), (New-Object System.Text.UTF8Encoding($false)))
Say ('  exit code {0}   expected 0 ; elapsed {1:N0} s ; console lines {2}' -f $rcShell, ((Get-Date) - $t1).TotalSeconds, @($outShell).Count)
if ($rcShell -ne 0) {
    Say '  *** BUILD FAILED - last 30 console lines:'
    foreach ($bl in (@($outShell) | Select-Object -Last 30)) { Say ('      ' + "$bl") }
    Fin $false
}
foreach ($bl in (@($outShell) | Select-Object -Last 8)) { Say ('      ' + "$bl") }
Say ''

$fails = 0

Say '===== 3  which files did the two builds actually produce ====='
$zipsAfter = @(Get-ChildItem (Join-Path $CLONE 'Installations') -File -Filter '*.zip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
Say ('  packages in the clone AFTER the builds : {0}   expected {1}' -f $zipsAfter.Count, ($zipsBefore.Count + 2))
if ($zipsAfter.Count -ne ($zipsBefore.Count + 2)) { Say '      -> FAIL  the number of packages is not what two builds should leave'; $fails++ }
$zipRTM   = @($zipsAfter | Where-Object { $_.Name -like '*_RTM.zip' }   | Select-Object -First 1)
$zipShell = @($zipsAfter | Where-Object { $_.Name -like '*_Shell.zip' } | Select-Object -First 1)
if ($zipRTM.Count -ne 1)   { Say '  *** no _RTM.zip produced - stop';   Fin $false }
if ($zipShell.Count -ne 1) { Say '  *** no _Shell.zip produced - stop'; Fin $false }
$zRTM = $zipRTM[0]; $zShell = $zipShell[0]
foreach ($z in @($zRTM, $zShell)) {
    $ageSec = ((Get-Date) - $z.LastWriteTime).TotalSeconds
    Say ('  {0}' -f $z.FullName)
    Say ('      {0:N1} MB   written {1}   age {2:N0} s   expected small' -f ($z.Length/1MB), $z.LastWriteTime, $ageSec)
    Say ('      sha256 {0}' -f (Get-Sha256Of $z.FullName))
    if ($ageSec -gt 1800) { Say '      -> FAIL  this package predates this run'; $fails++ }
}
Say ''

Say '===== 4  ORIGIN GATE - each package proves its own contents by hash ====='
Say '  Expected NORMALISED (CRLF stripped) sha256 of the four files of this batch, named BEFORE the run:'
Say '    Install-RTMView.ps1        BBB7223E37538FEF28A0F4A51725302AD82703D995848E8A8F9EE585C67C30D1'
Say '    Update-RTMView.ps1         29F139FB4EB5C7ACE972D9135ABFAF7A3A802D7F32D8D2451C6731AD12A9406E'
Say '    db/tools/Provision-FreshDb 4FCCB5F80D5D479F623093CA58D6EF2025E9BF17660FA6E2D6BE30AC2EF80177'
Say '    db/tools/Restore-All       0F01D7F1425B2C9319D920243FA6FAD9A63CE0C63801C44DF5D6A1C7D50F9DE6'
Say '  NEGATIVE HALF - the same four must NOT equal the pre-edit revisions:'
Say '    Install old (84bd7ce^)     4DF064394CBFEB033C4DFB1613957D88F464F4BF250CCA62A056B87AB697B9AA'
Say '    Update old  (84bd7ce^)     A88453E0B4A45F193FA643C5E5A5C1B0A8486D5B875BF27C3B08434ED90ACF03'
Say '    Provision old (e46e3ef^)   931B563FA6569021B7010402362E81CD067086D0AD2A87740DD270F85B2EE66E'
Say '    Restore-All old (e46e3ef^) E9C4AF40A79EDDD29AB31CA15C67844B0A3B626603337787184D049D873C58A7'
Say '  Why normalised: the builder rewrites every .ps1 in staging to UTF-8 BOM plus CRLF before zipping,'
Say '  while the repository stores these files with LF. Comparing raw bytes would report a difference that'
Say '  is the zipping step doing its job. The BOM and the CRLF are reported separately as facts.'
Say ''
Add-Type -AssemblyName System.IO.Compression.FileSystem
$wanted = @(
    @('Install-RTMView.ps1',            'BBB7223E37538FEF28A0F4A51725302AD82703D995848E8A8F9EE585C67C30D1', '4DF064394CBFEB033C4DFB1613957D88F464F4BF250CCA62A056B87AB697B9AA'),
    @('Update-RTMView.ps1',             '29F139FB4EB5C7ACE972D9135ABFAF7A3A802D7F32D8D2451C6731AD12A9406E', 'A88453E0B4A45F193FA643C5E5A5C1B0A8486D5B875BF27C3B08434ED90ACF03'),
    @('db/tools/Provision-FreshDb.ps1', '4FCCB5F80D5D479F623093CA58D6EF2025E9BF17660FA6E2D6BE30AC2EF80177', '931B563FA6569021B7010402362E81CD067086D0AD2A87740DD270F85B2EE66E'),
    @('db/tools/Restore-All.ps1',       '0F01D7F1425B2C9319D920243FA6FAD9A63CE0C63801C44DF5D6A1C7D50F9DE6', 'E9C4AF40A79EDDD29AB31CA15C67844B0A3B626603337787184D049D873C58A7')
)
foreach ($z in @($zRTM, $zShell)) {
    Say ('  --- package {0} ---' -f $z.Name)
    $zip = [System.IO.Compression.ZipFile]::OpenRead($z.FullName)
    try {
        Say ('      entries in the package : {0}' -f $zip.Entries.Count)
        $negMatches = @($zip.Entries | Where-Object { $_.FullName -like '*ZzzNoSuchEntry*' })
        Say ('      NEGCTL entries matching a name that cannot exist : {0}   expected 0' -f $negMatches.Count)
        if ($negMatches.Count -ne 0) { Say '      *** the entry matcher finds what is not there - stop'; $zip.Dispose(); Fin $false }
        $posMatches = @($zip.Entries | Where-Object { $_.FullName -like '*README*' })
        Say ('      POSCTL entries matching README : {0}   expected at least 1, proves the matcher can find' -f $posMatches.Count)
        if ($posMatches.Count -lt 1) { Say '      *** the entry matcher cannot find a file known to ship - stop'; $zip.Dispose(); Fin $false }
        foreach ($w in $wanted) {
            $name = $w[0]; $expNew = $w[1]; $expOld = $w[2]
            $hits = @($zip.Entries | Where-Object { $_.FullName -eq $name })
            Say ('      {0}' -f $name)
            Say ('          copies in the package : {0}   membership is the question, not the count' -f $hits.Count)
            if ($hits.Count -lt 1) { Say '          -> FAIL  ABSENT from this package'; $fails++; continue }
            foreach ($h in $hits) {
                $ms = New-Object System.IO.MemoryStream
                $es = $h.Open()
                try { $es.CopyTo($ms) } finally { $es.Dispose() }
                $raw = $ms.ToArray(); $ms.Dispose()
                $hasBom = ($raw.Length -ge 3 -and $raw[0] -eq 239 -and $raw[1] -eq 187 -and $raw[2] -eq 191)
                $crCount = @($raw | Where-Object { $_ -eq 13 }).Count
                $rawSha = Get-Sha256OfBytes $raw
                $nrmSha = Get-Sha256OfBytes (To-LfBytes $raw)
                Say ('          bytes {0} , BOM {1} , CR bytes {2}   (BOM True and CR above zero are the zipping step working)' -f $raw.Length, $hasBom, $crCount)
                Say ('          raw sha256        {0}' -f $rawSha)
                Say ('          normalised sha256 {0}' -f $nrmSha)
                Say ('          equals the b4ad301 content : {0}   expected True' -f ($nrmSha -eq $expNew))
                if ($nrmSha -ne $expNew) { Say '          -> FAIL  this is NOT the file we committed'; $fails++ }
                Say ('          equals the PRE-EDIT content : {0}   expected False' -f ($nrmSha -eq $expOld))
                if ($nrmSha -eq $expOld) { Say '          -> FAIL  the old revision travelled'; $fails++ }
            }
        }
    } finally { $zip.Dispose() }
    Say ''
}

Say '===== 5  what is NOT proven by the numbers above - said plainly ====='
Say '  db/tools/Provision-FreshDb.ps1 is in the package as a PASSENGER. Update-RTMView.ps1 never calls it,'
Say '  so nothing here shows the sequence resync working. PR234-INST-11 stays OPEN and closes only on a'
Say '  fresh install where step 7 runs and prints a count of processed sequences greater than zero.'
Say '  The adapter package is a SEPARATE artifact and is NOT built by this box: its own publish from'
Say ('  branch adapters at {0}, with log4net.config expected at 761 bytes, CRLF, sha256 1D520F4D...13FA2.' -f $ADAPTERREV)
Say ''

Say '===== 6  the numbers that will travel are written to a file, not remembered ====='
$lines = New-Object System.Collections.ArrayList
[void]$lines.Add('PACKAGES BUILT ' + $stamp + ' on ' + $env:COMPUTERNAME)
[void]$lines.Add('clone        : ' + $CLONE)
[void]$lines.Add('v3 revision  : ' + $head)
[void]$lines.Add('adapter rev  : ' + $ADAPTERREV + '  (NOT built by this box - separate artifact)')
[void]$lines.Add('mode         : RTM and Shell, SkipDB, no FreshDb')
[void]$lines.Add('RTM   zip    : ' + $zRTM.FullName)
[void]$lines.Add('RTM   sha256 : ' + (Get-Sha256Of $zRTM.FullName))
[void]$lines.Add('RTM   bytes  : ' + $zRTM.Length)
[void]$lines.Add('Shell zip    : ' + $zShell.FullName)
[void]$lines.Add('Shell sha256 : ' + (Get-Sha256Of $zShell.FullName))
[void]$lines.Add('Shell bytes  : ' + $zShell.Length)
[void]$lines.Add('failures     : ' + $fails)
[IO.File]::WriteAllLines($shaFile, $lines, (New-Object System.Text.UTF8Encoding($false)))
foreach ($l in $lines) { Say ('      ' + $l) }
Say ('  sha file written : {0}   exists {1}' -f $shaFile, (Test-Path $shaFile))
if (-not (Test-Path $shaFile)) { Say '      -> FAIL  the numbers were not persisted'; $fails++ }
Say ''

Say '===== SUMMARY ====='
Say ('  v3 revision built : {0}' -f $head)
Say ('  packages          : {0} , {1}' -f $zRTM.Name, $zShell.Name)
Say ('  failures          : {0}   anything above zero means DO NOT SEND THESE PACKAGES ANYWHERE' -f $fails)
Say ('  collector still intact : {0}   expected ArrayList' -f $ProbeLines.GetType().Name)
Say '  NOTHING WAS INSTALLED, SENT, RESTARTED OR DELETED. NO SERVER AND NO DATABASE WAS CONTACTED.'
Say '===== END-OF-RUN MARKER: BUILD-B4AD301-COMPLETE ====='
Fin ($fails -eq 0)
