<#
  PROBE  probe_234_20260920_predeploy-state.ps1
  BASED  ON probe_234_20260919_predeploy-state.ps1 - the same shape, used before the d702e2d install.
  UNIT   the 'BEFORE' half for the third package (20092026.1110_Shell.zip, built from 0f969d8).
  WHAT   What the machine carries right now, as NUMBERS: deployed revision, machine-config hashes,
         data.sys, the three satellite SIZES, services, legacy RTM, and the rollback floor named as
         an ARTEFACT (a file with a hash), not as the phrase 'we will put it back'.
  WHY THE SATELLITE SIZES MATTER HERE  They are the 'before' of the main predicate of this flight:
         after the install all three must DIFFER from what is printed here and MATCH the package.
  WHERE  SERVER 234. READ-ONLY: nothing is installed, started, stopped or written outside
         C:\RTMView-Ops\output\.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_predeploy-state-pkg3.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
function SafeCount($items) { if ($null -eq $items) { return -999 } ; return @($items).Count }
function ShaOf($path) { if (Test-Path $path) { return (Get-FileHash -Path $path -Algorithm SHA256).Hash } else { return 'ABSENT' } }

Say ("PRE-DEPLOY STATE  " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say  "READ ONLY. Nothing is started, stopped, installed or edited."
Say ("probe sha256 : " + (Get-FileHash -Path $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Write-Report
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
Say "  expected, inherited and under test : ProductVersion carries 0ae2102"
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
Say "  The delta is two .razor and two .resx. Razor and resx are COMPILED - they are not deployed as files."
Say "  So the before/after pair has to stand on the assemblies. This section measures what is really there,"
Say "  it does not assume: first it asks whether any source files exist under the deployed tree at all."
$razorFound = SafeCount (Get-ChildItem -Path $shellDir -Filter *.razor -Recurse -ErrorAction SilentlyContinue)
$resxFound  = SafeCount (Get-ChildItem -Path $shellDir -Filter *.resx  -Recurse -ErrorAction SilentlyContinue)
$dllFound   = SafeCount (Get-ChildItem -Path $shellDir -Filter *.dll   -Recurse -ErrorAction SilentlyContinue)
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
$floorZip = 'C:\RTMView-Ops\incoming\19092026.1544_Shell.zip'
$newZip   = 'C:\RTMView-Ops\incoming\20092026.1110_Shell.zip'
foreach ($pair in @(@('rollback floor', $floorZip, 'A40603C2C94485185AACE346E4514F922900464345F0FC81D75105B0437D7AA9'),
                    @('package to install', $newZip, '85A6F2706D62C51E8486DFB9E7E93538E65EB7960FF17B65FA2991761A60903D'))) {
  $label = $pair[0] ; $path = $pair[1] ; $expected = $pair[2]
  if (-not (Test-Path -LiteralPath $path)) { Say ("  " + $label.PadRight(20) + " : ABSENT at " + $path + "   <- STOP, report") ; continue }
  $item = Get-Item -LiteralPath $path
  $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
  Say ("  " + $label.PadRight(20) + " : " + (Split-Path -Leaf $path) + "   " + $item.Length + " B")
  Say ("  " + ' '.PadRight(20) + "   expected " + $expected)
  Say ("  " + ' '.PadRight(20) + "   measured " + $actual + "   match: " + ($actual -eq $expected))
}
Say  "  The floor is a FILE that exists and hashes correctly - that is what makes rollback a plan"
Say  "  rather than an intention. It is not deleted by this run nor by the install that follows."
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
        $qErr = Join-Path $OutputDir ("234_{0}_predeploy-state.err.txt" -f $RunStamp)
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
        $entryCount = SafeCount (Get-ChildItem $opsDir -ErrorAction SilentlyContinue)
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
Say  "END-OF-RUN MARKER: PREDEPLOY-STATE-COMPLETE"
Finish $true
