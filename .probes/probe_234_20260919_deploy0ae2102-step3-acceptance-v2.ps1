#Requires -Version 5.1
<#
  PROBE  probe_234_20260919_deploy0ae2102-step3-acceptance-v2.ps1
  V2     v1 returned 21 GREEN of 24. The three REDs were a fault of the instrument, not of the server:
         `Get-Date -Format u` prints LOCAL time and appends 'Z' WITHOUT converting, while the process
         start time was converted with .ToUniversalTime(). Comparing the two made services that had just
         been restarted look three hours older than the install.
         v2 drops the clock from that predicate entirely and uses something a timezone cannot bend:
         THE PROCESS ID, against the ids recorded before the install by step 2
         (RTMService 12840, RTMViewShell 13544, RTMTwilio_1 11008). A different pid means the process
         is a new one. Start times are still printed, in ONE clock, as supporting detail only.
         The class is now caught by tools/lint_probe.py, which this file passes.
  UNIT   PR234-DEPLOY-0ae2102 / STEP 3 - ACCEPTANCE. This is the box that decides whether the flight stands.
  WHERE  SERVER 234 ONLY. G0 refuses to run anywhere else.
  CHANGES  NOTHING on the system. Read-only, plus its own report under C:\RTMView-Ops\output\.
         The database is read with SELECT only; no dump, no service, no file is touched.
  ROLLBACK  Delete the report. If a check below is RED, the rollback for the FLIGHT is in the step 2
         report (R1..R4) - this probe never rolls anything back by itself.
  PASSWORD Asked with Read-Host -AsSecureString, for the F0 re-check only. Never printed.

  Every expectation below was written BEFORE the install, from the package and from the shipped
  installer's own source - not fitted to what the machine now shows.
#>

param(
  [string]$StagingDir = 'C:\RTMView-Ops\incoming\pkg_0ae2102_20260918_230306',
  [int]$LivenessTimeoutSeconds = 180
)

$ErrorActionPreference = 'Continue'
$RunStamp   = Get-Date -Format yyyyMMdd_HHmmss
$OutputDir  = 'C:\RTMView-Ops\output'
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$ReportPath = Join-Path $OutputDir ("234_{0}_deploy0ae2102-step3-acceptance.txt" -f $RunStamp)
$ReportLines = New-Object System.Collections.ArrayList

# --- expectations, pinned before the install ---------------------------------
$ExpectedCommit      = '0ae2102c1c841d75488e4ef286d22a15202c8de8'
$ExpectedCommitShort = '0ae2102'
$ExpectedWebDll  = '4848C42915EA9B3B7D4933E23E5D5C8231A57B0E06A11D012C2AB4F505BBFD8E'
$ExpectedWebExe  = '2D28453712304E891C8000E5A3B66C1E480173BBFF4A25B51634D86685442865'
$ExpectedRtmExe  = 'A62FA167F6F0F1E984366EB3EC90323489DEEE3DF90448F757F130AA13BEA297'
$ExpectedDataSys = '24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43'
$ExpectedTwilioExe = 'CC124AC26C6D27037E424987AFF105BA03C1371789E5FE9C901E73F24BC2850E'
$ExpectedConfigs = @{
  'C:\RTMView\Shell\appsettings.json'             = '6BDA96379E53A8E947DB1FE0C72B847C21D3589E99C7F30CA29A04A53156037A'
  'C:\RTMView\Shell\appsettings.Development.json' = '709C8ED5DDA3243AF077DDA34E48002E304F2A573DD9016FB85A09E0101AC6FE'
  'C:\RTMView\RTM\appsettings.json'               = '28ED04F0E029252EFDA5E2B741EBB1417EADFD8CE82B958F452A85DACB487D68'
  'C:\RTMView\RTM\log4net.config'                 = '534CCD7348BABD59F1FB8F2827936E961835A83A9FE0864ACB6DF5C7794B408B'
  'C:\RTMView\RTM.Twilio\appsettings.json'        = '93060DFBAE26B93062473844C2578FD7209DFE75470D0FCEBDD944467737CC01'
}
$ExpectedFingerprint = '411B2F16944EA5297CE679B0B544CCD0E3C91532F1F3CCF26A4372216C7CB135'
$ExpectedBackupDirs  = 9
$ExpectedNewBackup   = 'C:\RTMView\Backup\18092026_2303'
$RollbackBaseR4      = 'C:\RTMView\Backup\rtmtwilio_aa19743_20260913_011524'
$PreInstallProcessIds = @{ 'RTMService' = 12840; 'RTMViewShell' = 13544; 'RTMTwilio_1' = 11008 }

function Write-Report() { [IO.File]::WriteAllLines($ReportPath, $ReportLines, (New-Object System.Text.UTF8Encoding($false))) }
function Say($text) { [void]$ReportLines.Add("$text"); Write-Host "$text" }
function Rule() { Say ('-' * 78) }
function Finish($passed) { Write-Report; Write-Host ""; Write-Host ("REPORT: " + $ReportPath); if ($passed) { exit 0 } else { exit 1 } }
function Get-Sha256Of($target) {
  if (-not (Test-Path -LiteralPath $target)) { return 'ABSENT' }
  try { return (Get-FileHash -LiteralPath $target -Algorithm SHA256 -ErrorAction Stop).Hash }
  catch { return ('HASH-FAILED: ' + $_.Exception.GetType().Name + ': ' + $_.Exception.Message) }
}
$Checks = New-Object System.Collections.ArrayList
function Record($label, $passed, $detail) {
  [void]$Checks.Add([pscustomobject]@{ Label = $label; Passed = [bool]$passed })
  Say ("  [{0}] {1}" -f $(if ($passed) { 'GREEN' } else { 'RED  ' }), $label)
  if ($detail) { Say ("         " + $detail) }
}

Say ("STEP 3  ACCEPTANCE  " + (Get-Date -Format u) + "   host=" + $env:COMPUTERNAME)
Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
Say  "READ ONLY. This probe changes nothing; it only decides."
Write-Report
Rule

Say "SELF-TEST of the hash instrument"
$selfTestFile = Join-Path $env:TEMP ("sha_selftest_{0}.txt" -f $RunStamp)
[IO.File]::WriteAllText($selfTestFile, 'abc', (New-Object System.Text.UTF8Encoding($false)))
$selfTestGot = Get-Sha256Of $selfTestFile
Remove-Item -LiteralPath $selfTestFile -Force -ErrorAction SilentlyContinue
$selfTestOk = ($selfTestGot -eq 'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD')
Say ("  sha256('abc') -> " + $selfTestGot + "   SELF-TEST : " + $selfTestOk)
if (-not $selfTestOk) { Say "  every comparison below would be meaningless. STOP."; Finish $false }
Rule

Say "G0  machine identity"
$nameMatches = ($env:COMPUTERNAME -eq 'RTM')
$machineUuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidMatches = ($machineUuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  name match " + $nameMatches + " / uuid match " + $uuidMatches)
if (-not ($nameMatches -and $uuidMatches)) { Say "  *** NOT server 234 - refusing"; Finish $false }
Rule

Say "1  SERVICES - running, and a NEW process (clock-free: the pid, not the wall clock)"
Say  "  The pids below the arrow were recorded by step 2 BEFORE the install. A changed pid cannot be"
Say  "  produced by a timezone, a daylight shift or a report heading - only by the process being replaced."
foreach ($serviceName in @('RTMService','RTMViewShell','RTMTwilio_1')) {
  $service = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $serviceName) -ErrorAction SilentlyContinue
  if ($null -eq $service) { Record ($serviceName + " present") $false 'service ABSENT'; continue }
  $startedText = 'n/a'
  if ($service.ProcessId -gt 0) {
    $process = Get-Process -Id $service.ProcessId -ErrorAction SilentlyContinue
    if ($process) { $startedText = $process.StartTime.ToString('yyyy-MM-dd HH:mm:ss') + ' (machine local clock)' }
  }
  $previousPid = $PreInstallProcessIds[$serviceName]
  $isRunning = ($service.State -eq 'Running')
  $isNewProcess = ($service.ProcessId -ne $previousPid -and $service.ProcessId -gt 0)
  Record ($serviceName + " Running") $isRunning ("state " + $service.State + "  pid " + $service.ProcessId + "  started " + $startedText)
  Record ($serviceName + " is a NEW process (pid changed)") $isNewProcess ("pid " + $previousPid + " before the install -> " + $service.ProcessId + " now")
}
Say  "  RTMTwilio_1 is raised by the engine, never by hand. Running here means the engine did its job."
Rule

Say "2  LIVENESS TRIPLE, polled (not a single glance)"
$curlPath = "$env:SystemRoot\System32\curl.exe"
$deadline = (Get-Date).AddSeconds($LivenessTimeoutSeconds)
$livenessOk = $false
$attempts = 0
$shellCode = ''; $engineCode = ''; $pipeServed = $false
while ((Get-Date) -lt $deadline) {
  $attempts++
  if (Test-Path -LiteralPath $curlPath) {
    $shellCode  = (& $curlPath -k -s -o NUL -w "%{http_code}" --max-time 10 "https://127.0.0.1:8444/health") 2>$null
    $engineCode = (& $curlPath -s -o NUL -w "%{http_code}" --max-time 10 "http://127.0.0.1:8089/") 2>$null
  }
  $pipeNames = @()
  try { $pipeNames = @([IO.Directory]::GetFiles("\\.\pipe\") | ForEach-Object { $_.Substring(9) }) } catch { }
  $pipeServed = ($pipeNames -contains 'rtmpipe_v3')
  $engineAnswers = ("$engineCode" -ne '000' -and "$engineCode" -ne '')
  if (("$shellCode" -eq '200') -and $pipeServed -and $engineAnswers) { $livenessOk = $true; break }
  Start-Sleep -Seconds 5
}
$negativeCode = ''
if (Test-Path -LiteralPath $curlPath) { $negativeCode = (& $curlPath -k -s -o NUL -w "%{http_code}" --max-time 10 "https://127.0.0.1:8444/zzz-no-such-endpoint") 2>$null }
Say ("  attempts: " + $attempts + "   shell /health -> " + $shellCode + "   engine 8089 -> " + $engineCode + "   pipe rtmpipe_v3 -> " + $pipeServed)
Say ("  NEGCTL /zzz -> " + $negativeCode + "   (200 here would void the shell line)")
Record "liveness triple (pipe + engine listener + shell 200)" ($livenessOk -and ("$negativeCode" -ne '200')) ''
Rule

Say "3  BYTES ON THE GROUND = BYTES WE BUILT  (proof 1 of 'this build')"
$actualWebDll = Get-Sha256Of 'C:\RTMView\Shell\CcDashboard.Web.dll'
$actualWebExe = Get-Sha256Of 'C:\RTMView\Shell\CcDashboard.Web.exe'
$actualRtmExe = Get-Sha256Of 'C:\RTMView\RTM\RTM.exe'
$actualDataSys = Get-Sha256Of 'C:\RTMView\RTM\data.sys'
$actualTwilio = Get-Sha256Of 'C:\RTMView\RTM.Twilio\RTM.Twilio.exe'
Record "CcDashboard.Web.dll == package" ($actualWebDll -eq $ExpectedWebDll) ("on disk " + $actualWebDll)
Record "CcDashboard.Web.exe == package" ($actualWebExe -eq $ExpectedWebExe) ("on disk " + $actualWebExe)
Record "RTM.exe == package"             ($actualRtmExe -eq $ExpectedRtmExe) ("on disk " + $actualRtmExe)
Record "data.sys UNCHANGED (preserved)" ($actualDataSys -eq $ExpectedDataSys) ("on disk " + $actualDataSys + "  (the package ships 7745C5CA..., which must NOT be here)")
Record "RTM.Twilio.exe untouched"       ($actualTwilio -eq $ExpectedTwilioExe) ("on disk " + $actualTwilio + "  (the installer never mentions Twilio: 0 occurrences in its source)")
Rule

Say "4  COMPILATION ROOT AND VERSION  (proof 2 of 'this build' - provenance, not just bytes)"
$webExePath = 'C:\RTMView\Shell\CcDashboard.Web.exe'
$webDllPath = 'C:\RTMView\Shell\CcDashboard.Web.dll'
$productVersion = ''
if (Test-Path -LiteralPath $webDllPath) { $productVersion = (Get-Item -LiteralPath $webDllPath).VersionInfo.ProductVersion }
Say ("  ProductVersion of CcDashboard.Web.dll : '" + $productVersion + "'")
Record "ProductVersion carries the commit 0ae2102" ($productVersion -like ('*' + $ExpectedCommitShort + '*')) ("expected to contain " + $ExpectedCommit)
$pdbRootFound = $false
$foreignRoots = @()
if (Test-Path -LiteralPath $webDllPath) {
  $bytes = [IO.File]::ReadAllBytes($webDllPath)
  $asText = [Text.Encoding]::ASCII.GetString($bytes)
  $pdbRootFound = $asText.Contains('rtm_clean_0ae2102')
  foreach ($foreign in @('Dropbox','IceDash','Program Files')) {
    $count = ([regex]::Matches($asText, [regex]::Escape($foreign))).Count
    if ($count -gt 0) { $foreignRoots += ($foreign + ' x' + $count) }
  }
}
Record "PDB root names the clean clone (rtm_clean_0ae2102)" $pdbRootFound 'searched the raw bytes of CcDashboard.Web.dll for the build path'
Record "no foreign build roots inside the binary" ($foreignRoots.Count -eq 0) ("found: " + $(if ($foreignRoots.Count) { ($foreignRoots -join ', ') } else { 'none' }))
Say  "  The PDB root is the WEAKER witness of the two and is reported BESIDE the byte match, never instead of it."
Rule

Say "5  CONFIG SET UNCHANGED - the installer must not have rewritten a single one"
foreach ($configPath in ($ExpectedConfigs.Keys | Sort-Object)) {
  $actualConfig = Get-Sha256Of $configPath
  Record ((Split-Path -Leaf $configPath) + " unchanged") ($actualConfig -eq $ExpectedConfigs[$configPath]) ($configPath + "  now " + $actualConfig)
}
Rule

Say "6  BACKUPS - the installer's own, and the one this flight must not have destroyed"
$backupDirs = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue)
Record ("backup directories = " + $ExpectedBackupDirs) ($backupDirs.Count -eq $ExpectedBackupDirs) ("found " + $backupDirs.Count + " (was 8 before the install)")
Record "the installer's pre-install backup exists" (Test-Path -LiteralPath $ExpectedNewBackup) $ExpectedNewBackup
$r4Files = 0
if (Test-Path -LiteralPath $RollbackBaseR4) { $r4Files = @(Get-ChildItem -LiteralPath $RollbackBaseR4 -Recurse -File -ErrorAction SilentlyContinue).Count }
Record "R4 base of 13.09 still intact (357 files)" ($r4Files -eq 357) ($RollbackBaseR4 + " -> " + $r4Files + " files")
Rule

Say "7  DATABASE UNCHANGED - F must equal F0 taken at step 1"
$shellConfig = 'C:\RTMView\Shell\appsettings.json'
$databaseUser = 'ccdashboard_user'
if (Test-Path -LiteralPath $shellConfig) {
  $shellJson = Get-Content -LiteralPath $shellConfig -Raw | ConvertFrom-Json
  $connectionString = "$($shellJson.ConnectionStrings.DefaultConnection)"
  if ($connectionString -match 'Username\s*=\s*([^;]+)') { $databaseUser = $Matches[1].Trim() }
}
$psqlPath = $null
foreach ($pgVersionDir in @(Get-ChildItem -LiteralPath 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
  $candidate = Join-Path $pgVersionDir.FullName 'bin\psql.exe'
  if ((Test-Path -LiteralPath $candidate) -and ($null -eq $psqlPath)) { $psqlPath = $candidate }
}
$fingerprintNow = 'NOT-TAKEN'
if ($null -eq $psqlPath) { Record "fingerprint F == F0" $false 'psql not found - this is a GAP, not a pass' }
else {
  $securePassword = Read-Host -Prompt ('Password for ' + $databaseUser + '@127.0.0.1:5433/rtmviewdb (SELECT only)') -AsSecureString
  if (-not $securePassword -or $securePassword.Length -eq 0) { Record "fingerprint F == F0" $false 'no password supplied - GAP, not a pass' }
  else {
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    try { $env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer) }
    $queryFile = Join-Path $env:TEMP ("step3_f_{0}.sql" -f $RunStamp)
    $queryText = @'
SELECT 'whoami|' || current_database() || '|' || inet_server_port() || '|' || current_user;
SELECT 'tables|' || count(*)::text FROM information_schema.tables WHERE table_schema='public';
SELECT 'routines|' || count(*)::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public';
SELECT 'columns|' || count(*)::text FROM information_schema.columns WHERE table_schema='public';
SELECT 'indexes|' || count(*)::text FROM pg_indexes WHERE schemaname='public';
SELECT 'tenants|' || count(*)::text FROM tenants;
SELECT 'users|' || count(*)::text FROM identity.users;
SELECT 'NEGCTL_zzz|' || coalesce(to_regclass('public."zzz_no_such_table"')::text,'NULL');
'@
    [IO.File]::WriteAllText($queryFile, $queryText, (New-Object System.Text.UTF8Encoding($false)))
    $queryRows = & $psqlPath -h 127.0.0.1 -p 5433 -U $databaseUser -d rtmviewdb -At -f $queryFile 2>&1
    $psqlExit = $LASTEXITCODE
    $env:PGPASSWORD = ''
    Remove-Item -LiteralPath $queryFile -ErrorAction SilentlyContinue
    foreach ($queryRow in $queryRows) { Say ("      " + $queryRow) }
    Say ("  psql exit code : " + $psqlExit)
    if ($psqlExit -eq 0) {
      $fingerprintLines = @($queryRows | Where-Object { "$_" -notlike 'whoami|*' } | Sort-Object)
      $hasher = [System.Security.Cryptography.SHA256]::Create()
      $fingerprintNow = ([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes(($fingerprintLines -join "`n"))))).Replace('-','')
    }
    Say ("  F  now : " + $fingerprintNow)
    Say ("  F0 was : " + $ExpectedFingerprint)
    Record "fingerprint F == F0 (this flight ran no migrations)" ($fingerprintNow -eq $ExpectedFingerprint) ''
  }
}
Rule

Say "VERDICT"
$greenCount = @($Checks | Where-Object { $_.Passed }).Count
$redChecks  = @($Checks | Where-Object { -not $_.Passed })
Say ("  checks green : " + $greenCount + " of " + $Checks.Count)
if ($redChecks.Count -gt 0) {
  Say ("  RED (" + $redChecks.Count + "):")
  foreach ($redCheck in $redChecks) { Say ("      " + $redCheck.Label) }
}
$accepted = ($redChecks.Count -eq 0)
Say ("  STEP 3 : " + $(if ($accepted) { 'ACCEPTED - the build on 234 is 0ae2102, by bytes and by provenance' } else { 'NOT ACCEPTED - the rollback block is in the step 2 report; decide before anything else runs' }))
Say  "  What this still does NOT prove: that the seven fixes WORK, and that anyone accepted 0ae2102 in origin."
Say  "  It proves which bytes are on the ground and where they came from. CMP-01 live acceptance is step 4."
Say "===== END-OF-RUN MARKER: STEP3-COMPLETE ====="
Finish $accepted
