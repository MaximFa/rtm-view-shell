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
$ReportPath = Join-Path $OutputDir ("234_{0}_acceptance-e6a0fcb.txt" -f $RunStamp)
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
$ExpectedCommit  = 'e6a0fcb'
$ExpectedWebDll  = 'CE15C4A4E52D643576C878C4F1AAFDFC4D467D7D9017EEE20672E77394C567A8'
$EngineMustStay  = '097F087D66497A4C59C5216E8BB46E1C4F49739A2B2A2A6621483BD0DC1C10AB'
$WebDllBefore    = 'B88B851D64FB014FEC9C10A3287EE6DD776699BECAFD74C94BD5FCB168434E62'
# WHAT THE PACKAGE CARRIES - the verdict is EQUALS THE PACKAGE, never 'unchanged' and never 'grew'.
# Only he-IL carries changed values in this delta, and only values, so it moved by one 512-byte
# alignment step while ru-RU and en-US did not move at all. These three numbers are the PACKAGE
# numbers measured on the station when 11102026.0035_Shell.zip was built, and the install report
# of 00:48Z measured the same three on disk. Size is a note here: the content is proven in
# section 6 by a byte search for the Hebrew values themselves.
$ExpectedSatellite = @{ 'he-IL' = 77824 ; 'ru-RU' = 87552 ; 'en-US' = 70656 }
# pids measured before this install [234_20261011_004806_install-e6a0fcb.txt, PRE-STATE]
$PidBefore = @{ 'RTMService' = 12196 ; 'RTMViewShell' = 4692 ; 'RTMTwilio_1' = 2696 }

Say ("ACCEPTANCE OF e6a0fcb  " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
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

Say "4  THE NINE ASSET VERSIONS - PRESENCE ONLY, AND THE PREDICATE IS INVERTED HERE"
Say  "  This flight changes .resx values and Razor code. No wwwroot file and no version attribute"
Say  "  is in the delta [measured on the station while the package was built: the nine ?v= values"
Say  "  came out of e6a0fcb exactly as 4634162 left them]. A BUMPED number here would therefore be"
Say  "  the finding, not the pass, and version numbers prove NOTHING about this delivery."
Say  "  Positive half: all nine still served. Negative half: the next number up of each is absent -"
Say  "  which is what a rebuilt asset would have printed. Both halves, or the row is not a check."
$assetsOk = $true
if (-not $fetchOk) {
  Say "  *** NOT MEASURED - the fetch above did not produce a page. Nothing is asserted here."
  $assetsOk = $false
} else {
  # each row: what must be present, and the next version up, which must be absent
  $pairs = @()
  $pairs += ,@('CcDashboard.Web.styles.css?v=7', 'CcDashboard.Web.styles.css?v=8')
  $pairs += ,@('agentStateDistributionChart.js?v=10', 'agentStateDistributionChart.js?v=11')
  $pairs += ,@('daytrendChart.js?v=7', 'daytrendChart.js?v=8')
  $pairs += ,@('reportDistributionChart.js?v=4', 'reportDistributionChart.js?v=5')
  $pairs += ,@('widget-resize.js?v=3', 'widget-resize.js?v=4')
  $pairs += ,@('app.css?v=35', 'app.css?v=36')
  $pairs += ,@('tokens.css?v=3', 'tokens.css?v=4')
  $pairs += ,@('wallboard-skin.css?v=3', 'wallboard-skin.css?v=4')
  $pairs += ,@('app.js?v=2', 'app.js?v=3')
  Say ("  rows to measure : " + $pairs.Count + "   expected 9   (a smaller number means the list unrolled)")
  if ($pairs.Count -ne 9) { $assetsOk = $false ; Say "  *** the row list is not nine rows - not measured" }
  foreach ($pair in $pairs) {
    $want = $pair[0]
    $next = $pair[1]
    $wantCount = ([regex]::Matches($html, [regex]::Escape($want))).Count
    $nextCount = ([regex]::Matches($html, [regex]::Escape($next))).Count
    $rowOk = (($wantCount -ge 1) -and ($nextCount -eq 0))
    if (-not $rowOk) { $assetsOk = $false }
    Say ("  " + $want.PadRight(36) + " present " + $wantCount + "   next-up '" + $next + "' " + $nextCount + " (must be 0)   row: " + $(if ($rowOk) { 'GREEN' } else { 'RED' }))
  }
  $negAsset = ([regex]::Matches($html, [regex]::Escape('zzz-no-such-asset.css?v=99'))).Count
  Say ("  NEGCTL same reader, asset that cannot be there : " + $negAsset + "   must be 0")
  if ($negAsset -ne 0) { $assetsOk = $false }
  Rule
  Say "4b  THE FOUR CHART SCRIPTS - the served body against the file on disk, read NOW"
  Say  "  No byte count is carried in from a previous flight here. The expectation is the file"
  Say  "  that lies on this disk at this minute: served size = disk size and served sha = disk sha."
  Say  "  A carried-over byte count is exactly what printed four false +512 numbers of mine on 10.10."
  $scripts = @('agentStateDistributionChart.js', 'daytrendChart.js', 'reportDistributionChart.js', 'widget-resize.js')
  $versions = @{ 'agentStateDistributionChart.js' = '10' ; 'daytrendChart.js' = '7' ; 'reportDistributionChart.js' = '4' ; 'widget-resize.js' = '3' }
  foreach ($leaf in $scripts) {
    $version = $versions[$leaf]
    $tmp = Join-Path $env:TEMP ($leaf + '.served')
    $onDisk = 'C:\RTMView\Shell\wwwroot\js\' + $leaf
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    & $curl -k -s --max-time 20 -o $tmp ('https://127.0.0.1:8444/js/' + $leaf + '?v=' + $version)
    if (-not (Test-Path -LiteralPath $tmp)) { Say ("  " + $leaf.PadRight(32) + " NOTHING FETCHED - not measured") ; $assetsOk = $false ; continue }
    if (-not (Test-Path -LiteralPath $onDisk)) { Say ("  " + $leaf.PadRight(32) + " NOT ON DISK - not measured") ; $assetsOk = $false ; continue }
    $servedBytes = (Get-Item -LiteralPath $tmp).Length
    $diskBytes   = (Get-Item -LiteralPath $onDisk).Length
    $shaServed = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash
    $shaDisk   = (Get-FileHash -LiteralPath $onDisk -Algorithm SHA256).Hash
    $rowOk = (($servedBytes -eq $diskBytes) -and ($shaServed -eq $shaDisk))
    if (-not $rowOk) { $assetsOk = $false }
    Say ("  " + $leaf.PadRight(32) + " served " + $servedBytes + " B   on disk " + $diskBytes + " B   served IS the file on disk: " + ($shaServed -eq $shaDisk) + "   row: " + $(if ($rowOk) { 'GREEN' } else { 'RED' }))
  }
  Say  "  NEGCTL of this reader: /js/zzz-no-such-script.js must not produce a body"
  $negTmp = Join-Path $env:TEMP 'zzz_no_such_script.served'
  if (Test-Path -LiteralPath $negTmp) { Remove-Item -LiteralPath $negTmp -Force -ErrorAction SilentlyContinue }
  & $curl -k -s --max-time 20 -o $negTmp 'https://127.0.0.1:8444/js/zzz-no-such-script.js?v=1'
  $negLen = 0
  if (Test-Path -LiteralPath $negTmp) { $negLen = (Get-Item -LiteralPath $negTmp).Length }
  Say ("  NEGCTL body : " + $negLen + " B   a large body here would mean this reader returns a page for anything")
  if ($negLen -ge 1000) { $assetsOk = $false }
}
Say ("  ASSETS : " + $(if ($assetsOk) { 'GREEN - the nine versions are served and NOT ONE of them moved, as this delta requires' } else { 'RED - report, do not roll back on your own' }))
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

Say "6  THE TRANSLATION ITSELF - a byte search in the he-IL dictionary that now lies on this disk"
Say  "  THIS SECTION IS THE ACCEPTANCE OF THIS FLIGHT. Everything above only says that a new"
Say  "  binary landed and that nothing else moved. What was asked for is Hebrew where English was."
Say  "  The needles are built from code points below, not typed as literals, so no encoding of this"
Say  "  file, of the console or of the transfer can turn a needle into question marks and a real"
Say  "  finding into a green row. Each needle is ALSO searched as UTF-16LE, because a managed"
Say  "  resource dictionary may store its strings either way and a one-encoding search that finds"
Say  "  nothing proves nothing: on 10.10 decoding this satellite as text found 0 of 7 keys that"
Say  "  were all present."
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
# the needles, each assigned to its own variable BEFORE any array literal. On 11.10 the pre-deploy
# probe built these inside the literal and printed an empty meaning for two rows - the strings were
# right, the report was unreadable. The letters are given as code points and printed as such.
$HebTile = [string]::Join('', ([char]0x05DE, [char]0x05D3, [char]0x05D3, [char]0x05D9, [char]0x0020, [char]0x05D0, [char]0x05E8, [char]0x05D9, [char]0x05D7))
$HebNoData = [string]::Join('', ([char]0x05D0, [char]0x05D9, [char]0x05DF, [char]0x0020, [char]0x05E0, [char]0x05EA, [char]0x05D5, [char]0x05E0, [char]0x05D9, [char]0x05DD))
$EngTile = 'Tile Metrics'
$EngNoData = 'No Data'
$satHe = 'C:\RTMView\Shell\he-IL\CcDashboard.Web.resources.dll'
Say ("  file : " + $satHe + "   present : " + (Test-Path -LiteralPath $satHe))
if (-not (Test-Path -LiteralPath $satHe)) {
  Say "  *** the he-IL dictionary is not on disk - NOT MEASURED, and that alone is a red flight"
  $translationOk = $false
} else {
  $bytes = [IO.File]::ReadAllBytes($satHe)
  Say ("  size : " + $bytes.Length + " B   expected = package " + $ExpectedSatellite['he-IL'] + "   match: " + ($bytes.Length -eq $ExpectedSatellite['he-IL']))
  if ($bytes.Length -ne $ExpectedSatellite['he-IL']) { $translationOk = $false }
  Say ("  sha256 : " + (ShaOf $satHe))
  Say  "  SELF-TEST OF THE READER, before it is allowed to say 'absent' about anything:"
  $posNeedle = 'CcDashboard'
  $posU8 = Find-ByteRun $bytes ([Text.Encoding]::UTF8.GetBytes($posNeedle))
  $posU16 = Find-ByteRun $bytes ([Text.Encoding]::Unicode.GetBytes($posNeedle))
  $negOff = Find-ByteRun $bytes ([Text.Encoding]::UTF8.GetBytes('zzz-no-such-string-in-any-dictionary'))
  Say ("    POSCTL '" + $posNeedle + "' utf8 offset " + $posU8 + " / utf16 offset " + $posU16 + "   at least one must be >= 0")
  Say ("    NEGCTL a string that cannot be there : " + $negOff + "   must be -1")
  $readerOk = ((($posU8 -ge 0) -or ($posU16 -ge 0)) -and ($negOff -eq -1))
  Say ("    READER : " + $(if ($readerOk) { 'TRUSTED' } else { 'NOT TRUSTED - nothing below is counted' }))
  if (-not $readerOk) { $translationOk = $false }
  if ($readerOk) {
    $rows = @()
    $rows += ,@('HE  tile metrics', $HebTile,   'PRESENT')
    $rows += ,@('HE  no data',      $HebNoData, 'PRESENT')
    $rows += ,@('EN  tile metrics', $EngTile,   'GONE')
    $rows += ,@('EN  no data',      $EngNoData, 'GONE')
    Say ("  rows to measure : " + $rows.Count + "   expected 4")
    if ($rows.Count -ne 4) { $translationOk = $false ; Say "  *** the needle list is not four rows - not measured" }
    Say  "  BEFORE THIS INSTALL, measured on this machine at 00:41Z [234_20261011_004112_predeploy-e6a0fcb.txt]:"
    Say  "    the two English needles were PRESENT (utf8 offsets 69648 and 69617) and both Hebrew"
    Say  "    needles were ABSENT in both encodings. So each row below is a real change of state,"
    Say  "    not an assumption, and the English rows are the negative half of the Hebrew ones."
    foreach ($row in $rows) {
      $label = $row[0]
      $needle = $row[1]
      $expect = $row[2]
      $points = (($needle.ToCharArray() | ForEach-Object { 'U+{0:X4}' -f [int]$_ }) -join ' ')
      $offU8 = Find-ByteRun $bytes ([Text.Encoding]::UTF8.GetBytes($needle))
      $offU16 = Find-ByteRun $bytes ([Text.Encoding]::Unicode.GetBytes($needle))
      $found = (($offU8 -ge 0) -or ($offU16 -ge 0))
      if ($expect -eq 'PRESENT') { $rowOk = $found } else { $rowOk = (-not $found) }
      if (-not $rowOk) { $translationOk = $false }
      Say ("  " + $label.PadRight(16) + " expect " + $expect.PadRight(8) + " utf8 " + $offU8 + "   utf16 " + $offU16 + "   row: " + $(if ($rowOk) { 'GREEN' } else { 'RED' }))
      Say ("                   needle as code points : " + $points)
    }
  }
}
Say ("  TRANSLATION : " + $(if ($translationOk) { 'GREEN - the Hebrew values are in the dictionary the server loads, and the English ones are gone' } else { 'RED - report it, roll nothing back' }))
Rule
Say "VERDICT"
Say ("  binaries on disk     : " + $binariesOk)
Say ("  satellites equal the package : " + $satellitesOk)
Say ("  services restarted   : " + $servicesOk)
Say ("  served assets        : " + $assetsOk + "   (nine present, none bumped - a guard here, not the goal)")
Say ("  THE TRANSLATION      : " + $translationOk + "   <- this is what the flight was for")
Say ("  ledger               : " + $ledgerOk)
Say ("  a section was skipped by an error : " + $script:TrapFired + "   (True forbids a green verdict: a check that never ran is not a check that passed)")
$all = $translationOk -and ($binariesOk -and $satellitesOk -and $servicesOk -and $assetsOk -and $ledgerOk -and (-not $script:TrapFired))
Say ("  ACCEPTANCE : " + $(if ($all) { 'GREEN - every half of every check. The flight delivered.' } else { 'NOT ACCEPTED - the red rows above are the report, and no remedy is proposed here' }))
Say  "  Nothing was started, stopped, installed or configured by this run."
Say "===== END-OF-RUN MARKER: ACCEPTANCE-E6A0FCB-COMPLETE ====="
Finish $all
