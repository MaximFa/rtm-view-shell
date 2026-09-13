#Requires -Version 5.1
<#
  PROBE LOCAL / installer-89b   -   READ ONLY. Nothing is built, installed or written into the clone.
  WHERE IT RUNS : the BUILD machine (the workstation holding the clone and the package).
                  It REFUSES to run on server 234. Production takes no part in this task.
  WHAT IT ANSWERS : are the six changes of commit 20b9c65 present in what we ship TODAY, and
                  does the package carry exactly the text that was checked.
  HOW IT CANNOT LIE : every predicate is also run against 20b9c65^, where the change is absent by
                  construction, and MUST return the opposite number. A predicate that answers the
                  same on both revisions is declared USELESS and its result is not counted.
  Counts are LINES (git grep -c), stated PER FILE - never summed across the two files.
#>

$ErrorActionPreference = "Continue"
$Repo    = "D:\Claude\Projects\RTM View Shell"
$Pkg     = "D:\Claude\Build\rtm_clean_20260908_101212\Installations\08092026.1037.zip"
$NewRev  = "v3"
$OldRev  = "20b9c65^"
$InstF   = "deploy/Install-RTMView.ps1"
$UpdF    = "deploy/Update-RTMView.ps1"

$OutDir = Join-Path $Repo ".measurements"
if (-not (Test-Path $OutDir)) { $OutDir = $env:TEMP }
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ("LOCAL_{0}_installer-89b.txt" -f $stamp)
$ProbeLines = New-Object System.Collections.ArrayList
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$ProbeLines.Add("")
    [void]$ProbeLines.Add($(if ($pass) { "RUN COMPLETE" } else { "RUN ABORTED" }))
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function GitLines($rev, $file, $pattern) {
    $raw = & git -C $Repo grep -c -F -e $pattern $rev -- $file 2>$null
    if (-not $raw) { return 0 }
    $n = 0
    foreach ($line in @($raw)) {
        $m = [regex]::Match("$line", ":(\d+)\s*$")
        if ($m.Success) { $n += [int]$m.Groups[1].Value }
    }
    return $n
}

Say "===== WHERE IT RUNS ====="
Say "  the BUILD machine - repository and package only. Server 234 is NOT touched, nothing is written."
Say ("  probe file sha256 : {0}" -f (Get-FileHash -Path $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Say ("  report goes to    : {0}" -f $outf)
Say ("  local time now    : {0}" -f (Get-Date))
Say ""

Say "===== G0  this is NOT the server, and the inputs exist (gate) ====="
Say ("  machine name : {0}   (must NOT be RTM - that is server 234)" -f $env:COMPUTERNAME)
if ($env:COMPUTERNAME -eq "RTM") { Say "  *** this is server 234 - this task must not run here; aborting"; Fin $false }
Say ("  clone   : {0}   exists {1}" -f $Repo, (Test-Path $Repo))
Say ("  package : {0}   exists {1}" -f $Pkg, (Test-Path $Pkg))
if (-not (Test-Path $Repo)) { Say "  *** clone not found - nothing can be measured; aborting"; Fin $false }
$gitv = & git -C $Repo --version 2>$null
Say ("  git     : {0}" -f $(if ($gitv) { "$gitv" } else { "NOT AVAILABLE" }))
if (-not $gitv) { Say "  *** git not available - the object store is unreachable; aborting"; Fin $false }
Say ("  {0} resolves to : {1}" -f $NewRev, (& git -C $Repo rev-parse $NewRev 2>$null))
Say ("  {0} resolves to : {1}" -f $OldRev, (& git -C $Repo rev-parse $OldRev 2>$null))
Say "  G0 PASS"
Say ""

Say "===== G1  the instrument must be able to answer BOTH ways (gate) ====="
$negA = GitLines $NewRev $InstF "ThisMarkerMustNotExistAnywhere"
$negB = GitLines $OldRev $InstF "ThisMarkerMustNotExistAnywhere"
$posA = GitLines $NewRev $InstF "param("
$posB = GitLines $OldRev $InstF "param("
$qA = GitLines $NewRev $InstF '"appsettings.json"'
$qB = GitLines $OldRev $InstF '"appsettings.json"'
Say ("  expected : absent marker -> 0 on both ; present text 'param(' -> non-zero on both")
Say ("  expected : a pattern CONTAINING DOUBLE QUOTES -> non-zero on both (v3 4 / 20b9c65^ 2)")
Say ("  measured : absent marker {0} / {1} ; 'param(' {2} / {3}" -f $negA, $negB, $posA, $posB)
Say ("  measured : quoted pattern {0} / {1}" -f $qA, $qB)
Say "  WHY the quoted control exists: run 17:23 lost CHECK 3 because PowerShell strips inline double"
Say "  quotes when handing an argument to a native tool, so git searched for text nobody wrote and"
Say "  answered 0 everywhere. The old self-check used quote-free patterns and could not see it."
if (($negA -ne 0) -or ($negB -ne 0)) { Say "  *** the search finds what does not exist - the harness is broken; aborting"; Fin $false }
if (($posA -le 0) -or ($posB -le 0)) { Say "  *** the search cannot find what does exist - it is blind; aborting"; Fin $false }
if (($qA -le 0) -or ($qB -le 0)) { Say "  *** double quotes do not survive the call to git - every quoted predicate below would answer 0; aborting"; Fin $false }
Say "  G1 PASS"
Say ""

$checks = @(
    [pscustomobject]@{ N=1; What="Install preserves the Shell config before the package overwrites it";
                       Pat='$preserveShell = @('; ExpNewI=1; ExpNewU=0; ExpOldI=0; ExpOldU=0; DiscrFile="Install" },
    [pscustomobject]@{ N=2; What="what was preserved is written back, and says so out loud";
                       Pat='package version ignored'; ExpNewI=2; ExpNewU=2; ExpOldI=0; ExpOldU=0; DiscrFile="both" },
    [pscustomobject]@{ N=3; What="the RTM preserve list (the one carrying data.sys) exists in the INSTALLER";
                       Pat='$preserveRTM = @('; ExpNewI=1; ExpNewU=1; ExpOldI=0; ExpOldU=1; DiscrFile="Install" },
    [pscustomobject]@{ N=4; What="RTM gets its own connection string, carrying the DB PORT";
                       Pat='RTMConnectionString'; ExpNewI=3; ExpNewU=0; ExpOldI=0; ExpOldU=0; DiscrFile="Install" },
    [pscustomobject]@{ N=5; What="Update reads the preserved files BYTE-EXACT";
                       Pat='preserved[$pf] = [System.IO.File]::ReadAllBytes'; ExpNewI=0; ExpNewU=1; ExpOldI=0; ExpOldU=0; DiscrFile="Update" },
    [pscustomobject]@{ N=6; What="INVERTED: the old text round-trip that added a BOM is GONE";
                       Pat='Set-Content $dst $kv.Value -Encoding UTF8'; ExpNewI=0; ExpNewU=0; ExpOldI=0; ExpOldU=1; DiscrFile="Update" }
)

$allOk = $true
foreach ($c in $checks) {
    Say ("===== CHECK {0} - {1} =====" -f $c.N, $c.What)
    Say ("  pattern : {0}" -f $c.Pat)
    Say ("  expected LINES (per file, never summed):")
    Say ("      {0}      Install={1}  Update={2}" -f $NewRev, $c.ExpNewI, $c.ExpNewU)
    Say ("      {0}  Install={1}  Update={2}" -f $OldRev, $c.ExpOldI, $c.ExpOldU)
    $nI = GitLines $NewRev $InstF $c.Pat
    $nU = GitLines $NewRev $UpdF  $c.Pat
    $oI = GitLines $OldRev $InstF $c.Pat
    $oU = GitLines $OldRev $UpdF  $c.Pat
    Say ("  measured LINES:")
    Say ("      {0}      Install={1}  Update={2}" -f $NewRev, $nI, $nU)
    Say ("      {0}  Install={1}  Update={2}" -f $OldRev, $oI, $oU)
    $numbersOk = (($nI -eq $c.ExpNewI) -and ($nU -eq $c.ExpNewU) -and ($oI -eq $c.ExpOldI) -and ($oU -eq $c.ExpOldU))
    if ($c.DiscrFile -eq "Install")   { $discr = ($nI -ne $oI) }
    elseif ($c.DiscrFile -eq "Update"){ $discr = ($nU -ne $oU) }
    else                              { $discr = (($nI -ne $oI) -and ($nU -ne $oU)) }
    Say ("  all four numbers as expected : {0}" -f $numbersOk)
    Say ("  NEGATIVE HALF - the same predicate on {0} differs in {1} : {2}" -f $OldRev, $c.DiscrFile, $discr)
    if ($c.N -eq 3) {
        Say "  note: Update carries this line in BOTH revisions (1 and 1) - that half is NOT a discriminator and is not counted as one"
        Say "  note: the pattern is deliberately quote-free; the quoted form lost its quotes on the way to git in run 17:23"
        $q3 = GitLines $NewRev $InstF 'data.sys'
        Say ("  supporting reading: lines mentioning data.sys in {0} Install = {1} (expected non-zero)" -f $NewRev, $q3)
    }
    if ($c.N -eq 6) { Say "  note: here ZERO is the success, which is why the negative half is mandatory - the old revision must answer 1" }
    if ($numbersOk -and $discr) { Say ("  CHECK {0} : PASS" -f $c.N) }
    else {
        $allOk = $false
        if (-not $numbersOk) { Say ("  CHECK {0} : FAIL - a number differs from the expectation named before the run" -f $c.N) }
        else { Say ("  CHECK {0} : FAIL - the predicate answers the SAME on both revisions, so it proves nothing" -f $c.N) }
    }
    Say ""
}

Say "===== CHECK 7 - THE PACKAGE, not the repository. This is the one that speaks about the server. ====="
$pkgOk = $false
if (-not (Test-Path $Pkg)) {
    Say ("  package NOT FOUND at {0}" -f $Pkg)
    Say "  search area was exactly this path - no mask, no other root was tried"
    Say "  CHECK 7 : NOT MEASURED - checks 1-6 remain true ABOUT THE REPOSITORY and say nothing about what ships"
    $allOk = $false
} else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Pkg)
    $entries = @($zip.Entries | Where-Object { $_.Name -eq "Install-RTMView.ps1" })
    Say ("  entries named Install-RTMView.ps1 inside the package : {0}" -f $entries.Count)
    foreach ($e in $entries) { Say ("      {0}   {1} bytes" -f $e.FullName, $e.Length) }
    if ($entries.Count -eq 0) {
        Say "  the package does not carry the installer under that name - CHECK 7 FAIL"
        $allOk = $false
    } else {
        $expectNew = (& git -C $Repo rev-parse ("{0}:{1}" -f $NewRev, $InstF) 2>$null)
        $expectOld = (& git -C $Repo rev-parse ("{0}:{1}" -f $OldRev, $InstF) 2>$null)
        Say ("  expected blob {0} : {1}" -f $NewRev, $expectNew)
        Say ("  the same file at {0} : {1}   (the extracted copy must NOT equal this)" -f $OldRev, $expectOld)
        $i = 0
        foreach ($e in $entries) {
            $i++
            $tmp = Join-Path $env:TEMP ("inst89_{0}_{1}.ps1" -f $stamp, $i)
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $tmp, $true)
            $blob = (& git -C $Repo hash-object $tmp 2>$null)
            $sha  = (Get-FileHash -Path $tmp -Algorithm SHA256).Hash
            Say ("  copy {0} : {1}" -f $i, $e.FullName)
            Say ("      git blob : {0}" -f $blob)
            Say ("      sha256   : {0}" -f $sha)
            Say ("      equals {0} : {1}" -f $NewRev, ("$blob" -eq "$expectNew"))
            Say ("      equals {0} (must be False) : {1}" -f $OldRev, ("$blob" -eq "$expectOld"))
            if (("$blob" -eq "$expectNew") -and ("$blob" -ne "$expectOld")) { $pkgOk = $true }
            Remove-Item $tmp -ErrorAction SilentlyContinue
        }
        if ($pkgOk) { Say "  CHECK 7 : PASS - the package carries exactly the text checked above" }
        else {
            Say "  CHECK 7 : FAIL - the package does NOT carry the checked text."
            Say "  Then checks 1-6 are true ABOUT THE REPOSITORY ONLY and assert nothing about what would be installed."
            $allOk = $false
        }
    }
    $zip.Dispose()
}
Say ""

Say "===== SUMMARY ====="
Say ("  checks 1-6 (repository) + check 7 (package) all closed : {0}" -f $allOk)
Say ("  collector still intact : {0}   (must be ArrayList)" -f $ProbeLines.GetType().Name)
Say "  Everything above is a reading. NOTHING WAS BUILT, INSTALLED OR MODIFIED."
Say "===== END-OF-RUN MARKER: INSTALLER-89B-COMPLETE ====="
Say ("  LAST LINE : {0}" -f $(if ($allOk) { "PASS" } else { "FAIL (read the checks - at least one gate did not close)" }))
Fin $allOk
