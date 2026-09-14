#Requires -Version 5.1
<#
  PROBE 234 / C0 v2 - ONE bundle arrives, this unpacks it, proves every piece by sha256, and records
  the pre-install baseline. Still no install.
  WHERE IT RUNS : server 234 (machine RTM). Name and hardware UUID are a gate.
  WHAT IT WRITES: it EXPANDS the bundle into C:\RTMView-Ops\incoming\step5b_243424e\ and writes its own
                  report. It installs nothing, restarts nothing, stops nothing, edits no config, deletes
                  nothing, queries no database, asks for no password. It does not touch C:\IceDash, the
                  production RTM.Twilio service, legacy RTM, PostgreSQL 15 on 5432,
                  C:\Program Files\CcDashboard, or machine 140.
  WHY THE HASHES: between the build machine and this one lies a transfer, and now also a zip and an
                  unzip - three places where a file can arrive different. Each artifact is proven by
                  sha256 AFTER extraction, against the numbers the build printed.
  IF THE TARGET FOLDER ALREADY EXISTS it is NOT deleted and NOT overwritten blindly: the run stops and
  says so. Silently overwriting a folder is how a half-transferred payload becomes invisible.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir   = 'C:\RTMView-Ops\output'
$InDir    = 'C:\RTMView-Ops\incoming'
$BUNDLE   = 'C:\RTMView-Ops\incoming\step5b_243424e.zip'
$DEST     = 'C:\RTMView-Ops\incoming\step5b_243424e'
$SENTINEL = -999

$EXPECT = @(
    [pscustomobject]@{ Rel = '13092026.1653_RTM.zip';                 Bytes = 77823467; Sha = '7A25E17195BC85CFA35068D959E95C82CE18F0C74EC85F0F86DB30F175DC7607' },
    [pscustomobject]@{ Rel = '13092026.1654_Shell.zip';               Bytes = 55709284; Sha = '2DE008B727F065765CB515B6B3F3D48301B34CF509DF796D4D76F177A3C68C51' },
    [pscustomobject]@{ Rel = 'twilio_8d28531\RTM.Twilio.exe';         Bytes = 151552;   Sha = 'CC124AC26C6D27037E424987AFF105BA03C1371789E5FE9C901E73F24BC2850E' }
)

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_c0v2-unpack.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS - every artifact proven by sha256; install may proceed' }
                       else        { 'VERDICT: FAIL - do NOT install' }))
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
Say ('  assignment gate : unassigned {0} (want {1}) , two {2} (want 2)' -f (Safe-Count $null), $SENTINEL, (Safe-Count @('a','b')))
if ((Safe-Count $null) -ne $SENTINEL) { Say '  *** gate broken'; Fin $false }
Say ('  NEGCTL Test-Path on a file that cannot exist : {0}   expected False' -f (Test-Path -LiteralPath (Join-Path $InDir 'ZZZ-cannot-exist-ZZZ.zip')))
Say ('  now : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

Say ''
Say '===== 1  the bundle ====='
if (-not (Test-Path -LiteralPath $BUNDLE)) {
    Say ('  *** bundle NOT present : {0}' -f $BUNDLE)
    Say '  Transfer it first. Nothing else was done.'
    Fin $false
}
$bi = Get-Item -LiteralPath $BUNDLE
$bh = (Get-FileHash -LiteralPath $BUNDLE -Algorithm SHA256).Hash.ToUpper()
Say ('  {0}' -f $BUNDLE)
Say ('  bytes {0}   written {1}' -f $bi.Length, $bi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  sha256 {0}' -f $bh)
Say '  (compare this line with the sha the packing box printed on the workstation - same file or not)'

Say ''
Say '===== 2  extraction, or verification IN PLACE if the payload is already here ====='
$extracted = $false
if (Test-Path -LiteralPath $DEST) {
    $had = Safe-Count @(Get-ChildItem -LiteralPath $DEST -Recurse -File -ErrorAction SilentlyContinue)
    Say ('  target already exists and holds {0} files : {1}' -f $had, $DEST)
    Say '  NOT deleting it, NOT merging into it, NOT extracting over it. Instead the artifacts already'
    Say '  there are proven by sha256 below, exactly as they would be after an extraction. If they all'
    Say '  match the build-time numbers, how they arrived does not matter - the hash is the proof.'
    Say '  If any does not match, remove or rename this folder and re-run; do not patch it by hand.'
} else {
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        [IO.Compression.ZipFile]::ExtractToDirectory($BUNDLE, $DEST)
        $extracted = $true
        Say ('  extracted to : {0}' -f $DEST)
    } catch {
        Say ('  *** extraction failed : {0}' -f $_.Exception.Message)
        Fin $false
    }
}
$all = @(Get-ChildItem -LiteralPath $DEST -Recurse -File -ErrorAction SilentlyContinue)
Say ('  extraction performed by this run : {0}' -f $extracted)
Say ('  files present under the target   : {0}' -f (Safe-Count $all))

Say ''
Say '===== 3  every artifact proven by sha256 - expectation printed BEFORE the measurement ====='
$allOk = $true
foreach ($e in $EXPECT) {
    $p = Join-Path $DEST $e.Rel
    Say ''
    Say ('  --- {0} ---' -f $e.Rel)
    Say ('      expected bytes  : {0}' -f $e.Bytes)
    Say ('      expected sha256 : {0}' -f $e.Sha)
    if (-not (Test-Path -LiteralPath $p)) { Say '      *** NOT FOUND after extraction'; $allOk = $false; continue }
    $fi = Get-Item -LiteralPath $p
    $h  = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToUpper()
    $okB = ($fi.Length -eq $e.Bytes)
    $okH = ($h -eq $e.Sha.ToUpper())
    Say ('      measured bytes  : {0}   match {1}' -f $fi.Length, $okB)
    Say ('      measured sha256 : {0}   match {1}' -f $h, $okH)
    if (-not ($okB -and $okH)) { $allOk = $false }
}
$adir = Join-Path $DEST 'twilio_8d28531'
$l4 = Join-Path $adir 'log4net.config'
$acnt = Safe-Count @(Get-ChildItem -LiteralPath $adir -Recurse -File -ErrorAction SilentlyContinue)
Say ''
Say ('  adapter payload files : {0}' -f $acnt)
Say ('  log4net.config present : {0}   expected True (this is the whole reason aa19743 exists)' -f (Test-Path -LiteralPath $l4))
if (-not (Test-Path -LiteralPath $l4)) { $allOk = $false }
Flush

Say ''
Say '===== 4  PRE-INSTALL BASELINE - what will later prove the update HAPPENED ====='
$targets = @(
    [pscustomobject]@{ Svc = 'RTMService';   Dir = 'C:\RTMView\RTM';        Exe = 'C:\RTMView\RTM\RTM.exe' },
    [pscustomobject]@{ Svc = 'RTMViewShell'; Dir = 'C:\RTMView\Shell';      Exe = 'C:\RTMView\Shell\CcDashboard.Web.exe' },
    [pscustomobject]@{ Svc = 'RTMTwilio_1';  Dir = 'C:\RTMView\RTM.Twilio'; Exe = 'C:\RTMView\RTM.Twilio\RTM.Twilio.exe' }
)
foreach ($t in $targets) {
    Say ''
    Say ('  --- {0} ---' -f $t.Svc)
    $svc = Get-Service -Name $t.Svc -ErrorAction SilentlyContinue
    Say ('      service state : {0}' -f $(if ($svc) { $svc.Status } else { 'NOT FOUND' }))
    foreach ($pr in @(Get-WmiObject Win32_Service -Filter ("Name='" + $t.Svc + "'") -ErrorAction SilentlyContinue)) {
        if ($pr.ProcessId -gt 0) {
            $po = Get-Process -Id $pr.ProcessId -ErrorAction SilentlyContinue
            if ($po) { Say ('      pid {0} started {1}   <- T0; every install restart T1 must be LATER' -f $pr.ProcessId, $po.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
        }
    }
    if (Test-Path -LiteralPath $t.Exe) {
        $ei = Get-Item -LiteralPath $t.Exe
        Say ('      exe bytes {0}   mtime {1}' -f $ei.Length, $ei.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        Say ('      exe sha256 {0}' -f (Get-FileHash -LiteralPath $t.Exe -Algorithm SHA256).Hash.ToUpper())
        Say ('      ProductVersion {0}' -f $ei.VersionInfo.ProductVersion)
    } else { Say '      *** exe not found' }
    $files = @(Get-ChildItem -LiteralPath $t.Dir -Recurse -File -ErrorAction SilentlyContinue)
    Say ('      files in directory : {0}' -f (Safe-Count $files))
    foreach ($n in @($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1)) {
        Say ('      newest file there  : {0}   {1}' -f $n.Name, $n.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    }
}

Say ''
Say '===== 5  backups and liveness ====='
$pre = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'preinstall_*' })
Say ('  preinstall_* folders now : {0}   (a NEW one after the install is part of the proof)' -f (Safe-Count $pre))
$r4 = Safe-Count @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup\rtmtwilio_aa19743_20260913_011524' -Recurse -File -ErrorAction SilentlyContinue)
Say ('  R4 rollback base : {0} files   expected 357, MUST NOT be deleted' -f $r4)
$pipes = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) })
Say ('  named pipes visible : {0}   (zero would mean a blind instrument, not a dead system)' -f (Safe-Count $pipes))
Say ('  rtmpipe_v3 present  : {0}   expected True' -f ($pipes -contains 'rtmpipe_v3'))

Say ''
Say '===== verdict ====='
Say ('  every artifact matches its build-time sha256 : {0}' -f $allOk)
Say '  A mismatch here is the transfer or the zip, never the build. Repeat it; install nothing.'
Fin $allOk
