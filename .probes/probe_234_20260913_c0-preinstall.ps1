#Requires -Version 5.1
<#
  PROBE 234 / C0 - the packages are verified BEFORE anything is installed, and the pre-install
  state is recorded so that "the update happened" can later be PROVEN rather than assumed.
  WHERE IT RUNS : server 234 (machine RTM). Name and hardware UUID are a gate.
  WHAT IT DOES  : READS. It installs nothing, restarts nothing, stops nothing, writes no config,
                  deletes nothing, queries no database, asks for no password. It does not touch
                  C:\IceDash, the production RTM.Twilio service, legacy RTM, PostgreSQL 15 on 5432,
                  C:\Program Files\CcDashboard, or machine 140. Only write: its own report.
  WHY C0 EXISTS : the three sha256 values below come from the BUILD machine. Between that machine and
                  this one lies a transfer - exactly where a file arrives different. A hash is either
                  equal or it is not; "probably fine" is not a state a package can be in.
  GATES         : every expectation is printed BEFORE the measured value. A hash mismatch is a STOP:
                  nothing is installed and the transfer is repeated.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir   = 'C:\RTMView-Ops\output'
$InDir    = 'C:\RTMView-Ops\incoming'
$SENTINEL = -999

$EXPECT = @(
    [pscustomobject]@{ Name = '13092026.1653_RTM.zip';   Bytes = 77823467; Sha = '7A25E17195BC85CFA35068D959E95C82CE18F0C74EC85F0F86DB30F175DC7607' },
    [pscustomobject]@{ Name = '13092026.1654_Shell.zip'; Bytes = 55709284; Sha = '2DE008B727F065765CB515B6B3F3D48301B34CF509DF796D4D76F177A3C68C51' }
)
$EXPADAPTER = [pscustomobject]@{ Rel = 'twilio_8d28531\RTM.Twilio.exe'; Bytes = 151552; Sha = 'CC124AC26C6D27037E424987AFF105BA03C1371789E5FE9C901E73F24BC2850E' }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_c0-preinstall.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS - packages verified, transfer is sound, install may proceed' }
                       else        { 'VERDICT: FAIL - do NOT install; repeat the transfer' }))
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
$g = Safe-Count $null
Say ('  assignment gate : unassigned {0} (want {1}) , two {2} (want 2)' -f $g, $SENTINEL, (Safe-Count @('a','b')))
if ($g -ne $SENTINEL) { Say '  *** gate broken'; Fin $false }
$negFile = Join-Path $InDir 'ZZZ-cannot-exist-ZZZ.zip'
Say ('  NEGCTL Test-Path on a file that cannot exist : {0}   expected False' -f (Test-Path -LiteralPath $negFile))
if (Test-Path -LiteralPath $negFile) { Say '  *** instrument unsound'; Fin $false }
Say ('  now : {0}   READ ONLY, nothing is installed by this run' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))

Say ''
Say '===== 1  THE PACKAGES - expectation printed before the measurement ====='
$allOk = $true
foreach ($e in $EXPECT) {
    $p = Join-Path $InDir $e.Name
    Say ''
    Say ('  --- {0} ---' -f $e.Name)
    Say ('      expected bytes  : {0}' -f $e.Bytes)
    Say ('      expected sha256 : {0}' -f $e.Sha)
    if (-not (Test-Path -LiteralPath $p)) { Say '      *** NOT PRESENT in C:\RTMView-Ops\incoming'; $allOk = $false; continue }
    $fi = Get-Item -LiteralPath $p
    $h  = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToUpper()
    $bytesOk = ($fi.Length -eq $e.Bytes)
    $shaOk   = ($h -eq $e.Sha.ToUpper())
    Say ('      measured bytes  : {0}   match {1}' -f $fi.Length, $bytesOk)
    Say ('      measured sha256 : {0}   match {1}' -f $h, $shaOk)
    Say ('      written         : {0}' -f $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    if (-not ($bytesOk -and $shaOk)) { $allOk = $false }
}
Say ''
Say ('  --- adapter payload : {0} ---' -f $EXPADAPTER.Rel)
$ap = Join-Path $InDir $EXPADAPTER.Rel
Say ('      expected bytes  : {0}' -f $EXPADAPTER.Bytes)
Say ('      expected sha256 : {0}' -f $EXPADAPTER.Sha)
if (Test-Path -LiteralPath $ap) {
    $afi = Get-Item -LiteralPath $ap
    $ah  = (Get-FileHash -LiteralPath $ap -Algorithm SHA256).Hash.ToUpper()
    Say ('      measured bytes  : {0}   match {1}' -f $afi.Length, ($afi.Length -eq $EXPADAPTER.Bytes))
    Say ('      measured sha256 : {0}   match {1}' -f $ah, ($ah -eq $EXPADAPTER.Sha.ToUpper()))
    if (-not (($afi.Length -eq $EXPADAPTER.Bytes) -and ($ah -eq $EXPADAPTER.Sha.ToUpper()))) { $allOk = $false }
    $adir = [IO.Path]::GetDirectoryName($ap)
    $acnt = Safe-Count @(Get-ChildItem -LiteralPath $adir -Recurse -File -ErrorAction SilentlyContinue)
    $l4   = Join-Path $adir 'log4net.config'
    Say ('      files in the payload folder : {0}' -f $acnt)
    Say ('      log4net.config present      : {0}   expected True (this is why aa19743 exists)' -f (Test-Path -LiteralPath $l4))
    if (-not (Test-Path -LiteralPath $l4)) { $allOk = $false }
} else { Say '      *** NOT PRESENT'; $allOk = $false }
Flush

Say ''
Say '===== 2  PRE-INSTALL STATE - the baseline that will later prove the update HAPPENED ====='
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
    $proc = @(Get-WmiObject Win32_Service -Filter ("Name='" + $t.Svc + "'") -ErrorAction SilentlyContinue)
    foreach ($pr in $proc) {
        $pid2 = $pr.ProcessId
        if ($pid2 -gt 0) {
            $po = Get-Process -Id $pid2 -ErrorAction SilentlyContinue
            if ($po) { Say ('      pid {0} started {1}   <- this is T0; T1 must be LATER than it' -f $pid2, $po.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
        }
    }
    if (Test-Path -LiteralPath $t.Exe) {
        $ei = Get-Item -LiteralPath $t.Exe
        $eh = (Get-FileHash -LiteralPath $t.Exe -Algorithm SHA256).Hash.ToUpper()
        $pv = (Get-Item -LiteralPath $t.Exe).VersionInfo.ProductVersion
        Say ('      exe bytes {0}   mtime {1}' -f $ei.Length, $ei.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
        Say ('      exe sha256 {0}' -f $eh)
        Say ('      ProductVersion {0}' -f $pv)
    } else { Say '      *** exe not found' }
    $files = @(Get-ChildItem -LiteralPath $t.Dir -Recurse -File -ErrorAction SilentlyContinue)
    Say ('      files in directory : {0}' -f (Safe-Count $files))
    $newest = @($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    foreach ($n in $newest) { Say ('      newest file there  : {0}   {1}' -f $n.Name, $n.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) }
}

Say ''
Say '===== 3  BACKUP FOLDERS - a NEW one appearing is part of the proof that the installer ran ====='
$bdir = 'C:\RTMView\Backup'
$pre = @(Get-ChildItem -LiteralPath $bdir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'preinstall_*' })
Say ('  preinstall_* folders now : {0}' -f (Safe-Count $pre))
foreach ($b in @($pre | Sort-Object LastWriteTime -Descending | Select-Object -First 5)) {
    Say ('      {0}   {1}' -f $b.Name, $b.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
}
$r4 = Join-Path $bdir 'rtmtwilio_aa19743_20260913_011524'
$r4n = Safe-Count @(Get-ChildItem -LiteralPath $r4 -Recurse -File -ErrorAction SilentlyContinue)
Say ('  R4 rollback base rtmtwilio_aa19743_20260913_011524 : {0} files   expected 357, MUST NOT be deleted' -f $r4n)

Say ''
Say '===== 4  LIVENESS NOW - the pair, because /health alone is a false criterion ====='
$pipes = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) })
Say ('  named pipes visible : {0}   (zero here would mean the instrument is broken, not the system)' -f (Safe-Count $pipes))
Say ('  rtmpipe_v3 present  : {0}   expected True' -f ($pipes -contains 'rtmpipe_v3'))

Say ''
Say '===== verdict ====='
Say ('  packages and payload all match : {0}' -f $allOk)
Say '  A mismatch means the transfer, not the build. Repeat the transfer; install nothing.'
Fin $allOk
