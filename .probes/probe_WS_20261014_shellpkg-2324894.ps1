<#
  PROBE  probe_WS_20261014_shellpkg-2324894.ps1
  ON THE CORE. Every generic helper comes from .probes/_core.ps1 and is self-tested by Start-Probe
  before this file measures anything. Written fresh for this flight, not patched from the last one.
  UNIT   v4 head 2324894, -Mode Shell -SkipDB. Blessing: coordinator 2026-10-14T06:18:42Z with the
         operator word quoted in it.
  DELTA, RE-TAKEN BY ME as the blessing requires, measured from the object store this morning:
         16 files - 13 under src/ (UpdateTenantSettingsCommand, the NEW GetTenantStatusGroupsQuery,
         TenantSettings, WfmInputQueryService, WfmRealtimeLoop, TenantsPage, App.razor,
         ScreenEditorPage, WfmWidget.razor and its .razor.css, three .resx) and 3 new test files.
         RTM/ 0, deploy/ 0, db/ 0, migrations 0, wwwroot 0, .js 0. Agrees with the letter.
  THIS FLIGHT HAS NEEDLES, unlike the last one, and they run in BOTH directions:
         the scoped bundle moves v10 -> v11 and must carry "1fr auto 38px", which it did not before;
         web.dll must LOSE the UTF-16 string "[PROBE" - a DISAPPEARING needle, so the count that
         matters is zero and the encoding is printed beside it, or a zero would only mean I looked
         in the wrong encoding;
         CcDashboard.Application.dll must GAIN GetTenantStatusGroupsQuery;
         the resource key TenantSettings_WfmGroupNotInData must appear in web.dll, where en-US
         lives, and in both satellites he-IL and ru-RU.
         EXACTLY ONE asset version moves. The other eight must read what they read today, and a
         bump on any of them is the finding.
  WHAT STAYS UNLAWFUL EVEN WITH NEEDLES PRESENT: the sha of a rebuilt assembly. Two builds of one
         tree gave web.dll at an identical size with different sha, so no row here says "differs
         from the one deployed" in either direction. Equality is asserted only against THIS package.
  SERVER 234 IS NOT TOUCHED. The v4 worktree is not touched. No push.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$WORK      = 'D:\Claude\Projects\RTM View Shell'
$V4WT      = 'D:\Claude\Projects\RTM-design'
$BUILDROOT = 'D:\Claude\Build'
$BLESSED_HEAD = '2324894'
$DEPLOYED     = '2d75b01'

Start-Probe -Name 'shellpkg-2324894' -Title 'SHELL PACKAGE  v4 2324894  (Wfm counts agents again)' -OutputDir (Join-Path $WORK '.measurements')
Say ('PS version : ' + $PSVersionTable.PSVersion.ToString())
Say  'SERVER 234 IS NOT TOUCHED. The v4 worktree is not touched. No push.'
Rule

Say 'G0  THIS RUNS ON THE WORKSTATION, NOT ON 234 - the machine gate in its negative direction'
Say ('  host : ' + $env:COMPUTERNAME + '   (must NOT be RTM)')
if ($env:COMPUTERNAME -eq 'RTM') { Say '  THIS IS SERVER 234. The build belongs on the workstation. Nothing done.' ; Finish $false }
if (-not (Test-Path -LiteralPath $WORK)) { Say ('  not the workstation: ' + $WORK + ' does not exist here') ; Finish $false }
Say  '  G0 PASS'
Rule

Say 'G1  the head being built must be the BLESSED revision, not whatever the head is now'
$PIN_COMMIT = (Invoke-Native { & git -C "$V4WT" rev-parse v4 }).Trim()
$PIN_SHORT  = $PIN_COMMIT.Substring(0,7)
Say ('  expected : head of v4 == ' + $BLESSED_HEAD + '   (operator word 2026-10-14T06:18:42Z)')
Say ('  measured : ' + $PIN_COMMIT)
$headIsBlessed = ($PIN_SHORT -eq $BLESSED_HEAD)
Say ('  head == blessed : ' + $headIsBlessed)
if (-not $headIsBlessed) { Say '  STOP. The head moved past the blessed revision. Nothing is cloned, nothing is built.' ; Finish $false }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$CLONE = Join-Path $BUILDROOT ('rtm_v4s_{0}_{1}' -f $PIN_SHORT, $stamp)
Say ('  clone will be : ' + $CLONE)
Rule

Say 'G2  ROLLBACK FOR THIS RUN, printed BEFORE the first write'
Say ('  Remove-Item -Recurse -Force ' + [char]39 + $CLONE + [char]39)
Say  '  Nothing outside that directory is written. No service, no server, no worktree, no repo state.'
Rule

Say 'G3  clones left by PREVIOUS runs of this same step'
if (Test-Path -LiteralPath $BUILDROOT) {
  foreach ($priorDir in @(Get-ChildItem -LiteralPath $BUILDROOT -Directory -Filter 'rtm_v4s_*' -ErrorAction SilentlyContinue)) {
    $markFile = Join-Path $priorDir.FullName '.origin'
    if (-not (Test-Path -LiteralPath $markFile)) { Say ('  ' + $priorDir.Name + '  -> NO MARK: origin unknown. NOT TOUCHED.') ; continue }
    if ((Get-Content -LiteralPath $markFile -Raw) -like '*shellpkg-2324894*') {
      $sizeGb = [math]::Round((Get-ChildItem -LiteralPath $priorDir.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB, 2)
      Say ('  ' + $priorDir.Name + '  -> MY OWN previous run, ' + $sizeGb + ' GB. DELETING.')
      Remove-Item -LiteralPath $priorDir.FullName -Recurse -Force
      Say ('      deleted; exists now: ' + (Test-Path -LiteralPath $priorDir.FullName))
    } else { Say ('  ' + $priorDir.Name + '  -> ANOTHER probe artifact. NOT TOUCHED.') }
  }
}
Rule

Say 'G4  tools'
if (Test-Path -LiteralPath $CLONE) { Say ('  clone dir already exists: ' + $CLONE) ; Finish $false }
if (-not (Test-Path -LiteralPath $BUILDROOT)) { New-Item -ItemType Directory -Path $BUILDROOT | Out-Null }
if (-not (Get-Command git -ErrorAction SilentlyContinue))    { Say '  git not in PATH' ; Finish $false }
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { Say '  dotnet SDK not in PATH' ; Finish $false }
Say ('  git    : ' + (Invoke-Native { & git --version }))
Say ('  dotnet : ' + (Invoke-Native { & dotnet --version }))
$driveLetter = (Split-Path -Qualifier $BUILDROOT).TrimEnd(':')
Say ('  free on ' + $driveLetter + ' : ' + [math]::Round((Get-PSDrive -Name $driveLetter).Free/1GB,1) + ' GB')
Rule

Say 'PIN 1  clean clone at the pinned head'
Invoke-Native { & git clone --no-hardlinks -- "$V4WT" "$CLONE" 2>&1 } | ForEach-Object { Say ('  ' + $_) }
if ($LASTEXITCODE -ne 0) { Say '  git clone failed' ; Finish $false }
Invoke-Native { & git -C "$CLONE" checkout --detach $PIN_COMMIT 2>&1 } | ForEach-Object { Say ('  ' + $_) }
if ($LASTEXITCODE -ne 0) { Say '  checkout of the pinned commit failed' ; Finish $false }
$cloneHead = (Invoke-Native { & git -C "$CLONE" rev-parse HEAD }).Trim()
$pinClone = ($cloneHead -eq $PIN_COMMIT)
Say ('  expected : clone HEAD == ' + $PIN_COMMIT)
Say ('  measured : ' + $cloneHead)
Say ('  PIN 1 ' + $(if ($pinClone) { 'GREEN' } else { 'RED' }))
Rule

Say 'PIN 2  cleanliness, measured before this probe writes anything into the clone'
$porcelain = @(Invoke-Native { & git -C "$CLONE" status --porcelain })
Say ('  expected : 0 porcelain lines    measured : ' + $porcelain.Count)
$pinClean = ($porcelain.Count -eq 0)
Say ('  PIN 2 ' + $(if ($pinClean) { 'GREEN' } else { 'RED    tree not clean' }))
$originText = @(
  ('probe   : probe_WS_20261014_shellpkg-2324894.ps1'),
  ('sha256  : ' + (ShaOf $PSCommandPath)),
  ('core    : ' + (ShaOf (Join-Path (Split-Path -Parent $PSCommandPath) '_core.ps1'))),
  ('stamp   : ' + $stamp),
  ('machine : ' + $env:COMPUTERNAME + ' / ' + $env:USERNAME),
  ('commit  : ' + $PIN_COMMIT),
  ('unit    : v4 Wfm serving groups, Mode Shell SkipDB, by devops-0919')
) -join "`r`n"
[IO.File]::WriteAllText((Join-Path $CLONE '.origin'), $originText + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
Say  '  .origin written inside the clone'
Rule

Say 'PIN 2b  the deployed revision and the one being built must be DIFFERENT tokens'
Say ('  deployed on 234 : ' + $DEPLOYED + '    being built : ' + $PIN_SHORT)
if ($DEPLOYED -eq $PIN_SHORT) { Say '  RED. The two tokens are equal - every delta below would come out empty. Nothing is built.' ; Finish $false }
Say  '  PIN 2b GREEN'
Rule

Say 'PIN 3  content witnesses - every product file of the delta, blob by blob, clone against worktree'
$witnesses = @(Invoke-Native { & git -C "$V4WT" diff --name-only ($DEPLOYED + '..' + $PIN_COMMIT) -- src/ RTM/ } | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
Say ('  expected : 13 product files under src/, 0 under RTM/')
Say ('  measured : ' + $witnesses.Count)
if ($witnesses.Count -eq 0) { Say '  RED. The delta lists no product files - refusing to build a package that changes nothing.' ; Finish $false }
$mismatched = 0
foreach ($witness in $witnesses) {
  $blobClone = (Invoke-Native { & git -C "$CLONE" rev-parse ('HEAD:' + $witness) }).Trim()
  $blobWork  = (Invoke-Native { & git -C "$V4WT"  rev-parse ($PIN_COMMIT + ':' + $witness) }).Trim()
  if (-not (($blobClone -eq $blobWork) -and ($blobClone.Length -eq 40))) { $mismatched++ ; Say ('  MISMATCH ' + $witness) }
}
Say ('  blobs compared : ' + $witnesses.Count + '   mismatched : ' + $mismatched)
$pinWitness = ($mismatched -eq 0)
Say ('  PIN 3 ' + $(if ($pinWitness) { 'GREEN' } else { 'RED    a blob differs - the builder would read a tree I never checked' }))
Rule

Say 'PIN 3b  WHAT THE DELTA CONTAINS - this is what decides -Mode Shell -SkipDB'
$deltaAll = @(Invoke-Native { & git -C "$V4WT" diff --name-only ($DEPLOYED + '..' + $PIN_COMMIT) } | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
$migrationHits = @($deltaAll | Where-Object { $_ -like 'db/migrations/*' }).Count
$engineHits    = @($deltaAll | Where-Object { $_ -like 'RTM/*' }).Count
$srcHits       = @($deltaAll | Where-Object { $_ -like 'src/*' }).Count
$testHits      = @($deltaAll | Where-Object { $_ -like 'tests/*' }).Count
$resxHits      = @($deltaAll | Where-Object { $_ -like '*.resx' }).Count
$staticHits    = @($deltaAll | Where-Object { $_ -like '*wwwroot/*' }).Count
$scriptHits    = @($deltaAll | Where-Object { $_ -like '*.js' }).Count
$deployHits    = @($deltaAll | Where-Object { $_ -like 'deploy/*' }).Count
$scopedCssHits = @($deltaAll | Where-Object { $_ -like '*.razor.css' }).Count
Say ('  total files    : ' + $deltaAll.Count + '   (expected 16)')
Say ('  src/           : ' + $srcHits       + '   (expected 13)')
Say ('  tests/         : ' + $testHits      + '   (expected 3 - they do not travel in the package, named so the total adds up)')
Say ('  db/migrations/ : ' + $migrationHits + '   (expected 0 - non-zero means the DB layer may NOT be skipped)')
Say ('  RTM/ engine    : ' + $engineHits    + '   (expected 0 - WHY the mode is Shell)')
Say ('  deploy/        : ' + $deployHits    + '   (expected 0)')
Say ('  wwwroot/       : ' + $staticHits    + '   (expected 0 - WHY only the generated bundle may move)')
Say ('  *.js           : ' + $scriptHits    + '   (expected 0 - the three chart scripts must come out byte-identical)')
Say ('  .resx          : ' + $resxHits      + '   (expected 3 - WHY the satellites change and a new key must appear)')
Say ('  .razor.css     : ' + $scopedCssHits + '   (expected 1 - WHY the scoped bundle moves at all)')
$modeLawful = (($migrationHits -eq 0) -and ($engineHits -eq 0) -and ($deployHits -eq 0) -and ($srcHits -eq 13) -and ($resxHits -eq 3) -and ($scopedCssHits -eq 1))
Say ('  PIN 3b ' + $(if ($modeLawful) { 'GREEN  the mode is lawful and the delta is the blessed one' } else { 'RED    STOP - the delta does not match the blessing' }))
Rule

Say 'PIN 3c  EXACTLY ONE ASSET VERSION MOVES, and it is the scoped bundle'
$versionLines = @(Invoke-Native { & git -C "$V4WT" diff ($DEPLOYED + '..' + $PIN_COMMIT) } | Where-Object { $_ -match '^[+-][^+-]' -and $_ -match '\?v=' })
Say ('  lines carrying "?v=" in the delta : ' + $versionLines.Count + '   (expected 2 - one removed, one added)')
foreach ($versionLine in $versionLines) { Say ('    ' + $versionLine.Trim()) }
$bundleUp   = @($versionLines | Where-Object { $_ -match '^\+' -and $_ -match 'CcDashboard\.Web\.styles\.css\?v=11' }).Count
$bundleDown = @($versionLines | Where-Object { $_ -match '^-'  -and $_ -match 'CcDashboard\.Web\.styles\.css\?v=10' }).Count
$otherMoved = @($versionLines | Where-Object { $_ -notmatch 'CcDashboard\.Web\.styles\.css' }).Count
Say ('  bundle 10 removed : ' + $bundleDown + '   bundle 11 added : ' + $bundleUp + '   any OTHER asset moved : ' + $otherMoved + ' (must be 0)')
$pinVersions = (($bundleUp -eq 1) -and ($bundleDown -eq 1) -and ($otherMoved -eq 0))
Say ('  PIN 3c ' + $(if ($pinVersions) { 'GREEN  exactly one version moved, and it is the bundle' } else { 'RED' }))
Rule

if (-not ($pinClone -and $pinClean -and $pinWitness -and $modeLawful -and $pinVersions)) {
  Say 'STOP BEFORE BUILD: a provenance pin is RED. Nothing was built, nothing was packaged.'
  Finish $false
}

$buildStartedAt = Get-Date
Say ('PIN 4  build in the clean clone. Started ' + $buildStartedAt.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + 'Z  (local ' + $buildStartedAt.ToString('HH:mm:ss') + ')')
$builder = Join-Path $CLONE 'tools\Build-ProdRelease.ps1'
if (-not (Test-Path -LiteralPath $builder)) { Say ('  builder not found: ' + $builder) ; Finish $false }
Say ('  builder sha256 : ' + (ShaOf $builder))
$garnetDir = Join-Path $WORK 'tools\cache\garnet-1.1.10-win-x64-net8'
$nssmDir   = Join-Path $WORK 'tools\cache\nssm'
$buildExit = 1
Push-Location $CLONE
try {
  Invoke-Native { & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $builder -Mode Shell -SkipDB -GarnetDir $garnetDir -NssmDir $nssmDir 2>&1 } | ForEach-Object { Say ('  | ' + $_) }
  $buildExit = $LASTEXITCODE
} finally { Pop-Location }
Say ('  builder exit code : ' + $buildExit + '   (expected 0)')
Rule

Say 'PIN 5  THE PACKAGE - freshness first, because a stale zip would pass every other row'
$instDir = Join-Path $CLONE 'Installations'
if (-not (Test-Path -LiteralPath $instDir)) { Say '  no Installations directory in the clone' ; Finish $false }
$zip = Get-ChildItem -LiteralPath $instDir -Filter *.zip | Where-Object { $_.LastWriteTime -ge $buildStartedAt } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $zip) { Say '  RED. No .zip produced by THIS run - refusing to hand out an older package.' ; Finish $false }
$zipHash = ShaOf $zip.FullName
Say ('  freshness  : written ' + $zip.LastWriteTime.ToString('HH:mm:ss') + ' , build started ' + $buildStartedAt.ToString('HH:mm:ss'))
Say ('  zip name   : ' + $zip.Name)
Say ('  zip bytes  : ' + $zip.Length + '   (' + [math]::Round($zip.Length/1MB,2) + ' MB)')
Say ('  zip sha256 : ' + $zipHash)
Rule

Say 'PIN 6  INSIDE THE PACKAGE'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip.FullName)
$pkgOk = $true
try {
  $entries = $archive.Entries
  $entryNames = @($entries | ForEach-Object { $_.FullName })
  Say ('  entries : ' + $entryNames.Count)
  $rtmEntries   = @($entryNames | Where-Object { ($_ -replace '\\','/') -like 'RTM/*' }).Count
  $shellEntries = @($entryNames | Where-Object { ($_ -replace '\\','/') -like 'Shell/*' }).Count
  Say ('  RTM entries : ' + $rtmEntries + ' (expected 0)    Shell entries : ' + $shellEntries + ' (must be non-zero - POSCTL for the row beside it)')
  if (($rtmEntries -ne 0) -or ($shellEntries -le 0)) { $pkgOk = $false }
  foreach ($need in @('Update-RTMView.ps1','Install-RTMView.ps1')) {
    $hits = @($entryNames | Where-Object { $_ -like ('*' + $need) }).Count
    Say ('  contains ' + $need.PadRight(22) + ' : ' + $hits + '   (expected 1 or more)')
    if ($hits -lt 1) { $pkgOk = $false }
  }

  function Read-Entry([string]$suffix) {
    $entry = $entries | Where-Object { ($_.FullName -replace '\\','/') -like ('*' + $suffix) } | Select-Object -First 1
    if ($null -eq $entry) { return $null }
    $buffer = New-Object byte[] $entry.Length
    $reader = $entry.Open()
    try {
      $offset = 0
      while ($offset -lt $buffer.Length) {
        $read = $reader.Read($buffer, $offset, $buffer.Length - $offset)
        if ($read -le 0) { break }
        $offset += $read
      }
    } finally { $reader.Dispose() }
    return ,$buffer
  }
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

  Say ''
  Say '  6a  THE ASSET LIST, PARSED OUT OF App.razor - never typed here'
  $appRazorPath = Join-Path $CLONE 'src\CcDashboard.Web\Components\App.razor'
  $assetRows = @()
  if (Test-Path -LiteralPath $appRazorPath) {
    $appRazorText = [IO.File]::ReadAllText($appRazorPath)
    foreach ($assetMatch in [regex]::Matches($appRazorText, '(?:href|src)="([^":]+?)\?v=(\d+)"')) {
      $assetRows += ,@($assetMatch.Groups[1].Value, $assetMatch.Groups[2].Value)
    }
  } else { Say ('      App.razor not found at ' + $appRazorPath) ; $pkgOk = $false }
  Say ('      assets declared : ' + $assetRows.Count + '   (expected 9)')
  if ($assetRows.Count -ne 9) { $pkgOk = $false }
  $expectedVersions = @{
    'app.css' = '36' ; 'CcDashboard.Web.styles.css' = '11' ; 'js/daytrendChart.js' = '14'
    'js/agentStateDistributionChart.js' = '16' ; 'js/reportDistributionChart.js' = '6'
    'js/widget-resize.js' = '3' ; 'css/tokens.css' = '3' ; 'css/widgets/wallboard-skin.css' = '3'
    'js/app.js' = '2'
  }
  $versionsAgree = $true
  foreach ($assetRow in $assetRows) {
    $assetPath = $assetRow[0]
    $assetVersion = $assetRow[1]
    if (-not $expectedVersions.ContainsKey($assetPath)) { Say ('      ' + $assetPath + ' v=' + $assetVersion + '   NOT IN THE EXPECTED LIST <- finding') ; $versionsAgree = $false ; continue }
    $wanted = $expectedVersions[$assetPath]
    $agrees = ($wanted -eq $assetVersion)
    $note = $(if ($assetPath -eq 'CcDashboard.Web.styles.css') { '  <- the ONE that must move, 10 -> 11' } else { '' })
    Say ('      ' + $assetPath.PadRight(36) + ' expected v=' + $wanted.PadRight(3) + ' measured v=' + $assetVersion.PadRight(3) + '  ' + $(if ($agrees) { 'agrees' } else { 'DISAGREES <- finding' }) + $note)
    if (-not $agrees) { $versionsAgree = $false }
  }
  if (-not $versionsAgree) { $pkgOk = $false }

  Say ''
  Say '  6b  THE BUNDLE AND ITS NEW NEEDLE'
  $bundleBytes = Read-Entry 'wwwroot/CcDashboard.Web.styles.css'
  if ($null -eq $bundleBytes) { Say '      BUNDLE ABSENT FROM PACKAGE <- finding' ; $pkgOk = $false }
  else {
    $bundleSha = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($bundleBytes)).Replace('-','')
    $gridNeedle = Count-Needle $bundleBytes '1fr auto 38px' 'utf8'
    $negNeedle  = Count-Needle $bundleBytes '1fr auto 999px' 'utf8'
    Say ('      CcDashboard.Web.styles.css  ' + $bundleBytes.Length + ' B  ' + $bundleSha)
    Say ('      needle "1fr auto 38px"  : ' + $gridNeedle + '   expected 1 or more (it was 0 before this flight)')
    Say ('      NEGCTL "1fr auto 999px" : ' + $negNeedle + '   must be 0, which proves the counter is not matching everything')
    if (($gridNeedle -lt 1) -or ($negNeedle -ne 0)) { $pkgOk = $false }
  }

  Say ''
  Say '  6c  THE ASSEMBLIES AND THEIR NEEDLES - one appearing, one DISAPPEARING'
  $webBytes = Read-Entry 'CcDashboard.Web.dll'
  $appBytes = Read-Entry 'CcDashboard.Application.dll'
  foreach ($pair in @(@('CcDashboard.Web.dll', $webBytes), @('CcDashboard.Application.dll', $appBytes))) {
    if ($null -eq $pair[1]) { Say ('      ' + $pair[0] + ' ABSENT FROM PACKAGE <- finding') ; $pkgOk = $false ; continue }
    $sha = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($pair[1])).Replace('-','')
    Say ('      ' + $pair[0].PadRight(30) + ([string]$pair[1].Length).PadLeft(9) + ' B  ' + $sha)
  }
  if ($null -ne $webBytes) {
    $probeUtf16 = Count-Needle $webBytes '[PROBE' 'utf16'
    $probeUtf8  = Count-Needle $webBytes '[PROBE' 'utf8'
    Say ('      web.dll needle "[PROBE" utf16 : ' + $probeUtf16 + '   expected 0 - it was PRESENT before this flight and must be gone')
    Say ('      web.dll needle "[PROBE" utf8  : ' + $probeUtf8 + '   printed beside it so a zero cannot mean "I looked in the wrong encoding"')
    $keyWeb16 = Count-Needle $webBytes 'TenantSettings_WfmGroupNotInData' 'utf16'
    $keyWeb8  = Count-Needle $webBytes 'TenantSettings_WfmGroupNotInData' 'utf8'
    Say ('      web.dll key "TenantSettings_WfmGroupNotInData" : utf16 ' + $keyWeb16 + ' , utf8 ' + $keyWeb8 + '   expected 1 or more in ONE of the two')
    $negKey = Count-Needle $webBytes 'TenantSettings_ZzzNoSuchKey' 'utf16'
    Say ('      NEGCTL a key that cannot be there : ' + $negKey + '   must be 0')
    if (($probeUtf16 -ne 0) -or (($keyWeb16 + $keyWeb8) -lt 1) -or ($negKey -ne 0)) { $pkgOk = $false }
  }
  if ($null -ne $appBytes) {
    $query16 = Count-Needle $appBytes 'GetTenantStatusGroupsQuery' 'utf16'
    $query8  = Count-Needle $appBytes 'GetTenantStatusGroupsQuery' 'utf8'
    Say ('      Application.dll needle "GetTenantStatusGroupsQuery" : utf16 ' + $query16 + ' , utf8 ' + $query8 + '   expected 1 or more in ONE of the two (it was 0 before)')
    $negQuery = Count-Needle $appBytes 'GetTenantZzzNoSuchQuery' 'utf16'
    Say ('      NEGCTL a query that cannot be there : ' + $negQuery + '   must be 0')
    if ((($query16 + $query8) -lt 1) -or ($negQuery -ne 0)) { $pkgOk = $false }
  }

  Say ''
  Say '  6d  THE SATELLITES - three .resx are in this delta, so the new key must be in he-IL and ru-RU'
  Say '      Size is recorded and is a verdict in NEITHER direction: a 512-byte alignment step can'
  Say '      swallow a new string entirely. The KEY is the measurement.'
  foreach ($culture in @('he-IL','ru-RU','en-US')) {
    $bytes = Read-Entry ($culture + '/CcDashboard.Web.resources.dll')
    if ($null -eq $bytes) {
      if ($culture -eq 'en-US') { Say ('      ' + $culture.PadRight(8) + ' no satellite - en-US lives inside web.dll, measured in 6c') ; continue }
      Say ('      ' + $culture.PadRight(8) + ' ABSENT FROM PACKAGE <- finding') ; $pkgOk = $false ; continue
    }
    $key16 = Count-Needle $bytes 'TenantSettings_WfmGroupNotInData' 'utf16'
    $key8  = Count-Needle $bytes 'TenantSettings_WfmGroupNotInData' 'utf8'
    $neg   = Count-Needle $bytes 'TenantSettings_ZzzNoSuchKey' 'utf16'
    Say ('      ' + $culture.PadRight(8) + ([string]$bytes.Length).PadLeft(7) + ' B   key utf16 ' + $key16 + ' / utf8 ' + $key8 + '   NEGCTL ' + $neg + ' (must be 0)')
    if ($culture -ne 'en-US') {
      if ((($key16 + $key8) -lt 1) -or ($neg -ne 0)) { $pkgOk = $false }
    }
  }
} finally { $archive.Dispose() }
Rule

Say 'PIN 7  the package is copied to the project Installations directory, for the hand-over to 234'
$projInst = Join-Path $WORK 'Installations'
if (-not (Test-Path -LiteralPath $projInst)) { New-Item -ItemType Directory -Path $projInst | Out-Null }
$destZip = Join-Path $projInst $zip.Name
Copy-Item -LiteralPath $zip.FullName -Destination $destZip -Force
$destHash = ShaOf $destZip
Say ('  copied to : ' + $destZip)
Say ('  expected  : ' + $zipHash)
Say ('  measured  : ' + $destHash)
$copyOk = ($destHash -eq $zipHash)
Say ('  PIN 7 ' + $(if ($copyOk) { 'GREEN  the copy is byte-identical' } else { 'RED' }))
Rule

Say 'VERDICT OF THE PACKAGE BUILD'
Say ('  trap fired during the run        : ' + (Test-TrapFired) + '   (True means a section was SKIPPED, not passed)')
Say ('  PIN 1/2/2b/3 provenance          : ' + ($pinClone -and $pinClean -and $pinWitness))
Say ('  PIN 3b delta and mode            : ' + $modeLawful)
Say ('  PIN 3c exactly one version moved : ' + $pinVersions)
Say ('  PIN 4 builder exit 0             : ' + ($buildExit -eq 0))
Say ('  PIN 6 package, needles both ways : ' + $pkgOk)
Say ('  PIN 7 hand-over copy identical   : ' + $copyOk)
$all = ($pinClone -and $pinClean -and $pinWitness -and $modeLawful -and $pinVersions -and ($buildExit -eq 0) -and $pkgOk -and $copyOk -and (-not (Test-TrapFired)))
Say ('  PACKAGE : ' + $(if ($all) { 'READY TO HAND OVER' } else { 'NOT READY - see the RED rows above' }))
Say  '  Nothing has been installed. 234 is untouched. The install step is a separate box.'
Finish $all
