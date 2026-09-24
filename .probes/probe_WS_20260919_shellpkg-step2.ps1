<#
  PROBE  probe_WS_20260919_shellpkg-step2.ps1
  BASED  ON probe_WS_20260918_deploy0ae2102-step0-v4.ps1 (that run built 0ae2102 and is the proven shape).
         Changed here, and only here: the pinned revision is READ FROM THE WORKING CLONE AT RUN TIME
         instead of being hard-coded; the content witness is FOUR files instead of one; the build is
         -Mode Shell -SkipDB; and the package is opened for the three satellite assemblies, because
         those are what the before/after pair of this rollout stands on.
  UNIT   PR234-DEPLOY-LIGHT01/L10N step 2 - build the Shell package from a clean clone.
  WHY    The delta to what runs on 234 is four product files: two grid widgets and two .resx.
         No deploy/**, no db/** - so this is a Shell code-only package, and the DB layer is skipped.
  WHERE  WORKSTATION ONLY. Server 234 is NOT touched: no network to it, no copy, no install.
  WHAT   Clean clone -> head re-taken now -> four witnesses -> build -> package sha256 -> satellites.
  WRITES the clean clone directory printed below (must not exist), whatever the builder puts under its
         Installations, and the package copied into the working clone Installations (gitignored).
  ROLLBACK  Remove-Item -Recurse -Force <the clone path printed below>. Nothing else changes.
#>

param(
  [switch]$KeepClone,      # keep this run's clone after the package is copied out and verified
  [switch]$KeepPrevious    # keep clones left by previous runs of THIS step
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$WORK       = 'D:\Claude\Projects\RTM View Shell'
$BUILDROOT  = 'D:\Claude\Build'
# The four product files of this rollout. The provenance gate stands on THEIR blobs, not on the head:
# the head moves while we work - twice in eleven minutes on 19.09 - while the content does not.
$WITNESSES  = @(
  'src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor',
  'src/CcDashboard.Web/Components/Widgets/AgentGridWidget.razor',
  'src/CcDashboard.Web/Resources/SharedResources.he-IL.resx',
  'src/CcDashboard.Web/Resources/SharedResources.ru-RU.resx'
)
# What server 234 carries right now, measured by probe_234_20260919_predeploy-state.ps1 at 12:20 local.
# he-IL and ru-RU MUST differ in the package: the delta adds 82 and 60 keys. en-US MUST stay equal.
$ON_SERVER  = @{
  'he-IL' = 'F288C38EDF521F7F360718671BA34BE673E125E07D69FD439F49387AB00D6858'
  'ru-RU' = '4D4318CD497C9C0AA82366D496EA66BB282DE00C999379FE49D5F6A769B50B0C'
  'en-US' = '410B743BB5C33B94E60AC51856B59816270588A38B652CC33CCB4EE0C921742F'
}

$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = Join-Path $env:TEMP ("shellpkg_{0}.txt" -f $stamp)
# the head is re-taken HERE, at build time, and named in the report - never carried in from a message
$PIN_COMMIT = (& git -C "$WORK" rev-parse v3).Trim()
$PIN_SHORT  = $PIN_COMMIT.Substring(0,7)
$CLONE   = Join-Path $BUILDROOT ("rtm_clean_{0}_{1}" -f $PIN_SHORT, $stamp)

function Say([string]$s) { Write-Host $s }
function Line() { Write-Host ('-' * 78) }
function Invoke-Native([scriptblock]$Sb) {
  # native stderr under $ErrorActionPreference='Stop' would throw on ordinary progress output (git, dotnet)
  $prevPref = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Sb } finally { $ErrorActionPreference = $prevPref }
}

Start-Transcript -Path $logPath -Force | Out-Null
try {
  Say ("SHELL PACKAGE STEP 2  " + (Get-Date -Format 'u') + "   host=" + $env:COMPUTERNAME + "   user=" + $env:USERNAME)
  Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
  Say "SERVER 234 IS NOT TOUCHED BY THIS RUN."
  Say ("head of v3, re-taken now : " + $PIN_COMMIT)
  Say ("clone will be            : " + $CLONE)
  Line

  # ---- rollback, printed BEFORE the first write -----------------------------
  Say "ROLLBACK FOR THIS RUN:"
  Say ("  Remove-Item -Recurse -Force '" + $CLONE + "'")
  Say "  Nothing outside that directory is written. No service, no server, no repo state."
  Line

  # ---- what the probe FOUND on entry, before its first write -----------------
  Say "ON ENTRY: existing clean clones under the build root"
  $selfName = 'probe_WS_20260919_shellpkg-step2.ps1'
  $selfStem = 'shellpkg-step2'   # only clones carrying THIS step's own mark are ever removed
  if (Test-Path -LiteralPath $BUILDROOT) {
    $prior = @(Get-ChildItem -LiteralPath $BUILDROOT -Directory -Filter ("rtm_clean_" + $PIN_SHORT + "_*") -ErrorAction SilentlyContinue)
    if ($prior.Count -eq 0) { Say "  none" }
    foreach ($dir in $prior) {
      $mark = Join-Path $dir.FullName '.origin'
      if (-not (Test-Path -LiteralPath $mark)) {
        Say ("  " + $dir.Name + "  -> NO MARK: origin unknown. NOT TOUCHED.")
      } else {
        $txt = (Get-Content -LiteralPath $mark -Raw)
        if ($txt -like ("*" + $selfStem + "*")) {
          $szGB = [math]::Round((Get-ChildItem -LiteralPath $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB, 2)
          if ($KeepPrevious) {
            Say ("  " + $dir.Name + "  -> MY OWN previous run of this step, " + $szGB + " GB. KEPT (-KeepPrevious).")
          } else {
            Say ("  " + $dir.Name + "  -> MY OWN previous run of this step, " + $szGB + " GB. DELETING (it carries my mark; -KeepPrevious keeps it).")
            Remove-Item -LiteralPath $dir.FullName -Recurse -Force
            Say ("      deleted; exists now: " + (Test-Path -LiteralPath $dir.FullName))
          }
        } else {
          Say ("  " + $dir.Name + "  -> ANOTHER probe's artifact. NOT TOUCHED.")
        }
        foreach ($markLine in ($txt -split "`r?`n")) { if ($markLine.Trim()) { Say ("      | " + $markLine) } }
      }
    }
  } else { Say ("  build root does not exist yet: " + $BUILDROOT) }
  Say "  Anything WITHOUT this step's own mark is never deleted and never reused."
  Line

  # ---- preconditions --------------------------------------------------------
  if (-not (Test-Path -LiteralPath $WORK))  { throw ("working clone not found: " + $WORK) }
  if (Test-Path -LiteralPath $CLONE)        { throw ("clone dir already exists: " + $CLONE) }
  if (-not (Test-Path -LiteralPath $BUILDROOT)) { New-Item -ItemType Directory -Path $BUILDROOT | Out-Null }

  $git = (Get-Command git -ErrorAction SilentlyContinue)
  if (-not $git) { throw 'git not found in PATH' }
  Say ("git      : " + $git.Source + "  " + (Invoke-Native { & git --version }))
  $dotnet = (Get-Command dotnet -ErrorAction SilentlyContinue)
  if (-not $dotnet) { throw 'dotnet SDK not found in PATH' }
  Say ("dotnet   : " + $dotnet.Source + "  " + (Invoke-Native { & dotnet --version }))
  $pgd = (Get-Command pg_dump -ErrorAction SilentlyContinue)
  if ($pgd) { Say ("pg_dump  : " + $pgd.Source) } else { Say "pg_dump  : NOT in PATH (build self-skips the DB dump with a WARN; reported, not decided here)" }
  $drive = Get-PSDrive -Name (Split-Path -Qualifier $BUILDROOT).TrimEnd(':')
  Say ("free on " + $drive.Name + ": " + [math]::Round($drive.Free/1GB,1) + " GB")
  Line

  # ---- PIN 1: clean clone, HEAD == 0ae2102 ----------------------------------
  Say "PIN 1  clean clone"
  Invoke-Native { & git clone --no-hardlinks -- "$WORK" "$CLONE" 2>&1 } | ForEach-Object { Say ("  " + $_) }
  if ($LASTEXITCODE -ne 0) { throw 'git clone failed' }
  Invoke-Native { & git -C "$CLONE" checkout --detach $PIN_COMMIT 2>&1 } | ForEach-Object { Say ("  " + $_) }
  if ($LASTEXITCODE -ne 0) { throw 'checkout of the pinned commit failed' }
  $cloneHead = (Invoke-Native { & git -C "$CLONE" rev-parse HEAD }).Trim()
  $workHead  = (Invoke-Native { & git -C "$WORK"  rev-parse HEAD }).Trim()
  Say ("  clone HEAD : " + $cloneHead)
  Say ("  work  HEAD : " + $workHead)
  $pinClone = ($cloneHead -eq $PIN_COMMIT)
  Say ("  PIN 1 " + $(if ($pinClone) { 'GREEN  clone HEAD == ' + $PIN_SHORT } else { 'RED    clone HEAD != ' + $PIN_SHORT }))
  Line

  # ---- PIN 2: cleanliness ---------------------------------------------------
  Say "PIN 2  cleanliness of the clean clone (measured BEFORE this probe writes anything into it)"
  $porc = @(Invoke-Native { & git -C "$CLONE" status --porcelain })
  Say ("  git status --porcelain lines : " + $porc.Count)
  if ($porc.Count -gt 0) { $porc | ForEach-Object { Say ("    " + $_) } }
  $pinClean = ($porc.Count -eq 0)
  Say ("  PIN 2 " + $(if ($pinClean) { 'GREEN  0 lines' } else { 'RED    tree not clean' }))

  # ---- the run mark goes in only AFTER pin 2 was taken on a pristine tree -----
  $selfPath = $MyInvocation.MyCommand.Path
  $selfHash = if ($selfPath) { (Get-FileHash -Algorithm SHA256 -LiteralPath $selfPath).Hash } else { 'unknown' }
  $originTxt = @(
    ("probe   : " + $selfName),
    ("sha256  : " + $selfHash),
    ("stamp   : " + $stamp),
    ("machine : " + $env:COMPUTERNAME + " / " + $env:USERNAME),
    ("commit  : " + $PIN_COMMIT),
    ("unit    : PR234-DEPLOY-LIGHT01/L10N step 2, by devops-0919")
  ) -join "`r`n"
  [System.IO.File]::WriteAllText((Join-Path $CLONE '.origin'), $originTxt + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
  Say ("  .origin written inside the clone (probe name, sha256, stamp, machine, commit)")
  Line

  # ---- PIN 3: content witness ----------------------------------------------
  Say "PIN 3  content witnesses - all FOUR product files of this rollout, blob by blob"
  $pinWitness = $true
  foreach ($witness in $WITNESSES) {
    $blobClone = (Invoke-Native { & git -C "$CLONE" rev-parse ("HEAD:" + $witness) }).Trim()
    $blobWork  = (Invoke-Native { & git -C "$WORK"  rev-parse ($PIN_COMMIT + ":" + $witness) }).Trim()
    $sameBlob  = ($blobClone -eq $blobWork -and $blobClone.Length -eq 40)
    if (-not $sameBlob) { $pinWitness = $false }
    Say ("  " + $witness)
    Say ("      clone " + $blobClone + "   work " + $blobWork + "   equal " + $sameBlob)
  }
  Say ("  PIN 3 " + $(if ($pinWitness) { 'GREEN  all four blobs equal' } else { 'RED    a blob differs - the builder would read a tree I never checked' }))
  Line

  if (-not ($pinClone -and $pinClean -and $pinWitness)) {
    Say "STOP BEFORE BUILD: a provenance pin is RED. Nothing was built, nothing was packaged."
    Say ("Run the rollback line above if you want the clone gone: " + $CLONE)
    return
  }

  # ---- PIN 4: build ---------------------------------------------------------
  $buildStartedAt = Get-Date
  Say ("PIN 4  build in the CLEAN clone (this is the long step). Build started at " + $buildStartedAt.ToString('u'))
  Say  "  Any package older than that timestamp is a leftover, not this run's result, and is refused below."
  $builder = Join-Path $CLONE 'tools\Build-ProdRelease.ps1'
  if (-not (Test-Path -LiteralPath $builder)) { throw ('builder not found: ' + $builder) }
  Say ("  builder sha256 : " + (Get-FileHash -Algorithm SHA256 -LiteralPath $builder).Hash)
  # PIN 4b: binaries the build needs that NO commit contains (tools\cache\ is gitignored)
  $GARNET = Join-Path $WORK 'tools\cache\garnet-1.1.10-win-x64-net8'
  $NSSM   = Join-Path $WORK 'tools\cache\nssm'
  Say "  PIN 4b  inputs that are NOT addressed by the commit (tools\cache\ is in .gitignore:74)"
  foreach ($pair in @(@('GarnetServer.exe', (Join-Path $GARNET 'GarnetServer.exe')), @('nssm.exe', (Join-Path $NSSM 'nssm.exe')))) {
    if (Test-Path -LiteralPath $pair[1]) {
      $fileInfo = Get-Item -LiteralPath $pair[1]
      Say ("    " + $pair[0] + " : " + (Get-FileHash -Algorithm SHA256 -LiteralPath $pair[1]).Hash)
      Say ("      path " + $pair[1] + "   " + $fileInfo.Length + " B   mtime " + $fileInfo.LastWriteTimeUtc.ToString('u'))
    } else {
      Say ("    " + $pair[0] + " : NOT FOUND at " + $pair[1] + "   <- build will refuse; stop and report")
    }
  }
  Say  "    These two are taken from the WORKING clone and are read-only inputs. They are pinned by sha256 here"
  Say  "    and by nothing else: the commit does not address them, and this flight does not claim it does."
  Say  "  command        : Build-ProdRelease.ps1 -Mode Shell -SkipDB -GarnetDir <work cache> -NssmDir <work cache>"
  Say  "  Mode Shell because the delta carries no RTM source and no db/**; SkipDB for the same reason."
  Push-Location $CLONE
  try {
    Invoke-Native { & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $builder -Mode Shell -SkipDB -GarnetDir $GARNET -NssmDir $NSSM 2>&1 } |
      ForEach-Object { Say ("  | " + $_) }
    $buildExit = $LASTEXITCODE
  } finally { Pop-Location }
  Say ("  builder exit code : " + $buildExit)
  Line

  # ---- package --------------------------------------------------------------
  Say "PACKAGE"
  $instDir = Join-Path $CLONE 'Installations'
  if (-not (Test-Path -LiteralPath $instDir)) { throw ('no Installations directory in the clean clone: ' + $instDir) }
  $zip = Get-ChildItem -LiteralPath $instDir -Filter *.zip | Where-Object { $_.LastWriteTime -ge $buildStartedAt } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $zip) {
    $anyZip = @(Get-ChildItem -LiteralPath $instDir -Filter *.zip)
    Say ("  zips present in that directory at all : " + $anyZip.Count + " (none of them written after the build started)")
    foreach ($old in $anyZip) { Say ("    " + $old.Name + "   " + $old.LastWriteTime.ToString('u')) }
    throw 'no .zip produced by THIS run - refusing to hand out an older package'
  }
  Say ("  freshness : zip written " + $zip.LastWriteTime.ToString('u') + " , build started " + $buildStartedAt.ToString('u'))
  $zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip.FullName).Hash
  Say ("  zip name   : " + $zip.Name)
  Say ("  zip path   : " + $zip.FullName)
  Say ("  zip bytes  : " + $zip.Length + "   (" + [math]::Round($zip.Length/1MB,2) + " MB)")
  Say ("  zip sha256 : " + $zipHash)

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zipArchive = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
  try {
    $names = $zipArchive.Entries | ForEach-Object { $_.FullName }
    Say ("  entries    : " + $names.Count)
    $hasDb = @($names | Where-Object { $_ -like 'db/*' -or $_ -like 'db\*' }).Count
    Say ("  db\ entries in package : " + $hasDb + $(if ($hasDb -eq 0) { '   (pg_dump was skipped; reported, not decided here)' } else { '' }))
    foreach ($need in @('Update-RTMView.ps1','Install-RTMView.ps1')) {
      $hitCount = @($names | Where-Object { $_ -like ('*' + $need) }).Count
      Say ("  contains " + $need + " : " + $hitCount)
    }
    $webdll = $zipArchive.Entries | Where-Object { $_.FullName -like '*CcDashboard.Web.dll' } | Select-Object -First 1
    if ($webdll) {
      $tmp = Join-Path $env:TEMP ('webdll_' + $stamp + '.dll')
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($webdll, $tmp, $true)
      $webHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $tmp).Hash
      Remove-Item -LiteralPath $tmp -Force
      Say ("  CcDashboard.Web.dll in package : " + $webdll.FullName)
      Say ("  CcDashboard.Web.dll sha256     : " + $webHash)
    } else {
      $webHash = 'NOT-FOUND'
      Say "  CcDashboard.Web.dll : NOT FOUND IN PACKAGE  <- proof (1) cannot be taken; report, do not improvise"
    }
    Say ""
    Say "  SATELLITE ASSEMBLIES - the before/after pair of this rollout stands on these three"
    Say "  expected, stated BEFORE the measurement: he-IL and ru-RU DIFFER from what 234 carries"
    Say "  (the delta adds 82 and 60 keys); en-US is EQUAL to what 234 carries, its resx is untouched"
    foreach ($culture in @('he-IL','ru-RU','en-US')) {
      $satEntry = $zipArchive.Entries | Where-Object { $_.FullName -like ('*' + $culture + '/CcDashboard.Web.resources.dll') } | Select-Object -First 1
      if (-not $satEntry) { Say ("    " + $culture.PadRight(6) + " : NOT IN PACKAGE") ; continue }
      $tmpSat = Join-Path $env:TEMP ('sat_' + $culture + '_' + $stamp + '.dll')
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($satEntry, $tmpSat, $true)
      $satHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $tmpSat).Hash
      Remove-Item -LiteralPath $tmpSat -Force
      $serverHash = $ON_SERVER[$culture]
      $differs    = ($satHash -ne $serverHash)
      if ($culture -eq 'en-US') {
        $reading = if ($differs) { 'UNEXPECTED: differs, though its resx is not in the delta' } else { 'as expected: equal to 234' }
      } else {
        $reading = if ($differs) { 'as expected: differs from 234' } else { 'UNEXPECTED: equal to 234 - the new keys are not in this package' }
      }
      Say ("    " + $culture.PadRight(6) + " package " + $satHash)
      Say ("    " + '      ' + " on 234  " + $serverHash + "   -> " + $reading)
    }
  } finally { $zipArchive.Dispose() }
  Line

  # ---- ledger-ready line (NOT written anywhere yet; step 2 writes it on 234) --
  Say "MANIFEST LINE for C:\RTMView-Ops\applied\_ledger.txt  (step 2 writes it ON 234; nothing is written now)"
  $manifest = ('{0} | MANIFEST | commit={1} package={2} package_sha256={3} web.dll_sha256={4} by=devops-0916' -f `
      (Get-Date -Format 'u'), $PIN_SHORT, $zip.Name, $zipHash, $webHash)
  Say ("  " + $manifest)
  Line

  # ---- package leaves the clone, so the clone need not survive -----------------
  Say "PACKAGE OUT OF THE CLONE"
  $projInst = Join-Path $WORK 'Installations'
  if (-not (Test-Path -LiteralPath $projInst)) { New-Item -ItemType Directory -Path $projInst | Out-Null }
  $destZip = Join-Path $projInst $zip.Name
  if (Test-Path -LiteralPath $destZip) { throw ('destination already exists, not overwriting: ' + $destZip) }
  Copy-Item -LiteralPath $zip.FullName -Destination $destZip
  $destHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destZip).Hash
  Say ("  copied to  : " + $destZip)
  Say ("  sha256 here: " + $destHash)
  $copyOk = ($destHash -eq $zipHash)
  Say ("  COPY " + $(if ($copyOk) { 'GREEN  sha256 equal to the package in the clone' } else { 'RED    sha256 DIFFERS - do not use this package' }))
  [System.IO.File]::WriteAllText(($destZip + '.origin.txt'), ($originTxt + "`r`n" + $manifest + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
  Say ("  mark       : " + $destZip + ".origin.txt  (probe, sha256, stamp, machine, commit, MANIFEST line)")
  Say  "  Installations\*.zip is gitignored (.gitignore:58) - the repository stays clean."

  if (-not $copyOk) {
    Say "  CLONE KEPT because the copy is RED."
  } elseif ($KeepClone) {
    Say ("  CLONE KEPT (-KeepClone): " + $CLONE)
  } else {
    $cloneGB = [math]::Round((Get-ChildItem -LiteralPath $CLONE -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB, 2)
    Say ("  removing this run's clone (" + $cloneGB + " GB); the package is out and hash-verified")
    Remove-Item -LiteralPath $CLONE -Recurse -Force
    Say ("  clone exists now: " + (Test-Path -LiteralPath $CLONE))
  }
  $freeAfter = (Get-PSDrive -Name (Split-Path -Qualifier $BUILDROOT).TrimEnd(':')).Free
  Say ("  free on " + (Split-Path -Qualifier $BUILDROOT) + " after housekeeping: " + [math]::Round($freeAfter/1GB,1) + " GB")
  $instGB = [math]::Round((Get-ChildItem -LiteralPath $projInst -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB, 2)
  Say ("  Installations\ now holds " + $instGB + " GB of packages - reported, not touched: that archive is yours.")
  Line

  Say "VERDICT"
  Say ("  PIN 1 clone HEAD == " + $PIN_SHORT + "   : " + $(if ($pinClone) { 'GREEN' } else { 'RED' }))
  Say ("  PIN 2 porcelain 0 lines      : " + $(if ($pinClean) { 'GREEN' } else { 'RED' }))
  Say ("  PIN 3 witness blob equal     : " + $(if ($pinWitness) { 'GREEN' } else { 'RED' }))
  Say ("  PIN 4 build exit 0 + zip     : " + $(if ($buildExit -eq 0) { 'GREEN' } else { 'RED  exit=' + $buildExit }))
  Say  "  PIN 4b cache binaries         : pinned by sha256 above; NOT addressed by the commit, said plainly."
  Say  "  PIN 5 compilation root       : NOT MEASURABLE HERE. It is taken on 234 after the install (step 3)."
  Say ("  head built from              : " + $PIN_COMMIT + "   re-taken by this run, not carried in")
  Say ("  package for step 2 : " + $destZip)
  Say ("  its sha256         : " + $destHash)
}
catch {
  Say ""
  Say ("BROKEN OFF: " + $_.Exception.Message)
  Say ("At: " + $_.InvocationInfo.PositionMessage)
  Say "Nothing was sent to 234. The clone directory, if created, is the only residue; the rollback line above removes it."
}
finally {
  Stop-Transcript | Out-Null
  Write-Host ""
  Write-Host ("TRANSCRIPT: " + $logPath)
}
