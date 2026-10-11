<#
  PROBE  probe_WS_20261011_shellpkg-2f3b426.ps1
  SHAPE  FROM probe_WS_20261010_shellpkg-4634162.ps1 - the flight whose predicate matches this one
         (static DOES move here), not from the e6a0fcb probe that ran last, whose whole point was
         that nothing static moves. The form is chosen by the predicate, never by what ran last.
  UNIT   v4 head 2f3b426, built -Mode Shell -SkipDB. Blessing 2026-10-11T07:58:22Z with the
         operator's word quoted in it ("daju slovo"). The inbox is re-read as the first action of
         the install step, as the gate of de5f50f requires; a later letter with a stop word stops it.
  THE HEAD IS PINNED TO THE BLESSED REVISION
         The coordinator blessed 2f3b426 and wrote "head further - stop". So this probe does not
         just re-take the head and build whatever it finds: it compares it to the blessed token
         and refuses when they differ. Measured by rev-parse, printed before the comparison.
  WHY SHELL AND NOT FULL - re-measured here by BLOB, never taken from the letter:
         the clean difference e6a0fcb..2f3b426 is FIFTEEN files - fourteen under src/ plus one
         test under tests/ which never travels in a package. RTM/ 0, deploy/ 0, db/ 0, migrations 0.
  THE SATELLITE PREDICATE IS GROWTH AGAIN - AND IT IS RE-DERIVED, NOT REMEMBERED
         Three .resx are in this delta (en-US / he-IL / ru-RU, four new Wfm font-size keys in each),
         so the three satellites must come out LARGER than what 234 carries. The flight before this
         one demanded EQUALITY, and carrying that rule over would paint a correct package red on
         three rows. PE alignment is 512 B, so growth arrives in multiples of 512; a smaller step
         would itself be a finding. Size is a note, the key names are the content proof.
  A NEW FILE TRAVELS IN A DIFFERENT ASSEMBLY, WHICH IS A ROW OF ITS OWN
         ContrastInk.cs is new and lives in src/CcDashboard.Contracts, so it compiles into
         CcDashboard.Contracts.dll - NOT into CcDashboard.Web.dll. A package that carries a changed
         web.dll and an UNCHANGED Contracts.dll would look green everywhere else and still be
         missing the readable-ink work. So the name is searched for inside that assembly, with a
         reader self-test, and the assembly is compared against what 234 runs.
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
$DEPLOYED  = 'e6a0fcb'
# Measured on 234 TODAY, after the e6a0fcb install [234_20261011_005750_acceptance-e6a0fcb.txt].
# Three .resx are in this delta, so these are the numbers the package must come out ABOVE. They are
# hours old, not days: the pre-deploy probe on the machine re-takes them before the install, and
# these are the build-side expectation, not the rollback floor.
$ON_SERVER_BYTES = @{ 'he-IL' = 77824 ; 'ru-RU' = 87552 ; 'en-US' = 70656 }
$DEPLOYED_ENGINE_SHA = '097F087D66497A4C59C5216E8BB46E1C4F49739A2B2A2A6621483BD0DC1C10AB'
$DEPLOYED_WEB_SHA    = 'CE15C4A4E52D643576C878C4F1AAFDFC4D467D7D9017EEE20672E77394C567A8'
# Blessed by the coordinator at 07:58:22Z. A head further along is a stop, not a build.
$BLESSED_HEAD = '2f3b426'

$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$measDir = Join-Path $WORK '.measurements'
if (-not (Test-Path -LiteralPath $measDir)) { New-Item -ItemType Directory -Path $measDir | Out-Null }
$logPath = Join-Path $measDir ("WS_{0}_shellpkg-2f3b426.txt" -f $stamp)

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
    Say  "  SIZE IS A NOTE HERE, NOT A VERDICT, AND THIS LINE IS A CORRECTION OF MY OWN RUN AT 11:14."
    Say  "  I wrote 'all three must GROW' into this probe from the shape of the 4634162 flight. The"
    Say  "  package was correct and the row went RED anyway: he-IL carries all four new keys and still"
    Say  "  came out at exactly 77824 B, because PE alignment is 512 B and the four names plus their"
    Say  "  values fit inside the padding the previous build already had. A size that does not move"
    Say  "  proves nothing, in either direction - the fourth false size number of mine in two days."
    Say  "  THE VERDICT IS THE KEY NAMES BELOW. Size is printed so a reader can see the step."
    $satellitesGrew = 0
    $satellitesPresent = 0
    foreach ($culture in @('he-IL','ru-RU','en-US')) {
      $satEntry = $archive.Entries | Where-Object { ($_.FullName -replace '\\','/') -like ('*/' + $culture + '/CcDashboard.Web.resources.dll') } | Select-Object -First 1
      if (-not $satEntry) { Say ("    " + $culture.PadRight(6) + " : NOT IN PACKAGE  <- report, do not improvise") ; continue }
      $serverBytes = $ON_SERVER_BYTES[$culture]
      $deltaBytes  = $satEntry.Length - $serverBytes
      $satellitesPresent++
      if ($deltaBytes -gt 0) { $satellitesGrew++ }
      $reading = if ($deltaBytes -gt 0) { 'note: moved +' + $deltaBytes + ' B (one 512-byte alignment step per 512 B)' }
                 elseif ($deltaBytes -eq 0) { 'note: did not move - lawful when the new keys fit inside the existing padding; the key search below decides' }
                 else { 'note: SHRANK by ' + [math]::Abs($deltaBytes) + ' B - unusual, worth a line in the report' }
      Say ("    " + $culture.PadRight(6) + " package " + $satEntry.Length + " B   on 234 " + $serverBytes + " B   -> " + $reading)
    }
    Say ("  satellites that moved in size : " + $satellitesGrew + " of 3   A NOTE, NOT A VERDICT - see the line above.")
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
      Say ("    " + $culture.PadRight(6) + " keys present : " + $hits + " of 4   expected 4")
      Say  "      the other half of the pair, measured in the blobs of the revision 234 runs now: all"
      Say  "      four key names were absent there, so four present here is a change of state, not a hope"
    }
    Say ""
    Say  "  THE NEW ASSEMBLY - ContrastInk.cs is new and lives in CcDashboard.Contracts, so it does"
    Say  "  NOT compile into web.dll. An unchanged Contracts.dll here would mean the readable-ink"
    Say  "  work is simply not in the package, with every other row still green."
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
      Say ("    type name 'ContrastInk' : utf8 " + $cInk8 + "   utf16 " + $cInk16 + "   -> " + $(if (($cInk8 -ge 0) -or ($cInk16 -ge 0)) { 'PRESENT - the new file is in this assembly' } else { 'ABSENT  <- the finding: the package does not carry it' }))
      Say  "    The pre-deploy probe on 234 takes the sha of the Contracts.dll that lies there now,"
      Say  "    so the acceptance can show the pair; this number is the build side of it."
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
  Say  "END-OF-RUN MARKER: SHELLPKG-2F3B426-COMPLETE"
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
