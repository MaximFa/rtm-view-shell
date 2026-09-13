#Requires -Version 5.1
<#
  PROBE 234 / preinstall-state      STEP A of the step-4 plan
  WHERE IT RUNS : server 234. Database rtmviewdb on port 5433. It REFUSES to run on any other machine:
                  name AND hardware UUID are a gate.
  READ ONLY. It starts nothing, stops nothing, installs nothing, writes no config, touches no service.
  Every database statement is a SELECT. C:\IceDash is not read and not listed. PG15 on 5432 is not contacted.
  WHAT IT WRITES: its report and one SQL result file under C:\RTMView-Ops\output, plus scratch files in TEMP
  that it deletes. It CREATES no artifact, so it carries no .origin mark - nothing for a later run to mistake.

  WHY IT EXISTS. It is the BEFORE half of the batch deploy and its result is a GATE, not a formality. The
  batch carries three installer edits plus the adapter config; what is actually under test is whether
  C:\RTMView\RTM\log4net.config survives a binary update the way data.sys now does. A claim about survival
  needs a number from BEFORE, or after the update there is nothing to compare against.

  TWO THINGS THIS RUN EXISTS TO CAPTURE, both required before any write to this machine:
  (1) the sha256 of the LIVE C:\RTMView\RTM.Twilio\log4net.config against the reference recovered from
      server 140 - the condition the coordinator recorded in the backlog;
  (2) the sha256 AND the modification time of every config the update will preserve, read FROM DISK.
      From disk, because on 08.09 an editor buffer held the production adapter name and the old database
      port, and saving it would have repeated the 30.08 incident: a file open in an editor and a file on
      disk are different objects.
  And one more, added because the coordinator found the gate blind: the file counts, newest timestamps and
  executable mtimes of the three product directories, plus the backup directories that exist right now. The
  binaries in the new package are byte-identical to the installed ones, so their hashes cannot tell
  "survived the update" from "the update never touched this directory". A changed mtime and a NEW backup
  directory can. Those numbers are worthless unless taken BEFORE - which is what this run is for.

  Password is NEVER prompted and never printed: it is read from the machine own Shell config, and only its
  length goes into the report.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$REF_LOG4NET = '1D520F4D7AD2451BBBA4BD6CB7BAAFD0BE3C06AB407C8DD1ACD86D7FAE613FA2'
$DATASYS_PREFIX = '24F0BFAC'
$OutDir = 'C:\RTMView-Ops\output'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_preinstall-state.txt')
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [void]$L.Add('')
    [void]$L.Add($(if ($pass) { 'VERDICT: PASS' } else { 'VERDICT: FAIL' }))
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function H($p) { if (Test-Path $p) { (Get-FileHash $p -Algorithm SHA256).Hash } else { 'ABSENT' } }

Say '===== G0  machine identity - this probe refuses to run anywhere else ====='
$n = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$u = ($uuid -eq $UUIDGATE)
Say ('  name  expected {0} , actual {1} -> {2}' -f $NAMEGATE, $env:COMPUTERNAME, $n)
Say ('  uuid  expected {0} , actual {1} -> {2}' -f $UUIDGATE, $uuid, $u)
if (-not ($n -and $u)) { Say '  *** NOT server 234 - refusing to measure'; Fin $false }
Say ('  PowerShell {0}' -f $PSVersionTable.PSVersion)
Say ('  this probe sha256 : {0}   compare with the number named BEFORE the run' -f (H $MyInvocation.MyCommand.Path))
Say ('  NEGCTL sha of a missing path : {0}   expected ABSENT' -f (H 'C:\zzz-no-such-file.bin'))
if ((H 'C:\zzz-no-such-file.bin') -ne 'ABSENT') { Say '  *** the hash helper cannot report absence - stop'; Fin $false }
Say '  G0 PASS'
Say ''

$fails = 0

Say '===== 1  services - name, state, start mode, exe path ====='
foreach ($s in @('RTMService','RTMViewShell','RTMTwilio_1','RTM.Twilio','RTM','RTMApplyService','Garnet')) {
    $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $s) -ErrorAction SilentlyContinue
    if ($null -eq $svc) { Say ('  {0,-16} ABSENT' -f $s) }
    else { Say ('  {0,-16} {1,-9} {2,-10} {3}' -f $svc.Name, $svc.State, $svc.StartMode, $svc.PathName) }
}
Say '  expected: our three Running ; production RTM.Twilio and legacy RTM Stopped ; RTMApplyService ABSENT is NORMAL'
$neg = Get-CimInstance Win32_Service -Filter "Name='ZzzNoSuchServiceHere'" -ErrorAction SilentlyContinue
Say ('  NEGCTL a service that cannot exist : {0}   expected ABSENT' -f $(if ($null -eq $neg) { 'ABSENT' } else { 'FOUND - predicate broken' }))
if ($null -ne $neg) { $fails++ }
$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'C:\RTMView\*' })
Say ('  processes running out of C:\RTMView : {0}' -f $procs.Count)
foreach ($pr in $procs) { Say ('      {0,-18} pid {1,-7} started {2}   {3}' -f $pr.ProcessName, $pr.Id, $pr.StartTime, $pr.Path) }
Say ''

Say '===== 2  CONDITION FROM THE BACKLOG - the live adapter log4net.config against the 140 reference ====='
$adpCfg = 'C:\RTMView\RTM.Twilio\log4net.config'
Say ('  expected : {0}' -f $REF_LOG4NET)
$adpSha = H $adpCfg
Say ('  actual   : {0}' -f $adpSha)
if (Test-Path $adpCfg) {
    $ab = [IO.File]::ReadAllBytes($adpCfg)
    Say ('  {0} bytes , CR {1} , modified {2}   expected 761 bytes and CR 21' -f $ab.Length, @($ab | Where-Object { $_ -eq 13 }).Count, (Get-Item $adpCfg).LastWriteTime)
}
if ($adpSha -ne $REF_LOG4NET) { Say '  -> FAIL  this is the coordinator condition: a mismatch means edit 2 is reconsidered, and I say so first'; $fails++ }
else { Say '  -> PASS  the live file is the reference byte for byte' }
Say ''

Say '===== 3  BEFORE baseline - every file the update must PRESERVE, read FROM DISK ====='
Say '  Update-RTMView preserve lists, read from the store at b4ad301:'
Say '    RTM   : data.sys , appsettings.json , log4net.config      <- log4net.config is edit 3, the subject of this batch'
Say '    Shell : appsettings.json , appsettings.Production.json , nlog.config'
foreach ($f in @('C:\RTMView\RTM\data.sys','C:\RTMView\RTM\appsettings.json','C:\RTMView\RTM\log4net.config','C:\RTMView\Shell\appsettings.json','C:\RTMView\Shell\appsettings.Production.json','C:\RTMView\Shell\nlog.config','C:\RTMView\RTM.Twilio\appsettings.json','C:\RTMView\RTM.Twilio\log4net.config')) {
    if (-not (Test-Path $f)) { Say ('  {0}  ABSENT' -f $f) }
    else { $it = Get-Item $f; Say ('  {0}' -f $f); Say ('      {0,8} bytes   modified {1}   sha256 {2}' -f $it.Length, $it.LastWriteTime, (H $f)) }
}
$dsSha = H 'C:\RTMView\RTM\data.sys'
Say ('  data.sys starts with the machine reference {0} : {1}   (the handoff records that reference truncated, so only the prefix can be compared - said rather than implied)' -f $DATASYS_PREFIX, ("$dsSha".StartsWith($DATASYS_PREFIX)))
if (-not ("$dsSha".StartsWith($DATASYS_PREFIX))) { Say '  -> FAIL  data.sys is not the machine file'; $fails++ }
Say ''

Say '===== 4  BEFORE baseline for the POSITIVE PROOF that an update happened at all ====='
Say '  The package binaries are byte-identical to the installed ones, so a hash cannot tell "survived the'
Say '  update" from "the update never touched this directory". These numbers can, and only if taken NOW.'
foreach ($d in @('C:\RTMView\Shell','C:\RTMView\RTM','C:\RTMView\RTM.Twilio')) {
    if (-not (Test-Path $d)) { Say ('  {0} : ABSENT' -f $d); continue }
    $files = @(Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue)
    $newest = @($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    Say ('  {0}' -f $d)
    Say ('      files {0} , total {1:N1} MB , newest {2}' -f $files.Count, (($files | Measure-Object Length -Sum).Sum/1MB), $(if ($newest.Count -eq 1) { "$($newest[0].Name) $($newest[0].LastWriteTime)" } else { 'none' }))
}
foreach ($exe in @('C:\RTMView\RTM\RTM.exe','C:\RTMView\Shell\CcDashboard.Web.exe','C:\RTMView\RTM.Twilio\RTM.Twilio.exe')) {
    if (-not (Test-Path $exe)) { Say ('  {0} : ABSENT' -f $exe); continue }
    $it = Get-Item $exe
    Say ('  {0}' -f $exe)
    Say ('      {0,10} bytes   created {1}   modified {2}' -f $it.Length, $it.CreationTime, $it.LastWriteTime)
    Say ('      sha256 {0}   this one is EXPECTED to be unchanged after the update - there is no new product code' -f (H $exe))
}
$bdir = 'C:\RTMView\Backup'
if (-not (Test-Path $bdir)) { Say ('  {0} : ABSENT - then a new backup directory appearing is itself the proof' -f $bdir) }
else {
    $bk = @(Get-ChildItem $bdir -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    Say ('  backup directories under {0} right now : {1}' -f $bdir, $bk.Count)
    foreach ($b in $bk) { Say ('      {0}   created {1}' -f $b.Name, $b.CreationTime) }
    Say '  AFTER the update this count must be HIGHER, with a stamp from today.'
}
Say '  NEGATIVE HALF, stated now so the green later has a price: if the update does NOT happen, all three'
Say '  directories keep their file counts AND their newest timestamps, no new backup directory appears, and'
Say '  the service start lines keep their old times. By hashes alone that picture is indistinguishable from a'
Say '  successful update - which is exactly why these numbers are taken.'
Say ''

Say '===== 5  config VALUES from disk (reading only - PR234-SHELL-CFG-01 is DEFERRED, nothing is fixed) ====='
$rtmCfg = 'C:\RTMView\RTM\appsettings.json'
if (-not (Test-Path $rtmCfg)) { Say ('  {0} ABSENT' -f $rtmCfg); $fails++ }
else {
    $j = Get-Content $rtmCfg -Raw | ConvertFrom-Json
    Say ("  RTM:AdaptorServiceName = '{0}'   expected RTMTwilio_1 - anything else means our service drives the PRODUCTION adapter" -f $j.RTM.AdaptorServiceName)
    if ("$($j.RTM.AdaptorServiceName)" -ne 'RTMTwilio_1') { Say '      -> FAIL  stop, do not install: this is the 30.08 incident shape'; $fails++ }
    Say ("  RTM:PipeName           = '{0}'" -f $j.RTM.PipeName)
    Say ("  RTM:TenantId           = '{0}'" -f $j.RTM.TenantId)
    $cs = "$($j.RTM.RTMConnectionString)"
    if ($cs -match 'Port\s*=\s*(\d+)') {
        Say ('  RTM conn Port          = {0}   expected 5433' -f $Matches[1])
        if ($Matches[1] -ne '5433') { Say '      -> FAIL  the engine points at the OLD database'; $fails++ }
    } else { Say '  RTM conn Port          = not stated in the string' }
}
$shCfg = 'C:\RTMView\Shell\appsettings.json'
if (-not (Test-Path $shCfg)) { Say ('  {0} ABSENT' -f $shCfg); $fails++ }
else {
    $raw = Get-Content $shCfg -Raw
    $s = $raw | ConvertFrom-Json
    Say ("  Shell DefaultTenantSlug     = '{0}'   absent is the EXPECTED state while deferred; a value present is the finding" -f $s.DefaultTenantSlug)
    Say ('  Shell MetricsApply present  : {0}   expected False while deferred' -f ($raw -match 'MetricsApply'))
    Say ('  Shell RtmRelay override     : {0}   expected False while deferred' -f ($raw -match 'RtmRelay'))
    $serilogLine = @($raw -split "`n" | Where-Object { $_ -match 'log-' } | Select-Object -First 1)
    if ($serilogLine.Count -eq 1) { Say ('  Shell Serilog path line     : {0}' -f $serilogLine[0].Trim()) }
    Say '  a RELATIVE Serilog path means the running Shell writes its log into C:\Windows\System32\logs - half a day was lost to that'
    $scs = "$($s.ConnectionStrings.DefaultConnection)"
    if ($scs -match 'Port\s*=\s*(\d+)') { Say ('  Shell conn Port             = {0}   expected 5433' -f $Matches[1]) }
    if ($scs -match 'Database\s*=\s*([^;]+)') { Say ('  Shell conn Database         = {0}' -f $Matches[1].Trim()) }
    if ($scs -match 'Username\s*=\s*([^;]+)') { Say ('  Shell conn Username         = {0}' -f $Matches[1].Trim()) }
    if ($scs -match 'Password\s*=\s*([^;]+)') { $script:PW = $Matches[1].Trim(); Say ('  Shell conn Password         = present, {0} characters, NOT printed' -f $script:PW.Length) }
    else { Say '  Shell conn Password         = NOT FOUND - the database sections will be skipped, and that is a gap, not a pass' }
}
Say ''

Say '===== 6  liveness - the PAIR, with the negative control on the address that ANSWERED ====='
$curl = Join-Path $env:SystemRoot 'System32\curl.exe'
$http200 = $false
$httpAddr = 'none'
if (-not (Test-Path $curl)) { Say '  curl.exe ABSENT - the HTTP half is NOT MEASURED, and that says nothing about the application' }
else {
    foreach ($u2 in @('https://127.0.0.1:8444/health','https://localhost:8444/health','http://127.0.0.1:5000/health')) {
        $code = (& $curl -k -s -o NUL -w '%{http_code}' --max-time 15 $u2) 2>$null
        Say ('  {0} -> {1}' -f $u2, $code)
        if (("$code" -ne '000') -and ($httpAddr -eq 'none')) { $httpAddr = $u2; $script:httpCode = "$code" }
    }
    if ($httpAddr -eq 'none') { Say '  every address returned 000 - UNREACHABLE (not a liveness verdict)' }
    else {
        $body = (& $curl -k -s --max-time 15 $httpAddr) 2>$null
        $negc = (& $curl -k -s -o NUL -w '%{http_code}' --max-time 15 ($httpAddr -replace '/health','/zzz-no-such-endpoint')) 2>$null
        Say ('  verdict taken on {0} : code {1} , body {2}' -f $httpAddr, $script:httpCode, $body)
        Say ('  NEGCTL on THAT SAME address -> {0}   must be neither 200 nor 000, or the pair proves nothing' -f $negc)
        $http200 = (($script:httpCode -eq '200') -and ("$negc" -ne '200') -and ("$negc" -ne '000'))
    }
}
$pipeName = 'rtmpipe_v3'
if (Test-Path $rtmCfg) { $pipeName = "$((Get-Content $rtmCfg -Raw | ConvertFrom-Json).RTM.PipeName)" }
$pipes = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) })
Say ('  pipes visible in total : {0}   zero here means the measurement is broken, not that there are none' -f $pipes.Count)
if ($pipes.Count -eq 0) { Say '      -> FAIL  pipe enumeration returned nothing'; $fails++ }
$served = ($pipes -contains $pipeName)
Say ("  pipe '{0}' served : {1}   expected True" -f $pipeName, $served)
Say ('  NEGCTL an impossible pipe served : {0}   expected False' -f ($pipes -contains 'zzz-no-such-pipe-here'))
Say ('  LIVENESS BEFORE (both halves, or it is not liveness) : {0}' -f ($http200 -and $served))
if (-not ($http200 -and $served)) { Say '      a red here is a STOP for the install, not a detail - it goes to the coordinator'; $fails++ }
Say ''

Say '===== 7  the database, SELECT only - it names itself, and the instrument proves it can fail ====='
$psql = $null
foreach ($c in @(Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $pp = Join-Path $c.FullName 'bin\psql.exe'
    if ((Test-Path $pp) -and ($null -eq $psql)) { $psql = $pp }
}
if ($null -eq $psql) { Say '  psql.exe NOT FOUND - the database sections are NOT MEASURED, and that is a gap, not a pass'; $fails++ }
elseif (-not $script:PW) { Say '  no password from the machine config - database sections NOT MEASURED'; $fails++ }
else {
    Say ('  psql : {0}' -f $psql)
    $env:PGCLIENTENCODING = 'UTF8'
    $env:PGPASSWORD = $script:PW
    $badf = Join-Path $env:TEMP ('probeA_bad_' + $stamp + '.sql')
    [IO.File]::WriteAllText($badf, "SELECT this_is_not_valid FROM;`n", (New-Object System.Text.UTF8Encoding($false)))
    $null = & $psql -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=1 -At -f $badf 2>&1
    $rcBad = $LASTEXITCODE
    Remove-Item $badf -ErrorAction SilentlyContinue
    Say ('  INSTRUMENT CHECK a deliberately broken query : exit {0}   expected NON-zero, otherwise a zero below means only that psql started' -f $rcBad)
    if ($rcBad -eq 0) { Say '      *** psql does not fail on a broken query - refusing to trust its zeroes'; $env:PGPASSWORD = ''; Fin $false }

    $sqlf = Join-Path $env:TEMP ('probeA_' + $stamp + '.sql')
    $resf = Join-Path $OutDir ('234_' + $stamp + '_preinstall-sql.txt')
    $errf = Join-Path $OutDir ('234_' + $stamp + '_preinstall-sql.err.txt')
    $sql = @'
SELECT 'whoami db=' || current_database() || ' port=' || inet_server_port() || ' user=' || current_user || ' ver=' || substring(version() from 1 for 30);
SELECT 'tenant | ' || "Id" || ' | ' || "Slug" FROM tenants ORDER BY "Slug";
SELECT 'regclass ' || t || ' = ' || coalesce(to_regclass('public.' || quote_ident(t))::text, 'NULL')
  FROM unnest(ARRAY['RTSGrid_Grid','RTSGrid_Row','RTSGrid_Column','RTSGrid_Cell','RTSGrid_Metric','NGC_BusinessUnit','RTSData_Interaction','RTSData_UserStatusLog']) AS t;
SELECT 'NEGCTL regclass zzz_no_such_table = ' || coalesce(to_regclass('public."zzz_no_such_table"')::text, 'NULL');
SELECT 'rowcount RTSGrid_Grid = '   || count(*)::text FROM "RTSGrid_Grid";
SELECT 'rowcount RTSGrid_Row = '    || count(*)::text FROM "RTSGrid_Row";
SELECT 'rowcount RTSGrid_Column = ' || count(*)::text FROM "RTSGrid_Column";
SELECT 'rowcount RTSGrid_Cell = '   || count(*)::text FROM "RTSGrid_Cell";
SELECT 'rowcount RTSGrid_Metric = ' || count(*)::text FROM "RTSGrid_Metric";
SELECT 'seq ' || tbl || ' sequence=' || coalesce(seqname,'NONE')
       || ' last_value=' || coalesce(pg_sequence_last_value(seqname::regclass)::text,'NULL')
       || ' max_id=' || coalesce(maxid::text,'NULL')
       || ' verdict=' || CASE WHEN seqname IS NULL THEN 'NO SEQUENCE FOUND'
                              WHEN pg_sequence_last_value(seqname::regclass) IS NULL THEN 'UNSET - the next insert collides'
                              WHEN maxid IS NULL THEN 'NO ROWS'
                              WHEN pg_sequence_last_value(seqname::regclass) >= maxid THEN 'OK'
                              ELSE 'BEHIND - the next insert collides' END
FROM (
  SELECT 'RTSGrid_Grid'::text AS tbl, pg_get_serial_sequence('public."RTSGrid_Grid"','Id') AS seqname, (SELECT max("Id") FROM "RTSGrid_Grid") AS maxid
  UNION ALL SELECT 'RTSGrid_Row',    pg_get_serial_sequence('public."RTSGrid_Row"','Id'),    (SELECT max("Id") FROM "RTSGrid_Row")
  UNION ALL SELECT 'RTSGrid_Column', pg_get_serial_sequence('public."RTSGrid_Column"','Id'), (SELECT max("Id") FROM "RTSGrid_Column")
  UNION ALL SELECT 'RTSGrid_Cell',   pg_get_serial_sequence('public."RTSGrid_Cell"','Id'),   (SELECT max("Id") FROM "RTSGrid_Cell")
) q;
SELECT 'NEGCTL the sequence predicate on a table that does not exist = ' || coalesce(pg_get_serial_sequence('public.zzz_no_such_table','Id'), 'NULL');
SELECT 'migration history tables present: ' || coalesce(string_agg(table_schema || '.' || table_name, ', '), 'NONE FOUND')
  FROM information_schema.tables WHERE table_name ILIKE '%migration%';
SELECT 'flow T0 Interaction = ' || count(*)::text FROM "RTSData_Interaction";
SELECT 'flow T0 UserStatusLog = ' || count(*)::text FROM "RTSData_UserStatusLog";
SELECT 'flow T0 taken at ' || now()::text;
'@
    [IO.File]::WriteAllText($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))
    $null = & $psql -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=0 -At -o $resf -f $sqlf 2>$errf
    $rcSql = $LASTEXITCODE
    Say ('  psql exit {0} ; results in {1} ; error file {2} bytes' -f $rcSql, $resf, $(if (Test-Path $errf) { (Get-Item $errf).Length } else { 'ABSENT' }))
    Say '  psql writes the result file ITSELF - no PowerShell variable stands between a native unicode stream and the file'
    if ((Test-Path $errf) -and ((Get-Item $errf).Length -gt 0)) {
        Say '  --- stderr, printed because a non-empty error file is a CONDITION, not a footnote ---'
        foreach ($e in (Get-Content $errf)) { Say ('      ' + $e) }
        $fails++
    }
    if (Test-Path $resf) { foreach ($r in (Get-Content $resf)) { Say ('      ' + $r) } }
    Remove-Item $sqlf -ErrorAction SilentlyContinue

    Say ''
    Say '  --- flow, three samples 60 s apart, on APPEND-ONLY tables (RTSData_UserStatus is an UPSERT and is NOT a gate) ---'
    $f1f = Join-Path $env:TEMP ('probeA_flow_' + $stamp + '.sql')
    $flowSql = @'
SELECT (SELECT count(*) FROM "RTSData_Interaction")::text || ' ' || (SELECT count(*) FROM "RTSData_UserStatusLog")::text || ' ' || now()::text;
'@
    [IO.File]::WriteAllText($f1f, $flowSql, (New-Object System.Text.UTF8Encoding($false)))
    $samples = @()
    for ($i = 1; $i -le 3; $i++) {
        $rf = Join-Path $env:TEMP ('probeA_flow_out_' + $stamp + '_' + $i + '.txt')
        $null = & $psql -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=1 -At -o $rf -f $f1f 2>&1
        $line = if (Test-Path $rf) { (Get-Content $rf | Select-Object -First 1) } else { 'NO RESULT' }
        Say ('      sample {0} : {1}' -f $i, $line)
        $samples += "$line"
        Remove-Item $rf -ErrorAction SilentlyContinue
        if ($i -lt 3) { Start-Sleep -Seconds 60 }
    }
    Remove-Item $f1f -ErrorAction SilentlyContinue
    try {
        $a = [int64](($samples[0] -split ' ')[0]); $b = [int64](($samples[2] -split ' ')[0])
        $c = [int64](($samples[0] -split ' ')[1]); $d = [int64](($samples[2] -split ' ')[1])
        Say ('      Interaction   {0} -> {1}   delta {2}' -f $a, $b, ($b - $a))
        Say ('      UserStatusLog {0} -> {1}   delta {2}' -f $c, $d, ($d - $c))
        if (($b -lt $a) -or ($d -lt $c)) { Say '      -> FAIL  a count WENT DOWN on an append-only table'; $fails++ }
        elseif (($b -gt $a) -or ($d -gt $c)) { Say '      -> PASS  the feed is growing' }
        else { Say '      -> QUIET: neither table grew in two minutes. Both may legally stand still in a quiet hour (Interaction upserts per segment, UserStatusLog writes only on a status change), so this is NOT a FAIL by itself: the feed is UNPROVEN in this window, and whether to wait for a busy one is the coordinator decision.' }
    } catch { Say ('      -> the samples could not be parsed: {0}   NOT MEASURED, not a pass' -f $_.Exception.Message); $fails++ }
    $env:PGPASSWORD = ''
}
Say ''

Say '===== 8  the adapter log - the observability that was missing for two days ====='
$adpLog = 'C:\Logs\RTM.Twilio\log.txt'
if (-not (Test-Path $adpLog)) { Say ('  {0} : ABSENT - after the update, this file existing and being fresh is the gate for edit 2' -f $adpLog) }
else {
    $it = Get-Item $adpLog
    Say ('  {0}   {1} bytes   modified {2}   age {3:N0} minutes' -f $adpLog, $it.Length, $it.LastWriteTime, ((Get-Date) - $it.LastWriteTime).TotalMinutes)
    foreach ($l in (Get-Content $adpLog -Tail 5)) { Say ('      ' + $l) }
}
Say ''

Say '===== SUMMARY - this is the BEFORE half. Nothing here was changed. ====='
Say ('  adapter log4net.config equals the 140 reference : {0}' -f ((H $adpCfg) -eq $REF_LOG4NET))
Say ('  failures : {0}   anything above zero is a STOP: it goes to the coordinator before any write' -f $fails)
Say '  Numbers to carry into the AFTER run: the eight config hashes, the three directory file counts and'
Say '  newest timestamps, the three executable mtimes, and the list of backup directories.'
Say '  NOTHING WAS STARTED, STOPPED, INSTALLED OR CHANGED. EVERY DATABASE STATEMENT WAS A SELECT.'
Say '===== END-OF-RUN MARKER: PREINSTALL-STATE-COMPLETE ====='
Fin ($fails -eq 0)
