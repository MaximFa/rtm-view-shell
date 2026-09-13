#Requires -Version 5.1
<#
  BOX LOCAL / clone-23cdbd6   -   WHERE IT RUNS: the LOCAL workstation. No server, no database.
  WHAT IT WRITES : one NEW folder under D:\Claude\Build. It touches nothing else - not the working
                   repo, not any server. The source repository is only READ from.
  WHAT IT DOES NOT DO : it does NOT build. It clones and then GATES the clone, and stops.
                        Building is the next step, after these numbers are seen.

  Why a clone at all: the working repo carries uncommitted changes (a backend edit that was never
  accepted, plus other roles' files). A clone copies COMMITS, never the dirty tree - so the gate
  below can prove the package will be built from accepted code and nothing else.
#>

$ErrorActionPreference = "Continue"
$PIN     = "23cdbd65ddea515db4474b8c9f50630fe396749d"
$SEEDPIN = "75487a4aae89db6ecf532fb3f157c2251e9d5758"
$SRC     = "D:\Claude\Projects\RTM View Shell"
$stamp   = Get-Date -Format yyyyMMdd_HHmmss
$DEST    = "D:\Claude\Build\rtm_clean_$stamp"
$OutDir  = "D:\Claude\Build"
$outf    = Join-Path $OutDir "LOCAL_$($stamp)_clone-gate.txt"
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

Say "===== G1  the instrument checks ITSELF first ====="
$cmd = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ("  Get-Sha256Of resolves to : {0}   (must be Function)" -f $cmd.CommandType)
if ("$($cmd.CommandType)" -ne "Function") { Say "  *** shadowed helper"; Fin $false }
Say ("  NEGCTL hash of a missing path : {0}   (must be ABSENT)" -f (Get-Sha256Of "C:\zzz-no-such-file.bin"))
$git = Get-Command git.exe -ErrorAction SilentlyContinue
if ($null -eq $git) { Say "  *** git.exe NOT FOUND - cannot proceed"; Fin $false }
Say ("  git    : {0}" -f $git.Source)
Say ("  host {0} / PS {1}" -f $env:COMPUTERNAME, $PSVersionTable.PSVersion)
Say ("  source : {0}   exists {1}" -f $SRC, (Test-Path $SRC))
if (-not (Test-Path $SRC)) { Say "  *** source repo not found"; Fin $false }
Say ("  target : {0}   (must not exist yet: {1})" -f $DEST, (-not (Test-Path $DEST)))
if (Test-Path $DEST) { Say "  *** target already exists - refusing to write into it"; Fin $false }
Say "  G1 PASS"
Say ""

Say "===== 1  the source repo names the pin BEFORE we clone ====="
$srcHas = (& $git.Source -C $SRC cat-file -e "$PIN^{commit}" 2>&1)
$srcOk = ($LASTEXITCODE -eq 0)
Say ("  source contains {0} : {1}" -f $PIN.Substring(0,7), $srcOk)
if (-not $srcOk) { Say "  *** the pin is not in the source repo"; Fin $false }
Say ("  its subject : {0}" -f (& $git.Source -C $SRC log -1 --format="%h %ad %s" --date=short $PIN 2>&1))
& $git.Source -C $SRC cat-file -e "deadbee0000000000000000000000000000dead^{commit}" 2>$null
Say ("  NEGCTL an impossible commit resolves : {0}   (must be False)" -f ($LASTEXITCODE -eq 0))
Say ""

Say "===== 2  clone - the ONLY write this box performs ====="
Say ("  git clone --no-hardlinks '{0}' '{1}'" -f $SRC, $DEST)
$cloneOut = (& $git.Source clone --no-hardlinks --quiet "$SRC" "$DEST" 2>&1)
$rc = $LASTEXITCODE
foreach ($cl in $cloneOut) { Say ("      {0}" -f $cl) }
Say ("  clone exit code : {0}" -f $rc)
if ($rc -ne 0) { Say "  *** clone failed"; Fin $false }
$coOut = (& $git.Source -C $DEST checkout --quiet $PIN 2>&1)
$rc2 = $LASTEXITCODE
foreach ($cl in $coOut) { Say ("      {0}" -f $cl) }
Say ("  checkout exit code : {0}" -f $rc2)
if ($rc2 -ne 0) { Say "  *** checkout failed"; Fin $false }
Say ""

Say "===== 3  CLONE GATE - every item states what it expects BEFORE the number ====="
$fails = 0

$head = "$(& $git.Source -C $DEST rev-parse HEAD 2>&1)".Trim()
$g1 = ($head -eq $PIN)
Say ("  [1] HEAD expected {0}" -f $PIN)
Say ("      HEAD actual   {0}   -> {1}" -f $head, $(if ($g1) { "PASS" } else { "FAIL" }))
if (-not $g1) { $fails++ }

$porc = @(& $git.Source -C $DEST status --porcelain 2>&1)
$g2 = ($porc.Count -eq 0)
Say ("  [2] working tree of the CLONE, expected 0 entries : {0} -> {1}" -f $porc.Count, $(if ($g2) { "PASS" } else { "FAIL" }))
foreach ($pl in $porc) { Say ("      {0}" -f $pl) }
if (-not $g2) { $fails++ }

$seedPath = "src/CcDashboard.Application/Commands/Dashboards/SaveQueueGridRtsCommand.cs"
$blobHead = "$(& $git.Source -C $DEST rev-parse "HEAD:$seedPath" 2>&1)".Trim()
$blobDisk = "$(& $git.Source -C $DEST hash-object (Join-Path $DEST ($seedPath -replace '/','\')) 2>&1)".Trim()
$g3 = ($blobHead -eq $blobDisk)
Say ("  [3] the UNACCEPTED backend edit must NOT be in the clone")
Say ("      SaveQueueGridRtsCommand.cs  in HEAD {0}" -f $blobHead)
Say ("      SaveQueueGridRtsCommand.cs  on disk {0}   -> {1}" -f $blobDisk, $(if ($g3) { "PASS (identical, so the dirty edit did not travel)" } else { "FAIL" }))
if (-not $g3) { $fails++ }

$seedFile = Join-Path $DEST "db\data\01_tenants.sql"
$g4 = Test-Path $seedFile
Say ("  [4] db/data/01_tenants.sql present, expected True : {0} -> {1}" -f $g4, $(if ($g4) { "PASS" } else { "FAIL" }))
if (-not $g4) { $fails++ }
if ($g4) {
    $seedText = Get-Content $seedFile -Raw
    $hasSlug = ($seedText -match '(?i)ON\s+CONFLICT\s*\(\s*"Slug"\s*\)')
    $hasId   = ($seedText -match '(?i)ON\s+CONFLICT\s*\(\s*"Id"\s*\)')
    $hasCanon= ($seedText -match "019e03e9")
    $hasTrunc= ($seedText -match "(?i)TRUNCATE")
    $hasRand = ($seedText -match "01a07e07")
    Say ("      conflict target Slug, expected True  : {0} -> {1}" -f $hasSlug, $(if ($hasSlug) { "PASS" } else { "FAIL" }))
    Say ("      conflict target Id,   expected False : {0} -> {1}" -f $hasId,   $(if (-not $hasId) { "PASS" } else { "FAIL" }))
    Say ("      canonical Id 019e03e9, expected True : {0} -> {1}" -f $hasCanon,$(if ($hasCanon) { "PASS" } else { "FAIL" }))
    Say ("      TRUNCATE, expected False             : {0} -> {1}" -f $hasTrunc,$(if (-not $hasTrunc) { "PASS" } else { "FAIL" }))
    Say ("      random Id 01a07e07, expected False   : {0} -> {1}" -f $hasRand, $(if (-not $hasRand) { "PASS" } else { "FAIL" }))
    if (-not $hasSlug) { $fails++ }
    if ($hasId)   { $fails++ }
    if (-not $hasCanon) { $fails++ }
    if ($hasTrunc) { $fails++ }
    if ($hasRand)  { $fails++ }
    Say ("      NEGCTL a phrase that must not be there : {0}   (must be False)" -f ($seedText -match "ZzzNoSuchPhrase"))
}

$builder = Join-Path $DEST "tools\Build-ProdRelease.ps1"
$g5 = Test-Path $builder
Say ("  [5] tools/Build-ProdRelease.ps1 present, expected True : {0} -> {1}" -f $g5, $(if ($g5) { "PASS" } else { "FAIL" }))
if (-not $g5) { $fails++ }
$dbTools = Join-Path $DEST "db\tools"
Say ("      db\tools present (the drift gate lives there) : {0}" -f (Test-Path $dbTools))

$g6 = Test-Path (Join-Path $DEST "zzz-no-such-file-in-any-clone.txt")
Say ("  [6] NEGCTL a file that cannot exist, expected False : {0} -> {1}" -f $g6, $(if (-not $g6) { "PASS" } else { "FAIL - the checker is blind" }))
if ($g6) { $fails++ }
Say ""

Say "===== SUMMARY ====="
Say ("  clone   : {0}" -f $DEST)
Say ("  HEAD    : {0}" -f $head)
Say ("  failures: {0}   (anything above zero means DO NOT BUILD from this clone)" -f $fails)
Say ("  collector still intact : {0}   (must be ArrayList)" -f $ProbeLines.GetType().Name)
Say "  NOTHING WAS BUILT. NOTHING WAS SENT ANYWHERE. NO SERVER WAS TOUCHED."
Say "===== END-OF-RUN MARKER: CLONE-GATE-COMPLETE ====="
Fin ($fails -eq 0)
