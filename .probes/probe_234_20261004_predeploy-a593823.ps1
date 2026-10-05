<#
  PROBE  probe_234_20261004_predeploy-a593823.ps1
  BASED  ON probe_234_20260926_predeploy-251ca40.ps1 - the shape that served the v4 Full flight.
  UNIT   the BEFORE half of the static-version rollout (v4 head e7eb243). What runs here now is
         a593823, so this file is named after a593823: a probe is named after the state it MEASURES.
  COMPOSITION, RE-MEASURED ON THE STATION RATHER THAN TAKEN FROM THE MESSAGE
         delta a593823..e7eb243 = 3 commits, product files TWO (App.razor, wwwroot/app.css),
         RTM/ 0, db/migrations/ 0, .resx 0. So: Mode Shell is lawful, and the satellite predicate
         INVERTS - with no .resx in the delta the three satellites must stay EQUAL afterwards.
         Equality is the PASS this time. Carrying the last flight's "must grow" rule would paint a
         correct install red on all three rows.
  ⚠ THE ADAPTER STILL DIES, AND THE COORDINATOR'S WORDING SAYS OTHERWISE
         The engine BINARY is not replaced - true. But Update-RTMView stops and starts BOTH services
         whatever the package carries, and the engine restart is what kills the adapter process.
         Evidence, not argument: the 20.09 flight carried ZERO files under RTM/ [measured] and its
         install report still shows RTMTwilio_1 Stopped at +0 s and Running at +20 s
         [234_20260920_213755_install-251ca40.txt]. So the ~27 s adapter window applies to THIS
         flight too and is named in the run-box before the click.
  WHAT IS NEW HERE  the static versions AS THE SERVER SERVES THEM. The whole point of this rollout
         is that the browser kept cached files; proving it means reading the HTML the live service
         returns, not the file in the repo. These are the BEFORE values the acceptance compares to.
  WHERE  SERVER 234. READ-ONLY: nothing is installed, started, stopped or written outside
         C:\RTMView-Ops\output\. The legacy C:\IceDash\RTM\RTM.exe is not touched.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_predeploy-a593823.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
function SafeCount($items) { if ($null -eq $items) { return -999 } ; return @($items).Count }
# CountOf separates the two things SafeCount could not tell apart: a search that legitimately found
# NOTHING (0) and a call that FAILED (-999). Get-ChildItem on an empty folder returns $null, and the
# old SafeCount printed that genuine zero as NOT MEASURED. Caught by tools/lint_probe.py, 2026-09-20.
function CountOf($block) { try { return @(& $block).Count } catch { return -999 } }
function ShaOf($path) { if (Test-Path $path) { return (Get-FileHash -Path $path -Algorithm SHA256).Hash } else { return 'ABSENT' } }

Say ("PRE-DEPLOY STATE  " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say  "READ ONLY. Nothing is started, stopped, installed or edited."
Say ("probe sha256 : " + (Get-FileHash -Path $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Write-Report
Rule

Say "G-1  instrument self-test on a known answer, before any live count"
Say "  expected : empty folder -> 0 (a real zero) ; a throwing call -> -999 (not measured) ; two items -> 2"
$selfDir = Join-Path $env:TEMP ("probe_selftest_{0}" -f $RunStamp)
New-Item -ItemType Directory -Force -Path $selfDir | Out-Null
$selfEmpty = CountOf { Get-ChildItem $selfDir -ErrorAction SilentlyContinue }
New-Item -ItemType File -Force -Path (Join-Path $selfDir 'a.txt') | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $selfDir 'b.txt') | Out-Null
$selfTwo = CountOf { Get-ChildItem $selfDir -ErrorAction SilentlyContinue }
$selfThrow = CountOf { throw "deliberate" }
Say ("  measured : empty " + $selfEmpty + " / two items " + $selfTwo + " / throwing " + $selfThrow)
Remove-Item $selfDir -Recurse -Force -ErrorAction SilentlyContinue
if (($selfEmpty -ne 0) -or ($selfTwo -ne 2) -or ($selfThrow -ne -999)) {
    Say "  *** the counting instrument cannot tell an empty result from a failure - every count below is void"
    Finish $false
}
Say "  G-1 PASS"
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  expected : name RTM and uuid E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing to measure"; Finish $false }
Say "  G0 PASS"
Rule

Say "1  services (Get-Service, read only)"
Say "  expected : RTMViewShell / RTMService / RTMTwilio_1 Running ; RTMApplyService ABSENT is NORMAL ;"
Say "             production RTM.Twilio and legacy RTM untouched, whatever their state"
foreach ($svc in @('RTMViewShell','RTMService','RTMTwilio_1','RTMApplyService','RTM.Twilio','RTM')) {
    $svcObj = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($null -eq $svcObj) { Say ("  " + $svc.PadRight(16) + " : ABSENT") }
    else { Say ("  " + $svc.PadRight(16) + " : " + $svcObj.Status + "   (StartType " + $svcObj.StartType + ")") }
}
Rule

Say "2  the deployed Shell - WHICH revision is actually on this machine"
Say "  expected for THIS flight : ProductVersion carries a593823 - the v4 Full package, installed 2026-09-26 19:56."
Say "  Source: the acceptance report 234_20260926_200146_acceptance-a593823.txt, which measured"
Say "  web.dll sha256 530121B84C3EB5070A77A1376CEB2039AE2EBA60268506DD09FED4183A66EAEC on this machine."
Say "  Anything else here means the machine is not where the coordinator and I think it is - STOP and report."
$shellDir = 'C:\RTMView\Shell'
$mainDll  = Join-Path $shellDir 'CcDashboard.Web.dll'
$mainExe  = Join-Path $shellDir 'CcDashboard.Web.exe'
foreach ($binPath in @($mainDll, $mainExe)) {
    if (Test-Path $binPath) {
        $verInfo = (Get-Item $binPath).VersionInfo
        Say ("  " + $binPath)
        Say ("      ProductVersion : " + $verInfo.ProductVersion)
        Say ("      FileVersion    : " + $verInfo.FileVersion)
        Say ("      sha256         : " + (ShaOf $binPath))
        Say ("      size/modified  : " + (Get-Item $binPath).Length + " bytes / " + (Get-Item $binPath).LastWriteTime)
    } else { Say ("  " + $binPath + " : ABSENT") }
}
Rule

Say "3  the four files of the delta, AS THEY EXIST ON THIS MACHINE"
Say "  The product half of this delta is TWO files: App.razor and wwwroot/app.css. No .resx at all."
Say "  THEREFORE THE SATELLITE PREDICATE IS INVERTED FOR THIS FLIGHT: the three sizes below must be"
Say "  UNCHANGED afterwards. Equality is the pass; a satellite that MOVED would mean something"
Say "  reached the dictionaries that this delta does not contain, and that is the finding to report."
Say "  So the before/after pair has to stand on the assemblies. This section measures what is really there,"
Say "  it does not assume: first it asks whether any source files exist under the deployed tree at all."
$razorFound = CountOf { Get-ChildItem -Path $shellDir -Filter *.razor -Recurse -ErrorAction SilentlyContinue }
$resxFound  = CountOf { Get-ChildItem -Path $shellDir -Filter *.resx  -Recurse -ErrorAction SilentlyContinue }
$dllFound   = CountOf { Get-ChildItem -Path $shellDir -Filter *.dll   -Recurse -ErrorAction SilentlyContinue }
Say ("  .razor files under the deployed tree : " + $razorFound + "   (expected 0)")
Say ("  .resx  files under the deployed tree : " + $resxFound  + "   (expected 0)")
Say ("  POSCTL .dll files under the same tree: " + $dllFound   + "   (must be non-zero, else this search is blind)")
if ($dllFound -le 0) { Say "  *** the search itself found no assemblies - the two zeroes above prove nothing" }
Say "  satellite assemblies carrying the translations (this is where the two .resx end up):"
foreach ($culture in @('he-IL','ru-RU','en-US','ru','he')) {
    $sat = Join-Path (Join-Path $shellDir $culture) 'CcDashboard.Web.resources.dll'
    if (Test-Path $sat) {
        Say ("  " + $culture.PadRight(6) + " : " + (ShaOf $sat) + "   " + (Get-Item $sat).Length + " bytes   " + (Get-Item $sat).LastWriteTime)
    } else { Say ("  " + $culture.PadRight(6) + " : ABSENT") }
}
Rule

Say "4  adapter log4net.config - the open condition from the backlog, carried since 08 September"
Say "  expected sha256 : 1D520F4D7AD2451BBBA4BD6CB7BAAFD0BE3C06AB407C8DD1ACD86D7FAE613FA2"
$adapterCfgDir = 'C:\RTMView\RTM.Twilio'
$log4 = Join-Path $adapterCfgDir 'log4net.config'
$log4Sha = ShaOf $log4
Say ("  measured sha256 : " + $log4Sha)
Say ("  match : " + ($log4Sha -eq '1D520F4D7AD2451BBBA4BD6CB7BAAFD0BE3C06AB407C8DD1ACD86D7FAE613FA2'))
$adapterJson = Join-Path $adapterCfgDir 'appsettings.json'
if (Test-Path $adapterJson) {
    $rawAdapter = Get-Content $adapterJson -Raw -Encoding UTF8
    $mLog = [regex]::Match($rawAdapter, '(?i)LogConfig[^:]*:\s*"([^"]*)"')
    $mPipe = [regex]::Match($rawAdapter, '(?i)PipeName[^:]*:\s*"([^"]*)"')
    Say ("  adapter appsettings sha256 : " + (ShaOf $adapterJson))
    Say ("  LogConfig points at : " + $(if ($mLog.Success) { $mLog.Groups[1].Value } else { 'KEY NOT PRESENT' }))
    Say ("  PipeName            : " + $(if ($mPipe.Success) { $mPipe.Groups[1].Value } else { 'KEY NOT PRESENT' }))
} else { Say ("  " + $adapterJson + " : ABSENT") }
Rule

Say "4b  ROLLBACK FLOOR and the package to be installed - both named as ARTEFACTS, with hashes"
$floorZip = 'C:\RTMView-Ops\incoming\26092026.1937.zip'
Say "  FLOOR - the package that is running right now (a593823, the Full package of 26.09)."
$floorExpected = 'C8DCFAEB9B6DCE8133E163F910C4C84517268D5C01201B34F81DAC3E314E9ADF'
if (-not (Test-Path -LiteralPath $floorZip)) {
    Say ("  shell floor          : ABSENT at " + $floorZip + "   <- STOP, report, do not build the install box")
} else {
    $floorItem = Get-Item -LiteralPath $floorZip
    $floorActual = (Get-FileHash -LiteralPath $floorZip -Algorithm SHA256).Hash
    Say ("  shell floor          : " + (Split-Path -Leaf $floorZip) + "   " + $floorItem.Length + " B")
    Say ("  " + ' '.PadRight(20) + "   expected " + $floorExpected)
    Say ("  " + ' '.PadRight(20) + "   measured " + $floorActual + "   match: " + ($floorActual -eq $floorExpected))
}
Say ""
Say "  ENGINE FLOOR - NOT named from memory. This flight replaces the engine, and a Shell package"
Say "  cannot undo that. Every RTM package on this disk is listed below with its hash; which one is"
Say "  the floor is decided from these numbers, not from recollection. NONE present is a STOP."
$rtmPackages = CountOf { Get-ChildItem 'C:\RTMView-Ops\incoming' -Filter *RTM*.zip -ErrorAction SilentlyContinue }
Say ("  RTM packages found in incoming : " + $rtmPackages)
if ($rtmPackages -le 0) {
    Say "  *** NO RTM PACKAGE ON THIS DISK. There is no engine floor. STOP - do not build the install box."
} else {
    foreach ($rtmZip in (Get-ChildItem 'C:\RTMView-Ops\incoming' -Filter *RTM*.zip -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)) {
        Say ("    " + $rtmZip.Name.PadRight(32) + " " + $rtmZip.Length + " B   " + $rtmZip.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + "   " + (ShaOf $rtmZip.FullName))
    }
}
$incomingZips = CountOf { Get-ChildItem 'C:\RTMView-Ops\incoming' -Filter *.zip -ErrorAction SilentlyContinue }
Say ("  POSCTL packages visible in incoming : " + $incomingZips + "   (a zero here means the search is blind, not that the floor is gone)")
Say  "  The floor is a FILE that exists and hashes correctly - that is what makes rollback a plan"
Say  "  rather than an intention. It is not deleted by this run nor by the install that follows."
Rule

Say "4c  THE ENGINE AND THE ADAPTER - the BEFORE of the pid predicate"
Say  "  The acceptance of this flight cannot use the word Running: the adapter is Running now and will"
Say  "  be Running afterwards. What proves it came back is a DIFFERENT pid than the one printed here."
$engineDir = 'C:\RTMView\RTM'
foreach ($binName in @('RTM.dll','RTM.exe')) {
    $binPath = Join-Path $engineDir $binName
    if (Test-Path -LiteralPath $binPath) {
        $binInfo = (Get-Item -LiteralPath $binPath).VersionInfo
        Say ("  " + $binPath)
        Say ("      ProductVersion : " + $binInfo.ProductVersion)
        Say ("      sha256         : " + (ShaOf $binPath))
        Say ("      size/modified  : " + (Get-Item -LiteralPath $binPath).Length + " bytes / " + (Get-Item -LiteralPath $binPath).LastWriteTime)
    } else { Say ("  " + $binPath + " : ABSENT") }
}
foreach ($svcName in @('RTMService','RTMTwilio_1','RTMViewShell')) {
    $svcObj = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $svcName) -ErrorAction SilentlyContinue
    if ($null -eq $svcObj) { Say ("  " + $svcName.PadRight(14) + " : ABSENT") ; continue }
    $procObj = Get-Process -Id $svcObj.ProcessId -ErrorAction SilentlyContinue
    $startedAt = $(if ($procObj) { $procObj.StartTime.ToString('yyyy-MM-dd HH:mm:ss') } else { 'NOT MEASURED - no process for that pid' })
    Say ("  " + $svcName.PadRight(14) + " : " + $svcObj.State + "   pid " + $svcObj.ProcessId + "   started " + $startedAt)
}
Say  "  ^ RTMTwilio_1 pid above is the number the acceptance compares against. EQUAL pid afterwards"
Say  "  means the adapter never went down - which contradicts the open subject and is a FINDING,"
Say  "  not a pass. The legacy service RTM is read below and never restarted by us."
$legacySvc = Get-CimInstance Win32_Service -Filter "Name='RTM'" -ErrorAction SilentlyContinue
Say ("  legacy RTM     : " + $(if ($null -eq $legacySvc) { 'ABSENT' } else { $legacySvc.State + "   pid " + $legacySvc.ProcessId }) + "   (not ours, never touched)")
Rule

Say "5  liveness as a PAIR - an address that does not answer is UNREACHABLE, not a verdict"
$curl = "$env:SystemRoot\System32\curl.exe"
$shellCfg = Join-Path $shellDir 'appsettings.json'
$httpOk = $false ; $negOk = $false ; $liveBase = 'NONE'
$targets = @()
if (Test-Path $shellCfg) {
    $rawShell = Get-Content $shellCfg -Raw -Encoding UTF8
    Say ("  Shell appsettings sha256 : " + (ShaOf $shellCfg))
    foreach ($urlMatch in [regex]::Matches($rawShell, '(?i)"(?:Url|Urls|ApplicationUrl)"\s*:\s*"([^"]+)"')) {
        foreach ($piece in ($urlMatch.Groups[1].Value -split ';')) {
            $addr = $piece.Trim()
            if ($addr) { $targets += $addr.TrimEnd('/').Replace('+','127.0.0.1').Replace('0.0.0.0','127.0.0.1').Replace('[::]','127.0.0.1').Replace('*','127.0.0.1') }
        }
    }
    foreach ($addr in @($targets)) {
        $portMatch = [regex]::Match($addr, '^(https?)://[^/:]+(?::(\d+))?')
        if ($portMatch.Success) {
            $loop = $portMatch.Groups[1].Value + '://127.0.0.1' + $(if ($portMatch.Groups[2].Success) { ':' + $portMatch.Groups[2].Value } else { '' })
            if ($targets -notcontains $loop) { $targets += $loop }
        }
    }
} else { Say ("  " + $shellCfg + " : ABSENT") }
Say ("  addresses to try, from the machine s own config : " + $(if (@($targets).Count -gt 0) { ($targets -join ' , ') } else { 'NONE' }))
if (-not (Test-Path $curl)) { Say "  curl.exe ABSENT - the HTTP half is NOT MEASURED (this says nothing about the product)" }
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
        $neg = (& $curl -k -s -o NUL -w '%{http_code}' --max-time 15 ($liveBase + '/zzz-no-such-endpoint')) 2>$null
        Say ("  NEGCTL on the answering address " + $liveBase + " : /zzz -> " + $neg + "   (must be neither 200 nor 000)")
        $negOk = (("$neg" -ne '200') -and ("$neg" -ne '000'))
    } else { Say "  HTTP half : NOT MEASURED - no address answered" }
}
$pipeName = ''
$rtmCfg = 'C:\RTMView\RTM\appsettings.json'
if (Test-Path $rtmCfg) {
    $pipeMatch = [regex]::Match((Get-Content $rtmCfg -Raw -Encoding UTF8), '(?i)PipeName[^:]*:\s*"([^"]*)"')
    if ($pipeMatch.Success) { $pipeName = $pipeMatch.Groups[1].Value }
}
$pipes = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) })
$pipeTotal = SafeCount $pipes
Say ("  engine PipeName from disk : " + $(if ($pipeName) { $pipeName } else { 'KEY NOT PRESENT' }))
Say ("  pipes visible in total    : " + $pipeTotal + "   (a zero here means the measurement is broken, not that there are none)")
$served = (($pipeName -ne '') -and ($pipes -contains $pipeName))
$negPipe = ($pipes -contains 'zzz-no-such-pipe-here')
Say ("  configured pipe served : " + $served + "   NEGCTL impossible pipe served : " + $negPipe + " (must be False)")
Say ("  LIVENESS (both halves, negative controls included) : " + ($httpOk -and $negOk -and $served -and (-not $negPipe) -and ($pipeTotal -gt 0)))
Rule

Say "5b  STATIC VERSIONS AS THE SERVER SERVES THEM - the BEFORE of this flight is predicate"
Say  "  This rollout exists because browsers kept cached copies: the operator saw no change after"
Say  "  26.09. Proving the fix means reading the HTML the LIVE SERVICE returns, not the file in the"
Say  "  repository. Expected here, before the measurement, from the deployed revision a593823:"
Say  "    app.css?v=32 · daytrendChart.js?v=3 · agentStateDistributionChart.js?v=3"
Say  "    CcDashboard.Web.styles.css with NO version at all · wallboard-skin.css?v=1"
Say  "  After the install those five must read v=33, v=4, v=4, v=1, v=2. These are the numbers the"
Say  "  acceptance compares against, and they are taken from the machine, not from the branch."
if ((-not (Test-Path $curl)) -or ($liveBase -eq 'NONE')) {
    Say "  NOT MEASURED - no answering address or no curl. This is a gap in the BEFORE half, say so."
} else {
    # -L: the root answers 302 -> /screens -> /login?ReturnUrl=/screens, and ONLY that landing
    # page carries the asset links. Without it this read returned a 597-byte redirect wrapper
    # and zero assets [measured 2026-10-04 13:26 on 234].
    $indexHtml = (& $curl -k -sL --max-time 25 $liveBase) 2>$null
    $htmlLength = 0
    if ($indexHtml) { $htmlLength = ("$indexHtml").Length }
    Say ("  HTML served from " + $liveBase + " : " + $htmlLength + " characters")
    if ($htmlLength -le 0) {
        Say "  *** EMPTY BODY - that is a broken read, not a page without versions. NOT MEASURED."
    } else {
        $assetMatches = [regex]::Matches("$indexHtml", '(?i)([A-Za-z0-9._-]+\.(?:css|js))(\?v=([0-9]+))?')
        $seen = @{}
        foreach ($assetMatch in $assetMatches) {
            $assetName = $assetMatch.Groups[1].Value
            $assetVer  = $(if ($assetMatch.Groups[3].Success) { 'v=' + $assetMatch.Groups[3].Value } else { 'NO VERSION' })
            if (-not $seen.ContainsKey($assetName)) { $seen[$assetName] = $assetVer }
        }
        foreach ($assetName in ($seen.Keys | Sort-Object)) { Say ("    " + $assetName.PadRight(38) + $seen[$assetName]) }
        Say ("  distinct assets found : " + $seen.Count)
        Say  "  A ZERO HERE HAS TWO POSSIBLE CAUSES AND THIS LINE USED TO NAME ONLY ONE:"
        Say  "  either the parser missed them, or THE WRONG PAGE WAS FETCHED. On 2026-10-04 it was"
        Say  "  the second - a 597-byte redirect wrapper - and the message pointed at the parser,"
        Say  "  which is the wrong suspect. Check the byte count above before blaming the regex."
    }
}
Rule

Say "6  the database names itself"
$psql = $null
foreach ($pgDir in @(Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $cand = Join-Path $pgDir.FullName 'bin\psql.exe'
    if ((Test-Path $cand) -and ($null -eq $psql)) { $psql = $cand }
}
$dbUser = '' ; $dbName = '' ; $dbPort = '' ; $dbPw = ''
if (Test-Path $shellCfg) {
    $rawShell2 = Get-Content $shellCfg -Raw -Encoding UTF8
    $connMatch = [regex]::Match($rawShell2, '(?i)Password\s*=\s*([^;"]+)') ; if ($connMatch.Success) { $dbPw = $connMatch.Groups[1].Value.Trim() }
    $connMatch = [regex]::Match($rawShell2, '(?i)(?:Username|User ID)\s*=\s*([^;"]+)') ; if ($connMatch.Success) { $dbUser = $connMatch.Groups[1].Value.Trim() }
    $connMatch = [regex]::Match($rawShell2, '(?i)Database\s*=\s*([^;"]+)') ; if ($connMatch.Success) { $dbName = $connMatch.Groups[1].Value.Trim() }
    $connMatch = [regex]::Match($rawShell2, '(?i)Port\s*=\s*(\d+)') ; if ($connMatch.Success) { $dbPort = $connMatch.Groups[1].Value }
}
Say ("  psql : " + $(if ($psql) { $psql } else { 'NOT FOUND' }))
Say ("  connection taken from the machine s own Shell config : user " + $dbUser + " / db " + $dbName + " / port " + $dbPort + " / password " + $dbPw.Length + " chars (value never printed)")
if ((-not $psql) -or (-not $dbPw) -or (-not $dbName) -or (-not $dbPort)) {
    Say "  DATABASE SECTION : NOT MEASURED (-999) - no client or no credentials on the machine. This is a gap, not a zero."
} else {
    $env:PGPASSWORD = $dbPw
    $okSql = Join-Path $env:TEMP ("predeploy_ok_{0}.sql" -f $RunStamp)
    [IO.File]::WriteAllText($okSql, "SELECT 'ALIVE=' || 1::text;", (New-Object System.Text.UTF8Encoding($false)))
    $null = & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -At -f $okSql 2>&1
    $okRc = $LASTEXITCODE
    $badSql = Join-Path $env:TEMP ("predeploy_bad_{0}.sql" -f $RunStamp)
    [IO.File]::WriteAllText($badSql, "SELECT this_function_does_not_exist();", (New-Object System.Text.UTF8Encoding($false)))
    $null = & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -At -f $badSql 2>&1
    $badRc = $LASTEXITCODE
    Say ("  instrument : valid query rc " + $okRc + " (expected 0) ; deliberately broken query rc " + $badRc + " (expected non-zero)")
    if (($okRc -ne 0) -or ($badRc -eq 0)) {
        Say "  DATABASE SECTION : NOT MEASURED (-999) - the client cannot tell success from failure here"
    } else {
        $qSql = Join-Path $env:TEMP ("predeploy_q_{0}.sql" -f $RunStamp)
        $qText = @'
SELECT 'whoami: db=' || current_database() || ' port=' || inet_server_port() || ' user=' || current_user;
SELECT 'server_version: ' || current_setting('server_version');
SELECT 'tenants total = ' || count(*)::text FROM tenants;
SELECT 'tenant | ' || "Id" || ' | ' || "Slug" || ' | ' || "Status" FROM tenants ORDER BY "Slug";
SELECT 'COUNT RTSGrid_Metric = ' || count(*)::text FROM "RTSGrid_Metric";
SELECT 'COUNT NGC_BusinessUnit = ' || count(*)::text FROM "NGC_BusinessUnit";
SELECT 'COUNT NGC_Queues = ' || count(*)::text FROM "NGC_Queues";
SELECT 'NEGCTL to_regclass zzz_no_such_table = ' || coalesce(to_regclass('public."zzz_no_such_table"')::text,'NULL (correct)');
'@
        [IO.File]::WriteAllText($qSql, $qText, (New-Object System.Text.UTF8Encoding($false)))
        $qOut = Join-Path $env:TEMP ("predeploy_q_{0}.txt" -f $RunStamp)
        $qErr = Join-Path $OutputDir ("234_{0}_predeploy-a593823.err.txt" -f $RunStamp)
        & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p $dbPort -U $dbUser -d $dbName -At -o $qOut -f $qSql 2> $qErr
        $qRc = $LASTEXITCODE
        if (Test-Path $qOut) { foreach ($row in (Get-Content $qOut -Encoding UTF8)) { Say ("      " + $row) } }
        $errSize = 0 ; if (Test-Path $qErr) { $errSize = (Get-Item $qErr).Length }
        Say ("  psql exit code " + $qRc + " ; stderr file " + $errSize + " bytes (anything above 0 is a finding: " + $qErr + ")")
        Remove-Item $qSql, $qOut -ErrorAction SilentlyContinue
    }
    Remove-Item $okSql, $badSql -ErrorAction SilentlyContinue
    $env:PGPASSWORD = ''
}
Rule

Say "7  the ops root and room to work"
foreach ($opsDir in @('C:\RTMView-Ops','C:\RTMView-Ops\incoming','C:\RTMView-Ops\output','C:\RTMView-Ops\backup')) {
    if (Test-Path $opsDir) {
        $entryCount = CountOf { Get-ChildItem $opsDir -ErrorAction SilentlyContinue }
        Say ("  " + $opsDir.PadRight(30) + " : present, " + $entryCount + " entries")
    } else { Say ("  " + $opsDir.PadRight(30) + " : ABSENT") }
}
$drive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
if ($null -ne $drive) { Say ("  free space on C: " + [math]::Round($drive.Free/1GB,1) + " GB of " + [math]::Round(($drive.Free+$drive.Used)/1GB,1) + " GB") }
else { Say "  free space on C: NOT MEASURED (-999)" }
Rule

Say "SUMMARY - readings only, no verdict about the rollout is drawn here"
Say ("  report        : " + $ReportPath)
Say ("  collector     : " + $ReportLines.GetType().Name + " (must be ArrayList)")
Say  "  Nothing was started, stopped, installed or edited."
Say  "END-OF-RUN MARKER: PREDEPLOY-A593823-COMPLETE"
Finish $true
