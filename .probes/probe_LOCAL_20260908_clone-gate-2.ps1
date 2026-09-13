#Requires -Version 5.1
<#
  BOX LOCAL / clone-gate-2   -   WHERE IT RUNS: the LOCAL workstation. No server, no database.
  READ ONLY. It creates NO clone: it gates the clone that already exists.

  WHY A SECOND RUN : the first gate returned FAIL on one item, and the FAIL was mine.
  It asked "does the file contain ON CONFLICT ("Id")" over the WHOLE file - and the file
  carries a comment block explaining why the target must NOT be Id ("Do not fix this back to
  (Id)"). So the predicate matched the explanation of the rule and reported a violation of it.
  A predicate that cannot tell a statement from a comment about the statement is not a check.
  This run strips comment lines first, then asks the same questions of the CODE only, and also
  counts the conflict clauses - because "the right one is present" is weaker than "there is
  exactly one, and it is the right one".
#>

$ErrorActionPreference = "Continue"
$PIN     = "23cdbd65ddea515db4474b8c9f50630fe396749d"
$SEEDPIN = "75487a4aae89db6ecf532fb3f157c2251e9d5758"
$CLONE   = "D:\Claude\Build\rtm_clean_20260908_101212"
$OutDir  = "D:\Claude\Build"
$stamp   = Get-Date -Format yyyyMMdd_HHmmss
$outf    = Join-Path $OutDir "LOCAL_$($stamp)_clone-gate-2.txt"
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
if ($null -eq $git) { Say "  *** git.exe NOT FOUND"; Fin $false }
Say ("  git  : {0}" -f $git.Source)
Say ("  host {0} / PS {1}" -f $env:COMPUTERNAME, $PSVersionTable.PSVersion)
Say ("  clone under test : {0}   exists {1}" -f $CLONE, (Test-Path $CLONE))
if (-not (Test-Path $CLONE)) { Say "  *** that clone is gone - re-run the cloning box instead"; Fin $false }
Say "  G1 PASS"
Say ""

Say "===== G2  the comment-stripper is proven on a KNOWN case before it is trusted ====="
$sample = @("-- ON CONFLICT (`"Id`") must not be used", "INSERT INTO t VALUES (1)", "ON CONFLICT (`"Slug`") DO NOTHING;")
$stripped = @($sample | Where-Object { $_.TrimStart() -notmatch "^--" })
Say ("  sample lines in : {0} , after stripping comments : {1}   (expected 3 -> 2)" -f $sample.Count, $stripped.Count)
$posCheck = (($stripped -join "`n") -match 'ON\s+CONFLICT\s*\(\s*"Slug"\s*\)')
$negCheck = (($stripped -join "`n") -match 'ON\s+CONFLICT\s*\(\s*"Id"\s*\)')
Say ("  on the sample: Slug found {0} (expected True) , Id found {1} (expected False)" -f $posCheck, $negCheck)
if (($stripped.Count -ne 2) -or (-not $posCheck) -or $negCheck) { Say "  *** the stripper does not do what it claims - refusing to judge the real file"; Fin $false }
Say "  G2 PASS - the stripper removes comments and the predicates survive"
Say ""

$fails = 0

Say "===== 1  the clone still is what it was ====="
$head = "$(& $git.Source -C $CLONE rev-parse HEAD 2>&1)".Trim()
$g1 = ($head -eq $PIN)
Say ("  HEAD expected {0}" -f $PIN)
Say ("  HEAD actual   {0}   -> {1}" -f $head, $(if ($g1) { "PASS" } else { "FAIL" }))
if (-not $g1) { $fails++ }
$porc = @(& $git.Source -C $CLONE status --porcelain 2>&1)
$g2 = ($porc.Count -eq 0)
Say ("  working tree entries, expected 0 : {0} -> {1}" -f $porc.Count, $(if ($g2) { "PASS" } else { "FAIL" }))
foreach ($pl in $porc) { Say ("      {0}" -f $pl) }
if (-not $g2) { $fails++ }
$seedPath = "src/CcDashboard.Application/Commands/Dashboards/SaveQueueGridRtsCommand.cs"
$blobDisk = "$(& $git.Source -C $CLONE hash-object (Join-Path $CLONE ($seedPath -replace '/','\')) 2>&1)".Trim()
$g3 = ($blobDisk -eq $SEEDPIN)
Say ("  SaveQueueGridRtsCommand.cs expected {0}" -f $SEEDPIN)
Say ("  SaveQueueGridRtsCommand.cs actual   {0}   -> {1}" -f $blobDisk, $(if ($g3) { "PASS (the unaccepted edit did not travel)" } else { "FAIL" }))
if (-not $g3) { $fails++ }
Say ""

Say "===== 2  the seed file, judged on CODE ONLY - comments stripped first ====="
$seedFile = Join-Path $CLONE "db\data\01_tenants.sql"
if (-not (Test-Path $seedFile)) { Say "  db/data/01_tenants.sql ABSENT -> FAIL"; $fails++ }
else {
    $allLines  = @(Get-Content $seedFile)
    $codeLines = @($allLines | Where-Object { $_.TrimStart() -notmatch "^--" })
    $code = ($codeLines -join "`n")
    Say ("  lines total {0} , comment lines {1} , code lines {2}" -f $allLines.Count, ($allLines.Count - $codeLines.Count), $codeLines.Count)
    Say ("  POSCTL comment lines found, expected greater than 0 : {0}" -f ($allLines.Count - $codeLines.Count))
    if (($allLines.Count - $codeLines.Count) -le 0) { Say "  *** no comments found in a file that certainly has them - stripper blind"; $fails++ }

    $conflicts = @([regex]::Matches($code, '(?i)ON\s+CONFLICT\s*\(\s*"([A-Za-z]+)"\s*\)'))
    Say ("  ON CONFLICT clauses in CODE, expected exactly 1 : {0}" -f $conflicts.Count)
    if ($conflicts.Count -ne 1) { Say "      -> FAIL"; $fails++ }
    else {
        $target = $conflicts[0].Groups[1].Value
        Say ("      its target is '{0}', expected 'Slug' -> {1}" -f $target, $(if ($target -eq "Slug") { "PASS" } else { "FAIL" }))
        if ($target -ne "Slug") { $fails++ }
    }
    $inCode = @{
        "canonical Id 019e03e9" = @($true,  ($code -match "019e03e9"))
        "DO NOTHING"            = @($true,  ($code -match "(?i)DO\s+NOTHING"))
        "TRUNCATE"              = @($false, ($code -match "(?i)TRUNCATE"))
        "DELETE"                = @($false, ($code -match "(?i)\bDELETE\b"))
        "random Id 01a07e07"    = @($false, ($code -match "01a07e07"))
        "DO UPDATE"             = @($false, ($code -match "(?i)DO\s+UPDATE"))
    }
    foreach ($key in $inCode.Keys) {
        $expected = $inCode[$key][0]; $actual = $inCode[$key][1]
        $ok = ($expected -eq $actual)
        Say ("  code contains '{0}' : expected {1} , actual {2} -> {3}" -f $key, $expected, $actual, $(if ($ok) { "PASS" } else { "FAIL" }))
        if (-not $ok) { $fails++ }
    }
    Say ("  NEGCTL a phrase that cannot be there : {0}   (must be False)" -f ($code -match "ZzzNoSuchPhrase"))
    Say "  --- the code lines themselves, so the numbers above can be checked by eye ---"
    foreach ($cl in $codeLines) { if ($cl.Trim().Length -gt 0) { Say ("      {0}" -f $cl) } }
}
Say ""

Say "===== 3  the builder and the drift gate are in the clone ====="
$builder = Join-Path $CLONE "tools\Build-ProdRelease.ps1"
$g5 = Test-Path $builder
Say ("  tools/Build-ProdRelease.ps1, expected True : {0} -> {1}" -f $g5, $(if ($g5) { "PASS" } else { "FAIL" }))
if (-not $g5) { $fails++ }
$dbToolsCount = @(Get-ChildItem (Join-Path $CLONE "db\tools") -File -ErrorAction SilentlyContinue).Count
Say ("  db\tools files : {0}   (Compare-ToBaseline lives here; 0 means the drift gate would WARN-skip)" -f $dbToolsCount)
Say ("  Compare-ToBaseline.ps1 present : {0}" -f (Test-Path (Join-Path $CLONE "db\tools\Compare-ToBaseline.ps1")))
Say ("  NEGCTL a file that cannot exist : {0}   (must be False)" -f (Test-Path (Join-Path $CLONE "zzz-no-such-file.txt")))
Say ""

Say "===== SUMMARY ====="
Say ("  clone    : {0}" -f $CLONE)
Say ("  HEAD     : {0}" -f $head)
Say ("  failures : {0}   (anything above zero means DO NOT BUILD from this clone)" -f $fails)
Say ("  collector still intact : {0}   (must be ArrayList)" -f $ProbeLines.GetType().Name)
Say "  NOTHING WAS BUILT, CLONED, SENT OR CHANGED."
Say "===== END-OF-RUN MARKER: CLONE-GATE-2-COMPLETE ====="
Fin ($fails -eq 0)
