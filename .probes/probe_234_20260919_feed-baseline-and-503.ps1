#Requires -Version 5.1
<#
  PROBE  probe_234_20260919_feed-baseline-and-503.ps1
  UNIT   PR234-FEED-BASELINE-01 (new) + PR234-HEALTH-503-01.
  WHY    Two questions about ONE place, which is why they travel together and not in two runs:
         (a) the feed has no baseline at all - nobody ever wrote down what "normal" is, so today's
             19-hour-old row cannot be read as good or bad. This run WRITES that baseline down.
         (b) /health answers 200 Healthy on HTTPS and 503 Unhealthy on the plain HTTP port. That is
             the application answering, not an unreachable address, and the two answers disagree.
  NOT A GATE  The feed is an OBSERVATION here (norm N-16): an empty window is a quiet hour, not a
         failure. Nothing in this probe decides anything; it produces numbers and names them.
  WHERE  SERVER 234. READ ONLY: SELECT, curl, file reads. Nothing is started, stopped or edited.
  COUNTERS  -999 means NOT MEASURED and is never printed as 0.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_feed-baseline-and-503.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }

Say ("FEED BASELINE AND THE 503  " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say  "READ ONLY. Nothing is started, stopped or edited. The feed here is an observation, not a gate."
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

Say "1  CONTEXT - who is running, so the feed numbers are read against something"
foreach ($serviceName in @('RTMViewShell','RTMService','RTMTwilio_1','RTM')) {
  $service = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $serviceName) -ErrorAction SilentlyContinue
  if ($null -eq $service) { Say ("  " + $serviceName.PadRight(14) + " ABSENT") }
  else { Say ("  " + $serviceName.PadRight(14) + $service.State + "   pid " + $service.ProcessId) }
}
$pipes = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) })
Say ("  pipe rtmpipe_v3 served : " + ($pipes -contains 'rtmpipe_v3') + "   pipes in total " + @($pipes).Count)
Rule

Say "2  THE 503 - the same endpoint asked on both ports, body printed verbatim"
Say  "  expected, before the measurement: HTTPS 8444 answers 200 Healthy; HTTP 5000 answered 503"
Say  "  Unhealthy at 12:20 and again at 13:07. What is NOT known is WHICH check reports unhealthy."
$curl = "$env:SystemRoot\System32\curl.exe"
if (-not (Test-Path -LiteralPath $curl)) { Say "  curl.exe ABSENT - this whole section is NOT MEASURED (-999)" }
else {
  foreach ($endpoint in @('http://127.0.0.1:5000/health','https://127.0.0.1:8444/health','http://127.0.0.1:5000/healthz','http://127.0.0.1:5000/health/ready')) {
    $code = (& $curl -k -s -o NUL -w '%{http_code}' --max-time 20 $endpoint) 2>$null
    if ("$code" -eq '000') { Say ("  " + $endpoint.PadRight(38) + " -> UNREACHABLE (not a verdict about the application)") ; continue }
    $bodyText = (& $curl -k -s --max-time 20 $endpoint) 2>$null
    $bodyJoined = (@($bodyText) -join ' ')
    if ($bodyJoined.Length -gt 600) { $bodyJoined = $bodyJoined.Substring(0,600) + ' ...[cut at 600 chars]' }
    Say ("  " + $endpoint.PadRight(38) + " -> " + $code)
    Say ("      body : " + $(if ($bodyJoined) { $bodyJoined } else { '(empty)' }))
  }
  Say "  response headers of the 503, because the body of a health endpoint is often just one word:"
  $headerText = (& $curl -k -s -i -o - --max-time 20 'http://127.0.0.1:5000/health') 2>$null
  $headerLines = @($headerText) | Select-Object -First 20
  foreach ($headerLine in $headerLines) { if ("$headerLine".Trim()) { Say ("      | " + $headerLine) } }
}
Rule

Say "3  WHERE the Shell writes its log right now, and what it says about health"
Say  "  The Serilog path in the config is relative, so the log follows the service working directory."
$logCandidates = @('C:\RTMView\Shell\logs','C:\Windows\System32\logs')
$newestLog = $null
foreach ($logDir in $logCandidates) {
  if (-not (Test-Path -LiteralPath $logDir)) { Say ("  " + $logDir.PadRight(30) + " : ABSENT") ; continue }
  $found = @(Get-ChildItem -LiteralPath $logDir -Filter 'log-*.txt' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
  Say ("  " + $logDir.PadRight(30) + " : " + $found.Count + " log files")
  if ($found.Count -gt 0) {
    Say ("      newest " + $found[0].Name + "   " + $found[0].Length + " B   " + $found[0].LastWriteTime)
    if (($null -eq $newestLog) -or ($found[0].LastWriteTime -gt $newestLog.LastWriteTime)) { $newestLog = $found[0] }
  }
}
if ($null -eq $newestLog) { Say "  no Shell log found in either place - section NOT MEASURED (-999)" }
else {
  Say ("  reading the newest one: " + $newestLog.FullName)
  $healthHits = @(Select-String -LiteralPath $newestLog.FullName -Pattern 'health','unhealthy','degraded' -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -Last 15)
  Say ("  lines mentioning health/unhealthy/degraded : " + $healthHits.Count)
  foreach ($hit in $healthHits) { Say ("      | " + $hit.Line.Trim()) }
  $positiveControl = @(Select-String -LiteralPath $newestLog.FullName -Pattern 'Information','Error','Warning' -SimpleMatch -ErrorAction SilentlyContinue).Count
  Say ("  POSCTL lines with a log level at all : " + $positiveControl + "   (zero here means this search is blind, not that the log is silent)")
  Say  "  last 8 lines of that log, verbatim:"
  foreach ($tailLine in (Get-Content -LiteralPath $newestLog.FullName -Tail 8 -Encoding UTF8)) { Say ("      | " + $tailLine) }
}
Rule

Say "4  THE FEED - three samples 60 s apart. THIS IS THE BASELINE WE NEVER WROTE DOWN."
$psql = $null
foreach ($pgDir in @(Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
  $candidate = Join-Path $pgDir.FullName 'bin\psql.exe'
  if ((Test-Path -LiteralPath $candidate) -and ($null -eq $psql)) { $psql = $candidate }
}
$shellCfg = 'C:\RTMView\Shell\appsettings.json'
$dbUser = '' ; $dbName = '' ; $dbPort = '' ; $dbPassword = ''
if (Test-Path -LiteralPath $shellCfg) {
  $rawShell = Get-Content -LiteralPath $shellCfg -Raw -Encoding UTF8
  $connMatch = [regex]::Match($rawShell, '(?i)Password\s*=\s*([^;"]+)') ; if ($connMatch.Success) { $dbPassword = $connMatch.Groups[1].Value.Trim() }
  $connMatch = [regex]::Match($rawShell, '(?i)(?:Username|User ID)\s*=\s*([^;"]+)') ; if ($connMatch.Success) { $dbUser = $connMatch.Groups[1].Value.Trim() }
  $connMatch = [regex]::Match($rawShell, '(?i)Database\s*=\s*([^;"]+)') ; if ($connMatch.Success) { $dbName = $connMatch.Groups[1].Value.Trim() }
  $connMatch = [regex]::Match($rawShell, '(?i)Port\s*=\s*(\d+)') ; if ($connMatch.Success) { $dbPort = $connMatch.Groups[1].Value }
}
Say ("  connection from the machine own config : user " + $dbUser + " / db " + $dbName + " / port " + $dbPort + " / password " + $dbPassword.Length + " chars")
if ((-not $psql) -or (-not $dbPassword) -or (-not $dbName) -or (-not $dbPort)) { Say "  FEED SECTION : NOT MEASURED (-999)" ; Say "END-OF-RUN MARKER: FEED-503-COMPLETE" ; Finish $false }
$env:PGPASSWORD = $dbPassword
$okFile = Join-Path $env:TEMP ("feed_ok_{0}.sql" -f $RunStamp)
[IO.File]::WriteAllText($okFile, "SELECT 'ALIVE=' || 1::text;", (New-Object System.Text.UTF8Encoding($false)))
$null = & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -At -f $okFile 2>&1
$okRc = $LASTEXITCODE
$badFile = Join-Path $env:TEMP ("feed_bad_{0}.sql" -f $RunStamp)
[IO.File]::WriteAllText($badFile, "SELECT this_function_does_not_exist();", (New-Object System.Text.UTF8Encoding($false)))
$null = & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -At -f $badFile 2>&1
$badRc = $LASTEXITCODE
Say ("  instrument : valid query rc " + $okRc + " (expected 0) ; broken query rc " + $badRc + " (expected non-zero)")
Remove-Item -LiteralPath $okFile, $badFile -ErrorAction SilentlyContinue
if (($okRc -ne 0) -or ($badRc -eq 0)) { Say "  FEED SECTION : NOT MEASURED (-999) - the client cannot tell success from failure" ; $env:PGPASSWORD = '' ; Say "END-OF-RUN MARKER: FEED-503-COMPLETE" ; Finish $false }

$sampleFile = Join-Path $env:TEMP ("feed_sample_{0}.sql" -f $RunStamp)
$sampleText = @'
SELECT (SELECT count(*) FROM "RTSData_Interaction")::text || '|' ||
       (SELECT count(*) FROM "RTSData_UserStatusLog")::text || '|' ||
       (SELECT count(*) FROM "RTSData_UserStatus")::text || '|' ||
       coalesce((SELECT round(EXTRACT(EPOCH FROM (now() - max("UpdateTime"))))::text FROM "RTSData_Interaction"),'NULL') || '|' ||
       coalesce((SELECT round(EXTRACT(EPOCH FROM (now() - max("UpdateTime"))))::text FROM "RTSData_UserStatus"),'NULL') || '|' ||
       coalesce((SELECT max("UpdateTime")::text FROM "RTSData_UserStatus"),'NULL') || '|' ||
       coalesce((SELECT max("UpdateTime")::text FROM "RTSData_Interaction"),'NULL') || '|' ||
       (SELECT now()::text);
'@
[IO.File]::WriteAllText($sampleFile, $sampleText, (New-Object System.Text.UTF8Encoding($false)))
$interactionCounts = @() ; $logCounts = @() ; $statusCounts = @()
for ($sample = 1; $sample -le 3; $sample++) {
  $sampleOut = Join-Path $env:TEMP ("feed_s{0}_{1}.txt" -f $sample, $RunStamp)
  & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -At -o $sampleOut -f $sampleFile 2>&1 | Out-Null
  $sampleRc = $LASTEXITCODE
  $line = '' ; if (Test-Path -LiteralPath $sampleOut) { $line = (Get-Content -LiteralPath $sampleOut | Select-Object -First 1) }
  $fields = "$line".Split('|')
  if (($sampleRc -eq 0) -and ($fields.Count -eq 8)) {
    $interactionCounts += [int64]$fields[0] ; $logCounts += [int64]$fields[1] ; $statusCounts += [int64]$fields[2]
    Say ("  sample " + $sample + " at " + (Get-Date -Format 'HH:mm:ss') + " (machine clock) / db now " + $fields[7])
    Say ("      Interaction " + $fields[0] + "   UserStatusLog " + $fields[1] + "   UserStatus " + $fields[2])
    Say ("      newest row age, seconds : Interaction " + $fields[3] + "   UserStatus " + $fields[4])
    Say ("      newest UpdateTime       : UserStatus " + $fields[5] + " | Interaction " + $fields[6])
  } else { Say ("  sample " + $sample + " FAILED (rc " + $sampleRc + ") - counted as NOT MEASURED, not as zero") }
  Remove-Item -LiteralPath $sampleOut -ErrorAction SilentlyContinue
  if ($sample -lt 3) { Start-Sleep -Seconds 60 }
}
Remove-Item -LiteralPath $sampleFile -ErrorAction SilentlyContinue
$env:PGPASSWORD = ''
Say ""
if (($interactionCounts.Count -eq 3) -and ($logCounts.Count -eq 3)) {
  Say ("  growth over the window : Interaction " + ($interactionCounts[2] - $interactionCounts[0]) + "   UserStatusLog " + ($logCounts[2] - $logCounts[0]) + "   UserStatus " + ($statusCounts[2] - $statusCounts[0]))
  Say  "  A zero here is NOT a failure: it is a quiet window. What it is not is EVIDENCE OF HEALTH either."
} else { Say "  growth : NOT MEASURED (-999) - fewer than three good samples" }
Say ""
Say "  BASELINE, written down so the next rollout has something to compare against:"
if ($interactionCounts.Count -ge 1) {
  Say ("  BASELINE 2026-09-19 : Interaction=" + $interactionCounts[0] + " UserStatusLog=" + $logCounts[0] + " UserStatus=" + $statusCounts[0])
  Say  "  BASELINE ages and timestamps are in sample 1 above. Copy this line into the bus - it is the"
  Say  "  first time this system has a recorded normal; today it had none, and that is why a 19-hour-old"
  Say  "  row could not be called good or bad."
}
Rule

Say "SUMMARY - numbers only. No verdict about the feed is drawn here, by design."
Say ("  collector : " + $ReportLines.GetType().Name)
Say "END-OF-RUN MARKER: FEED-503-COMPLETE"
Finish $true
