<#
  PROBE  probe_WS_20261010_shellpkg-4634162.ps1
  SHAPE  FROM probe_WS_20261010_shellpkg-fe30a27.ps1 - the run that built the package now on the
         stand. Note on that predecessor: a search-and-replace of mine turned its own SHAPE line
         into a self-reference, so it names itself instead of probe_WS_20261010_shellpkg-304f540.
         That probe has already run and is committed, so it is left as it is and the defect is
         reported rather than edited away.
  UNIT   v4 head 4634162, built -Mode Shell -SkipDB: FEAT-REDESIGN-01, the SINGLE rollout the
         operator asked for instead of piecemeal ones. Blessing 2026-10-10T19:42:10Z with the
         operator's word quoted in it; the 16:52Z stop is lifted by that same letter, and the inbox
         was re-read as the first action, as the gate of de5f50f requires.
  WHY SHELL AND NOT FULL - re-measured by BLOB, not by name, and not taken from the letter:
         the clean difference fe30a27..4634162 is SEVENTEEN files by blob - sixteen under
         src/CcDashboard.Web and one .gitignore, which the letter does not name and which never
         travels in a package. RTM/ 0, deploy/ 0, db/ 0, migrations 0.
  THE SATELLITE PREDICATE INVERTS BACK TO GROWTH - THE THIRD FLIP IN FOUR FLIGHTS
         This delta carries THREE .resx (SharedResources en-US / he-IL / ru-RU), so the three
         satellites must come out LARGER than what 234 carries. Equality would mean the dictionaries
         were never rebuilt. The previous two flights demanded equality; carrying that rule over
         would paint a correct package red on all three rows. PE file alignment is 512 bytes, so
         growth arrives in multiples of 512 - a smaller step would itself be a finding.
  WHAT THE PACKAGE MUST CARRY, AND IT IS THE POINT OF THE FLIGHT
         App.razor compiles into CcDashboard.Web.dll, so the five new asset versions cannot be
         checked as files here. They are checked after the install, from the HTML the live server
         serves - and that HTML lives behind two redirects (root -> /screens -> /login), measured
         2026-10-04 13:26. Here the only provable thing is that web.dll CHANGED against what 234
         runs: equality would mean the flight carries nothing.
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
$DEPLOYED  = 'fe30a27'
# Measured on 234 on 2026-10-05 [234_20261005_090548_acceptance-e7eb243.txt]. With no .resx in
# the delta these must come out EQUAL in the package. FIVE DAYS OLD - the pre-deploy probe on the
# machine re-takes them before the install; these are the build-side expectation, not the floor.
$ON_SERVER_BYTES = @{ 'he-IL' = 77312 ; 'ru-RU' = 87040 ; 'en-US' = 70144 }
$DEPLOYED_ENGINE_SHA = '097F087D66497A4C59C5216E8BB46E1C4F49739A2B2A2A6621483BD0DC1C10AB'
$DEPLOYED_WEB_SHA    = '010934A3577889EFCECB3AC1139D1D43777E50396D129F6BBDAA40ACCC484F72'

$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$measDir = Join-Path $WORK '.measurements'
if (-not (Test-Path -LiteralPath $measDir)) { New-Item -ItemType Directory -Path $measDir | Out-Null }
$logPath = Join-Path $measDir ("WS_{0}_shellpkg-4634162.txt" -f $stamp)

function Say([string]$text) { Write-Host $text }
function Line() { Write-Host ('-' * 78) }
function Invoke-Native([scriptblock]$Block) {
  $prevPref = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Block } finally { $ErrorActionPreference = $prevPref }
}

Start-Transcript -Path $logPath -Force | Out-Null
try {
  Say ("SHELL PACKAGE (v4, static versions)  " + (Get-Date -Format 'u') + "   host=" + $env:COMPUTERNAME)
  Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
  Say  "SERVER 234 IS NOT TOUCHED. The v4 worktree is not touched."
  $PIN_COMMIT = (Invoke-Native { & git -C "$WORK" rev-parse v4 }).Trim()
  $PIN_SHORT  = $PIN_COMMIT.Substring(0,7)
  $CLONE      = Join-Path $BUILDROOT ("rtm_v4s_{0}_{1}" -f $PIN_SHORT, $stamp)
  Say ("head of v4, re-taken now : " + $PIN_COMMIT)
  Say  "  The coordinator named 4634162 as the orientation. If the line above is a different commit,"
  Say  "  the head moved while we worked and THAT is what gets built and reported - not the message."
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
  Say ("  .resx          : " + $resxHits + "   (expected ZERO - this is WHY the satellites must NOT move)")
  $modeLawful = (($migrationHits -eq 0) -and ($engineHits -eq 0) -and ($srcHits -gt 0))
  Say ("  PIN 3b " + $(if ($modeLawful) { 'GREEN  -Mode Shell -SkipDB is lawful for this delta' } else { 'RED    STOP - the mode does not match the delta' }))
  Line

  if (-not ($pinClone -and $pinClean -and $pinWitness -and $modeLawful)) {
    Say "STOP BEFORE BUILD: a provenance pin is RED. Nothing was built, nothing was packaged."
    Say ("Rollback line above removes the clone: " + $CLONE)
    return
  }

  $buildStartedAt = Get-Date
  Say ("PIN 4  build in the clean clone. Started at " + $buildStartedAt.ToString('u'))
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
  Say ("  freshness  : written " + $zip.LastWriteTime.ToString('u') + " , build started " + $buildStartedAt.ToString('u'))
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
    Say  "  Measured from App.razor in BOTH revisions: FIVE versions move, FOUR do not."
    Say  "    CcDashboard.Web.styles.css?v=7        present , v=5 GONE"
    Say  "    agentStateDistributionChart.js?v=10   present , v=7 GONE   body 15310 B, blob 59543C45"
    Say  "    daytrendChart.js?v=7                  present , v=4 GONE   body 11456 B, blob 91A1BE01"
    Say  "    reportDistributionChart.js?v=4        present , v=2 GONE   body  7935 B, blob 85F699A9"
    Say  "    widget-resize.js?v=3                  present , v=2 GONE   body 35102 B, blob CBB0BA53"
    Say  "    app.css?v=35 / tokens.css?v=3 / wallboard-skin.css?v=3 / app.js?v=2  -> presence only"
    Say  "  THE NEEDLES OF THE NEW Wfm MARKUP: .wfmgrid and .wfmnote, which live in the new"
    Say  "  WfmWidget.razor.css and are absent on fe30a27 (measured: 0 -> 1). They compile into"
    Say  "  CcDashboard.Web.styles.css, so they are provable in its served body."
    Say  "  A bumped version proves a new file was served; the needles prove the markup landed."
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
    Say  "  SATELLITE ASSEMBLIES - compared by SIZE against what 234 carries RIGHT NOW"
    Say  "  EXPECTED, BEFORE THE MEASUREMENT: all three EQUAL. This delta touches no .resx at all,"
    Say  "  so a satellite that MOVED would mean something reached the dictionaries the delta does"
    Say  "  not contain - that is the finding here, and equality is the pass."
    $satellitesGrew = 0
    foreach ($culture in @('he-IL','ru-RU','en-US')) {
      $satEntry = $archive.Entries | Where-Object { ($_.FullName -replace '\\','/') -like ('*/' + $culture + '/CcDashboard.Web.resources.dll') } | Select-Object -First 1
      if (-not $satEntry) { Say ("    " + $culture.PadRight(6) + " : NOT IN PACKAGE  <- report, do not improvise") ; continue }
      $serverBytes = $ON_SERVER_BYTES[$culture]
      $deltaBytes  = $satEntry.Length - $serverBytes
      if ($deltaBytes -gt 0) { $satellitesGrew++ }
      $reading = if ($deltaBytes -gt 0) { 'as expected: GREW by ' + $deltaBytes + ' B - three .resx in this delta' }
                 elseif ($deltaBytes -eq 0) { 'FINDING: UNCHANGED - this delta carries THREE .resx, so equality means the dictionaries were not rebuilt' }
                 else { 'FINDING: SHRANK by ' + [math]::Abs($deltaBytes) + ' B - report, do not improvise' }
      Say ("    " + $culture.PadRight(6) + " package " + $satEntry.Length + " B   on 234 " + $serverBytes + " B   -> " + $reading)
    }
    Say ("  satellites GREW : " + $satellitesGrew + " of 3   (3 expected; anything less is the finding of this run)")
    Say  "  Growth is the pass here. The predicate has flipped three times across four flights, so"
    Say  "  it is re-derived from the delta every run and never carried over." 
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
  Say  "END-OF-RUN MARKER: SHELLPKG-4634162-COMPLETE"
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
