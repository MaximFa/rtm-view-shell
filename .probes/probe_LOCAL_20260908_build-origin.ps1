#Requires -Version 5.1
<#
  PROBE LOCAL / build-origin   -   READ ONLY. Reads the build clone and the packages. Changes nothing.
  WHERE IT RUNS : the LOCAL workstation (not 234, not 140). No database is touched.
  QUESTION      : from WHICH commit was 08092026.0859_Full.zip built, and does that package really
                  carry db/data/01_tenants.sql with the Slug conflict target.
  Git commands used are READ ONLY (rev-parse, log, describe). The index is not touched.
#>

$ErrorActionPreference = "Continue"
$OutDir = "D:\Claude\Build"
if (-not (Test-Path $OutDir)) { $OutDir = $env:TEMP }
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "LOCAL_$($stamp)_build-origin.txt"
$ProbeLines = New-Object System.Collections.ArrayList
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($path) { if (Test-Path $path) { (Get-FileHash $path -Algorithm SHA256).Hash } else { "ABSENT" } }

Say "===== G1  the instrument checks ITSELF first ====="
$cmd = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ("  Get-Sha256Of resolves to : {0}   (must be Function)" -f $cmd.CommandType)
if ("$($cmd.CommandType)" -ne "Function") { Say "  *** shadowed helper"; Fin $false }
Say ("  POSCTL hash of this file : {0}" -f (Get-Sha256Of $MyInvocation.MyCommand.Path))
Say ("  NEGCTL hash of a missing path : {0}   (must be ABSENT)" -f (Get-Sha256Of "C:\zzz-no-such-file.bin"))
$git = (Get-Command git.exe -ErrorAction SilentlyContinue)
Say ("  git.exe : {0}" -f $(if ($null -eq $git) { "NOT FOUND - the clone section will be a GAP, not a pass" } else { $git.Source }))
Say ("  host {0} / user {1} / PS {2}" -f $env:COMPUTERNAME, $env:USERNAME, $PSVersionTable.PSVersion)
Say "  G1 PASS"
Say ""

Say "===== 1  where the build clones are - searched, not assumed ====="
$searchRoots = @("D:\Claude\Build","D:\Claude\Projects","D:\RTMView-Ops","C:\Temp")
$clones = New-Object System.Collections.ArrayList
foreach ($root in $searchRoots) {
    if (-not (Test-Path $root)) { Say ("  {0,-26} : does not exist" -f $root); continue }
    $gitDirs = @(Get-ChildItem $root -Depth 3 -Directory -Force -Filter ".git" -ErrorAction SilentlyContinue)
    Say ("  {0,-26} : .git directories found {1}" -f $root, $gitDirs.Count)
    foreach ($gd in $gitDirs) { [void]$clones.Add($gd.Parent.FullName) }
}
Say ("  clones total : {0}" -f $clones.Count)
Say ""

Say "===== 2  each clone names its own HEAD - read only ====="
if ($null -eq $git) { Say "  git.exe not found - SKIPPED, and that is a GAP" }
else {
    foreach ($clone in $clones) {
        Say ("  --- {0} ---" -f $clone)
        $head   = (& $git.Source -C $clone rev-parse HEAD 2>&1)
        $branch = (& $git.Source -C $clone rev-parse --abbrev-ref HEAD 2>&1)
        $subj   = (& $git.Source -C $clone log -1 --format="%h %ad %s" --date=short 2>&1)
        Say ("      branch : {0}" -f $branch)
        Say ("      HEAD   : {0}" -f $head)
        Say ("      tip    : {0}" -f $subj)
        foreach ($pin in @("4ff48488bae3bf5be7a76e19968d109e13e747dc","8cfc9af79fad81c2cef8e1c85332601f3f94b9db")) {
            & $git.Source -C $clone merge-base --is-ancestor $pin HEAD 2>$null
            $isAnc = ($LASTEXITCODE -eq 0)
            Say ("      contains {0} : {1}" -f $pin.Substring(0,7), $isAnc)
        }
        $has = (& $git.Source -C $clone cat-file -e "HEAD:db/data/01_tenants.sql" 2>&1)
        Say ("      HEAD carries db/data/01_tenants.sql : {0}" -f ($LASTEXITCODE -eq 0))
    }
}
Say ""

Say "===== 3  the packages themselves ====="
$pkgRoot = "D:\Claude\Build"
if (-not (Test-Path $pkgRoot)) { Say ("  {0} : does not exist - cannot inspect packages" -f $pkgRoot) }
else {
    $zips = @(Get-ChildItem $pkgRoot -Recurse -File -Filter "*_Full.zip" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 4)
    Say ("  *_Full.zip found : {0}" -f $zips.Count)
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    foreach ($zip in $zips) {
        Say ("  --- {0} ---" -f $zip.FullName)
        Say ("      {0} bytes   modified {1}" -f $zip.Length, $zip.LastWriteTime)
        Say ("      sha256 {0}" -f (Get-Sha256Of $zip.FullName))
        $archive = $null
        try { $archive = [IO.Compression.ZipFile]::OpenRead($zip.FullName) } catch { Say ("      *** cannot open: {0}" -f $_.Exception.Message) }
        if ($null -ne $archive) {
            Say ("      entries total : {0}" -f $archive.Entries.Count)
            $seed = @($archive.Entries | Where-Object { $_.FullName -like "*01_tenants.sql" })
            $neighbour = @($archive.Entries | Where-Object { $_.FullName -like "*db/data/*" -or $_.FullName -like "*db\data\*" })
            Say ("      entries under db/data : {0}   (POSITIVE control - 0 here means the search is blind)" -f $neighbour.Count)
            Say ("      01_tenants.sql present : {0}" -f ($seed.Count -gt 0))
            if ($seed.Count -gt 0) {
                $reader = New-Object IO.StreamReader($seed[0].Open())
                $text = $reader.ReadToEnd(); $reader.Close()
                Say ("      01_tenants.sql size : {0} chars" -f $text.Length)
                Say ("      conflict target Slug present : {0}" -f ($text -match '(?i)ON\s+CONFLICT\s*\(\s*"Slug"\s*\)'))
                Say ("      conflict target Id present   : {0}   (must be False)" -f ($text -match '(?i)ON\s+CONFLICT\s*\(\s*"Id"\s*\)'))
                Say ("      contains the canonical Id 019e03e9 : {0}" -f ($text -match "019e03e9"))
                Say ("      contains TRUNCATE : {0}   (must be False)" -f ($text -match "(?i)TRUNCATE"))
            }
            $archive.Dispose()
        }
    }
}
Say ""

Say "===== SUMMARY ====="
Say ("  collector still intact : {0}   (must be ArrayList)" -f $ProbeLines.GetType().Name)
Say "  Everything above is a reading. NOTHING WAS BUILT, MOVED OR CHANGED."
Say "===== END-OF-RUN MARKER: BUILD-ORIGIN-COMPLETE ====="
Fin $true
