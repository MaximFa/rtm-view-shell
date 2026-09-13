#Requires -Version 5.1
<#
  BOX LOCAL / build-and-origin-gate
  WHERE IT RUNS : the LOCAL workstation. No server is touched, no database, no network deploy.
  WHAT IT WRITES : a package .zip inside the ALREADY-GATED clone, plus report files under
                   D:\Claude\Build. The working repository is not touched at all.
  WHAT IT DOES   : builds the Full package in the clone, then makes the package PROVE what is
                   inside it, then writes its sha256 to a file so the number that travels to the
                   server comes from a measurement and not from memory.

  SECOND RUN. The first attempt died in pre-flight: Garnet binaries not found in the clone.
  Root cause measured, not guessed: .gitignore line 74 ignores tools/cache/, so those binaries
  live only in the working tree and a fresh clone never has them. The builder accepts -GarnetDir
  and -NssmDir and honours ABSOLUTE paths (it only prefixes $Root when the path is relative), so
  this run points them at the working tree's cache. Nothing is written there - it is read from.
  The code still comes from the clone; only the third-party binaries come from the cache, exactly
  as in every package built so far.

  The clone was gated separately and passed: HEAD 23cdbd6, tree clean, the unaccepted backend
  edit absent, the seed file carrying exactly one ON CONFLICT clause targeting Slug.
  Nothing here re-clones. If the build fails, the gate section does not run.
#>

$ErrorActionPreference = "Continue"
$CLONE  = "D:\Claude\Build\rtm_clean_20260908_101212"
$PIN    = "23cdbd65ddea515db4474b8c9f50630fe396749d"
$OutDir = "D:\Claude\Build"
$stamp  = Get-Date -Format yyyyMMdd_HHmmss
$outf   = Join-Path $OutDir "LOCAL_$($stamp)_build-origin-gate.txt"
$buildLog = Join-Path $OutDir "LOCAL_$($stamp)_build-console.txt"
$ProbeLines = New-Object System.Collections.ArrayList
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$ProbeLines.Add("")
    [void]$ProbeLines.Add($(if ($pass) { "VERDICT: PASS" } else { "VERDICT: FAIL" }))
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT     : {0}" -f $outf)
    Write-Host ("BUILD LOG  : {0}" -f $buildLog)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($path) { if (Test-Path $path) { (Get-FileHash $path -Algorithm SHA256).Hash } else { "ABSENT" } }
function Get-CodeText($path) {
    $lines = @(Get-Content $path)
    $code  = @($lines | Where-Object { $_.TrimStart() -notmatch "^--" })
    return ($code -join "`n")
}

Say "===== G1  the instrument checks ITSELF first ====="
$cmd = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ("  Get-Sha256Of resolves to : {0}   (must be Function)" -f $cmd.CommandType)
if ("$($cmd.CommandType)" -ne "Function") { Say "  *** shadowed helper"; Fin $false }
Say ("  NEGCTL hash of a missing path : {0}   (must be ABSENT)" -f (Get-Sha256Of "C:\zzz-no-such-file.bin"))
$git = Get-Command git.exe -ErrorAction SilentlyContinue
if ($null -eq $git) { Say "  *** git.exe NOT FOUND"; Fin $false }
$dotnet = Get-Command dotnet.exe -ErrorAction SilentlyContinue
Say ("  dotnet : {0}" -f $(if ($null -eq $dotnet) { "NOT FOUND - the build cannot run" } else { $dotnet.Source }))
if ($null -eq $dotnet) { Fin $false }
Say ("  host {0} / PS {1}" -f $env:COMPUTERNAME, $PSVersionTable.PSVersion)
$WORKTREE  = "D:\Claude\Projects\RTM View Shell"
$GARNETDIR = Join-Path $WORKTREE "tools\cache\garnet-1.1.10-win-x64-net8"
$NSSMDIR   = Join-Path $WORKTREE "tools\cache\nssm"
$garnetExe = Join-Path $GARNETDIR "GarnetServer.exe"
$nssmExe   = Join-Path $NSSMDIR "nssm.exe"
Say ("  GarnetServer.exe present : {0}   {1}" -f (Test-Path $garnetExe), $garnetExe)
Say ("  nssm.exe present         : {0}   {1}" -f (Test-Path $nssmExe), $nssmExe)
Say ("  NEGCTL an exe that cannot be there : {0}   (must be False)" -f (Test-Path (Join-Path $GARNETDIR "ZzzNoSuch.exe")))
if (-not (Test-Path $garnetExe)) { Say "  *** Garnet binaries missing in the working tree too - stop"; Fin $false }
if (-not (Test-Path $nssmExe))   { Say "  *** nssm missing in the working tree too - stop"; Fin $false }
$freeGb = (Get-PSDrive D).Free / 1GB
Say ("  free space on D: {0:N1} GB   (measured now, not yesterday)" -f $freeGb)
if ($freeGb -lt 5) { Say "  *** less than 5 GB free - refusing to build"; Fin $false }
Say "  G1 PASS"
Say ""

Say "===== G2  the clone is still the gated one ====="
Say ("  clone : {0}   exists {1}" -f $CLONE, (Test-Path $CLONE))
if (-not (Test-Path $CLONE)) { Say "  *** the gated clone is gone"; Fin $false }
$head = "$(& $git.Source -C $CLONE rev-parse HEAD 2>&1)".Trim()
Say ("  HEAD expected {0}" -f $PIN)
Say ("  HEAD actual   {0}" -f $head)
if ($head -ne $PIN) { Say "  *** the clone moved since it was gated"; Fin $false }
$dirty = @(& $git.Source -C $CLONE status --porcelain 2>&1)
Say ("  working tree entries, expected 0 : {0}" -f $dirty.Count)
foreach ($dl in $dirty) { Say ("      {0}" -f $dl) }
if ($dirty.Count -ne 0) { Say "  *** the clone is no longer clean"; Fin $false }
$zipsBefore = @(Get-ChildItem (Join-Path $CLONE "Installations") -File -Filter "*.zip" -ErrorAction SilentlyContinue)
Say ("  packages already in the clone before the build : {0}" -f $zipsBefore.Count)
Say "  G2 PASS"
Say ""

Say "===== 1  BUILD  (this is the long step; console goes to the build log) ====="
Say ("  command : .\tools\Build-ProdRelease.ps1 -Mode Full -SkipDB -GarnetDir <worktree cache> -NssmDir <worktree cache>   in {0}" -f $CLONE)
Say "  -SkipDB skips only the pg_dump DB/ folder. The db/ module (schema, functions, data, tools)"
Say "  is copied by an unconditional block, so db/data/01_tenants.sql ships regardless - and that"
Say "  is verified below on the package itself, not assumed from reading the builder."
$t0 = Get-Date
Push-Location $CLONE
$buildOut = & powershell.exe -ExecutionPolicy Bypass -NoProfile -File (Join-Path $CLONE "tools\Build-ProdRelease.ps1") -Mode Full -SkipDB -GarnetDir $GARNETDIR -NssmDir $NSSMDIR 2>&1
$buildRc = $LASTEXITCODE
Pop-Location
$elapsed = ((Get-Date) - $t0).TotalSeconds
[IO.File]::WriteAllLines($buildLog, @($buildOut | ForEach-Object { "$_" }), (New-Object System.Text.UTF8Encoding($false)))
Say ("  build exit code : {0}   elapsed {1:N0} s   console lines {2}" -f $buildRc, $elapsed, @($buildOut).Count)
if ($buildRc -ne 0) {
    Say "  *** BUILD FAILED - last 30 console lines:"
    foreach ($bl in (@($buildOut) | Select-Object -Last 30)) { Say ("      {0}" -f $bl) }
    Fin $false
}
Say "  --- last 12 console lines ---"
foreach ($bl in (@($buildOut) | Select-Object -Last 12)) { Say ("      {0}" -f $bl) }
Say ""

$fails = 0

Say "===== 2  which file did the build actually produce ====="
$zipsAfter = @(Get-ChildItem (Join-Path $CLONE "Installations") -File -Filter "*.zip" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
Say ("  packages in the clone after the build : {0}   (was {1})" -f $zipsAfter.Count, $zipsBefore.Count)
if ($zipsAfter.Count -eq 0) { Say "  *** no package produced"; Fin $false }
$zip = $zipsAfter[0]
Say ("  newest : {0}" -f $zip.FullName)
Say ("           {0:N1} MB   written {1}" -f ($zip.Length/1MB), $zip.LastWriteTime)
$zipHash = Get-Sha256Of $zip.FullName
Say ("  sha256 : {0}" -f $zipHash)
$ageSec = ((Get-Date) - $zip.LastWriteTime).TotalSeconds
Say ("  age    : {0:N0} s   (must be small - an old file here would mean the build wrote elsewhere)" -f $ageSec)
if ($ageSec -gt 900) { Say "  *** this package predates this run"; $fails++ }
Say ""

Say "===== 3  ORIGIN GATE - the package proves its own contents ====="
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
$archive = $null
try { $archive = [IO.Compression.ZipFile]::OpenRead($zip.FullName) } catch { Say ("  *** cannot open the package: {0}" -f $_.Exception.Message); Fin $false }
$entries = @($archive.Entries)
Say ("  entries in the package : {0}" -f $entries.Count)

$installers = @($entries | Where-Object { $_.Name -eq "Install-RTMView.ps1" })
Say ("  Install-RTMView.ps1 copies, expected exactly 1 : {0}" -f $installers.Count)
foreach ($ie in $installers) { Say ("      {0}" -f $ie.FullName) }
if ($installers.Count -ne 1) { Say "      -> FAIL"; $fails++ }
else {
    $reader = New-Object IO.StreamReader($installers[0].Open())
    $instTxt = $reader.ReadToEnd(); $reader.Close()
    $marks = @(
        @("preserve block for Shell configs", $instTxt.Contains('$preserveShell'), $true),
        @("Preserved: log line",              $instTxt.Contains('Preserved:'),     $true),
        @("data.sys branch",                  $instTxt.Contains('data.sys'),       $true),
        @('DB port injection Port=$DBPort',   $instTxt.Contains('Port=$DBPort'),   $true),
        @("-FreshDb supported",               ($instTxt.Contains('-FreshDb') -or $instTxt.Contains('$FreshDb')), $true)
    )
    foreach ($mk in $marks) {
        $ok = ($mk[1] -eq $mk[2])
        Say ("  installer carries '{0}' : expected {1} , actual {2} -> {3}" -f $mk[0], $mk[2], $mk[1], $(if ($ok) { "PASS" } else { "FAIL" }))
        if (-not $ok) { $fails++ }
    }
    $m6 = ([regex]::Matches($instTxt, [regex]::Escape('(package version ignored)'))).Count
    Say ("  d01851a wording occurrences, expected 2 : {0} -> {1}" -f $m6, $(if ($m6 -eq 2) { "PASS" } else { "FAIL" }))
    if ($m6 -ne 2) { $fails++ }
    $instHashZip  = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($instTxt))).Replace("-","")
    $instRepoPath = Join-Path $CLONE "deploy\Install-RTMView.ps1"
    Say ("  NEGCTL a phrase that cannot be in the installer : {0}   (must be False)" -f $instTxt.Contains("ZzzNoSuchPhrase"))
    Say ("  installer also present in the clone at deploy\ : {0}" -f (Test-Path $instRepoPath))
}

$dbDataEntries = @($entries | Where-Object { $_.FullName -match "(?i)db[\\/]data[\\/]" })
Say ("  entries under db/data, POSITIVE control, expected greater than 0 : {0}" -f $dbDataEntries.Count)
foreach ($de in $dbDataEntries) { Say ("      {0}" -f $de.FullName) }
if ($dbDataEntries.Count -eq 0) { Say "      -> FAIL (either the module did not ship, or this search is blind)"; $fails++ }

$seedEntry = @($entries | Where-Object { $_.Name -eq "01_tenants.sql" })
Say ("  01_tenants.sql copies, expected exactly 1 : {0}" -f $seedEntry.Count)
if ($seedEntry.Count -ne 1) { Say "      -> FAIL"; $fails++ }
else {
    $tmpSeed = Join-Path $env:TEMP ("seed_{0}.sql" -f $stamp)
    [IO.Compression.ZipFileExtensions]::ExtractToFile($seedEntry[0], $tmpSeed, $true)
    $code = Get-CodeText $tmpSeed
    $conflicts = @([regex]::Matches($code, '(?i)ON\s+CONFLICT\s*\(\s*"([A-Za-z]+)"\s*\)'))
    Say ("  ON CONFLICT clauses in CODE, expected exactly 1 : {0}" -f $conflicts.Count)
    if ($conflicts.Count -ne 1) { $fails++ }
    else {
        $target = $conflicts[0].Groups[1].Value
        Say ("      target '{0}', expected 'Slug' -> {1}" -f $target, $(if ($target -eq "Slug") { "PASS" } else { "FAIL" }))
        if ($target -ne "Slug") { $fails++ }
    }
    Say ("  code carries canonical Id 019e03e9, expected True : {0}" -f ($code -match "019e03e9"))
    if (-not ($code -match "019e03e9")) { $fails++ }
    Say ("  code carries TRUNCATE, expected False : {0}" -f ($code -match "(?i)TRUNCATE"))
    if ($code -match "(?i)TRUNCATE") { $fails++ }
    Remove-Item $tmpSeed -ErrorAction SilentlyContinue
}

$provision = @($entries | Where-Object { $_.Name -eq "Provision-FreshDb.ps1" })
$compare   = @($entries | Where-Object { $_.Name -eq "Compare-ToBaseline.ps1" })
Say ("  db/tools/Provision-FreshDb.ps1 in package : {0}" -f ($provision.Count -gt 0))
Say ("  db/tools/Compare-ToBaseline.ps1 in package : {0}   (0 makes the drift gate WARN-skip on the server)" -f ($compare.Count -gt 0))
$garnetInZip = @($entries | Where-Object { $_.Name -eq "GarnetServer.exe" })
$nssmInZip   = @($entries | Where-Object { $_.Name -eq "nssm.exe" })
Say ("  GarnetServer.exe in package, expected present : {0}" -f ($garnetInZip.Count -gt 0))
Say ("  nssm.exe in package, expected present         : {0}" -f ($nssmInZip.Count -gt 0))
if ($garnetInZip.Count -eq 0) { $fails++ }
if ($nssmInZip.Count -eq 0)   { $fails++ }
$archive.Dispose()
Say ""

Say "===== 4  NEGATIVE CONTROL - the same predicates must say NO about an older package ====="
$oldCands = @(Get-ChildItem "D:\Claude\Build" -Recurse -File -Filter "*.zip" -ErrorAction SilentlyContinue |
              Where-Object { $_.FullName -ne $zip.FullName } | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
if ($oldCands.Count -eq 0) { Say "  no older package found under D:\Claude\Build - the negative control is a GAP, not a pass"; $fails++ }
else {
    $old = $oldCands[0]
    Say ("  older package : {0}" -f $old.FullName)
    Say ("                  {0:N1} MB   written {1}" -f ($old.Length/1MB), $old.LastWriteTime)
    $oldArc = $null
    try { $oldArc = [IO.Compression.ZipFile]::OpenRead($old.FullName) } catch { Say ("  *** cannot open: {0}" -f $_.Exception.Message) }
    if ($null -ne $oldArc) {
        $oldEntries = @($oldArc.Entries)
        $oldSeed = @($oldEntries | Where-Object { $_.Name -eq "01_tenants.sql" })
        $oldData = @($oldEntries | Where-Object { $_.FullName -match "(?i)db[\\/]data[\\/]" })
        Say ("  its entries under db/data, POSITIVE control, expected greater than 0 : {0}" -f $oldData.Count)
        Say ("  its 01_tenants.sql, expected 0 : {0} -> {1}" -f $oldSeed.Count, $(if ($oldSeed.Count -eq 0) { "PASS - the zero is real, the neighbour was found" } else { "note: this older package already carries the seed" }))
        if ($oldData.Count -eq 0) { Say "      *** the neighbour was not found either - this zero proves nothing"; $fails++ }
        $oldArc.Dispose()
    }
}
Say ""

Say "===== 5  the number that travels to the server, written to a file ====="
$hashFile = Join-Path $OutDir ("PACKAGE_SHA256_{0}.txt" -f $stamp)
$hashBody = @(
    ("package : " + $zip.FullName),
    ("bytes   : " + $zip.Length),
    ("sha256  : " + $zipHash),
    ("built   : " + $zip.LastWriteTime),
    ("clone   : " + $CLONE),
    ("HEAD    : " + $head)
)
[IO.File]::WriteAllLines($hashFile, $hashBody, (New-Object System.Text.UTF8Encoding($false)))
$reread = Get-Sha256Of $zip.FullName
Say ("  sha256 written to : {0}" -f $hashFile)
Say ("  re-read of the package hash : {0}" -f $reread)
Say ("  matches the first reading   : {0}   (must be True)" -f ($reread -eq $zipHash))
if ($reread -ne $zipHash) { $fails++ }
Say ""

Say "===== SUMMARY ====="
Say ("  package  : {0}" -f $zip.FullName)
Say ("  sha256   : {0}" -f $zipHash)
Say ("  HEAD     : {0}" -f $head)
Say ("  failures : {0}   (anything above zero means DO NOT SEND this package anywhere)" -f $fails)
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "  NOTHING WAS SENT TO ANY SERVER. NO DATABASE WAS TOUCHED."
Say "===== END-OF-RUN MARKER: BUILD-ORIGIN-GATE-COMPLETE ====="
Fin ($fails -eq 0)
