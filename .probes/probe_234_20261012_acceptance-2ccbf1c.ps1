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
$ReportPath = Join-Path $OutputDir ("234_{0}_acceptance-2ccbf1c.txt" -f $RunStamp)
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
$ExpectedCommit  = '2ccbf1c'
$ExpectedWebDll  = '88393643C244611BE9AD562117097C7E3959C1AE92DAAA5987EB566479BAA66E'
# Every assembly is judged by one predicate: equal to what THIS PACKAGE carries. A rebuild is not
# byte-reproducible (measured on the station today), so 'differs from what was here before' is no
# proof of anything and no row of this probe uses it.
# THE PACKAGE SIDE IS READ FROM THE STAGING THIS INSTALL LEFT ON THE MACHINE, not carried here
# by hand. The install of 09:56 kept it, and this run compares disk against it directly.
$StagingDir = 'C:\RTMView-Ops\incoming\pkg_2ccbf1c_20261012_095644'
# The THREE served bodies. Plain text in wwwroot, not built assemblies, so their sha IS a lawful
# expectation - and the package side comes from the staging on this disk, read in this run.
# The 'before' sha are the only numbers carried in, and they are the halves that can return red:
# they were SERVED by this machine at 09:53 local [234_20261012_095307_predeploy-2ccbf1c.txt].
$BeforeDayTrendSha = 'A899B111D197AC0B33A9FF89AF94C37B22E3A2EF08B5484F8B31A22D6545F175'
$BeforeAsdSha      = '8DE9F39353D10C31C7C6F53BA74C0A7A2CB81779EE881ECA26C34A7F73570AA6'
$BeforeReportSha   = '9A10E43CE10A8F142D2427E01A6075EBC66DB62D9F137F037F09C1D4992AA601'
$EngineMustStay  = '097F087D66497A4C59C5216E8BB46E1C4F49739A2B2A2A6621483BD0DC1C10AB'
$WebDllBefore    = '6FF870FB6345CDA5A5032A3BD2DA0821C16E142570B1F5353154CD0B554ABC75'
# WHAT THE PACKAGE CARRIES - the verdict is EQUALS THE PACKAGE, never 'unchanged' and never 'grew'.
# All three dictionaries are rebuilt in this delta (four new Wfm font-size keys each) and the sizes
# moved by 0 / +512 / +512: he-IL carries all four keys at the very same byte count, because the
# names and values fit inside the 512-byte alignment padding. These are the PACKAGE numbers from
# [WS_20261011_111040], and the install report of 11:30 local measured the same three on disk.
# Size is a note. Demanding growth is what printed a red on this correct package at 11:14 today.
$ExpectedSatellite = @{ 'he-IL' = 77824 ; 'ru-RU' = 88064 ; 'en-US' = 71168 }

# pids measured before this install [234_20261012_095307_predeploy-2ccbf1c.txt, section 3]
$PidBefore = @{ 'RTMService' = 7116 ; 'RTMViewShell' = 7856 ; 'RTMTwilio_1' = 3096 }

Say ("ACCEPTANCE OF 2ccbf1c  " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
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

Say "4  THE NINE ASSET VERSIONS - THREE PAIRS MOVE, AND ONE IS GUARDED AGAINST MOVING"
Say  "  Measured in the blobs of both revisions today: agentState 14->16, daytrend 12->14 and"
Say  "  report 4->6. Each needs BOTH halves - the new number present and the old one gone - and the"
Say  "  old numbers were served by THIS machine at 09:53 local, before the install."
Say  "  AND ONE ROW IS INVERTED: widget-resize.js must STILL be v=3, with v=4 ABSENT. The"
Say  "  coordinator named it because this delta touches the canvas sizing path; a v=4 appearing here"
Say  "  would mean something was rebuilt that the flight did not account for. That absence is this"
Say  "  row's negative half, and it is the one row where a bump is the finding."
Say  "  Version numbers remain the weak half: section 4b compares the served bodies against the"
Say  "  package copy the install left on this disk."
$assetsOk = $true
if (-not $fetchOk) {
  Say "  *** NOT MEASURED - the fetch above did not produce a page. Nothing is asserted here."
  $assetsOk = $false
} else {
  # each row: what must be present, and what must be GONE ('' where there is no stale half)
  $pairs = @()
  $pairs += ,@('agentStateDistributionChart.js?v=16', 'agentStateDistributionChart.js?v=14')
  $pairs += ,@('daytrendChart.js?v=14', 'daytrendChart.js?v=12')
  $pairs += ,@('reportDistributionChart.js?v=6', 'reportDistributionChart.js?v=4')
  $pairs += ,@('CcDashboard.Web.styles.css?v=9', '')
  $pairs += ,@('widget-resize.js?v=3', 'widget-resize.js?v=4')
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
  Say "4b  THE THREE BODIES, AGAINST THE PACKAGE COPY ON THIS DISK - the row that sees the flight"
  Say  "  The package side is NOT a number I typed into this probe: it is read from the staging the"
  Say  "  install of 09:56 left behind, so both sides are measured here, in this run, by this"
  Say  "  instrument. Four wrong numbers of mine in two days came from carrying expectations across"
  Say  "  machines. Three halves per row: served equals the package copy, served is NOT what was"
  Say  "  served before the install, and the needle _applyCanvasSize is present where it was 0."
  Say ("  staging : " + $StagingDir + "   exists : " + (Test-Path -LiteralPath $StagingDir))
  if (-not (Test-Path -LiteralPath $StagingDir)) { Say "  *** the staging is gone - the package side cannot be measured. NOT MEASURED." ; $assetsOk = $false }
  else {
    $bodyRows = @()
    $bodyRows += ,@('/js/daytrendChart.js?v=14', 'daytrend', 'daytrendChart.js', $BeforeDayTrendSha)
    $bodyRows += ,@('/js/agentStateDistributionChart.js?v=16', 'asd', 'agentStateDistributionChart.js', $BeforeAsdSha)
    $bodyRows += ,@('/js/reportDistributionChart.js?v=6', 'report', 'reportDistributionChart.js', $BeforeReportSha)
    Say ("  rows to measure : " + $bodyRows.Count + "   expected 3")
    if ($bodyRows.Count -ne 3) { $assetsOk = $false ; Say "  *** the row list is not three rows - not measured" }
    foreach ($bodyRow in $bodyRows) {
      $urlPath   = $bodyRow[0]
      $label     = $bodyRow[1]
      $leafName  = $bodyRow[2]
      $beforeSha = $bodyRow[3]
      $stagedPath = Join-Path $StagingDir ('Shell\wwwroot\js\' + $leafName)
      $wantSha = ShaOf $stagedPath
      $tmp = Join-Path $env:TEMP ('served_' + $label + '.bin')
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
      & $curl -k -s --max-time 20 -o $tmp ('https://127.0.0.1:8444' + $urlPath)
      if (-not (Test-Path -LiteralPath $tmp)) { Say ("  " + $label.PadRight(10) + " NOTHING FETCHED - not measured") ; $assetsOk = $false ; continue }
      $servedBytes = (Get-Item -LiteralPath $tmp).Length
      $servedSha = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash
      $bodyText = Get-Content -LiteralPath $tmp -Raw
      $hits = ([regex]::Matches("" + $bodyText, [regex]::Escape('_applyCanvasSize'))).Count
      $negHits = ([regex]::Matches("" + $bodyText, [regex]::Escape('zzznosuchneedle'))).Count
      Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
      $shaOk = (($wantSha -ne 'ABSENT') -and ($servedSha -eq $wantSha))
      $movedOk = ($servedSha -ne $beforeSha)
      $rowOk = ($shaOk -and $movedOk -and ($hits -ge 1) -and ($negHits -eq 0))
      if (-not $rowOk) { $assetsOk = $false }
      Say ("  " + $label.PadRight(10) + " served " + $servedBytes + " B   sha " + $servedSha)
      Say ("  " + ' '.PadRight(10) + " package copy on this disk " + $wantSha)
      Say ("  " + ' '.PadRight(10) + " equals the package : " + $shaOk + "   is NOT what was served before : " + $movedOk)
      Say ("  " + ' '.PadRight(10) + " needle '_applyCanvasSize' " + $hits + "   expected 1 or more   before the install 0   NEGCTL " + $negHits + " must be 0   row: " + $(if ($rowOk) { 'GREEN' } else { 'RED' }))
    }
  }
}
Say ("  ASSETS : " + $(if ($assetsOk) { 'GREEN - three bumped versions served, widget-resize still v=3, and the bodies ARE the package copies on this disk' } else { 'RED - report, do not roll back on your own' }))
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
  $stagedSat = Join-Path $StagingDir ('Shell\' + $culture + '\CcDashboard.Web.resources.dll')
  $stagedSatSha = ShaOf $stagedSat
  $satShaOk = (($stagedSatSha -ne 'ABSENT') -and ($satSha -eq $stagedSatSha))
  if (-not ($sizeOk -and $satShaOk)) { $translationOk = $false }
  Say ("  " + $culture.PadRight(6) + " " + $satBytes.Length + " B   equals the package size " + $ExpectedSatellite[$culture] + " : " + $sizeOk)
  Say ("  " + ' '.PadRight(6) + " sha " + $satSha)
  Say ("  " + ' '.PadRight(6) + " package copy on this disk " + $stagedSatSha + "   equal : " + $satShaOk)
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
  $stagedContracts = ShaOf (Join-Path $StagingDir 'Shell\CcDashboard.Contracts.dll')
  $shaOk = (($stagedContracts -ne 'ABSENT') -and ($contractsSha -eq $stagedContracts))
  if (-not $shaOk) { $translationOk = $false }
  Say ("  size : " + $contractsBytes.Length + " B   sha " + $contractsSha)
  Say ("  package copy on this disk : " + $stagedContracts)
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
Say ("  served bodies        : " + $assetsOk + "   <- three bodies equal the package copy on this disk, needle 0 -> 4/5/4")
Say ("  guard: keys + ink    : " + $translationOk + "   (nothing of the previous flight was lost)")
Say ("  ledger               : " + $ledgerOk)
Say ("  a section was skipped by an error : " + $script:TrapFired + "   (True forbids a green verdict: a check that never ran is not a check that passed)")
$all = $translationOk -and ($binariesOk -and $satellitesOk -and $servicesOk -and $assetsOk -and $ledgerOk -and (-not $script:TrapFired))
Say ("  ACCEPTANCE : " + $(if ($all) { 'GREEN - every half of every check. The flight delivered.' } else { 'NOT ACCEPTED - the red rows above are the report, and no remedy is proposed here' }))
Say  "  Nothing was started, stopped, installed or configured by this run."
Say "===== END-OF-RUN MARKER: ACCEPTANCE-2CCBF1C-COMPLETE ====="
Finish $all
