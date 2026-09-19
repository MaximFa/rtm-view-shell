#Requires -Version 5.1
<#
  PROBE  probe_234_20260919_deploy0ae2102-step2-install.ps1
  UNIT   PR234-DEPLOY-0ae2102 / STEP 2 - THE INSTALL. This box WRITES on the live server.
  WHERE  SERVER 234 ONLY. G0 refuses to run anywhere else.
  WHAT   package -> sha256 gate -> Unblock-File -> manual extract -> Update-RTMView.ps1 with the flags the
         accepted plan names -> two assertions on the installer's own output -> MANIFEST line into the ops ledger.
  ACCEPTANCE IS NOT HERE. Step 3 does it. This box only performs the install and records what it saw.
  PASSWORD Asked with Read-Host -AsSecureString. Never printed, never written to the report.
#>

param(
  [string]$Package = 'C:\RTMView-Ops\incoming\18092026.2225.zip'
)

$ErrorActionPreference = 'Continue'
$PIN_ZIP_SHA = '01188805B05F3C98C4854B8F89870D9C2421CD746881ECEF80F24C3F27A7CC9A'
$PIN_COMMIT  = '0ae2102'
$stamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutDir = 'C:\RTMView-Ops\output'
$AppDir = 'C:\RTMView-Ops\applied'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
$outf = Join-Path $OutDir ("234_{0}_deploy0ae2102-step2-install.txt" -f $stamp)
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add("$s"); Write-Host "$s" }
function Line() { Say ('-' * 78) }
function Flush() { [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) { Flush; Write-Host ""; Write-Host ("REPORT: " + $outf); if ($pass) { exit 0 } else { exit 1 } }
function Sha256Of($p) {
  if (-not (Test-Path -LiteralPath $p)) { return 'ABSENT' }
  try { return (Get-FileHash -LiteralPath $p -Algorithm SHA256 -ErrorAction Stop).Hash }
  catch { return ('HASH-FAILED: ' + $_.Exception.GetType().Name + ': ' + $_.Exception.Message) }
}

Say ("STEP 2  INSTALL  " + (Get-Date -Format u) + "   host=" + $env:COMPUTERNAME)
Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
Line

Say "SELF-TEST of the hash instrument, before it gates anything"
$tmp = Join-Path $env:TEMP ("sha_selftest_{0}.txt" -f $stamp)
[IO.File]::WriteAllText($tmp, 'abc', (New-Object System.Text.UTF8Encoding($false)))
$got = Sha256Of $tmp
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
$selfOk = ($got -eq 'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD')
Say ("  sha256('abc') -> " + $got)
Say ("  SELF-TEST : " + $selfOk)
if (-not $selfOk) { Say "  the gate below would be meaningless. STOP."; Fin $false }
Line

Say "G0  machine identity"
$nameOk = ($env:COMPUTERNAME -eq 'RTM')
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  name match " + $nameOk + " / uuid match " + $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say "  *** NOT server 234 - refusing"; Fin $false }
Say "  G0 PASS"
Line

Say "ROLLBACK, PRINTED BEFORE THE FIRST WRITE"
Say "  R1 services down and staying down:"
Say "       Start-Service RTMService ; wait for pipe rtmpipe_v3 + a reply on 8089 ; Start-Service RTMViewShell ;"
Say "       wait for https://127.0.0.1:8444/health = 200.  RTMTwilio_1 is NEVER started by hand - the engine raises it."
Say "  R2 binaries wrong after the install:"
Say "       the installer takes its own pre-install backup under C:\RTMView\Backup\<stamp>\ ."
Say "       Stop the services, copy that directory back over C:\RTMView\Shell and \RTM, then R1."
Say "  R3 database (NOT expected - this flight runs no migrations):"
Say "       pg_restore -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb --clean --if-exists <the step-1 dump>"
Say "       then re-check F0, then R1.  R3 needs the operator's word at the moment, it is not automatic."
Say "  R4 the 13.09 adapter base C:\RTMView\Backup\rtmtwilio_aa19743_20260913_011524 is NOT touched by this flight;"
Say "       -KeepBackups 50 is what keeps the installer from deleting it."
Line

Say "PRE-STATE, taken again here so this report stands alone"
$pre = @{}
foreach ($s in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $s) -ErrorAction SilentlyContinue
  if ($null -eq $svc) { Say ("  {0,-14} ABSENT" -f $s); $pre[$s] = 'ABSENT' }
  else { $pre[$s] = $svc.State; Say ("  {0,-14} {1,-9} pid {2}" -f $svc.Name, $svc.State, $svc.ProcessId) }
}
$bkBefore = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue).Count
Say ("  backup directories BEFORE : " + $bkBefore + "   (step 3 expects exactly " + ($bkBefore + 1) + ")")
Say ("  Shell\CcDashboard.Web.dll BEFORE : " + (Sha256Of 'C:\RTMView\Shell\CcDashboard.Web.dll'))
Say ("  RTM\data.sys              BEFORE : " + (Sha256Of 'C:\RTMView\RTM\data.sys') + "   (MUST NOT change - the installer preserves it)")
Line

Say "PACKAGE GATE"
Say ("  package : " + $Package)
if (-not (Test-Path -LiteralPath $Package)) { Say "  *** NOT FOUND. Nothing was written. STOP."; Fin $false }
$zipSha = Sha256Of $Package
Say ("  sha256 here     : " + $zipSha)
Say ("  sha256 expected : " + $PIN_ZIP_SHA + "   (taken on the workstation at step 0)")
if ($zipSha -ne $PIN_ZIP_SHA) { Say "  *** MISMATCH. This is not the package that step 0 built. Nothing was written. STOP."; Fin $false }
Say "  GATE GREEN - the bytes on this server are the bytes that were built from 0ae2102"
Unblock-File -LiteralPath $Package -ErrorAction SilentlyContinue
Say "  Unblock-File applied to the package"
Line

Say "EXTRACT (manual, entry by entry: this package writes its entry names with backslashes)"
$work = Join-Path 'C:\RTMView-Ops\incoming' ("pkg_{0}_{1}" -f $PIN_COMMIT, $stamp)
if (Test-Path -LiteralPath $work) { Say ("  *** staging dir already exists: " + $work + " - STOP"); Fin $false }
New-Item -ItemType Directory -Path $work -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$za = [System.IO.Compression.ZipFile]::OpenRead($Package)
$n = 0
try {
  foreach ($e in $za.Entries) {
    if ([string]::IsNullOrEmpty($e.Name)) { continue }
    $rel = $e.FullName.Replace('/', '\')
    $dst = Join-Path $work $rel
    $dir = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dst, $true)
    $n++
  }
} finally { $za.Dispose() }
Say ("  extracted files : " + $n + "   into " + $work)
$updater = Join-Path $work 'Update-RTMView.ps1'
foreach ($need in @($updater, (Join-Path $work 'Shell'), (Join-Path $work 'RTM'))) {
  Say ("  present: " + $need + " -> " + (Test-Path -LiteralPath $need))
}
if (-not (Test-Path -LiteralPath $updater)) { Say "  *** Update-RTMView.ps1 missing from the package. Nothing installed. STOP."; Fin $false }
Get-ChildItem -LiteralPath $work -Recurse -Include *.ps1 | ForEach-Object { Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue }
Say ("  Update-RTMView.ps1 sha256 : " + (Sha256Of $updater))
Say ("  package Shell\CcDashboard.Web.dll sha256 : " + (Sha256Of (Join-Path $work 'Shell\CcDashboard.Web.dll')))
Line

Say "PASSWORD"
$sec = Read-Host -Prompt 'Password for ccdashboard_user@127.0.0.1:5433/rtmviewdb' -AsSecureString
$PW = $null
if ($sec -and $sec.Length -gt 0) {
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { $PW = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
  Say ("  supplied, " + $PW.Length + " characters (NOT printed, NOT in this report)")
} else { Say "  nothing supplied - STOP before the install"; Fin $false }
Line

Say "THE INSTALL - this is the moment the server changes"
Say "  command (exactly the accepted plan, and -ForceDeploy is deliberately NOT used):"
Say "    Update-RTMView.ps1 -DBPort 5433 -SkipDrift -SkipCacheMigration -KeepBackups 50 -MigrationList '' -DBPassword <hidden>"
Flush
$t0 = Get-Date
$out = & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $updater `
        -DBPort 5433 -SkipDrift -SkipCacheMigration -KeepBackups 50 -MigrationList '' -DBPassword $PW 2>&1
$installExit = $LASTEXITCODE
$PW = $null
$outLines = @($out | ForEach-Object { "$_" })
foreach ($l in $outLines) { Say ("  | " + $l) }
Say ("  installer exit code : " + $installExit)
Say ("  elapsed : " + [math]::Round(((Get-Date) - $t0).TotalSeconds, 1) + " s")
Line

Say "TWO ASSERTIONS ON THE INSTALLER'S OWN WORDS (ordinal Contains, both needles, counted)"
$joined = ($outLines -join "`n")
$nMig  = ([regex]::Matches($joined, [regex]::Escape('No migrations specified'))).Count
$nSkip = ([regex]::Matches($joined, [regex]::Escape('Drift gate SKIPPED'))).Count
$nFlag = ([regex]::Matches($joined, [regex]::Escape('-SkipDrift'))).Count
Say ("  'No migrations specified'  occurrences : " + $nMig  + "   (expected 1 - this flight changes no schema)")
Say ("  'Drift gate SKIPPED'       occurrences : " + $nSkip + "   (expected 1)")
Say ("  '-SkipDrift' named in that line        : " + $nFlag + "   (expected >= 1 - INST-14: the installer prints the flag actually passed)")
$nNeg = ([regex]::Matches($joined, [regex]::Escape('-ForceDeploy'))).Count
Say ("  NEGCTL '-ForceDeploy' anywhere in the output : " + $nNeg + "   (must be 0 - it was not passed)")
$assertOk = (($nMig -eq 1) -and ($nSkip -eq 1) -and ($nFlag -ge 1))
Say ("  ASSERTIONS : " + $(if ($assertOk) { 'GREEN' } else { 'RED - report it, do not re-run the installer' }))
Line

Say "POST-STATE, a first glance only. STEP 3 IS THE ACCEPTANCE, NOT THIS."
foreach ($s in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $s) -ErrorAction SilentlyContinue
  Say ("  {0,-14} {1}   (was {2})" -f $s, $(if ($null -eq $svc) { 'ABSENT' } else { $svc.State }), $pre[$s])
}
$bkAfter = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue).Count
Say ("  backup directories : " + $bkBefore + " -> " + $bkAfter + "   (a backup that did not appear means the installer never reached its backup step)")
Say ("  Shell\CcDashboard.Web.dll AFTER : " + (Sha256Of 'C:\RTMView\Shell\CcDashboard.Web.dll'))
Say  "      expected (from the package) : 4848C42915EA9B3B7D4933E23E5D5C8231A57B0E06A11D012C2AB4F505BBFD8E"
Say ("  RTM\data.sys              AFTER : " + (Sha256Of 'C:\RTMView\RTM\data.sys'))
Say  "      expected UNCHANGED          : 24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43"
Say  "      the package carries a DIFFERENT data.sys (7745C5CA...). If that one is on disk, the preserve failed."
Line

Say "LEDGER - the build-to-commit link, because our installer writes no manifest of its own"
$ledger = Join-Path $AppDir '_ledger.txt'
$manifest = ('{0} | MANIFEST | commit={1} package={2} package_sha256={3} web.dll_sha256={4} installer_exit={5} by=devops-0916' -f `
  (Get-Date -Format u), $PIN_COMMIT, (Split-Path -Leaf $Package), $zipSha, '4848C42915EA9B3B7D4933E23E5D5C8231A57B0E06A11D012C2AB4F505BBFD8E', $installExit)
try {
  Add-Content -LiteralPath $ledger -Value $manifest -Encoding UTF8 -ErrorAction Stop
  Say ("  written to " + $ledger)
  Say ("  " + $manifest)
  Say ("  ledger now has " + (@(Get-Content -LiteralPath $ledger)).Count + " lines")
} catch { Say ("  *** could not write the ledger: " + $_.Exception.Message) }
Line

Say "VERDICT OF STEP 2 (installation only)"
Say ("  installer exit : " + $installExit)
Say ("  assertions     : " + $assertOk)
Say ("  staging kept at: " + $work + "   (step 3 reads Compare-ToBaseline from here; delete it after step 4)")
$ok = (($installExit -eq 0) -and $assertOk)
Say ("  STEP 2 : " + $(if ($ok) { 'DONE - go to step 3, which decides whether this flight is accepted' } else { 'PROBLEM - stop and report; the rollback block is at the top of this report' }))
Say "===== END-OF-RUN MARKER: STEP2-COMPLETE ====="
Fin $ok
