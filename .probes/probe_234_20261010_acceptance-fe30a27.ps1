<#
  PROBE  probe_234_20261010_acceptance-fe30a27.ps1
  BASED  ON probe_234_20261010_acceptance-6b720b2.ps1 - the PREVIOUS flight of today. Every pin is
         re-derived from this delta and from the pre-deploy reading taken at 13:48.
  UNIT   acceptance of the Shell flight v4 fe30a27, installed on 234 on 2026-10-10 13:52-13:54. It
         fixes the regression the operator found: the font-size setting not reaching table rows.
  WHY THE PROOF IS NOT ON DISK  the point of the flight is what the live service SERVES. A file on
         disk proves nothing here and neither does a 200 on /health.
  NINE ASSETS, AND ONLY TWO HAVE A NEGATIVE HALF - derived from git, not overlooked
         tokens.css                       v=3 present , v=2 gone
         CcDashboard.Web.styles.css       v=5 present , v=4 gone
         app.css v=35 · wallboard-skin.css v=3 · agentStateDistributionChart.js v=7 ·
         daytrendChart.js v=4 · widget-resize.js v=2 · reportDistributionChart.js v=2 ·
         app.js v=2  -> PRESENCE ONLY. Read from App.razor in BOTH revisions today: these seven are
         identical in the two, so there is no stale number to vanish and demanding one would paint a
         correct install red. app.js is in the list because I read the markup myself - it is not in
         the coordinator's letter.
         The two "now" values were MEASURED on this machine before the install
         [234_20261010_134820_predeploy-fe30a27.txt: tokens v=2, styles v=4], so the two negative
         halves are real observations, not assumptions about what used to be there.
  THE BODIES ARE CHECKED TOO, not only the numbers in the links
         tokens.css: expected 14999 B from the v4 blob 233d7d04, and the sha256 of what the server
         hands out must equal the sha256 of the file on disk.
         CcDashboard.Web.styles.css: the three NEEDLES OF THE FIX, measured in the blobs today with
         the file each lives in - 0.9857em appears (QueueGridWidget.razor.css), 0.9em appears
         (AgentGridWidget.razor.css), 0.8625rem DISAPPEARS (QueueGridWidget.razor.css). Those
         .razor.css files compile into this one served file, which is why the needles are provable
         in its body and not as files of their own. A version number can be bumped without the rule
         changing; the needles are what prove the fix itself landed.
  WHERE  SERVER 234. READ ONLY. No service is started, stopped or configured. Nothing is installed.
         The adapter is never started by hand. Legacy RTM is not touched.
#>

$ErrorActionPreference = 'Continue'
$RunStartedAt = Get-Date
$RunStamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir = 'C:\RTMView-Ops\output'
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }
$ReportPath = Join-Path $OutputDir ("234_{0}_acceptance-fe30a27.txt" -f $RunStamp)
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
$ExpectedCommit  = 'fe30a27'
$ExpectedWebDll  = '010934A3577889EFCECB3AC1139D1D43777E50396D129F6BBDAA40ACCC484F72'
$EngineMustStay  = '097F087D66497A4C59C5216E8BB46E1C4F49739A2B2A2A6621483BD0DC1C10AB'
$WebDllBefore    = '6F05414CC4C7A96E6462013088FABE7E387DBE4159520BCCC4B691EE3CF0A13D'
$ExpectedSatellite = @{ 'he-IL' = 77312 ; 'ru-RU' = 87040 ; 'en-US' = 70144 }
# pids measured before this install [234_20261010_134820_predeploy-fe30a27.txt]
$PidBefore = @{ 'RTMService' = 4568 ; 'RTMViewShell' = 3088 ; 'RTMTwilio_1' = 4164 }

Say ("ACCEPTANCE OF fe30a27  " + $RunStartedAt.ToString('yyyy-MM-dd HH:mm:ss') + " (machine local clock)  host=" + $env:COMPUTERNAME)
Say  "READ ONLY. The adapter is NOT started by hand - the engine owns its lifecycle."
Say ("probe sha256 : " + (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
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
  Say ("  satellite " + $culture.PadRight(6) + " " + $satelliteSize + " B   expected UNCHANGED " + $want + "   match: " + ($satelliteSize -eq $want))
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

Say "4  THE FIVE ASSET VERSIONS, EACH AS A PAIR"
$assetsOk = $true
if (-not $fetchOk) {
  Say "  *** NOT MEASURED - the fetch above did not produce a page. Nothing is asserted here."
  $assetsOk = $false
} else {
  # Each row: what must be present, what must be GONE, and '' when there is no negative half.
  $pairs = @()
  $pairs += ,@('tokens.css?v=3', 'tokens.css?v=2')
  $pairs += ,@('CcDashboard.Web.styles.css?v=5', 'CcDashboard.Web.styles.css?v=4')
  $pairs += ,@('app.css?v=35', '')
  $pairs += ,@('wallboard-skin.css?v=3', '')
  $pairs += ,@('agentStateDistributionChart.js?v=7', '')
  $pairs += ,@('daytrendChart.js?v=4', '')
  $pairs += ,@('widget-resize.js?v=2', '')
  $pairs += ,@('reportDistributionChart.js?v=2', '')
  $pairs += ,@('app.js?v=2', '')
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
      Say ("  " + $want.PadRight(36) + " present " + $wantCount + "   stale '" + $stale + "' " + $staleCount + "   row: " + $(if ($rowOk) { 'GREEN' } else { 'RED' }))
    }
  }
  $negAsset = ([regex]::Matches($html, [regex]::Escape('zzz-no-such-asset.css?v=99'))).Count
  Say ("  NEGCTL same reader, asset that cannot be there : " + $negAsset + "   must be 0")
  Say  "  Every row with a stale half needs BOTH: the new number present AND the old one gone."
  Say  "  Presence alone would also be satisfied by an HTML served from a place the flight never"
  Say  "  reached. The four stale values were measured on THIS machine at 11:14 today, before the"
  Say  "  install - so their disappearance is a real observation, not an assumption."
  Rule
  Say "4b  THE BODY OF tokens.css - the number in the link is not the file"
  $cssTmp = Join-Path $env:TEMP 'tokens_served_fe30a27.css'
  $cssOnDisk = 'C:\RTMView\Shell\wwwroot\css\tokens.css'
  Say  "  expected from the v4 blob 233d7d04 : 14999 B"
  & $curl -k -s --max-time 20 -o $cssTmp 'https://127.0.0.1:8444/css/tokens.css?v=3'
  if (-not (Test-Path -LiteralPath $cssTmp)) { Say "  *** NOTHING FETCHED - not measured" ; $assetsOk = $false }
  else {
    $cssServedBytes = (Get-Item -LiteralPath $cssTmp).Length
    Say ("  served : " + $cssServedBytes + " B   match: " + ($cssServedBytes -eq 14999))
    Say ("  on disk exists : " + (Test-Path -LiteralPath $cssOnDisk))
    if (Test-Path -LiteralPath $cssOnDisk) {
      $shaServed = (Get-FileHash -LiteralPath $cssTmp -Algorithm SHA256).Hash
      $shaDisk   = (Get-FileHash -LiteralPath $cssOnDisk -Algorithm SHA256).Hash
      Say ("  sha256 served  : " + $shaServed)
      Say ("  sha256 on disk : " + $shaDisk)
      Say ("  the server hands out the file that was installed : " + ($shaServed -eq $shaDisk) + "   expected True")
      if (($shaServed -ne $shaDisk) -or ($cssServedBytes -ne 14999)) { $assetsOk = $false }
    } else { $assetsOk = $false }
  }
  Rule
  Say "4c  THE NEEDLES OF THE FIX, inside the served styles file"
  Say  "  A bumped version number proves a new file was served. It does NOT prove the rule changed."
  Say  "  These three were measured in the blobs today, each with the file it lives in."
  $styTmp = Join-Path $env:TEMP 'styles_served_fe30a27.css'
  & $curl -k -s --max-time 20 -o $styTmp 'https://127.0.0.1:8444/CcDashboard.Web.styles.css?v=5'
  if (-not (Test-Path -LiteralPath $styTmp)) { Say "  *** NOTHING FETCHED - not measured" ; $assetsOk = $false }
  else {
    $styBytes = (Get-Item -LiteralPath $styTmp).Length
    Say ("  served : " + $styBytes + " B")
    if ($styBytes -lt 1000) { Say "  *** body under 1000 B - that is not the styles file. Not searched." ; $assetsOk = $false }
    else {
      $styText = Get-Content -LiteralPath $styTmp -Raw
      foreach ($needle in @(@('0.9857em', 1, 'QueueGridWidget.razor.css'), @('0.9em', 1, 'AgentGridWidget.razor.css'), @('0.8625rem', 0, 'QueueGridWidget.razor.css - must be GONE'))) {
        $found = ([regex]::Matches($styText, [regex]::Escape($needle[0]))).Count
        $wanted = $needle[1]
        $rowOk = if ($wanted -eq 0) { $found -eq 0 } else { $found -ge 1 }
        if (-not $rowOk) { $assetsOk = $false }
        Say ("  " + $needle[0].PadRight(12) + " found " + $found + "   expected " + $(if ($wanted -eq 0) { '0' } else { '1 or more' }) + "   [" + $needle[2] + "]   row: " + $(if ($rowOk) { 'GREEN' } else { 'RED' }))
      }
      Say ("  NEGCTL same reader, value that cannot be there : " + ([regex]::Matches($styText, [regex]::Escape('0.1234zz'))).Count + "   must be 0")
    }
  }
}
Say ("  ASSETS : " + $(if ($assetsOk) { 'GREEN - the server is serving the bumped versions' } else { 'RED - report, do not roll back on your own' }))
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

Say "VERDICT"
Say ("  binaries on disk     : " + $binariesOk)
Say ("  satellites unchanged : " + $satellitesOk)
Say ("  services restarted   : " + $servicesOk)
Say ("  SERVED ASSET VERSIONS: " + $assetsOk + "   <- this is what the flight was for")
Say ("  ledger               : " + $ledgerOk)
Say ("  a section was skipped by an error : " + $script:TrapFired + "   (True forbids a green verdict: a check that never ran is not a check that passed)")
$all = ($binariesOk -and $satellitesOk -and $servicesOk -and $assetsOk -and $ledgerOk -and (-not $script:TrapFired))
Say ("  ACCEPTANCE : " + $(if ($all) { 'GREEN - every half of every check. The flight delivered.' } else { 'NOT ACCEPTED - the red rows above are the report, and no remedy is proposed here' }))
Say  "  Nothing was started, stopped, installed or configured by this run."
Say "===== END-OF-RUN MARKER: ACCEPTANCE-FE30A27-COMPLETE ====="
Finish $all
