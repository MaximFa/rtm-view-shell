<#
  PROBE  probe_234_20260919_acceptance-0f969d8.ps1
  BASED  ON probe_234_20260919_acceptance-0f969d8.ps1 - this morning's acceptance, same shape.
  UNIT   acceptance of the THIRD Shell package (0f969d8): five fixes, all three dictionaries changed.
  RE-TAKEN, NOT INHERITED  Every expectation below was re-measured for this flight. Carrying the
         previous flight's satellite sizes here would have made the check unable to fail: they are
         exactly the numbers this install had to move away from.
  WHAT   ProductVersion of the deployed Shell, satellites by SIZE, the adapter over three samples,
         liveness AS A PAIR - and, new here, WHO ANSWERS: the PID that owns the answering socket
         must be the PID of OUR service.
  WHY THE PID CHECK  On this machine a second, foreign CcDashboard installation
         (C:\Program Files\CcDashboard, service CcDashboard) listens on 127.0.0.1:5000, and an
         address-specific binding beats our wildcard one. Half a day on 19.09 was spent carrying that
         instance's 503 as a defect of ours. Liveness therefore takes the address from OUR service's
         own config AND proves the responder is ours. (234-lab.md section 4.)
  WHERE  SERVER 234. READ-ONLY: no service is started or stopped, no file is written outside
         C:\RTMView-Ops\output\.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_acceptance-0f969d8.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
$ExpectedCommit = '0f969d8'
$ExpectedWebDll = 'E9D27996B41BB797A1C67EA3DEEE1BAEF46A0D5029E9E904792E07BF67973560'
# RE-TAKEN for this flight, not inherited: the dictionaries changed, so these are the NEW sizes
$ExpectedSatellite = @{ 'he-IL' = 74752 ; 'ru-RU' = 84992 ; 'en-US' = 68096 }

function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
function ShaOf($path) { if (Test-Path -LiteralPath $path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash } else { return 'ABSENT' } }
function StateOf($serviceName) {
  $service = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $serviceName) -ErrorAction SilentlyContinue
  if ($null -eq $service) { return [pscustomobject]@{ State = 'ABSENT' ; ProcessId = -999 } }
  return [pscustomobject]@{ State = $service.State ; ProcessId = $service.ProcessId }
}

Say ("ACCEPTANCE OF 0f969d8  " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say  "READ ONLY. The adapter is NOT started by hand - the engine owns its lifecycle."
Say ("probe sha256 : " + (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Write-Report
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

Say "1  WHICH revision is deployed now"
Say ("  expected : ProductVersion carries " + $ExpectedCommit + " ; CcDashboard.Web.dll sha256 " + $ExpectedWebDll)
$mainDll = 'C:\RTMView\Shell\CcDashboard.Web.dll'
$deployedSha = ShaOf $mainDll
$productVersion = 'ABSENT'
if (Test-Path -LiteralPath $mainDll) { $productVersion = (Get-Item -LiteralPath $mainDll).VersionInfo.ProductVersion }
$versionCarries = ("$productVersion" -like ('*' + $ExpectedCommit + '*'))
Say ("  measured : ProductVersion " + $productVersion)
Say ("  measured : sha256 " + $deployedSha + "   equals the package build : " + ($deployedSha -eq $ExpectedWebDll))
Say ("  carries " + $ExpectedCommit + " : " + $versionCarries)
$revisionOk = ($versionCarries -and ($deployedSha -eq $ExpectedWebDll))
Rule

Say "2  satellites, by SIZE (byte equality between different builds is never used)"
$satellitesOk = $true
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satellitePath = 'C:\RTMView\Shell\' + $culture + '\CcDashboard.Web.resources.dll'
  if (-not (Test-Path -LiteralPath $satellitePath)) { Say ("  " + $culture.PadRight(6) + " ABSENT") ; $satellitesOk = $false ; continue }
  $actualSize = (Get-Item -LiteralPath $satellitePath).Length
  $sizeMatches = ($actualSize -eq $ExpectedSatellite[$culture])
  if (-not $sizeMatches) { $satellitesOk = $false }
  Say ("  " + $culture.PadRight(6) + " " + $actualSize + " B   expected " + $ExpectedSatellite[$culture] + " B   match " + $sizeMatches)
}
Rule

Say "3  WHEN the installer finished - taken from the ledger it wrote, not from my memory"
$ledgerPath = 'C:\RTMView-Ops\applied\_ledger.txt'
$installerFinished = $null
if (Test-Path -LiteralPath $ledgerPath) {
  $lastLine = (Get-Content -LiteralPath $ledgerPath | Where-Object { $_ -like ('*commit=' + $ExpectedCommit + '*') } | Select-Object -Last 1)
  Say ("  ledger line : " + $lastLine)
  $stampMatch = [regex]::Match("$lastLine", '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})')
  if ($stampMatch.Success) {
    $installerFinished = [datetime]::ParseExact($stampMatch.Groups[1].Value, 'yyyy-MM-dd HH:mm:ss', $null)
    Say ("  installer finished at : " + $installerFinished.ToString('yyyy-MM-dd HH:mm:ss') + "   (machine local clock; the ledger writes local time)")
  } else { Say "  the timestamp could not be parsed from that line - the elapsed numbers below say NOT MEASURED" }
} else { Say ("  " + $ledgerPath + " : ABSENT - elapsed since the install is NOT MEASURED") }
Rule

Say "4  THE ADAPTER - three samples, a minute apart, each with its own clock reading"
Say  "  The engine raises RTMTwilio_1; this probe never starts it. What is measured is whether it came back."
$engineStart = 'NOT MEASURED'
$engineNow = StateOf 'RTMService'
if ($engineNow.ProcessId -gt 0) {
  $engineProcess = Get-Process -Id $engineNow.ProcessId -ErrorAction SilentlyContinue
  if ($engineProcess) { $engineStart = $engineProcess.StartTime.ToString('yyyy-MM-dd HH:mm:ss') }
}
Say ("  RTMService   : " + $engineNow.State + "   pid " + $engineNow.ProcessId + "   started " + $engineStart)
$adapterStates = @()
for ($sample = 1; $sample -le 3; $sample++) {
  $adapterNow = StateOf 'RTMTwilio_1'
  $adapterStart = 'n/a'
  if ($adapterNow.ProcessId -gt 0) {
    $adapterProcess = Get-Process -Id $adapterNow.ProcessId -ErrorAction SilentlyContinue
    if ($adapterProcess) { $adapterStart = $adapterProcess.StartTime.ToString('yyyy-MM-dd HH:mm:ss') }
  }
  $adapterStates += $adapterNow.State
  Say ("  sample " + $sample + " at " + (Get-Date -Format 'HH:mm:ss') + " : RTMTwilio_1 " + $adapterNow.State + "   pid " + $adapterNow.ProcessId + "   started " + $adapterStart)
  if (($adapterNow.State -eq 'Running') -and ($null -ne $installerFinished) -and ($adapterStart -ne 'n/a')) {
    $cameUpAfter = ([datetime]$adapterStart - $installerFinished).TotalSeconds
    Say ("      came up " + [math]::Round($cameUpAfter,0) + " s after the installer finished - that number is what we will expect next time")
  }
  if ($sample -lt 3) { Start-Sleep -Seconds 60 }
}
$adapterRunning = ($adapterStates -contains 'Running')
$adapterAlwaysStopped = (@($adapterStates | Where-Object { $_ -ne 'Stopped' }).Count -eq 0)
Say ("  states seen : " + ($adapterStates -join ' , '))
Say ("  adapter came back on its own : " + $adapterRunning)
Rule

Say "5  liveness as a PAIR"
$curl = "$env:SystemRoot\System32\curl.exe"
$shellCfg = 'C:\RTMView\Shell\appsettings.json'
$httpOk = $false ; $negOk = $false ; $liveBase = 'NONE'
$targets = @()
if (Test-Path -LiteralPath $shellCfg) {
  $rawShell = Get-Content -LiteralPath $shellCfg -Raw -Encoding UTF8
  foreach ($urlMatch in [regex]::Matches($rawShell, '(?i)"(?:Url|Urls|ApplicationUrl)"\s*:\s*"([^"]+)"')) {
    foreach ($piece in ($urlMatch.Groups[1].Value -split ';')) {
      $addr = $piece.Trim()
      if ($addr) { $targets += $addr.TrimEnd('/').Replace('+','127.0.0.1').Replace('0.0.0.0','127.0.0.1').Replace('[::]','127.0.0.1').Replace('*','127.0.0.1') }
    }
  }
}
Say ("  addresses from the machine own config : " + $(if (@($targets).Count -gt 0) { ($targets -join ' , ') } else { 'NONE' }))
if (-not (Test-Path -LiteralPath $curl)) { Say "  curl.exe ABSENT - HTTP half NOT MEASURED" }
else {
  foreach ($base in @($targets)) {
    $code = (& $curl -k -s -o NUL -w '%{http_code}' --max-time 15 ($base + '/health')) 2>$null
    if ("$code" -eq '000') { Say ("  " + $base + '/health -> UNREACHABLE (not a liveness verdict)') }
    else {
      $body = (& $curl -k -s --max-time 15 ($base + '/health')) 2>$null
      Say ("  " + $base + '/health -> ' + $code + "   body " + $body)
      if (("$code" -eq '200') -and ($liveBase -eq 'NONE')) { $liveBase = $base ; $httpOk = $true }
    }
  }
  if ($liveBase -ne 'NONE') {
    $negCode = (& $curl -k -s -o NUL -w '%{http_code}' --max-time 15 ($liveBase + '/zzz-no-such-endpoint')) 2>$null
    Say ("  NEGCTL on " + $liveBase + " : /zzz -> " + $negCode + "   (must be neither 200 nor 000)")
    $negOk = (("$negCode" -ne '200') -and ("$negCode" -ne '000'))
  } else { Say "  HTTP half : NOT MEASURED - no address answered" }
}
$pipeName = ''
$rtmCfg = 'C:\RTMView\RTM\appsettings.json'
if (Test-Path -LiteralPath $rtmCfg) {
  $pipeMatch = [regex]::Match((Get-Content -LiteralPath $rtmCfg -Raw -Encoding UTF8), '(?i)PipeName[^:]*:\s*"([^"]*)"')
  if ($pipeMatch.Success) { $pipeName = $pipeMatch.Groups[1].Value }
}
$pipes = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) })
Say ("  engine PipeName from disk : " + $(if ($pipeName) { $pipeName } else { 'KEY NOT PRESENT' }))
Say ("  pipes visible in total    : " + @($pipes).Count)
$pipeServed = (($pipeName -ne '') -and ($pipes -contains $pipeName))
$pipeNeg = ($pipes -contains 'zzz-no-such-pipe-here')
Say ("  configured pipe served : " + $pipeServed + "   NEGCTL impossible pipe : " + $pipeNeg + " (must be False)")
# --- WHO ANSWERED: the responder must be OUR service, not the neighbour on the same port ---
$ourPid = 0
$ourSvc = Get-CimInstance Win32_Service -Filter "Name='RTMViewShell'" -ErrorAction SilentlyContinue
if ($null -ne $ourSvc) { $ourPid = [int]$ourSvc.ProcessId }
Say ("  our service RTMViewShell pid : " + $(if ($ourPid -gt 0) { $ourPid } else { 'NOT RUNNING' }))
$responderOk = $false
if ($liveBase -eq 'NONE') { Say "  OWNERSHIP : NOT MEASURED - no address answered" }
elseif ($ourPid -le 0) { Say "  OWNERSHIP : RED - our service has no process" }
else {
  $uri = [uri]$liveBase
  $port = $uri.Port
  $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
  Say ("  listeners on port " + $port + " : " + $listeners.Count)
  foreach ($listener in $listeners) {
    $owner = (Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue)
    $ownerPath = if ($owner) { try { $owner.Path } catch { 'path unavailable' } } else { 'gone' }
    Say ("    " + $listener.LocalAddress + ":" + $listener.LocalPort + "  pid " + $listener.OwningProcess + "  " + $ownerPath)
  }
  # Windows picks the address-specific binding over the wildcard one. Same rule here.
  $hostAddr = $uri.Host
  $exact = @($listeners | Where-Object { $_.LocalAddress -eq $hostAddr })
  $chosen = if ($exact.Count -gt 0) { $exact[0] } elseif ($listeners.Count -gt 0) { $listeners[0] } else { $null }
  if ($null -eq $chosen) { Say "  OWNERSHIP : RED - nobody listens on that port, yet something answered. Report it." }
  else {
    $responderOk = ([int]$chosen.OwningProcess -eq $ourPid)
    Say ("  the socket that served " + $liveBase + " belongs to pid " + $chosen.OwningProcess +
         " ; ours is " + $ourPid + "  ->  " + $(if ($responderOk) { 'OURS' } else { 'NOT OURS - this reading says nothing about our product' }))
    Say  "  NEGATIVE HALF: this comparison printed NOT OURS on 19.09 for 127.0.0.1:5000, where the"
    Say  "  foreign installation answers. It is able to fail, and it has."
  }
}
$livenessOk = ($httpOk -and $negOk -and $pipeServed -and (-not $pipeNeg) -and (@($pipes).Count -gt 0) -and $responderOk)
Say ("  LIVENESS (pair + responder is ours) : " + $livenessOk)
Rule

Say "6  the database names itself, and the feed as an OBSERVATION"
Say  "  The feed is NOT a gate here: an empty window is a quiet hour, not a failure (norm N-16),"
Say  "  and with the adapter down it is expected to stand still. The numbers are printed for the coordinator."
$psql = $null
foreach ($pgDir in @(Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
  $candidate = Join-Path $pgDir.FullName 'bin\psql.exe'
  if ((Test-Path -LiteralPath $candidate) -and ($null -eq $psql)) { $psql = $candidate }
}
$dbUser = '' ; $dbName = '' ; $dbPort = '' ; $dbPassword = ''
if (Test-Path -LiteralPath $shellCfg) {
  $rawShell2 = Get-Content -LiteralPath $shellCfg -Raw -Encoding UTF8
  $connMatch = [regex]::Match($rawShell2, '(?i)Password\s*=\s*([^;"]+)') ; if ($connMatch.Success) { $dbPassword = $connMatch.Groups[1].Value.Trim() }
  $connMatch = [regex]::Match($rawShell2, '(?i)(?:Username|User ID)\s*=\s*([^;"]+)') ; if ($connMatch.Success) { $dbUser = $connMatch.Groups[1].Value.Trim() }
  $connMatch = [regex]::Match($rawShell2, '(?i)Database\s*=\s*([^;"]+)') ; if ($connMatch.Success) { $dbName = $connMatch.Groups[1].Value.Trim() }
  $connMatch = [regex]::Match($rawShell2, '(?i)Port\s*=\s*(\d+)') ; if ($connMatch.Success) { $dbPort = $connMatch.Groups[1].Value }
}
Say ("  psql : " + $(if ($psql) { $psql } else { 'NOT FOUND' }) + " ; user " + $dbUser + " / db " + $dbName + " / port " + $dbPort + " / password " + $dbPassword.Length + " chars")
if ((-not $psql) -or (-not $dbPassword) -or (-not $dbName) -or (-not $dbPort)) { Say "  DATABASE SECTION : NOT MEASURED (-999)" }
else {
  $env:PGPASSWORD = $dbPassword
  $okFile = Join-Path $env:TEMP ("acc_ok_{0}.sql" -f $RunStamp)
  [IO.File]::WriteAllText($okFile, "SELECT 'ALIVE=' || 1::text;", (New-Object System.Text.UTF8Encoding($false)))
  $null = & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -At -f $okFile 2>&1
  $okRc = $LASTEXITCODE
  $badFile = Join-Path $env:TEMP ("acc_bad_{0}.sql" -f $RunStamp)
  [IO.File]::WriteAllText($badFile, "SELECT this_function_does_not_exist();", (New-Object System.Text.UTF8Encoding($false)))
  $null = & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -At -f $badFile 2>&1
  $badRc = $LASTEXITCODE
  Say ("  instrument : valid query rc " + $okRc + " (expected 0) ; broken query rc " + $badRc + " (expected non-zero)")
  if (($okRc -ne 0) -or ($badRc -eq 0)) { Say "  DATABASE SECTION : NOT MEASURED (-999) - the client cannot tell success from failure" }
  else {
    $queryFile = Join-Path $env:TEMP ("acc_q_{0}.sql" -f $RunStamp)
    $queryText = @'
SELECT 'whoami: db=' || current_database() || ' port=' || inet_server_port() || ' user=' || current_user;
SELECT 'server_version: ' || current_setting('server_version');
SELECT 'tenants total = ' || count(*)::text FROM tenants;
SELECT 'COUNT RTSData_Interaction = ' || count(*)::text FROM "RTSData_Interaction";
SELECT 'COUNT RTSData_UserStatusLog = ' || count(*)::text FROM "RTSData_UserStatusLog";
SELECT 'newest RTSData_UserStatus UpdateTime age s = ' || coalesce(round(EXTRACT(EPOCH FROM (now() - max("UpdateTime"))))::text,'NULL') FROM "RTSData_UserStatus";
SELECT 'COUNT RTSGrid_Metric = ' || count(*)::text FROM "RTSGrid_Metric";
SELECT 'NEGCTL to_regclass zzz_no_such_table = ' || coalesce(to_regclass('public."zzz_no_such_table"')::text,'NULL (correct)');
'@
    [IO.File]::WriteAllText($queryFile, $queryText, (New-Object System.Text.UTF8Encoding($false)))
    $queryOut = Join-Path $env:TEMP ("acc_q_{0}.txt" -f $RunStamp)
    $queryErr = Join-Path $OutputDir ("234_{0}_acceptance-0f969d8.err.txt" -f $RunStamp)
    & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -At -o $queryOut -f $queryFile 2> $queryErr
    $queryRc = $LASTEXITCODE
    if (Test-Path -LiteralPath $queryOut) { foreach ($row in (Get-Content -LiteralPath $queryOut -Encoding UTF8)) { Say ("      " + $row) } }
    $errBytes = 0 ; if (Test-Path -LiteralPath $queryErr) { $errBytes = (Get-Item -LiteralPath $queryErr).Length }
    Say ("  psql exit " + $queryRc + " ; stderr " + $errBytes + " bytes")
    Remove-Item -LiteralPath $queryFile, $queryOut -ErrorAction SilentlyContinue
  }
  Remove-Item -LiteralPath $okFile, $badFile -ErrorAction SilentlyContinue
  $env:PGPASSWORD = ''
}
Rule

Say "7  legacy RTM, read once more - not ours, never touched"
$legacyNow = StateOf 'RTM'
Say ("  RTM : " + $legacyNow.State + "   (was Running before the install and right after it)")
Rule

Say "VERDICT"
Say ("  revision deployed is " + $ExpectedCommit + " : " + $revisionOk)
Say ("  satellites by size                : " + $satellitesOk)
Say ("  liveness pair                     : " + $livenessOk)
Say ("  adapter came back on its own      : " + $adapterRunning)
if ($adapterAlwaysStopped) {
  Say  "  THE ADAPTER STAYED DOWN IN ALL THREE SAMPLES."
  Say  "  Next action, pre-blessed by the coordinator on 19.09: restart the ENGINE so it raises the adapter."
  Say  "  It is NOT a rollback: this package carries no RTM folder, data.sys is unchanged and the adapter"
  Say  "  config is byte-identical - three measured facts against blaming the rollout."
}
Say ("  collector : " + $ReportLines.GetType().Name)
Say "END-OF-RUN MARKER: ACCEPTANCE-0F969D8-COMPLETE"
$allOk = ($revisionOk -and $satellitesOk -and $livenessOk -and $adapterRunning)
Say ("  LAST LINE : " + $(if ($allOk) { 'PASS' } else { 'INCOMPLETE - read the sections; the feed is not a gate here' }))
Finish $allOk
