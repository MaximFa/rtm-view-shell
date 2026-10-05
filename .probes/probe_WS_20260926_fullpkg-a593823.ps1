<#
  PROBE  probe_WS_20260926_fullpkg-a593823.ps1
  SHAPE  FROM probe_WS_20260920_shellpkg-step4.ps1 - pins, clean clone, mark, package-out.
  UNIT   the v4 rollout package: branch v4, head a593823, built -Mode Full -SkipDB.
  WHY FULL AND NOT SHELL  measured on the station, delta 251ca40..a593823:
         db/migrations/ 0 · RTM/ 3 · src/ 24 · .resx 3. Engine files in the delta make -Mode Shell
         unlawful for this flight - the three flights before this one were Shell-only and this one
         is not.
  WHERE  WORKSTATION ONLY. Server 234 is NOT touched. The v4 worktree (RTM-design) is NOT touched:
         this builds in its own clean clone of the pinned commit.

  WITNESSES ARE COMPUTED, NOT CHOSEN
         Earlier flights listed the delta's product files by hand. With 27 of them that becomes my
         judgement about which ones matter, and a witness list I curate is a list I can curate wrong.
         Here the probe asks git for every file under src/ and RTM/ in the delta and compares each
         blob between the clone and the working repo. Nothing is picked; nothing is left out.

  THE MAIN PREDICATE, INVERTED AS ALWAYS AND RE-MEASURED FOR THIS FLIGHT
         The three dictionaries gain 8 keys each (957 -> 965, measured on the station), so every
         satellite must be LARGER than what 234 carries. The 'on 234' row below was measured at
         16:25 today [234_20260926_162510_predeploy-251ca40.txt] and is not the previous flight's:
         those numbers describe a package that has since been replaced.
         The previous flight moved +2048/+1536/+1536 from NINETEEN keys. Eight keys will not move
         them by the same amounts, and no such expectation is stated here.
#>

param([switch]$KeepClone)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$WORK      = 'D:\Claude\Projects\RTM View Shell'
$BUILDROOT = 'D:\Claude\Build'
$DEPLOYED  = '251ca40'
$ON_SERVER_BYTES = @{ 'he-IL' = 76800 ; 'ru-RU' = 86528 ; 'en-US' = 69632 }
$DEPLOYED_ENGINE_SHA = '4FE7009A5E28D27EA84700CD1BE0ED6835F42E26813FFE8260B2590C73F4114E'
$DEPLOYED_WEB_SHA    = '76C00DBCAA2E7A06F960E724BC8FD9A31FF9C22D8827A55BFFD815937B066115'

$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$measDir = Join-Path $WORK '.measurements'
if (-not (Test-Path -LiteralPath $measDir)) { New-Item -ItemType Directory -Path $measDir | Out-Null }
$logPath = Join-Path $measDir ("WS_{0}_fullpkg-a593823.txt" -f $stamp)

function Say([string]$text) { Write-Host $text }
function Line() { Write-Host ('-' * 78) }
function Invoke-Native([scriptblock]$Block) {
  $prevPref = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Block } finally { $ErrorActionPreference = $prevPref }
}

Start-Transcript -Path $logPath -Force | Out-Null
try {
  Say ("FULL PACKAGE (v4)  " + (Get-Date -Format 'u') + "   host=" + $env:COMPUTERNAME)
  Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
  Say  "SERVER 234 IS NOT TOUCHED. The v4 worktree is not touched."
  $PIN_COMMIT = (Invoke-Native { & git -C "$WORK" rev-parse v4 }).Trim()
  $PIN_SHORT  = $PIN_COMMIT.Substring(0,7)
  $CLONE      = Join-Path $BUILDROOT ("rtm_v4_{0}_{1}" -f $PIN_SHORT, $stamp)
  Say ("head of v4, re-taken now : " + $PIN_COMMIT)
  Say  "  The coordinator named a593823 as the orientation. If the line above is a different commit,"
  Say  "  the head moved while we worked and THAT is what gets built and reported - not the message."
  Say ("clone will be            : " + $CLONE)
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
    ("probe   : probe_WS_20260926_fullpkg-a593823.ps1"),
    ("sha256  : " + $selfHash),
    ("stamp   : " + $stamp),
    ("machine : " + $env:COMPUTERNAME + " / " + $env:USERNAME),
    ("commit  : " + $PIN_COMMIT),
    ("unit    : v4 rollout package, Mode Full SkipDB, by devops-0919")
  ) -join "`r`n"
  [System.IO.File]::WriteAllText((Join-Path $CLONE '.origin'), $originText + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
  Say  "  .origin written inside the clone"
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
  Say ("  RTM/ engine    : " + $engineHits + "   (expected non-zero - this is WHY the mode is Full, not Shell)")
  Say ("  src/           : " + $srcHits + "   (POSCTL - a zero here would mean the delta listing is empty)")
  Say ("  .resx          : " + $resxHits + "   (expected 3 - this is WHY the satellites must move)")
  $modeLawful = (($migrationHits -eq 0) -and ($engineHits -gt 0) -and ($srcHits -gt 0))
  Say ("  PIN 3b " + $(if ($modeLawful) { 'GREEN  -Mode Full -SkipDB is lawful for this delta' } else { 'RED    STOP - the mode does not match the delta' }))
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
  Say  "  command : Build-ProdRelease.ps1 -Mode Full -SkipDB -GarnetDir <work cache> -NssmDir <work cache>"
  Push-Location $CLONE
  try {
    Invoke-Native { & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $builder -Mode Full -SkipDB -GarnetDir $garnetDir -NssmDir $nssmDir 2>&1 } |
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
  $webHash = 'NOT-FOUND' ; $engineHash = 'NOT-FOUND'
  try {
    $entryNames = $archive.Entries | ForEach-Object { $_.FullName }
    Say ("  entries    : " + $entryNames.Count)
    foreach ($need in @('Update-RTMView.ps1','Install-RTMView.ps1')) {
      Say ("  contains " + $need + " : " + @($entryNames | Where-Object { $_ -like ('*' + $need) }).Count)
    }
    Say ("  RTM\ entries in package   : " + @($entryNames | Where-Object { ($_ -replace '\\','/') -like 'RTM/*' }).Count + "   (must be non-zero for Mode Full)")
    Say ("  Shell\ entries in package : " + @($entryNames | Where-Object { ($_ -replace '\\','/') -like 'Shell/*' }).Count + "   (must be non-zero for Mode Full)")

    foreach ($pair in @(@('CcDashboard.Web.dll', $DEPLOYED_WEB_SHA), @('RTM.dll', $DEPLOYED_ENGINE_SHA))) {
      $leaf = $pair[0] ; $deployedSha = $pair[1]
      $entry = $archive.Entries | Where-Object { (Split-Path -Leaf ($_.FullName -replace '\\','/')) -eq $leaf } | Select-Object -First 1
      if (-not $entry) { Say ("  " + $leaf.PadRight(22) + " NOT IN PACKAGE  <- report, do not improvise") ; continue }
      $tempFile = Join-Path $env:TEMP ('fullpkg_' + [Guid]::NewGuid().ToString('N') + '.bin')
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $tempFile, $true)
      $entryHash = (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash
      $entryBytes = (Get-Item -LiteralPath $tempFile).Length
      Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
      if ($leaf -eq 'CcDashboard.Web.dll') { $webHash = $entryHash } else { $engineHash = $entryHash }
      $moved = ($entryHash -ne $deployedSha)
      Say ("  " + $leaf.PadRight(22) + $entryHash + "  " + $entryBytes + " B")
      Say ("  " + ' '.PadRight(22) + "differs from what 234 runs : " + $moved + "   (equal would mean this flight changes nothing there)")
    }

    Say ""
    Say  "  SATELLITE ASSEMBLIES - compared by SIZE against what 234 carries RIGHT NOW"
    Say  "  EXPECTED, BEFORE THE MEASUREMENT: all three LARGER. Eight keys were added to each"
    Say  "  dictionary and none removed. Equality is a FINDING; smaller is a FINDING of another kind."
    $satellitesGrew = 0
    foreach ($culture in @('he-IL','ru-RU','en-US')) {
      $satEntry = $archive.Entries | Where-Object { ($_.FullName -replace '\\','/') -like ('*/' + $culture + '/CcDashboard.Web.resources.dll') } | Select-Object -First 1
      if (-not $satEntry) { Say ("    " + $culture.PadRight(6) + " : NOT IN PACKAGE  <- report, do not improvise") ; continue }
      $serverBytes = $ON_SERVER_BYTES[$culture]
      $deltaBytes  = $satEntry.Length - $serverBytes
      if ($deltaBytes -gt 0) { $satellitesGrew++ }
      $reading = if ($deltaBytes -gt 0) { 'as expected: GREW (+' + $deltaBytes + ' B, multiple of 512: ' + (($deltaBytes % 512) -eq 0) + ')' }
                 elseif ($deltaBytes -eq 0) { 'FINDING: identical to 234 - the new keys are NOT in this package' }
                 else { 'FINDING: SMALLER than 234 by ' + [math]::Abs($deltaBytes) + ' B - keys were lost' }
      Say ("    " + $culture.PadRight(6) + " package " + $satEntry.Length + " B   on 234 " + $serverBytes + " B   -> " + $reading)
    }
    Say ("  satellites grown : " + $satellitesGrew + " of 3   (3 expected; anything less is the finding of this run)")
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
  Say ("  RTM.dll in package   : " + $engineHash)
  Say  "  Server 234 was not touched. Nothing was installed anywhere."
  Say  "END-OF-RUN MARKER: FULLPKG-A593823-COMPLETE"
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
