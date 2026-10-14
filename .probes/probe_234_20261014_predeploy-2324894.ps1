<#
  PROBE  probe_234_20261014_predeploy-2324894.ps1
  ON THE CORE. READ-ONLY: nothing is installed, restarted or re-configured, no log level is touched.
  UNIT   flight 2324894 over the standing 2d75b01. Blessing 2026-10-14T06:18:42Z, operator word in it.
  THE BEFORE HALF OF A DISAPPEARING NEEDLE IS THE WHOLE POINT OF THIS STEP.
         This flight must REMOVE the UTF-16 string "[PROBE" from web.dll. A zero after the install
         proves nothing unless the count before it is non-zero - otherwise the row would pass on a
         package that changed nothing, which is the purest false green. So the count is taken here,
         on the machine, in both encodings, and the acceptance is judged against it.
         The same in the other direction for the three needles that must APPEAR: the bundle's
         "1fr auto 38px", Application.dll's GetTenantStatusGroupsQuery, and the resource key
         TenantSettings_WfmGroupNotInData in web.dll and both satellites. Each must read ZERO now.
  THE DISK GATE THE COORDINATOR ADDED after yesterday's failure: free space on C: must be at least
         TWO backup sets. The size of a set is MEASURED here (Shell plus RTM, which the updater
         copies whatever the mode), not carried from yesterday's 3578 MB. Below two sets this probe
         says STOP and the list goes to the coordinator - I do not clean anything myself.
  THE VERSIONS: exactly one moves. app.css 36, daytrend 14, asd 16, report 6, widget-resize 3,
         tokens 3, skin 3, app.js 2 must read what they read now; the scoped bundle moves 10 -> 11.
  WHAT IS NOT A PREDICATE: the sha of a rebuilt assembly, in either direction. Equality is asserted
         only against the package, by the install probe, which holds both halves at one time.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$PKG_NAME = '14102026.0928_Shell.zip'
$PKG_SHA  = 'BB226218B2289ED5FF34CA705F3B4D53E409C1E846B7B02356C8E0C1AB4A52B6'
$FLOOR_SHA_PREFIX = '8E2652AE'
$SHELL_DIR = 'C:\RTMView\Shell'
$OPS_ROOT  = 'C:\RTMView-Ops'

Start-Probe -Name 'predeploy-2324894' -Title 'PRE-DEPLOY READING on 234, flight 2324894 (Wfm counts agents again)'
Say 'READ-ONLY. Nothing is installed, restarted, re-configured or deleted by this probe.'
Rule
Assert-Machine

function Count-Needle($haystack, [string]$text, [string]$encoding) {
  if ($null -eq $haystack) { return -1 }
  $needle = $(if ($encoding -eq 'utf16') { [Text.Encoding]::Unicode.GetBytes($text) } else { [Text.Encoding]::UTF8.GetBytes($text) })
  $count = 0
  $from = 0
  while ($from -le ($haystack.Length - $needle.Length)) {
    $slice = New-Object byte[] ($haystack.Length - $from)
    [Array]::Copy($haystack, $from, $slice, 0, $slice.Length)
    $foundAt = Find-ByteRun $slice $needle
    if ($foundAt -lt 0) { break }
    $count++
    $from = $from + $foundAt + $needle.Length
  }
  return $count
}
function Read-File([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  return ,[IO.File]::ReadAllBytes($path)
}
function Size-Of([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return -1 }
  $measured = Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum
  if ($null -eq $measured.Sum) { return 0 }
  return [int64]$measured.Sum
}

Say '1  THE DISK GATE - measured, not carried from yesterday'
$shellSize  = Size-Of $SHELL_DIR
$engineSize = Size-Of 'C:\RTMView\RTM'
$oneSet = $shellSize + $engineSize
$driveC = Get-PSDrive -Name C
Say ('  Shell ' + [math]::Round($shellSize/1MB,1) + ' MB + RTM ' + [math]::Round($engineSize/1MB,1) + ' MB = one backup set ' + [math]::Round($oneSet/1MB,1) + ' MB')
Say  '  The updater copies BOTH whatever the mode (Update-RTMView.ps1:278 has no mode condition),'
Say  '  which is what ran C: out of space yesterday at step 2 of 5.'
Say ('  expected : free >= 2 sets = ' + [math]::Round(2*$oneSet/1MB,1) + ' MB')
Say ('  measured : free ' + [math]::Round($driveC.Free/1MB,1) + ' MB (' + [math]::Round($driveC.Free/1GB,2) + ' GB)')
$diskOk = ($driveC.Free -ge (2 * $oneSet))
Say ('  DISK GATE : ' + $(if ($diskOk) { 'PASS' } else { 'STOP - below two sets. The list goes to the coordinator; I clean nothing myself.' }))
Rule

Say '2  WHAT IS DEPLOYED NOW - recorded, never asserted'
$webPath = Join-Path $SHELL_DIR 'CcDashboard.Web.dll'
$appPath = Join-Path $SHELL_DIR 'CcDashboard.Application.dll'
Say ('  CcDashboard.Web.dll         : ' + (ShaOf $webPath))
Say ('  CcDashboard.Application.dll : ' + (ShaOf $appPath))
Say ('  CcDashboard.Contracts.dll   : ' + (ShaOf (Join-Path $SHELL_DIR 'CcDashboard.Contracts.dll')))
$negAssembly = ShaOf (Join-Path $SHELL_DIR 'CcDashboard.NoSuchAssembly.dll')
Say ('  NEGCTL an assembly that cannot be there : ' + $negAssembly + '   (must read ABSENT)')
Say  '  A rebuilt assembly sha changes by itself, so neither "equals" nor "differs" against these is'
Say  '  a lawful verdict later. They are here so the install report can say the file was replaced.'
Rule

Say '3  THE NEEDLES, BEFORE - this is what makes the acceptance provable'
$webBytes = Read-File $webPath
$appBytes = Read-File $appPath
$bundlePath = Join-Path $SHELL_DIR 'wwwroot\CcDashboard.Web.styles.css'
$bundleBytes = Read-File $bundlePath
$needlesOk = $true
if ($null -eq $webBytes) { Say '  web.dll ABSENT - the before half is NOT MEASURED' ; $needlesOk = $false }
else {
  $probe16 = Count-Needle $webBytes '[PROBE' 'utf16'
  $probe8  = Count-Needle $webBytes '[PROBE' 'utf8'
  Say ('  web.dll "[PROBE"  utf16 : ' + $probe16 + '   utf8 : ' + $probe8)
  Say  '  EXPECTED NOW: non-zero in at least one encoding. THIS IS THE DISAPPEARING NEEDLE: if it is'
  Say  '  already zero today, then the zero demanded after the install proves nothing at all, and the'
  Say  '  acceptance would pass on a package carrying nothing. A zero here is a STOP, not a detail.'
  if (($probe16 + $probe8) -lt 1) { $needlesOk = $false }
  $key16 = Count-Needle $webBytes 'TenantSettings_WfmGroupNotInData' 'utf16'
  $key8  = Count-Needle $webBytes 'TenantSettings_WfmGroupNotInData' 'utf8'
  Say ('  web.dll key "TenantSettings_WfmGroupNotInData" : utf16 ' + $key16 + ' , utf8 ' + $key8 + '   expected 0 now, 1 or more after')
  $negNeedle = Count-Needle $webBytes 'TenantSettings_ZzzNoSuchKey' 'utf16'
  Say ('  NEGCTL a key that cannot be there : ' + $negNeedle + '   must be 0, which proves the counter is not matching everything')
  if ($negNeedle -ne 0) { $needlesOk = $false }
}
if ($null -eq $appBytes) { Say '  Application.dll ABSENT - the before half is NOT MEASURED' ; $needlesOk = $false }
else {
  $query16 = Count-Needle $appBytes 'GetTenantStatusGroupsQuery' 'utf16'
  $query8  = Count-Needle $appBytes 'GetTenantStatusGroupsQuery' 'utf8'
  Say ('  Application.dll "GetTenantStatusGroupsQuery" : utf16 ' + $query16 + ' , utf8 ' + $query8 + '   expected 0 now, 1 or more after')
}
if ($null -eq $bundleBytes) { Say '  the scoped bundle is ABSENT on disk - NOT MEASURED' ; $needlesOk = $false }
else {
  $grid = Count-Needle $bundleBytes '1fr auto 38px' 'utf8'
  $negGrid = Count-Needle $bundleBytes '1fr auto 999px' 'utf8'
  Say ('  bundle "1fr auto 38px" : ' + $grid + '   expected 0 now, 1 or more after')
  Say ('  NEGCTL "1fr auto 999px" : ' + $negGrid + '   must be 0')
  Say ('  bundle on disk now : ' + $bundleBytes.Length + ' B  ' + (ShaOf $bundlePath))
  if ($negGrid -ne 0) { $needlesOk = $false }
}
foreach ($culture in @('he-IL','ru-RU')) {
  $satellitePath = Join-Path $SHELL_DIR ($culture + '\CcDashboard.Web.resources.dll')
  $satelliteBytes = Read-File $satellitePath
  if ($null -eq $satelliteBytes) { Say ('  ' + $culture + ' satellite ABSENT') ; $needlesOk = $false ; continue }
  $satKey = Count-Needle $satelliteBytes 'TenantSettings_WfmGroupNotInData' 'utf16'
  Say ('  ' + $culture.PadRight(6) + ' ' + ([string]$satelliteBytes.Length).PadLeft(7) + ' B   key now : ' + $satKey + '   expected 0 now, 1 or more after')
}
Say ('  THE BEFORE HALF IS USABLE : ' + $needlesOk)
Rule

Say '4  THE NINE ASSET VERSIONS THE SERVER SERVES RIGHT NOW'
Say  '  EXACTLY ONE may move: the scoped bundle, 10 -> 11. The other eight must read what they read'
Say  '  here, and a bump on any of them is the finding.'
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
  Say ('  fetch usable as evidence : ' + $fetchOk)
  $negCode = (& $curl -k -s -o NUL -w '%{http_code}' --max-time 20 ($base + '/zzz-no-such-endpoint')) 2>$null
  Say ('  NEGCTL /zzz-no-such-endpoint -> ' + $negCode + '   (must be neither 200 nor 000)')
}
$versionsHold = $fetchOk
if ($fetchOk) {
  $expectedNow = @{
    'app.css' = '36' ; 'CcDashboard.Web.styles.css' = '10' ; 'css/tokens.css' = '3'
    'css/widgets/wallboard-skin.css' = '3' ; 'js/app.js' = '2' ; 'js/widget-resize.js' = '3'
    'js/daytrendChart.js' = '14' ; 'js/agentStateDistributionChart.js' = '16' ; 'js/reportDistributionChart.js' = '6'
  }
  foreach ($assetMatch in [regex]::Matches($html, '(?:href|src)="([^":]+?)\?v=(\d+)"')) {
    $assetPath = $assetMatch.Groups[1].Value
    $assetVersion = $assetMatch.Groups[2].Value
    if (-not $expectedNow.ContainsKey($assetPath)) { Say ('    ' + $assetPath + ' v=' + $assetVersion + '   NOT IN THE EXPECTED LIST <- finding') ; $versionsHold = $false ; continue }
    $wanted = $expectedNow[$assetPath]
    $agrees = ($wanted -eq $assetVersion)
    $note = $(if ($assetPath -eq 'CcDashboard.Web.styles.css') { '   <- the ONE that will move, to 11' } else { '' })
    Say ('    ' + $assetPath.PadRight(36) + ' expected now v=' + $wanted.PadRight(3) + ' served v=' + $assetVersion.PadRight(3) + ' ' + $(if ($agrees) { 'agrees' } else { 'DISAGREES <- finding' }) + $note)
    if (-not $agrees) { $versionsHold = $false }
  }
  $negAsset = ([regex]::Matches($html, 'zzz-no-such-asset\.css\?v=\d+')).Count
  Say ('  NEGCTL an asset that cannot be served : ' + $negAsset + ' hits (expected 0)')
  if ($negAsset -ne 0) { $versionsHold = $false }
}
Say ('  all nine hold at the numbers they must hold now : ' + $versionsHold)
Rule

Say '5  SERVICES AND THEIR PIDS - the install report compares against THESE numbers'
foreach ($serviceName in @('RTMViewShell','RTMService','RTMTwilio_1')) {
  $serviceState = StateOf $serviceName
  Say ('  ' + $serviceName.PadRight(14) + ' state ' + ([string]$serviceState.State).PadRight(9) + ' pid ' + $serviceState.ProcessId)
}
$negService = StateOf 'RTMNoSuchService'
Say ('  NEGCTL a service that cannot exist : ' + $negService.State + '   (must read ABSENT)')
Rule

Say '6  ROLLBACK FLOOR AND THE PACKAGE OF THIS FLIGHT'
$floorFound = $false
$packageFound = $false
foreach ($packageFile in @(Get-ChildItem -LiteralPath (Join-Path $OPS_ROOT 'incoming') -Filter *.zip -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 8)) {
  $packageSha = ShaOf $packageFile.FullName
  $isFloor = $packageSha.StartsWith($FLOOR_SHA_PREFIX)
  $isNew   = ($packageSha -eq $PKG_SHA)
  if ($isFloor) { $floorFound = $true }
  if ($isNew) { $packageFound = $true }
  $label = $(if ($isFloor) { 'ROLLBACK FLOOR 2d75b01' } elseif ($isNew) { 'THE PACKAGE OF THIS FLIGHT' } else { '' })
  Say ('  ' + $packageFile.Name.PadRight(30) + ([string]$packageFile.Length).PadLeft(10) + ' B  ' + $packageSha.Substring(0,16) + '...  ' + $label)
}
Say ('  rollback floor present : ' + $floorFound + '   (a package whose sha begins ' + $FLOOR_SHA_PREFIX + ')')
Say ('  this flight package on the disk yet : ' + $packageFound + '   (False before the transfer is normal)')
Rule

Say 'VERDICT OF THE PRE-DEPLOY READING'
Say ('  trap fired during the run : ' + (Test-TrapFired) + '   (True means a section was SKIPPED, not passed)')
Say ('  section 1 disk gate       : ' + $diskOk)
Say ('  section 3 before-half usable (the disappearing needle is PRESENT today) : ' + $needlesOk)
Say ('  section 4 versions hold   : ' + $versionsHold)
Say ('  section 6 rollback floor  : ' + $floorFound)
$all = ($diskOk -and $needlesOk -and $versionsHold -and $floorFound -and (-not (Test-TrapFired)))
Say ('  PRE-DEPLOY : ' + $(if ($all) { 'THE BEFORE COLUMN IS TAKEN AND THE MACHINE IS AS THE BLESSING DESCRIBES' } else { 'STOP - see the False rows above' }))
Say  '  Nothing was installed. The install step is a separate box and re-reads the inbox first.'
Finish $all
