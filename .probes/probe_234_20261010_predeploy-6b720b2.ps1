<#
  PROBE  probe_234_20261010_predeploy-6b720b2.ps1
  UNIT   pre-deploy state of 234 before the Shell flight v4 6b720b2 (package 10102026.1102_Shell.zip).
  WHY IT EXISTS  every number I hold about this machine is FIVE DAYS OLD - they come from the
         PREVIOUS flight's acceptance [234_20261005_090548_acceptance-e7eb243.txt]. A five-day-old
         number is an expectation, not a measurement, so this run re-takes all of them and prints
         the expectation BEFORE the measurement on every row.
  WHAT IT ADDS OVER THE PREVIOUS PRE-DEPLOY PROBE, and it is the point
         It reads the FIVE ASSET VERSIONS THE LIVE SERVER SERVES RIGHT NOW. Those are the "before"
         half of the acceptance pairs. Without them the acceptance can only prove the new number is
         present, never that the old one is gone - and presence alone was satisfied once already by
         an HTML served from a place a flight had not reached.
  THE FETCH IS GATED BEFORE IT IS TRUSTED  root redirects to /screens and that to /login, so -L is
         passed; a body under 2000 chars is a redirect wrapper and fails the gate instead of being
         searched. Measured 2026-10-04: a fetch without -L returned 597 bytes and the fault looked
         like a bad pattern. It was the fetch.
  WHERE  SERVER 234. READ ONLY. Nothing is installed, no service is started, stopped or configured.
         The package is NOT copied by this run. Legacy RTM is not touched.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_predeploy-6b720b2.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
$script:SayCount = 0
function Say($text) {
  [void]$ReportLines.Add("$text"); Write-Host "$text"
  $script:SayCount++
  if (($script:SayCount % 25) -eq 0) { Write-Report }
}
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ''; Write-Host ('REPORT: ' + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
trap {
  [void]$ReportLines.Add('*** TERMINATING ERROR - the run stops here, and this is why:')
  [void]$ReportLines.Add('    message : ' + $_.Exception.Message)
  [void]$ReportLines.Add('    at line : ' + $_.InvocationInfo.ScriptLineNumber + '  ' + ("" + $_.InvocationInfo.Line).Trim())
  Write-Report
  Write-Host '*** TERMINATING ERROR written into the report'
  continue
}
function ShaOf($path) { if (Test-Path -LiteralPath $path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash } else { 'ABSENT' } }
function StateOf($name) {
  $service = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $name) -ErrorAction SilentlyContinue
  if ($null -eq $service) { return [pscustomobject]@{ State = 'ABSENT' ; ProcessId = 0 } }
  return [pscustomobject]@{ State = $service.State ; ProcessId = $service.ProcessId }
}

# EXPECTATIONS, each with the file it came from. Five days old - that is why they are re-taken.
$ExpectWebDll   = '098D079358D78E0A7DE53F1DFC54A8A6E08D125830DD2CD74DE12308C7B24AE1'
$ExpectEngine   = '097F087D66497A4C59C5216E8BB46E1C4F49739A2B2A2A6621483BD0DC1C10AB'
$ExpectSatellite = @{ 'he-IL' = 77312 ; 'ru-RU' = 87040 ; 'en-US' = 70144 }
$FloorShellZip  = 'C:\RTMView-Ops\incoming\04102026.1459_Shell.zip'
$FloorShellSha  = 'E91D677CE111327FA471F33DCEFA08A22CBAFE641F66AB7A8680CDC42AFBBF49'
$FloorFullZip   = 'C:\RTMView-Ops\incoming\26092026.1937.zip'
$FloorFullSha   = 'C8DCFAEB9B6DCE8133E163F910C4C84517268D5C01201B34F81DAC3E314E9ADF'
$IncomingPkg    = 'C:\RTMView-Ops\incoming\10102026.1102_Shell.zip'
$IncomingSha    = 'EF8E7E4552158B94A635D5FE042AA30391AFE047EAD6621E586DAA32028E9731'
$IncomingBytes  = 54090340

Say ("PRE-DEPLOY 6b720b2  " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say  "READ ONLY. Nothing installed, no service touched, the package is not copied by this run."
Say ("probe sha256 : " + (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say  "  expected : name RTM and uuid E9516FFB-3068-47EA-8860-6A9D764325E6"
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say '  *** NOT server 234 - refusing to measure'; Finish $false }
Say "  G0 PASS"
Rule

Say "G1  SELF-TEST of the hash instrument, before it judges anything"
$selfTest = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::ASCII.GetBytes('abc'))) -Algorithm SHA256).Hash
Say ("  sha256('abc') measured : " + $selfTest)
Say  "  sha256('abc') expected : BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"
if ($selfTest -ne 'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD') { Say '  *** the hash instrument is wrong - every number below would be worthless'; Finish $false }
Say "  G1 PASS"
Rule

Say "1  WHAT IS DEPLOYED NOW - expectation printed first, then the measurement"
$webNow = ShaOf 'C:\RTMView\Shell\CcDashboard.Web.dll'
Say ("  web.dll expected (from the 05.10 acceptance) : " + $ExpectWebDll)
Say ("  web.dll measured now                         : " + $webNow)
Say ("  the machine still runs e7eb243 : " + ($webNow -eq $ExpectWebDll) + "   (False means something landed here in these five days - a finding, and the flight stops)")
$engineNow = ShaOf 'C:\RTMView\RTM\RTM.dll'
Say ("  RTM.dll expected : " + $ExpectEngine)
Say ("  RTM.dll measured : " + $engineNow + "   match: " + ($engineNow -eq $ExpectEngine))
$dataSysNow = ShaOf 'C:\RTMView\RTM\data.sys'
Say ("  data.sys now     : " + $dataSysNow + "   (recorded so the install can prove it was not touched)")
$shellCfgNow = ShaOf 'C:\RTMView\Shell\appsettings.json'
$log4netNow  = ShaOf 'C:\RTMView\RTM.Twilio\log4net.config'
Say ("  Shell\appsettings.json    : " + $shellCfgNow)
Say ("  RTM.Twilio\log4net.config : " + $log4netNow)
$stateOk = (($webNow -eq $ExpectWebDll) -and ($engineNow -eq $ExpectEngine))
Rule

Say "2  SATELLITES - this delta has no .resx, so they must not move during the install"
$satellitesOk = $true
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satellitePath = 'C:\RTMView\Shell\' + $culture + '\CcDashboard.Web.resources.dll'
  $expected = $ExpectSatellite[$culture]
  if (-not (Test-Path -LiteralPath $satellitePath)) { Say ("  " + $culture.PadRight(6) + " ABSENT - RED") ; $satellitesOk = $false ; continue }
  $satelliteSize = (Get-Item -LiteralPath $satellitePath).Length
  if ($satelliteSize -ne $expected) { $satellitesOk = $false }
  Say ("  " + $culture.PadRight(6) + " expected " + $expected + "   measured " + $satelliteSize + "   match: " + ($satelliteSize -eq $expected) + "   sha " + (ShaOf $satellitePath))
}
Say ("  satellites as expected : " + $satellitesOk)
Rule

Say "3  SERVICES and their pids - the install report compares against THESE numbers"
foreach ($name in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $service = StateOf $name
  Say ("  {0,-14} {1}   pid {2}" -f $name, $service.State, $service.ProcessId)
}
$legacy = StateOf 'RTM'
Say ("  legacy RTM     " + $legacy.State + "   pid " + $legacy.ProcessId + "   - not ours, never touched, printed so a change by another hand is not blamed on this flight")
Rule

Say "4  THE FIVE ASSET VERSIONS THE SERVER SERVES RIGHT NOW - the BEFORE half of the acceptance"
$curl = "$env:SystemRoot\System32\curl.exe"
$html = ''
$fetchOk = $false
if (-not (Test-Path -LiteralPath $curl)) { Say "  *** curl.exe ABSENT - the before half is NOT MEASURED" }
else {
  $base = 'https://127.0.0.1:8444'
  $finalUrl = (& $curl -k -s -L -o NUL -w '%{url_effective}' --max-time 20 ($base + '/')) 2>$null
  $code     = (& $curl -k -s -L -o NUL -w '%{http_code}'     --max-time 20 ($base + '/')) 2>$null
  $html     = (& $curl -k -s -L --max-time 20 ($base + '/')) 2>$null
  $bodyChars = ("" + $html).Length
  Say ("  final url  : " + $finalUrl)
  Say ("  http code  : " + $code + "   body chars : " + $bodyChars)
  $fetchOk = (("$code" -eq '200') -and ($bodyChars -ge 2000))
  Say ("  fetch usable as evidence : " + $fetchOk + "   (under 2000 chars is a redirect wrapper, not a page)")
  $negCode = (& $curl -k -s -o NUL -w '%{http_code}' --max-time 20 ($base + '/zzz-no-such-endpoint')) 2>$null
  Say ("  NEGCTL /zzz-no-such-endpoint -> " + $negCode + "   (must be neither 200 nor 000)")
}
if ($fetchOk) {
  Say  "  WHAT IS THERE NOW, and what the acceptance will demand after the install:"
  $assets = @()
  $assets += ,@('app.css',                        '33', '35')
  $assets += ,@('CcDashboard.Web.styles.css',     '1',  '4')
  $assets += ,@('wallboard-skin.css',             '2',  '3')
  $assets += ,@('agentStateDistributionChart.js', '4',  '7')
  $assets += ,@('daytrendChart.js',               '4',  '4')
  foreach ($asset in $assets) {
    $leaf = $asset[0]
    $expectBefore = $asset[1]
    $expectAfter  = $asset[2]
    $found = @([regex]::Matches($html, [regex]::Escape($leaf) + '\?v=(\d+)') | ForEach-Object { $_.Groups[1].Value })
    $foundText = if ($found.Count -gt 0) { ($found -join ',') } else { 'NONE' }
    $agrees = ($found -contains $expectBefore)
    Say ("  " + $leaf.PadRight(32) + " now v=" + $foundText.PadRight(6) + " expected now v=" + $expectBefore.PadRight(3) + " agrees: " + $agrees)
    if ($expectAfter -eq $expectBefore) {
      Say ("  " + ' '.PadRight(32) + " after the install: v=" + $expectAfter + " PRESENCE ONLY - unchanged in this delta, so there is no stale number to vanish")
    } else {
      Say ("  " + ' '.PadRight(32) + " after the install: v=" + $expectAfter + " present AND v=" + $expectBefore + " gone")
    }
  }
  $negAsset = ([regex]::Matches($html, [regex]::Escape('zzz-no-such-asset.css?v=99'))).Count
  Say ("  NEGCTL same reader, asset that cannot be there : " + $negAsset + "   must be 0")
}
Rule

Say "5  ROLLBACK FLOORS - artefacts on this disk, with hashes, BEFORE anything is written"
Say  "  A plan to rebuild from the branch is not a floor. The floor is a package that exists here."
$floorsOk = $true
foreach ($floor in @(@($FloorShellZip, $FloorShellSha, 'the package running now (e7eb243)'), @($FloorFullZip, $FloorFullSha, 'the full package of 26.09, both halves'))) {
  $floorPath = $floor[0]
  $floorSha  = $floor[1]
  Say ("  " + $floor[2])
  Say ("    path     : " + $floorPath + "   exists: " + (Test-Path -LiteralPath $floorPath))
  if (-not (Test-Path -LiteralPath $floorPath)) { Say "    *** ABSENT - no floor here" ; $floorsOk = $false ; continue }
  $measured = ShaOf $floorPath
  Say ("    expected : " + $floorSha)
  Say ("    measured : " + $measured + "   match: " + ($measured -eq $floorSha))
  if ($measured -ne $floorSha) { $floorsOk = $false }
}
Say ("  floors present and intact : " + $floorsOk)
Rule

Say "6  THE PACKAGE TO BE INSTALLED - is it here yet, and is it the right bytes"
Say ("  expected path  : " + $IncomingPkg)
Say ("  expected bytes : " + $IncomingBytes)
Say ("  expected sha   : " + $IncomingSha)
$pkgHere = Test-Path -LiteralPath $IncomingPkg
Say ("  present on this machine : " + $pkgHere)
$pkgOk = $false
if (-not $pkgHere) { Say "  NOT HERE YET - that is the next step, not a fault. This run copies nothing." }
else {
  $pkgBytes = (Get-Item -LiteralPath $IncomingPkg).Length
  $pkgSha = ShaOf $IncomingPkg
  Say ("  measured bytes : " + $pkgBytes + "   match: " + ($pkgBytes -eq $IncomingBytes))
  Say ("  measured sha   : " + $pkgSha)
  $pkgOk = (($pkgSha -eq $IncomingSha) -and ($pkgBytes -eq $IncomingBytes))
  Say ("  the bytes here are the bytes built on the station : " + $pkgOk)
}
Rule

Say "7  DISK - a pair, not one number"
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$freeGb = [math]::Round($disk.FreeSpace / 1GB, 2)
Say ("  free on C: : " + $freeGb + " GB")
Say ("  the package is " + [math]::Round($IncomingBytes / 1GB, 3) + " GB and the installer takes its own backup of Shell and RTM plus a pg_dump")
Say ("  last flight those cost: Shell copy ~4 s, RTM copy ~46 s, pg_dump 11282437 B / ~13 s [234_20261005_081231]")
Say ("  room for one more backup set : " + ($freeGb -gt 5) + "   (judged against 5 GB, not against zero)")
Rule

Say "VERDICT OF THE PRE-DEPLOY READING"
Say ("  machine still runs the revision I think it does : " + $stateOk)
Say ("  satellites as expected                          : " + $satellitesOk)
Say ("  rollback floors present and intact              : " + $floorsOk)
Say ("  before-half of the asset pairs measured         : " + $fetchOk)
Say ("  package already on the machine                  : " + $pkgOk + "   (False here is normal before the transfer)")
$ready = ($stateOk -and $satellitesOk -and $floorsOk -and $fetchOk)
Say ("  READY FOR THE TRANSFER STEP : " + $(if ($ready) { 'YES - the state is what the flight assumes' } else { 'NO - the red rows above are the report; nothing was changed by this run' }))
Say  "  Nothing was installed, started, stopped or configured. No package was copied."
Say "===== END-OF-RUN MARKER: PREDEPLOY-6B720B2-COMPLETE ====="
Finish $ready
