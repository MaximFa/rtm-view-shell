#Requires -Version 5.1
<#
  BOX LOCAL / negctl-packages   -   READ ONLY. Builds nothing, sends nothing, changes nothing.
  WHERE IT RUNS : the LOCAL workstation.

  WHY : the build and the origin gate passed on every content item, but the negative control
  failed - and it failed because of how I chose the file, not because of the package. My rule was
  "the newest zip under D:\Claude\Build other than the new one", and that caught
  RTM\deployment\RTM_v1.0.0_20260531.zip - an unrelated artifact that lives INSIDE the clone and
  has no db/ module at all. Its zero for the seed therefore proved nothing, and my own guard said
  so rather than reporting a false green.

  A negative control has to be the SAME KIND of thing: an earlier RELEASE PACKAGE, which carries
  db/data but must not carry the seed. So this run looks only where packages are produced -
  Installations\ folders - and runs ONE predicate over BOTH the new package and the old ones,
  demanding opposite answers. Same instrument, two objects, contrary results: that is what makes
  a green mean something.
#>

$ErrorActionPreference = "Continue"
$NEWPKG = "D:\Claude\Build\rtm_clean_20260908_101212\Installations\08092026.1037.zip"
$NEWSHA = "D24E7C7ABE3B1C52B796854A4E42591453635F8B6C252A2150853A9CE58C8F38"
$OutDir = "D:\Claude\Build"
$stamp  = Get-Date -Format yyyyMMdd_HHmmss
$outf   = Join-Path $OutDir "LOCAL_$($stamp)_negctl-packages.txt"
$ProbeLines = New-Object System.Collections.ArrayList
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$ProbeLines.Add("")
    [void]$ProbeLines.Add($(if ($pass) { "VERDICT: PASS" } else { "VERDICT: FAIL" }))
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($path) { if (Test-Path $path) { (Get-FileHash $path -Algorithm SHA256).Hash } else { "ABSENT" } }

function Measure-Package($path) {
    $res = New-Object PSObject -Property @{ Path=$path; Entries=-1; DbData=-1; Seed=-1; Installer=-1; Opened=$false }
    $arc = $null
    try { $arc = [IO.Compression.ZipFile]::OpenRead($path) } catch { return $res }
    $res.Opened = $true
    $e = @($arc.Entries)
    $res.Entries   = $e.Count
    $res.DbData    = @($e | Where-Object { $_.FullName -match "(?i)db[\\/]data[\\/]" }).Count
    $res.Seed      = @($e | Where-Object { $_.Name -eq "01_tenants.sql" }).Count
    $res.Installer = @($e | Where-Object { $_.Name -eq "Install-RTMView.ps1" }).Count
    $arc.Dispose()
    return $res
}

Say "===== G1  the instrument checks ITSELF first ====="
$cmd = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ("  Get-Sha256Of resolves to : {0}   (must be Function)" -f $cmd.CommandType)
if ("$($cmd.CommandType)" -ne "Function") { Say "  *** shadowed helper"; Fin $false }
$cmd2 = Get-Command Measure-Package -ErrorAction SilentlyContinue
Say ("  Measure-Package resolves to : {0}   (must be Function)" -f $cmd2.CommandType)
if ("$($cmd2.CommandType)" -ne "Function") { Say "  *** shadowed helper"; Fin $false }
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
Say ("  host {0} / PS {1}" -f $env:COMPUTERNAME, $PSVersionTable.PSVersion)
Say "  G1 PASS"
Say ""

Say "===== 1  the package under test still is the one that was gated ====="
Say ("  path : {0}" -f $NEWPKG)
Say ("  exists : {0}" -f (Test-Path $NEWPKG))
if (-not (Test-Path $NEWPKG)) { Say "  *** the new package is gone"; Fin $false }
$sha = Get-Sha256Of $NEWPKG
Say ("  sha256 expected {0}" -f $NEWSHA)
Say ("  sha256 actual   {0}" -f $sha)
$sameFile = ($sha -eq $NEWSHA)
Say ("  identical : {0}   (must be True - otherwise we are judging a different file)" -f $sameFile)
if (-not $sameFile) { Say "  *** the package changed since the gate"; Fin $false }
Say ""

Say "===== 2  where RELEASE PACKAGES actually live - Installations folders only ====="
$pkgDirs = @()
foreach ($root in @("D:\Claude\Build","D:\Claude\Projects\RTM View Shell")) {
    if (-not (Test-Path $root)) { Say ("  {0} : does not exist" -f $root); continue }
    $dirs = @(Get-ChildItem $root -Recurse -Directory -Filter "Installations" -ErrorAction SilentlyContinue)
    Say ("  {0,-40} : Installations folders {1}" -f $root, $dirs.Count)
    foreach ($dd in $dirs) { $pkgDirs += $dd.FullName }
}
$all = New-Object System.Collections.ArrayList
foreach ($pd in $pkgDirs) {
    foreach ($z in @(Get-ChildItem $pd -File -Filter "*.zip" -ErrorAction SilentlyContinue)) { [void]$all.Add($z) }
}
Say ("  release packages found in total : {0}" -f $all.Count)
if ($all.Count -lt 2) { Say "  *** fewer than two packages - no negative control possible here"; Fin $false }
Say ""

Say "===== 3  ONE predicate, EVERY package. The new one must differ from the old ones. ====="
Say "  columns: entries | db/data entries | 01_tenants.sql | Install-RTMView.ps1"
$oldWithNeighbour = 0
$oldWithSeed = 0
$fails = 0
foreach ($z in ($all | Sort-Object LastWriteTime -Descending)) {
    $m = Measure-Package $z.FullName
    $isNew = ($z.FullName -eq $NEWPKG)
    $tag = $(if ($isNew) { "NEW " } else { "old " })
    if (-not $m.Opened) { Say ("  {0} {1}   *** could not be opened" -f $tag, $z.FullName); continue }
    Say ("  {0} {1,-11} {2,5} | {3,3} | {4,3} | {5,3}   {6}" -f $tag, $z.Name, $m.Entries, $m.DbData, $m.Seed, $m.Installer, $z.LastWriteTime)
    if (-not $isNew) {
        if ($m.DbData -gt 0) { $oldWithNeighbour++ }
        if ($m.Seed -gt 0)   { $oldWithSeed++ }
    } else {
        Say ("       NEW package expects db/data greater than 0 : {0} -> {1}" -f $m.DbData, $(if ($m.DbData -gt 0) { "PASS" } else { "FAIL" }))
        Say ("       NEW package expects 01_tenants.sql = 1     : {0} -> {1}" -f $m.Seed, $(if ($m.Seed -eq 1) { "PASS" } else { "FAIL" }))
        if ($m.DbData -le 0) { $fails++ }
        if ($m.Seed -ne 1)   { $fails++ }
    }
}
Say ""

Say "===== 4  the verdict of the control itself ====="
Say ("  older packages that DO carry db/data (the neighbour) : {0}" -f $oldWithNeighbour)
Say ("  older packages that carry 01_tenants.sql             : {0}" -f $oldWithSeed)
Say "  The control is meaningful only if at least one older package HAS the neighbour and"
Say "  does NOT have the seed: then the zero comes from the file, not from a blind search."
$controlOk = (($oldWithNeighbour -ge 1) -and ($oldWithSeed -eq 0))
Say ("  negative control satisfied : {0}" -f $controlOk)
if ($oldWithNeighbour -lt 1) { Say "  *** no older package carries db/data at all - the control is a GAP, not a pass"; $fails++ }
if ($oldWithSeed -gt 0) { Say "  note: an older package already carries the seed - say which, do not average it away"; $fails++ }
Say ""

Say "===== SUMMARY ====="
Say ("  package  : {0}" -f $NEWPKG)
Say ("  sha256   : {0}" -f $sha)
Say ("  failures : {0}" -f $fails)
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "  NOTHING WAS BUILT, SENT OR CHANGED."
Say "===== END-OF-RUN MARKER: NEGCTL-PACKAGES-COMPLETE ====="
Fin ($fails -eq 0)
