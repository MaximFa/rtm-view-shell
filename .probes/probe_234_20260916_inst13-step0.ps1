#Requires -Version 5.1
<#
  PROBE 234 / inst13-step0          PR234-INST-13 acceptance on 234 - STEP 0: BEFORE, BACKUP, READINESS.
  WHERE IT RUNS : server 234 (hostname "RTM"). Anything else aborts.
  SERVICES      : NOT touched. Read only: RTMService, RTMViewShell, RTMTwilio_1.
  DATABASE      : rtmviewdb on 5433 - READ ONLY (pg_dump + fingerprint). 5432 not touched.
  WRITES        : C:\RTMView-Ops\backup\inst13_<stamp>\   (config copies, rtmviewdb.dump, F0.txt)
                  C:\RTMView-Ops\inst13dry_<stamp>\       (pkg\Update-RTMView.ps1 + empty root\)
                  C:\RTMView-Ops\output\234_<stamp>_inst13-step0.txt
  PERIMETER     : C:\IceDash\, RTM.Twilio (production), C:\Program Files\CcDashboard\ - not read, not touched.
  Plan          : tools/plan_234_inst13_dry_ADE.md (coordinator section-4 PASS 2026-09-16). Author devops-0916.
  Needs, in C:\RTMView-Ops\incoming\ next to this file:
     inst13_Update-RTMView_cf619dbb_shipped.ps1   (the subject, as the builder ships it: UTF-8 BOM + CRLF)
#>
$ErrorActionPreference = 'Continue'
$SENTINEL = -999
$SUBJ_SHA = '7EF750E83D8A6146ED39FF3C3041DC666F120BCD1CA2FBF5AABF715DB69E9CC0'
$STAMP = (Get-Date).ToString('yyyyMMdd_HHmmss')
$OPS = 'C:\RTMView-Ops'
$IN = Join-Path $OPS 'incoming'
$OUT = Join-Path $OPS 'output'
$BK = Join-Path $OPS ('backup\inst13_' + $STAMP)
$DRY = Join-Path $OPS ('inst13dry_' + $STAMP)
$REPORT = Join-Path $OUT ('234_' + $STAMP + '_inst13-step0.txt')
$PGBIN = 'C:\Program Files\PostgreSQL\18\bin'
$Lines = New-Object System.Collections.ArrayList
$Bad = New-Object System.Collections.ArrayList
function Say($t) { [void]$Lines.Add([string]$t); Write-Host $t }
function Fail($t) { [void]$Bad.Add([string]$t); Say ('  [RED] ' + $t) }
function Flush { try { New-Item -ItemType Directory -Path $OUT -Force | Out-Null; [IO.File]::WriteAllLines($REPORT, [string[]]$Lines, (New-Object Text.UTF8Encoding($false))) } catch { Write-Host ('report write failed: ' + $_) } }
function Abort($t) { Say ''; Say ('*** ABORT: ' + $t); Say 'STEP0: NOT READY'; Say 'LAST LINE: FAIL'; Flush; Write-Host ('report: ' + $REPORT); exit 2 }
function Safe-Count($c) { if ($null -eq $c) { return $SENTINEL }; return @($c).Count }
function Sha($p) { return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash }
function Snap($n) {
    $w = Get-CimInstance Win32_Service -Filter ("Name='" + $n + "'") -ErrorAction SilentlyContinue
    if ($null -eq $w) { return [pscustomobject]@{ Name=$n; State='ABSENT'; Pid=0; Start='-'; Path='-' } }
    $st = '-'; if ($w.ProcessId -gt 0) { $p = Get-Process -Id $w.ProcessId -ErrorAction SilentlyContinue; if ($p) { $st = $p.StartTime.ToString('yyyy-MM-dd HH:mm:ss') } }
    return [pscustomobject]@{ Name=$n; State=[string]$w.State; Pid=[int]$w.ProcessId; Start=$st; Path=[string]$w.PathName }
}

Say '===== PROBE 234 / inst13-step0 ====='
Say ('WHERE IT RUNS : ' + $env:COMPUTERNAME + ' (want RTM = 234) | PS ' + $PSVersionTable.PSVersion + ' ' + $PSVersionTable.PSEdition + ' | now ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
Say ('STAMP         : ' + $STAMP + '   <- steps 1-4 use this stamp')
Say 'EXPECTATIONS  : host RTM, elevated, Desktop | 3 services Running | liveness engine /health 200 AND pipe from RTM:PipeName present | shell /health 200'
Say '                ProductVersion RTM.dll +621a797, CcDashboard.Web.dll +621a797, RTM.Twilio.dll +8d28531 (printed, mismatch = RED)'
Say '                config copies sha256 == source | pg_dump rc 0, size > 0, pg_restore --list entries > 0 | F0 printed | subject sha256 == ' + $SUBJ_SHA + ', parse errors 0'
Say ''

$gA = Safe-Count $null; $gB = Safe-Count @(); $gC = Safe-Count @('x','y')
Say ('self-gate Safe-Count : {0}/{1}/{2} (want {3}/0/2)' -f $gA, $gB, $gC, $SENTINEL)
if (-not (($gA -eq $SENTINEL) -and ($gB -eq 0) -and ($gC -eq 2))) { Abort 'Safe-Count gate broken' }

if ($env:COMPUTERNAME -ne 'RTM') { Abort ('host is "' + $env:COMPUTERNAME + '", not 234 ("RTM")') }
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Say ('elevated : ' + $admin); if (-not $admin) { Abort 'not elevated' }
if ($PSVersionTable.PSEdition -ne 'Desktop') { Abort 'run under Windows PowerShell 5.1' }
foreach ($d in @($BK, $DRY)) { if (Test-Path $d) { Abort ('already exists: ' + $d) } }

# ---- 1. services ----
Say ''; Say '--- 1. services (read only) ---'
foreach ($n in @('RTMService','RTMViewShell','RTMTwilio_1')) {
    $s = Snap $n
    Say ('  {0,-13} state={1,-8} pid={2,-6} StartTime={3}  path={4}' -f $s.Name, $s.State, $s.Pid, $s.Start, $s.Path)
    if ($s.State -ne 'Running') { Fail ($n + ' not Running') }
    if ($s.Path -notlike '*C:\RTMView\*') { Fail ($n + ' binary is not under C:\RTMView - not ours?') }
}

# ---- 2. config: only named keys ----
Say ''; Say '--- 2. config, named keys only (no secrets printed) ---'
$rtmCfg = $null; $shCfg = $null
try { $rtmCfg = Get-Content -LiteralPath 'C:\RTMView\RTM\appsettings.json' -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Fail ('RTM appsettings.json unreadable: ' + $_.Exception.Message) }
try { $shCfg = Get-Content -LiteralPath 'C:\RTMView\Shell\appsettings.json' -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Fail ('Shell appsettings.json unreadable: ' + $_.Exception.Message) }
$pipeName = $null; $engUrl = $null; $shPort = $null
if ($rtmCfg) {
    $pipeName = [string]$rtmCfg.RTM.PipeName
    $engUrl = [string]$rtmCfg.Kestrel.Endpoints.Http.Url
    Say ('  RTM:PipeName = "' + $pipeName + '" | RTM Kestrel Http.Url = "' + $engUrl + '" | RTM:AdaptorServiceName = "' + [string]$rtmCfg.RTM.AdaptorServiceName + '"')
}
if ($shCfg) {
    $httpsUrl = [string]$shCfg.Kestrel.Endpoints.Https.Url
    if ($httpsUrl -match ':(\d+)\s*$') { $shPort = $Matches[1] }
    Say ('  Shell Kestrel Https.Url = "' + $httpsUrl + '" -> port ' + $shPort)
}
if (-not $pipeName) { Fail 'RTM:PipeName empty' }
if (-not $engUrl) { Fail 'engine Kestrel Http.Url empty' }
if (-not $shPort) { Fail 'shell https port not found' }

# ---- 3. liveness ----
Say ''; Say '--- 3. liveness (curl.exe; Invoke-WebRequest is not a negative witness on PS 5.1) ---'
$pipes = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) })
$pipeHit = @($pipes | Where-Object { $_ -eq $pipeName }).Count
Say ('  pipes on host {0} (POSCTL: > 0) | "{1}" present {2} (want 1)' -f $pipes.Count, $pipeName, $pipeHit)
if ($pipes.Count -eq 0) { Fail 'pipe listing empty - instrument broken' }
if ($pipeHit -ne 1) { Fail 'engine pipe absent' }
if ($engUrl) {
    $e = & curl.exe -s -o NUL -w '%{http_code}' --max-time 10 ($engUrl.TrimEnd('/') + '/health')
    Say ('  engine ' + $engUrl + '/health -> ' + $e + ' (want 200)'); if ("$e" -ne '200') { Fail 'engine /health not 200' }
}
if ($shPort) {
    $h = & curl.exe -k -s -o NUL -w '%{http_code}' --max-time 10 ('https://localhost:' + $shPort + '/health')
    $neg = & curl.exe -k -s -o NUL -w '%{http_code}' --max-time 5 ('https://localhost:' + ([int]$shPort + 1) + '/health')
    Say ('  shell https://localhost:' + $shPort + '/health -> ' + $h + ' (want 200) | NEGCTL port ' + ([int]$shPort + 1) + ' -> ' + $neg + ' (want 000)')
    if ("$h" -ne '200') { Fail 'shell /health not 200' }
    if ("$neg" -eq '200') { Fail 'NEGCTL answered 200 - curl check does not discriminate' }
}

# ---- 4. installed build ----
Say ''; Say '--- 4. installed build ---'
foreach ($pair in @(@('C:\RTMView\RTM\RTM.dll','621a797'), @('C:\RTMView\Shell\CcDashboard.Web.dll','621a797'), @('C:\RTMView\RTM.Twilio\RTM.Twilio.dll','8d28531'))) {
    if (Test-Path -LiteralPath $pair[0]) {
        $pv = (Get-Item -LiteralPath $pair[0]).VersionInfo.ProductVersion
        $ok = $pv -like ('*+' + $pair[1] + '*')
        Say ('  {0} PV={1} want +{2} -> {3}' -f $pair[0], $pv, $pair[1], $ok)
        if (-not $ok) { Fail ($pair[0] + ' is not +' + $pair[1]) }
    } else { Fail ($pair[0] + ' missing') }
}

# ---- 5. backup B1: configs ----
Say ''; Say '--- 5. BACKUP B1: configs (sha256 of source == copy; values never printed) ---'
New-Item -ItemType Directory -Path (Join-Path $BK 'cfg') -Force | Out-Null
$cfgList = @('C:\RTMView\RTM\appsettings.json','C:\RTMView\RTM\data.sys','C:\RTMView\RTM\log4net.config','C:\RTMView\Shell\appsettings.json','C:\RTMView\RTM.Twilio\appsettings.json','C:\RTMView\RTM.Twilio\log4net.config')
$manifest = New-Object System.Collections.ArrayList
foreach ($src in $cfgList) {
    if (-not (Test-Path -LiteralPath $src)) { Say ('  absent (not copied): ' + $src); [void]$manifest.Add('ABSENT ' + $src); continue }
    $dst = Join-Path (Join-Path $BK 'cfg') (($src.Substring(3)) -replace '[\\:]', '__')
    Copy-Item -LiteralPath $src -Destination $dst -Force
    $a = Sha $src; $b = Sha $dst
    Say ('  {0} -> {1} | {2} == {3} : {4}' -f $src, (Split-Path $dst -Leaf), $a.Substring(0,12), $b.Substring(0,12), ($a -eq $b))
    if ($a -ne $b) { Fail ('copy mismatch ' + $src) }
    [void]$manifest.Add($a + ' ' + $src)
}
[IO.File]::WriteAllLines((Join-Path $BK 'cfg_manifest.txt'), [string[]]$manifest, (New-Object Text.UTF8Encoding($false)))

# ---- 6. backup B2: rtmviewdb + fingerprint F0 ----
Say ''; Say '--- 6. BACKUP B2: pg_dump rtmviewdb @5433 + fingerprint F0 ---'
$pgDump = Join-Path $PGBIN 'pg_dump.exe'; $pgRestore = Join-Path $PGBIN 'pg_restore.exe'; $psql = Join-Path $PGBIN 'psql.exe'
foreach ($t in @($pgDump, $pgRestore, $psql)) { if (-not (Test-Path -LiteralPath $t)) { Abort ('missing ' + $t) } }
$sec = Read-Host -AsSecureString 'postgres password for 127.0.0.1:5433'
$pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
Say ('  password length : ' + $pw.Length)
if ($pw.Length -eq 0) { Abort 'empty password' }
$env:PGPASSWORD = $pw; $pw = $null
$ver = & $psql -h 127.0.0.1 -p 5433 -U postgres -d rtmviewdb -At -v ON_ERROR_STOP=1 -c 'SELECT version()' 2>&1
Say ('  version() : ' + ($ver | Select-Object -First 1))
& $psql -h 127.0.0.1 -p 5433 -U postgres -d rtmviewdb -At -v ON_ERROR_STOP=1 -c 'SELECT * FROM inst13_table_that_cannot_exist' *> $null
$negRc = $LASTEXITCODE
Say ('  psql NEGCTL rc=' + $negRc + ' (want non-zero)'); if ($negRc -eq 0) { Remove-Item Env:\PGPASSWORD; Abort 'psql rc is not a gate' }
$sqlF = Join-Path $BK 'F0.sql'
$sql = @"
SELECT 'tables_public', count(*)::text FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'
UNION ALL SELECT 'routines_public', count(*)::text FROM information_schema.routines WHERE routine_schema='public'
UNION ALL SELECT 'columns_md5', md5(string_agg(table_name||'.'||column_name||':'||data_type, ',' ORDER BY table_name, ordinal_position)) FROM information_schema.columns WHERE table_schema='public'
UNION ALL SELECT 'migration_tables', string_agg(table_schema||'.'||table_name, ',') FROM information_schema.tables WHERE table_name ILIKE '%migrationshistory%'
UNION ALL SELECT 'databases_like_inst13', count(*)::text FROM pg_database WHERE datname LIKE 'inst13dry%';
"@
[IO.File]::WriteAllText($sqlF, $sql, (New-Object Text.UTF8Encoding($false)))
$f0 = & $psql -h 127.0.0.1 -p 5433 -U postgres -d rtmviewdb -At -F '=' -v ON_ERROR_STOP=1 -f $sqlF 2>&1
$f0Rc = $LASTEXITCODE
Say ('  F0 rc=' + $f0Rc); foreach ($l in @($f0)) { Say ('    ' + $l) }
if ($f0Rc -ne 0) { Fail 'F0 query failed' }
[IO.File]::WriteAllLines((Join-Path $BK 'F0.txt'), [string[]]@($f0 | ForEach-Object { "$_" }), (New-Object Text.UTF8Encoding($false)))
$dump = Join-Path $BK 'rtmviewdb.dump'
$t0 = Get-Date
& $pgDump -h 127.0.0.1 -p 5433 -U postgres -Fc -f $dump rtmviewdb 2> (Join-Path $BK 'pg_dump.stderr.txt')
$dRc = $LASTEXITCODE
$dSize = if (Test-Path -LiteralPath $dump) { (Get-Item -LiteralPath $dump).Length } else { 0 }
$list = @(& $pgRestore --list $dump 2>$null | Where-Object { $_ -and $_ -notmatch '^;' })
Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
Say ('  pg_dump rc={0} size={1} B in {2:N0} s | pg_restore --list entries={3} (want rc 0, size > 0, entries > 0)' -f $dRc, $dSize, ((Get-Date) - $t0).TotalSeconds, $list.Count)
if ($dRc -ne 0 -or $dSize -le 0 -or $list.Count -le 0) { Fail 'database backup not proven readable' }

# ---- 7. subject staged + A ----
Say ''; Say '--- 7. subject staged + A (parse) ---'
$subj = Join-Path $IN 'inst13_Update-RTMView_cf619dbb_shipped.ps1'
if (-not (Test-Path -LiteralPath $subj)) { Abort ('subject missing: ' + $subj) }
$ss = Sha $subj
Say ('  subject sha256 ' + $ss + ' want ' + $SUBJ_SHA + ' -> ' + ($ss -eq $SUBJ_SHA))
if ($ss -ne $SUBJ_SHA) { Abort 'subject is not the reviewed file' }
New-Item -ItemType Directory -Path (Join-Path $DRY 'pkg') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $DRY 'root') -Force | Out-Null
$staged = Join-Path $DRY 'pkg\Update-RTMView.ps1'
Copy-Item -LiteralPath $subj -Destination $staged -Force
Set-Content -LiteralPath (Join-Path $DRY '.origin') -Value ('inst13 step0 ' + $STAMP + ' RTM subject ' + $SUBJ_SHA) -Encoding ASCII
$pkgItems = @(Get-ChildItem -LiteralPath (Join-Path $DRY 'pkg') -Force)
$rootItems = @(Get-ChildItem -LiteralPath (Join-Path $DRY 'root') -Force)
Say ('  pkg entries {0} (want 1: no Shell\ RTM\ Extras\ db\) | root entries {1} (want 0)' -f $pkgItems.Count, $rootItems.Count)
if ($pkgItems.Count -ne 1 -or $rootItems.Count -ne 0) { Fail 'staging not bare' }
$errs = $null; $toks = $null
[Management.Automation.Language.Parser]::ParseFile($staged, [ref]$toks, [ref]$errs) | Out-Null
$nErr = Safe-Count $errs
$e2 = $null; [Management.Automation.Language.Parser]::ParseInput('if (', [ref]$toks, [ref]$e2) | Out-Null
Say ('  A: parse errors {0} (want 0) | NEGCTL broken input errors {1} (want > 0)' -f $nErr, (Safe-Count $e2))
if ((Safe-Count $e2) -le 0) { Fail 'parser NEGCTL returned 0' }
if ($nErr -ne 0) { Fail ('A red: ' + $nErr + ' parse errors') }
$A = if ($nErr -eq 0) { 'GREEN' } else { 'RED' }

Say ''
Say ('RED items : ' + $Bad.Count); foreach ($b in $Bad) { Say ('  - ' + $b) }
Say ('A         : ' + $A)
Say ('backup    : ' + $BK)
Say ('staging   : ' + $DRY)
Say ('STEP0     : ' + $(if ($Bad.Count -eq 0) { 'READY (stamp ' + $STAMP + ')' } else { 'NOT READY' }))
Say ('LAST LINE : ' + $(if ($Bad.Count -eq 0) { 'PASS' } else { 'FAIL' }))
Say '===== END ====='
Flush
Write-Host ''; Write-Host ('report : ' + $REPORT)
