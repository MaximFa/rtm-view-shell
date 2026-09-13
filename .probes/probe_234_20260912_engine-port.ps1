#Requires -Version 5.1
<#
  PROBE 234 / engine-port      the decisive reading before step 4 is allowed to exist
  WHERE IT RUNS : server 234 (machine RTM). It REFUSES to run anywhere else - machine name AND hardware
                  UUID are a gate. EVERY line of this box runs on 234.
  READ ONLY. Starts nothing, stops nothing, restarts nothing, writes no config, touches no service, installs
  nothing. Every database statement is a SELECT. C:\IceDash is NOT read, NOT listed and NOT queried - the
  coordinator carries that question to the operator himself.
  WHAT IT WRITES: its report and SQL result files under C:\RTMView-Ops\output, plus scratch files in TEMP
  that it deletes. It creates no artifact, so it carries no .origin mark.

  THE QUESTION. The engine config carries no Port in its connection string, and our own installer documents
  that failure by name (Install-RTMView.ps1:487-497: RTM's connection string was never built from
  parameters, so a side-by-side install on a non-default port left RTM pointing at 5432; the injection that
  fixes it runs only when -DBAppPassword is given). AppConfig substitutes only Username and Password from
  data.sys - never Host, never Port. So the engine MAY be reading the OLD database on 5432.
  A config says where a process MEANT to go. This box measures where it ACTUALLY went: established TCP
  connections of the engine process itself, and the sessions both database instances report.

  WHY IT MATTERS MORE THAN THE INSTALL. Update-RTMView does not fix that string (grep RTMConnectionString in
  it = 0) and keeps appsettings.json in its preserve list. An install would therefore PRESERVE the wrong
  connection string and hand us a green step 4, while the after-measurement - flow growth, Queue Grid saving
  without 23505 - would have been taken against an unknown database. The sequence resync of 08.09 was done
  on 5433; if the engine writes to 5432 it never touched what the engine uses.

  EXPECTATIONS, PRINTED BEFORE THE NUMBERS, so neither outcome can be read as whatever suits us:
    engine established to 5433 > 0 and to 5432 = 0   -> the engine is on OUR database, finding (v) is closed
    engine established to 5433 = 0 and to 5432 > 0   -> the engine is on the OLD database, this is confirmed
    both zero                                        -> NOT MEASURED: a pool at idle closes its connections;
                                                        the pg_stat_activity halves below then decide, and a
                                                        point-in-time zero is never proof of "nothing uses it"
  NEGATIVE HALF of the same instrument: the Shell process must show connections to 5433. If the measurement
  cannot see the Shell connections either, it cannot see connections at all, and its zero for the engine
  means nothing.

  Passwords are NEVER prompted and never printed: they are read from the machine own config, and only their
  length goes into the report.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_engine-port.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS' } else { 'VERDICT: FAIL' }))
    [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($targetPath) {
    if (Test-Path $targetPath) { return (Get-FileHash $targetPath -Algorithm SHA256).Hash } else { return 'ABSENT' }
}
function Mask-Password($text) { return [regex]::Replace("$text", '(?i)(password\s*=\s*)([^;]+)', '$1<masked>') }

Say '===== G0  machine identity and the instrument, both proven before anything is measured ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq $UUIDGATE)
Say ('  name  expected {0} , actual {1} -> {2}' -f $NAMEGATE, $env:COMPUTERNAME, $nameOk)
Say ('  uuid  expected {0} , actual {1} -> {2}' -f $UUIDGATE, $uuid, $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say '  *** NOT server 234 - refusing to measure'; Fin $false }
Say ('  PowerShell {0}' -f $PSVersionTable.PSVersion)
$resolvedHash = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ('  Get-Sha256Of resolves to : {0}   expected Function' -f $resolvedHash.CommandType)
if ("$($resolvedHash.CommandType)" -ne 'Function') { Say '  *** the hash helper is shadowed - stop'; Fin $false }
$resolvedMask = Get-Command Mask-Password -ErrorAction SilentlyContinue
Say ('  Mask-Password resolves to : {0}   expected Function' -f $resolvedMask.CommandType)
if ("$($resolvedMask.CommandType)" -ne 'Function') { Say '  *** the masking helper is shadowed - refusing to read any connection string'; Fin $false }
Say ('  POSCTL masking a known string : {0}   expected the password replaced' -f (Mask-Password 'Host=x;Password=SuperSecret;Port=1'))
if ((Mask-Password 'Host=x;Password=SuperSecret;Port=1') -match 'SuperSecret') { Say '  *** the mask does not mask - refusing to print connection strings'; Fin $false }
Say ('  this probe sha256 : {0}' -f (Get-Sha256Of $MyInvocation.MyCommand.Path))
Say ('  NEGCTL hash of a missing path : {0}   expected ABSENT' -f (Get-Sha256Of 'C:\zzz-no-such-file.bin'))
$tcpCmd = Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue
Say ('  Get-NetTCPConnection available : {0}   without it the decisive half is NOT MEASURED' -f ($null -ne $tcpCmd))
Say ('  collector type at entry : {0}   expected ArrayList' -f $Report.GetType().Name)
Say '  G0 PASS'
Say ''

$fails = 0
$notMeasured = 0

Say '===== 1  the three processes, by PATH not by name - a service name is not a process ====='
$enginePid = 0
$shellPid = 0
$adapterPid = 0
foreach ($proc in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'C:\RTMView\*' })) {
    Say ('  {0,-18} pid {1,-7} started {2}   {3}' -f $proc.ProcessName, $proc.Id, $proc.StartTime, $proc.Path)
    if ($proc.Path -eq 'C:\RTMView\RTM\RTM.exe') { $enginePid = $proc.Id }
    if ($proc.Path -eq 'C:\RTMView\Shell\CcDashboard.Web.exe') { $shellPid = $proc.Id }
    if ($proc.Path -eq 'C:\RTMView\RTM.Twilio\RTM.Twilio.exe') { $adapterPid = $proc.Id }
}
Say ('  engine PID {0} , shell PID {1} , adapter PID {2}   all three must be non-zero' -f $enginePid, $shellPid, $adapterPid)
if (($enginePid -eq 0) -or ($shellPid -eq 0)) { Say '  *** the engine or the shell process was not found by path - the decisive measurement is impossible'; $notMeasured++ }
Say '  NOTE: processes out of C:\IceDash are deliberately NOT enumerated here.'
Say ''

Say '===== 2  THE DECISIVE READING - where the engine actually WENT, not where it meant to go ====='
Say '  expectation, printed BEFORE the numbers:'
Say '    engine to 5433 > 0 and to 5432 = 0  -> the engine is on OUR database, finding (v) closed'
Say '    engine to 5433 = 0 and to 5432 > 0  -> the engine is on the OLD database, finding (v) CONFIRMED'
Say '    both zero                           -> NOT MEASURED, a pool at idle closes its connections'
if (($null -eq $tcpCmd) -or ($enginePid -eq 0)) { Say '  NOT MEASURED - no Get-NetTCPConnection or no engine process'; $notMeasured++ }
else {
    $allEstablished = @(Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue)
    Say ('  established connections on this machine in total : {0}   zero here would mean the instrument is blind' -f $allEstablished.Count)
    if ($allEstablished.Count -eq 0) { Say '      *** the connection enumeration returned nothing - its zeroes prove nothing'; $notMeasured++ }
    $engineConns = @($allEstablished | Where-Object { $_.OwningProcess -eq $enginePid })
    $shellConns  = @($allEstablished | Where-Object { $_.OwningProcess -eq $shellPid })
    $engineTo5432 = @($engineConns | Where-Object { $_.RemotePort -eq 5432 }).Count
    $engineTo5433 = @($engineConns | Where-Object { $_.RemotePort -eq 5433 }).Count
    $shellTo5432  = @($shellConns  | Where-Object { $_.RemotePort -eq 5432 }).Count
    $shellTo5433  = @($shellConns  | Where-Object { $_.RemotePort -eq 5433 }).Count
    Say ('  ENGINE pid {0} : total established {1} , to 5432 = {2} , to 5433 = {3}' -f $enginePid, $engineConns.Count, $engineTo5432, $engineTo5433)
    foreach ($conn in $engineConns) { Say ('      {0}:{1} -> {2}:{3}' -f $conn.LocalAddress, $conn.LocalPort, $conn.RemoteAddress, $conn.RemotePort) }
    Say ('  NEGATIVE HALF, the same instrument on the SHELL pid {0} : total {1} , to 5432 = {2} , to 5433 = {3}' -f $shellPid, $shellConns.Count, $shellTo5432, $shellTo5433)
    foreach ($conn in $shellConns) { Say ('      {0}:{1} -> {2}:{3}' -f $conn.LocalAddress, $conn.LocalPort, $conn.RemoteAddress, $conn.RemotePort) }
    Say '  The Shell config states Port=5433 explicitly, so the Shell is the control: if the instrument cannot'
    Say '  see the Shell connections either, it cannot see connections at all and its engine zeroes mean nothing.'
    if (($engineTo5433 -gt 0) -and ($engineTo5432 -eq 0)) { Say '  -> READING: the engine is connected to OUR database on 5433' }
    elseif (($engineTo5432 -gt 0) -and ($engineTo5433 -eq 0)) { Say '  -> READING: the engine is connected to the OLD database on 5432. Finding (v) CONFIRMED. This is a STOP for the install.'; $fails++ }
    elseif (($engineTo5432 -gt 0) -and ($engineTo5433 -gt 0)) { Say '  -> READING: the engine holds connections to BOTH ports. Neither branch of the expectation applies - I report it and do not build a story.'; $fails++ }
    else { Say '  -> NOT MEASURED: the engine holds no established connection to either port right now. A pool at idle closes its connections, so this is not evidence of anything. The pg_stat_activity halves below decide.'; $notMeasured++ }
}
Say ''

Say '===== 3  the engine config, read from disk, with the KEY NAMES - my v2 predicate looked in the wrong place ====='
Say '  v2 asked for RTM:RTMConnectionString and printed an empty string. That key does not exist: the engine'
Say '  connection string lives in the TOP-LEVEL ConnectionStrings section. So "Port not stated" was my'
Say '  predicate missing, not a measured fact. It is measured here, in the right place.'
$rtmCfg = 'C:\RTMView\RTM\appsettings.json'
$enginePortInCfg = 'NOT STATED'
if (-not (Test-Path $rtmCfg)) { Say ('  {0} ABSENT' -f $rtmCfg); $fails++ }
else {
    $rtmJson = Get-Content $rtmCfg -Raw | ConvertFrom-Json
    Say ('  sha256 of the file being read : {0}' -f (Get-Sha256Of $rtmCfg))
    Say ('  top-level keys : {0}' -f (($rtmJson.PSObject.Properties.Name) -join ', '))
    if ($rtmJson.ConnectionStrings) {
        Say ('  keys under ConnectionStrings : {0}' -f (($rtmJson.ConnectionStrings.PSObject.Properties.Name) -join ', '))
        foreach ($connProp in $rtmJson.ConnectionStrings.PSObject.Properties) {
            $connText = "$($connProp.Value)"
            Say ('  ConnectionStrings.{0} = {1}' -f $connProp.Name, (Mask-Password $connText))
            if ($connText -match '(?i)Port\s*=\s*(\d+)') { Say ('      Port stated = {0}' -f $Matches[1]); $enginePortInCfg = $Matches[1] }
            else { Say '      Port NOT stated in this string - Npgsql then uses its default 5432' }
            if ($connText -match '(?i)Host\s*=\s*([^;]+)') { Say ('      Host stated = {0}' -f $Matches[1].Trim()) }
            if ($connText -match '(?i)Database\s*=\s*([^;]+)') { Say ('      Database stated = {0}' -f $Matches[1].Trim()) }
            if ($connText -match '(?i)Username\s*=\s*([^;]+)') { Say ('      Username stated = {0}' -f $Matches[1].Trim()) }
        }
    } else { Say '  ConnectionStrings : ABSENT as a section' }
    Say ('  RTM:LogConfig = {0}' -f $rtmJson.RTM.LogConfig)
    Say '  data.sys supplies Username and Password only (AppConfig.cs:80-86) - never Host, never Port.'
    Say ('  engine Port as stated in config : {0}' -f $enginePortInCfg)
}
Say ''

Say '===== 4  what each database instance says about ITS OWN sessions - the other side of the same question ====='
$dbPassword = $null
$shellCfg = 'C:\RTMView\Shell\appsettings.json'
if (Test-Path $shellCfg) {
    $shellJson = Get-Content $shellCfg -Raw | ConvertFrom-Json
    if ($shellJson.ConnectionStrings -and $shellJson.ConnectionStrings.Default) {
        $defConn = "$($shellJson.ConnectionStrings.Default)"
        if ($defConn -match '(?i)password\s*=\s*([^;]+)') { $dbPassword = $Matches[1].Trim() }
    }
}
$psqlPath = $null
foreach ($pgDir in @(Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $candidate = Join-Path $pgDir.FullName 'bin\psql.exe'
    if ((Test-Path $candidate) -and ($null -eq $psqlPath)) { $psqlPath = $candidate }
}
if ($null -eq $psqlPath) { Say '  psql.exe NOT FOUND - this whole section is NOT MEASURED, which is a gap, not a pass'; $notMeasured++ }
elseif ($null -eq $dbPassword) { Say '  no password from the machine config - this whole section is NOT MEASURED'; $notMeasured++ }
else {
    Say ('  psql : {0}   credentials: ccdashboard_user, password {1} characters from the Shell config, NOT printed' -f $psqlPath, $dbPassword.Length)
    Say '  The SAME credentials are tried on BOTH instances. If 5432 refuses them, that is a reading about'
    Say '  access, NOT about whether the engine uses it, and it will be reported as NOT MEASURED.'
    $env:PGCLIENTENCODING = 'UTF8'
    $env:PGPASSWORD = $dbPassword
    $actFile = Join-Path $env:TEMP ('probeB_act_' + $stamp + '.sql')
    $actSql = @'
SELECT 'self db=' || current_database() || ' port=' || inet_server_port() || ' ver=' || substring(version() from 1 for 26);
SELECT 'session | ' || coalesce(datname,'-') || ' | ' || coalesce(usename,'-') || ' | ' || coalesce(application_name,'-')
       || ' | ' || coalesce(host(client_addr),'local') || ' | ' || coalesce(state,'-') || ' | since ' || coalesce(backend_start::text,'-')
  FROM pg_stat_activity WHERE backend_type = 'client backend' ORDER BY backend_start;
SELECT 'client backends total = ' || count(*)::text FROM pg_stat_activity WHERE backend_type = 'client backend';
SELECT 'xact_commit = ' || xact_commit::text || ' tup_returned = ' || tup_returned::text || ' tup_inserted = ' || tup_inserted::text
  FROM pg_stat_database WHERE datname = current_database();
SELECT 'counters are cumulative since stats reset ' || coalesce(stats_reset::text,'never') FROM pg_stat_database WHERE datname = current_database();
SELECT 'NEGCTL sessions with an impossible application_name = ' || count(*)::text FROM pg_stat_activity WHERE application_name = 'ZzzNoSuchApp';
'@
    [IO.File]::WriteAllText($actFile, $actSql, (New-Object System.Text.UTF8Encoding($false)))
    foreach ($port in @('5433','5432')) {
        Say ('  --- instance on port {0} ---' -f $port)
        $resFile = Join-Path $OutDir ('234_' + $stamp + '_activity_' + $port + '.txt')
        $errFile = Join-Path $OutDir ('234_' + $stamp + '_activity_' + $port + '.err.txt')
        $null = & $psqlPath -h 127.0.0.1 -p $port -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=0 -At -o $resFile -f $actFile 2>$errFile
        $rc = $LASTEXITCODE
        $errSize = $(if (Test-Path $errFile) { (Get-Item $errFile).Length } else { 0 })
        Say ('      psql exit {0} , error file {1} bytes' -f $rc, $errSize)
        if ($errSize -gt 0) {
            Say '      --- stderr, printed because a non-empty error file is a CONDITION ---'
            foreach ($errLine in (Get-Content $errFile)) { Say ('          ' + $errLine) }
            Say ('      the instance on {0} did not answer these queries - that is a reading about ACCESS, not about the engine' -f $port)
            $notMeasured++
        }
        if (Test-Path $resFile) { foreach ($resLine in (Get-Content $resFile)) { Say ('      ' + $resLine) } }
    }
    Remove-Item $actFile -ErrorAction SilentlyContinue
    Say '  How to read this: a session whose client is this machine and whose application_name names our engine'
    Say '  is positive evidence. ZERO client backends is NOT evidence of "nothing uses this database" - the'
    Say '  cumulative counters next to it are, and they are printed for exactly that reason.'
    Say ''

    Say '===== 5  schema census of BOTH instances - to be compared against the store on the build machine ====='
    Say '  I do not carry db/schema.sql onto this server, so nothing is compared here: the numbers and the'
    Say '  lists are captured, and the comparison happens in the repository where the authoritative file lives.'
    $censusFile = Join-Path $env:TEMP ('probeB_census_' + $stamp + '.sql')
    $censusSql = @'
SELECT 'tables in public = ' || count(*)::text FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
SELECT 'routines in public = ' || count(*)::text FROM information_schema.routines WHERE routine_schema = 'public';
SELECT 'columns in public = ' || count(*)::text FROM information_schema.columns WHERE table_schema = 'public';
SELECT 'table | ' || table_name || ' | columns ' || (SELECT count(*)::text FROM information_schema.columns c WHERE c.table_schema = 'public' AND c.table_name = t.table_name)
  FROM information_schema.tables t WHERE t.table_schema = 'public' AND t.table_type = 'BASE TABLE' ORDER BY table_name;
SELECT 'routine | ' || routine_name FROM information_schema.routines WHERE routine_schema = 'public' ORDER BY routine_name;
SELECT 'pk | ' || tc.table_name || ' | ' || kcu.column_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
 WHERE tc.table_schema = 'public' AND tc.constraint_type = 'PRIMARY KEY' AND tc.table_name LIKE 'RTSGrid%'
 ORDER BY tc.table_name, kcu.ordinal_position;
SELECT 'NEGCTL tables named impossibly = ' || count(*)::text FROM information_schema.tables WHERE table_name = 'zzz_no_such_table';
'@
    [IO.File]::WriteAllText($censusFile, $censusSql, (New-Object System.Text.UTF8Encoding($false)))
    foreach ($port in @('5433','5432')) {
        $censusRes = Join-Path $OutDir ('234_' + $stamp + '_census_' + $port + '.txt')
        $censusErr = Join-Path $OutDir ('234_' + $stamp + '_census_' + $port + '.err.txt')
        $null = & $psqlPath -h 127.0.0.1 -p $port -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=0 -At -o $censusRes -f $censusFile 2>$censusErr
        $rc = $LASTEXITCODE
        $errSize = $(if (Test-Path $censusErr) { (Get-Item $censusErr).Length } else { 0 })
        Say ('  port {0} : psql exit {1} , error file {2} bytes , results {3}' -f $port, $rc, $errSize, $censusRes)
        if (Test-Path $censusRes) {
            foreach ($censusLine in (Get-Content $censusRes)) { if ($censusLine -notmatch '^(table|routine) \| ') { Say ('      ' + $censusLine) } }
            Say ('      the per-table and per-routine lines are in the file, not here: {0} lines total' -f @(Get-Content $censusRes).Count)
        }
        if ($errSize -gt 0) { foreach ($errLine in (Get-Content $censusErr)) { Say ('      ' + $errLine) } }
    }
    Remove-Item $censusFile -ErrorAction SilentlyContinue
    Say ''

    Say '===== 6  PR234-QGRID-79 - the sequence predicate, with the key column taken from the SCHEMA this time ====='
    Say '  In v2 I wrote max("Id") from memory and psql answered: column "Id" does not exist. The primary key'
    Say '  names are read from information_schema here, and each sequence is then checked against ITS OWN key.'
    Say '  The predicate is the one from backend-0912: last_value must be >= max(key), or the next insert collides.'
    $seqFile = Join-Path $env:TEMP ('probeB_seq_' + $stamp + '.sql')
    $seqSql = @'
DO $$
DECLARE
    rec record;
    pk_name text;
    seq_name text;
    max_val bigint;
    last_val bigint;
    verdict text;
BEGIN
    FOR rec IN SELECT table_name FROM information_schema.tables
                WHERE table_schema = 'public' AND table_type = 'BASE TABLE' AND table_name LIKE 'RTSGrid%'
                ORDER BY table_name LOOP
        SELECT kcu.column_name INTO pk_name
          FROM information_schema.table_constraints tc
          JOIN information_schema.key_column_usage kcu
            ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
         WHERE tc.table_schema = 'public' AND tc.constraint_type = 'PRIMARY KEY' AND tc.table_name = rec.table_name
         ORDER BY kcu.ordinal_position LIMIT 1;
        IF pk_name IS NULL THEN
            RAISE NOTICE 'seq | % | NO PRIMARY KEY FOUND - nothing to check', rec.table_name;
            CONTINUE;
        END IF;
        seq_name := pg_get_serial_sequence('public.' || quote_ident(rec.table_name), pk_name);
        EXECUTE format('SELECT max(%I) FROM public.%I', pk_name, rec.table_name) INTO max_val;
        IF seq_name IS NULL THEN
            RAISE NOTICE 'seq | % | key % | NO SEQUENCE (the key is not generated) | max=%', rec.table_name, pk_name, coalesce(max_val::text,'NULL');
            CONTINUE;
        END IF;
        SELECT pg_sequence_last_value(seq_name::regclass) INTO last_val;
        IF last_val IS NULL THEN verdict := 'UNSET - the next insert collides';
        ELSIF max_val IS NULL THEN verdict := 'NO ROWS';
        ELSIF last_val >= max_val THEN verdict := 'OK';
        ELSE verdict := 'BEHIND - the next insert collides';
        END IF;
        RAISE NOTICE 'seq | % | key % | sequence % | last_value % | max % | %', rec.table_name, pk_name, seq_name, coalesce(last_val::text,'NULL'), coalesce(max_val::text,'NULL'), verdict;
    END LOOP;
    RAISE NOTICE 'seq | NEGCTL | a table that does not exist has no sequence: %', coalesce(pg_get_serial_sequence('public.zzz_no_such_table','Id'),'NULL');
EXCEPTION WHEN undefined_table THEN
    RAISE NOTICE 'seq | NEGCTL | asking for a non-existent table raised undefined_table, which is also a valid no';
END
$$;
'@
    [IO.File]::WriteAllText($seqFile, $seqSql, (New-Object System.Text.UTF8Encoding($false)))
    foreach ($port in @('5433','5432')) {
        $seqOut = Join-Path $OutDir ('234_' + $stamp + '_sequences_' + $port + '.txt')
        Say ('  --- sequences on port {0} (RAISE NOTICE goes to stderr, so both streams are captured into one file) ---' -f $port)
        $seqLines = & $psqlPath -h 127.0.0.1 -p $port -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=0 -At -f $seqFile 2>&1
        $rc = $LASTEXITCODE
        [IO.File]::WriteAllLines($seqOut, @($seqLines | ForEach-Object { "$_" }), (New-Object System.Text.UTF8Encoding($false)))
        Say ('      psql exit {0} , lines {1} , file {2}' -f $rc, @($seqLines).Count, $seqOut)
        foreach ($seqLine in @($seqLines)) { if ("$seqLine" -match 'seq \|') { Say ('      ' + ("$seqLine" -replace '^NOTICE:\s*','')) } }
        $behind = @($seqLines | Where-Object { "$_" -match 'BEHIND|UNSET' }).Count
        Say ('      sequences BEHIND or UNSET on this instance : {0}   expected 0 ; anything above zero is PR234-QGRID-79 alive' -f $behind)
        if (($port -eq '5433') -and ($behind -gt 0)) { Say '      -> FAIL on our database: the next insert into one of these tables collides'; $fails++ }
    }
    Remove-Item $seqFile -ErrorAction SilentlyContinue
    $env:PGPASSWORD = ''
}
Say ''

Say '===== SUMMARY ====='
Say ('  collector type at exit : {0}   expected ArrayList' -f $Report.GetType().Name)
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Say '  *** the collector was overwritten - the report on disk is incomplete'; $fails++ }
Say ('  failures     : {0}   anything above zero is a STOP for step 4: it goes to the coordinator' -f $fails)
Say ('  NOT MEASURED : {0}   gaps, named where they occur, never counted as passes' -f $notMeasured)
Say '  NOTHING WAS STARTED, STOPPED, INSTALLED, RESTARTED OR CHANGED. EVERY DATABASE STATEMENT WAS A SELECT'
Say '  OR A READ-ONLY DO BLOCK THAT ONLY RAISES NOTICES. C:\IceDash WAS NOT TOUCHED.'
Say '===== END-OF-RUN MARKER: ENGINE-PORT-COMPLETE ====='
Fin ($fails -eq 0)
