#Requires -Version 5.1
<#
  PROBE  probe_234_20260919_port5000-owner.ps1
  UNIT   PORT5000-OVERLAP-01 + PR234-REDIS-NOAUTH-01, step 1: WHO owns the endpoint that answers 503.
  WHY    The 503 is measured and its cause is measured (Redis answers NOAUTH). What is NOT measured is
         whose application it is: both our services run with a working directory of System32, so the log
         under C:\Windows\System32\logs cannot name its author by its path. Fixing the Redis password
         before the owner is established would fix the wrong thing.
  ORDER  Owner first, cause second. This probe does the first half only.
  WHERE  SERVER 234. READ ONLY: TCP connection table, process and service tables, file reads.
         Nothing is started, stopped, edited or restarted. No password is touched or printed.
  NEEDLES From the corpus: this log writes levels as [ERR] / [INF] / [WRN], not as Error / Information.
         Today a control built from my idea of a log printed zero next to fifteen real lines; the needle
         here is taken from the file, and a control that finds nothing says the search is blind.
  COUNTERS  -999 means NOT MEASURED and is never printed as 0.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_port5000-owner.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }

Say ("WHO OWNS PORT 5000  " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say  "READ ONLY. No service is touched, no config is read for its secrets, nothing is restarted."
Say ("probe sha256 : " + (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Write-Report
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing"; Finish $false }
Say "  G0 PASS"
Rule

Say "1  THE LISTENERS - the port names its process, the process names its file"
Say  "  expected, before the measurement: something answers on 5000 and on 8444; which service owns"
Say  "  which is exactly what is not known today."
foreach ($port in @(5000, 8444, 8089, 5433)) {
  $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
  if ($listeners.Count -eq 0) { Say ("  port " + $port + " : no listener") ; continue }
  foreach ($listener in $listeners) {
    $owningProcess = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
    $processPath = 'NOT READABLE'
    if ($owningProcess) { try { $processPath = $owningProcess.Path } catch { $processPath = 'NOT READABLE' } }
    $serviceOfProcess = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.ProcessId -eq $listener.OwningProcess })
    $serviceName = $(if ($serviceOfProcess.Count -gt 0) { ($serviceOfProcess | ForEach-Object { $_.Name }) -join ',' } else { 'no service owns this pid' })
    Say ("  port " + $port + " : pid " + $listener.OwningProcess + "   address " + $listener.LocalAddress)
    Say ("      process : " + $(if ($owningProcess) { $owningProcess.ProcessName } else { 'gone' }) + "   path " + $processPath)
    Say ("      service : " + $serviceName)
  }
}
Rule

Say "2  OUR SERVICES - what each one runs, and from where"
foreach ($serviceName in @('RTMViewShell','RTMService','RTMTwilio_1','RTM','RTM.Twilio')) {
  $service = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $serviceName) -ErrorAction SilentlyContinue
  if ($null -eq $service) { Say ("  " + $serviceName.PadRight(14) + " ABSENT") ; continue }
  Say ("  " + $serviceName.PadRight(14) + $service.State + "   pid " + $service.ProcessId)
  Say ("      binPath : " + $service.PathName)
  if ($service.ProcessId -gt 0) {
    $serviceProcess = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f $service.ProcessId) -ErrorAction SilentlyContinue
    if ($serviceProcess) { Say ("      exe     : " + $serviceProcess.ExecutablePath) ; Say ("      cmdline : " + $serviceProcess.CommandLine) }
  }
}
Rule

Say "3  WHO CLAIMS 5000 IN CONFIGURATION - the file says it, not me"
foreach ($configPath in @('C:\RTMView\Shell\appsettings.json','C:\RTMView\RTM\appsettings.json','C:\RTMView\RTM.Twilio\appsettings.json')) {
  if (-not (Test-Path -LiteralPath $configPath)) { Say ("  " + $configPath + " : ABSENT") ; continue }
  $rawConfig = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
  $urlHits = @([regex]::Matches($rawConfig, '(?i)"(?:Url|Urls|ApplicationUrl)"\s*:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
  $mentions5000 = ([regex]::Matches($rawConfig, '5000')).Count
  Say ("  " + $configPath)
  Say ("      urls declared : " + $(if ($urlHits.Count -gt 0) { ($urlHits -join ' , ') } else { 'none' }))
  Say ("      the number 5000 appears " + $mentions5000 + " time(s) anywhere in this file")
  $redisHits = @([regex]::Matches($rawConfig, '(?i)"([A-Za-z]*(?:Redis|Cache|Garnet)[A-Za-z]*)"\s*:') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
  Say ("      keys whose name mentions Redis/Cache/Garnet : " + $(if ($redisHits.Count -gt 0) { ($redisHits -join ' , ') } else { 'none' }))
  $passwordHits = ([regex]::Matches($rawConfig, '(?i)password')).Count
  Say ("      the word password appears " + $passwordHits + " time(s) - values are NOT printed by this probe")
}
Rule

Say "4  THE LOGS, SORTED BY THEIR OWN CONTENT - a path in System32 names nobody"
Say  "  Needles taken FROM the corpus: [ERR] / [INF] / [WRN] are how this log writes levels."
$logDirectories = @('C:\Windows\System32\logs','C:\RTMView\Shell\logs','C:\RTMView\RTM\Logs','C:\Logs\RTM.Twilio')
foreach ($logDirectory in $logDirectories) {
  if (-not (Test-Path -LiteralPath $logDirectory)) { Say ("  " + $logDirectory.PadRight(30) + " : ABSENT") ; continue }
  $logFiles = @(Get-ChildItem -LiteralPath $logDirectory -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
  Say ("  " + $logDirectory.PadRight(30) + " : " + $logFiles.Count + " newest files listed")
  foreach ($logFile in $logFiles) {
    Say ("      " + $logFile.Name + "   " + $logFile.Length + " B   " + $logFile.LastWriteTime)
    if ($logFile.Length -eq 0) { Say "          empty file - nothing to attribute" ; continue }
    $levelCount = @(Select-String -LiteralPath $logFile.FullName -Pattern '[ERR]','[INF]','[WRN]' -SimpleMatch -ErrorAction SilentlyContinue).Count
    Say ("          POSCTL lines carrying a level tag : " + $levelCount + "   (zero here means the search is blind)")
    foreach ($marker in @('CcDashboard','RTMService','RTM.Twilio','TwilioAdapter','Kestrel','Now listening on')) {
      $markerCount = @(Select-String -LiteralPath $logFile.FullName -Pattern $marker -SimpleMatch -ErrorAction SilentlyContinue).Count
      if ($markerCount -gt 0) { Say ("          marker " + $marker.PadRight(18) + " : " + $markerCount) }
    }
    $listeningLines = @(Select-String -LiteralPath $logFile.FullName -Pattern 'Now listening on' -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -First 4)
    foreach ($listeningLine in $listeningLines) { Say ("          | " + $listeningLine.Line.Trim()) }
    $firstLines = @(Get-Content -LiteralPath $logFile.FullName -TotalCount 3 -Encoding UTF8)
    foreach ($firstLine in $firstLines) { Say ("          first | " + $firstLine) }
  }
}
Rule

Say "5  THE CACHE SERVICE ITSELF - is anything listening where a cache would listen"
foreach ($cachePort in @(6379, 3278)) {
  $cacheListeners = @(Get-NetTCPConnection -State Listen -LocalPort $cachePort -ErrorAction SilentlyContinue)
  if ($cacheListeners.Count -eq 0) { Say ("  port " + $cachePort + " : no listener") ; continue }
  foreach ($cacheListener in $cacheListeners) {
    $cacheProcess = Get-Process -Id $cacheListener.OwningProcess -ErrorAction SilentlyContinue
    Say ("  port " + $cachePort + " : pid " + $cacheListener.OwningProcess + "   process " + $(if ($cacheProcess) { $cacheProcess.ProcessName } else { 'gone' }))
  }
}
foreach ($cacheServiceName in @('Garnet','Memurai','redis')) {
  $cacheService = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $cacheServiceName) -ErrorAction SilentlyContinue
  if ($null -eq $cacheService) { Say ("  service " + $cacheServiceName.PadRight(10) + " : ABSENT") }
  else { Say ("  service " + $cacheServiceName.PadRight(10) + " : " + $cacheService.State + "   binPath " + $cacheService.PathName) }
}
Rule

Say "SUMMARY - readings only. The owner is whatever section 1 and section 4 agree on; if they"
Say "disagree, that disagreement is the finding and it is not resolved by choosing the nicer half."
Say ("  collector : " + $ReportLines.GetType().Name)
Say "END-OF-RUN MARKER: PORT5000-OWNER-COMPLETE"
Finish $true
