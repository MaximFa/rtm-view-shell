<#
  PROBE  probe_WS_20260926_enginefloor-build-0ae2102.ps1
  SHAPE  FROM probe_WS_20260920_shellpkg-step4.ps1 - the pins, the clean clone and the mark are its
         structure. The satellite machinery of that probe is deliberately NOT carried over: an engine
         package contains no Shell satellites, and a check about files a build never produces cannot
         fail. A check that cannot fail is an ornament.
  UNIT   NOT a rollout build. This builds the ROLLBACK FLOOR the v4 flight does not have.
         Measured on 234 at 16:38 [234_20260926_163820_enginefloor.txt]: of four RTM packages on that
         disk, ZERO contain the running engine - and the archive reader was proven sound on a known
         answer BEFORE that zero was believed.
  WHERE  WORKSTATION ONLY. Server 234 is not touched: no network to it, no copy, no install.
         The v4 worktree (RTM-design) is not touched either: this builds in its own clean clone.

  THE PIN IS FIXED, AND THAT IS THE POINT
         Every other build here re-takes a branch head. This one must not. The floor has to match
         what is DEPLOYED, so the pin is the literal commit 0ae2102, resolved and printed below.

  THE OUTCOME I CANNOT PREDICT, NAMED BEFORE THE RUN INSTEAD OF AFTER
         The package must contain RTM.dll. Whether its sha256 equals the deployed
         4FE7009A5E28D27EA84700CD1BE0ED6835F42E26813FFE8260B2590C73F4114E depends on whether this
         .NET build is byte-reproducible on this machine, and I do not know that it is.
         Both outcomes are named now and neither will be dressed up afterwards:
           IDENTICAL -> the floor restores the machine byte for byte. Strongest case.
           DIFFERENT -> the floor restores the same SOURCE revision, not the same bytes. Weaker,
                        still a floor, and accepting it is the coordinator decision - not mine,
                        and not something to bury inside a green line.
           NO RTM.dll -> neither of those. A failed build, reported as a failed build.
#>

param(
  [switch]$KeepClone
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$WORK      = 'D:\Claude\Projects\RTM View Shell'
$BUILDROOT = 'D:\Claude\Build'
$WITNESSES = @('RTM/RTM/Engine.cs','RTM/RTM/Union.cs','RTM/RTM/UserManager.cs')
$DEPLOYED_ENGINE_SHA = '4FE7009A5E28D27EA84700CD1BE0ED6835F42E26813FFE8260B2590C73F4114E'

$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$measDir = Join-Path $WORK '.measurements'
if (-not (Test-Path -LiteralPath $measDir)) { New-Item -ItemType Directory -Path $measDir | Out-Null }
$logPath = Join-Path $measDir ("WS_{0}_enginefloor-build.txt" -f $stamp)

function Say([string]$text) { Write-Host $text }
function Line() { Write-Host ('-' * 78) }
function Invoke-Native([scriptblock]$Block) {
  $prevPref = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Block } finally { $ErrorActionPreference = $prevPref }
}

Start-Transcript -Path $logPath -Force | Out-Null
try {
  Say ("ENGINE FLOOR BUILD (0ae2102)  " + (Get-Date -Format 'u') + "   host=" + $env:COMPUTERNAME)
  Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
  Say  "SERVER 234 IS NOT TOUCHED BY THIS RUN. The v4 worktree is not touched either."
  $PIN_COMMIT = (Invoke-Native { & git -C "$WORK" rev-parse '0ae2102^{commit}' }).Trim()
  $PIN_SHORT  = $PIN_COMMIT.Substring(0,7)
  $CLONE      = Join-Path $BUILDROOT ("rtm_floor_{0}_{1}" -f $PIN_SHORT, $stamp)
  Say ("fixed pin 0ae2102, resolved now : " + $PIN_COMMIT)
  Say ("clone will be                   : " + $CLONE)
  Line

  Say "ROLLBACK FOR THIS RUN, printed BEFORE the first write:"
  Say ("  Remove-Item -Recurse -Force '" + $CLONE + "'")
  Say  "  Nothing outside that directory is written. No service, no server, no repo state, no worktree."
  Line

  if (-not (Test-Path -LiteralPath $WORK))  { throw ("working clone not found: " + $WORK) }
  if (Test-Path -LiteralPath $CLONE)        { throw ("clone dir already exists: " + $CLONE) }
  if (-not (Test-Path -LiteralPath $BUILDROOT)) { New-Item -ItemType Directory -Path $BUILDROOT | Out-Null }
  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  if (-not $gitCmd) { throw 'git not found in PATH' }
  $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
  if (-not $dotnetCmd) { throw 'dotnet SDK not found in PATH' }
  Say ("git    : " + (Invoke-Native { & git --version }))
  Say ("dotnet : " + (Invoke-Native { & dotnet --version }))
  $driveLetter = (Split-Path -Qualifier $BUILDROOT).TrimEnd(':')
  Say ("free on " + $driveLetter + ": " + [math]::Round((Get-PSDrive -Name $driveLetter).Free/1GB,1) + " GB")
  Line

  Say "PIN 1  clean clone at the FIXED commit"
  Invoke-Native { & git clone --no-hardlinks -- "$WORK" "$CLONE" 2>&1 } | ForEach-Object { Say ("  " + $_) }
  if ($LASTEXITCODE -ne 0) { throw 'git clone failed' }
  Invoke-Native { & git -C "$CLONE" checkout --detach $PIN_COMMIT 2>&1 } | ForEach-Object { Say ("  " + $_) }
  if ($LASTEXITCODE -ne 0) { throw 'checkout of the pinned commit failed' }
  $cloneHead = (Invoke-Native { & git -C "$CLONE" rev-parse HEAD }).Trim()
  Say ("  clone HEAD : " + $cloneHead)
  $pinClone = ($cloneHead -eq $PIN_COMMIT)
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
    ("probe   : probe_WS_20260926_enginefloor-build-0ae2102.ps1"),
    ("sha256  : " + $selfHash),
    ("stamp   : " + $stamp),
    ("machine : " + $env:COMPUTERNAME + " / " + $env:USERNAME),
    ("commit  : " + $PIN_COMMIT),
    ("unit    : ENGINE FLOOR package from 0ae2102, by devops-0919")
  ) -join "`r`n"
  [System.IO.File]::WriteAllText((Join-Path $CLONE '.origin'), $originText + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
  Say  "  .origin written inside the clone"
  Line

  Say "PIN 3  content witnesses - the THREE engine files, blob by blob"
  $pinWitness = $true
  foreach ($witness in $WITNESSES) {
    $blobClone = (Invoke-Native { & git -C "$CLONE" rev-parse ("HEAD:" + $witness) }).Trim()
    $blobWork  = (Invoke-Native { & git -C "$WORK"  rev-parse ($PIN_COMMIT + ":" + $witness) }).Trim()
    $sameBlob  = (($blobClone -eq $blobWork) -and ($blobClone.Length -eq 40))
    if (-not $sameBlob) { $pinWitness = $false }
    Say ("  " + $witness.PadRight(26) + " clone " + $blobClone + "  equal " + $sameBlob)
  }
  Say ("  PIN 3 " + $(if ($pinWitness) { 'GREEN  all three blobs equal' } else { 'RED    a blob differs' }))
  Line

  Say "PIN 3b  is -Mode RTM lawful for this floor"
  $engineFileCount = @(Invoke-Native { & git -C "$CLONE" ls-tree -r --name-only HEAD -- RTM/ }).Count
  Say ("  files under RTM/ at this commit : " + $engineFileCount + "   (must be non-zero, else there is no engine to package)")
  $modeLawful = ($engineFileCount -gt 0)
  Say ("  PIN 3b " + $(if ($modeLawful) { 'GREEN' } else { 'RED    STOP' }))
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
  Say  "  command : Build-ProdRelease.ps1 -Mode RTM -SkipDB -GarnetDir <work cache> -NssmDir <work cache>"
  Push-Location $CLONE
  try {
    Invoke-Native { & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $builder -Mode RTM -SkipDB -GarnetDir $garnetDir -NssmDir $nssmDir 2>&1 } |
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
  $engineHash = 'NOT-FOUND'
  try {
    $entryNames = $archive.Entries | ForEach-Object { $_.FullName }
    Say ("  entries    : " + $entryNames.Count)
    $engineEntry = $archive.Entries | Where-Object { (Split-Path -Leaf ($_.FullName -replace '\\','/')) -eq 'RTM.dll' } | Select-Object -First 1
    if ($engineEntry) {
      $tempFile = Join-Path $env:TEMP ('floorbuild_' + $stamp + '.dll')
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($engineEntry, $tempFile, $true)
      $engineHash = (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash
      Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
      Say ("  RTM.dll in package : " + $engineEntry.FullName)
      Say ("  RTM.dll sha256     : " + $engineHash)
    } else { Say "  RTM.dll : NOT IN PACKAGE  <- this is a failed build, not a weak floor" }
  } finally { $archive.Dispose() }
  Line

  Say "THE COMPARISON THIS RUN EXISTS FOR"
  Say ("  deployed on 234 : " + $DEPLOYED_ENGINE_SHA)
  Say ("  built here      : " + $engineHash)
  if ($engineHash -eq 'NOT-FOUND') {
    Say  "  VERDICT : FAILED BUILD - no engine binary in the package. Not a floor. Report, do not improvise."
  } elseif ($engineHash -eq $DEPLOYED_ENGINE_SHA) {
    Say  "  VERDICT : IDENTICAL - the build is byte-reproducible here and this package restores the"
    Say  "            machine exactly. Strongest floor. Nothing further is needed."
  } else {
    Say  "  VERDICT : DIFFERENT BYTES, SAME SOURCE REVISION."
    Say  "            The build is not byte-reproducible on this machine. This package rebuilds the"
    Say  "            engine from the revision that is deployed, which is a floor, but a weaker one:"
    Say  "            a rollback would put back equivalent code, not the identical binary."
    Say  "            ACCEPTING THIS IS THE COORDINATOR DECISION. It is printed here, not smoothed over."
  }
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
  if ($destHash -ne $zipHash) {
    Say "  CLONE KEPT because the copy is RED."
  } elseif ($KeepClone) {
    Say ("  CLONE KEPT (-KeepClone): " + $CLONE)
  } else {
    Remove-Item -LiteralPath $CLONE -Recurse -Force
    Say ("  clone removed; exists now: " + (Test-Path -LiteralPath $CLONE))
  }
  Line

  Say "VERDICT LINES"
  Say ("  PIN 1 clone HEAD == " + $PIN_SHORT + "  : " + $(if ($pinClone) { 'GREEN' } else { 'RED' }))
  Say ("  PIN 2 porcelain 0 lines     : " + $(if ($pinClean) { 'GREEN' } else { 'RED' }))
  Say ("  PIN 3 witness blobs equal   : " + $(if ($pinWitness) { 'GREEN' } else { 'RED' }))
  Say ("  PIN 4 build exit 0 + zip    : " + $(if ($buildExit -eq 0) { 'GREEN' } else { 'RED  exit=' + $buildExit }))
  Say ("  floor package : " + $destZip)
  Say ("  its sha256    : " + $destHash)
  Say  "  Server 234 was not touched. Nothing was installed anywhere."
  Say  "END-OF-RUN MARKER: ENGINEFLOOR-BUILD-COMPLETE"
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
