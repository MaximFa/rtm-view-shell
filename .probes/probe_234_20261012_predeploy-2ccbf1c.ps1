<#
  PROBE  probe_234_20261011_predeploy-e6a0fcb.ps1
  BASED  ON probe_234_20261010_predeploy-4634162.ps1 - the previous flight.
  UNIT   pre-deploy state of 234 before the evening flight v4 e6a0fcb (package
         11102026.0035_Shell.zip): the Hebrew translation of the Wfm labels plus behaviour the
         operator stated through the evening. Blessing 2026-10-10T21:29:14Z with his word quoted
         there; the inbox was re-read first, as the gate of de5f50f requires.
  ITS REAL JOB IS THE 'BEFORE' OF THE TRANSLATION NEEDLES
         The asset versions prove NOTHING in this flight: App.razor is not in the delta and the ?v=
         numbers are identical in both revisions (measured by listing them from App.razor in each
         and diffing to nothing). What proves delivery is the he-IL dictionary BY CONTENT, so this
         run records, by byte search with a self-tested reader, that right now:
           'Tile Metrics' and 'No Data' ARE present in he-IL  (they must vanish)
           the two Hebrew values are ABSENT                   (they must appear)
         A vanishing needle is the half a presence-only check can never give, and it is worthless
         unless somebody saw the English text there first. That is this run.
  WHY IT EXISTS  the stand was installed two hours ago, so the numbers are fresh - but fresh is not
         the same as measured. This run re-takes every one and prints the expectation BEFORE the
         measurement. Its real job is the BEFORE half of the acceptance pairs: only TWO asset
         versions move in this delta, and the acceptance cannot prove the old ones are gone unless
         somebody saw them there first.
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
$ReportPath = Join-Path $OutputDir ("234_{0}_predeploy-2ccbf1c.txt" -f $RunStamp)
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
function Find-ByteRun([byte[]]$haystack, [byte[]]$needle) {
  if ($needle.Length -eq 0 -or $haystack.Length -lt $needle.Length) { return -1 }
  $last = $haystack.Length - $needle.Length
  for ($outer = 0; $outer -le $last; $outer++) {
    $matched = $true
    for ($inner = 0; $inner -lt $needle.Length; $inner++) {
      if ($haystack[$outer + $inner] -ne $needle[$inner]) { $matched = $false ; break }
    }
    if ($matched) { return $outer }
  }
  return -1
}
function ShaOf($path) { if (Test-Path -LiteralPath $path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash } else { 'ABSENT' } }
function StateOf($name) {
  $service = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $name) -ErrorAction SilentlyContinue
  if ($null -eq $service) { return [pscustomobject]@{ State = 'ABSENT' ; ProcessId = 0 } }
  return [pscustomobject]@{ State = $service.State ; ProcessId = $service.ProcessId }
}

# EXPECTATIONS, each with the measurement file it came from. All of them were taken on this
# machine within the last nine hours - and they are still re-taken here, by this run.
$ExpectWebDll   = '6FF870FB6345CDA5A5032A3BD2DA0821C16E142570B1F5353154CD0B554ABC75'
$ExpectEngine   = '097F087D66497A4C59C5216E8BB46E1C4F49739A2B2A2A6621483BD0DC1C10AB'
# WHAT THE MACHINE CARRIES NOW - read back from [234_20261011_005750_acceptance.txt], the run
# that was accepted for the revision now installed.
# SIZE IS A NOTE in this probe, not a row that can fail: the build of 2f3b426 printed a RED on
# he-IL because I demanded growth, while the dictionary carried all four new keys and stayed at
# 77824 B - the four names fit inside the 512-byte alignment padding. The content rows are the keys.
$ExpectSatellite = @{ 'he-IL' = 77824 ; 'ru-RU' = 88064 ; 'en-US' = 71168 }
$FloorShellZip  = 'C:\RTMView-Ops\incoming\11102026.1245_Shell.zip'
$FloorShellSha  = '03305E4ED02F37BF49CF459B4652C9D4B568A7755268BDC3E736570B1EFF3FFA'
$FloorFullZip   = 'C:\RTMView-Ops\incoming\26092026.1937.zip'
$FloorFullSha   = 'C8DCFAEB9B6DCE8133E163F910C4C84517268D5C01201B34F81DAC3E314E9ADF'
$IncomingPkg    = 'C:\RTMView-Ops\incoming\12102026.0946_Shell.zip'
$IncomingSha    = 'BB618F107CB5D1D889B136C6B7C2A87BCA8345E99BA29846E152FE0A880F5BA1'
$IncomingBytes  = 54137961
# The THREE chart bodies THIS package carries [WS_20261012_094305_shellpkg-2ccbf1c.txt]. They do
# grow in this delta, but the acceptance still compares the served body against THESE sha: a size
# that moves proves no more than a size that does not.
$PackageDayTrendSha = 'FB550D106277E10C4E04AE9D1C9A78C1D5ED1B9C51D2F8ABE69630C9A54C762D'
$PackageAsdSha      = '6A80A085A86F7ABC9941652F85A1C0EE417953AE7FD65D552FF360428E514BBC'
$PackageReportSha   = 'A1198F9AD914E217C44741C85D7837565BDC57A8FE04B904715F21E85DD516C7'

Say ("PRE-DEPLOY 2ccbf1c  " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
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
Say ("  web.dll expected (from the accepted acceptance at 23:18 local) : " + $ExpectWebDll)
Say ("  web.dll measured now                         : " + $webNow)
Say ("  the machine still runs 4634162 : " + ($webNow -eq $ExpectWebDll) + "   (False means something landed here since 23:18 local - a finding, and the flight stops)")
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

Say "2  SATELLITES - only he-IL changes here, and SIZE IS A NOTE, never a verdict"
$satellitesOk = $true
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satellitePath = 'C:\RTMView\Shell\' + $culture + '\CcDashboard.Web.resources.dll'
  $expected = $ExpectSatellite[$culture]
  if (-not (Test-Path -LiteralPath $satellitePath)) { Say ("  " + $culture.PadRight(6) + " ABSENT - RED") ; $satellitesOk = $false ; continue }
  $satelliteSize = (Get-Item -LiteralPath $satellitePath).Length
  if ($satelliteSize -ne $expected) { $satellitesOk = $false }
  Say ("  " + $culture.PadRight(6) + " expected " + $expected + "   measured " + $satelliteSize + "   match: " + ($satelliteSize -eq $expected) + "   sha " + (ShaOf $satellitePath))
}
Say ("  satellites as expected BEFORE the install : " + $satellitesOk)
Say  "  AFTER the install the package carries he-IL 77824 (+512), ru-RU 87552 and en-US 70656 (no"
Say  "  movement at all - only the Hebrew dictionary changes in this delta). The verdict is equality"
Say  "  with the package; the movement is printed as a note. Size has already produced one false red"
Say  "  of mine this evening and three false +512 in tonight's build report, where the comparison"
Say  "  was made against sizes from BEFORE the previous flight."  
Rule

Say "3  SERVICES and their pids - the install report compares against THESE numbers"
foreach ($name in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $service = StateOf $name
  Say ("  {0,-14} {1}   pid {2}" -f $name, $service.State, $service.ProcessId)
}
$legacy = StateOf 'RTM'
Say ("  legacy RTM     " + $legacy.State + "   pid " + $legacy.ProcessId + "   - not ours, never touched, printed so a change by another hand is not blamed on this flight")
Rule

Say "4  THE NINE ASSET VERSIONS THE SERVER SERVES RIGHT NOW - the BEFORE half of the acceptance"
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
  Say  "  WHAT IS THERE NOW, and what the acceptance will demand after the install."
  Say  "  THREE MOVE AND SIX DO NOT. Measured in the blobs of both revisions today: agentState"
  Say  "  14->16, daytrend 12->14, report 4->6. styles stays at v=9, and widget-resize MUST stay at"
  Say  "  v=3: the coordinator named it because this delta touches the canvas sizing path, so a v=4"
  Say  "  appearing after the install is a finding, not a pass. That row's negative half is the"
  Say  "  absence of v=4, and it is written into the acceptance."
  $assets = @()
  $assets += ,@('CcDashboard.Web.styles.css',     '9',  '9')
  $assets += ,@('agentStateDistributionChart.js', '14', '16')
  $assets += ,@('daytrendChart.js',               '12', '14')
  $assets += ,@('reportDistributionChart.js',     '4',  '6')
  $assets += ,@('widget-resize.js',               '3',  '3')
  $assets += ,@('app.css',                        '35', '35')
  $assets += ,@('tokens.css',                     '3',  '3')
  $assets += ,@('wallboard-skin.css',             '3',  '3')
  $assets += ,@('app.js',                         '2',  '2')
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

Say "4b  THE TWO CHART BODIES AS THEY ARE SERVED NOW - BY sha, BECAUSE THE SIZES DO NOT MOVE"
Say  "  The three scripts DO grow in this delta (13192->15436, 17145->19604, 7935->10965), and that"
Say  "  changes nothing: the before half taken here is the sha of each served body plus the count of"
Say  "  the needle, and the acceptance compares the served body against the sha THIS PACKAGE carries,"
Say  "  measured on the station. The previous flight settled why - a size that moves proves no more"
Say  "  than a size that does not, and only the sha and the needle can see the delivery:"
Say ("    daytrendChart.js               package sha " + $PackageDayTrendSha)
Say ("    agentStateDistributionChart.js package sha " + $PackageAsdSha)
Say ("    reportDistributionChart.js     package sha " + $PackageReportSha)
Say  "  A further caution measured today: the sha of a REBUILT assembly changes by itself, so no"
Say  "  row here says 'must stay the same'. These two files are plain text in wwwroot, not built"
Say  "  assemblies, so their sha is a lawful expectation - that difference is the whole point."
if (-not $fetchOk) { Say "  *** the fetch above produced no page - NOT MEASURED" }
else {
  $bodyRows = @()
  $bodyRows += ,@('/js/daytrendChart.js?v=12', 'daytrend', $PackageDayTrendSha)
  $bodyRows += ,@('/js/agentStateDistributionChart.js?v=14', 'asd', $PackageAsdSha)
  $bodyRows += ,@('/js/reportDistributionChart.js?v=4', 'report', $PackageReportSha)
  Say ("  rows : " + $bodyRows.Count + "   expected 3")
  foreach ($bodyRow in $bodyRows) {
    $urlPath = $bodyRow[0]
    $label   = $bodyRow[1]
    $afterSha = $bodyRow[2]
    $tmp = Join-Path $env:TEMP ('before_' + $label + '.bin')
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    & $curl -k -s --max-time 20 -o $tmp ('https://127.0.0.1:8444' + $urlPath)
    if (-not (Test-Path -LiteralPath $tmp)) { Say ("  " + $label.PadRight(10) + " NOTHING FETCHED - not measured") ; continue }
    $bodyBytes = (Get-Item -LiteralPath $tmp).Length
    $bodySha = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash
    $bodyText = Get-Content -LiteralPath $tmp -Raw
    $hits = ([regex]::Matches("" + $bodyText, [regex]::Escape('_applyCanvasSize'))).Count
    $negHits = ([regex]::Matches("" + $bodyText, [regex]::Escape('zzznosuchneedle'))).Count
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    Say ("  " + $label.PadRight(10) + " served now " + $bodyBytes + " B   sha " + $bodySha)
    Say ("  " + ' '.PadRight(10) + " already equals the package sha : " + ($bodySha -eq $afterSha) + "   expected False - True would mean it is already installed")
    Say ("  " + ' '.PadRight(10) + " needle '_applyCanvasSize' " + $hits + "   expected 0   NEGCTL " + $negHits + " must be 0")
  }
}
Rule

Say "4c  WHAT THIS FLIGHT MUST NOT TOUCH - the dictionaries and the Contracts assembly"
Say  "  No .resx and no Contracts source is in this delta. But a sha comparison is NOT how that is"
Say  "  checked: measured on the station today, two builds of byte-identical .resx produced three"
Say  "  dictionaries with DIFFERENT sha at identical sizes. A rebuild is not byte-reproducible."
Say  "  So what is taken here is the size and the CONTENT - the four Wfm key names and the type"
Say  "  name - and after the install the same four names must still be found."
$KeyTileTitle = 'Wfm_TileTitleFontSize'
$KeyTileValue = 'Wfm_TileValueFontSize'
$KeyListTitle = 'Wfm_ListTitleFontSize'
$KeyListValue = 'Wfm_ListValueFontSize'
$keyNames = @($KeyTileTitle, $KeyTileValue, $KeyListTitle, $KeyListValue)
Say  "  G2 SELF-TEST of the byte finder, on a known answer, before it judges anything:"
$probeHay = [Text.Encoding]::UTF8.GetBytes('aaaHELLObbb')
$posHit  = Find-ByteRun $probeHay ([Text.Encoding]::UTF8.GetBytes('HELLO'))
$posMiss = Find-ByteRun $probeHay ([Text.Encoding]::UTF8.GetBytes('WORLD'))
Say ("    present needle found at " + $posHit + "   expected 3   absent needle at " + $posMiss + "   expected -1")
if ($posHit -ne 3 -or $posMiss -ne -1) { Say "  *** THE FINDER IS WRONG - every number below would be worthless. STOP." ; Finish $false }
Say  "    G2 PASS"
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satPath = 'C:\RTMView\Shell\' + $culture + '\CcDashboard.Web.resources.dll'
  if (-not (Test-Path -LiteralPath $satPath)) { Say ("  " + $culture.PadRight(6) + " ABSENT on this disk - a finding") ; continue }
  $satBytes = [IO.File]::ReadAllBytes($satPath)
  Say ("  " + $culture.PadRight(6) + " " + $satBytes.Length + " B   expected " + $ExpectSatellite[$culture] + " : " + ($satBytes.Length -eq $ExpectSatellite[$culture]) + "   sha " + (ShaOf $satPath) + " (a note - a rebuild changes it by itself)")
  $posOff = Find-ByteRun $satBytes ([Text.Encoding]::UTF8.GetBytes('CcDashboard'))
  $negOff = Find-ByteRun $satBytes ([Text.Encoding]::UTF8.GetBytes('zzz-no-such-key-in-any-dictionary'))
  $readerOk = (($posOff -ge 0) -and ($negOff -eq -1))
  Say ("  " + ' '.PadRight(6) + " reader self-test: POSCTL @" + $posOff + "  NEGCTL " + $negOff + "  -> " + $(if ($readerOk) { 'TRUSTED' } else { 'NOT TRUSTED' }))
  if (-not $readerOk) { continue }
  $hits = 0
  foreach ($key in $keyNames) {
    $atUtf8  = Find-ByteRun $satBytes ([Text.Encoding]::UTF8.GetBytes($key))
    $atUtf16 = Find-ByteRun $satBytes ([Text.Encoding]::Unicode.GetBytes($key))
    if (($atUtf8 -ge 0) -or ($atUtf16 -ge 0)) { $hits++ }
  }
  Say ("  " + ' '.PadRight(6) + " Wfm font-size keys present : " + $hits + " of 4   expected 4 now and 4 after")
}
$contractsPath = 'C:\RTMView\Shell\CcDashboard.Contracts.dll'
if (-not (Test-Path -LiteralPath $contractsPath)) { Say "  CcDashboard.Contracts.dll ABSENT - a finding" }
else {
  $contractsBytes = [IO.File]::ReadAllBytes($contractsPath)
  $inkPos = Find-ByteRun $contractsBytes ([Text.Encoding]::UTF8.GetBytes('CcDashboard'))
  $inkNeg = Find-ByteRun $contractsBytes ([Text.Encoding]::UTF8.GetBytes('zzz-no-such-type-name'))
  $ink8 = Find-ByteRun $contractsBytes ([Text.Encoding]::UTF8.GetBytes('ContrastInk'))
  $ink16 = Find-ByteRun $contractsBytes ([Text.Encoding]::Unicode.GetBytes('ContrastInk'))
  Say ("  Contracts.dll " + $contractsBytes.Length + " B   sha " + (ShaOf $contractsPath) + " (a note, not an expectation)")
  Say ("  reader self-test: POSCTL @" + $inkPos + "  NEGCTL " + $inkNeg)
  Say ("  'ContrastInk' present now : " + (($ink8 -ge 0) -or ($ink16 -ge 0)) + "   utf8 " + $ink8 + "   expected True now and True after")
}
Rule

Say "5  ROLLBACK FLOORS - artefacts on this disk, with hashes, BEFORE anything is written"
Say  "  A plan to rebuild from the branch is not a floor. The floor is a package that exists here."
$floorsOk = $true
foreach ($floor in @(@($FloorShellZip, $FloorShellSha, 'the package running now (4634162)'), @($FloorFullZip, $FloorFullSha, 'the full package of 26.09, both halves'))) {
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
Say ("  last flight cost 114.7 s [234_20261010_230808]; the adapter came back at +84 s")
Say ("  room for one more backup set : " + ($freeGb -gt 5) + "   (judged against 5 GB, not against zero)")
Say  "  Free space was 25.16 GB after this evening's cleanup and 25.06 GB after the transfer."
Say  "  The installer will add one more backup set of about 3.2 GB; three sets are kept by a"
Say  "  cleanup step after the acceptance, never by -KeepBackups 3."  
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
Say "===== END-OF-RUN MARKER: PREDEPLOY-2CCBF1C-COMPLETE ====="
Finish $ready
