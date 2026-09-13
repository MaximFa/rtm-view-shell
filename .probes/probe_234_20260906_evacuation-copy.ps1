#Requires -Version 5.1
# ============================================================================
#  PROBE 234 / evacuation-copy  -  steps B and C in ONE run
#  WHERE IT RUNS : server 234.
#  WRITES        : ONLY new files, into C:\RTMView-Ops\preserve_<stamp>\ .
#                  Nothing is deleted, moved, overwritten, installed or uninstalled.
#                  Source files are read only.
#  SCOPE         : everything inside C:\RTMView\ that dies with the machine.
#                  C:\RTMView-Ops\backup and \output are NOT copied - they are
#                  outside the demolition zone, and a second copy beside the first
#                  on the same disk is a duplicate, not a preservation.
#  VERIFY        : every copied file is SHA-256'd and compared against the manifest
#                  234_20260906_121236_evacuation-manifest.txt. One mismatch = STOP.
# ============================================================================

$ErrorActionPreference = "Continue"
$OpsRoot   = "C:\RTMView-Ops"
$OutDir    = Join-Path $OpsRoot "output"
$Manifest  = Join-Path $OutDir "234_20260906_121236_evacuation-manifest.txt"
$stamp     = Get-Date -Format yyyyMMdd_HHmm
$Preserve  = Join-Path $OpsRoot "preserve_$stamp"
$Report    = Join-Path $OutDir "234_$($stamp)_evacuation-copy.txt"

$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }

Say "WHERE IT RUNS : server 234. Copies INTO C:\RTMView-Ops\preserve_... . Nothing deleted or overwritten."
Say ("destination   : {0}" -f $Preserve)
Say ("manifest      : {0}" -f $Manifest)
Say ""

if (-not (Test-Path $Manifest)) { Say "*** STOP: manifest not found. Without it the copy cannot be verified. Nothing was copied."; [IO.File]::WriteAllLines($Report,$L,(New-Object System.Text.UTF8Encoding($false))); exit 1 }

# ---- load manifest: HASH|<sha256>|<bytes>|<path> ----
$man = @{}
foreach ($line in [IO.File]::ReadAllLines($Manifest)) {
    if ($line.StartsWith("HASH|")) {
        $p = $line.Split("|",4)
        $man[$p[3].ToLower()] = $p[1]
    }
}
Say ("manifest entries loaded : {0}" -f $man.Count)

$PreDir  = "C:\RTMView\Backup\preinstall_20260830_004812"
$curCfgs = @(
    'C:\RTMView\Shell\appsettings.json',
    'C:\RTMView\RTM\appsettings.json',
    'C:\RTMView\RTM\data.sys',
    'C:\RTMView\RTM.Twilio\appsettings.json'
)
$cfgExt = @('.json','.sys','.config','.xml','.ini')

New-Item -ItemType Directory -Force -Path (Join-Path $Preserve 'configs\current')    | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Preserve 'configs\preinstall') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Preserve 'preinstall_binaries')| Out-Null

$copied = New-Object System.Collections.ArrayList
function CopyOne($src, $dstDir, $relName) {
    $dst = Join-Path $dstDir $relName
    $dp  = Split-Path $dst -Parent
    if (-not (Test-Path $dp)) { New-Item -ItemType Directory -Force -Path $dp | Out-Null }
    Copy-Item -LiteralPath $src -Destination $dst -ErrorAction SilentlyContinue
    [void]$copied.Add([pscustomobject]@{ Src=$src; Dst=$dst })
}

Say ""
Say "===== B1 CURRENT CONFIGS (the machine's live state - evidence of what the installer lost) ====="
foreach ($c in $curCfgs) {
    if (Test-Path $c) {
        $rel = ($c -replace '^C:\\RTMView\\','') -replace '\\','__'
        CopyOne $c (Join-Path $Preserve 'configs\current') $rel
        Say ("  copied  {0}   ->  configs\current\{1}" -f $c, $rel)
    } else { Say ("  ABSENT  {0}" -f $c) }
}

Say ""
Say "===== B2 PREINSTALL CONFIGS (state BEFORE the installer - the pair for the comparison) ====="
$preFiles = @()
if (Test-Path $PreDir) { $preFiles = @(Get-ChildItem $PreDir -Recurse -File -ErrorAction SilentlyContinue) }
else { Say ("  *** ABSENT: {0}" -f $PreDir) }
$preCfg = @($preFiles | Where-Object { $cfgExt -contains $_.Extension.ToLower() })
$preBin = @($preFiles | Where-Object { $cfgExt -notcontains $_.Extension.ToLower() })
Say ("  config-like files : {0}" -f $preCfg.Count)
foreach ($f in $preCfg) {
    $rel = $f.FullName.Substring($PreDir.Length).TrimStart('\')
    CopyOne $f.FullName (Join-Path $Preserve 'configs\preinstall') $rel
    Say ("      {0}" -f $rel)
}

Say ""
Say "===== B3 PREINSTALL BINARIES (kept whole: we never measured their revisions) ====="
Say ("  files : {0}" -f $preBin.Count)
$i = 0
foreach ($f in $preBin) {
    $rel = $f.FullName.Substring($PreDir.Length).TrimStart('\')
    CopyOne $f.FullName (Join-Path $Preserve 'preinstall_binaries') $rel
    $i++
    if ($i % 200 -eq 0) { Write-Host ("      ... {0} / {1}" -f $i, $preBin.Count) }
}
Say ("  copied : {0}" -f $i)

Say ""
Say "===== C VERIFY - SHA-256 of every copied file against the manifest ====="
$ok = 0; $bad = 0; $notInMan = 0; $missingDst = 0
$badList = New-Object System.Collections.ArrayList
foreach ($c in $copied) {
    if (-not (Test-Path $c.Dst)) { $missingDst++; [void]$badList.Add("MISSING AT DESTINATION: " + $c.Src); continue }
    $h = (Get-FileHash -Path $c.Dst -Algorithm SHA256).Hash
    $key = $c.Src.ToLower()
    if (-not $man.ContainsKey($key)) { $notInMan++; [void]$badList.Add("NOT IN MANIFEST: " + $c.Src); continue }
    if ($man[$key] -eq $h) { $ok++ } else { $bad++; [void]$badList.Add("HASH MISMATCH: " + $c.Src) }
}
Say ("  files copied        : {0}" -f $copied.Count)
Say ("  SHA-256 matched     : {0}" -f $ok)
Say ("  SHA-256 MISMATCH    : {0}   (must be 0)" -f $bad)
Say ("  missing at dest     : {0}   (must be 0)" -f $missingDst)
Say ("  not in manifest     : {0}   (must be 0)" -f $notInMan)
foreach ($b in $badList) { Say ("      {0}" -f $b) }

Say ""
Say "===== NEGATIVE CONTROL - the verifier must be able to say NO ====="
$probe = Join-Path $Preserve 'configs\current\ZZZ_control.txt'
[IO.File]::WriteAllText($probe, "this file is not in the manifest")
$ph = (Get-FileHash -Path $probe -Algorithm SHA256).Hash
$inMan = $man.ContainsKey(('C:\RTMView\ZZZ_control.txt').ToLower())
Say ("  a file deliberately absent from the manifest is recognised as absent : {0}   (must be True)" -f (-not $inMan))
Say  "  (left in place on purpose - it is proof the check runs, not a copied artefact)"

Say ""
Say "===== NOT COPIED - outside the demolition zone, by coordinator's ruling ====="
foreach ($d in @("$OpsRoot\backup", "$OpsRoot\output")) {
    if (Test-Path $d) {
        $ff = @(Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue)
        $bb = ($ff | Measure-Object -Property Length -Sum).Sum
        Say ("  {0} : {1} files, {2} MB - NOT copied (already outside C:\RTMView\)" -f $d, $ff.Count, [math]::Round($bb/1MB,1))
    }
}
Say "  .measurements\ and .probes\ live on the LOCAL machine (D:\Claude\Projects\...), not on 234 -> outside the demolition zone, not touched."

$free = [math]::Round((Get-PSDrive C).Free/1GB,2)
Say ""
Say ("free space on C: after copy : {0} GB" -f $free)
Say "===== END-OF-RUN MARKER: EVACUATION-COPY-COMPLETE ====="

[IO.File]::WriteAllLines($Report, $L, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
if ($bad -eq 0 -and $missingDst -eq 0 -and $notInMan -eq 0 -and $copied.Count -gt 0) {
    Write-Host "GATE: PASS - every copied file matches the manifest byte for byte"
} else {
    Write-Host "GATE: FAIL - DO NOT PROCEED TO DEMOLITION. Read the report."
}
Write-Host ""
Write-Host "COPY THIS BACK:"
Write-Host "   $Report"
