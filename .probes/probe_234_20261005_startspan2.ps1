<#
  PROBE  probe_234_20261005_startspan2.ps1
  BASED  ON probe_234_20261005_startspan.ps1, which RAN on 234 at 07:54 and produced a 1442930-byte
         report of 9531 lines - 9415 of them the WRONG DAY. Its section 3 read
         'log-' + (Get-Date) and the failed start it is about happened on 2026-10-04. So the
         instrument measured today, where no failed start exists, and could not answer the question
         it was built for: a false search area, not a server finding. Two fixes, both mine to own:
         the incident date is PINNED as a number and the window is printed, not the whole day; and
         the report is flushed in batches, because 9415 single-line flushes of a growing 1.4 MB file
         is what made the earlier run look hung.
  BASED  ON probe_234_20261004_startspan.ps1, which RAN on 234 on 2026-10-05 at 07:50 and left a
         260-byte report holding nothing but its own heading. It printed to the console and died
         somewhere in the middle, so there was no evidence at all and no cause either. That is a
         defect of the INSTRUMENT, not of the subject, and it is fixed here in two places:
         every Say now reaches the disk immediately, and a trap writes the terminating error, with
         its line number, INTO the report instead of ending the run in silence.
  UNIT   PR234-SHELL-SERVICE-START-TIMEOUT-01, the reading half. Four questions from the coordinator.
  WHY THIS RUN EXISTS, AND IT STARTS WITH MY OWN ERROR
         I wrote that the service "missed by three seconds". That does not follow from the measurement
         and the coordinator rejected it. The timeout is 45 s and fired at 13:05:29, so counting began
         near 13:04:44; the seed line is 13:05:26. Three seconds is the AGE of the migrations line when
         the service was killed - not the shortfall. How much longer it needed is NOT measured, and
         about 42 s went somewhere BEFORE the seed line ever appeared. That gap is the subject here.
  WHAT IT ASKS
         1. the FIRST line of the log for that start, not only the last two - where the 42 s went
         2. the same span on an EARLIER start that SUCCEEDED after a reboot - without a pair, 42 s
            has nothing to be compared against and means nothing on its own
         3. where 45000 comes from: Windows ships 30000, so somebody set ServicesPipeTimeout
         4. whether RTMViewShell has failure actions at all - the engine has them and it came back
  NEGATIVE HALF, NAMED BEFORE THE RUN  if the first log line of that start turns out to be 13:05:2x,
         my arithmetic is wrong, the 42 s does not exist, and the question becomes what the service
         manager was counting from. The probe prints the number either way and draws no conclusion.
  WHERE  SERVER 234. READ-ONLY. No service is started, stopped or configured. Nothing is installed.
         The registry is READ, never written. Legacy RTM is not touched.
#>

$ErrorActionPreference = 'Continue'
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_startspan.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
$script:SayCount = 0
function Say($text) {
  [void]$ReportLines.Add("$text"); Write-Host "$text"
  $script:SayCount++
  if (($script:SayCount % 50) -eq 0) { Write-Report }
}
# Every line hits the disk as it is produced. The previous version flushed twice - at the start and
# at the end - so a death in the middle left a report with a heading and nothing else, which is
# exactly what happened on 2026-10-05 07:50. Console output is not evidence: it gets truncated.
trap {
  [void]$ReportLines.Add('*** TERMINATING ERROR - the run stops here, and this is why:')
  [void]$ReportLines.Add('    message : ' + $_.Exception.Message)
  [void]$ReportLines.Add('    type    : ' + $_.Exception.GetType().FullName)
  [void]$ReportLines.Add('    at line : ' + $_.InvocationInfo.ScriptLineNumber + '  ' + ("" + $_.InvocationInfo.Line).Trim())
  Write-Report
  Write-Host '*** TERMINATING ERROR written into the report'
  continue
}
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ''; Write-Host ('REPORT: ' + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
function CountOf($block) { try { return @(& $block).Count } catch { return -999 } }

Say ('START SPAN - PR234-SHELL-SERVICE-START-TIMEOUT-01  ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + '  host=' + $env:COMPUTERNAME)
Say  'READ ONLY. No service is started, stopped or reconfigured. The registry is read, never written.'
Say ('probe sha256 : ' + (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Write-Report
Rule

Say 'G0  machine identity'
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ('  expected : name RTM and uuid E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ('  measured : name match ' + $nameMatches + ' / uuid match ' + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say '  *** NOT server 234 - refusing to measure'; Finish $false }
Say '  G0 PASS'
Rule

Say '1  BOOTS - every restart this log keeps, so a start can be tied to the boot it followed'
$bootEvents = @(Get-WinEvent -FilterHashtable @{LogName='System'; Id=12; ProviderName='Microsoft-Windows-Kernel-General'} -MaxEvents 12 -ErrorAction SilentlyContinue)
Say ('  boot records found : ' + $bootEvents.Count + '   (a zero here is a blind search, not a machine that never booted)')
foreach ($bootEvent in $bootEvents) { Say ('    boot ' + $bootEvent.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')) }
Rule

Say '2  THE SHELL LOG, FILE BY FILE - first line, last line, and the span between them'
Say  '  The span is what the question is about: from the first thing the app managed to write to the'
Say  '  last. It is NOT the whole start - the process lives before it logs anything - but it is the'
Say  '  only part the application itself witnesses, and it is measured, not guessed.'
$logDir = 'C:\Logs\RTMViewShell'
$logFiles = @(Get-ChildItem -LiteralPath $logDir -Filter *.txt -ErrorAction SilentlyContinue | Sort-Object Name)
Say ('  log files : ' + $logFiles.Count + '   in ' + $logDir)
if ($logFiles.Count -eq 0) { Say '  *** no log files at all - that is itself the finding, report it' }
foreach ($logFile in $logFiles) {
    $firstLine = (Get-Content -LiteralPath $logFile.FullName -TotalCount 1 -ErrorAction SilentlyContinue)
    $lastLine  = (Get-Content -LiteralPath $logFile.FullName -Tail 1 -ErrorAction SilentlyContinue)
    $lineCount = CountOf { Get-Content -LiteralPath $logFile.FullName -ErrorAction SilentlyContinue }
    Say ('  ' + $logFile.Name + '   ' + $logFile.Length + ' B   lines ' + $lineCount + '   mtime ' + $logFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
    Say ('      first : ' + $firstLine)
    Say ('      last  : ' + $lastLine)
}
Rule

Say '3  TODAY IN FULL - every line of the failed start, so the 42 s has somewhere to be'
# PINNED, not derived from the clock. The failed start is 2026-10-04 13:04-13:06; 'today' is a
# different day with no failed start in it, which is what the previous version actually read.
$IncidentDay    = '20261004'
$IncidentPrefix = '2026-10-04 13:0'
$incidentLog = Join-Path $logDir ('log-' + $IncidentDay + '.txt')
Say ('  incident log : ' + $incidentLog)
Say ('  window       : lines beginning "' + $IncidentPrefix + '" (13:00:00 to 13:09:59)')
if (-not (Test-Path -LiteralPath $incidentLog)) {
    Say '  *** ABSENT - and the search area is named above, so this is a measured absence.'
} else {
    $allLines = @(Get-Content -LiteralPath $incidentLog -ErrorAction SilentlyContinue)
    Say ('  lines in that file, whole day : ' + $allLines.Count)
    if ($allLines.Count -gt 0) { Say ('  VERY FIRST LINE OF THE DAY     : ' + $allLines[0]) }
    $inWindow = @($allLines | Where-Object { $_.StartsWith($IncidentPrefix) })
    Say ('  lines inside the window        : ' + $inWindow.Count + '   (zero here means the window is wrong, not that the start was silent)')
    $negPrefix = '2026-10-04 13:9'
    $negWindow = @($allLines | Where-Object { $_.StartsWith($negPrefix) })
    Say ('  NEGCTL same filter, impossible hour "' + $negPrefix + '" : ' + $negWindow.Count + '   must be 0')
    Say  '  THE WINDOW, LINE BY LINE - the first line here is where the 42 s has to be accounted for:'
    foreach ($line in $inWindow) { Say ('  | ' + $line) }
    Say ('  printed ' + $inWindow.Count + ' lines of ' + $allLines.Count + ' in the file - the rest of the day is deliberately not here')
}
Rule

Say '4  SERVICE CONTROL MANAGER - what it said about BOTH services, so ours has a comparison'
$scmEvents = @(Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Service Control Manager'; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue |
               Where-Object { $_.Message -match 'RTMViewShell|RTMService|RTMTwilio_1' })
Say ('  events mentioning our three services in 7 days : ' + $scmEvents.Count)
foreach ($scmEvent in ($scmEvents | Select-Object -First 30)) {
    $flatMessage = ($scmEvent.Message -replace "`r`n", ' ' -replace '\s+', ' ')
    Say ('    ' + $scmEvent.TimeCreated.ToString('MM-dd HH:mm:ss') + '  id ' + $scmEvent.Id + '  ' + $flatMessage.Substring(0, [Math]::Min(150, $flatMessage.Length)))
}
Rule

Say '5  WHERE 45000 COMES FROM - Windows ships 30000, so somebody set it'
$controlKey = 'HKLM:\SYSTEM\CurrentControlSet\Control'
$pipeTimeout = (Get-ItemProperty -Path $controlKey -Name 'ServicesPipeTimeout' -ErrorAction SilentlyContinue).ServicesPipeTimeout
if ($null -eq $pipeTimeout) {
    Say '  ServicesPipeTimeout : NOT SET - the effective value is the Windows default of 30000 ms.'
    Say '  That contradicts the 45000 in the event text, and the contradiction is the finding, not a detail.'
} else {
    Say ('  ServicesPipeTimeout : ' + $pipeTimeout + ' ms')
}
Say  '  Who set it and when is NOT readable from the value itself - the registry keeps no per-value'
Say  '  author. Saying otherwise would be invention; this probe reports the value and stops there.'
Rule

Say '6  FAILURE ACTIONS - the engine came back after the same boot, ours did not'
foreach ($serviceName in @('RTMViewShell','RTMService','RTMTwilio_1')) {
    Say ('  --- ' + $serviceName + ' ---')
    $failureText = (& sc.exe qfailure $serviceName) 2>&1
    foreach ($failureLine in @($failureText | ForEach-Object { "$_" })) { if ("$failureLine".Trim()) { Say ('    ' + $failureLine.Trim()) } }
    $svcObject = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $serviceName) -ErrorAction SilentlyContinue
    if ($svcObject) { Say ('    state ' + $svcObject.State + '  startmode ' + $svcObject.StartMode + '  pid ' + $svcObject.ProcessId + '  delayed-auto: ' + (Get-ItemProperty -Path ('HKLM:\SYSTEM\CurrentControlSet\Services\' + $serviceName) -Name 'DelayedAutostart' -ErrorAction SilentlyContinue).DelayedAutostart) }
}
Rule

Say 'SUMMARY - readings only. No conclusion is drawn here and no remedy is proposed.'
Say ('  report : ' + $ReportPath)
Say  '  Three remedies exist in principle - raise the timeout, move the seed out of startup, delayed'
Say  '  autostart - and this run deliberately recommends none of them: the numbers above decide,'
Say  '  and one of them (the pair with an earlier successful start) may not exist in these logs at all.'
Say  '  Nothing was started, stopped, installed or configured.'
Say 'END-OF-RUN MARKER: STARTSPAN-COMPLETE'
Finish $true
