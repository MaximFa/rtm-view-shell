#Requires -Version 5.1
<#
  PROBE  probe_234_20260919_deploy0ae2102-step1-v2.ps1
  V2     two faults of v1, both mine:
         (a) EVERY line that printed a sha256 was missing from the report - the helper failed silently and
             $ErrorActionPreference='Continue' swallowed it. v2 computes hashes inline and PRINTS THE ERROR
             when it cannot, so a missing hash can never again look like a line that was not asked for.
         (b) the DB password is not in the Shell connection string on this machine, so the floor was not
             taken and the verdict was NOT READY - correctly. v2 names the keys that ARE in the string
             (names only), looks in the other usual places, and if none has it, ASKS the operator with
             Read-Host -AsSecureString. The password is never printed and never written to the report.
  UNIT   PR234-DEPLOY-0ae2102 / STEP 1  (plan tools/plan_234_deploy_0ae2102.md, blob c73e3405)
  WHERE  SERVER 234 ONLY. G0 refuses to run anywhere else.
  WHAT   Pre-state before the install: services (pid, StartTime, ProductVersion), liveness TRIPLE,
         config sha256 set, database floor B1 (pg_dump) + fingerprint F0, free disk. Verdict READY / NOT READY.
  CHANGES  Nothing is started, stopped, installed or reconfigured. The ONLY write is the backup:
         C:\RTMView-Ops\backup\rtmviewdb_pre0ae2102_<stamp>.dump   (the R3 floor), plus the report under
         C:\RTMView-Ops\output\.
  ROLLBACK  Delete those two files. Nothing else was touched; no service state was changed.
  PASSWORD Read from the machine's own Shell config; only its length is printed.
#>

param(
  [switch]$NoPrompt   # do not ask for the DB password; then the floor is simply not taken
)

$ErrorActionPreference = 'Continue'
$stamp  = Get-Date -Format yyyyMMdd_HHmmss
$OutDir = 'C:\RTMView-Ops\output'
$BakDir = 'C:\RTMView-Ops\backup'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $BakDir | Out-Null
$outf = Join-Path $OutDir ("234_{0}_deploy0ae2102-step1.txt" -f $stamp)
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add("$s"); Write-Host "$s" }
function Line() { Say ('-' * 78) }
function Fin($pass) {
  [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host ""
  Write-Host ("REPORT: " + $outf)
  if ($pass) { exit 0 } else { exit 1 }
}
function H($p) {
  if (-not (Test-Path -LiteralPath $p)) { return 'ABSENT' }
  try { return (Get-FileHash -LiteralPath $p -Algorithm SHA256 -ErrorAction Stop).Hash }
  catch { return ('HASH-FAILED: ' + $_.Exception.GetType().Name + ': ' + $_.Exception.Message) }
}

Say ("STEP 1  pre-state  " + (Get-Date -Format u) + "   host=" + $env:COMPUTERNAME)
Say ("PS version: " + $PSVersionTable.PSVersion.ToString())
Line
Say "ROLLBACK FOR THIS RUN (printed before the only write):"
Say ("  Remove-Item '" + $BakDir + "\rtmviewdb_pre0ae2102_" + $stamp + ".dump'")
Say ("  Remove-Item '" + $outf + "'")
Say "  No service is started or stopped. No binary, no config, no schema is touched."
Line

# ---- G0: this probe refuses to run anywhere but 234 -------------------------
Say "G0  machine identity"
$nameOk = ($env:COMPUTERNAME -eq 'RTM')
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq 'E9516FFB-3068-47EA-8860-6A9D764325E6')
Say ("  name match " + $nameOk + " / uuid match " + $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say "  *** NOT server 234 - refusing to measure or write"; Fin $false }
Say "  G0 PASS"
Line

# ---- 1. services -------------------------------------------------------------
Say "1  services: state, pid, StartTime, and the ProductVersion of the exe actually on disk"
$svcNames = @('RTMService','RTMViewShell','RTMTwilio_1')
$svcState = @{}
foreach ($s in $svcNames) {
  $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $s) -ErrorAction SilentlyContinue
  if ($null -eq $svc) { Say ("  {0,-14} ABSENT" -f $s); $svcState[$s] = 'ABSENT'; continue }
  $svcState[$s] = $svc.State
  $pid_ = $svc.ProcessId
  $st = 'n/a'
  if ($pid_ -gt 0) {
    $p = Get-Process -Id $pid_ -ErrorAction SilentlyContinue
    if ($p) { $st = $p.StartTime.ToString('u') }
  }
  Say ("  {0,-14} {1,-9} pid {2,-7} started {3}" -f $svc.Name, $svc.State, $pid_, $st)
  Say ("      path  " + $svc.PathName)
  $exe = $svc.PathName
  if ($exe -match '^"([^"]+)"') { $exe = $Matches[1] } else { $exe = ($exe -split ' ')[0] }
  if (Test-Path -LiteralPath $exe) {
    $vi = (Get-Item -LiteralPath $exe).VersionInfo
    Say ("      exe   ProductVersion '" + $vi.ProductVersion + "'  FileVersion '" + $vi.FileVersion + "'")
    Say ("      exe   sha256 " + (H $exe))
  } else { Say "      exe   FILE NOT FOUND AT THAT PATH" }
}
Say "  NEGCTL a service that cannot exist:"
$neg = Get-CimInstance Win32_Service -Filter "Name='ZzzNoSuchServiceHere'" -ErrorAction SilentlyContinue
Say ("      returned " + $(if ($null -eq $neg) { 'ABSENT   (correct)' } else { '*** FOUND - the predicate is broken' }))
Line

# ---- 2. the shipped binaries whose bytes step 3 will compare -----------------
Say "2  binaries that the flight will re-measure after the install"
foreach ($f in @('C:\RTMView\Shell\CcDashboard.Web.dll','C:\RTMView\Shell\CcDashboard.Web.exe','C:\RTMView\RTM\RTM.exe')) {
  Say ("  " + $f)
  Say ("      sha256 " + (H $f))
  if (Test-Path -LiteralPath $f) {
    $i = Get-Item -LiteralPath $f
    Say ("      " + $i.Length + " B   modified " + $i.LastWriteTimeUtc.ToString('u') + "   ProductVersion '" + $i.VersionInfo.ProductVersion + "'")
  }
}
Say ("  NEGCTL hash of a path that cannot exist : " + (H 'C:\RTMView\zzz-no-such-file.dll') + "   (must be ABSENT)")
Line

# ---- 3. config set, by hash --------------------------------------------------
Say "3  config files, by sha256 (step 3 expects the SAME hashes - the installer must not rewrite them)"
$cfgs = @('C:\RTMView\Shell\appsettings.json','C:\RTMView\RTM\appsettings.json','C:\RTMView\RTM\log4net.config')
foreach ($c in $cfgs) { Say ("  {0,-42} {1}" -f $c, (H $c)) }
$rtmCfg = 'C:\RTMView\RTM\appsettings.json'
$shCfg  = 'C:\RTMView\Shell\appsettings.json'
$script:PW = $null
$script:DBUSER = 'ccdashboard_user'
$pipeName = 'rtmpipe_v3'
if (Test-Path -LiteralPath $rtmCfg) {
  $j = Get-Content -LiteralPath $rtmCfg -Raw | ConvertFrom-Json
  $pipeName = "$($j.RTM.PipeName)"
  Say ("  RTM PipeName            = '" + $pipeName + "'")
  Say ("  RTM AdaptorServiceName  = '" + $j.RTM.AdaptorServiceName + "'")
}
if (Test-Path -LiteralPath $shCfg) {
  $s = Get-Content -LiteralPath $shCfg -Raw | ConvertFrom-Json
  $scs = "$($s.ConnectionStrings.DefaultConnection)"
  if ($scs -match 'Port\s*=\s*(\d+)')      { Say ("  Shell conn Port         = " + $Matches[1]) }
  if ($scs -match 'Database\s*=\s*([^;]+)'){ Say ("  Shell conn Database     = " + $Matches[1].Trim()) }
  if ($scs -match 'Username\s*=\s*([^;]+)'){ $script:DBUSER = $Matches[1].Trim(); Say ("  Shell conn Username     = " + $script:DBUSER) }
  if ($scs -match 'Password\s*=\s*([^;]+)'){ $script:PW = $Matches[1].Trim(); Say ("  Shell conn Password     = present, " + $script:PW.Length + " characters (NOT printed)") }
  else {
    Say "  Shell conn Password     = NOT in this string. The KEYS that ARE in it (names only, no values):"
    foreach ($kv in ($scs -split ';')) { $k = ($kv -split '=')[0].Trim(); if ($k) { Say ("      " + $k) } }
  }
}
if (-not $script:PW) {
  Say "  looking in the other usual places (names and lengths only):"
  foreach ($alt in @('C:\RTMView\Shell\appsettings.Production.json','C:\RTMView\Shell\appsettings.Development.json')) {
    if (Test-Path -LiteralPath $alt) {
      try {
        $aj = Get-Content -LiteralPath $alt -Raw | ConvertFrom-Json
        $acs = "$($aj.ConnectionStrings.DefaultConnection)"
        if ($acs -match 'Password\s*=\s*([^;]+)') { $script:PW = $Matches[1].Trim(); Say ("      " + $alt + " : password present, " + $script:PW.Length + " characters") }
        else { Say ("      " + $alt + " : present, no Password in DefaultConnection") }
      } catch { Say ("      " + $alt + " : unreadable as JSON - " + $_.Exception.Message) }
    } else { Say ("      " + $alt + " : ABSENT") }
  }
  if (-not $script:PW -and $env:PGPASSWORD) { $script:PW = $env:PGPASSWORD; Say ("      environment PGPASSWORD : present, " + $script:PW.Length + " characters") }
  $pgpass = Join-Path $env:APPDATA 'postgresql\pgpass.conf'
  Say ("      " + $pgpass + " : " + $(if (Test-Path -LiteralPath $pgpass) { 'PRESENT (not parsed here)' } else { 'ABSENT' }))
}
if (-not $script:PW -and -not $NoPrompt) {
  Say "  none of the above has it. Asking the operator - typed characters are hidden, never printed, never written to the report."
  $sec = Read-Host -Prompt ("Password for " + $script:DBUSER + "@127.0.0.1:5433/rtmviewdb") -AsSecureString
  if ($sec -and $sec.Length -gt 0) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $script:PW = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    Say ("  operator supplied a password, " + $script:PW.Length + " characters (NOT printed)")
  } else { Say "  operator supplied nothing - the floor will not be taken and the verdict will be NOT READY" }
} elseif (-not $script:PW) { Say "  -NoPrompt was passed: not asking. The floor will not be taken." }
Line

# ---- 4. liveness TRIPLE ------------------------------------------------------
Say "4  liveness: pipe + engine listener + shell /health. One of the three alone is not liveness."
$curl = "$env:SystemRoot\System32\curl.exe"
$shell200 = $false; $engineAnswers = $false
if (-not (Test-Path -LiteralPath $curl)) {
  Say "  curl.exe ABSENT - HTTP not measured by an external process; NOT calling it green"
} else {
  $code = (& $curl -k -s -o NUL -w "%{http_code}" --max-time 15 "https://127.0.0.1:8444/health") 2>$null
  $negc = (& $curl -k -s -o NUL -w "%{http_code}" --max-time 15 "https://127.0.0.1:8444/zzz-no-such-endpoint") 2>$null
  Say ("  shell  https 8444 /health -> " + $code)
  Say ("  NEGCTL https 8444 /zzz    -> " + $negc + "   (200 here would void the line above)")
  $shell200 = (("$code" -eq '200') -and ("$negc" -ne '200'))
  $ecode = (& $curl -s -o NUL -w "%{http_code}" --max-time 10 "http://127.0.0.1:8089/") 2>$null
  Say ("  engine http 8089 /        -> " + $ecode + "   (the engine has NO /health route: ANY code means the listener answers; 000 means it does not)")
  $engineAnswers = ("$ecode" -ne '000' -and "$ecode" -ne '')
}
$pipes = @()
try { $pipes = @([IO.Directory]::GetFiles("\\.\pipe\") | ForEach-Object { $_.Substring(9) }) } catch { Say ("  pipe enumeration failed: " + $_.Exception.Message) }
Say ("  pipes visible in total : " + $pipes.Count + "   (0 here means the measurement is broken, not that there are none)")
$served = ($pipes -contains $pipeName)
Say ("  pipe '" + $pipeName + "' served : " + $served)
Say ("  NEGCTL impossible pipe served : " + ($pipes -contains 'zzz-no-such-pipe-here') + "   (must be False)")
$liveness = ($shell200 -and $served -and $engineAnswers)
Say ("  LIVENESS TRIPLE : " + $liveness)
Line

# ---- 5. database: floor B1 + fingerprint F0 ----------------------------------
Say "5  database on 5433: the R3 floor (pg_dump) and the fingerprint F0 that step 3 must reproduce"
$pgRoot = 'C:\Program Files\PostgreSQL'
$psql = $null; $pgdump = $null
foreach ($c in @(Get-ChildItem -LiteralPath $pgRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
  $a = Join-Path $c.FullName 'bin\psql.exe'; $b = Join-Path $c.FullName 'bin\pg_dump.exe'
  if ((Test-Path $a) -and ($null -eq $psql))   { $psql = $a }
  if ((Test-Path $b) -and ($null -eq $pgdump)) { $pgdump = $b }
}
$dbOk = $false; $F0 = 'NOT-TAKEN'; $dumpPath = Join-Path $BakDir ("rtmviewdb_pre0ae2102_{0}.dump" -f $stamp)
if ($null -eq $psql -or $null -eq $pgdump) { Say "  psql/pg_dump NOT FOUND - this is a GAP, not a pass. STOP: without the floor the flight has no R3." }
elseif (-not $script:PW) { Say "  no password from the Shell config - GAP, not a pass. STOP: no floor, no R3." }
else {
  Say ("  psql    : " + $psql)
  Say ("  pg_dump : " + $pgdump)
  $env:PGPASSWORD = $script:PW
  $sqlf = Join-Path $env:TEMP ("step1_f0_{0}.sql" -f $stamp)
  $sql = @'
SELECT 'whoami|' || current_database() || '|' || inet_server_port() || '|' || current_user;
SELECT 'tables|' || count(*)::text FROM information_schema.tables WHERE table_schema='public';
SELECT 'routines|' || count(*)::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public';
SELECT 'columns|' || count(*)::text FROM information_schema.columns WHERE table_schema='public';
SELECT 'indexes|' || count(*)::text FROM pg_indexes WHERE schemaname='public';
SELECT 'tenants|' || count(*)::text FROM tenants;
SELECT 'users|' || count(*)::text FROM identity.users;
SELECT 'NEGCTL_zzz|' || coalesce(to_regclass('public."zzz_no_such_table"')::text,'NULL');
'@
  [IO.File]::WriteAllText($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))
  $rows = & $psql -h 127.0.0.1 -p 5433 -U $script:DBUSER -d rtmviewdb -At -f $sqlf 2>&1
  $psqlExit = $LASTEXITCODE
  Remove-Item -LiteralPath $sqlf -ErrorAction SilentlyContinue
  foreach ($r in $rows) { Say ("      " + $r) }
  Say ("  psql exit code : " + $psqlExit)
  if ($psqlExit -eq 0) {
    $fpLines = @($rows | Where-Object { "$_" -notlike 'whoami|*' } | Sort-Object)
    $joined = ($fpLines -join "`n")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $F0 = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($joined)))).Replace('-','')
    Say ("  F0 (sha256 over the sorted lines above, 'whoami' excluded) : " + $F0)
    Say  "  Step 3 recomputes F0 the SAME way. F != F0 means the flight changed the schema, which it must not."

    Say "  taking the floor B1 (pg_dump, custom format) - THIS IS THE ONLY WRITE OF THIS PROBE"
    & $pgdump -h 127.0.0.1 -p 5433 -U $script:DBUSER -d rtmviewdb -F c --no-password -f $dumpPath 2>&1 | ForEach-Object { Say ("      " + $_) }
    $dumpExit = $LASTEXITCODE
    if ((Test-Path -LiteralPath $dumpPath) -and ((Get-Item -LiteralPath $dumpPath).Length -gt 0)) {
      $di = Get-Item -LiteralPath $dumpPath
      Say ("  dump    : " + $dumpPath)
      Say ("  bytes   : " + $di.Length + "   exit " + $dumpExit)
      Say ("  sha256  : " + (H $dumpPath))
      $dbOk = ($dumpExit -eq 0)
    } else {
      Say ("  *** pg_dump produced nothing usable (exit " + $dumpExit + "). A zero-byte or missing dump is NOT a floor.")
      if (Test-Path -LiteralPath $dumpPath) { Remove-Item -LiteralPath $dumpPath -Force; Say "  the empty file was removed so it cannot be mistaken for a backup" }
    }
  }
  $env:PGPASSWORD = ''
}
Line

# ---- 6. room and the backups that must survive -------------------------------
Say "6  disk and the backups the flight must not destroy"
foreach ($d in @('C','D')) {
  $dr = Get-PSDrive -Name $d -ErrorAction SilentlyContinue
  if ($dr) { Say ("  drive " + $d + ": free " + [math]::Round($dr.Free/1GB,1) + " GB of " + [math]::Round(($dr.Free+$dr.Used)/1GB,1) + " GB") }
}
$r4 = 'C:\RTMView\Backup\rtmtwilio_aa19743_20260913_011524'
Say ("  R4 base " + $r4)
if (Test-Path -LiteralPath $r4) {
  $cnt = @(Get-ChildItem -LiteralPath $r4 -Recurse -File -ErrorAction SilentlyContinue).Count
  Say ("      PRESENT, " + $cnt + " files   (the plan expects 357; -KeepBackups 50 is what protects it)")
} else { Say "      *** ABSENT - R4 is gone. Say so before the install, not after." }
$bk = @(Get-ChildItem -LiteralPath 'C:\RTMView\Backup' -Directory -ErrorAction SilentlyContinue)
Say ("  backup directories now : " + $bk.Count + "   (step 3 expects exactly one MORE than this)")
foreach ($b in ($bk | Sort-Object Name)) { Say ("      " + $b.Name) }
Line

# ---- verdict -----------------------------------------------------------------
$ready = ($liveness -and $dbOk)
Say "VERDICT"
Say ("  services   : RTMService=" + $svcState['RTMService'] + "  RTMViewShell=" + $svcState['RTMViewShell'] + "  RTMTwilio_1=" + $svcState['RTMTwilio_1'])
Say ("  liveness   : " + $liveness + "   (pipe + engine listener + shell /health, all three)")
Say ("  floor B1   : " + $(if ($dbOk) { 'TAKEN  ' + $dumpPath } else { 'NOT TAKEN' }))
Say ("  F0         : " + $F0)
Say ("  READY FOR STEP 2 : " + $(if ($ready) { 'READY' } else { 'NOT READY - step 2 must not be issued' }))
Say "  Nothing was started, stopped or changed by this probe."
Say "===== END-OF-RUN MARKER: STEP1-COMPLETE ====="
Fin $ready
