#Requires -Version 5.1
<#
  PROBE 234 / flag-on      BOX A of two. Turns RtmRelay:DiagPushLogging from false to true in the
                           Shell config, and nothing else. Restarts NOTHING.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate.

  *** THIS BOX WRITES ON PRODUCTION: IT EDITS ONE VALUE IN THE OPERATOR'S CONFIG. REVERSIBLE. ***
  It restarts no service, touches no binary, applies no migration, queries no database, asks for no
  password. C:\IceDash is never read or listed. The engine, the adapter and the Shell keep running:
  the coordinator verified [v3: RtmRelayService.cs:27,38 IOptionsMonitor; :349 CurrentValue read at use
  time; Program.cs:26 reloadOnChange] that the value is picked up live, so NO Shell restart is needed -
  and a Shell restart would destroy the predicate the whole analysis rests on.

  WHY BOX A IS SEPARATE FROM BOX B. Between the edit and the mark there is a HUMAN action: the
  coordinator reloads the Agent Grid page, which raises a fresh subscription and drives a message down
  the same path, giving us the positive control that the flag is actually LIVE in the process (his
  item 4, 11:5x). A single script cannot wait for that reload deterministically - a Start-Sleep would
  race his click, and a measurement that raced a human is indistinguishable from a finding. The seam
  belongs exactly where the human acts. Second reason: if one combined box died half-way, the flag
  would stay ON in production. Here box A leaves a ready restore command and a marker file, and box B
  restores the flag on BOTH paths - when its control fails and after all the numbers are taken.

  HOW THE EDIT IS MADE. By TEXT replacement of the single value, not through
  ConvertFrom-Json/ConvertTo-Json: the round trip would rewrite the whole operator file, reformat it and
  lose key order, and I have to show that EXACTLY ONE LINE changed. Gates on the edit:
     the key must exist with value false in the file that decides the effective value; if it is ABSENT
       everywhere the probe STOPS - adding a key is a different edit and needs its own word;
     backup of the original taken BEFORE the edit, named with a stamp, verified by sha256;
     after the edit: sha256 of both config files, byte-size delta, and a LINE DIFF that must show
       exactly one changed line - more than one and the probe restores the backup itself;
     the file must still parse as JSON after the edit, or the backup is restored immediately.

  WHAT IT LEAVES FOR BOX B: a marker file in C:\RTMView-Ops\output\ carrying the edit time, the config
  path and the backup path. Box B reads the newest marker and uses the edit time as the boundary for the
  flag-live control, so that boundary is a measured timestamp rather than something retyped by hand.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$KEY = 'DiagPushLogging'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_flag-on.txt')
$markerPath = Join-Path $OutDir ('234_' + $stamp + '_flag-on.marker')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (flag is on, one line changed, backup in place)' } else { 'VERDICT: FAIL (nothing was left changed, or it was restored - see above)' }))
    [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($p) {
    if (Test-Path -LiteralPath $p) { return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash } else { return 'ABSENT' }
}

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to write'; Fin $false }
$rr = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ('  Get-Sha256Of resolves to {0}   expected Function' -f $rr.CommandType)
if ("$($rr.CommandType)" -ne 'Function') { Say '  *** helper shadowed - stop'; Fin $false }
Say ('  now : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say '  NO service is restarted by this box. The value is picked up live (IOptionsMonitor + reloadOnChange).'

Say ''
Say '===== 1  the Shell service and its config, DISCOVERED ====='
$svcShell = @(Get-WmiObject Win32_Service -ErrorAction SilentlyContinue |
              Where-Object { $_.PathName -match '(?i)RTMView\\Shell' }) | Select-Object -First 1
if (-not $svcShell) { Say '  *** no service whose path matches RTMView\Shell - I will not guess it. Stop.'; Fin $false }
$shExe = "$($svcShell.PathName)".Trim()
if ($shExe.StartsWith('"')) { $shExe = $shExe.Substring(1, $shExe.IndexOf('"', 1) - 1) }
else { $q = $shExe.IndexOf(' -'); if ($q -gt 0) { $shExe = $shExe.Substring(0, $q) } }
$shellDir = [IO.Path]::GetDirectoryName($shExe)
Say ('  service {0} , state {1}' -f $svcShell.Name, $svcShell.State)
Say ('  exe {0}' -f $shExe)
Say ('  dir {0}' -f $shellDir)
Say ('  pid {0}   <- it must NOT change; this box does not restart it' -f $svcShell.ProcessId)
$pidBefore = $svcShell.ProcessId

$cfgBase = Join-Path $shellDir 'appsettings.json'
$cfgProd = Join-Path $shellDir 'appsettings.Production.json'
$target = $null
foreach ($cfg in @($cfgProd, $cfgBase)) {   # Production decides the effective value, so it is preferred
    Say ''
    Say ('  {0}   exists {1}' -f $cfg, (Test-Path -LiteralPath $cfg))
    if (-not (Test-Path -LiteralPath $cfg)) { continue }
    $raw = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8
    Say ('      sha256 {0}   bytes {1}' -f (Get-Sha256Of $cfg), (Get-Item -LiteralPath $cfg).Length)
    $hits = [regex]::Matches($raw, '"' + $KEY + '"\s*:\s*(true|false)', 'IgnoreCase')
    Say ('      occurrences of "{0}" with a boolean value : {1}' -f $KEY, $hits.Count)
    foreach ($h in $hits) { Say ('        found : {0}' -f $h.Value) }
    if ($hits.Count -eq 1 -and $null -eq $target) { $target = [pscustomobject]@{ Path = $cfg; Raw = $raw; Match = $hits[0] } }
    if ($hits.Count -gt 1) { Say '      *** more than one occurrence - I will not guess which one decides. Stop.'; Fin $false }
}
if ($null -eq $target) {
    Say ''
    Say ('  *** the key "{0}" is not present with a boolean value in EITHER config.' -f $KEY)
    Say '      Its default is false (RtmRelayOptions.cs:6), so the effective value is false - but ADDING'
    Say '      a key is a different edit from flipping one: it changes the shape of the operator file and'
    Say '      needs its own word. I stop here instead of inventing the edit.'
    Fin $false
}
Say ''
Say ('  TARGET FILE : {0}' -f $target.Path)
Say ('  current value : {0}' -f $target.Match.Value)
if ($target.Match.Value -match '(?i)true') {
    Say '  the flag is ALREADY true - nothing to change. Box B can run as it is; no backup was made and'
    Say '  no file was touched. Telling the coordinator so rather than writing a no-op.'
    # One Add per fully-formed string. The earlier form - 'key=' + $value inside an @(...) literal -
    # emitted the key and the value as TWO array elements, so every pair landed on two lines in the
    # marker while the pure literals stayed whole. Measured in 234_20260913_115735_resub-v4.txt, which
    # printed the file verbatim. Built explicitly here, then read back and gated.
    $markerLines = New-Object System.Collections.ArrayList
    [void]$markerLines.Add('flag-on marker')
    [void]$markerLines.Add([string]::Concat('editTime=', (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')))
    [void]$markerLines.Add([string]::Concat('config=', $target.Path))
    [void]$markerLines.Add('backup=NONE-ALREADY-TRUE')
    [void]$markerLines.Add('changed=0')
    [IO.File]::WriteAllLines($markerPath, $markerLines, (New-Object System.Text.UTF8Encoding($false)))
    $check = @(Get-Content -LiteralPath $markerPath -Encoding UTF8)
    Say ('  marker lines written {0} , read back {1}   expected equal' -f $markerLines.Count, $check.Count)
    foreach ($cl in $check) { Say ('      | ' + $cl) }
    if ($check.Count -ne $markerLines.Count) { Say '  *** the marker came back in a different shape - stop'; Fin $false }
    Say ('  marker : {0}' -f $markerPath)
    Fin $true
}

Say ''
Say '===== 2  BACKUP before the edit ====='
$backup = $target.Path + '.devops_' + $stamp + '.bak'
Copy-Item -LiteralPath $target.Path -Destination $backup -Force
$shaOrig = Get-Sha256Of $target.Path
$shaBak  = Get-Sha256Of $backup
Say ('  backup  : {0}' -f $backup)
Say ('  sha original {0}' -f $shaOrig)
Say ('  sha backup   {0}   identical : {1}   expected True' -f $shaBak, ($shaOrig -eq $shaBak))
if ($shaOrig -ne $shaBak) { Say '  *** the backup does not match the original - refusing to edit'; Fin $false }

Say ''
Say '===== 3  THE EDIT - one value, by text replacement ====='
$before = $target.Raw
$newValue = $target.Match.Value -replace '(?i)false', 'true'
$after = $before.Remove($target.Match.Index, $target.Match.Length).Insert($target.Match.Index, $newValue)
Say ('  replacing : {0}' -f $target.Match.Value)
Say ('  with      : {0}' -f $newValue)
Say ('  bytes before {0} , after {1} , delta {2}   expected delta -1 (false -> true)' -f $before.Length, $after.Length, ($after.Length - $before.Length))
$linesBefore = $before -split "`n"
$linesAfter  = $after  -split "`n"
$changed = 0
$maxi = [Math]::Max($linesBefore.Count, $linesAfter.Count)
for ($i = 0; $i -lt $maxi; $i++) {
    $lb = $(if ($i -lt $linesBefore.Count) { $linesBefore[$i] } else { '<missing>' })
    $la = $(if ($i -lt $linesAfter.Count)  { $linesAfter[$i]  } else { '<missing>' })
    if ($lb -ne $la) {
        $changed++
        Say ('    line {0} BEFORE | {1}' -f ($i+1), $lb.Trim())
        Say ('    line {0} AFTER  | {1}' -f ($i+1), $la.Trim())
    }
}
Say ('  changed lines : {0}   expected exactly 1' -f $changed)
Say ('  line count : before {0} , after {1}   expected equal' -f $linesBefore.Count, $linesAfter.Count)
if ($changed -ne 1 -or $linesBefore.Count -ne $linesAfter.Count) {
    Say '  *** more than one line would change - NOT writing anything. The file on disk is untouched.'
    Fin $false
}
# write preserving the original encoding shape: UTF8 without BOM if it had none
$hadBom = $false
$firstBytes = [IO.File]::ReadAllBytes($target.Path)
if ($firstBytes.Length -ge 3 -and $firstBytes[0] -eq 0xEF -and $firstBytes[1] -eq 0xBB -and $firstBytes[2] -eq 0xBF) { $hadBom = $true }
Say ('  original had a BOM : {0} - the same shape is written back' -f $hadBom)
[IO.File]::WriteAllText($target.Path, $after, (New-Object System.Text.UTF8Encoding($hadBom)))

Say ''
Say '===== 4  PROOF after the edit ====='
$raw2 = Get-Content -LiteralPath $target.Path -Raw -Encoding UTF8
$hits2 = [regex]::Matches($raw2, '"' + $KEY + '"\s*:\s*(true|false)', 'IgnoreCase')
Say ('  occurrences now : {0}   value : {1}' -f $hits2.Count, $(if ($hits2.Count -gt 0) { $hits2[0].Value } else { 'NONE' }))
$valueOk = ($hits2.Count -eq 1 -and $hits2[0].Value -match '(?i)true')
Say ('  value is true : {0}   expected True' -f $valueOk)
$parseOk = $true
try { $null = $raw2 | ConvertFrom-Json } catch { $parseOk = $false; Say ('  *** JSON no longer parses : {0}' -f $_.Exception.Message) }
Say ('  still valid JSON : {0}   expected True' -f $parseOk)
Say ('  sha256 now : {0}' -f (Get-Sha256Of $target.Path))
Say ('  sha256 was : {0}   differ : {1}   expected True' -f $shaOrig, ((Get-Sha256Of $target.Path) -ne $shaOrig))
$otherCfg = $(if ($target.Path -eq $cfgProd) { $cfgBase } else { $cfgProd })
Say ('  the OTHER config {0} : sha {1}   must be unchanged by this box' -f $otherCfg, (Get-Sha256Of $otherCfg))
$svcShell2 = Get-WmiObject Win32_Service -Filter ("Name='" + $svcShell.Name + "'") -ErrorAction SilentlyContinue
Say ('  Shell pid now {0} , before {1} , UNCHANGED : {2}   expected True' -f $svcShell2.ProcessId, $pidBefore, ($svcShell2.ProcessId -eq $pidBefore))
if (-not ($valueOk -and $parseOk)) {
    Say '  *** restoring the backup NOW and leaving production as it was'
    Copy-Item -LiteralPath $backup -Destination $target.Path -Force
    Say ('  restored : sha {0}   equals original : {1}' -f (Get-Sha256Of $target.Path), ((Get-Sha256Of $target.Path) -eq $shaOrig))
    Fin $false
}

$editTime = Get-Date
# One Add per fully-formed string - see the note in the already-true branch above. The file is then read
# back and gated, because a marker box B cannot parse costs a production write to fix, and box B is the
# thing that returns this flag to false.
$markerLines = New-Object System.Collections.ArrayList
[void]$markerLines.Add('flag-on marker')
[void]$markerLines.Add([string]::Concat('editTime=', $editTime.ToString('yyyy-MM-dd HH:mm:ss.fff')))
[void]$markerLines.Add([string]::Concat('config=', $target.Path))
[void]$markerLines.Add([string]::Concat('backup=', $backup))
[void]$markerLines.Add([string]::Concat('shaOriginal=', $shaOrig))
[void]$markerLines.Add('changed=1')
[IO.File]::WriteAllLines($markerPath, $markerLines, (New-Object System.Text.UTF8Encoding($false)))
$markerCheck = @(Get-Content -LiteralPath $markerPath -Encoding UTF8)
Say ''
Say '===== 4b  the marker, read back and GATED - box B depends on it to undo this edit ====='
Say ('  lines written {0} , read back {1}   expected equal' -f $markerLines.Count, $markerCheck.Count)
foreach ($cl in $markerCheck) { Say ('      | ' + $cl) }
$pairsOk = $true
foreach ($needKey in @('editTime','config','backup','changed')) {
    $found = @($markerCheck | Where-Object { $_.StartsWith($needKey + '=') -and $_.Length -gt ($needKey.Length + 1) }).Count
    Say ('  {0,-12} complete on ONE line : {1}   expected 1' -f $needKey, $found)
    if ($found -ne 1) { $pairsOk = $false }
}
if (($markerCheck.Count -ne $markerLines.Count) -or (-not $pairsOk)) {
    Say '  *** the marker is not in the shape box B needs. Restoring the backup, so production is not left'
    Say '      with an enabled flag and no usable undo, then stopping.'
    Copy-Item -LiteralPath $backup -Destination $target.Path -Force
    Say ('  restored : sha {0}   equals original : {1}' -f (Get-Sha256Of $target.Path), ((Get-Sha256Of $target.Path) -eq $shaOrig))
    Fin $false
}

Say ''
Say '===== 5  what happens next, and how to undo this without me ====='
Say ('  EDIT TIME : {0}   <- box B uses this as the boundary for the flag-live control' -f $editTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))
Say ('  marker    : {0}' -f $markerPath)
Say '  NEXT: the coordinator reloads the Agent Grid page. That raises a fresh subscription and drives a'
Say '  message down the same path, so RECV updateUserGrid appearing in the Shell log AFTER the edit time'
Say '  proves the flag is live in the process - not merely true in the file. Box B checks exactly that'
Say '  and refuses to start the main run if it is absent.'
Say ''
Say '  IF BOX B IS NOT RUN, restore the flag with this one line - it does not need me:'
Say ('      Copy-Item -LiteralPath "{0}" -Destination "{1}" -Force' -f $backup, $target.Path)
Say '  Box B restores it itself on BOTH paths: when its control fails, and after all numbers are taken.'
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Fin $true
