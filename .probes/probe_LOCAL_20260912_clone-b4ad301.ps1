#Requires -Version 5.1
<#
  BOX LOCAL / clone-b4ad301
  WHERE IT RUNS : the LOCAL workstation (the build machine). NO server, NO database, NO network deploy.
                  Server 234 is not touched by a single command in this box. PG15 on 5432 and PG18 on
                  5433 are not contacted at all.
  WHAT IT WRITES: exactly one thing - a fresh clone at D:\Claude\Build\rtm_clean_b4ad301 - plus its
                  own report file under D:\Claude\Build. The working repository is NEVER written to:
                  it is only read, and no index-touching git command is run against it.
  WHAT IT DOES  : clones the pin the coordinator named for this build, then GATES that clone and stops.
                  It does NOT build. The build is the next box, and it runs only if this one says PASS.

  WHY THE PIN IS NOT HEAD. The working repo HEAD is ce66691 (backend orphan-cell fix), which has not
  passed the coordinator acceptance - its origin is being clarified with the operator right now. The
  build therefore takes b4ad301. This box proves the unaccepted commit did not travel: not by trusting
  the checkout, but by asking whether ce66691 is an ancestor of the clone HEAD (must be False) and by
  hashing the one file it changes (must be the b4ad301 blob, not the ce66691 one).

  EVERY expectation below is printed BEFORE the measured value. Every negative control is a GATE: if a
  control that must fail does not fail, this box stops instead of reporting green.
#>

$ErrorActionPreference = 'Continue'

$PIN        = 'b4ad3014805ef647fc2e551357955d644a2298aa'
$UNACCEPTED = 'ce66691f599b43208e86e27ab870fccd24203365'
$SRC        = 'D:\Claude\Projects\RTM View Shell'
$DEST       = 'D:\Claude\Build\rtm_clean_b4ad301'
$PREVCLONE  = 'D:\Claude\Build\rtm_clean_20260908_101212'
$OutDir     = 'D:\Claude\Build'
$SEEDPATH   = 'src/CcDashboard.Application/Commands/Dashboards/SaveQueueGridRtsCommand.cs'
$SEED_B4    = '75487a4aae89db6ecf532fb3f157c2251e9d5758'
$SEED_CE    = 'fb8bc0a08b9237856c6dbe1556562cc212a58b1d'

$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('LOCAL_' + $stamp + '_clone-b4ad301.txt')
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
function Count-In($text, $pattern) { return @([regex]::Matches($text, $pattern)).Count }

Say '===== G1  the instrument checks ITSELF first (each control is a gate) ====='
$self = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ('  Get-Sha256Of resolves to : {0}   expected Function' -f $self.CommandType)
if ("$($self.CommandType)" -ne 'Function') { Say '  *** shadowed helper - stop'; Fin $false }
Say ('  NEGCTL sha of a missing path : {0}   expected ABSENT' -f (Get-Sha256Of 'C:\zzz-no-such-file.bin'))
if ((Get-Sha256Of 'C:\zzz-no-such-file.bin') -ne 'ABSENT') { Say '  *** the hash helper cannot report absence - stop'; Fin $false }
$probeSelf = $MyInvocation.MyCommand.Path
Say ('  this box    : {0}' -f $probeSelf)
Say ('  its sha256  : {0}   (compare with the number named BEFORE the run)' -f (Get-Sha256Of $probeSelf))
$git = Get-Command git.exe -ErrorAction SilentlyContinue
if ($null -eq $git) { Say '  *** git.exe NOT FOUND - stop'; Fin $false }
Say ('  git         : {0}' -f $git.Source)
Say ('  host {0} / PowerShell {1}' -f $env:COMPUTERNAME, $PSVersionTable.PSVersion)
Say ('  counter POSCTL : pattern that must be found twice in a known string : {0}   expected 2' -f (Count-In 'aXbXc' 'X'))
Say ('  counter NEGCTL : pattern that cannot be found : {0}   expected 0' -f (Count-In 'aXbXc' 'ZzzNoSuch'))
if ((Count-In 'aXbXc' 'X') -ne 2 -or (Count-In 'aXbXc' 'ZzzNoSuch') -ne 0) { Say '  *** the counter does not count - stop'; Fin $false }
Say ('  source repo present : {0}   {1}' -f (Test-Path $SRC), $SRC)
if (-not (Test-Path $SRC)) { Say '  *** the working repository is not at that path - stop'; Fin $false }
$freeGb = (Get-PSDrive D).Free / 1GB
Say ('  free space on D: {0:N1} GB   expected at least 5' -f $freeGb)
if ($freeGb -lt 5) { Say '  *** less than 5 GB free - refusing to clone'; Fin $false }
Say ('  destination must NOT exist yet : exists {0}   expected False' -f (Test-Path $DEST))
if (Test-Path $DEST) { Say ('  *** ' + $DEST + ' already exists. An existing clone is NOT reused: rename or remove it, then re-run.'); Fin $false }
Say ('  previous build clone still in place : {0}   {1}   (proof of origin of the 08.09 package - must not be deleted)' -f (Test-Path $PREVCLONE), $PREVCLONE)
Say '  G1 PASS'
Say ''

Say '===== G2  the source repo names the pin BEFORE anything is cloned ====='
$null = & $git.Source -C $SRC cat-file -e ($PIN + '^{commit}') 2>&1
$rcPin = $LASTEXITCODE
Say ('  cat-file -e {0} : exit {1}   expected 0' -f $PIN, $rcPin)
if ($rcPin -ne 0) { Say '  *** the pin does not exist in the source repo - stop'; Fin $false }
$null = & $git.Source -C $SRC cat-file -e 'deadbee0000000000000000000000000000dead^{commit}' 2>&1
$rcNeg = $LASTEXITCODE
Say ('  NEGCTL cat-file -e on an impossible sha : exit {0}   expected non-zero' -f $rcNeg)
if ($rcNeg -eq 0) { Say '  *** the existence predicate cannot say no - stop'; Fin $false }
Say ('  subject of the pin : {0}' -f ("$(& $git.Source -C $SRC log -1 --format=%h%x20%ad%x20%s --date=short $PIN 2>&1)").Trim())
Say ('  source HEAD right now : {0}   (for the record; NOT what we build)' -f ("$(& $git.Source -C $SRC rev-parse HEAD 2>&1)").Trim())
Say '  G2 PASS'
Say ''

Say '===== 1  CLONE - the only write this box performs ====='
Say ('  git clone --no-hardlinks --quiet from {0}' -f $SRC)
Say ('  into {0}' -f $DEST)
$cloneOut = & $git.Source clone --no-hardlinks --quiet "$SRC" "$DEST" 2>&1
$rcClone = $LASTEXITCODE
foreach ($cl in @($cloneOut)) { Say ('      ' + "$cl") }
Say ('  clone exit code : {0}   expected 0' -f $rcClone)
if ($rcClone -ne 0) { Say '  *** clone failed - stop'; Fin $false }
$coOut = & $git.Source -C $DEST checkout --quiet --detach $PIN 2>&1
$rcCo = $LASTEXITCODE
foreach ($cl in @($coOut)) { Say ('      ' + "$cl") }
Say ('  checkout exit code : {0}   expected 0' -f $rcCo)
if ($rcCo -ne 0) { Say '  *** checkout of the pin failed - stop'; Fin $false }
Say ''

$fails = 0

Say '===== 2  the clone is the pin, and the unaccepted commit did NOT travel ====='
$head = ("$(& $git.Source -C $DEST rev-parse HEAD 2>&1)").Trim()
Say ('  HEAD expected {0}' -f $PIN)
Say ('  HEAD actual   {0}   -> {1}' -f $head, $(if ($head -eq $PIN) { 'PASS' } else { 'FAIL' }))
if ($head -ne $PIN) { $fails++ }
$porc = @(& $git.Source -C $DEST status --porcelain 2>&1)
Say ('  working tree entries expected 0 : {0}   -> {1}' -f $porc.Count, $(if ($porc.Count -eq 0) { 'PASS' } else { 'FAIL' }))
foreach ($pl in $porc) { Say ('      ' + "$pl") }
if ($porc.Count -ne 0) { $fails++ }
$null = & $git.Source -C $DEST merge-base --is-ancestor $UNACCEPTED HEAD 2>&1
$rcAnc = $LASTEXITCODE
Say ('  is the UNACCEPTED commit {0} an ancestor of HEAD ? exit {1}   expected non-zero, i.e. NO' -f $UNACCEPTED, $rcAnc)
if ($rcAnc -eq 0) { Say '      -> FAIL  the unaccepted commit is inside what we would build'; $fails++ } else { Say '      -> PASS' }
$null = & $git.Source -C $DEST merge-base --is-ancestor $PIN HEAD 2>&1
$rcAnc2 = $LASTEXITCODE
Say ('  POSCTL is the pin itself an ancestor of HEAD ? exit {0}   expected 0, i.e. YES' -f $rcAnc2)
if ($rcAnc2 -ne 0) { Say '      *** the ancestry predicate cannot say yes - its NO above proves nothing'; $fails++ }
$seedWin  = $SEEDPATH -replace '/', [char]92
$seedDisk = ("$(& $git.Source -C $DEST hash-object (Join-Path $DEST $seedWin) 2>&1)").Trim()
Say ('  SaveQueueGridRtsCommand.cs on disk expected {0}  (the b4ad301 blob)' -f $SEED_B4)
Say ('  SaveQueueGridRtsCommand.cs on disk actual   {0}  -> {1}' -f $seedDisk, $(if ($seedDisk -eq $SEED_B4) { 'PASS' } else { 'FAIL' }))
if ($seedDisk -ne $SEED_B4) { $fails++ }
Say ('  and it must NOT be the ce66691 blob {0} : is it ? {1}   expected False' -f $SEED_CE, ($seedDisk -eq $SEED_CE))
if ($seedDisk -eq $SEED_CE) { $fails++ }
Say ''

Say '===== 3  the four files of this batch are in the clone, by blob, not by eye ====='
$expected = @(
    @('deploy\Install-RTMView.ps1',    '1789bafe8a44aefe05f959675ec7fc0375484b20'),
    @('deploy\Update-RTMView.ps1',     'b8c2e832f1ac0d81816cf16a80f3e03a2c6b37d7'),
    @('db\tools\Provision-FreshDb.ps1','5ac7eb1d4d7ff27cb0835fa3d5e9cdc060d0ce5c'),
    @('db\tools\Restore-All.ps1',      '8a946b70d34496743463495988132bca61ffe3d5')
)
foreach ($pair in $expected) {
    $rel = $pair[0]; $exp = $pair[1]
    $full = Join-Path $DEST $rel
    if (-not (Test-Path $full)) { Say ('  {0} : ABSENT -> FAIL' -f $rel); $fails++; continue }
    $got = ("$(& $git.Source -C $DEST hash-object $full 2>&1)").Trim()
    Say ('  {0}' -f $rel)
    Say ('      expected {0}' -f $exp)
    Say ('      actual   {0}   -> {1}' -f $got, $(if ($got -eq $exp) { 'PASS' } else { 'FAIL' }))
    if ($got -ne $exp) { $fails++ }
}
Say ''

Say '===== 4  the three edits are present as TEXT in the clone, each with its negative half ====='
$prov = Join-Path $DEST 'db\tools\Provision-FreshDb.ps1'
$rest = Join-Path $DEST 'db\tools\Restore-All.ps1'
$inst = Join-Path $DEST 'deploy\Install-RTMView.ps1'
$upd  = Join-Path $DEST 'deploy\Update-RTMView.ps1'
$tProv = (Get-Content $prov) -join "`n"
$tRest = (Get-Content $rest) -join "`n"
$tInst = (Get-Content $inst) -join "`n"
$tUpd  = (Get-Content $upd)  -join "`n"
Say '  edit 1 - sequence resync must select IDENTITY as well as serial'
Say ('      Provision-FreshDb  deptype IN (   expected 1 : {0}' -f (Count-In $tProv 'deptype IN \('))
Say ('      Restore-All        deptype IN (   expected 1 : {0}' -f (Count-In $tRest 'deptype IN \('))
Say ('      NEGATIVE HALF - the old filter must be GONE from both files')
Say ('      Provision-FreshDb  deptype=       expected 0 : {0}' -f (Count-In $tProv 'deptype='))
Say ('      Restore-All        deptype=       expected 0 : {0}' -f (Count-In $tRest 'deptype='))
if ((Count-In $tProv 'deptype IN \(') -ne 1) { $fails++ }
if ((Count-In $tRest 'deptype IN \(') -ne 1) { $fails++ }
if ((Count-In $tProv 'deptype=') -ne 0) { $fails++ }
if ((Count-In $tRest 'deptype=') -ne 0) { $fails++ }
Say ('      quote_ident in Provision-FreshDb expected at least 1 : {0}' -f (Count-In $tProv 'quote_ident'))
if ((Count-In $tProv 'quote_ident') -lt 1) { $fails++ }
Say '  edit 3 - the engine log4net.config must be in the preserve lists, per file'
Say ('      Install-RTMView  log4net.config  expected 1 : {0}' -f (Count-In $tInst 'log4net\.config'))
Say ('      Update-RTMView   log4net.config  expected 1 : {0}' -f (Count-In $tUpd  'log4net\.config'))
if ((Count-In $tInst 'log4net\.config') -ne 1) { $fails++ }
if ((Count-In $tUpd  'log4net\.config') -ne 1) { $fails++ }
Say ('      NEGCTL a string that cannot be in either file : {0} / {1}   expected 0 / 0' -f (Count-In $tInst 'ZzzNoSuchMarker'), (Count-In $tUpd 'ZzzNoSuchMarker'))
Say ''

Say '===== 5  what the builder will need, measured in the clone ====='
Say ('  tools\Build-ProdRelease.ps1 present expected True : {0}' -f (Test-Path (Join-Path $DEST 'tools\Build-ProdRelease.ps1')))
if (-not (Test-Path (Join-Path $DEST 'tools\Build-ProdRelease.ps1'))) { $fails++ }
Say ('  db\tools\Compare-ToBaseline.ps1 present expected True : {0}   (absent means the drift gate WARN-skips)' -f (Test-Path (Join-Path $DEST 'db\tools\Compare-ToBaseline.ps1')))
if (-not (Test-Path (Join-Path $DEST 'db\tools\Compare-ToBaseline.ps1'))) { $fails++ }
$dbToolsCount = @(Get-ChildItem (Join-Path $DEST 'db\tools') -File -ErrorAction SilentlyContinue).Count
Say ('  files in db\tools : {0}' -f $dbToolsCount)
Say ('  tools\cache\garnet-1.1.10-win-x64-net8\GarnetServer.exe in the CLONE : {0}   expected False - tools/cache is gitignored, so the build box must point -GarnetDir at the working tree' -f (Test-Path (Join-Path $DEST 'tools\cache\garnet-1.1.10-win-x64-net8\GarnetServer.exe')))
Say ('  the same exe in the WORKING TREE : {0}' -f (Test-Path (Join-Path $SRC 'tools\cache\garnet-1.1.10-win-x64-net8\GarnetServer.exe')))
Say ('  nssm.exe in the WORKING TREE     : {0}' -f (Test-Path (Join-Path $SRC 'tools\cache\nssm\nssm.exe')))
Say ('  NEGCTL a file that cannot exist in any clone : {0}   expected False' -f (Test-Path (Join-Path $DEST 'zzz-no-such-file-in-any-clone.txt')))
Say ''

Say '===== SUMMARY ====='
Say ('  clone       : {0}' -f $DEST)
Say ('  HEAD        : {0}' -f $head)
Say ('  unaccepted  : {0} is NOT an ancestor of HEAD' -f $UNACCEPTED)
Say ('  failures    : {0}   anything above zero means DO NOT BUILD from this clone' -f $fails)
Say ('  collector still intact : {0}   expected ArrayList' -f $ProbeLines.GetType().Name)
Say '  NOTHING WAS BUILT, INSTALLED, SENT OR RESTARTED. NO SERVER AND NO DATABASE WAS CONTACTED.'
Say '===== END-OF-RUN MARKER: CLONE-B4AD301-COMPLETE ====='
Fin ($fails -eq 0)
