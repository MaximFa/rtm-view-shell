<#
  PROBE  probe_234_20260919_logowner-handles.ps1
  UNIT   PR234-REDIS-NOAUTH-01 / PORT5000-OVERLAP-01 - WHO writes the health-error lines in
         C:\Windows\System32\logs. The predicate is FILE HANDLES, not process start time:
         coordinator-0919b ruled that a start-time match is convergence, not attribution - both
         installations are autostart services and come up in the same window, so time would print
         "matched" for either one.
  WHERE  SERVER 234. READ-ONLY. No service is started, stopped or reconfigured. The foreign
         installation (pid of service CcDashboard, C:\Program Files\CcDashboard) is NOT touched:
         we only ask the operating system which process holds which file open.
  GATE   If no handle-reading instrument exists on this machine, this probe STOPS and says so.
         Nothing is installed on 234 for this. An empty attribution beats a false one.
  OUT    C:\RTMView-Ops\output\234_<stamp>_logowner-handles.txt
#>

$ErrorActionPreference = 'Continue'
$RunStamp   = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir  = 'C:\RTMView-Ops\output'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$ReportPath = Join-Path $OutputDir ("234_{0}_logowner-handles.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }

Say ("LOG OWNER BY HANDLES  " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  expected : name RTM and uuid E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing"; Finish $false }
Say "  G0 PASS"
Rule

Say "1  WHO IS WHO - the two installations, named before anything is attributed"
$ourService     = Get-CimInstance Win32_Service -Filter "Name='RTMViewShell'" -ErrorAction SilentlyContinue
$foreignService = Get-CimInstance Win32_Service -Filter "Name='CcDashboard'"  -ErrorAction SilentlyContinue
$ourPid     = if ($null -ne $ourService)     { [int]$ourService.ProcessId }     else { 0 }
$foreignPid = if ($null -ne $foreignService) { [int]$foreignService.ProcessId } else { 0 }
Say ("  ours    : service RTMViewShell pid " + $ourPid + "   " + $(if ($null -ne $ourService) { $ourService.PathName } else { 'ABSENT' }))
Say ("  foreign : service CcDashboard  pid " + $foreignPid + "   " + $(if ($null -ne $foreignService) { $foreignService.PathName } else { 'ABSENT' }))
Say  "  The foreign one is read about, never touched."
Rule

Say "2  INSTRUMENT GATE - can this machine read handles at all?"
Say  "  Nothing is installed for this probe. If the instrument is absent, the run stops and the"
Say  "  attribution stays [not measured] - that is a legitimate outcome, a guessed owner is not."
$handleExe = $null
$candidates = @()
$cmd = Get-Command handle.exe -ErrorAction SilentlyContinue
if ($cmd) { $candidates += $cmd.Source }
$candidates += @(
  'C:\Sysinternals\handle.exe', 'C:\Sysinternals\handle64.exe',
  'C:\Tools\handle.exe', 'C:\Tools\handle64.exe',
  'C:\RTMView-Ops\handle.exe', 'C:\RTMView-Ops\handle64.exe',
  'C:\Program Files\Sysinternals\handle64.exe'
)
foreach ($candidate in $candidates) {
  if (($null -eq $handleExe) -and $candidate -and (Test-Path -LiteralPath $candidate)) { $handleExe = $candidate }
}
Say ("  handle.exe : " + $(if ($handleExe) { $handleExe } else { 'NOT FOUND in PATH or the usual locations' }))
if (-not $handleExe) {
  Say ""
  Say "  STOP - THE ATTRIBUTION CANNOT BE TAKEN ON THIS MACHINE."
  Say "  Windows has no built-in way to list the processes holding a given file open:"
  Say "    - openfiles.exe needs 'maintain objects list' enabled, which needs a REBOOT of a live server;"
  Say "    - a start-time comparison is convergence, not attribution, and is explicitly refused here."
  Say "  PR234-REDIS-NOAUTH-01 therefore stays OPEN with its cause [not measured]. Nothing was guessed."
  Finish $false
}
Rule

Say "3  THE FILES - everything written in the shared log directory in the last 24 hours"
$logDir = 'C:\Windows\System32\logs'
if (-not (Test-Path -LiteralPath $logDir)) { Say ("  " + $logDir + " does not exist - report, do not improvise"); Finish $false }
$since = (Get-Date).AddHours(-24)
$logFiles = @(Get-ChildItem -LiteralPath $logDir -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $since } | Sort-Object LastWriteTime -Descending)
Say ("  files written since " + $since.ToString('yyyy-MM-dd HH:mm') + " : " + $logFiles.Count)
foreach ($logFile in $logFiles) { Say ("    " + $logFile.Name + "   " + $logFile.Length + " B   " + $logFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) }
Rule

Say "4  EXPECTED, PRINTED BEFORE MEASURED"
Say ("  I expect the health-error lines to be held by the FOREIGN process, pid " + $foreignPid + ",")
Say  "  because our own /health answers Healthy while those lines say a Redis check fails."
Say  "  THREE outcomes are possible for every file, and all three are printed as themselves:"
Say ("    held by pid " + $ourPid + "     -> ours"
)
Say ("    held by pid " + $foreignPid + "  -> foreign")
Say  "    held by NOBODY          -> ATTRIBUTION NOT AVAILABLE (the file was written and closed)"
Rule

Say "5  HOLDERS, FILE BY FILE"
$anyHolderFound = $false
$ownership = @{}
foreach ($logFile in $logFiles) {
  $target = $logFile.FullName
  $raw = & $handleExe -nobanner -accepteula -u $target 2>&1
  $holders = @()
  foreach ($line in @($raw | ForEach-Object { "$_" })) {
    $match = [regex]::Match($line, '^\s*(?<proc>\S.*?)\s+pid:\s*(?<pid>\d+)\s')
    if ($match.Success) { $holders += [pscustomobject]@{ Proc = $match.Groups['proc'].Value.Trim(); Pid = [int]$match.Groups['pid'].Value } }
  }
  Say ("  " + $logFile.Name)
  if ($holders.Count -eq 0) {
    Say  "      holders : NONE -> ATTRIBUTION NOT AVAILABLE for this file (written and closed)"
  } else {
    $anyHolderFound = $true
    foreach ($holder in $holders) {
      $proc = Get-Process -Id $holder.Pid -ErrorAction SilentlyContinue
      $procPath = if ($proc) { try { $proc.Path } catch { 'path unavailable' } } else { 'process gone' }
      $whose = if ($holder.Pid -eq $ourPid) { 'OURS' } elseif ($holder.Pid -eq $foreignPid) { 'FOREIGN' } else { 'NEITHER of the two' }
      Say ("      pid " + $holder.Pid + "  " + $procPath + "   -> " + $whose)
      $ownership[$logFile.Name] = $whose
    }
  }
}
Rule

Say "6  NEGATIVE HALF - the instrument must be able to tell the two apart"
Say  "  A probe whose every answer comes out the same does not distinguish the installations."
Say  "  So: a file held by ours and NOT by the foreign one, and a file held by the foreign and not ours."
$ourOwn     = @($ownership.GetEnumerator() | Where-Object { $_.Value -eq 'OURS' })
$foreignOwn = @($ownership.GetEnumerator() | Where-Object { $_.Value -eq 'FOREIGN' })
Say ("  files attributed to OURS    : " + $ourOwn.Count + "   " + (($ourOwn | ForEach-Object { $_.Key }) -join ' , '))
Say ("  files attributed to FOREIGN : " + $foreignOwn.Count + "   " + (($foreignOwn | ForEach-Object { $_.Key }) -join ' , '))
$discriminates = (($ourOwn.Count -gt 0) -and ($foreignOwn.Count -gt 0))
Say ("  DISCRIMINATES : " + $discriminates + "   (False means the reading cannot separate the two and proves nothing)")
Rule

Say "7  POSITIVE CONTROL ON THE INSTRUMENT ITSELF"
Say  "  If the instrument finds no holder for ANY file, that is 'the instrument cannot read', not"
Say  "  'nobody holds anything'. The control: a file we KNOW is held - our own service's main binary."
$knownHeld = 'C:\RTMView\Shell\CcDashboard.Web.dll'
$controlRaw = & $handleExe -nobanner -accepteula -u $knownHeld 2>&1
$controlHits = @(@($controlRaw | ForEach-Object { "$_" }) | Where-Object { $_ -match 'pid:\s*\d+' })
Say ("  holders of " + $knownHeld + " : " + $controlHits.Count + "   (0 here means the instrument is blind)")
foreach ($hit in $controlHits) { Say ("      | " + $hit.Trim()) }
$posControlOk = ($controlHits.Count -gt 0)
Say ("  POSCTL : " + $posControlOk)
Rule

Say "VERDICT"
Say ("  instrument present   : True (" + $handleExe + ")")
Say ("  POSCTL instrument    : " + $posControlOk)
Say ("  any holder found     : " + $anyHolderFound)
Say ("  discriminates ours/foreign : " + $discriminates)
$verdictOk = ($posControlOk -and $anyHolderFound -and $discriminates)
Say ("  ATTRIBUTION USABLE   : " + $verdictOk)
Say  "  If ATTRIBUTION USABLE is False, the cause of PR234-REDIS-NOAUTH-01 stays [not measured]."
Say ("  LAST LINE : " + $(if ($verdictOk) { 'PASS' } else { 'FAIL' }))
Say "===== END-OF-RUN MARKER: LOGOWNER-HANDLES-COMPLETE ====="
Finish $verdictOk
