<#
  PROBE  probe_234_20260919_logpath-whereweWRITE.ps1
  UNIT   PR234-SHELL-CFG-01 - the question the preconditions run left open THROUGH MY OWN FAULT:
         I measured that C:\Logs\RTMViewShell EXISTS and is writable, and never looked INSIDE it.
  WHY    The preconditions run overturned the premise: the path in the machine's own appsettings.json
         is ALREADY ABSOLUTE (C:\Logs\RTMViewShell\log-.txt), the directory exists, and the update
         preserved the file. So the change may not be needed at all - what is missing is the one
         reading that says WHERE OUR SERVICE ACTUALLY WRITES RIGHT NOW.
  WHERE  SERVER 234. READ-ONLY. No service touched, no file written outside C:\RTMView-Ops\output.
  OUT    C:\RTMView-Ops\output\234_<stamp>_logpath-whereweWRITE.txt
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp   = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir  = 'C:\RTMView-Ops\output'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$ReportPath = Join-Path $OutputDir ("234_{0}_logpath-whereweWRITE.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
function Read-Live([string]$file, [int]$tailCount) {
  # a live log is held open by its writer: read it with FileShare.ReadWrite or get nothing
  try {
    $stream = New-Object System.IO.FileStream($file, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
      $reader = New-Object System.IO.StreamReader($stream)
      try { $all = $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally { $stream.Dispose() }
    $lines = @($all -split "`r?`n" | Where-Object { $_ -ne '' })
    return ,@($lines | Select-Object -Last $tailCount)
  } catch { return ,@('READ FAILED: ' + $_.Exception.Message) }
}

Say ("WHERE DO WE ACTUALLY WRITE  " + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing"; Finish $false }
Say "  G0 PASS"
Rule

Say "1  OUR SERVICE AND WHEN IT LAST STARTED - every 'after' below is relative to THIS moment"
$shellService = Get-CimInstance Win32_Service -Filter "Name='RTMViewShell'" -ErrorAction SilentlyContinue
if ($null -eq $shellService) { Say "  *** RTMViewShell ABSENT"; Finish $false }
$shellPid = [int]$shellService.ProcessId
$shellProcess = Get-Process -Id $shellPid -ErrorAction SilentlyContinue
$shellStart = if ($shellProcess) { $shellProcess.StartTime } else { $null }
Say ("  RTMViewShell pid " + $shellPid + "   started " + $(if ($shellStart) { $shellStart.ToString('yyyy-MM-dd HH:mm:ss') } else { 'UNKNOWN' }))
Say  "  It was restarted by the installer at 17:25 today, so anything our service writes must be newer than that."
Rule

Say "2  EXPECTED, BEFORE MEASURED"
Say  "  The machine config already carries an ABSOLUTE path C:\Logs\RTMViewShell\log-.txt."
Say  "  If that is what the running service obeys, then:"
Say  "    (a) C:\Logs\RTMViewShell holds a file written AFTER the service start above, and"
Say  "    (b) the newest file in C:\Windows\System32\logs is OLDER than that start - we stopped"
Say  "        contributing there. Its last write was 13:22 today, hours BEFORE the 17:25 restart."
Say  "  If instead (a) is empty, the service does NOT obey that file and the real path lives elsewhere."
Rule

Say "3  WHAT IS INSIDE THE TARGET DIRECTORY - the reading I failed to take last run"
$targetDir = 'C:\Logs\RTMViewShell'
if (-not (Test-Path -LiteralPath $targetDir)) { Say ("  " + $targetDir + " ABSENT - contradicts the previous run, stop and report"); Finish $false }
$targetFiles = @(Get-ChildItem -LiteralPath $targetDir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
Say ("  files : " + $targetFiles.Count)
$writtenAfterStart = 0
foreach ($targetFile in ($targetFiles | Select-Object -First 10)) {
  $isAfterStart = ($shellStart -ne $null) -and ($targetFile.LastWriteTime -ge $shellStart)
  if ($isAfterStart) { $writtenAfterStart++ }
  Say ("    " + $targetFile.Name.PadRight(30) + " " + $targetFile.Length.ToString().PadLeft(12) + " B   " +
       $targetFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + "   written after our service started : " + $isAfterStart)
}
Say ("  files written AFTER our current process started : " + $writtenAfterStart)
Rule

Say "4  THE NEWEST LINES THERE - read with FileShare.ReadWrite, because a live log is held open"
if ($targetFiles.Count -gt 0) {
  $newest = $targetFiles[0]
  Say ("  " + $newest.FullName)
  foreach ($line in (Read-Live $newest.FullName 12)) { Say ("    | " + $line) }
} else { Say "  nothing to read - the directory is empty" }
Rule

Say "5  THE SHARED POT - is it still growing, and with whose lines"
$sharedDir = 'C:\Windows\System32\logs'
$sharedFiles = @(Get-ChildItem -LiteralPath $sharedDir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
$sharedNewest = if ($sharedFiles.Count -gt 0) { $sharedFiles[0] } else { $null }
if ($null -eq $sharedNewest) { Say "  empty" }
else {
  $sharedIsAfterStart = ($shellStart -ne $null) -and ($sharedNewest.LastWriteTime -ge $shellStart)
  Say ("  newest : " + $sharedNewest.Name + "   " + $sharedNewest.Length + " B   " + $sharedNewest.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
  Say ("  written after our service started : " + $sharedIsAfterStart + "   (False = we are not the ones filling it now)")
  Say  "  last lines of it, for whose they look like:"
  foreach ($line in (Read-Live $sharedNewest.FullName 8)) { Say ("    | " + $line) }
}
Rule

Say "6  POSITIVE CONTROL ON THE READER ITSELF"
Say  "  If the live reader returned nothing everywhere, that is 'the reader is blind', not 'the logs are empty'."
$controlFile = $null
foreach ($candidate in @($targetFiles + $sharedFiles)) { if (($null -eq $controlFile) -and ($candidate.Length -gt 0)) { $controlFile = $candidate } }
if ($null -eq $controlFile) { Say "  no non-empty log file anywhere - POSCTL : False" ; $posControlOk = $false }
else {
  $controlLines = @(Read-Live $controlFile.FullName 3)
  $posControlOk = (($controlLines.Count -gt 0) -and ($controlLines[0] -notlike 'READ FAILED*'))
  Say ("  read " + $controlLines.Count + " line(s) from " + $controlFile.Name + "   POSCTL : " + $posControlOk)
}
Rule

Say "VERDICT"
Say ("  our log directory holds files written after our process start : " + ($writtenAfterStart -gt 0))
Say ("  reader working (POSCTL) : " + $posControlOk)
Say  "  This run changes nothing. It answers one question: does the running service obey the absolute"
Say  "  path that is already in its config on disk."
Say ("  LAST LINE : " + $(if ($posControlOk) { 'PASS' } else { 'FAIL' }))
Say "===== END-OF-RUN MARKER: LOGPATH-WHEREWEWRITE-COMPLETE ====="
Finish $posControlOk
