#Requires -Version 5.1
<#
  PROBE 234 / C4 - provenance of what ACTUALLY LANDED, and proof that the update happened.
  WHERE IT RUNS : server 234 (machine RTM). Name and hardware UUID are a gate.
  WHAT IT DOES  : READS. It opens assemblies as bytes, reads service and file metadata, and counts
                  files. It installs nothing, restarts nothing, stops nothing, writes no config,
                  deletes nothing, contacts no database, asks for no password. It does not touch
                  C:\IceDash, the production RTM.Twilio service, legacy RTM, PostgreSQL on either port,
                  or C:\Program Files\CcDashboard. Only write: its own report.
  WHY THE .dll AND NOT THE .exe : for a self-contained .NET publish the .exe is an apphost stub - all
                  three of ours are exactly 151552 bytes, which is the stub, not the code. The managed
                  assembly is the .dll beside it, and that is where the PDB path lives.
  THE PREDICATE : three lines per binary.
                  ProductVersion       - accompanies. A stamp, and stamps can be wrong.
                  PDB compilation root - proves WHOSE binary this is. It is written into the assembly
                                         by the compiler and names the directory it was built in.
                  sha256               - proves its exact composition.
                  All three together, never one alone. This is the rule that cost a day to learn.
  SEARCH METHOD : decode each file ONCE per encoding and call IndexOf. A per-byte loop over a PE file is
                  a million iterations and hung an earlier run - the tool must fit the task.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir   = 'C:\RTMView-Ops\output'
$SENTINEL = -999
$OURBUILD = 'RTMView-build-243424e'
$OURADAPT = 'RTMView-adapters-wt'
$LEGACY   = 'Dropbox'

$TARGETS = @(
    [pscustomobject]@{ Svc='RTMService';   Dir='C:\RTMView\RTM';        Dll='C:\RTMView\RTM\RTM.dll';                  Exe='C:\RTMView\RTM\RTM.exe';                  Expect=$OURBUILD },
    [pscustomobject]@{ Svc='RTMViewShell'; Dir='C:\RTMView\Shell';      Dll='C:\RTMView\Shell\CcDashboard.Web.dll';    Exe='C:\RTMView\Shell\CcDashboard.Web.exe';    Expect=$OURBUILD },
    [pscustomobject]@{ Svc='RTMTwilio_1';  Dir='C:\RTMView\RTM.Twilio'; Dll='C:\RTMView\RTM.Twilio\RTM.Twilio.dll';    Exe='C:\RTMView\RTM.Twilio\RTM.Twilio.exe';    Expect=$OURADAPT }
)

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_c4-provenance.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound - read the three roots above)' }
                       else        { 'VERDICT: FAIL (instrument unsound)' }))
    Flush
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Safe-Count($c) { if ($null -eq $c) { return $SENTINEL } return @($c).Count }

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
Say ('  assignment gate : unassigned {0} (want {1})' -f (Safe-Count $null), $SENTINEL)
if ((Safe-Count $null) -ne $SENTINEL) { Say '  *** gate broken'; Fin $false }
Say ('  now : {0}   READ ONLY' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  expected root, engine and shell : ...{0}...' -f $OURBUILD)
Say ('  expected root, adapter          : ...{0}...' -f $OURADAPT)
Say ('  a root containing "{0}" would mean a LEGACY binary and is a failure' -f $LEGACY)

$allOk = $true
foreach ($t in $TARGETS) {
    Say ''
    Say ('===== {0} =====' -f $t.Svc)
    if (-not (Test-Path -LiteralPath $t.Dll)) { Say ('  *** managed assembly not found : {0}' -f $t.Dll); $allOk = $false; continue }
    $fi = Get-Item -LiteralPath $t.Dll
    Say ('  assembly : {0}' -f $t.Dll)
    Say ('  bytes {0}   mtime {1}' -f $fi.Length, $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    Say ('  sha256 {0}' -f (Get-FileHash -LiteralPath $t.Dll -Algorithm SHA256).Hash.ToUpper())
    Say ('  ProductVersion (assembly) : {0}' -f $fi.VersionInfo.ProductVersion)
    if (Test-Path -LiteralPath $t.Exe) {
        $ei = Get-Item -LiteralPath $t.Exe
        Say ('  apphost exe : {0} bytes   mtime {1}   ProductVersion {2}' -f $ei.Length, $ei.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $ei.VersionInfo.ProductVersion)
    }
    $bytes = [IO.File]::ReadAllBytes($t.Dll)
    $asA = [Text.Encoding]::ASCII.GetString($bytes)
    $idx = $asA.IndexOf('.pdb', [StringComparison]::OrdinalIgnoreCase)
    $root = '(none found)'
    if ($idx -ge 0) {
        $from = [Math]::Max(0, $idx - 220)
        $chunk = $asA.Substring($from, [Math]::Min(230, $asA.Length - $from))
        $cand = @(($chunk -split '[^\x20-\x7E]') | Where-Object { $_ -match '(?i)\.pdb' })
        if ((Safe-Count $cand) -gt 0) { $root = $cand[0] }
    }
    Say ('  PDB compilation root : {0}' -f $root)
    $isOurs   = ($root -like ('*' + $t.Expect + '*'))
    $isLegacy = ($root -like ('*' + $LEGACY + '*'))
    Say ('  matches expected root : {0}   contains "{1}" : {2}' -f $isOurs, $LEGACY, $isLegacy)
    if ((-not $isOurs) -or $isLegacy) { $allOk = $false }
    $files = @(Get-ChildItem -LiteralPath $t.Dir -Recurse -File -ErrorAction SilentlyContinue)
    Say ('  files in install dir : {0}' -f (Safe-Count $files))
    $newest = @($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    foreach ($n in $newest) { Say ('  newest file there    : {0}   {1}' -f $n.Name, $n.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) }
    $svc = Get-Service -Name $t.Svc -ErrorAction SilentlyContinue
    Say ('  service state : {0}' -f $(if ($svc) { $svc.Status } else { 'NOT FOUND' }))
    foreach ($pr in @(Get-WmiObject Win32_Service -Filter ("Name='" + $t.Svc + "'") -ErrorAction SilentlyContinue)) {
        if ($pr.ProcessId -gt 0) {
            $po = Get-Process -Id $pr.ProcessId -ErrorAction SilentlyContinue
            if ($po) { Say ('  pid {0} started {1}   <- T1 for this service' -f $pr.ProcessId, $po.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
        }
    }
}
Flush

Say ''
Say '===== content anchors - hash proves what was placed, an anchor proves it was WHOLE ====='
$anchors = @(
    [pscustomobject]@{ File='C:\RTMView\RTM\RTM.dll';               Needle='AddGridConnection: union ' },
    [pscustomobject]@{ File='C:\RTMView\RTM\RTM.dll';               Needle='refreshUnions Add' },
    [pscustomobject]@{ File='C:\RTMView\RTM.Twilio\RTM.Twilio.dll'; Needle='CLIENT[' }
)
foreach ($a in $anchors) {
    if (-not (Test-Path -LiteralPath $a.File)) { Say ('  {0} : file absent' -f $a.File); continue }
    $b = [IO.File]::ReadAllBytes($a.File)
    $u = [Text.Encoding]::Unicode.GetString($b)
    $s = [Text.Encoding]::ASCII.GetString($b)
    $where = 'no'
    if ($u.IndexOf($a.Needle, [StringComparison]::Ordinal) -ge 0) { $where = 'UTF16' }
    elseif ($s.IndexOf($a.Needle, [StringComparison]::Ordinal) -ge 0) { $where = 'ASCII' }
    Say ('  {0,-46} literal "{1}" : {2}' -f [IO.Path]::GetFileName($a.File), $a.Needle, $where)
}
$negNeedle = 'ZZZ-this-literal-cannot-be-in-any-assembly-ZZZ'
$bn = [IO.File]::ReadAllBytes('C:\RTMView\RTM\RTM.dll')
$un = [Text.Encoding]::Unicode.GetString($bn)
$sn = [Text.Encoding]::ASCII.GetString($bn)
$negFound = (($un.IndexOf($negNeedle, [StringComparison]::Ordinal) -ge 0) -or ($sn.IndexOf($negNeedle, [StringComparison]::Ordinal) -ge 0))
Say ('  NEGCTL impossible literal found : {0}   expected False' -f $negFound)
if ($negFound) { Say '  *** the matcher finds things that are not there'; Fin $false }

Say ''
Say '===== proof that the update HAPPENED, not merely that files exist ====='
$pre = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue)
Say ('  backup folders now : {0}   (at C0, preinstall_* was 0 - a NEW folder is the proof)' -f (Safe-Count $pre))
foreach ($b in @($pre | Sort-Object LastWriteTime -Descending | Select-Object -First 6)) {
    $n = Safe-Count @(Get-ChildItem -LiteralPath $b.FullName -Recurse -File -ErrorAction SilentlyContinue)
    Say ('      {0,-40} {1}   {2} files' -f $b.Name, $b.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $n)
}
$r4 = Safe-Count @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup\rtmtwilio_aa19743_20260913_011524' -Recurse -File -ErrorAction SilentlyContinue)
Say ('  R4 rollback base : {0} files   expected 357, must not be deleted' -f $r4)

Say ''
Say '===== liveness by the PAIR - /health alone is a false criterion ====='
$pipes = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) })
Say ('  named pipes visible : {0}   (zero would mean a blind instrument)' -f (Safe-Count $pipes))
Say ('  rtmpipe_v3 present  : {0}   expected True' -f ($pipes -contains 'rtmpipe_v3'))
foreach ($u in @('http://127.0.0.1:5000/health','https://127.0.0.1:8444/health')) {
    try {
        $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 8
        Say ('  {0} -> HTTP {1}' -f $u, $r.StatusCode)
    } catch { Say ('  {0} -> no answer : {1}' -f $u, $_.Exception.Message) }
}

Say ''
Say '===== what this settles ====='
Say '  Settles: whose binaries are installed, their exact composition, that the fix literals are inside'
Say '  them, that a new backup folder appeared, and that the pipe is up.'
Say '  Does NOT settle: whether the fixes WORK. That is the acceptance run, and it belongs to shell.'
Fin $allOk
