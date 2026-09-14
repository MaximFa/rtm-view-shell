#Requires -Version 5.1
<#
  PROBE 234 / D1 - move OUR engine off the shared port: the config value only. WRITES ONE VALUE.
  WHERE IT RUNS : server 234 (machine RTM). Name and hardware UUID are a gate.
  WHAT IT WRITES: a backup copy beside C:\RTMView\RTM\appsettings.json, then ONE value inside that
                  file: http://127.0.0.1:8088 -> http://127.0.0.1:8089. Nothing else. It does NOT
                  restart anything (that is D2), does not touch the database, asks for no password,
                  and never opens C:\IceDash, the production RTM.Twilio, legacy RTM,
                  C:\Program Files\CcDashboard or PostgreSQL on either port.
  WHY          : our Shell's five live sockets are held at the server end by the LEGACY engine
                 (pid 3576, C:\IceDash\RTM\RTM.exe) because both engines listen on 8088. Moving OUR
                 engine to 8089 removes the ambiguity BY CONSTRUCTION instead of checking for it.
                 The adapter already targets 127.0.0.1:8089 and is not touched.
  THE EDIT IS TARGETED, NOT A JSON ROUND-TRIP: re-serialising rewrites the whole file, and production
                 JSON here is formatted by a previous ConvertTo-Json (two spaces after the colon), so a
                 rewrite would change bytes nobody asked to change.
  GATES         : entry values re-measured NOW; a replacement that matches 0 places is a STOP with an
                 automatic restore - a no-op edit reporting success is a service quietly left on the old
                 port; byte verification after the edit (size delta must be exactly 0, BOM unchanged,
                 no NUL, JSON still parses).
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir   = 'C:\RTMView-Ops\output'
$CFG      = 'C:\RTMView\RTM\appsettings.json'
$OLDURL   = 'http://127.0.0.1:8088'
$NEWURL   = 'http://127.0.0.1:8089'
$SENTINEL = -999

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_d1-port-config.txt')
$bak   = $CFG + '.devops_' + $stamp + '.bak'
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS - the value is changed; D2 (restart) is a SEPARATE move' }
                       else        { 'VERDICT: FAIL - read the RESTORE line above' }))
    Flush
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Safe-Count($c) { if ($null -eq $c) { return $SENTINEL } return @($c).Count }
function Restore-Line() {
    Say ''
    Say '  RESTORE - one line, puts the previous configuration back:'
    Say ('    Copy-Item -LiteralPath "{0}" -Destination "{1}" -Force' -f $bak, $CFG)
}

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
Say ('  assignment gate : unassigned {0} (want {1})' -f (Safe-Count $null), $SENTINEL)
Say ('  now : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say '  this run edits ONE value and restarts NOTHING'

Say ''
Say '===== 1  ENTRY PREDICATES - re-measured now, not inherited from an hour ago ====='
$l8089 = @(Get-NetTCPConnection -LocalPort 8089 -State Listen -ErrorAction SilentlyContinue)
Say ('  listeners on 8089 : {0}   expected 0' -f (Safe-Count $l8089))
foreach ($x in $l8089) {
    $pr = Get-Process -Id $x.OwningProcess -ErrorAction SilentlyContinue
    Say ('      {0} pid {1} {2}' -f $x.LocalAddress, $x.OwningProcess, $(if ($pr) { $pr.Path } else { '(gone)' }))
}
if ((Safe-Count $l8089) -ne 0) { Say '  *** 8089 is taken - STOP. The port must be chosen again with the coordinator.'; Fin $false }
$l8088 = @(Get-NetTCPConnection -LocalPort 8088 -State Listen -ErrorAction SilentlyContinue)
Say ('  listeners on 8088 : {0}   expected 2 (ours + legacy)' -f (Safe-Count $l8088))
foreach ($x in $l8088) {
    $pr = Get-Process -Id $x.OwningProcess -ErrorAction SilentlyContinue
    $sv = @(Get-WmiObject Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.ProcessId -eq $x.OwningProcess })
    Say ('      {0} pid {1} {2}  svc {3}' -f $x.LocalAddress, $x.OwningProcess, $(if ($pr) { $pr.Path } else { '(gone)' }), ($sv.Name -join ','))
}
if (-not (Test-Path -LiteralPath $CFG)) { Say ('  *** config not found : {0}' -f $CFG); Fin $false }
$cfgObj = $null
try { $cfgObj = Get-Content -LiteralPath $CFG -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { Say ('  *** config does not parse BEFORE the edit : {0}' -f $_.Exception.Message); Fin $false }
$cur = "$($cfgObj.Kestrel.Endpoints.Http.Url)"
Say ('  engine Kestrel:Endpoints:Http:Url = {0}   expected {1}' -f $cur, $OLDURL)
if ($cur -ne $OLDURL) { Say '  *** the value is not what the procedure was written against - STOP, nothing touched'; Fin $false }

Say ''
Say '===== 2  backup first - it is the only rollback ====='
$beforeBytes = [IO.File]::ReadAllBytes($CFG)
$beforeSha = (Get-FileHash -LiteralPath $CFG -Algorithm SHA256).Hash.ToUpper()
Say ('  size before {0} bytes   sha256 {1}' -f $beforeBytes.Length, $beforeSha)
Say ('  first three bytes : {0:X2} {1:X2} {2:X2}' -f $beforeBytes[0], $beforeBytes[1], $beforeBytes[2])
Copy-Item -LiteralPath $CFG -Destination $bak -Force
if (-not (Test-Path -LiteralPath $bak)) { Say '  *** backup was not created - refusing to edit'; Fin $false }
$bakSha = (Get-FileHash -LiteralPath $bak -Algorithm SHA256).Hash.ToUpper()
Say ('  backup : {0}' -f $bak)
Say ('  backup sha256 {0}   identical to original -> {1}' -f $bakSha, ($bakSha -eq $beforeSha))
if ($bakSha -ne $beforeSha) { Say '  *** the backup is not a copy - refusing to edit'; Fin $false }

Say ''
Say '===== 3  the targeted edit - one value, no re-serialisation ====='
$text = [IO.File]::ReadAllText($CFG, [Text.Encoding]::UTF8)
$matches = ([regex]::Matches($text, [regex]::Escape($OLDURL))).Count
Say ('  occurrences of {0} in the file : {1}   expected 1' -f $OLDURL, $matches)
if ($matches -eq 0) {
    Say '  *** ZERO matches. A replacement that changes nothing and reports success is how a service is'
    Say '  *** quietly left on the old port. Nothing was written; the file is untouched.'
    Fin $false
}
if ($matches -gt 1) {
    Say '  *** more than one occurrence - the procedure names ONE value; I will not guess which.'
    Say '  *** Nothing was written. Bring this to the coordinator.'
    Fin $false
}
$newText = $text.Replace($OLDURL, $NEWURL)
$hadBom = (($beforeBytes[0] -eq 0xEF) -and ($beforeBytes[1] -eq 0xBB) -and ($beforeBytes[2] -eq 0xBF))
[IO.File]::WriteAllText($CFG, $newText, (New-Object Text.UTF8Encoding($hadBom)))
Say ('  written. BOM preserved as it was : {0}' -f $hadBom)

Say ''
Say '===== 4  byte verification - not "it looks right" ====='
$afterBytes = [IO.File]::ReadAllBytes($CFG)
$afterSha = (Get-FileHash -LiteralPath $CFG -Algorithm SHA256).Hash.ToUpper()
$delta = $afterBytes.Length - $beforeBytes.Length
Say ('  size after {0} bytes   delta {1}   expected 0 (8088 and 8089 are the same length)' -f $afterBytes.Length, $delta)
Say ('  sha256 after {0}   changed -> {1}   expected True' -f $afterSha, ($afterSha -ne $beforeSha))
Say ('  first three bytes : {0:X2} {1:X2} {2:X2}' -f $afterBytes[0], $afterBytes[1], $afterBytes[2])
$nul = 0
foreach ($b in $afterBytes) { if ($b -eq 0) { $nul++ } }
Say ('  NUL bytes : {0}   expected 0' -f $nul)
$ok = (($delta -eq 0) -and ($afterSha -ne $beforeSha) -and ($nul -eq 0))
$parsed = $null
try { $parsed = Get-Content -LiteralPath $CFG -Raw -Encoding UTF8 | ConvertFrom-Json }
catch { Say ('  *** the file no longer parses : {0}' -f $_.Exception.Message); $ok = $false }
if ($null -ne $parsed) {
    $now = "$($parsed.Kestrel.Endpoints.Http.Url)"
    Say ('  Kestrel:Endpoints:Http:Url = {0}   expected {1}' -f $now, $NEWURL)
    if ($now -ne $NEWURL) { $ok = $false }
    Say '  (no other key of this file is printed - it carries machine secrets)'
}
if (-not $ok) {
    Say '  *** verification failed - restoring from the backup now'
    Copy-Item -LiteralPath $bak -Destination $CFG -Force
    $restSha = (Get-FileHash -LiteralPath $CFG -Algorithm SHA256).Hash.ToUpper()
    Say ('  restored sha256 {0}   equals original -> {1}' -f $restSha, ($restSha -eq $beforeSha))
    Restore-Line
    Fin $false
}

Say ''
Say '===== 5  state after D1, and what is NOT done ====='
Say '  The running engine still listens on 8088: a config file is read at START-UP.'
Say '  D2 (restart RTMService, then RTMTwilio_1 by the invariant) is a SEPARATE move and is not done here.'
Say '  The Shell is not touched by this run at all.'
foreach ($s in @('RTMService','RTMTwilio_1','RTMViewShell')) {
    foreach ($pr in @(Get-WmiObject Win32_Service -Filter ("Name='" + $s + "'") -ErrorAction SilentlyContinue)) {
        if ($pr.ProcessId -gt 0) {
            $po = Get-Process -Id $pr.ProcessId -ErrorAction SilentlyContinue
            if ($po) { Say ('  {0,-14} pid {1,-7} started {2}' -f $s, $pr.ProcessId, $po.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
        }
    }
}
Restore-Line
Fin $true
