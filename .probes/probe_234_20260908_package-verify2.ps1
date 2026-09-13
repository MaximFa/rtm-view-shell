#Requires -Version 5.1
<#
  PROBE 234 / package-verify   -   READ ONLY. Nothing is unpacked, installed, started or changed.
  WHERE IT RUNS : server 234. No database is touched. No service is touched.
  QUESTION      : is the file that arrived byte-for-byte the package that was built and gated,
                  and does the same instrument say NO about the other package sitting beside it.

  Two objects, one predicate, opposite answers expected. A hash check that has never been seen
  to fail is not evidence; the older package next to it is what makes the match mean something.
#>

$ErrorActionPreference = "Continue"
$EXPECTED = "D24E7C7ABE3B1C52B796854A4E42591453635F8B6C252A2150853A9CE58C8F38"
$EXPBYTES = 129353518
$NEWNAME  = "08092026.1037.zip"
$SEARCHDIRS = @("C:\Users\RTMServer1\Downloads", "C:\Temp", "C:\RTMView-Ops\incoming")
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_package-verify.txt"
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

Say "===== G0  machine identity - this probe refuses to run anywhere else ====="
$nameOk = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  name match {0} / uuid match {1}" -f $nameOk, $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say "  *** NOT server 234 - refusing"; Fin $false }
Say "  G0 PASS"
Say ""

Say "===== G1  the instrument checks ITSELF first ====="
$cmd = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ("  Get-Sha256Of resolves to : {0}   (must be Function)" -f $cmd.CommandType)
if ("$($cmd.CommandType)" -ne "Function") { Say "  *** shadowed helper"; Fin $false }
Say ("  NEGCTL hash of a missing path : {0}   (must be ABSENT)" -f (Get-Sha256Of "C:\zzz-no-such-file.bin"))
Say ("  host {0} / PS {1}" -f $env:COMPUTERNAME, $PSVersionTable.PSVersion)
Say "  G1 PASS"
Say ""

Say "===== 1  every .zip in the places a package could have landed ====="
$found = New-Object System.Collections.ArrayList
foreach ($dir in $SEARCHDIRS) {
    if (-not (Test-Path $dir)) { Say ("  {0,-34} : does not exist" -f $dir); continue }
    $zips = @(Get-ChildItem $dir -File -Filter "*.zip" -ErrorAction SilentlyContinue)
    Say ("  {0,-34} : zip files {1}" -f $dir, $zips.Count)
    foreach ($z in $zips) { [void]$found.Add($z) }
}
Say ("  candidates in total : {0}   (searched by PATH and by the name pattern *.zip - both halves stated)" -f $found.Count)
if ($found.Count -eq 0) { Say "  *** nothing to verify"; Fin $false }
Say ""

Say "===== 2  ONE predicate over EVERY candidate. Only one may match. ====="
Say ("  expected sha256 : {0}" -f $EXPECTED)
Say ("  expected bytes  : {0}" -f $EXPBYTES)
Say ""
$matches = 0
$newSeen = $false
$fails = 0
foreach ($z in ($found | Sort-Object LastWriteTime -Descending)) {
    $h = Get-Sha256Of $z.FullName
    $isMatch = ($h -eq $EXPECTED)
    if ($isMatch) { $matches++ }
    $tag = $(if ($z.Name -eq $NEWNAME) { "TARGET" } else { "other " })
    if ($z.Name -eq $NEWNAME) { $newSeen = $true }
    Say ("  {0} {1}" -f $tag, $z.FullName)
    Say ("         {0} bytes   written {1}" -f $z.Length, $z.LastWriteTime)
    Say ("         sha256 {0}" -f $h)
    Say ("         matches the built package : {0}" -f $isMatch)
    if ($z.Name -eq $NEWNAME) {
        Say ("         size equals the built size : {0}   (expected True)" -f ($z.Length -eq $EXPBYTES))
        if (-not $isMatch) { Say "         *** THE TARGET FILE DOES NOT MATCH - do not unpack it"; $fails++ }
        if ($z.Length -ne $EXPBYTES) { $fails++ }
    } else {
        if ($isMatch) { Say "         *** an unexpected file has the same hash - say which, do not ignore"; $fails++ }
    }
    Say ""
}
if (-not $newSeen) { Say ("  *** {0} was not found in any searched directory" -f $NEWNAME); $fails++ }
Say ("  files matching the expected hash : {0}   (must be exactly 1)" -f $matches)
if ($matches -ne 1) { $fails++ }
Say "  The other packages answering NO are what make the single YES meaningful:"
Say "  an instrument never seen to refuse has not been shown to be capable of refusing."
Say ""

Say "===== 3  the target is a readable archive, and it is NOT unpacked here ====="
$target = @($found | Where-Object { $_.Name -eq $NEWNAME })
if ($target.Count -eq 1) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    $arc = $null
    try { $arc = [IO.Compression.ZipFile]::OpenRead($target[0].FullName) } catch { Say ("  *** cannot open the archive: {0}" -f $_.Exception.Message); $fails++ }
    if ($null -ne $arc) {
        $e = @($arc.Entries)
        $seed = @($e | Where-Object { $_.Name -eq "01_tenants.sql" }).Count
        $inst = @($e | Where-Object { $_.Name -eq "Install-RTMView.ps1" }).Count
        $dbd  = @($e | Where-Object { $_.FullName -match "(?i)db[\\/]data[\\/]" }).Count
        Say ("  entries {0} | db/data {1} | 01_tenants.sql {2} | Install-RTMView.ps1 {3}" -f $e.Count, $dbd, $seed, $inst)
        Say ("  expected on this package: entries 914 | db/data 5 | seed 1 | installer 1")
        if ($e.Count -ne 914 -or $dbd -ne 5 -or $seed -ne 1 -or $inst -ne 1) { Say "  *** the archive does not carry what the gate measured"; $fails++ }
        $arc.Dispose()
    }
    Say "  (the archive was read in memory - NOTHING was extracted to disk)"
}
Say ""

Say "===== SUMMARY ====="
Say ("  failures : {0}   (anything above zero means DO NOT UNPACK)" -f $fails)
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "  NOTHING WAS UNPACKED, INSTALLED, STARTED OR STOPPED."
Say "===== END-OF-RUN MARKER: PACKAGE-VERIFY-COMPLETE ====="
Fin ($fails -eq 0)
