#Requires -Version 5.1
<#
  PROBE 234 / backup-inventory   -   READ ONLY. Nothing is copied, moved or deleted.
  WHERE IT RUNS : server 234 (G0 enforces it by exiting, not warning).
  WRITES        : one report into C:\RTMView-Ops\output\ . Nothing else, anywhere.
  PURPOSE       : C:\RTMView\Backup holds 5420 files; the evacuation took 880 of them - one
                  subfolder. The other ~4540 were never named, and the delete would take them.
                  The evacuation gate could not catch this: it compared what was carried out
                  against a manifest built from the same list. A list checked against itself
                  proves nothing about completeness. So: read the directory FROM DISK and say
                  what is actually in it.
  WHAT IT ANSWERS, per top-level entry under Backup:
                  file count, total bytes, earliest and latest write time, and WHAT IT IS -
                  judged by CONTENT (what file types dominate), never by the folder's name.
  DECIDES NOTHING : it carries nothing out and deletes nothing. The decision is the coordinator's.
#>

$ErrorActionPreference = "Continue"
$OpsRoot  = "C:\RTMView-Ops"
$OutDir   = Join-Path $OpsRoot "output"
$Preserve = Join-Path $OpsRoot "preserve_20260906_1230"
$BackupD  = "C:\RTMView\Backup"
$server   = "234"
$topic    = "backup-inventory"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}

Say "WHERE IT RUNS : server 234. READ ONLY - nothing is copied, moved or deleted."
Say ""

# ---------------- G0 ----------------
$expName = "RTM"
$expUuid = "E9516FFB-3068-47EA-8860-6A9D764325E6"
$expMac  = "000D3AD3061B"
Say "===== G0 which machine is this ====="
$gotName = $env:COMPUTERNAME
$gotUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$macs    = @(Get-WmiObject Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" -ErrorAction SilentlyContinue |
             ForEach-Object { "$($_.MACAddress)".Replace(":","").ToUpper() })
$ok = ($gotName -eq $expName) -and ($gotUuid -eq $expUuid) -and ($macs -contains $expMac) -and (Test-Path $Preserve)
Say ("  name {0} / uuid {1} / mac {2} / footprint {3}" -f ($gotName -eq $expName), ($gotUuid -eq $expUuid), ($macs -contains $expMac), (Test-Path $Preserve))
if (-not $ok) { Say "  *** G0 FAILED - THIS IS NOT SERVER 234. Nothing was read."; Fin $false }
Say "  G0 PASS - this is server 234"

if (-not (Test-Path $BackupD)) { Say ("  *** {0} does not exist." -f $BackupD); Fin $false }

# ---------------- what the evacuation actually took ----------------
Say ""
Say "===== A what the evacuation took out of Backup, read from preserve_ - not from the manifest ====="
$presBackup = @(Get-ChildItem $Preserve -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -like "*preinstall_20260830_004812*" })
Say ("  files under preserve_ whose path contains preinstall_20260830_004812 : {0}" -f $presBackup.Count)
Say  "  (the evacuation named ONE subfolder plus four config files - that was the whole list)"

# ---------------- the directory as it actually is ----------------
Say ""
Say "===== B what is ACTUALLY in C:\RTMView\Backup - read from disk ====="
$all = @(Get-ChildItem $BackupD -Recurse -File -ErrorAction SilentlyContinue)
$allBytes = ($all | Measure-Object -Property Length -Sum).Sum
if ($allBytes -eq $null) { $allBytes = 0 }
Say ("  total: {0} files, {1:N1} MB" -f $all.Count, ($allBytes/1MB))
Say ""
Say "  top-level entries (type judged by CONTENT, not by folder name):"
Say ""
Say ("  {0,-34} {1,>7} {2,>11}  {3,-19} {4,-19} {5}" -f "entry","files","MB","earliest","latest","what it looks like")
Say ("  {0}" -f ("-" * 130))

$rows = @()
foreach ($d in @(Get-ChildItem $BackupD -Directory -ErrorAction SilentlyContinue)) {
    $f = @(Get-ChildItem $d.FullName -Recurse -File -ErrorAction SilentlyContinue)
    $b = ($f | Measure-Object -Property Length -Sum).Sum
    if ($b -eq $null) { $b = 0 }
    $ext = @{}
    foreach ($x in $f) { $e = $x.Extension.ToLower(); if ($e -eq "") { $e = "<none>" }; if ($ext.ContainsKey($e)) { $ext[$e]++ } else { $ext[$e] = 1 } }
    $top = @($ext.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 3 |
             ForEach-Object { "$($_.Key) x$($_.Value)" }) -join ", "
    $kind = "unidentified"
    if     (@($f | Where-Object { $_.Extension -match '^\.(dump|backup|sql)$' }).Count -gt 0) { $kind = "DATABASE DUMPS" }
    elseif (@($f | Where-Object { $_.Name -eq 'data.sys' }).Count -gt 0)                      { $kind = "installer snapshot (has data.sys)" }
    elseif (@($f | Where-Object { $_.Extension -match '^\.(dll|exe)$' }).Count -gt 10)        { $kind = "deployed binaries (a copy of an installation)" }
    elseif (@($f | Where-Object { $_.Extension -match '^\.(log|txt)$' }).Count -eq $f.Count -and $f.Count -gt 0) { $kind = "logs only" }
    $earliest = ""; $latest = ""
    if ($f.Count -gt 0) {
        $earliest = ($f | Sort-Object LastWriteTime | Select-Object -First 1).LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        $latest   = ($f | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime.ToString("yyyy-MM-dd HH:mm")
    }
    $evac = ($d.Name -eq 'preinstall_20260830_004812')
    Say ("  {0,-34} {1,7} {2,11:N1}  {3,-19} {4,-19} {5}" -f $d.Name, $f.Count, ($b/1MB), $earliest, $latest, $kind)
    Say ("  {0,-34} {1}" -f "", ("      contents: " + $top + $(if ($evac) { "   <-- THIS ONE IS ALREADY EVACUATED" } else { "   <-- NOT evacuated" })))
    $rows += @{ name=$d.Name; files=$f.Count; bytes=$b; evac=$evac }
}

$loose = @(Get-ChildItem $BackupD -File -ErrorAction SilentlyContinue)
$lb = ($loose | Measure-Object -Property Length -Sum).Sum
if ($lb -eq $null) { $lb = 0 }
Say ""
Say ("  loose files directly in Backup\ (not in any subfolder) : {0} files, {1:N1} MB" -f $loose.Count, ($lb/1MB))
foreach ($x in ($loose | Select-Object -First 20)) {
    Say ("      {0,-52} {1,12}  {2}" -f $x.Name, $x.Length, $x.LastWriteTime.ToString("yyyy-MM-dd HH:mm"))
}
if ($loose.Count -gt 20) { Say ("      ... and {0} more" -f ($loose.Count - 20)) }

# ---------------- the arithmetic that matters ----------------
Say ""
Say "===== C the arithmetic - what would be lost by deleting as-is ====="
$evacFiles = 0; $evacBytes = 0; $keepFiles = 0; $keepBytes = 0
foreach ($r in $rows) {
    if ($r.evac) { $evacFiles += $r.files; $evacBytes += $r.bytes }
    else         { $keepFiles += $r.files; $keepBytes += $r.bytes }
}
$keepFiles += $loose.Count; $keepBytes += $lb
Say ("  already evacuated      : {0,6} files, {1,10:N1} MB" -f $evacFiles, ($evacBytes/1MB))
Say ("  NOT evacuated          : {0,6} files, {1,10:N1} MB   <- this is what the delete would take" -f $keepFiles, ($keepBytes/1MB))
Say ("  sum matches the total  : {0}   (must be True)" -f (($evacFiles + $keepFiles) -eq $all.Count))
$free = [math]::Round((Get-PSDrive C).Free/1GB,2)
Say ("  free space on C:       : {0} GB   (carrying the rest out would cost {1:N1} GB of it)" -f $free, ($keepBytes/1GB))
Say ("  NEGCTL a folder that must NOT be there : {0}   (must be False)" -f (Test-Path (Join-Path $BackupD "NoSuchFolder_xyz")))

Say ""
Say "  NOTHING WAS COPIED, MOVED OR DELETED. This probe decides nothing."
Say ""
Say "===== END-OF-RUN MARKER: BACKUP-INVENTORY-COMPLETE ====="
Fin $true
