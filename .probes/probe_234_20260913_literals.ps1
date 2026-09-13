#Requires -Version 5.1
<#
  PROBE 234 / literals      IS THE FIX IN THE DEPLOYED BINARY - asked of the binary itself. READ ONLY.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate. Restarts nothing,
                  writes no config, opens no config, queries no database, deletes nothing, prompts for no
                  password. C:\IceDash is never touched. Only write: its own report. Runs in seconds.

  TWO DEFECTS OF MINE THAT THIS RUN REPLACES, both named before any number.
  1. THE PREVIOUS PROBE HUNG, and that was my choice of instrument, not the machine: I searched bytes with
     a per-byte PowerShell loop - roughly a million iterations per file across a thousand files. Here each
     file is decoded ONCE per encoding and searched with IndexOf, which is a single framework call.
  2. ITS MATCHER WAS TOO COARSE FOR THE CLAIM I MADE WITH IT. "The path string occurs somewhere in the
     file" is not "this is the compilation root", and I presented the first as if it were the second. So
     I WITHDRAW, as unconfirmed, my statement that the deployed engine is a foreign build. What the
     partial output did establish is narrower: RTM.dll carries our build path, RTM.exe carries none - and
     RTM.exe is the apphost, which carries no root by nature, so that zero was never evidence.

  WHAT THIS ASKS INSTEAD, and why it is decisive. Commit 803832a (2026-06-07, ancestor of both b4ad301 and
  v3) replaced a dictionary indexer with TryGetValue in the agent-grid serve path and INTRODUCED A STRING
  that did not exist before it:
        "AddGridConnection: union " ... " not registered (agent grid not nuked)"
  String literals live inside the assembly. So:
        literal PRESENT in RTM.dll  -> the deployed code HAS the fix, and then a KeyNotFoundException from
                                       get_Item inside that method cannot come from this branch; it comes
                                       from somewhere else (an inlined callee), and the subject moves
        literal ABSENT              -> the deployed code is PRE-FIX, the exception is explained exactly,
                                       and the branch never shipped to this server
  This asks the binary, not its version stamp and not a path - neither of which can answer it.

  ALSO MEASURED, because it settles the stack-trace path honestly: the PDB path recorded inside each
  assembly. That single string IS the compilation root, unlike an arbitrary path occurrence, and it tells
  us whether C:\Users\user\Dropbox\Code\RTM came from the binary or from a stale PDB lying beside it.
  Plus whether a matching .pdb file exists next to the assembly, and when it was written.

  CONTROLS
    assignment gate : Safe-Count returns -999 for an unassigned value, self-tested on three inputs
    POSCTL per file : a literal that MUST be present in both versions - "In use" - anchors the search;
                      if that is absent too, the search is blind and no absence below is a finding
    NEGCTL          : a literal that cannot exist must be found 0 times
    Each answer is printed per file with the encoding that matched, so a zero can be told apart from a
    zero in the wrong encoding.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$SENTINEL = -999

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_literals.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound)' }))
    [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Safe-Count($collection) {
    if ($null -eq $collection) { return $SENTINEL }
    return @($collection).Count
}
# one decode per encoding, then IndexOf - no per-byte loop anywhere in this probe
function Find-Literal($asUnicode, $asAscii, $needle) {
    if ($asUnicode.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) { return 'UTF16' }
    if ($asAscii.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) { return 'ASCII' }
    return 'no'
}

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
foreach ($h in @('Safe-Count','Find-Literal')) {
    $rr = Get-Command $h -ErrorAction SilentlyContinue
    Say ('  {0} resolves to {1}   expected Function' -f $h, $rr.CommandType)
    if ("$($rr.CommandType)" -ne 'Function') { Say '  *** helper shadowed'; Fin $false }
}
$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('  assignment gate : unassigned {0} (want {1}) , empty {2} , two {3}' -f $gA, $SENTINEL, $gB, $gC)
if (-not (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2))) { Say '  *** gate broken'; Fin $false }
$tu = [Text.Encoding]::Unicode.GetString([Text.Encoding]::Unicode.GetBytes('alpha MARKER-OK beta'))
$ta = [Text.Encoding]::ASCII.GetString([Text.Encoding]::ASCII.GetBytes('alpha MARKER-OK beta'))
Say ('  Find-Literal self-test : present in UTF16 -> {0} (want UTF16)' -f (Find-Literal $tu 'zzz' 'MARKER-OK'))
Say ('  Find-Literal self-test : present in ASCII -> {0} (want ASCII)' -f (Find-Literal 'zzz' $ta 'MARKER-OK'))
Say ('  Find-Literal self-test : absent           -> {0} (want no)'    -f (Find-Literal 'zzz' 'zzz' 'MARKER-OK'))
$selfOk = ((Find-Literal $tu 'zzz' 'MARKER-OK') -eq 'UTF16') -and ((Find-Literal 'zzz' $ta 'MARKER-OK') -eq 'ASCII') -and ((Find-Literal 'zzz' 'zzz' 'MARKER-OK') -eq 'no')
Say ('  self-test : {0}   expected True' -f $selfOk)
if (-not $selfOk) { Say '  *** matcher broken - measuring nothing'; Fin $false }
Say ('  now : {0}   READ ONLY, seconds not minutes' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

Say ''
Say '===== 1  the assemblies that decide, DISCOVERED from the service manager ====='
$targets = New-Object System.Collections.ArrayList
foreach ($svcName in @('RTMService','RTMTwilio_1')) {
    $svc = Get-WmiObject Win32_Service -Filter ("Name='" + $svcName + "'") -ErrorAction SilentlyContinue
    if (-not $svc) { Say ('  {0} : NOT FOUND' -f $svcName); continue }
    $exe = "$($svc.PathName)".Trim()
    if ($exe.StartsWith('"')) { $exe = $exe.Substring(1, $exe.IndexOf('"', 1) - 1) }
    else { $q = $exe.IndexOf(' -'); if ($q -gt 0) { $exe = $exe.Substring(0, $q) } }
    $d = [IO.Path]::GetDirectoryName($exe)
    Say ('  {0,-12} -> {1}' -f $svcName, $d)
    foreach ($nm in @('RTM.dll','RTM.exe','RTM.Tools.dll','RTM.Configuration.dll','RTM.Twilio.dll','RTM.Twilio.exe','RTM.Adapter.Common.dll')) {
        $p = Join-Path $d $nm
        if (Test-Path -LiteralPath $p) { [void]$targets.Add($p) }
    }
}
Say ('  assemblies to inspect : {0}   expected >= 2' -f (Safe-Count $targets))
if ((Safe-Count $targets) -lt 1) { Say '  *** nothing to inspect'; Fin $false }

$LITERALS = @(
    @{ Tag = 'FIX-803832a  Warn literal'; Needle = 'AddGridConnection: union ' },
    @{ Tag = 'FIX-803832a  tail'        ; Needle = 'not registered (agent grid not nuked)' },
    @{ Tag = 'FIX  data grid variant'   ; Needle = 'not found after on-demand register' },
    @{ Tag = 'POSCTL both versions'     ; Needle = ' In use' },
    @{ Tag = 'ROOT foreign'             ; Needle = 'Dropbox\Code\RTM' },
    @{ Tag = 'ROOT ours'                ; Needle = 'D:\Claude\Build' },
    @{ Tag = 'ROOT ours 0908 clone'     ; Needle = 'rtm_clean_20260908_101212' },
    @{ Tag = 'NEGCTL impossible'        ; Needle = 'ZZZ-cannot-occur-ZZZ' }
)

$negTotal = 0
$posTotal = 0
foreach ($p in $targets) {
    Say ''
    Say ('===== 2  ' + $p + ' =====')
    $fi = Get-Item -LiteralPath $p
    Say ('  {0} bytes   written {1}' -f $fi.Length, $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    Say ('  ProductVersion {0}' -f $fi.VersionInfo.ProductVersion)
    Say ('  sha256 {0}' -f (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash)
    $bytes = $null
    try { $bytes = [IO.File]::ReadAllBytes($p) } catch { Say ('  *** cannot read : {0}' -f $_.Exception.Message); continue }
    $asU = [Text.Encoding]::Unicode.GetString($bytes)
    $asA = [Text.Encoding]::ASCII.GetString($bytes)
    foreach ($l in $LITERALS) {
        $where = Find-Literal $asU $asA $l.Needle
        Say ('  {0,-28} {1,-6}   [{2}]' -f $l.Tag, $where, $l.Needle)
        if ($l.Tag -eq 'NEGCTL impossible' -and $where -ne 'no') { $negTotal++ }
        if ($l.Tag -eq 'POSCTL both versions' -and $where -ne 'no') { $posTotal++ }
    }
    # the PDB path recorded INSIDE the assembly: the authoritative compilation root
    $pdbIdx = $asA.IndexOf('.pdb', [StringComparison]::OrdinalIgnoreCase)
    if ($pdbIdx -ge 0) {
        $from = [Math]::Max(0, $pdbIdx - 200)
        $chunk = $asA.Substring($from, [Math]::Min(204, $asA.Length - $from))
        $clean = ($chunk -split '[^\x20-\x7E]') | Where-Object { $_ -match '(?i)\.pdb' } | Select-Object -First 1
        Say ('  PDB path recorded in the assembly : {0}' -f $(if ($clean) { $clean } else { '(found .pdb but could not isolate the string)' }))
    } else {
        Say '  PDB path recorded in the assembly : none found'
    }
    $sidecar = [IO.Path]::ChangeExtension($p, '.pdb')
    if (Test-Path -LiteralPath $sidecar) {
        $si = Get-Item -LiteralPath $sidecar
        Say ('  .pdb beside it : YES   {0} bytes   written {1}' -f $si.Length, $si.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    } else {
        Say '  .pdb beside it : no'
    }
}

Say ''
Say '===== 3  controls and what the answer means ====='
Say ('  POSCTL " In use" found in : {0} assemblies   expected > 0, else the search is blind' -f $posTotal)
Say ('  NEGCTL impossible literal : {0}   expected 0' -f $negTotal)
Say '  READING THE RESULT, fixed before the numbers:'
Say '    RTM.dll HAS the 803832a literals  -> the deployed engine carries the fix, and the'
Say '      KeyNotFoundException must come from an inlined callee, not from this branch. My'
Say '      "foreign build" statement stays withdrawn and the subject moves to WHICH callee.'
Say '    RTM.dll LACKS them                -> the deployed engine is PRE-803832a, the exception is fully'
Say '      explained, and the fix has never reached this server.'
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Fin (($negTotal -eq 0) -and ($posTotal -gt 0))
