<#
  PROBE  probe_WS_20261013_shellpkg-2d75b01.ps1
  SHAPE  FIRST probe built on .probes/_core.ps1. Everything generic - the byte finder, the report
         writer, the self-test, the row reader, the stamp parser - now lives in the core and is
         proven there before this file measures anything. Five of the instrument defects of
         11-12.10 lived in exactly that carried-by-hand half; this file carries only pins and
         predicates. The core prints its own sha in the header.
  UNIT   v4 head 2d75b01, -Mode Shell -SkipDB. Blessing for this flight: operator word "daju"
         at 2026-10-13T10:18:59Z over the standing f333db5.
  DELTA, RE-TAKEN BY ME AS THE BLESSING DEMANDED ("pere-snimi sam"), measured 2026-10-13 from the
         shared object store, not copied from the letter:
           M src/CcDashboard.Web/Components/Dashboard/ScreenEditorPage.razor   (+17 lines)
           M src/CcDashboard.Web/Components/Widgets/WfmWidget.razor            (+10 lines)
         TWO files, pure additions, 27 insertions and 0 deletions. wwwroot/ 0, RTM/ 0, deploy/ 0,
         db/ 0, .resx 0, Contracts 0, migrations 0. No "?v=" string anywhere in the delta.
         Agrees with the coordinator's figures - and is re-measured below by blob, in PIN 3.
  WHAT THIS FLIGHT CAN AND CANNOT PROVE - the hardest line of this probe
         The edit assigns four config properties in C# inside two .razor files. It produces NO new
         string in any served file: the property names, the four selectors and every CSS class
         already existed. THERE IS NO BYTE NEEDLE. So this probe does NOT invent one, and it does
         not assert "web.dll differs from the one before" either - a rebuilt assembly's sha changes
         by itself (measured 2026-10-12: two builds of byte-identical .resx gave different satellite
         sha at identical sizes), so "differs" would be True for a package carrying nothing at all.
         What the package side can lawfully prove is exactly three things, and this probe proves
         only those: the package is FRESH (built after this run started), it is INTERNALLY
         COMPLETE (Shell entries, no RTM entries, the updater present), and every file this flight
         must NOT move comes out of it. The version of what runs on 234 is proven elsewhere: by the
         sha of THIS zip recorded in the ledger at install, and by the behavioural acceptance of
         the four Wfm font sizes in the viewer.
  NO NUMBER FROM 234 IS WRITTEN INTO THIS FILE. The last flights pinned the server's satellite
         sizes and assembly hashes here, by hand, from yesterday's report - and a carried satellite
         rule painted a correct package RED on three rows on 2026-10-11. This probe only RECORDS
         what the package carries; the pre-deploy probe records what 234 carries; the install probe
         compares disk against the unpacked staging of this very package, where both halves are
         measured in one place at one time.
  SERVER 234 IS NOT TOUCHED. The v4 worktree is not touched. No push. Nothing outside the clone
         directory named in the rollback line is written.
#>

. (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '_core.ps1')

$WORK      = 'D:\Claude\Projects\RTM View Shell'
$V4WT      = 'D:\Claude\Projects\RTM-design'
$BUILDROOT = 'D:\Claude\Build'
$BLESSED_HEAD = '2d75b01'
# What 234 runs right now - the other end of the delta. NEVER the same token as the head being
# built: a search-and-replace across this file made those two equal on 2026-10-10, the delta came
# out empty and the probe refused to build. PIN 2b checks it.
$DEPLOYED  = 'f333db5'

Start-Probe -Name 'shellpkg-2d75b01' -Title 'SHELL PACKAGE  v4 2d75b01  (Wfm font sizes)' -OutputDir (Join-Path $WORK '.measurements')
Say ('PS version : ' + $PSVersionTable.PSVersion.ToString())
Say  'SERVER 234 IS NOT TOUCHED. The v4 worktree is not touched. No push.'
Rule

Say 'G1  the head being built must be the BLESSED revision, not whatever the head is now'
$PIN_COMMIT = (Invoke-Native { & git -C "$V4WT" rev-parse v4 }).Trim()
$PIN_SHORT  = $PIN_COMMIT.Substring(0,7)
Say ('  expected : head of v4 == ' + $BLESSED_HEAD + '   (operator word 2026-10-13T10:18:59Z)')
Say ('  measured : ' + $PIN_COMMIT)
$headIsBlessed = ($PIN_SHORT -eq $BLESSED_HEAD)
Say ('  head == blessed : ' + $headIsBlessed)
if (-not $headIsBlessed) {
  Say '  STOP. The head moved past the blessed revision. Nothing is cloned, nothing is built.'
  Say '  Report both tokens and ask for a blessing on the new head.'
  Finish $false
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$CLONE = Join-Path $BUILDROOT ('rtm_v4s_{0}_{1}' -f $PIN_SHORT, $stamp)
Say ('  clone will be : ' + $CLONE)
Rule

Say 'G2  ROLLBACK FOR THIS RUN, printed BEFORE the first write'
Say ('  Remove-Item -Recurse -Force ' + [char]39 + $CLONE + [char]39)
Say  '  Nothing outside that directory is written. No service, no server, no worktree, no repo state.'
Rule

Say 'G3  clones left by PREVIOUS runs of this same step'
Say  '  Only directories carrying THIS step mark are deleted; anything else is named and left alone.'
if (Test-Path -LiteralPath $BUILDROOT) {
  foreach ($priorDir in @(Get-ChildItem -LiteralPath $BUILDROOT -Directory -Filter 'rtm_v4s_*' -ErrorAction SilentlyContinue)) {
    $markFile = Join-Path $priorDir.FullName '.origin'
    if (-not (Test-Path -LiteralPath $markFile)) {
      Say ('  ' + $priorDir.Name + '  -> NO MARK: origin unknown. NOT TOUCHED.')
    } elseif ((Get-Content -LiteralPath $markFile -Raw) -like '*shellpkg-2d75b01*') {
      $sizeGb = [math]::Round((Get-ChildItem -LiteralPath $priorDir.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB, 2)
      Say ('  ' + $priorDir.Name + '  -> MY OWN previous run, ' + $sizeGb + ' GB. DELETING.')
      Remove-Item -LiteralPath $priorDir.FullName -Recurse -Force
      Say ('      deleted; exists now: ' + (Test-Path -LiteralPath $priorDir.FullName))
    } else {
      Say ('  ' + $priorDir.Name + '  -> ANOTHER probe artifact. NOT TOUCHED.')
    }
  }
}
Rule

Say 'G4  tools'
if (-not (Test-Path -LiteralPath $V4WT))  { Say ('  v4 worktree not found: ' + $V4WT) ; Finish $false }
if (Test-Path -LiteralPath $CLONE)        { Say ('  clone dir already exists: ' + $CLONE) ; Finish $false }
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
Say ('  expected : 0 porcelain lines')
Say ('  measured : ' + $porcelain.Count)
$pinClean = ($porcelain.Count -eq 0)
Say ('  PIN 2 ' + $(if ($pinClean) { 'GREEN' } else { 'RED    tree not clean' }))
$selfPath = $PSCommandPath
$originText = @(
  ('probe   : probe_WS_20261013_shellpkg-2d75b01.ps1'),
  ('sha256  : ' + (ShaOf $selfPath)),
  ('core    : ' + (ShaOf (Join-Path (Split-Path -Parent $PSCommandPath) '_core.ps1'))),
  ('stamp   : ' + $stamp),
  ('machine : ' + $env:COMPUTERNAME + ' / ' + $env:USERNAME),
  ('commit  : ' + $PIN_COMMIT),
  ('unit    : v4 Wfm font sizes, Mode Shell SkipDB, by devops-0919')
) -join "`r`n"
[IO.File]::WriteAllText((Join-Path $CLONE '.origin'), $originText + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
Say  '  .origin written inside the clone'
Rule

Say 'PIN 2b  the deployed revision and the one being built must be DIFFERENT tokens'
Say ('  deployed on 234 : ' + $DEPLOYED)
Say ('  being built     : ' + $PIN_SHORT)
if ($DEPLOYED -eq $PIN_SHORT) {
  Say '  RED. The two tokens are equal - a search-and-replace has overwritten one of them and every'
  Say '  delta below would come out empty. Nothing is built.'
  Finish $false
}
Say  '  PIN 2b GREEN  the two tokens differ, so the delta below is a real delta'
Rule

Say 'PIN 3  content witnesses - every product file of the delta, blob by blob, clone against worktree'
$witnesses = @(Invoke-Native { & git -C "$V4WT" diff --name-only ($DEPLOYED + '..' + $PIN_COMMIT) -- src/ RTM/ } | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
Say ('  expected : 2 product files, both .razor under src/CcDashboard.Web')
Say ('  measured : ' + $witnesses.Count)
foreach ($witness in $witnesses) { Say ('    ' + $witness) }
if ($witnesses.Count -eq 0) { Say '  RED. The delta lists no product files - refusing to build a package that changes nothing.' ; Finish $false }
$mismatched = 0
foreach ($witness in $witnesses) {
  $blobClone = (Invoke-Native { & git -C "$CLONE" rev-parse ('HEAD:' + $witness) }).Trim()
  $blobWork  = (Invoke-Native { & git -C "$V4WT"  rev-parse ($PIN_COMMIT + ':' + $witness) }).Trim()
  if (-not (($blobClone -eq $blobWork) -and ($blobClone.Length -eq 40))) {
    $mismatched++ ; Say ('  MISMATCH ' + $witness + '  clone ' + $blobClone + '  work ' + $blobWork)
  }
}
Say ('  blobs compared : ' + $witnesses.Count + '   mismatched : ' + $mismatched)
$pinWitness = ($mismatched -eq 0)
Say ('  PIN 3 ' + $(if ($pinWitness) { 'GREEN  every product blob of the delta is equal' } else { 'RED    a blob differs - the builder would read a tree I never checked' }))
Rule

Say 'PIN 3b  WHAT THE DELTA CONTAINS - this is what decides -Mode Shell -SkipDB'
$deltaAll = @(Invoke-Native { & git -C "$V4WT" diff --name-only ($DEPLOYED + '..' + $PIN_COMMIT) } | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
$migrationHits = @($deltaAll | Where-Object { $_ -like 'db/migrations/*' }).Count
$engineHits    = @($deltaAll | Where-Object { $_ -like 'RTM/*' }).Count
$srcHits       = @($deltaAll | Where-Object { $_ -like 'src/*' }).Count
$resxHits      = @($deltaAll | Where-Object { $_ -like '*.resx' }).Count
$staticHits    = @($deltaAll | Where-Object { $_ -like '*wwwroot/*' }).Count
$contractHits  = @($deltaAll | Where-Object { $_ -like 'src/CcDashboard.Contracts/*' }).Count
$deployHits    = @($deltaAll | Where-Object { $_ -like 'deploy/*' }).Count
$razorHits     = @($deltaAll | Where-Object { $_ -like '*.razor' }).Count
Say ('  total files    : ' + $deltaAll.Count + '   (expected 2)')
Say ('  db/migrations/ : ' + $migrationHits + '   (expected 0 - non-zero means the DB layer may NOT be skipped)')
Say ('  RTM/ engine    : ' + $engineHits    + '   (expected 0 - this is WHY the mode is Shell, not Full)')
Say ('  deploy/        : ' + $deployHits    + '   (expected 0 - the updater itself is unchanged)')
Say ('  wwwroot/       : ' + $staticHits    + '   (expected 0 - WHY every asset version must stay put)')
Say ('  .resx          : ' + $resxHits      + '   (expected 0 - WHY the satellites must come out EQUAL, not grown)')
Say ('  Contracts/     : ' + $contractHits  + '   (expected 0 - the four properties already existed there)')
Say ('  *.razor        : ' + $razorHits     + '   (expected 2 - this is where the whole flight lives)')
Say ('  src/           : ' + $srcHits       + '   (POSCTL - a zero here would mean the listing came out empty and every line above is a blind pass)')
$modeLawful = (($migrationHits -eq 0) -and ($engineHits -eq 0) -and ($srcHits -gt 0) -and ($deltaAll.Count -eq 2) -and ($razorHits -eq 2))
Say ('  PIN 3b ' + $(if ($modeLawful) { 'GREEN  -Mode Shell -SkipDB is lawful and the delta is the blessed one' } else { 'RED    STOP - the delta does not match the blessing' }))
Rule

Say 'PIN 3c  NO "?v=" STRING ANYWHERE IN THE DELTA - the asset versions cannot have moved'
$versionLines = @(Invoke-Native { & git -C "$V4WT" diff ($DEPLOYED + '..' + $PIN_COMMIT) } | Where-Object { $_ -match '^[+-][^+-]' -and $_ -match '\?v=' })
Say ('  expected : 0 added or removed lines carrying "?v="')
Say ('  measured : ' + $versionLines.Count)
foreach ($versionLine in $versionLines) { Say ('    ' + $versionLine) }
$negVersion = @(Invoke-Native { & git -C "$V4WT" diff ($DEPLOYED + '~1..' + $DEPLOYED) } | Where-Object { $_ -match '^[+-][^+-]' -and $_ -match '\?v=' }).Count
Say ('  NEGCTL   : the SAME search over the previous flight (' + $DEPLOYED + '~1..' + $DEPLOYED + ') finds ' + $negVersion + ' such lines - that flight did move versions, so this search is able to return non-zero')
$pinVersions = (($versionLines.Count -eq 0) -and ($negVersion -gt 0))
Say ('  PIN 3c ' + $(if ($pinVersions) { 'GREEN  no version moved, and the search proved it can find one' } else { 'RED' }))
Rule

if (-not ($pinClone -and $pinClean -and $pinWitness -and $modeLawful -and $pinVersions)) {
  Say 'STOP BEFORE BUILD: a provenance pin is RED. Nothing was built, nothing was packaged.'
  Say ('Rollback line above removes the clone: ' + $CLONE)
  Finish $false
}

$buildStartedAt = Get-Date
Say ('PIN 4  build in the clean clone. Started ' + $buildStartedAt.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + 'Z  (local ' + $buildStartedAt.ToString('HH:mm:ss') + ' local)')
Say  '  Any package older than that timestamp is a leftover, not this run result, and is refused below.'
$builder = Join-Path $CLONE 'tools\Build-ProdRelease.ps1'
if (-not (Test-Path -LiteralPath $builder)) { Say ('  builder not found: ' + $builder) ; Finish $false }
Say ('  builder sha256 : ' + (ShaOf $builder))
$garnetDir = Join-Path $WORK 'tools\cache\garnet-1.1.10-win-x64-net8'
$nssmDir   = Join-Path $WORK 'tools\cache\nssm'
foreach ($toolName in @('GarnetServer.exe','nssm.exe')) {
  $toolPath = if ($toolName -eq 'nssm.exe') { Join-Path $nssmDir $toolName } else { Join-Path $garnetDir $toolName }
  if (Test-Path -LiteralPath $toolPath) { Say ('  ' + $toolName.PadRight(18) + (ShaOf $toolPath)) }
  else { Say ('  ' + $toolName.PadRight(18) + 'NOT FOUND at ' + $toolPath + '  <- the build will refuse; stop and report') }
}
Say  '  command : Build-ProdRelease.ps1 -Mode Shell -SkipDB -GarnetDir <work cache> -NssmDir <work cache>'
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
if (-not (Test-Path -LiteralPath $instDir)) { Say ('  no Installations directory in the clone: ' + $instDir) ; Finish $false }
$zip = Get-ChildItem -LiteralPath $instDir -Filter *.zip | Where-Object { $_.LastWriteTime -ge $buildStartedAt } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $zip) { Say '  RED. No .zip produced by THIS run - refusing to hand out an older package.' ; Finish $false }
$zipHash = ShaOf $zip.FullName
Say ('  freshness  : written ' + $zip.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss') + ' local , build started ' + $buildStartedAt.ToString('HH:mm:ss') + ' local')
Say ('  zip name   : ' + $zip.Name)
Say ('  zip bytes  : ' + $zip.Length + '   (' + [math]::Round($zip.Length/1MB,2) + ' MB)')
Say ('  zip sha256 : ' + $zipHash)
Say  '  THIS SHA IS THE PROOF OF VERSION FOR THIS FLIGHT. It goes into the ledger at install, and the'
Say  '  install probe compares the disk against the staging unpacked from this very file. There is no'
Say  '  byte needle in this edit, so this sha and the behavioural acceptance are the whole proof.'
Rule

Say 'PIN 6  INSIDE THE PACKAGE - completeness, and everything that must NOT have moved'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip.FullName)
$pkgOk = $true
try {
  $entries = $archive.Entries
  $entryNames = @($entries | ForEach-Object { $_.FullName })
  Say ('  entries : ' + $entryNames.Count)
  foreach ($need in @('Update-RTMView.ps1','Install-RTMView.ps1')) {
    $hits = @($entryNames | Where-Object { $_ -like ('*' + $need) }).Count
    Say ('  contains ' + $need.PadRight(22) + ' : ' + $hits + '   (expected 1 or more)')
    if ($hits -lt 1) { $pkgOk = $false }
  }
  $rtmEntries   = @($entryNames | Where-Object { ($_ -replace '\\','/') -like 'RTM/*' }).Count
  $shellEntries = @($entryNames | Where-Object { ($_ -replace '\\','/') -like 'Shell/*' }).Count
  Say ('  RTM\   entries : ' + $rtmEntries   + '   (expected 0 for Mode Shell)')
  Say ('  Shell\ entries : ' + $shellEntries + '   (must be non-zero - else the package carries nothing; POSCTL for the two rows above)')
  if (($rtmEntries -ne 0) -or ($shellEntries -le 0)) { $pkgOk = $false }

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
    return $buffer
  }

  Say  ''
  Say  ''
  Say  '  6a  THE STATIC FILES - THE LIST IS READ OUT OF App.razor, NOT TYPED HERE'
  Say  '      The first run of this probe typed the nine paths by hand and got three of them wrong:'
  Say  '      app.js is under js/, wallboard-skin.css under css/widgets/, and the resize script is'
  Say  '      widget-resize.js, not widgetResize.js. All three printed "ABSENT FROM PACKAGE" and'
  Say  '      painted a correct package RED - a false red, the dearer kind, because it sends me to'
  Say  '      fix something healthy. A list I can mistype is not a measurement. The list below is'
  Say  '      parsed out of App.razor at the pinned revision, so it cannot disagree with the page'
  Say  '      that actually loads these files, and a tenth asset appearing there would be followed.'
  $appRazorPath = Join-Path $CLONE 'src\CcDashboard.Web\Components\App.razor'
  $assetRows = @()
  if (-not (Test-Path -LiteralPath $appRazorPath)) {
    Say ('      App.razor not found at ' + $appRazorPath + '  <- cannot derive the list') ; $pkgOk = $false
  } else {
    $appRazorText = [IO.File]::ReadAllText($appRazorPath)
    foreach ($assetMatch in [regex]::Matches($appRazorText, '(?:href|src)="([^":]+?)\?v=(\d+)"')) {
      $assetRows += ,@($assetMatch.Groups[1].Value, $assetMatch.Groups[2].Value)
    }
  }
  Say ('      assets declared in App.razor : ' + $assetRows.Count + '   (expected 9 - the blessing names nine)')
  if ($assetRows.Count -ne 9) { $pkgOk = $false }
  if ($null -eq $appRazorText) { $appRazorText = '' }
  $negAsset = ([regex]::Matches($appRazorText, 'zzz-no-such-asset\.css\?v=\d+')).Count
  Say ('      NEGCTL an asset that cannot be declared : ' + $negAsset + ' hits (expected 0; the 9 above prove the same regex does find real ones)')
  if ($negAsset -ne 0) { $pkgOk = $false }
  Say  ''
  Say  '      THE VERSIONS THE BLESSING NAMES, against the versions App.razor carries at 2d75b01.'
  Say  '      No wwwroot file and no "?v=" line is in the delta (PIN 3b, PIN 3c), so every one of'
  Say  '      these must still read exactly what the coordinator wrote down.'
  $blessedVersions = @{
    'app.css' = '36' ; 'CcDashboard.Web.styles.css' = '10' ; 'js/daytrendChart.js' = '14'
    'js/agentStateDistributionChart.js' = '16' ; 'js/reportDistributionChart.js' = '6'
    'js/widget-resize.js' = '3' ; 'css/tokens.css' = '3' ; 'css/widgets/wallboard-skin.css' = '3'
    'js/app.js' = '2'
  }
  $versionsAgree = $true
  foreach ($assetRow in $assetRows) {
    $assetPath = $assetRow[0] ; $assetVersion = $assetRow[1]
    if (-not $blessedVersions.ContainsKey($assetPath)) {
      Say ('      ' + $assetPath.PadRight(38) + ' v=' + $assetVersion + '   NOT IN THE BLESSED LIST <- finding') ; $versionsAgree = $false ; continue
    }
    $expectedVersion = $blessedVersions[$assetPath]
    $agrees = ($expectedVersion -eq $assetVersion)
    Say ('      ' + $assetPath.PadRight(38) + ' expected v=' + $expectedVersion.PadRight(3) + ' measured v=' + $assetVersion.PadRight(3) + '  ' + $(if ($agrees) { 'agrees' } else { 'MOVED <- finding' }))
    if (-not $agrees) { $versionsAgree = $false }
  }
  if (-not $versionsAgree) { $pkgOk = $false }
  Say  ''
  Say  '      AND THE BODIES, out of the package itself. These are plain text files, not built'
  Say  '      assemblies, so their sha IS a lawful predicate; the install probe compares the disk'
  Say  '      against this same staging, where both halves are measured at one time.'
  foreach ($assetRow in $assetRows) {
    $staticPath = 'wwwroot/' + $assetRow[0]
    $bytes = Read-Entry $staticPath
    if ($null -eq $bytes) { Say ('      ' + $staticPath.PadRight(44) + ' ABSENT FROM PACKAGE  <- finding') ; $pkgOk = $false ; continue }
    $sha = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($bytes)).Replace('-','')
    Say ('      ' + $staticPath.PadRight(44) + ' ' + ([string]$bytes.Length).PadLeft(7) + ' B  ' + $sha)
  }
  $bundleBytes = Read-Entry 'wwwroot/CcDashboard.Web.styles.css'
  if ($null -ne $bundleBytes) {
    $bundleSha = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($bundleBytes)).Replace('-','')
    Say  ''
    Say ('      SCOPED BUNDLE, called out on its own because the blessing stops the flight on it:')
    Say ('        CcDashboard.Web.styles.css  ' + $bundleBytes.Length + ' B  ' + $bundleSha)
    Say  '        It is built from the .razor.css files and no .razor.css is in this delta. THIS sha is'
    Say  '        the one handed out before the install; the install probe compares the disk against it,'
    Say  '        and a bundle that moved is a stop and a letter to the coordinator, not a note.'
  } else { Say '      SCOPED BUNDLE ABSENT FROM PACKAGE  <- finding' ; $pkgOk = $false }

  Say  ''
  Say  '  6b  THE THREE DICTIONARIES - PRESENCE AND SIZE ONLY, AND NO KEY SEARCH AT ALL'
  Say  '      The first run of this probe searched all three for the four Wfm property names and'
  Say  '      printed "0/4" on every row. That rule was carried over from the f333db5 flight, where'
  Say  '      three .resx WERE in the delta and four new label keys had to appear. Measured in the'
  Say  '      2d75b01 tree today: the three .resx carry NO key whose name starts with Wfm, and the'
  Say  '      four names are C# CONFIG PROPERTIES, not resource keys - they were never supposed to'
  Say  '      be in a dictionary, before this flight or after it. Demanding them painted a correct'
  Say  '      package red on three rows, which is the same fault as the carried satellite-growth'
  Say  '      rule of 2026-10-11. .resx count in this delta is 0 (PIN 3b), so the only lawful'
  Say  '      predicate here is: present, and equal to what 234 runs - and that comparison belongs'
  Say  '      to the install probe, which has both halves in front of it at once.'
  foreach ($culture in @('he-IL','ru-RU','en-US')) {
    $bytes = Read-Entry ($culture + '/CcDashboard.Web.resources.dll')
    if ($null -eq $bytes) { Say ('      ' + $culture.PadRight(8) + ' ABSENT FROM PACKAGE  <- finding') ; $pkgOk = $false ; continue }
    $sha = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($bytes)).Replace('-','')
    Say ('      ' + $culture.PadRight(8) + ([string]$bytes.Length).PadLeft(7) + ' B  ' + $sha + '   (sha RECORDED, never a predicate: a rebuild changes it by itself)')
  }
  $negSat = Read-Entry 'zz-ZZ/CcDashboard.Web.resources.dll'
  Say ('      NEGCTL a culture that cannot be in the package : ' + $(if ($null -eq $negSat) { 'absent, as it must be - so the three rows above are real reads' } else { 'FOUND - the reader is broken' }))
  if ($null -ne $negSat) { $pkgOk = $false }

  Say  ''
  Say  '  6c  THE ASSEMBLIES. web.dll is RECORDED, not compared against the deployed one: it was'
  Say  '      rebuilt, so "differs" is True even for a package carrying nothing, and "equals" is'
  Say  '      impossible. Contracts and the engine must simply be PRESENT and come from this package.'
  foreach ($assembly in @('CcDashboard.Web.dll','CcDashboard.Contracts.dll')) {
    $bytes = Read-Entry $assembly
    if ($null -eq $bytes) { Say ('      ' + $assembly.PadRight(28) + ' ABSENT FROM PACKAGE  <- finding') ; $pkgOk = $false ; continue }
    $sha = [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($bytes)).Replace('-','')
    Say ('      ' + $assembly.PadRight(28) + ([string]$bytes.Length).PadLeft(9) + ' B  ' + $sha)
  }
  Say  ''
  Say  '  6d  THE FOUR CONFIG PROPERTY NAMES INSIDE web.dll. This is NOT a needle for the edit - the'
  Say  '      properties existed before it and the two .razor files compile into the same assembly,'
  Say  '      so their presence is True on both sides of this flight. It is a completeness check on'
  Say  '      the assembly, and it is labelled as such so no one reads it as proof of version.'
  $webBytes = Read-Entry 'CcDashboard.Web.dll'
  if ($null -ne $webBytes) {
    foreach ($prop in @('WfmTileTitleFontSize','WfmTileValueFontSize','WfmListTitleFontSize','WfmListValueFontSize')) {
      $offsetFound = Find-Text $webBytes $prop
      Say ('      ' + $prop.PadRight(24) + ' @ ' + $offsetFound + '   (present on BOTH sides of this flight - completeness, not proof)')
      if ($offsetFound -lt 0) { $pkgOk = $false }
    }
    $negProp = Find-Text $webBytes 'WfmTileTitleFontSizeZZZ'
    Say ('      NEGCTL a name that cannot be there : ' + $(if ($negProp -lt 0) { 'absent, as it must be' } else { 'FOUND - the search is broken, every row above is a blind pass' }))
    if ($negProp -ge 0) { $pkgOk = $false }
  }
} finally { $archive.Dispose() }
Rule

Say 'PIN 7  the package is copied to the project Installations directory, for the hand-over to 234'
$projInst = Join-Path $WORK 'Installations'
if (-not (Test-Path -LiteralPath $projInst)) { New-Item -ItemType Directory -Path $projInst | Out-Null }
$destZip = Join-Path $projInst $zip.Name
Copy-Item -LiteralPath $zip.FullName -Destination $destZip -Force
$destHash = ShaOf $destZip
Say ('  copied to  : ' + $destZip)
Say ('  expected   : sha equal to the zip measured in PIN 5')
Say ('  measured   : ' + $destHash)
$copyOk = ($destHash -eq $zipHash)
Say ('  PIN 7 ' + $(if ($copyOk) { 'GREEN  the copy is byte-identical' } else { 'RED    the copy differs from the built zip' }))
Rule

Say 'VERDICT OF THE PACKAGE BUILD'
Say ('  trap fired during the run          : ' + (Test-TrapFired) + '   (True means a section was SKIPPED, not passed)')
Say ('  PIN 1/2/2b/3 provenance            : ' + ($pinClone -and $pinClean -and $pinWitness))
Say ('  PIN 3b delta and mode              : ' + $modeLawful)
Say ('  PIN 3c no asset version moved       : ' + $pinVersions)
Say ('  PIN 4 builder exit 0               : ' + ($buildExit -eq 0))
Say ('  PIN 6 package complete and clean   : ' + $pkgOk + '   (asset list parsed from App.razor, versions against the blessed nine, no key search)')
Say ('  PIN 7 hand-over copy identical     : ' + $copyOk)
$all = ($pinClone -and $pinClean -and $pinWitness -and $modeLawful -and $pinVersions -and ($buildExit -eq 0) -and $pkgOk -and $copyOk -and (-not (Test-TrapFired)))
Say ('  PACKAGE : ' + $(if ($all) { 'READY TO HAND OVER' } else { 'NOT READY - see the RED rows above' }))
Say  '  Nothing has been installed. 234 is untouched. The install step is a separate box.'
Finish $all
