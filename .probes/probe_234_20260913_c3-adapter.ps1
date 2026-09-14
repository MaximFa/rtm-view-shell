#Requires -Version 5.1
<#
  PROBE 234 / C3 - the adapter is replaced by hand, because the installer does not manage it.
  WHERE IT RUNS : server 234 (machine RTM). Name and hardware UUID are a gate.
  WHAT IT WRITES: it stops RTMTwilio_1, copies the whole install directory to a new backup folder,
                  lays the new publish payload over C:\RTMView\RTM.Twilio, restores the MACHINE
                  appsettings.json and log4net.config from that same backup, and starts the service.
                  It deletes nothing. It does not touch C:\IceDash, the production RTM.Twilio service,
                  legacy RTM, PostgreSQL on either port, or C:\Program Files\CcDashboard. It asks for
                  no password and issues no SQL.
  THE ONE INVARIANT IT SERVES: the engine was restarted by C1 and C2, and on this adapter revision the
                  pipe has no reconnect of its own - so the adapter must come up AFTER the engine, which
                  is exactly what this move does.
  HOW THE CONFIG IS PROVEN: the machine config files are hashed BEFORE they are overwritten, and the
                  restored copies must hash to the SAME values. The expectation is measured in this run,
                  not carried in from another run - a borrowed number is how a false red is built.
  IF ANY GATE FAILS the run stops and prints the ONE line that puts the old adapter back, so that
                  recovery does not depend on me being awake.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE  = 'RTM'
$UUIDGATE  = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir    = 'C:\RTMView-Ops\output'
$SVC       = 'RTMTwilio_1'
$INSTALL   = 'C:\RTMView\RTM.Twilio'
$PAYLOAD   = 'C:\RTMView-Ops\incoming\step5b_243424e\twilio_8d28531'
$BACKROOT  = 'C:\RTMView\Backup'
$EXESHA    = 'CC124AC26C6D27037E424987AFF105BA03C1371789E5FE9C901E73F24BC2850E'
$KEEP      = @('appsettings.json','log4net.config')
$SENTINEL  = -999

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_c3-adapter.txt')
$BACKUP = Join-Path $BACKROOT ('rtmtwilio_predeploy_' + $stamp)
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS - adapter replaced, machine config proven identical, service up' }
                       else        { 'VERDICT: FAIL - read the RECOVERY line above' }))
    Flush
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Safe-Count($c) { if ($null -eq $c) { return $SENTINEL } return @($c).Count }
function Sha($p) { if (Test-Path -LiteralPath $p) { return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToUpper() } return 'ABSENT' }
function Recovery() {
    Say ''
    Say '  RECOVERY - one line, puts the previous adapter back:'
    Say ('    Stop-Service {0}; Copy-Item -Path "{1}\*" -Destination "{2}" -Recurse -Force; Start-Service {0}' -f $SVC, $BACKUP, $INSTALL)
}

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
Say ('  assignment gate : unassigned {0} (want {1})' -f (Safe-Count $null), $SENTINEL)
if ((Safe-Count $null) -ne $SENTINEL) { Say '  *** gate broken'; Fin $false }
Say ('  now : {0}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  target service : {0}   install dir : {1}' -f $SVC, $INSTALL)
Say '  the production RTM.Twilio service and C:\IceDash are NOT addressed by this run'

Say ''
Say '===== 1  payload - proven before anything is stopped ====='
$exeSrc = Join-Path $PAYLOAD 'RTM.Twilio.exe'
if (-not (Test-Path -LiteralPath $exeSrc)) { Say ('  *** payload missing : {0}' -f $exeSrc); Fin $false }
$srcSha = Sha $exeSrc
Say ('  expected exe sha256 : {0}' -f $EXESHA)
Say ('  payload  exe sha256 : {0}   match {1}' -f $srcSha, ($srcSha -eq $EXESHA))
if ($srcSha -ne $EXESHA) { Say '  *** payload is not the build we verified - stopping before touching anything'; Fin $false }
$srcCount = Safe-Count @(Get-ChildItem -LiteralPath $PAYLOAD -Recurse -File -ErrorAction SilentlyContinue)
Say ('  payload files : {0}' -f $srcCount)
foreach ($k in $KEEP) { Say ('  payload carries {0} : {1}' -f $k, (Test-Path -LiteralPath (Join-Path $PAYLOAD $k))) }

Say ''
Say '===== 2  the machine config, hashed BEFORE it can be overwritten ====='
$before = @{}
foreach ($k in $KEEP) {
    $p = Join-Path $INSTALL $k
    $before[$k] = Sha $p
    Say ('  {0,-20} {1}' -f $k, $before[$k])
}
$oldExeSha = Sha (Join-Path $INSTALL 'RTM.Twilio.exe')
$oldCount  = Safe-Count @(Get-ChildItem -LiteralPath $INSTALL -Recurse -File -ErrorAction SilentlyContinue)
Say ('  installed exe sha256 (before) : {0}' -f $oldExeSha)
Say ('  files in install dir (before) : {0}' -f $oldCount)
if ($oldExeSha -eq $EXESHA) { Say '  NOTE: the new exe is ALREADY in place - this run would be a no-op replacement' }

Say ''
Say '===== 3  stop, then back up the WHOLE directory ====='
$svcObj = Get-Service -Name $SVC -ErrorAction SilentlyContinue
if (-not $svcObj) { Say '  *** service not found'; Fin $false }
Say ('  state before stop : {0}' -f $svcObj.Status)
Stop-Service -Name $SVC -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
$svcObj = Get-Service -Name $SVC
Say ('  state after stop  : {0}   expected Stopped' -f $svcObj.Status)
if ("$($svcObj.Status)" -ne 'Stopped') { Say '  *** did not stop - nothing was changed'; Fin $false }
New-Item -ItemType Directory -Force -Path $BACKUP | Out-Null
Copy-Item -Path (Join-Path $INSTALL '*') -Destination $BACKUP -Recurse -Force -ErrorAction SilentlyContinue
$bkCount = Safe-Count @(Get-ChildItem -LiteralPath $BACKUP -Recurse -File -ErrorAction SilentlyContinue)
Say ('  backup : {0}' -f $BACKUP)
Say ('  files backed up : {0}   expected {1}' -f $bkCount, $oldCount)
if ($bkCount -lt $oldCount) {
    Say '  *** backup is short - refusing to overwrite an install I cannot restore'
    Say '  the service is STOPPED; start it again with: Start-Service ' + $SVC
    Fin $false
}
Flush

Say ''
Say '===== 4  lay down the new payload ====='
Copy-Item -Path (Join-Path $PAYLOAD '*') -Destination $INSTALL -Recurse -Force -ErrorAction SilentlyContinue
$newExeSha = Sha (Join-Path $INSTALL 'RTM.Twilio.exe')
Say ('  installed exe sha256 (after) : {0}   match expected {1}' -f $newExeSha, ($newExeSha -eq $EXESHA))
if ($newExeSha -ne $EXESHA) { Say '  *** the new exe did not land'; Recovery; Fin $false }

Say ''
Say '===== 5  restore the MACHINE config and prove it byte-identical ====='
$cfgOk = $true
foreach ($k in $KEEP) {
    $src = Join-Path $BACKUP $k
    $dst = Join-Path $INSTALL $k
    if ($before[$k] -eq 'ABSENT') { Say ('  {0} was absent before; nothing to restore' -f $k); continue }
    Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction SilentlyContinue
    $now = Sha $dst
    Say ('  {0,-20} restored {1}   expected {2}   match {3}' -f $k, $now, $before[$k], ($now -eq $before[$k]))
    if ($now -ne $before[$k]) { $cfgOk = $false }
}
if (-not $cfgOk) { Say '  *** machine configuration is NOT what it was - this is exactly the August incident'; Recovery; Fin $false }

Say ''
Say '===== 6  start, and prove liveness by the PAIR ====='
Start-Service -Name $SVC -ErrorAction SilentlyContinue
Start-Sleep -Seconds 6
$svcObj = Get-Service -Name $SVC
Say ('  state : {0}   expected Running' -f $svcObj.Status)
foreach ($pr in @(Get-WmiObject Win32_Service -Filter ("Name='" + $SVC + "'") -ErrorAction SilentlyContinue)) {
    if ($pr.ProcessId -gt 0) {
        $po = Get-Process -Id $pr.ProcessId -ErrorAction SilentlyContinue
        if ($po) { Say ('  pid {0} started {1}   <- this is the adapter T1' -f $pr.ProcessId, $po.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
    }
}
$pipes = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) })
Say ('  named pipes visible : {0}   (zero would mean a blind instrument)' -f (Safe-Count $pipes))
Say ('  rtmpipe_v3 present  : {0}   expected True' -f ($pipes -contains 'rtmpipe_v3'))
if ("$($svcObj.Status)" -ne 'Running') { Say '  *** the new adapter did not start'; Recovery; Fin $false }

Say ''
Say '===== 7  state after the move ====='
$newCount = Safe-Count @(Get-ChildItem -LiteralPath $INSTALL -Recurse -File -ErrorAction SilentlyContinue)
Say ('  files in install dir : {0} (was {1})' -f $newCount, $oldCount)
$pv = (Get-Item -LiteralPath (Join-Path $INSTALL 'RTM.Twilio.exe')).VersionInfo.ProductVersion
Say ('  ProductVersion : {0}' -f $pv)
Say '  ProductVersion accompanies; the PDB compilation root proves whose binary it is, and that is C4.'
Say ('  backup kept at : {0}   (not deleted by this run)' -f $BACKUP)
Say '  NOTE: the R4 base C:\RTMView\Backup\rtmtwilio_aa19743_20260913_011524 is untouched.'
Fin $true
