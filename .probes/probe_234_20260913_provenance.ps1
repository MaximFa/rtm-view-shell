#Requires -Version 5.1
<#
  PROBE 234 / provenance      WHICH BUILD IS ACTUALLY INSTALLED - by the bytes, not by the stamp.
  WHERE IT RUNS : server 234 (machine RTM). Machine name AND hardware UUID are a gate; it refuses to run
                  anywhere else. READ ONLY: restarts nothing, stops nothing, writes no config, deletes
                  nothing, queries no database, prompts for no password, and OPENS NO CONFIG FILE AT ALL.
                  C:\IceDash is never read or listed. Its only write is its own report.

  WHY THIS RUN EXISTS. The deployed engine throws KeyNotFoundException from a ConcurrentDictionary
  INDEXER inside Engine.AddGridConnection, with the frame pointing at
  C:\Users\user\Dropbox\Code\RTM\RTM\Engine.cs:line 2576. In b4ad301 - which the binary stamps as its
  ProductVersion - that method is at line 2108 and uses TryGetValue, which cannot throw that exception;
  the indexer guard landed in 803832a on 2026-06-07 and is an ancestor of both b4ad301 and v3. So the
  running engine is built from code OLDER than the stamp claims, on a machine that is not ours.
  Therefore ProductVersion is not a predicate for "what is installed" - it can be carried without the
  code. This probe replaces it with something that cannot be carried: the SOURCE ROOT baked into each
  assembly, read as BYTES, printed per file, beside the sha256.

  THE THREE CANDIDATE ROOTS, and why the third one matters [coordinator, 13:2x]:
      C:\Users\user\Dropbox\Code\RTM   - a foreign tree; this is what the engine frame shows
      D:\Claude\Build                  - our build machine, the general form
      rtm_clean_20260908_101212        - our build clone of 08.09 specifically
  Without the third, a file that is neither Dropbox nor a generic D:\Claude\Build path would read as
  "ours" by elimination, and that is a third case wearing the clothes of a conclusion. Each root is
  searched in BOTH ASCII and UTF-16LE, because a path can be stored either way inside a PE file, and a
  single-encoding search would produce an honest zero for the wrong reason.

  WHAT IS PRINTED, per file and in this order: the ROOT found (the decisive field, first), then
  ProductVersion and sha256 side by side so that "right stamp, wrong bytes" is visible as one line
  instead of a manual comparison, then size and write time so the arrival can be dated.

  CONTROLS:
    assignment gate - counts go through Safe-Count, which returns -999 for an unassigned value rather
                      than 0, self-tested on three inputs before anything is measured
    POSCTL          - at least one file must carry one of the three roots; zero everywhere would mean the
                      byte search is broken, not that every build is anonymous
    NEGCTL          - a root that cannot exist must be found in 0 files
    the assemblies that matter most are printed FIRST by name (RTM.exe / RTM.dll carry Engine.cs), so the
    decisive line is not buried under three hundred dependency DLLs
  Nothing here can leak a secret: no config, no connection string, no key is read. Only PE files and
  their hashes.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$SENTINEL = -999

$ROOTS = @(
    @{ Tag = 'FOREIGN-DROPBOX'; Needle = 'Dropbox\Code\RTM' },
    @{ Tag = 'OURS-CLEAN0908';  Needle = 'rtm_clean_20260908_101212' },
    @{ Tag = 'OURS-BUILD';      Needle = 'D:\Claude\Build' }
)
$NEGROOT = 'ZZZ-no-such-build-root-ZZZ'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_provenance.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function SayFileOnly($text) { [void]$Report.Add($text) }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound)' } else { 'VERDICT: FAIL (instrument unsound - numbers are not evidence)' }))
    Flush
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Safe-Count($collection) {
    if ($null -eq $collection) { return $SENTINEL }
    return @($collection).Count
}
function Find-Root($bytes, $needle) {
    # search the needle in BOTH ASCII and UTF-16LE: a PE file may store a path either way
    $ascii = [Text.Encoding]::ASCII.GetBytes($needle)
    $wide  = [Text.Encoding]::Unicode.GetBytes($needle)
    foreach ($pat in @($ascii, $wide)) {
        $limit = $bytes.Length - $pat.Length
        if ($limit -lt 0) { continue }
        for ($i = 0; $i -le $limit; $i++) {
            if ($bytes[$i] -ne $pat[0]) { continue }
            $hit = $true
            for ($k = 1; $k -lt $pat.Length; $k++) {
                if ($bytes[$i + $k] -ne $pat[$k]) { $hit = $false; break }
            }
            if ($hit) { return $true }
        }
    }
    return $false
}

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
foreach ($h in @('Safe-Count','Find-Root')) {
    $rr = Get-Command $h -ErrorAction SilentlyContinue
    Say ('  {0} resolves to {1}   expected Function' -f $h, $rr.CommandType)
    if ("$($rr.CommandType)" -ne 'Function') { Say '  *** helper shadowed - stop'; Fin $false }
}
$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('  assignment gate : unassigned {0} (want {1}) , empty {2} (want 0) , two {3} (want 2)' -f $gA, $SENTINEL, $gB, $gC)
if (-not (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2))) { Say '  *** gate broken'; Fin $false }
Say '  --- Find-Root self-test, on bytes I build here, so the matcher is proven before it is trusted ---'
$probeAscii = [Text.Encoding]::ASCII.GetBytes('xx' + $ROOTS[0].Needle + 'yy')
$probeWide  = [Text.Encoding]::Unicode.GetBytes('xx' + $ROOTS[0].Needle + 'yy')
$probeNone  = [Text.Encoding]::ASCII.GetBytes('nothing of interest here')
Say ('  ASCII  sample -> {0}   expected True'  -f (Find-Root $probeAscii $ROOTS[0].Needle))
Say ('  UTF16  sample -> {0}   expected True'  -f (Find-Root $probeWide  $ROOTS[0].Needle))
Say ('  absent sample -> {0}   expected False' -f (Find-Root $probeNone  $ROOTS[0].Needle))
$selfOk = ((Find-Root $probeAscii $ROOTS[0].Needle) -and (Find-Root $probeWide $ROOTS[0].Needle) -and (-not (Find-Root $probeNone $ROOTS[0].Needle)))
Say ('  matcher self-test : {0}   expected True' -f $selfOk)
if (-not $selfOk) { Say '  *** the byte matcher is broken - measuring nothing'; Fin $false }
Say ('  now : {0}   READ ONLY - no config file is opened by this probe at all' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Flush

Say ''
Say '===== 1  the three install directories, DISCOVERED from the service manager ====='
$dirs = New-Object System.Collections.ArrayList
foreach ($svcName in @('RTMService','RTMTwilio_1')) {
    $svc = Get-WmiObject Win32_Service -Filter ("Name='" + $svcName + "'") -ErrorAction SilentlyContinue
    if (-not $svc) { Say ('  {0} : NOT FOUND' -f $svcName); continue }
    $exe = "$($svc.PathName)".Trim()
    if ($exe.StartsWith('"')) { $exe = $exe.Substring(1, $exe.IndexOf('"', 1) - 1) }
    else { $q = $exe.IndexOf(' -'); if ($q -gt 0) { $exe = $exe.Substring(0, $q) } }
    $d = [IO.Path]::GetDirectoryName($exe)
    Say ('  {0,-12} -> {1}   state {2}' -f $svcName, $d, $svc.State)
    [void]$dirs.Add([pscustomobject]@{ Tag = $svcName; Dir = $d })
}
$svcShell = @(Get-WmiObject Win32_Service -ErrorAction SilentlyContinue |
              Where-Object { $_.PathName -match '(?i)RTMView\\Shell' }) | Select-Object -First 1
if ($svcShell) {
    $sx = "$($svcShell.PathName)".Trim()
    if ($sx.StartsWith('"')) { $sx = $sx.Substring(1, $sx.IndexOf('"', 1) - 1) }
    else { $q2 = $sx.IndexOf(' -'); if ($q2 -gt 0) { $sx = $sx.Substring(0, $q2) } }
    $sd = [IO.Path]::GetDirectoryName($sx)
    Say ('  {0,-12} -> {1}   state {2}' -f $svcShell.Name, $sd, $svcShell.State)
    [void]$dirs.Add([pscustomobject]@{ Tag = $svcShell.Name; Dir = $sd })
} else { Say '  the Shell service was not found by path RTMView\Shell - not guessing it' }
Say ('  directories : {0}   expected 3' -f (Safe-Count $dirs))
if ((Safe-Count $dirs) -lt 1) { Say '  *** nothing to inspect'; Fin $false }

$FIRST = @('RTM.exe','RTM.dll','CcDashboard.Web.exe','CcDashboard.Web.dll','RTM.Twilio.exe','RTM.Twilio.dll',
           'RTM.Tools.dll','RTM.Adapter.Common.dll','RTM.Configuration.dll')
$rootTally = @{}
$negHits = 0
$anyRoot = 0
$scanned = 0
$foreign = New-Object System.Collections.ArrayList
$anon = New-Object System.Collections.ArrayList

foreach ($entry in $dirs) {
    Say ''
    Say ('===== 2  ' + $entry.Tag + ' : ' + $entry.Dir + ' =====')
    if (-not (Test-Path -LiteralPath $entry.Dir)) { Say '  directory absent'; continue }
    $all = @(Get-ChildItem -LiteralPath $entry.Dir -File -ErrorAction SilentlyContinue |
             Where-Object { $_.Extension -match '(?i)^\.(exe|dll)$' })
    Say ('  exe/dll files : {0}' -f (Safe-Count $all))
    # decisive assemblies first, then the rest
    $ordered = @(@($all | Where-Object { $FIRST -contains $_.Name }) + @($all | Where-Object { $FIRST -notcontains $_.Name }))
    $headerShown = $false
    foreach ($f in $ordered) {
        $scanned++
        $bytes = $null
        try { $bytes = [IO.File]::ReadAllBytes($f.FullName) } catch { }
        $found = New-Object System.Collections.ArrayList
        if ($null -ne $bytes) {
            foreach ($r in $ROOTS) { if (Find-Root $bytes $r.Needle) { [void]$found.Add($r.Tag) } }
            if (Find-Root $bytes $NEGROOT) { $negHits++ }
        }
        $rootStr = $(if ((Safe-Count $found) -eq 0) { 'none' } else { ($found -join '+') })
        if (-not $rootTally.ContainsKey($rootStr)) { $rootTally[$rootStr] = 0 }
        $rootTally[$rootStr] = $rootTally[$rootStr] + 1
        if ((Safe-Count $found) -gt 0) { $anyRoot++ }
        if ($found -contains 'FOREIGN-DROPBOX') { [void]$foreign.Add($entry.Tag + ' : ' + $f.Name) }
        if ((Safe-Count $found) -eq 0) { [void]$anon.Add($entry.Tag + ' : ' + $f.Name) }

        $pv = ''
        try { $pv = "$((Get-Item -LiteralPath $f.FullName).VersionInfo.ProductVersion)" } catch { }
        if ($pv.Length -gt 48) { $pv = $pv.Substring(0, 48) }
        $sha = ''
        try { $sha = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.Substring(0, 16) } catch { }
        $line = ('  {0,-18} {1,-28} {2,-48} {3,-17} {4,10}  {5}' -f `
                 $rootStr, $f.Name, $pv, $sha, $f.Length, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))
        # the decisive ones and anything foreign go to the screen; the long tail goes to the file only
        if (($FIRST -contains $f.Name) -or ($found -contains 'FOREIGN-DROPBOX')) {
            if (-not $headerShown) {
                Say ('  {0,-18} {1,-28} {2,-48} {3,-17} {4,10}  {5}' -f 'ROOT','FILE','PRODUCTVERSION','SHA256(16)','BYTES','WRITTEN')
                $headerShown = $true
            }
            Say $line
        } else {
            SayFileOnly $line
        }
    }
    Flush
}

Say ''
Say '===== 3  tally by source root ====='
foreach ($k in @($rootTally.Keys | Sort-Object)) { Say ('  {0,-24} files {1}' -f $k, $rootTally[$k]) }
Say ('  files scanned : {0}' -f $scanned)
Say ('  POSCTL files carrying ANY known root : {0}   expected > 0, else the byte search is broken' -f $anyRoot)
Say ('  NEGCTL impossible root found in      : {0}   expected 0' -f $negHits)

Say ''
Say '===== 4  every file built in the FOREIGN tree ====='
Say ('  count : {0}' -f (Safe-Count $foreign))
foreach ($x in $foreign) { Say ('      ' + $x) }
if ((Safe-Count $foreign) -eq 0) {
    Say '  none - then the engine frame came from an assembly outside these directories, or the path is'
    Say '  not stored in the PE at all for these builds. Either way I do not convert that into "ours".'
}
Say ''
Say ('  files with NO known root (the third case - neither foreign nor ours) : {0}' -f (Safe-Count $anon))
foreach ($x in @($anon | Select-Object -First 25)) { SayFileOnly ('      ' + $x) }
Say '  their names are in the report file. Most will be third-party dependencies, which carry no root of'
Say '  ours by nature - so this bucket is NOT evidence by itself, only a list to read.'

Say ''
Say '===== verdict - on MY instrument only ====='
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Write-Host '*** collector clobbered'; exit 1 }
Say ('  matcher self-test True ; files {0} ; POSCTL {1} ; NEGCTL {2}' -f $scanned, $anyRoot, $negHits)
Fin (($negHits -eq 0) -and ($anyRoot -gt 0))
