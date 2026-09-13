#Requires -Version 5.1
<#
  PROBE 234 / package-verify   -   verifies the copy, then unpacks. Installs NOTHING.
  WHERE IT RUNS : server 234 (G0 exits, it does not warn).
  WRITES        : unpacks into C:\Temp\install_234\ and writes one report into output\.
                  Touches nothing else. No service, no database, no C:\IceDash\.
  WHY           : provenance was proved on the dev machine, but 234 will be installed from a
                  COPY. A copy is another place where content can diverge from what we approved.
                  So the copy proves itself by sha256 BEFORE it is unpacked - not after.
#>

$ErrorActionPreference = "Continue"
$Zip      = "C:\Temp\08092026.0027.zip"
$Dest     = "C:\Temp\install_234"
$Expected = "CCD1EBC35E976DFAA0E7664A20E7BBF9E2A5D777E7CEB4F8D411432DA0D8DADC"
$OutDir   = "C:\RTMView-Ops\output"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_package-verify.txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}

Say "===== G0 which machine is this ====="
$n = ($env:COMPUTERNAME -eq "RTM")
$u = ("$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper() -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
$m = (@(Get-WmiObject Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" -ErrorAction SilentlyContinue |
        ForEach-Object { "$($_.MACAddress)".Replace(":","").ToUpper() }) -contains "000D3AD3061B")
$f = (Test-Path "C:\RTMView-Ops\preserve_20260906_1230")
Say ("  name {0} / uuid {1} / mac {2} / footprint {3}" -f $n, $u, $m, $f)
if (-not ($n -and $u -and $m -and $f)) { Say "  *** G0 FAILED - not server 234. Nothing was read."; Fin $false }
Say "  G0 PASS"

Say ""
Say "===== the copy proves itself BEFORE it is unpacked ====="
if (-not (Test-Path $Zip)) { Say ("  *** NOT FOUND: {0}" -f $Zip); Fin $false }
$size = (Get-Item $Zip).Length
$got  = (Get-FileHash $Zip -Algorithm SHA256).Hash
Say ("  file     : {0}" -f $Zip)
Say ("  size     : {0} bytes ({1:N1} MB)" -f $size, ($size/1MB))
Say ("  got      : {0}" -f $got)
Say ("  expected : {0}" -f $Expected)
$match = ($got -eq $Expected)
Say ("  MATCH    : {0}" -f $match)
Say ("  CONTROL the comparator can deny : {0}   (must be True)" -f ($got -ne "0000000000000000000000000000000000000000000000000000000000000000"))
if (-not $match) {
    Say ""
    Say "  *** MISMATCH - this is NOT the package we verified. NOT unpacked. Report."
    Fin $false
}

Say ""
Say "===== unpacking ====="
if (Test-Path $Dest) { Say ("  destination already exists, contents will be overwritten: {0}" -f $Dest) }
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    Expand-Archive -Path $Zip -DestinationPath $Dest -Force -ErrorAction Stop
} catch {
    Say ("  *** unpack failed: {0}" -f $_.Exception.Message)
    Fin $false
}
$files = @(Get-ChildItem $Dest -Recurse -File -ErrorAction SilentlyContinue)
Say ("  files unpacked : {0}" -f $files.Count)

Say ""
Say "===== the unpacked installer is the one we approved ====="
$found = @(Get-ChildItem $Dest -Recurse -File -Filter "Install-RTMView.ps1")
Say ("  Install-RTMView.ps1 copies : {0}   (must be 1)" -f $found.Count)
foreach ($x in $found) { Say ("      {0}" -f $x.FullName) }
if ($found.Count -ne 1) { Say "  *** STOP - which one would run?"; Fin $false }
$txt = [IO.File]::ReadAllText($found[0].FullName, [Text.Encoding]::UTF8)
$a = $txt.Contains('$preserveShell')
$b = $txt.Contains('Preserved:')
$c = ([regex]::Matches($txt, [regex]::Escape('(package version ignored)'))).Count
Say ("  preserve block                 : {0}   (must be True)" -f $a)
Say ("  'Preserved:' log line          : {0}   (must be True)" -f $b)
Say ("  d01851a wording, occurrences   : {0}   (must be 2)" -f $c)
Say  "  (only these three distinguish the fixed installer from the old one - measured 2026-09-08;"
Say  "   data.sys / Port=`$DBPort / -FreshDb existed before the fix and prove nothing about it)"
$ok = ($a -and $b -and $c -eq 2)
Say ("  installer is the fixed one : {0}" -f $ok)
if (-not $ok) { Say "  *** STOP - the unpacked installer is not the fixed one."; Fin $false }

Say ""
Say "===== what came with it ====="
foreach ($n2 in @("Update-RTMView.ps1","schema.sql","Provision-FreshDb.ps1")) {
    Say ("  {0,-26} : {1}" -f $n2, @(Get-ChildItem $Dest -Recurse -File -Filter $n2).Count)
}
Say ("  db\data\*.sql   : {0}   (must be 4)" -f @(Get-ChildItem (Join-Path $Dest "db\data") -File -Filter "*.sql" -ErrorAction SilentlyContinue).Count)
Say ("  DB\ dumps       : {0}   (must be 0 - built with -SkipDB on purpose)" -f @(Get-ChildItem (Join-Path $Dest "DB") -File -ErrorAction SilentlyContinue).Count)

Say ""
Say "===== END-OF-RUN MARKER: PACKAGE-VERIFY-COMPLETE ====="
Say ""
Say "NOTHING WAS INSTALLED. No service, no database, no configuration was touched."
Fin $true
