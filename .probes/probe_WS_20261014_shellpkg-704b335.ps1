<#
  PROBE  probe_WS_20261014_shellpkg-704b335.ps1
  ON THE CORE. Built on the shape of this morning 2324894 package probe - the provenance pins and
  the build are the same mechanism - with every expectation and every needle REDERIVED from this
  flight own delta. A pin carried over from the last flight would be a number without a path.
  UNIT   v4 head 704b335 over the installed 2324894, -Mode Shell -SkipDB. Blessing: coordinator
         2026-10-14T11:01:23Z, operator word quoted in it.
  DELTA, RE-TAKEN BY ME from the object store, not from the letter: 23 files - 18 under src/,
         5 under tests/. db/migrations 0, checked by me with `git log 2324894..704b335 --
         '*Migrations*'` coming out empty while 4 commits and 23 files answer in the same range,
         which is that check positive control. RTM/ 0, deploy/ 0.
         ADDED: GetWfmServingGroupCandidatesQuery, WfmEngineAgentCountProvider, WfmLogGate.
         DELETED: GetTenantStatusGroupsQuery and two of its test files.
  WHAT IS DIFFERENT FROM THE LAST FLIGHT, and why a carried expectation would have gone red:
         last time wwwroot/ was 0 and the scoped bundle moved 10 -> 11. THIS time wwwroot/ is 1
         (js/widget-resize.js), the bundle does NOT move and stays at v=11, and the one version
         that moves is js/widget-resize.js?v=3 -> ?v=4.
  THE NEEDLES, BOTH DIRECTIONS:
         APPEARING - Application.dll gains GetWfmServingGroupCandidatesQuery; Infrastructure.dll
                     gains WfmEngineAgentCountProvider and WfmLogGate; web.dll and both satellites
                     gain the resource key Wfm_NUnknown.
         DISAPPEARING - Application.dll must LOSE GetTenantStatusGroupsQuery. Its before-count is
                     not a guess: measured on 234 at 09:46 today as utf16 1 / utf8 3. A zero here
                     means something only because that count was non-zero.
         Both encodings are printed on every needle, so a zero can never mean "I looked in the
         wrong encoding". js/widget-resize.js is a plain static file, so its sha IS lawful and it
         is compared with the blob of the pinned revision - exact equality, not a size.
  WHAT STAYS UNLAWFUL: the sha of a rebuilt assembly, in either direction. Equality is asserted
         only against THIS package, never against what the machine runs now.
  ALSO WORTH THE COORDINATOR EYE: the test WfmN0WarningTests is DELETED in this delta. The N=0
         warning that the last flight treated as its negative half is not part of this build, so
         the acceptance must not wait for it - it must wait for the no-data path instead.
  SERVER 234 IS NOT TOUCHED. The v4 worktree is not touched. No push.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$WORK      = 'D:\Claude\Projects\RTM View Shell'
$V4WT      = 'D:\Claude\Projects\RTM-design'
$BUILDROOT = 'D:\Claude\Build'
$BLESSED_HEAD = '704b335'
$DEPLOYED     = '2324894'

Start-Probe -Name 'shellpkg-704b335' -Title 'SHELL PACKAGE  v4 704b335  (N from the engine by skill)' -OutputDir (Join-Path $WORK '.measurements')
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
Say ('  expected : head of v4 == ' + $BLESSED_HEAD + '   (operator word 2026-10-14T11:01:23Z)')
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
    if ((Get-Content -LiteralPath $markFile -Raw) -like '*shellpkg-704b335*') {
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
  ('probe   : probe_WS_20261014_shellpkg-704b335.ps1'),
  ('sha256  : ' + (ShaOf $PSCommandPath)),
  ('core    : ' + (ShaOf (Join-Path (Split-Path -Parent $PSCommandPath) '_core.ps1'))),
  ('stamp   : ' + $stamp),
  ('machine : ' + $env:COMPUTERNAME + ' / ' + $env:USERNAME),
  ('commit  : ' + $PIN_COMMIT),
  ('unit    : v4 N from engine by skill, Mode Shell SkipDB, by devops-0919')
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
Say ('  expected : 18 product files under src/, 0 under RTM/')
Say ('  measured : ' + $witnesses.Count)
if ($witnesses.Count -eq 0) { Say '  RED. The delta lists no product files - refusing to build a package that changes nothing.' ; Finish $false }
# A DELTA WITH DELETIONS NEEDS TWO LAWFUL SHAPES, not one. The reference probe this file is built
# on came from a delta with no deletions, and its loop demanded a 40-character blob on both sides.
# This flight DELETES GetTenantStatusGroupsQuery.cs, so there is no blob for it at the pin and that
# loop called a healthy tree RED at 14:07 today - a false red made by the instrument.
# A path in the delta is witnessed either as the SAME blob on both sides, or as ABSENT on both
# sides at the pin. The two kinds are counted separately, and the deletion count is its own control.
$mismatched = 0
$agreedPresent = 0
$agreedAbsent = 0
foreach ($witness in $witnesses) {
  $blobClone = (Invoke-Native { & git -C "$CLONE" rev-parse ('HEAD:' + $witness) 2>$null }).Trim()
  $blobWork  = (Invoke-Native { & git -C "$V4WT"  rev-parse ($PIN_COMMIT + ':' + $witness) 2>$null }).Trim()
  $cloneHasIt = ($blobClone.Length -eq 40)
  $workHasIt  = ($blobWork.Length -eq 40)
  if ($cloneHasIt -and $workHasIt) {
    if ($blobClone -eq $blobWork) { $agreedPresent++ } else { $mismatched++ ; Say ('  MISMATCH, two different blobs : ' + $witness) }
  }
  elseif ((-not $cloneHasIt) -and (-not $workHasIt)) { $agreedAbsent++ ; Say ('  agreed ABSENT at the pin (a deletion in this delta) : ' + $witness) }
  else { $mismatched++ ; Say ('  MISMATCH, present on one side only : ' + $witness + '   clone ' + $cloneHasIt + ' / worktree ' + $workHasIt) }
}
Say ('  paths witnessed : ' + $witnesses.Count + '   same blob : ' + $agreedPresent + '   absent on both : ' + $agreedAbsent + '   MISMATCHED : ' + $mismatched)
Say ('  expected : 17 same blob, 1 absent on both (GetTenantStatusGroupsQuery.cs), 0 mismatched')
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
Say ('  total files    : ' + $deltaAll.Count + '   (expected 23)')
Say ('  src/           : ' + $srcHits       + '   (expected 18)')
Say ('  tests/         : ' + $testHits      + '   (expected 5 - they do not travel in the package, named so the total adds up)')
Say ('  db/migrations/ : ' + $migrationHits + '   (expected 0 - non-zero means the DB layer may NOT be skipped)')
Say ('  RTM/ engine    : ' + $engineHits    + '   (expected 0 - WHY the mode is Shell)')
Say ('  deploy/        : ' + $deployHits    + '   (expected 0)')
Say ('  wwwroot/       : ' + $staticHits    + '   (expected 1 - js/widget-resize.js, and THAT is why a version moves)')
Say ('  *.js           : ' + $scriptHits    + '   (expected 1 - widget-resize.js; the three chart scripts stay byte-identical)')
Say ('  .resx          : ' + $resxHits      + '   (expected 3 - WHY the satellites change and a new key must appear)')
Say ('  .razor.css     : ' + $scopedCssHits + '   (expected 0 - WHY the scoped bundle must NOT move this time)')
$modeLawful = (($migrationHits -eq 0) -and ($engineHits -eq 0) -and ($deployHits -eq 0) -and ($srcHits -eq 18) -and ($resxHits -eq 3) -and ($scopedCssHits -eq 0) -and ($staticHits -eq 1))
Say ('  PIN 3b ' + $(if ($modeLawful) { 'GREEN  the mode is lawful and the delta is the blessed one' } else { 'RED    STOP - the delta does not match the blessing' }))
Rule

Say 'PIN 3c  EXACTLY ONE ASSET VERSION MOVES, and this time it is js/widget-resize.js'
$versionLines = @(Invoke-Native { & git -C "$V4WT" diff ($DEPLOYED + '..' + $PIN_COMMIT) } | Where-Object { $_ -match '^[+-][^+-]' -and $_ -match '\?v=' })
Say ('  lines carrying "?v=" in the delta : ' + $versionLines.Count + '   (expected 2 - one removed, one added)')
foreach ($versionLine in $versionLines) { Say ('    ' + $versionLine.Trim()) }
$resizeUp   = @($versionLines | Where-Object { $_ -match '^\+' -and $_ -match 'widget-resize\.js\?v=4' }).Count
$resizeDown = @($versionLines | Where-Object { $_ -match '^-'  -and $_ -match 'widget-resize\.js\?v=3' }).Count
$otherMoved = @($versionLines | Where-Object { $_ -notmatch 'widget-resize\.js' }).Count
Say ('  widget-resize 3 removed : ' + $resizeDown + '   4 added : ' + $resizeUp + '   any OTHER asset moved : ' + $otherMoved + ' (must be 0 - the bundle stays at v=11)')
$pinVersions = (($resizeUp -eq 1) -and ($resizeDown -eq 1) -and ($otherMoved -eq 0))
Say ('  PIN 3c ' + $(if ($pinVersions) { 'GREEN  exactly one version moved, and it is widget-resize.js' } else { 'RED' }))
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
    'js/widget-resize.js' = '4' ; 'css/tokens.css' = '3' ; 'css/widgets/wallboard-skin.css' = '3'
    'js/app.js' = '2'
  }
  $versionsAgree = $true
  foreach ($assetRow in $assetRows) {
    $assetPath = $assetRow[0]
    $assetVersion = $assetRow[1]
    if (-not $expectedVersions.ContainsKey($assetPath)) { Say ('      ' + $assetPath + ' v=' + $assetVersion + '   NOT IN THE EXPECTED LIST <- finding') ; $versionsAgree = $false ; continue }
    $wanted = $expectedVersions[$assetPath]
    $agrees = ($wanted -eq $assetVersion)
    $note = $(if ($assetPath -eq 'js/widget-resize.js') { '  <- the ONE that must move, 3 -> 4' } else { '' })
    Say ('      ' + $assetPath.PadRight(36) + ' expected v=' + $wanted.PadRight(3) + ' measured v=' + $assetVersion.PadRight(3) + '  ' + $(if ($agrees) { 'agrees' } else { 'DISAGREES <- finding' }) + $note)
    if (-not $agrees) { $versionsAgree = $false }
  }
  if (-not $versionsAgree) { $pkgOk = $false }

  Say ''
  Say '  6b  THE ONE STATIC FILE THAT CHANGED - a plain file, so its sha IS a lawful predicate'
  $resizeBytes = Read-Entry 'wwwroot/js/widget-resize.js'
  $resizeFromRepo = Join-Path $CLONE 'src\CcDashboard.Web\wwwroot\js\widget-resize.js'
  if ($null -eq $resizeBytes) { Say '      widget-resize.js ABSENT FROM PACKAGE <- finding' ; $pkgOk = $false }
  elseif (-not (Test-Path -LiteralPath $resizeFromRepo)) { Say '      widget-resize.js not in the clone - NOT MEASURED' ; $pkgOk = $false }
  else {
    $resizeShaPkg  = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($resizeBytes)).Replace('-','')
    $resizeShaRepo = ShaOf $resizeFromRepo
    Say ('      in the package : ' + $resizeBytes.Length + ' B  ' + $resizeShaPkg)
    Say ('      in the clone   : ' + (Get-Item -LiteralPath $resizeFromRepo).Length + ' B  ' + $resizeShaRepo)
    $resizeSame = ($resizeShaPkg -eq $resizeShaRepo)
    Say ('      package == the pinned revision : ' + $resizeSame)
    Say  '      This file is not compiled, so equality with the source tree is exact and lawful -'
    Say  '      unlike an assembly, whose sha changes between two builds of one tree.'
    if (-not $resizeSame) { $pkgOk = $false }
  }
  Say ''
  Say '  6b2  THE SCOPED BUNDLE MUST NOT HAVE MOVED - it is in the package, but no .razor.css changed'
  $bundleBytes = Read-Entry 'wwwroot/CcDashboard.Web.styles.css'
  if ($null -eq $bundleBytes) { Say '      BUNDLE ABSENT FROM PACKAGE <- finding' ; $pkgOk = $false }
  else {
    $bundleSha = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($bundleBytes)).Replace('-','')
    Say ('      CcDashboard.Web.styles.css  ' + $bundleBytes.Length + ' B  ' + $bundleSha)
    Say ('      the grid needle of the LAST flight "1fr auto 38px" : ' + (Count-Needle $bundleBytes '1fr auto 38px' 'utf8') + '   expected 1 or more - it must still be there, this flight does not undo it')
    Say ('      NEGCTL "1fr auto 999px" : ' + (Count-Needle $bundleBytes '1fr auto 999px' 'utf8') + '   must be 0')
    if ((Count-Needle $bundleBytes '1fr auto 38px' 'utf8') -lt 1) { $pkgOk = $false }
    if ((Count-Needle $bundleBytes '1fr auto 999px' 'utf8') -ne 0) { $pkgOk = $false }
  }

  Say ''
  Say '  6c  THE ASSEMBLIES - three appearing needles and one DISAPPEARING'
  $webBytes = Read-Entry 'CcDashboard.Web.dll'
  $appBytes = Read-Entry 'CcDashboard.Application.dll'
  $infraBytes = Read-Entry 'CcDashboard.Infrastructure.dll'
  foreach ($pair in @(@('CcDashboard.Web.dll', $webBytes), @('CcDashboard.Application.dll', $appBytes), @('CcDashboard.Infrastructure.dll', $infraBytes))) {
    if ($null -eq $pair[1]) { Say ('      ' + $pair[0] + ' ABSENT FROM PACKAGE <- finding') ; $pkgOk = $false ; continue }
    $sha = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($pair[1])).Replace('-','')
    Say ('      ' + $pair[0].PadRight(32) + ([string]$pair[1].Length).PadLeft(9) + ' B  ' + $sha)
  }
  if ($null -ne $appBytes) {
    $goneUtf16 = Count-Needle $appBytes 'GetTenantStatusGroupsQuery' 'utf16'
    $goneUtf8  = Count-Needle $appBytes 'GetTenantStatusGroupsQuery' 'utf8'
    Say ('      DISAPPEARING "GetTenantStatusGroupsQuery" : utf16 ' + $goneUtf16 + ' , utf8 ' + $goneUtf8)
    Say  '      expected 0 in BOTH. Measured on 234 at 09:46 today in the installed build as utf16 1'
    Say  '      and utf8 3, so this zero carries meaning; without that before-count it would not.'
    $newQuery16 = Count-Needle $appBytes 'GetWfmServingGroupCandidatesQuery' 'utf16'
    $newQuery8  = Count-Needle $appBytes 'GetWfmServingGroupCandidatesQuery' 'utf8'
    Say ('      APPEARING "GetWfmServingGroupCandidatesQuery" : utf16 ' + $newQuery16 + ' , utf8 ' + $newQuery8 + '   expected 1 or more in one of the two')
    $negQuery = Count-Needle $appBytes 'GetWfmZzzNoSuchQuery' 'utf16'
    Say ('      NEGCTL a query that cannot be there : ' + $negQuery + '   must be 0')
    if ((($goneUtf16 + $goneUtf8) -ne 0) -or (($newQuery16 + $newQuery8) -lt 1) -or ($negQuery -ne 0)) { $pkgOk = $false }
  }
  if ($null -ne $infraBytes) {
    $provider16 = Count-Needle $infraBytes 'WfmEngineAgentCountProvider' 'utf16'
    $provider8  = Count-Needle $infraBytes 'WfmEngineAgentCountProvider' 'utf8'
    $gate16 = Count-Needle $infraBytes 'WfmLogGate' 'utf16'
    $gate8  = Count-Needle $infraBytes 'WfmLogGate' 'utf8'
    Say ('      APPEARING "WfmEngineAgentCountProvider" : utf16 ' + $provider16 + ' , utf8 ' + $provider8 + '   expected 1 or more')
    Say ('      APPEARING "WfmLogGate"                  : utf16 ' + $gate16 + ' , utf8 ' + $gate8 + '   expected 1 or more')
    $negInfra = Count-Needle $infraBytes 'WfmZzzNoSuchProvider' 'utf16'
    Say ('      NEGCTL a type that cannot be there : ' + $negInfra + '   must be 0')
    if ((($provider16 + $provider8) -lt 1) -or (($gate16 + $gate8) -lt 1) -or ($negInfra -ne 0)) { $pkgOk = $false }
  }
  if ($null -ne $webBytes) {
    $keyWeb16 = Count-Needle $webBytes 'Wfm_NUnknown' 'utf16'
    $keyWeb8  = Count-Needle $webBytes 'Wfm_NUnknown' 'utf8'
    Say ('      web.dll key "Wfm_NUnknown" : utf16 ' + $keyWeb16 + ' , utf8 ' + $keyWeb8 + '   expected 1 or more in one of the two (en-US lives here)')
    $negKey = Count-Needle $webBytes 'Wfm_ZzzNoSuchKey' 'utf16'
    Say ('      NEGCTL a key that cannot be there : ' + $negKey + '   must be 0')
    if ((($keyWeb16 + $keyWeb8) -lt 1) -or ($negKey -ne 0)) { $pkgOk = $false }
  }

  Say ''
  Say '  6d  THE SATELLITES - three .resx are in this delta, so Wfm_NUnknown must be in he-IL and ru-RU'
  Say '      Size is a verdict in NEITHER direction: a 512-byte alignment step can swallow a new'
  Say '      string whole. The KEY is the measurement; the size is printed as context.'
  foreach ($culture in @('he-IL','ru-RU','en-US')) {
    $bytes = Read-Entry ($culture + '/CcDashboard.Web.resources.dll')
    if ($null -eq $bytes) {
      if ($culture -eq 'en-US') { Say ('      ' + $culture.PadRight(8) + ' no satellite - en-US lives inside web.dll, measured in 6c') ; continue }
      Say ('      ' + $culture.PadRight(8) + ' ABSENT FROM PACKAGE <- finding') ; $pkgOk = $false ; continue
    }
    $key16 = Count-Needle $bytes 'Wfm_NUnknown' 'utf16'
    $key8  = Count-Needle $bytes 'Wfm_NUnknown' 'utf8'
    $neg   = Count-Needle $bytes 'Wfm_ZzzNoSuchKey' 'utf16'
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
