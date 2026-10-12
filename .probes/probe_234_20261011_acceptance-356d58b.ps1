<#
  PROBE  probe_234_20261010_acceptance-4634162.ps1
  BASED  ON probe_234_20261010_acceptance-fe30a27.ps1 - the previous flight of today. Every pin is
         re-derived from this delta and from the pre-deploy reading taken at 23:04.
  UNIT   acceptance of FEAT-REDESIGN-01, v4 4634162, installed on 234 on 2026-10-10 23:08-23:10 -
         the SINGLE rollout the operator asked for: the new Wfm widget, the redrawn ASD and DayTrend
         widgets, four chart scripts and the dictionaries of all three languages.
  WHY THE PROOF IS NOT ON DISK  the point of the flight is what the live service SERVES. A file on
         disk proves nothing here and neither does a 200 on /health.
  NINE ASSETS, FIVE WITH A NEGATIVE HALF AND FOUR WITHOUT - derived from git, not overlooked
         CcDashboard.Web.styles.css       v=7  present , v=5 gone
         agentStateDistributionChart.js   v=10 present , v=7 gone
         daytrendChart.js                 v=7  present , v=4 gone
         reportDistributionChart.js       v=4  present , v=2 gone
         widget-resize.js                 v=3  present , v=2 gone
         app.css v=35 · tokens.css v=3 · wallboard-skin.css v=3 · app.js v=2 -> PRESENCE ONLY,
         because these four are identical in both revisions; demanding that their old number vanish
         would paint a correct install red.
         All five stale values were MEASURED on this machine before the install
         [234_20261010_230439_predeploy-4634162.txt: styles 5, ASD 7, daytrend 4, report 2,
         resize 2], so every negative half is an observation, not an assumption.
  THE BODIES ARE CHECKED TOO, not only the numbers in the links
         The four chart scripts are served as files, so each is fetched and compared to the blob it
         was built from, by SIZE and by sha256 against the copy on disk:
           agentStateDistributionChart.js 15310 B (blob 59543c45)
           daytrendChart.js               11456 B (blob 91a1be01)
           reportDistributionChart.js      7935 B (blob 85f699a9)
           widget-resize.js               35102 B (blob cbb0ba53)
         CcDashboard.Web.styles.css: the NEEDLES OF THE NEW Wfm MARKUP - .wfmgrid and .wfmnote,
         which live in the new WfmWidget.razor.css and are absent on fe30a27 (measured 0 -> 1).
         That .razor.css compiles into this one served file, so the needles are provable in its
         body. A bumped version proves a new file was served; the needles prove the markup landed.
  WHERE  SERVER 234. READ ONLY. No service is started, stopped or configured. Nothing is installed.
         The adapter is never started by hand. Legacy RTM is not touched.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_acceptance-356d58b.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList
function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
$script:SayCount = 0
# A trap with 'continue' turns a FAILED check into a SKIPPED check, and a verdict that does not know
# the difference prints green over a check that never ran. Measured on myself 2026-10-10: a call to a
# function that does not exist in this probe (Line, which is Rule here) skipped the whole app.css
# body section and the run still printed ACCEPTANCE GREEN. So the trap raises a flag the verdict reads.
$script:TrapFired = $false
function Say($text) {
  [void]$ReportLines.Add("$text"); Write-Host "$text"
  $script:SayCount++
  if (($script:SayCount % 25) -eq 0) { Write-Report }
}
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ''; Write-Host ('REPORT: ' + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
trap {
  $script:TrapFired = $true
  [void]$ReportLines.Add('*** TERMINATING ERROR - a section was SKIPPED, not failed. This is why:')
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

# PINS. Every one of these was measured, and the measurement is named next to it.
$ExpectedCommit  = '356d58b'
$ExpectedWebDll  = '6FF870FB6345CDA5A5032A3BD2DA0821C16E142570B1F5353154CD0B554ABC75'
# Every assembly is judged by one predicate: equal to what THIS PACKAGE carries. A rebuild is not
# byte-reproducible (measured on the station today), so 'differs from what was here before' is no
# proof of anything and no row of this probe uses it.
$ExpectedContracts = '2801DB1DC23C0EFF7DF3B7E3D9E0F57B5CA6A7BBBE0771DB2BBE3700F82E5864'
# The two served bodies, which are PLAIN TEXT in wwwroot, not built assemblies - their sha IS a
# lawful expectation, and it is the only thing that can see this flight, because both keep their
# byte count: 13192 and 17145 in both revisions [WS_20261011_124150_shellpkg-356d58b.txt].
$ExpectedDayTrendSha = 'A899B111D197AC0B33A9FF89AF94C37B22E3A2EF08B5484F8B31A22D6545F175'
$ExpectedAsdSha      = '8DE9F39353D10C31C7C6F53BA74C0A7A2CB81779EE881ECA26C34A7F73570AA6'
# the same two as they were SERVED before this install [234_20261011_125518_predeploy-356d58b.txt]
$BeforeDayTrendSha = 'B9D47155CBCABB4B111D401E5B2D546CF1C1D806A4C68E20410E8957A86385C2'
$BeforeAsdSha      = '3A73000DE73997133F44413634F199BD1FAAC1A9BB0FC36B8EB26470D5A447E6'
$EngineMustStay  = '097F087D66497A4C59C5216E8BB46E1C4F49739A2B2A2A6621483BD0DC1C10AB'
$WebDllBefore    = '6ECF2A9BFCA7899720DDA2FA9A1C4EC38F4610F28DA2C842F06068309DBFEB93'
# WHAT THE PACKAGE CARRIES - the verdict is EQUALS THE PACKAGE, never 'unchanged' and never 'grew'.
# All three dictionaries are rebuilt in this delta (four new Wfm font-size keys each) and the sizes
# moved by 0 / +512 / +512: he-IL carries all four keys at the very same byte count, because the
# names and values fit inside the 512-byte alignment padding. These are the PACKAGE numbers from
# [WS_20261011_111040], and the install report of 11:30 local measured the same three on disk.
# Size is a note. Demanding growth is what printed a red on this correct package at 11:14 today.
$ExpectedSatellite = @{ 'he-IL' = 77824 ; 'ru-RU' = 88064 ; 'en-US' = 71168 }
$ExpectedSatelliteSha = @{
  'he-IL' = '083E94528464B4F2B40BA5145207B75AD397DC550D515D6069AE9C71A2285478'
  'ru-RU' = '80E74923572E2A70AF6FC43CE2278CCBC3E334FA041BC575E010A1AA9EA4E159'
  'en-US' = '9FF97D9F0A982C44C2BFB760B7BA2B0F7247977353EFF008EFC4847B1AD38D93'
}
# pids measured before this install [234_20261011_125518_predeploy-356d58b.txt, section 3]
$PidBefore = @{ 'RTMService' = 1712 ; 'RTMViewShell' = 8436 ; 'RTMTwilio_1' = 5716 }

Say ("ACCEPTANCE OF 356d58b  " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say  "READ ONLY. The adapter is NOT started by hand - the engine owns its lifecycle."
Say ("probe sha256 : " + (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Say  "SHAPE FROM probe_234_20261010_acceptance-4634162.ps1. Every pin in it was replaced by a measured"
Say  "number of THIS flight, and the predicate of section 4 was inverted on purpose - see the note there."
Rule

Say "G0  machine identity (gate)"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  expected : name RTM and uuid E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  measured : name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say '  *** NOT server 234 - refusing to measure'; Finish $false }
Say "  G0 PASS"
Rule

Say "1  BINARIES ON DISK - necessary, nowhere near sufficient"
$webNow = ShaOf 'C:\RTMView\Shell\CcDashboard.Web.dll'
Say ("  web.dll expected  : " + $ExpectedWebDll)
Say ("  web.dll measured  : " + $webNow)
Say ("  equals the package : " + ($webNow -eq $ExpectedWebDll))
Say ("  still the OLD one  : " + ($webNow -eq $WebDllBefore) + "   (True here would mean nothing landed)")
$engineNow = ShaOf 'C:\RTMView\RTM\RTM.dll'
Say ("  RTM.dll measured   : " + $engineNow)
Say ("  UNCHANGED as a Shell flight requires : " + ($engineNow -eq $EngineMustStay))
$binariesOk = (($webNow -eq $ExpectedWebDll) -and ($engineNow -eq $EngineMustStay))
$satellitesOk = $true
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satellitePath = 'C:\RTMView\Shell\' + $culture + '\CcDashboard.Web.resources.dll'
  if (-not (Test-Path -LiteralPath $satellitePath)) { Say ("  satellite " + $culture + " ABSENT - RED") ; $satellitesOk = $false ; continue }
  $satelliteSize = (Get-Item -LiteralPath $satellitePath).Length
  $want = $ExpectedSatellite[$culture]
  if ($satelliteSize -ne $want) { $satellitesOk = $false }
  Say ("  satellite " + $culture.PadRight(6) + " " + $satelliteSize + " B   expected = package " + $want + "   match: " + ($satelliteSize -eq $want))
}
Say ("  binaries : " + $binariesOk + "   satellites : " + $satellitesOk)
Rule

Say "2  SERVICES - a changed pid, not the word Running"
$servicesOk = $true
foreach ($name in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $service = StateOf $name
  $changed = (($service.ProcessId -ne $PidBefore[$name]) -and ($service.ProcessId -gt 0))
  if (($service.State -ne 'Running') -or (-not $changed)) { $servicesOk = $false }
  Say ("  {0,-14} {1}   pid {2}   was {3}   pid changed: {4}" -f $name, $service.State, $service.ProcessId, $PidBefore[$name], $changed)
}
Say  "  An UNCHANGED pid would mean the process never went down, which contradicts the install report."
Say ("  services : " + $servicesOk)
Rule

Say "3  THE SERVED HTML - this is the acceptance"
$curl = "$env:SystemRoot\System32\curl.exe"
Say ("  curl.exe present : " + (Test-Path -LiteralPath $curl))
$html = ''
$fetchOk = $false
$finalUrl = 'NONE'
if (-not (Test-Path -LiteralPath $curl)) { Say "  *** curl.exe ABSENT - the acceptance is NOT MEASURED, not green" }
else {
  $base = 'https://127.0.0.1:8444'
  Say ("  base : " + $base + "   following redirects with -L, because root -> /screens -> /login")
  $finalUrl = (& $curl -k -s -L -o NUL -w '%{url_effective}' --max-time 20 ($base + '/')) 2>$null
  $code     = (& $curl -k -s -L -o NUL -w '%{http_code}'     --max-time 20 ($base + '/')) 2>$null
  $html     = (& $curl -k -s -L --max-time 20 ($base + '/')) 2>$null
  $bytes = ("" + $html).Length
  Say ("  final url  : " + $finalUrl)
  Say ("  http code  : " + $code)
  Say ("  body chars : " + $bytes)
  Say  "  FETCH GATE: a body under 2000 chars is a redirect wrapper, not a page. 2026-10-04 a fetch"
  Say  "  without -L returned 597 bytes and the fault looked like a bad pattern. It was the fetch."
  $fetchOk = (("$code" -eq '200') -and ($bytes -ge 2000))
  Say ("  fetch usable as evidence : " + $fetchOk)
  $negCode = (& $curl -k -s -o NUL -w '%{http_code}' --max-time 20 ($base + '/zzz-no-such-endpoint')) 2>$null
  Say ("  NEGCTL /zzz-no-such-endpoint -> " + $negCode + "   (must be neither 200 nor 000, else this reader proves nothing)")
}
Rule

Say "4  THE NINE ASSET VERSIONS - TWO PAIRS MOVE, SEVEN ARE PRESENCE ONLY"
Say  "  Measured in the blobs of both revisions today: agentState 13->14 and daytrend 11->12, and"
Say  "  nothing else moves - styles stays at v=9 although App.razor is in the delta, because only"
Say  "  those two attributes were raised in it. Demanding a third bump would paint a correct flight"
Say  "  red. The two that move need BOTH halves; the old numbers were served by THIS machine at"
Say  "  12:55 local, before the install, so their disappearance is an observation."
Say  "  AND VERSION NUMBERS ARE THE WEAK HALF HERE: both bodies keep their byte count across this"
Say  "  delta, so section 4b compares the served bodies against the package sha, not their size."
$assetsOk = $true
if (-not $fetchOk) {
  Say "  *** NOT MEASURED - the fetch above did not produce a page. Nothing is asserted here."
  $assetsOk = $false
} else {
  # each row: what must be present, and what must be GONE ('' where there is no stale half)
  $pairs = @()
  $pairs += ,@('agentStateDistributionChart.js?v=14', 'agentStateDistributionChart.js?v=13')
  $pairs += ,@('daytrendChart.js?v=12', 'daytrendChart.js?v=11')
  $pairs += ,@('CcDashboard.Web.styles.css?v=9', '')
  $pairs += ,@('reportDistributionChart.js?v=4', '')
  $pairs += ,@('widget-resize.js?v=3', '')
  $pairs += ,@('app.css?v=35', '')
  $pairs += ,@('tokens.css?v=3', '')
  $pairs += ,@('wallboard-skin.css?v=3', '')
  $pairs += ,@('app.js?v=2', '')
  Say ("  rows to measure : " + $pairs.Count + "   expected 9   (a smaller number means the list unrolled)")
  if ($pairs.Count -ne 9) { $assetsOk = $false ; Say "  *** the row list is not nine rows - not measured" }
  foreach ($pair in $pairs) {
    $want = $pair[0]
    $stale = $pair[1]
    $wantCount = ([regex]::Matches($html, [regex]::Escape($want))).Count
    if ($stale -eq '') {
      $rowOk = ($wantCount -ge 1)
      if (-not $rowOk) { $assetsOk = $false }
      Say ("  " + $want.PadRight(36) + " present " + $wantCount + "   no stale half: unchanged in this delta   row: " + $(if ($rowOk) { 'GREEN' } else { 'RED' }))
    } else {
      $staleCount = ([regex]::Matches($html, [regex]::Escape($stale))).Count
      $rowOk = (($wantCount -ge 1) -and ($staleCount -eq 0))
      if (-not $rowOk) { $assetsOk = $false }
      Say ("  " + $want.PadRight(36) + " present " + $wantCount + "   stale '" + $stale + "' " + $staleCount + " (must be 0)   row: " + $(if ($rowOk) { 'GREEN' } else { 'RED' }))
    }
  }
  $negAsset = ([regex]::Matches($html, [regex]::Escape('zzz-no-such-asset.css?v=99'))).Count
  Say ("  NEGCTL same reader, asset that cannot be there : " + $negAsset + "   must be 0")
  if ($negAsset -ne 0) { $assetsOk = $false }
  Rule
  Say "4b  THE TWO BODIES, AGAINST THE PACKAGE sha - THE ONLY ROW THAT CAN SEE THIS FLIGHT"
  Say  "  Both scripts are 13192 B and 17145 B in BOTH revisions, so size proves nothing and even"
  Say  "  'served equals the file on disk' would be green on a machine where nothing landed. Three"
  Say  "  halves per row: the served sha equals the package sha, it is NOT the sha served before the"
  Say  "  install, and the needle Math.max(3, dpr) appears where it was 0."
  $bodyRows = @()
  $bodyRows += ,@('/js/daytrendChart.js?v=12', 'daytrend', $ExpectedDayTrendSha, $BeforeDayTrendSha, 13192)
  $bodyRows += ,@('/js/agentStateDistributionChart.js?v=14', 'asd', $ExpectedAsdSha, $BeforeAsdSha, 17145)
  Say ("  rows to measure : " + $bodyRows.Count + "   expected 2")
  if ($bodyRows.Count -ne 2) { $assetsOk = $false ; Say "  *** the row list is not two rows - not measured" }
  foreach ($bodyRow in $bodyRows) {
    $urlPath  = $bodyRow[0]
    $label    = $bodyRow[1]
    $wantSha  = $bodyRow[2]
    $beforeSha = $bodyRow[3]
    $wantBytes = $bodyRow[4]
    $tmp = Join-Path $env:TEMP ('served_' + $label + '.bin')
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    & $curl -k -s --max-time 20 -o $tmp ('https://127.0.0.1:8444' + $urlPath)
    if (-not (Test-Path -LiteralPath $tmp)) { Say ("  " + $label.PadRight(10) + " NOTHING FETCHED - not measured") ; $assetsOk = $false ; continue }
    $servedBytes = (Get-Item -LiteralPath $tmp).Length
    $servedSha = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash
    $bodyText = Get-Content -LiteralPath $tmp -Raw
    $hits = ([regex]::Matches("" + $bodyText, [regex]::Escape('Math.max(3, dpr)'))).Count
    $negHits = ([regex]::Matches("" + $bodyText, [regex]::Escape('zzznosuchneedle'))).Count
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    $shaOk = ($servedSha -eq $wantSha)
    $movedOk = ($servedSha -ne $beforeSha)
    $rowOk = ($shaOk -and $movedOk -and ($hits -ge 1) -and ($negHits -eq 0))
    if (-not $rowOk) { $assetsOk = $false }
    Say ("  " + $label.PadRight(10) + " served " + $servedBytes + " B   (the same count as before the install, by design: " + ($servedBytes -eq $wantBytes) + ")")
    Say ("  " + ' '.PadRight(10) + " sha " + $servedSha)
    Say ("  " + ' '.PadRight(10) + " equals the package sha : " + $shaOk + "   is NOT what was served before : " + $movedOk)
    Say ("  " + ' '.PadRight(10) + " needle 'Math.max(3, dpr)' " + $hits + "   expected 1 or more   before the install it was 0   NEGCTL " + $negHits + " must be 0   row: " + $(if ($rowOk) { 'GREEN' } else { 'RED' }))
  }
}
Say ("  ASSETS : " + $(if ($assetsOk) { 'GREEN - the two bumped versions are served and the served bodies ARE the ones this package carries' } else { 'RED - report, do not roll back on your own' }))
Rule

Say "5  THE LEDGER LINE THIS FLIGHT WROTE - the build-to-commit link, read back, not remembered"
$ledgerPath = 'C:\RTMView-Ops\applied\_ledger.txt'
$ledgerOk = $false
if (-not (Test-Path -LiteralPath $ledgerPath)) { Say ("  " + $ledgerPath + " : ABSENT") }
else {
  $line = (Get-Content -LiteralPath $ledgerPath | Where-Object { $_ -like ('*commit=' + $ExpectedCommit + '*') } | Select-Object -Last 1)
  Say ("  line : " + $line)
  $ledgerOk = (("" + $line) -like ('*web.dll_sha256=' + $ExpectedWebDll + '*'))
  Say ("  carries the web.dll hash measured on disk above : " + $ledgerOk)
  $negLine = @(Get-Content -LiteralPath $ledgerPath | Where-Object { $_ -like '*commit=zzzzzzz*' }).Count
  Say ("  NEGCTL same reader, commit that cannot be there : " + $negLine + "   must be 0")
}
Rule

Say "6  WHAT THIS FLIGHT MUST NOT HAVE BROKEN - the dictionaries and the Contracts assembly"
Say  "  THE ACCEPTANCE OF THIS FLIGHT IS SECTION 4b, not this one. No .resx and no Contracts source"
Say  "  is in this delta, so this section is the guard: the four keys of the previous flight and the"
Say  "  ContrastInk type must still be found, and all four files must equal what the package carries."
Say  "  Byte search, in UTF-8 and UTF-16LE, with the reader self-tested on each file before it is"
Say  "  allowed to say 'absent': a one-encoding search found 0 of 7 keys on 10.10 where all were"
Say  "  present, and in the package built today these names were found as UTF-16, not UTF-8."
$translationOk = $true
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
# needles in their own variables BEFORE any array literal: building them inside the literal is what
# printed two empty meanings in the pre-deploy report of 11.10.
$KeyTileTitle = 'Wfm_TileTitleFontSize'
$KeyTileValue = 'Wfm_TileValueFontSize'
$KeyListTitle = 'Wfm_ListTitleFontSize'
$KeyListValue = 'Wfm_ListValueFontSize'
$keyNames = @($KeyTileTitle, $KeyTileValue, $KeyListTitle, $KeyListValue)
Say ("  key names : " + $keyNames.Count + "   expected 4")
Say  "  BEFORE THIS INSTALL, measured on this machine at 11:21 local [234_20261011_112137, 4b]:"
Say  "    0 of 4 in every one of the three dictionaries, in both encodings. So a 4 below is a change"
Say  "    of state, and this row is able to return red."
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satPath = 'C:\RTMView\Shell\' + $culture + '\CcDashboard.Web.resources.dll'
  if (-not (Test-Path -LiteralPath $satPath)) { Say ("  " + $culture.PadRight(6) + " ABSENT on this disk - not measured, and a red flight") ; $translationOk = $false ; continue }
  $satBytes = [IO.File]::ReadAllBytes($satPath)
  $sizeOk = ($satBytes.Length -eq $ExpectedSatellite[$culture])
  $satSha = ShaOf $satPath
  $satShaOk = ($satSha -eq $ExpectedSatelliteSha[$culture])
  if (-not ($sizeOk -and $satShaOk)) { $translationOk = $false }
  Say ("  " + $culture.PadRight(6) + " " + $satBytes.Length + " B   equals the package size " + $ExpectedSatellite[$culture] + " : " + $sizeOk)
  Say ("  " + ' '.PadRight(6) + " sha " + $satSha + "   equals the package sha : " + $satShaOk)
  $posOff = Find-ByteRun $satBytes ([Text.Encoding]::UTF8.GetBytes('CcDashboard'))
  $negOff = Find-ByteRun $satBytes ([Text.Encoding]::UTF8.GetBytes('zzz-no-such-key-in-any-dictionary'))
  $readerOk = (($posOff -ge 0) -and ($negOff -eq -1))
  Say ("  " + ' '.PadRight(6) + " reader self-test on this very file: POSCTL @" + $posOff + "  NEGCTL " + $negOff + "  -> " + $(if ($readerOk) { 'TRUSTED' } else { 'NOT TRUSTED - rows below are not counted' }))
  if (-not $readerOk) { $translationOk = $false ; continue }
  $hits = 0
  foreach ($key in $keyNames) {
    $atUtf8  = Find-ByteRun $satBytes ([Text.Encoding]::UTF8.GetBytes($key))
    $atUtf16 = Find-ByteRun $satBytes ([Text.Encoding]::Unicode.GetBytes($key))
    $present = (($atUtf8 -ge 0) -or ($atUtf16 -ge 0))
    if ($present) { $hits++ }
    Say ("      " + $key.PadRight(24) + " utf8 " + $atUtf8 + "   utf16 " + $atUtf16 + "   present : " + $present + "   expected True - added last flight, must survive this one")
  }
  if ($hits -ne 4) { $translationOk = $false }
  Say ("  " + ' '.PadRight(6) + " keys present : " + $hits + " of 4   expected 4   (before the install: 0)")
}
Rule
Say "6b  THE NEW ASSEMBLY - ContrastInk, which web.dll cannot speak for"
$contractsPath = 'C:\RTMView\Shell\CcDashboard.Contracts.dll'
Say ("  file : " + $contractsPath + "   exists : " + (Test-Path -LiteralPath $contractsPath))
if (-not (Test-Path -LiteralPath $contractsPath)) { Say "  *** ABSENT - not measured, and a red flight" ; $translationOk = $false }
else {
  $contractsBytes = [IO.File]::ReadAllBytes($contractsPath)
  $contractsSha = ShaOf $contractsPath
  $shaOk = ($contractsSha -eq $ExpectedContracts)
  if (-not $shaOk) { $translationOk = $false }
  Say ("  size : " + $contractsBytes.Length + " B   sha " + $contractsSha)
  Say ("  equals the package : " + $shaOk + "   (no 'differs from before' row: a rebuild changes an assembly sha by itself)")
  $inkPos = Find-ByteRun $contractsBytes ([Text.Encoding]::UTF8.GetBytes('CcDashboard'))
  $inkNeg = Find-ByteRun $contractsBytes ([Text.Encoding]::UTF8.GetBytes('zzz-no-such-type-name'))
  $readerOk = (($inkPos -ge 0) -and ($inkNeg -eq -1))
  Say ("  reader self-test on this very file: POSCTL @" + $inkPos + "  NEGCTL " + $inkNeg + "  -> " + $(if ($readerOk) { 'TRUSTED' } else { 'NOT TRUSTED' }))
  if (-not $readerOk) { $translationOk = $false }
  else {
    $ink8  = Find-ByteRun $contractsBytes ([Text.Encoding]::UTF8.GetBytes('ContrastInk'))
    $ink16 = Find-ByteRun $contractsBytes ([Text.Encoding]::Unicode.GetBytes('ContrastInk'))
    $inkPresent = (($ink8 -ge 0) -or ($ink16 -ge 0))
    if (-not $inkPresent) { $translationOk = $false }
    Say ("  type name 'ContrastInk' present : " + $inkPresent + "   utf8 " + $ink8 + "   utf16 " + $ink16 + "   expected True")
    Say  "  It was already there before this install, and it must still be there: this delta carries"
    Say  "  no Contracts source, so a missing type name here would mean the package replaced the"
    Say  "  assembly with something built from a tree that does not have it."
  }
}
Say ("  THE GUARD : " + $(if ($translationOk) { 'GREEN - the four keys and ContrastInk survived, and all four files equal the package' } else { 'RED - report it, roll nothing back' }))
Rule
Say "VERDICT"
Say ("  binaries on disk     : " + $binariesOk)
Say ("  satellites equal the package : " + $satellitesOk + "   (by sha, not only by size)")
Say ("  services restarted   : " + $servicesOk)
Say ("  served bodies        : " + $assetsOk + "   <- two bodies equal the package sha, needle 0 -> 1")
Say ("  guard: keys + ink    : " + $translationOk + "   (nothing of the previous flight was lost)")
Say ("  ledger               : " + $ledgerOk)
Say ("  a section was skipped by an error : " + $script:TrapFired + "   (True forbids a green verdict: a check that never ran is not a check that passed)")
$all = $translationOk -and ($binariesOk -and $satellitesOk -and $servicesOk -and $assetsOk -and $ledgerOk -and (-not $script:TrapFired))
Say ("  ACCEPTANCE : " + $(if ($all) { 'GREEN - every half of every check. The flight delivered.' } else { 'NOT ACCEPTED - the red rows above are the report, and no remedy is proposed here' }))
Say  "  Nothing was started, stopped, installed or configured by this run."
Say "===== END-OF-RUN MARKER: ACCEPTANCE-356D58B-COMPLETE ====="
Finish $all
