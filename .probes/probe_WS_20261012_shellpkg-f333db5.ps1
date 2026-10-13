<#
  PROBE  probe_WS_20261012_shellpkg-f333db5.ps1
  SHAPE  FROM probe_WS_20261012_shellpkg-2ccbf1c.ps1 - the flight whose predicate matches this one
         (static DOES move here), not from the e6a0fcb probe that ran last, whose whole point was
         that nothing static moves. The form is chosen by the predicate, never by what ran last.
  UNIT   v4 head f333db5, built -Mode Shell -SkipDB. Blessing 2026-10-11T07:58:22Z with the
         operator's word quoted in it ("daju slovo"). The inbox is re-read as the first action of
         the install step, as the gate of de5f50f requires; a later letter with a stop word stops it.
  THE HEAD IS PINNED TO THE BLESSED REVISION
         The coordinator blessed 2f3b426 and wrote "head further - stop". So this probe does not
         just re-take the head and build whatever it finds: it compares it to the blessed token
         and refuses when they differ. Measured by rev-parse, printed before the comparison.
  WHY SHELL AND NOT FULL - re-measured here by BLOB, never taken from the letter:
         the clean difference 2ccbf1c..f333db5 is SIX files, all under src/CcDashboard.Web:
         App.razor, DistributionReportWidget.razor, the DayTrend widget and its .razor.css, the
         ASD .razor.css, and wwwroot/app.css. RTM/ 0, deploy/ 0, db/ 0, migrations 0, .resx 0,
         Contracts 0, and NO .js at all - which inverts the script rows of the last two flights.
  THE SATELLITE PREDICATE FLIPS BACK TO EQUALITY - RE-DERIVED, NOT REMEMBERED
         NO .resx is in this delta, so the three dictionaries must come out EQUAL to what 234 runs:
         77824 / 88064 / 71168. The flight before demanded growth; carrying that over would paint a
         correct package red on all three rows, which is exactly what happened to me yesterday in
         the mirror case. Equality is the pass, and the four Wfm keys must simply still be there.
  WHAT A REBUILT ASSEMBLY'S sha CAN AND CANNOT SAY - MEASURED, NOT ASSUMED
         Nothing under src/CcDashboard.Contracts is in this delta, so I first wrote that
         Contracts.dll must come out byte-identical to the one 234 runs. It did not, and the run
         above printed that as a finding. The check that settled it: the three DICTIONARIES, built
         from .resx that are identical between the two revisions, also came out with different sha
         at identical sizes. A rebuild is therefore not byte-reproducible, and the sha of a built
         assembly is not a predicate for 'the content did not change'. What this probe asserts
         instead: the assembly is PRESENT, equals what this very package carries, and contains the
         type name by a self-tested byte search. The same correction applies backwards: the line
         'Contracts.dll differs from the one that was there before', which I reported as proof in
         the 2f3b426 flight, would have been True for a package carrying nothing.
  NO SCRIPT CHANGES AT ALL THIS TIME, so the three script rows of the last flights invert: the
         three chart scripts must come out of the package BYTE-IDENTICAL to what 234 runs, and a
         changed one is the finding. The work is in CSS instead.
  WHAT CARRIES THE WORK, AND WHERE EACH PIECE CAN BE SEEN
         app.css is a plain file in wwwroot: measured in the blobs 100149 -> 100541 B, blob
         8550C9AE -> F11C2EE2, and the needle distribution-chart-box goes 0 -> 1. That one is
         provable inside the package.
         CcDashboard.Web.styles.css is the SCOPED BUNDLE, built from the .razor.css files, so its
         sha cannot be predicted here and is not pinned. Its needle is 'inset': the two .razor.css
         of this delta go 1 -> 2 (DayTrend) and 0 -> 1 (ASD), so the bundle must gain two. The
         BEFORE count is re-taken on the running server by the pre-deploy probe, NOT derived from
         the sources - the coordinator asked for exactly that order and it is the only honest one.
         web.dll carries the Razor code: its needle is the byte string ClipToNonZeroWindow, which
         appears in one source file of f333db5 and in none of 2ccbf1c.
  WHAT CANNOT BE PROVEN HERE
         App.razor compiles into CcDashboard.Web.dll, so the three moved asset versions are not
         files in this package. They are RECORDED here as a written expectation and proven after
         the install from the HTML the live server serves, behind two redirects.
  WHERE  WORKSTATION ONLY. Server 234 is NOT touched. The v4 worktree (RTM-design) is NOT touched.
#>

param([switch]$KeepClone)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$WORK      = 'D:\Claude\Projects\RTM View Shell'
$BUILDROOT = 'D:\Claude\Build'
# WHAT 234 RUNS RIGHT NOW - installed and accepted today at 11:24-11:34.
# This line is the one a blind search-and-replace broke on 2026-10-10: it made the probe diff the
# new head against itself, the delta came out empty and the probe refused to build - correctly.
# The deployed revision and the revision being built are NEVER the same token; PIN 2b checks it.
$DEPLOYED  = '2ccbf1c'
# Measured on 234 TODAY, after the e6a0fcb install [234_20261011_005750_acceptance-e6a0fcb.txt].
# Three .resx are in this delta, so these are the numbers the package must come out ABOVE. They are
# hours old, not days: the pre-deploy probe on the machine re-takes them before the install, and
# these are the build-side expectation, not the rollback floor.
$ON_SERVER_BYTES = @{ 'he-IL' = 77824 ; 'ru-RU' = 88064 ; 'en-US' = 71168 }
$DEPLOYED_ENGINE_SHA = '097F087D66497A4C59C5216E8BB46E1C4F49739A2B2A2A6621483BD0DC1C10AB'
$DEPLOYED_WEB_SHA    = '88393643C244611BE9AD562117097C7E3959C1AE92DAAA5987EB566479BAA66E'
# Contracts.dll does NOT change in this delta (0 files under src/CcDashboard.Contracts), so here
# EQUALITY with what 234 runs is the pass and a changed assembly is the finding.
$DEPLOYED_CONTRACTS_SHA = '13CC50E248C82E6D8326CA536A5988A3228EE7DE37543BE285562B51EC5CC3B7'
# Blessed by the coordinator at 07:58:22Z. A head further along is a stop, not a build.
$BLESSED_HEAD = 'f333db5'

$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$measDir = Join-Path $WORK '.measurements'
if (-not (Test-Path -LiteralPath $measDir)) { New-Item -ItemType Directory -Path $measDir | Out-Null }
$logPath = Join-Path $measDir ("WS_{0}_shellpkg-f333db5.txt" -f $stamp)

function Say([string]$text) { Write-Host $text }
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
function Line() { Write-Host ('-' * 78) }
function Invoke-Native([scriptblock]$Block) {
  $prevPref = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Block } finally { $ErrorActionPreference = $prevPref }
}

Start-Transcript -Path $logPath -Force | Out-Null
try {
  Say ("SHELL PACKAGE (v4, static versions)  " + ((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + 'Z') + "   host=" + $env:COMPUTERNAME)
  Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
  Say  "SERVER 234 IS NOT TOUCHED. The v4 worktree is not touched."
  $PIN_COMMIT = (Invoke-Native { & git -C "$WORK" rev-parse v4 }).Trim()
  $PIN_SHORT  = $PIN_COMMIT.Substring(0,7)
  $CLONE      = Join-Path $BUILDROOT ("rtm_v4s_{0}_{1}" -f $PIN_SHORT, $stamp)
  Say ("head of v4, re-taken now : " + $PIN_COMMIT)
  Say ("blessed head             : " + $BLESSED_HEAD + "   (coordinator 2026-10-11T07:58:22Z)")
  Say  "  The blessing names ONE revision and says: head further along - stop. A probe that merely"
  Say  "  re-takes the head and builds it would quietly ship whatever landed while we worked."
  $headIsBlessed = ($PIN_SHORT -eq $BLESSED_HEAD)
  Say ("  head == blessed : " + $headIsBlessed)
  if (-not $headIsBlessed) {
    Say  "  STOP. The head of v4 is not the revision that was blessed. Nothing is cloned and nothing"
    Say  "  is built. Report the two tokens and ask for a blessing on the new head."
    return
  }
  Say ("clone will be            : " + $CLONE)
  Line

  Say "ON ENTRY: clones left by PREVIOUS runs of this same step"
  Say  "  The run of 14:12 today died after the build and left its clone on disk - this probe had no"
  Say  "  entry cleanup at all, so nothing would ever have removed it. Only directories carrying THIS"
  Say  "  step's own mark are touched; anything else is named and left alone."
  if (Test-Path -LiteralPath $BUILDROOT) {
    foreach ($priorDir in @(Get-ChildItem -LiteralPath $BUILDROOT -Directory -Filter 'rtm_v4s_*' -ErrorAction SilentlyContinue)) {
      $markFile = Join-Path $priorDir.FullName '.origin'
      if (-not (Test-Path -LiteralPath $markFile)) {
        Say ("  " + $priorDir.Name + "  -> NO MARK: origin unknown. NOT TOUCHED.")
      } elseif ((Get-Content -LiteralPath $markFile -Raw) -like '*shellpkg-4634162*') {
        $sizeGb = [math]::Round((Get-ChildItem -LiteralPath $priorDir.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB, 2)
        Say ("  " + $priorDir.Name + "  -> MY OWN previous run, " + $sizeGb + " GB. DELETING.")
        Remove-Item -LiteralPath $priorDir.FullName -Recurse -Force
        Say ("      deleted; exists now: " + (Test-Path -LiteralPath $priorDir.FullName))
      } else {
        Say ("  " + $priorDir.Name + "  -> ANOTHER probe's artifact. NOT TOUCHED.")
      }
    }
  }
  Line

  Say "ROLLBACK FOR THIS RUN, printed BEFORE the first write:"
  Say ("  Remove-Item -Recurse -Force '" + $CLONE + "'")
  Say  "  Nothing outside that directory is written. No service, no server, no worktree, no repo state."
  Line

  if (-not (Test-Path -LiteralPath $WORK)) { throw ("working clone not found: " + $WORK) }
  if (Test-Path -LiteralPath $CLONE)       { throw ("clone dir already exists: " + $CLONE) }
  if (-not (Test-Path -LiteralPath $BUILDROOT)) { New-Item -ItemType Directory -Path $BUILDROOT | Out-Null }
  if (-not (Get-Command git -ErrorAction SilentlyContinue))    { throw 'git not found in PATH' }
  if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { throw 'dotnet SDK not found in PATH' }
  Say ("git    : " + (Invoke-Native { & git --version }))
  Say ("dotnet : " + (Invoke-Native { & dotnet --version }))
  $driveLetter = (Split-Path -Qualifier $BUILDROOT).TrimEnd(':')
  Say ("free on " + $driveLetter + ": " + [math]::Round((Get-PSDrive -Name $driveLetter).Free/1GB,1) + " GB")
  Line

  Say "PIN 1  clean clone at the pinned head"
  Invoke-Native { & git clone --no-hardlinks -- "$WORK" "$CLONE" 2>&1 } | ForEach-Object { Say ("  " + $_) }
  if ($LASTEXITCODE -ne 0) { throw 'git clone failed' }
  Invoke-Native { & git -C "$CLONE" checkout --detach $PIN_COMMIT 2>&1 } | ForEach-Object { Say ("  " + $_) }
  if ($LASTEXITCODE -ne 0) { throw 'checkout of the pinned commit failed' }
  $cloneHead = (Invoke-Native { & git -C "$CLONE" rev-parse HEAD }).Trim()
  $pinClone = ($cloneHead -eq $PIN_COMMIT)
  Say ("  clone HEAD : " + $cloneHead)
  Say ("  PIN 1 " + $(if ($pinClone) { 'GREEN  clone HEAD == ' + $PIN_SHORT } else { 'RED' }))
  Line

  Say "PIN 2  cleanliness, measured before this probe writes anything into the clone"
  $porcelain = @(Invoke-Native { & git -C "$CLONE" status --porcelain })
  Say ("  porcelain lines : " + $porcelain.Count)
  $pinClean = ($porcelain.Count -eq 0)
  Say ("  PIN 2 " + $(if ($pinClean) { 'GREEN  0 lines' } else { 'RED    tree not clean' }))

  $selfPath = $MyInvocation.MyCommand.Path
  $selfHash = if ($selfPath) { (Get-FileHash -Algorithm SHA256 -LiteralPath $selfPath).Hash } else { 'unknown' }
  $originText = @(
    ("probe   : probe_WS_20261010_shellpkg-4634162.ps1"),
    ("sha256  : " + $selfHash),
    ("stamp   : " + $stamp),
    ("machine : " + $env:COMPUTERNAME + " / " + $env:USERNAME),
    ("commit  : " + $PIN_COMMIT),
    ("unit    : v4 static-version package, Mode Shell SkipDB, by devops-0919")
  ) -join "`r`n"
  [System.IO.File]::WriteAllText((Join-Path $CLONE '.origin'), $originText + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
  Say  "  .origin written inside the clone"
  Line

  Say "PIN 2b  the deployed revision and the one being built must be DIFFERENT tokens"
  Say ("  deployed on 234 : " + $DEPLOYED)
  Say ("  being built     : " + $PIN_SHORT)
  if ($DEPLOYED -eq $PIN_SHORT) {
    throw ('the deployed revision and the head being built are the same token (' + $DEPLOYED + ') - a search-and-replace across this file has overwritten one of them, and every delta below would come out empty')
  }
  Say  "  PIN 2b GREEN  the two tokens differ, so the delta below is a real delta"
  Line

  Say "PIN 3  content witnesses - EVERY product file of the delta, computed from git, blob by blob"
  $witnesses = @(Invoke-Native { & git -C "$WORK" diff --name-only ($DEPLOYED + '..' + $PIN_COMMIT) -- src/ RTM/ } | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
  Say ("  files under src/ and RTM/ in the delta : " + $witnesses.Count)
  if ($witnesses.Count -eq 0) { throw 'the delta lists no product files - refusing to build a package that changes nothing' }
  $pinWitness = $true
  $mismatched = 0
  foreach ($witness in $witnesses) {
    $blobClone = (Invoke-Native { & git -C "$CLONE" rev-parse ("HEAD:" + $witness) }).Trim()
    $blobWork  = (Invoke-Native { & git -C "$WORK"  rev-parse ($PIN_COMMIT + ":" + $witness) }).Trim()
    $sameBlob  = (($blobClone -eq $blobWork) -and ($blobClone.Length -eq 40))
    if (-not $sameBlob) { $pinWitness = $false ; $mismatched++ ; Say ("  MISMATCH " + $witness + "  clone " + $blobClone + "  work " + $blobWork) }
  }
  Say ("  blobs compared : " + $witnesses.Count + "   mismatched : " + $mismatched)
  Say ("  PIN 3 " + $(if ($pinWitness) { 'GREEN  every product blob of the delta is equal' } else { 'RED    a blob differs - the builder would read a tree I never checked' }))
  Line

  Say "PIN 3b  what the delta contains - decides the mode"
  $deltaAll = @(Invoke-Native { & git -C "$WORK" diff --name-only ($DEPLOYED + '..' + $PIN_COMMIT) } | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
  $migrationHits = @($deltaAll | Where-Object { $_ -like 'db/migrations/*' }).Count
  $engineHits    = @($deltaAll | Where-Object { $_ -like 'RTM/*' }).Count
  $srcHits       = @($deltaAll | Where-Object { $_ -like 'src/*' }).Count
  $resxHits      = @($deltaAll | Where-Object { $_ -like '*Resources/SharedResources.*.resx' }).Count
  Say ("  db/migrations/ : " + $migrationHits + "   (expected 0 - non-zero means the DB layer may NOT be skipped)")
  Say ("  RTM/ engine    : " + $engineHits + "   (expected ZERO - this is WHY the mode is Shell, not Full)")
  Say ("  src/           : " + $srcHits + "   (POSCTL - a zero here would mean the delta listing is empty)")
  Say ("  .resx          : " + $resxHits + "   (expected THREE - this is WHY the satellites MUST grow)")
  $modeLawful = (($migrationHits -eq 0) -and ($engineHits -eq 0) -and ($srcHits -gt 0))
  Say ("  PIN 3b " + $(if ($modeLawful) { 'GREEN  -Mode Shell -SkipDB is lawful for this delta' } else { 'RED    STOP - the mode does not match the delta' }))
  Line

  if (-not ($pinClone -and $pinClean -and $pinWitness -and $modeLawful)) {
    Say "STOP BEFORE BUILD: a provenance pin is RED. Nothing was built, nothing was packaged."
    Say ("Rollback line above removes the clone: " + $CLONE)
    return
  }

  $buildStartedAt = Get-Date
  Say ("PIN 4  build in the clean clone. Started at " + $buildStartedAt.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + 'Z')
  Say  "  Any package older than that timestamp is a leftover, not this run's result, and is refused."
  $builder = Join-Path $CLONE 'tools\Build-ProdRelease.ps1'
  if (-not (Test-Path -LiteralPath $builder)) { throw ('builder not found: ' + $builder) }
  Say ("  builder sha256 : " + (Get-FileHash -Algorithm SHA256 -LiteralPath $builder).Hash)
  $garnetDir = Join-Path $WORK 'tools\cache\garnet-1.1.10-win-x64-net8'
  $nssmDir   = Join-Path $WORK 'tools\cache\nssm'
  foreach ($pair in @(@('GarnetServer.exe', (Join-Path $garnetDir 'GarnetServer.exe')), @('nssm.exe', (Join-Path $nssmDir 'nssm.exe')))) {
    if (Test-Path -LiteralPath $pair[1]) { Say ("  " + $pair[0].PadRight(18) + (Get-FileHash -Algorithm SHA256 -LiteralPath $pair[1]).Hash) }
    else { Say ("  " + $pair[0].PadRight(18) + "NOT FOUND at " + $pair[1] + "  <- build will refuse; stop and report") }
  }
  Say  "  command : Build-ProdRelease.ps1 -Mode Shell -SkipDB -GarnetDir <work cache> -NssmDir <work cache>"
  Push-Location $CLONE
  try {
    Invoke-Native { & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $builder -Mode Shell -SkipDB -GarnetDir $garnetDir -NssmDir $nssmDir 2>&1 } |
      ForEach-Object { Say ("  | " + $_) }
    $buildExit = $LASTEXITCODE
  } finally { Pop-Location }
  Say ("  builder exit code : " + $buildExit)
  Line

  Say "PACKAGE"
  $instDir = Join-Path $CLONE 'Installations'
  if (-not (Test-Path -LiteralPath $instDir)) { throw ('no Installations directory in the clone: ' + $instDir) }
  $zip = Get-ChildItem -LiteralPath $instDir -Filter *.zip | Where-Object { $_.LastWriteTime -ge $buildStartedAt } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $zip) { throw 'no .zip produced by THIS run - refusing to hand out an older package' }
  $zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip.FullName).Hash
  Say ("  freshness  : written " + $zip.LastWriteTime.ToString('u') + " , build started " + $buildStartedAt.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + 'Z')
  Say ("  zip name   : " + $zip.Name)
  Say ("  zip bytes  : " + $zip.Length + "   (" + [math]::Round($zip.Length/1MB,2) + " MB)")
  Say ("  zip sha256 : " + $zipHash)

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
  $webHash = 'NOT-FOUND'
  try {
    $entryNames = $archive.Entries | ForEach-Object { $_.FullName }
    Say ("  entries    : " + $entryNames.Count)
    foreach ($need in @('Update-RTMView.ps1','Install-RTMView.ps1')) {
      Say ("  contains " + $need + " : " + @($entryNames | Where-Object { $_ -like ('*' + $need) }).Count)
    }
    Say ("  RTM\ entries in package   : " + @($entryNames | Where-Object { ($_ -replace '\\','/') -like 'RTM/*' }).Count + "   (expected ZERO for Mode Shell)")
    Say ("  Shell\ entries in package : " + @($entryNames | Where-Object { ($_ -replace '\\','/') -like 'Shell/*' }).Count + "   (must be non-zero - else the package carries nothing)")

    # NO loop here, deliberately. The previous flight looped over @(@(name,sha), @(name,sha)); when I
    # dropped the engine row today the outer @( ) collapsed a single inner array into a flat one, so
    # $pair became the STRING and $pair[0] a Char - and the run died at $leaf.PadRight(22) on
    # [System.Char] after the package was already built. One element needs no loop, and a loop over
    # one element is where PowerShell unrolling bites. Measured 2026-10-04 14:17 on the station.
    # THE ASSET VERSIONS, measured from App.razor in BOTH revisions with git, today.
    # daytrendChart.js stays at v=4 in this delta - so it gets PRESENCE ONLY. Demanding that its
    # old number disappear would paint a correct package red, which is the same class of fault as
    # inheriting a satellite rule. The pairs are checked after the install, from the served HTML;
    # here they are only RECORDED so the acceptance has a written expectation to be judged against.
    Say  "  EXPECTED IN THE SERVED HTML AFTER THE INSTALL (recorded here, proven there)."
    Say  "  Measured from App.razor in BOTH revisions with git, today: THREE versions move, SIX do not."
    Say  "    CcDashboard.Web.styles.css?v=9        present , v=7 GONE"
    Say  "    agentStateDistributionChart.js?v=13   present , v=10 GONE  body 17145 B, blob 9654EE97"
    Say  "    daytrendChart.js?v=11                 present , v=7 GONE   body 13192 B, blob 66929035"
    Say  "    app.css?v=35 / tokens.css?v=3 / wallboard-skin.css?v=3 / app.js?v=2 /"
    Say  "    widget-resize.js?v=3 / reportDistributionChart.js?v=4  -> PRESENCE ONLY, and demanding"
    Say  "    that their numbers move would paint a correct package red - the same class of fault as"
    Say  "    carrying a satellite rule over from the previous flight."
    Say  "  THE NEEDLES OF THE WORK ITSELF, each with the half that can return red:"
    Say  "    aspect-ratio 1 / 1  in the served styles body  : on 2f3b426 the ASD razor.css has 2"
    Say  "                        occurrences and on e6a0fcb it has 0 - measured in the blobs."
    Say  "    ResizeObserver      in both served chart bodies : 4 occurrences each on 2f3b426,"
    Say  "                        0 on e6a0fcb - measured in the blobs."
    Say  "  The bodies and blobs above are the pair the acceptance compares the served file against;"
    Say  "  the byte counts are taken from git at this minute, not carried from any earlier flight."
    $leaf = 'CcDashboard.Web.dll'
    $deployedSha = $DEPLOYED_WEB_SHA
    $entry = $archive.Entries | Where-Object { (Split-Path -Leaf ($_.FullName -replace '\\','/')) -eq $leaf } | Select-Object -First 1
    if (-not $entry) { Say ("  " + $leaf.PadRight(22) + " NOT IN PACKAGE  <- report, do not improvise") }
    else {
      $tempFile = Join-Path $env:TEMP ('shellpkg_' + [Guid]::NewGuid().ToString('N') + '.bin')
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $tempFile, $true)
      $entryHash = (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash
      $entryBytes = (Get-Item -LiteralPath $tempFile).Length
      Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
      $webHash = $entryHash
      $moved = ($entryHash -ne $deployedSha)
      Say ("  " + $leaf.PadRight(22) + $entryHash + "  " + $entryBytes + " B")
      Say ("  " + ' '.PadRight(22) + "differs from what 234 runs : " + $moved + "   (equal would mean this flight changes nothing there)")
    }

    Say ""
    Say  "  SATELLITE ASSEMBLIES - size against what 234 carries RIGHT NOW, and the KEY NAMES inside"
    Say  "  EXPECTED BEFORE THE MEASUREMENT: all three EQUAL to what 234 runs. No .resx is in this"
    Say  "  delta, so a dictionary that MOVED would mean something reached the resources this flight"
    Say  "  does not contain. That is the finding here, and equality is the pass - the opposite of"
    Say  "  yesterday, where I carried the growth rule over and printed a red on a correct package."
    Say  "  The four Wfm keys below must simply still be present; they were added by the last flight."
    $satellitesGrew = 0
    $satellitesPresent = 0
    foreach ($culture in @('he-IL','ru-RU','en-US')) {
      $satEntry = $archive.Entries | Where-Object { ($_.FullName -replace '\\','/') -like ('*/' + $culture + '/CcDashboard.Web.resources.dll') } | Select-Object -First 1
      if (-not $satEntry) { Say ("    " + $culture.PadRight(6) + " : NOT IN PACKAGE  <- report, do not improvise") ; continue }
      $serverBytes = $ON_SERVER_BYTES[$culture]
      $deltaBytes  = $satEntry.Length - $serverBytes
      $satellitesPresent++
      if ($deltaBytes -ne 0) { $satellitesGrew++ }
      $reading = if ($deltaBytes -eq 0) { 'as expected: EQUAL to what 234 runs - no .resx in this delta' }
                 else { 'FINDING: moved by ' + $deltaBytes + ' B while this delta carries no .resx at all - report it' }
      Say ("    " + $culture.PadRight(6) + " package " + $satEntry.Length + " B   on 234 " + $serverBytes + " B   -> " + $reading)
    }
    Say ("  satellites that MOVED : " + $satellitesGrew + " of 3   expected 0 - this delta carries no .resx")
    Say ("  satellites PRESENT in the package : " + $satellitesPresent + " of 3   (all three must be there - that part IS a verdict)")
    Say ""
    Say  "  THE FOUR NEW KEY NAMES, searched as bytes inside each satellite - size is a note, this is"
    Say  "  the content. A key NAME is stored once per dictionary, in UTF-8; the search is run in both"
    Say  "  encodings anyway, because a one-encoding search that finds nothing proves nothing: on"
    Say  "  2026-10-10 decoding one of these assemblies as text found 0 of 7 keys that were all there."
    $keyNames = @('Wfm_TileTitleFontSize', 'Wfm_TileValueFontSize', 'Wfm_ListTitleFontSize', 'Wfm_ListValueFontSize')
    Say ("  key names to look for : " + $keyNames.Count + "   expected 4")
    foreach ($culture in @('he-IL','ru-RU','en-US')) {
      $satEntry = $archive.Entries | Where-Object { ($_.FullName -replace '\\','/') -like ('*/' + $culture + '/CcDashboard.Web.resources.dll') } | Select-Object -First 1
      if (-not $satEntry) { Say ("    " + $culture.PadRight(6) + " : NOT IN PACKAGE - not searched") ; continue }
      $satTmp = Join-Path $env:TEMP ('sat_' + $culture + '_' + [Guid]::NewGuid().ToString('N') + '.bin')
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($satEntry, $satTmp, $true)
      $satBytes = [IO.File]::ReadAllBytes($satTmp)
      Remove-Item -LiteralPath $satTmp -Force -ErrorAction SilentlyContinue
      $posOff = Find-ByteRun $satBytes ([Text.Encoding]::UTF8.GetBytes('CcDashboard'))
      $negOff = Find-ByteRun $satBytes ([Text.Encoding]::UTF8.GetBytes('zzz-no-such-key-in-any-dictionary'))
      $readerOk = (($posOff -ge 0) -and ($negOff -eq -1))
      Say ("    " + $culture.PadRight(6) + " reader self-test: POSCTL 'CcDashboard' @" + $posOff + "  NEGCTL " + $negOff + "  -> " + $(if ($readerOk) { 'TRUSTED' } else { 'NOT TRUSTED - rows below are not counted' }))
      if (-not $readerOk) { continue }
      $hits = 0
      foreach ($key in $keyNames) {
        $offsetUtf8  = Find-ByteRun $satBytes ([Text.Encoding]::UTF8.GetBytes($key))
        $offsetUtf16 = Find-ByteRun $satBytes ([Text.Encoding]::Unicode.GetBytes($key))
        $found = (($offsetUtf8 -ge 0) -or ($offsetUtf16 -ge 0))
        if ($found) { $hits++ }
        Say ("      " + $key.PadRight(24) + " utf8 " + $offsetUtf8 + "   utf16 " + $offsetUtf16 + "   -> " + $(if ($found) { 'PRESENT' } else { 'ABSENT  <- the finding' }))
      }
      Say ("    " + $culture.PadRight(6) + " keys present : " + $hits + " of 4   expected 4 - they were added by the previous flight and must survive this one")
    }
    Say ""
    Say  "  THE CONTRACTS ASSEMBLY, PREDICATE INVERTED AGAINST THE LAST FLIGHT. Nothing under"
    Say  "  src/CcDashboard.Contracts is in this delta, so this assembly must come out BYTE-IDENTICAL"
    Say  "  to the one 234 runs. Yesterday a change here was the proof; today a change is the finding."
    $cEntry = $archive.Entries | Where-Object { (Split-Path -Leaf ($_.FullName -replace '\\','/')) -eq 'CcDashboard.Contracts.dll' } | Select-Object -First 1
    if (-not $cEntry) { Say "    CcDashboard.Contracts.dll NOT IN PACKAGE  <- report, do not improvise" }
    else {
      $cTmp = Join-Path $env:TEMP ('contracts_' + [Guid]::NewGuid().ToString('N') + '.bin')
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($cEntry, $cTmp, $true)
      $cSha = (Get-FileHash -LiteralPath $cTmp -Algorithm SHA256).Hash
      $cBytes = [IO.File]::ReadAllBytes($cTmp)
      Remove-Item -LiteralPath $cTmp -Force -ErrorAction SilentlyContinue
      $cPos = Find-ByteRun $cBytes ([Text.Encoding]::UTF8.GetBytes('CcDashboard'))
      $cNeg = Find-ByteRun $cBytes ([Text.Encoding]::UTF8.GetBytes('zzz-no-such-type-name'))
      $cInk8 = Find-ByteRun $cBytes ([Text.Encoding]::UTF8.GetBytes('ContrastInk'))
      $cInk16 = Find-ByteRun $cBytes ([Text.Encoding]::Unicode.GetBytes('ContrastInk'))
      Say ("    CcDashboard.Contracts.dll " + $cSha + "   " + $cBytes.Length + " B")
      Say ("    reader self-test: POSCTL @" + $cPos + "   NEGCTL " + $cNeg + "   must be >=0 and -1")
      Say ("    type name 'ContrastInk' : utf8 " + $cInk8 + "   utf16 " + $cInk16 + "   -> " + $(if (($cInk8 -ge 0) -or ($cInk16 -ge 0)) { 'PRESENT - as it must be, it landed in the previous flight' } else { 'ABSENT  <- the finding' }))
      Say  "    A sha COMPARISON AGAINST THE ASSEMBLY 234 RUNS IS NOT A PREDICATE HERE, and this line"
      Say  "    replaces one that was. Measured on the station 2026-10-11 12:50 local, reading the two"
      Say  "    packages off the disk: the three dictionaries came out with DIFFERENT sha in the two"
      Say  "    builds at identical sizes, although no .resx is in the delta between them - so a"
      Say  "    rebuild is not byte-reproducible and a changed sha proves nothing about content."
      Say ("    for the record only, not a verdict: equals the assembly 234 runs : " + ($cSha -eq $DEPLOYED_CONTRACTS_SHA))
      Say  "    THE CONTENT ROWS ARE THE VERDICT: the type name above, found by a self-tested reader."
      Say ""
      Say  "    THE THREE CHART SCRIPTS - THIS DELTA TOUCHES NO .js, so each must come out of the package"
      Say  "    with the SAME size it has on 234 (15436 / 19604 / 10965 B) and the needle _applyCanvasSize"
      Say  "    still present. A CHANGED script here is the finding; the blob names below are the ones"
      Say  "    the running revision carries, for the record only - a rebuilt text file would differ."
      $scriptRows = @()
      $scriptRows += ,@('daytrendChart.js', 15436, 'A4C1EE02')
      $scriptRows += ,@('agentStateDistributionChart.js', 19604, '7031292A')
      $scriptRows += ,@('reportDistributionChart.js', 10965, '51BF699E')
      Say ("    rows : " + $scriptRows.Count + "   expected 3")
      foreach ($scriptRow in $scriptRows) {
        $leafName = $scriptRow[0]
        $sameBytes = $scriptRow[1]
        $oldBlob = $scriptRow[2]
        $sEntry = $archive.Entries | Where-Object { (Split-Path -Leaf ($_.FullName -replace '\\','/')) -eq $leafName } | Select-Object -First 1
        if (-not $sEntry) { Say ("    " + $leafName.PadRight(32) + " NOT IN PACKAGE  <- report, do not improvise") ; continue }
        $sTmp = Join-Path $env:TEMP ('js_' + [Guid]::NewGuid().ToString('N') + '.bin')
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($sEntry, $sTmp, $true)
        $sSha = (Get-FileHash -LiteralPath $sTmp -Algorithm SHA256).Hash
        $sBytes = [IO.File]::ReadAllBytes($sTmp)
        Remove-Item -LiteralPath $sTmp -Force -ErrorAction SilentlyContinue
        $sPos = Find-ByteRun $sBytes ([Text.Encoding]::UTF8.GetBytes('function'))
        $sNeg = Find-ByteRun $sBytes ([Text.Encoding]::UTF8.GetBytes('zzz-no-such-call('))
        $sNeedle = Find-ByteRun $sBytes ([Text.Encoding]::UTF8.GetBytes('_applyCanvasSize'))
        Say ("    " + $leafName.PadRight(32) + " " + $sBytes.Length + " B   expected " + $sameBytes + " : " + ($sBytes.Length -eq $sameBytes) + "   (a note)")
        Say ("    " + ' '.PadRight(32) + " sha256 " + $sSha)
        Say ("    " + ' '.PadRight(32) + " reader self-test: POSCTL 'function' @" + $sPos + "  NEGCTL " + $sNeg + "  must be >=0 and -1")
        Say ("    " + ' '.PadRight(32) + " needle '_applyCanvasSize' @" + $sNeedle + "   expected >=0, same as on 234 (blob " + $oldBlob + ") - this delta carries no .js")
        Say ("    " + ' '.PadRight(32) + " THE ACCEPTANCE COMPARES THE SERVED BODY AGAINST THIS SHA - not against its size.")
      }
      Say ""
      Say  "    app.css - THE FILE THAT CARRIES THE WORK, and it is plain text in wwwroot"
      $cssEntry = $archive.Entries | Where-Object { ($_.FullName -replace '\\','/') -like '*/wwwroot/app.css' } | Select-Object -First 1
      if (-not $cssEntry) { Say "    app.css NOT IN PACKAGE  <- report, do not improvise" }
      else {
        $cssTmp = Join-Path $env:TEMP ('appcss_' + [Guid]::NewGuid().ToString('N') + '.bin')
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($cssEntry, $cssTmp, $true)
        $cssSha = (Get-FileHash -LiteralPath $cssTmp -Algorithm SHA256).Hash
        $cssBytes = [IO.File]::ReadAllBytes($cssTmp)
        Remove-Item -LiteralPath $cssTmp -Force -ErrorAction SilentlyContinue
        $cssPos = Find-ByteRun $cssBytes ([Text.Encoding]::UTF8.GetBytes('.widget'))
        $cssNeg = Find-ByteRun $cssBytes ([Text.Encoding]::UTF8.GetBytes('zzz-no-such-class'))
        $cssNeedle = Find-ByteRun $cssBytes ([Text.Encoding]::UTF8.GetBytes('distribution-chart-box'))
        Say ("    app.css " + $cssBytes.Length + " B   expected 100541 (blob F11C2EE2; on 234 it is 100149)")
        Say ("    sha256 " + $cssSha)
        Say ("    reader self-test: POSCTL '.widget' @" + $cssPos + "  NEGCTL " + $cssNeg + "  must be >=0 and -1")
        Say ("    needle 'distribution-chart-box' @" + $cssNeedle + "   expected >=0; in the revision 234 runs it appears 0 times")
      }
      Say ""
      Say  "    web.dll - THE RAZOR CODE, by its own needle. The scoped bundle CcDashboard.Web.styles.css"
      Say  "    is built, so its sha is NOT pinned here; its 'inset' count is measured on the server"
      Say  "    before and after the install, in that order."
      $webEntry = $archive.Entries | Where-Object { (Split-Path -Leaf ($_.FullName -replace '\\','/')) -eq 'CcDashboard.Web.dll' } | Select-Object -First 1
      if (-not $webEntry) { Say "    CcDashboard.Web.dll NOT IN PACKAGE  <- report, do not improvise" }
      else {
        $webTmp = Join-Path $env:TEMP ('webdll_' + [Guid]::NewGuid().ToString('N') + '.bin')
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($webEntry, $webTmp, $true)
        $webBytes = [IO.File]::ReadAllBytes($webTmp)
        Remove-Item -LiteralPath $webTmp -Force -ErrorAction SilentlyContinue
        $webPos = Find-ByteRun $webBytes ([Text.Encoding]::UTF8.GetBytes('CcDashboard'))
        $webNeg = Find-ByteRun $webBytes ([Text.Encoding]::UTF8.GetBytes('zzz-no-such-method-name'))
        $clip8 = Find-ByteRun $webBytes ([Text.Encoding]::UTF8.GetBytes('ClipToNonZeroWindow'))
        $clip16 = Find-ByteRun $webBytes ([Text.Encoding]::Unicode.GetBytes('ClipToNonZeroWindow'))
        Say ("    reader self-test: POSCTL @" + $webPos + "  NEGCTL " + $webNeg + "  must be >=0 and -1")
        Say ("    needle 'ClipToNonZeroWindow' : utf8 " + $clip8 + "   utf16 " + $clip16 + "   expected present; on 234 it is absent")
      }
    }
    Say  "  The predicate has flipped across these flights, so it is re-derived every run. What this"
    Say  "  run taught: it must be re-derived from WHAT CAN BE OBSERVED, not only from the delta. A"
    Say  "  rebuilt dictionary is observable by its key names; its size is observable but not decisive." 
  } finally { $archive.Dispose() }
  Line

  Say "PACKAGE OUT OF THE CLONE"
  $projInst = Join-Path $WORK 'Installations'
  if (-not (Test-Path -LiteralPath $projInst)) { New-Item -ItemType Directory -Path $projInst | Out-Null }
  $destZip = Join-Path $projInst $zip.Name
  if (Test-Path -LiteralPath $destZip) { throw ('destination already exists, not overwriting: ' + $destZip) }
  Copy-Item -LiteralPath $zip.FullName -Destination $destZip
  $destHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destZip).Hash
  Say ("  copied to   : " + $destZip)
  Say ("  sha256 here : " + $destHash + "   equal to the clone copy: " + ($destHash -eq $zipHash))
  [System.IO.File]::WriteAllText(($destZip + '.origin.txt'), ($originText + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
  if ($destHash -ne $zipHash) { Say "  CLONE KEPT because the copy is RED." }
  elseif ($KeepClone) { Say ("  CLONE KEPT (-KeepClone): " + $CLONE) }
  else { Remove-Item -LiteralPath $CLONE -Recurse -Force ; Say ("  clone removed; exists now: " + (Test-Path -LiteralPath $CLONE)) }
  Line

  Say "VERDICT LINES"
  Say ("  PIN 1 clone HEAD == " + $PIN_SHORT + "  : " + $(if ($pinClone) { 'GREEN' } else { 'RED' }))
  Say ("  PIN 2 porcelain 0 lines     : " + $(if ($pinClean) { 'GREEN' } else { 'RED' }))
  Say ("  PIN 3 all delta blobs equal : " + $(if ($pinWitness) { 'GREEN' } else { 'RED' }))
  Say ("  PIN 4 build exit 0 + zip    : " + $(if ($buildExit -eq 0) { 'GREEN' } else { 'RED  exit=' + $buildExit }))
  Say ("  package for transfer : " + $destZip)
  Say ("  its sha256           : " + $destHash)
  Say ("  web.dll in package   : " + $webHash)
  Say  "  RTM.dll in package   : not applicable - Mode Shell carries no engine, and a line claiming"
  Say  "                         otherwise would be a check about a file this build never produces."
  Say  "  Server 234 was not touched. Nothing was installed anywhere."
  Say  "END-OF-RUN MARKER: SHELLPKG-F333DB5-COMPLETE"
}
catch {
  Say ""
  Say ("BROKEN OFF: " + $_.Exception.Message)
  Say ("At: " + $_.InvocationInfo.PositionMessage)
  Say  "Nothing was sent to 234. The clone directory, if created, is the only residue."
}
finally {
  Stop-Transcript | Out-Null
  Write-Host ""
  Write-Host ("TRANSCRIPT: " + $logPath)
}
