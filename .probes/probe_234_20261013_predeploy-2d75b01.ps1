<#
  PROBE  probe_234_20261013_predeploy-2d75b01.ps1
  ON THE CORE. Every generic helper comes from .probes/_core.ps1 and is self-tested by Start-Probe
  before this file measures anything.
  UNIT   flight 2d75b01 over the standing f333db5. Blessing: operator word "daju" 2026-10-13T10:18:59Z.
  READ-ONLY. Nothing is installed, no service is touched, no log level is changed, nothing is
  deleted. The only writes are this probe's own report under C:\RTMView-Ops\output and one
  temporary .sql file for the read below, which is printed back from disk before it is used.
  WHAT THIS PROBE IS FOR
         This flight has NO byte needle - the edit assigns four existing config properties inside
         two .razor files and produces no new string in any served file. So the acceptance rests on
         two things instead: the sha of the package in the ledger, and the BEHAVIOUR of the four
         Wfm font sizes in the viewer. Both need a BEFORE half taken on the running machine, and
         that is what this probe is. Everything it records is the "before" column the install and
         acceptance probes will be judged against.
  WHAT THE BLESSING DEMANDS, AND WHAT THAT MAKES THE PREDICATE HERE
         ALL NINE asset versions must stay put: app.css 36, styles 10, daytrend 14, asd 16,
         report 6, widget-resize 3, tokens 3, skin 3, app.js 2. The scoped bundle's sha must equal
         the one handed out before the install - a moved bundle is a STOP and a letter to the
         coordinator. Dictionaries, Contracts, engine, data.sys and the configs stay equal. So on
         this machine every single row is a "must-stay" row, and there is not one "must-change"
         row anywhere: the proof of version lives entirely in the ledger sha and the behaviour.
  WHAT THE PACKAGE SIDE ALREADY MEASURED [WS_20261013_134932_shellpkg-2d75b01.txt]
         zip 13102026.1353_Shell.zip  54140972 B  sha 8E2652AE40C3F8B53635FCA8D9F480218D04DECF8573DC56D24FAE783D2ED0D6
         The package's own copies of the nine assets, the bundle, the three dictionaries and the
         two assemblies are recorded there. They are NOT pinned into this file as expectations:
         this probe records what the MACHINE carries, and the install probe compares disk against
         the staging unpacked from that very zip, where both halves are measured at one time. The
         one number carried across is the zip sha, and it is carried to be CHECKED on this disk.
  A REBUILT ASSEMBLY'S sha IS NOT A PREDICATE - measured twice now. The two runs of the package
         probe today produced CcDashboard.Web.dll at exactly 1361408 B with different sha
         (5091CF91... and 23BC7CAF...) from the same source tree. So web.dll is compared only with
         THIS package, never with what the machine ran before, in either direction.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$PKG_SHA  = '8E2652AE40C3F8B53635FCA8D9F480218D04DECF8573DC56D24FAE783D2ED0D6'
$PKG_NAME = '13102026.1353_Shell.zip'
$FLOOR_SHA_PREFIX = '07263B55'
$SHELL_ROOT = 'C:\RTMView\Shell'
$OPS_ROOT   = 'C:\RTMView-Ops'

Start-Probe -Name 'predeploy-2d75b01' -Title 'PRE-DEPLOY READING on 234, flight 2d75b01 (Wfm font sizes)'
Say  'READ-ONLY. Nothing is installed, restarted, re-configured or deleted by this probe.'
Rule
Assert-Machine

Say '1  WHAT IS DEPLOYED NOW - the BEFORE column of every row that follows'
$deployedWeb = ShaOf (Join-Path $SHELL_ROOT 'CcDashboard.Web.dll')
$deployedContracts = ShaOf (Join-Path $SHELL_ROOT 'CcDashboard.Contracts.dll')
Say ('  CcDashboard.Web.dll       : ' + $deployedWeb)
Say ('  CcDashboard.Contracts.dll : ' + $deployedContracts)
Say  '  Recorded, not asserted. A rebuild changes an assembly sha by itself (measured twice today at'
Say  '  an identical size), so neither "equals" nor "differs" against these two is a lawful verdict.'
$negAssembly = ShaOf (Join-Path $SHELL_ROOT 'CcDashboard.NoSuchAssembly.dll')
Say ('  NEGCTL an assembly that cannot be there : ' + $negAssembly + '   (must read ABSENT, which proves the two reads above are real)')
$readsAreReal = (($deployedWeb -ne 'ABSENT') -and ($deployedContracts -ne 'ABSENT') -and ($negAssembly -eq 'ABSENT'))
Say ('  reads usable as evidence : ' + $readsAreReal)
Rule

Say '2  THE THREE DICTIONARIES - size and sha, as the BEFORE half'
Say  '  No .resx is in this delta, so the blessing requires them equal. Size is the comparable half;'
Say  '  the sha is recorded only so the install probe can say whether the file on disk was replaced.'
$satelliteRows = @()
foreach ($culture in @('he-IL','ru-RU','en-US')) {
  $satellitePath = Join-Path $SHELL_ROOT ($culture + '\CcDashboard.Web.resources.dll')
  if (Test-Path -LiteralPath $satellitePath) {
    $satelliteSize = (Get-Item -LiteralPath $satellitePath).Length
    Say ('  ' + $culture.PadRight(8) + ([string]$satelliteSize).PadLeft(7) + ' B  ' + (ShaOf $satellitePath))
    $satelliteRows += ,@($culture, $satelliteSize)
  } else { Say ('  ' + $culture.PadRight(8) + ' ABSENT  <- finding') }
}
Say ('  cultures read : ' + $satelliteRows.Count + '   (expected 3)')
Rule

Say '3  SERVICES AND THEIR PIDS - the install report compares against THESE numbers'
$serviceRows = @()
foreach ($serviceName in @('RTMViewShell','RTMService','RTMTwilio_1')) {
  $serviceState = StateOf $serviceName
  Say ('  ' + $serviceName.PadRight(14) + ' state ' + ([string]$serviceState.State).PadRight(9) + ' pid ' + $serviceState.ProcessId)
  $serviceRows += ,@($serviceName, $serviceState.State, $serviceState.ProcessId)
}
$negService = StateOf 'RTMNoSuchService'
Say ('  NEGCTL a service that cannot exist : ' + $negService.State + '   (must read ABSENT)')
Say  '  The blessing says all three pids change at the install. A pid that did NOT change means the'
Say  '  process was never restarted and is still running the previous assemblies.'
Rule

Say '4  THE NINE ASSET VERSIONS THE SERVER SERVES RIGHT NOW'
Say  '  EVERY ONE OF THEM IS A MUST-STAY ROW. There is not a single must-change row in this flight,'
Say  '  because no wwwroot file and no "?v=" line is in the delta. A bumped number here is the'
Say  '  finding, not the pass - which inverts the shape of the four flights before this one.'
$curl = "$env:SystemRoot\System32\curl.exe"
$html = ''
$fetchOk = $false
if (-not (Test-Path -LiteralPath $curl)) { Say '  *** curl.exe ABSENT - the served half is NOT MEASURED' }
else {
  $base = 'https://127.0.0.1:8444'
  $httpCode = (& $curl -k -s -L -o NUL -w '%{http_code}' --max-time 20 ($base + '/')) 2>$null
  $html     = (& $curl -k -s -L --max-time 20 ($base + '/')) 2>$null
  $bodyChars = ('' + $html).Length
  Say ('  http code : ' + $httpCode + '   body chars : ' + $bodyChars)
  $fetchOk = ((("$httpCode") -eq '200') -and ($bodyChars -ge 2000))
  Say ('  fetch usable as evidence : ' + $fetchOk + '   (under 2000 chars is a redirect wrapper, not a page)')
  $negCode = (& $curl -k -s -o NUL -w '%{http_code}' --max-time 20 ($base + '/zzz-no-such-endpoint')) 2>$null
  Say ('  NEGCTL /zzz-no-such-endpoint -> ' + $negCode + '   (must be neither 200 nor 000)')
}
$versionsHold = $fetchOk
if ($fetchOk) {
  $assetExpectations = @(
    @('app.css','36'), @('CcDashboard.Web.styles.css','10'), @('tokens.css','3'),
    @('wallboard-skin.css','3'), @('app.js','2'), @('widget-resize.js','3'),
    @('daytrendChart.js','14'), @('agentStateDistributionChart.js','16'), @('reportDistributionChart.js','6')
  )
  foreach ($assetExpectation in $assetExpectations) {
    $leaf = $assetExpectation[0]
    $expectedVersion = $assetExpectation[1]
    $found = @([regex]::Matches($html, [regex]::Escape($leaf) + '\?v=(\d+)') | ForEach-Object { $_.Groups[1].Value })
    $foundText = $(if ($found.Count -gt 0) { ($found -join ',') } else { 'NONE' })
    $agrees = ($found -contains $expectedVersion)
    Say ('  ' + $leaf.PadRight(34) + ' expected now v=' + $expectedVersion.PadRight(3) + ' served v=' + $foundText.PadRight(7) + ' ' + $(if ($agrees) { 'agrees' } else { 'DISAGREES <- finding' }))
    if (-not $agrees) { $versionsHold = $false }
  }
  $negAsset = ([regex]::Matches($html, 'zzz-no-such-asset\.css\?v=\d+')).Count
  Say ('  NEGCTL an asset that cannot be served : ' + $negAsset + ' hits (expected 0; the nine reads above prove the same regex finds real ones)')
  if ($negAsset -ne 0) { $versionsHold = $false }
}
Say ('  all nine hold at the blessed numbers : ' + $versionsHold)
Rule

Say '5  THE BODIES ON DISK - the BEFORE half the acceptance compares against'
Say  '  These are plain text files, not built assemblies, so their sha IS a lawful predicate and'
Say  '  EVERY ONE must come out unchanged after the install.'
$staticPaths = @(
  'wwwroot\app.css', 'wwwroot\app.js', 'wwwroot\css\tokens.css', 'wwwroot\css\widgets\wallboard-skin.css',
  'wwwroot\js\widget-resize.js', 'wwwroot\js\daytrendChart.js',
  'wwwroot\js\agentStateDistributionChart.js', 'wwwroot\js\reportDistributionChart.js'
)
$staticRead = 0
foreach ($staticPath in $staticPaths) {
  $fullPath = Join-Path $SHELL_ROOT $staticPath
  if (-not (Test-Path -LiteralPath $fullPath)) { Say ('  ' + $staticPath.PadRight(44) + ' ABSENT ON DISK  <- finding') ; continue }
  Say ('  ' + $staticPath.PadRight(44) + ([string](Get-Item -LiteralPath $fullPath).Length).PadLeft(7) + ' B  ' + (ShaOf $fullPath))
  $staticRead++
}
Say ('  static files read : ' + $staticRead + '   (expected 8; the bundle is section 6 on its own)')
Rule

Say '6  THE SCOPED BUNDLE, ON ITS OWN, BECAUSE THE BLESSING STOPS THE FLIGHT ON IT'
$bundlePath = Join-Path $SHELL_ROOT 'wwwroot\CcDashboard.Web.styles.css'
$bundleSha = ShaOf $bundlePath
$bundleSize = $(if (Test-Path -LiteralPath $bundlePath) { (Get-Item -LiteralPath $bundlePath).Length } else { 0 })
Say ('  on disk now : ' + $bundleSize + ' B  ' + $bundleSha)
Say ('  in this package [shellpkg report] : 25731 B  D2F85CB1B8ADFFE53D5583342B0D17806AC1CB7537D6A2EC75DEDF9057D5972E')
$bundleAgrees = ($bundleSha -eq 'D2F85CB1B8ADFFE53D5583342B0D17806AC1CB7537D6A2EC75DEDF9057D5972E')
Say ('  disk == package : ' + $bundleAgrees)
Say  '  The bundle is generated from the .razor.css files and no .razor.css is in this delta, so the'
Say  '  two must already be equal BEFORE the install - and equal again after it. If this row is'
Say  '  False here, the flight stops and the coordinator is written to, exactly as the blessing says:'
Say  '  it would mean the scoped CSS moved without a .razor.css in the delta, which I cannot explain.'
Rule

Say '7  ROLLBACK FLOOR - artefacts on this disk, with hashes, BEFORE anything is written'
$floorFound = $false
foreach ($packageFile in @(Get-ChildItem -LiteralPath (Join-Path $OPS_ROOT 'incoming') -Filter *.zip -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 8)) {
  $packageSha = ShaOf $packageFile.FullName
  $isFloor = $packageSha.StartsWith($FLOOR_SHA_PREFIX)
  $isNew   = ($packageSha -eq $PKG_SHA)
  $label = $(if ($isFloor) { 'ROLLBACK FLOOR f333db5' } elseif ($isNew) { 'THE PACKAGE OF THIS FLIGHT' } else { '' })
  Say ('  ' + $packageFile.Name.PadRight(30) + ([string]$packageFile.Length).PadLeft(10) + ' B  ' + $packageSha.Substring(0,16) + '...  ' + $label)
  if ($isFloor) { $floorFound = $true }
}
Say ('  expected : a package whose sha begins ' + $FLOOR_SHA_PREFIX + ' is present as the floor')
Say ('  measured : ' + $floorFound)
Rule

Say '8  THE PACKAGE TO BE INSTALLED - is it on this disk yet, and is it the right bytes'
$incomingPath = Join-Path (Join-Path $OPS_ROOT 'incoming') $PKG_NAME
$packagePresent = Test-Path -LiteralPath $incomingPath
Say ('  expected : ' + $PKG_NAME + '  sha ' + $PKG_SHA)
if (-not $packagePresent) {
  Say  '  measured : NOT ON THIS DISK YET - it still has to be copied over. Not a finding at this step.'
} else {
  $incomingSha = ShaOf $incomingPath
  Say ('  measured : ' + (Get-Item -LiteralPath $incomingPath).Length + ' B  ' + $incomingSha)
  Say ('  sha == the package built from 2d75b01 : ' + ($incomingSha -eq $PKG_SHA))
}
Rule

Say '9  WHAT THE BEHAVIOURAL ACCEPTANCE WILL NEED - are any Wfm font sizes set in the data today'
Say  '  The acceptance is behavioural: the computed font-size of the four Wfm roles in the viewer'
Say  '  must equal what is chosen in the editor. That is only measurable if a screen actually has'
Say  '  a Wfm widget. This read answers whether one exists and whether the four keys are already'
Say  '  in its config - it does NOT change a single row.'
$sqlDir = Join-Path $OPS_ROOT 'probes'
if (-not (Test-Path -LiteralPath $sqlDir)) { New-Item -ItemType Directory -Force -Path $sqlDir | Out-Null }
$sqlPath = Join-Path $sqlDir 'predeploy_2d75b01_wfm.sql'
$sqlText = @(
  "SELECT count(*) AS wfm_widgets",
  "FROM screen s, jsonb_array_elements(s.layout::jsonb -> 'widgets') w",
  "WHERE w ->> 'type' = 'wfm';"
) -join "`r`n"
[IO.File]::WriteAllText($sqlPath, $sqlText + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
Say  '  the query, printed back FROM DISK so what ran is what is shown (a -c string loses the quotes):'
foreach ($sqlLine in (Get-Content -LiteralPath $sqlPath)) { Say ('    | ' + $sqlLine) }
$psql = 'C:\Program Files\PostgreSQL\16\bin\psql.exe'
if (-not (Test-Path -LiteralPath $psql)) { Say ('  psql not at ' + $psql + ' - this section is NOT MEASURED') }
else {
  $queryOutput = @(Invoke-Native { & $psql -h 127.0.0.1 -p 5433 -U ccdash -d ccdashboard -t -A -f $sqlPath 2>&1 })
  $dataRows = Select-DataRows $queryOutput
  foreach ($outputLine in $queryOutput) { Say ('    ' + $outputLine) }
  Say ('  data rows : ' + $dataRows.Count + '   (a row counter, so it carries its own controls below)')
  Say ('  POSCTL a shape UNLIKE the question: Select-DataRows over three ERROR lines and one value is')
  Say ('         exercised in the core self-test at the top of this report and must read 1 of 4.')
  Say  '  If the count is 0 there is no Wfm widget on any screen, and the behavioural acceptance needs'
  Say  '  one placed first - that is a question for the coordinator, not something this probe invents.'
}
Rule

Say '10  DISK - a pair, not one number'
foreach ($driveName in @('C','D')) {
  $drive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
  if ($null -eq $drive) { Say ('  ' + $driveName + ': absent') ; continue }
  Say ('  ' + $driveName + ': free ' + [math]::Round($drive.Free/1GB,1) + ' GB of ' + [math]::Round(($drive.Free+$drive.Used)/1GB,1) + ' GB')
}
Say ('  the package is ' + [math]::Round(54140972/1MB,0) + ' MB and the installer keeps a backup set, so the pair above is what says whether it fits')
Rule

Say 'VERDICT OF THE PRE-DEPLOY READING'
Say ('  trap fired during the run           : ' + (Test-TrapFired) + '   (True means a section was SKIPPED, not passed)')
Say ('  section 1 assembly reads are real   : ' + $readsAreReal)
Say ('  section 4 all nine versions hold    : ' + $versionsHold)
Say ('  section 6 bundle disk == package    : ' + $bundleAgrees)
Say ('  section 7 rollback floor present    : ' + $floorFound)
$all = ($readsAreReal -and $versionsHold -and $bundleAgrees -and $floorFound -and (-not (Test-TrapFired)))
Say ('  PRE-DEPLOY : ' + $(if ($all) { 'THE BEFORE COLUMN IS TAKEN AND THE MACHINE IS AS THE BLESSING DESCRIBES' } else { 'STOP - see the False rows above' }))
Say  '  Nothing was installed. The install step is a separate box and re-reads the inbox first.'
Finish $all
