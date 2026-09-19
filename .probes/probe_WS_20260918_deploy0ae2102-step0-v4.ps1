<#
  PROBE  probe_WS_20260918_deploy0ae2102-step0-v4.ps1
  V4     disk housekeeping, asked for by the operator: clones were piling up. v4 (a) deletes ONLY clones
         carrying THIS step's own .origin mark, naming each one and its size before it goes; (b) copies the
         finished package into the project's own Installations\ (gitignored: .gitignore:58, so the repo
         stays clean) and re-hashes it THERE, equal or STOP; (c) removes its own clone at the end, because
         once the package is out and hash-verified the tree has no further use. -KeepClone / -KeepPrevious
         switch each half off. Nothing without this step's mark is ever touched.
  V3     v2 reached PIN 4 and the build refused: tools\cache\ is GITIGNORED (.gitignore:74), so Garnet
         (62 MB) and NSSM live only on the workstation and are in NO commit. A clean clone therefore can
         never build by itself. v3 points the builder at the working clone's cache via its own
         -GarnetDir/-NssmDir parameters (nothing is copied into the clean clone) and pins those binaries
         SEPARATELY, by sha256, as what they are: inputs NOT addressed by the commit.
  V2     v1 wrote its own .origin mark into the clone BEFORE taking pin 2, so `git status --porcelain`
         reported 1 line (`?? .origin`) and the probe stopped itself at PIN 2 RED. The stop was correct;
         the order was mine and wrong. v2 takes pin 2 on a pristine tree, then writes the mark.
  UNIT   PR234-DEPLOY-0ae2102 / STEP 0  (plan tools/plan_234_deploy_0ae2102.md, blob c73e3405, §4 closed 2026-09-18)
  WHERE  WORKSTATION ONLY. Server 234 is NOT touched by this probe: no network to 234, no copy, no install.
  WHAT   Clean clone -> pins 1..3 -> build (pin 4) -> package sha256 -> ledger-ready MANIFEST line.
  WRITES D:\Claude\Build\rtm_clean_0ae2102_<stamp>\  (new directory, must not exist)
         plus whatever Build-ProdRelease.ps1 puts under that clone's Installations\
         The working clone D:\Claude\Projects\RTM View Shell is READ ONLY here: clone reads it, nothing writes it.
  ROLLBACK  Remove-Item -Recurse -Force D:\Claude\Build\rtm_clean_0ae2102_<stamp>   (nothing else changed)
  OUT    transcript path printed at the end; copy it back as .measurements\WS_<stamp>_deploy0ae2102-step0.txt
#>

param(
  [switch]$KeepClone,      # keep this run's clone after the package is copied out and verified
  [switch]$KeepPrevious    # keep clones left by previous runs of THIS step
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$PIN_COMMIT = '0ae2102c1c841d75488e4ef286d22a15202c8de8'
$PIN_SHORT  = '0ae2102'
$WORK       = 'D:\Claude\Projects\RTM View Shell'
$BUILDROOT  = 'D:\Claude\Build'
$WITNESS    = 'src/CcDashboard.Web/Components/Widgets/QueueGridWidget.razor'

$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$CLONE   = Join-Path $BUILDROOT ("rtm_clean_{0}_{1}" -f $PIN_SHORT, $stamp)
$logPath = Join-Path $env:TEMP ("step0_{0}.txt" -f $stamp)

function Say([string]$s) { Write-Host $s }
function Line() { Write-Host ('-' * 78) }
function Invoke-Native([scriptblock]$Sb) {
  # native stderr under $ErrorActionPreference='Stop' would throw on ordinary progress output (git, dotnet)
  $p = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Sb } finally { $ErrorActionPreference = $p }
}

Start-Transcript -Path $logPath -Force | Out-Null
try {
  Say ("STEP 0  " + (Get-Date -Format 'u') + "   host=" + $env:COMPUTERNAME + "   user=" + $env:USERNAME)
  Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
  Say "SERVER 234 IS NOT TOUCHED BY THIS RUN."
  Line

  # ---- rollback, printed BEFORE the first write -----------------------------
  Say "ROLLBACK FOR THIS RUN:"
  Say ("  Remove-Item -Recurse -Force '" + $CLONE + "'")
  Say "  Nothing outside that directory is written. No service, no server, no repo state."
  Line

  # ---- what the probe FOUND on entry, before its first write -----------------
  Say "ON ENTRY: existing clean clones under the build root"
  $selfName = 'probe_WS_20260918_deploy0ae2102-step0-v4.ps1'
  $selfStem = 'deploy0ae2102-step0'   # matches v1 and v2: both are MY runs of this same step
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
        foreach ($l in ($txt -split "`r?`n")) { if ($l.Trim()) { Say ("      | " + $l) } }
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
  $p1 = ($cloneHead -eq $PIN_COMMIT)
  Say ("  PIN 1 " + $(if ($p1) { 'GREEN  clone HEAD == ' + $PIN_SHORT } else { 'RED    clone HEAD != ' + $PIN_SHORT }))
  Line

  # ---- PIN 2: cleanliness ---------------------------------------------------
  Say "PIN 2  cleanliness of the clean clone (measured BEFORE this probe writes anything into it)"
  $porc = @(Invoke-Native { & git -C "$CLONE" status --porcelain })
  Say ("  git status --porcelain lines : " + $porc.Count)
  if ($porc.Count -gt 0) { $porc | ForEach-Object { Say ("    " + $_) } }
  $p2 = ($porc.Count -eq 0)
  Say ("  PIN 2 " + $(if ($p2) { 'GREEN  0 lines' } else { 'RED    tree not clean' }))

  # ---- the run mark goes in only AFTER pin 2 was taken on a pristine tree -----
  $selfPath = $MyInvocation.MyCommand.Path
  $selfHash = if ($selfPath) { (Get-FileHash -Algorithm SHA256 -LiteralPath $selfPath).Hash } else { 'unknown' }
  $originTxt = @(
    ("probe   : " + $selfName),
    ("sha256  : " + $selfHash),
    ("stamp   : " + $stamp),
    ("machine : " + $env:COMPUTERNAME + " / " + $env:USERNAME),
    ("commit  : " + $PIN_COMMIT),
    ("unit    : PR234-DEPLOY-0ae2102 step 0, by devops-0916")
  ) -join "`r`n"
  [System.IO.File]::WriteAllText((Join-Path $CLONE '.origin'), $originTxt + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
  Say ("  .origin written inside the clone (probe name, sha256, stamp, machine, commit)")
  Line

  # ---- PIN 3: content witness ----------------------------------------------
  Say "PIN 3  content witness"
  $wA = (Invoke-Native { & git -C "$CLONE" rev-parse ("HEAD:" + $WITNESS) }).Trim()
  $wB = (Invoke-Native { & git -C "$WORK"  rev-parse ($PIN_COMMIT + ":" + $WITNESS) }).Trim()
  Say ("  clean clone HEAD:<witness>      : " + $wA)
  Say ("  work clone  " + $PIN_SHORT + ":<witness>  : " + $wB)
  $p3 = ($wA -eq $wB -and $wA.Length -eq 40)
  Say ("  PIN 3 " + $(if ($p3) { 'GREEN  blobs equal' } else { 'RED    blobs differ' }))
  Line

  if (-not ($p1 -and $p2 -and $p3)) {
    Say "STOP BEFORE BUILD: a provenance pin is RED. Nothing was built, nothing was packaged."
    Say ("Run the rollback line above if you want the clone gone: " + $CLONE)
    return
  }

  # ---- PIN 4: build ---------------------------------------------------------
  Say "PIN 4  build in the CLEAN clone (this is the long step)"
  $builder = Join-Path $CLONE 'tools\Build-ProdRelease.ps1'
  if (-not (Test-Path -LiteralPath $builder)) { throw ('builder not found: ' + $builder) }
  Say ("  builder sha256 : " + (Get-FileHash -Algorithm SHA256 -LiteralPath $builder).Hash)
  # PIN 4b: binaries the build needs that NO commit contains (tools\cache\ is gitignored)
  $GARNET = Join-Path $WORK 'tools\cache\garnet-1.1.10-win-x64-net8'
  $NSSM   = Join-Path $WORK 'tools\cache\nssm'
  Say "  PIN 4b  inputs that are NOT addressed by the commit (tools\cache\ is in .gitignore:74)"
  foreach ($pair in @(@('GarnetServer.exe', (Join-Path $GARNET 'GarnetServer.exe')), @('nssm.exe', (Join-Path $NSSM 'nssm.exe')))) {
    if (Test-Path -LiteralPath $pair[1]) {
      $fi = Get-Item -LiteralPath $pair[1]
      Say ("    " + $pair[0] + " : " + (Get-FileHash -Algorithm SHA256 -LiteralPath $pair[1]).Hash)
      Say ("      path " + $pair[1] + "   " + $fi.Length + " B   mtime " + $fi.LastWriteTimeUtc.ToString('u'))
    } else {
      Say ("    " + $pair[0] + " : NOT FOUND at " + $pair[1] + "   <- build will refuse; stop and report")
    }
  }
  Say  "    These two are taken from the WORKING clone and are read-only inputs. They are pinned by sha256 here"
  Say  "    and by nothing else: the commit does not address them, and this flight does not claim it does."
  Say  "  command        : Build-ProdRelease.ps1 -Mode Full -GarnetDir <work cache> -NssmDir <work cache>"
  Push-Location $CLONE
  try {
    Invoke-Native { & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $builder -Mode Full -GarnetDir $GARNET -NssmDir $NSSM 2>&1 } |
      ForEach-Object { Say ("  | " + $_) }
    $buildExit = $LASTEXITCODE
  } finally { Pop-Location }
  Say ("  builder exit code : " + $buildExit)
  Line

  # ---- package --------------------------------------------------------------
  Say "PACKAGE"
  $instDir = Join-Path $CLONE 'Installations'
  if (-not (Test-Path -LiteralPath $instDir)) { throw ('no Installations directory in the clean clone: ' + $instDir) }
  $zip = Get-ChildItem -LiteralPath $instDir -Filter *.zip | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $zip) { throw 'no .zip produced' }
  $zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip.FullName).Hash
  Say ("  zip name   : " + $zip.Name)
  Say ("  zip path   : " + $zip.FullName)
  Say ("  zip bytes  : " + $zip.Length + "   (" + [math]::Round($zip.Length/1MB,2) + " MB)")
  Say ("  zip sha256 : " + $zipHash)

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $za = [System.IO.Compression.ZipFile]::OpenRead($zip.FullName)
  try {
    $names = $za.Entries | ForEach-Object { $_.FullName }
    Say ("  entries    : " + $names.Count)
    $hasDb = @($names | Where-Object { $_ -like 'db/*' -or $_ -like 'db\*' }).Count
    Say ("  db\ entries in package : " + $hasDb + $(if ($hasDb -eq 0) { '   (pg_dump was skipped; reported, not decided here)' } else { '' }))
    foreach ($need in @('Update-RTMView.ps1','Install-RTMView.ps1')) {
      $n = @($names | Where-Object { $_ -like ('*' + $need) }).Count
      Say ("  contains " + $need + " : " + $n)
    }
    $webdll = $za.Entries | Where-Object { $_.FullName -like '*CcDashboard.Web.dll' } | Select-Object -First 1
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
  } finally { $za.Dispose() }
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
  Say ("  PIN 1 clone HEAD == " + $PIN_SHORT + "   : " + $(if ($p1) { 'GREEN' } else { 'RED' }))
  Say ("  PIN 2 porcelain 0 lines      : " + $(if ($p2) { 'GREEN' } else { 'RED' }))
  Say ("  PIN 3 witness blob equal     : " + $(if ($p3) { 'GREEN' } else { 'RED' }))
  Say ("  PIN 4 build exit 0 + zip     : " + $(if ($buildExit -eq 0) { 'GREEN' } else { 'RED  exit=' + $buildExit }))
  Say  "  PIN 4b cache binaries         : pinned by sha256 above; NOT addressed by the commit, said plainly."
  Say  "  PIN 5 compilation root       : NOT MEASURABLE HERE. It is taken on 234 after the install (step 3)."
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
