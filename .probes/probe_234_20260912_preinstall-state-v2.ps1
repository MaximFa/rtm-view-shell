#Requires -Version 5.1
<#
  PROBE 234 / preinstall-state-v2      STEP A of the step-4 plan, second attempt
  WHERE IT RUNS : server 234 (machine RTM). Database rtmviewdb on port 5433. It REFUSES to run anywhere
                  else: machine name AND hardware UUID are a gate. EVERY line of this box runs on 234.
  READ ONLY. Starts nothing, stops nothing, restarts nothing, writes no config, touches no service.
  Every database statement is a SELECT. C:\IceDash is not read and not listed. PG15 on 5432 is not contacted.
  WHAT IT WRITES: its report and the SQL result files under C:\RTMView-Ops\output, plus scratch files in
  TEMP that it deletes. It creates no artifact, so it carries no .origin mark.

  WHY V2 - two defects of MINE in v1, and both destroyed measurements rather than merely annoying:

  (1) The hash helper was named H. In PowerShell ALIASES resolve BEFORE functions, and h is the built-in
      alias for Get-History, so every single hash call went to Get-History and threw. The two headline
      numbers - the live adapter log4net.config against the 140 reference, and data.sys against the machine
      reference - were therefore NOT MEASURED, and v1 printed them as FAIL. A red that comes from a broken
      instrument is worse than no red: it accuses the machine of my defect. Here the helper has a long
      unambiguous name AND a gate that proves it resolves to a Function before anything is hashed.

  (2) The report collector was named $L, and section 8 looped with foreach ($l in ...). PowerShell variable
      names are case-insensitive, so the log line overwrote the collector and the report file on disk was
      truncated from that point. Here the collector is $Report, no loop variable is a single letter, and the
      collector type is checked at the END as a gate - the check exists in my local probes and I failed to
      carry it into the server one.

  (3) v1 could not find the database password in the Shell connection string and skipped every database
      section. That may be my predicate rather than a missing password, so this run PRINTS THE KEY NAMES it
      finds (names only, never values) and tries the documented places in order, saying which one answered.

  Password is NEVER prompted and never printed: it is read from the machine own config, and only its length
  goes into the report.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$REF_LOG4NET = '1D520F4D7AD2451BBBA4BD6CB7BAAFD0BE3C06AB407C8DD1ACD86D7FAE613FA2'
$DATASYS_PREFIX = '24F0BFAC'
$OutDir = 'C:\RTMView-Ops\output'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_preinstall-state-v2.txt')
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

Say '===== G0  machine identity - this probe refuses to run anywhere else ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq $UUIDGATE)
Say ('  name  expected {0} , actual {1} -> {2}' -f $NAMEGATE, $env:COMPUTERNAME, $nameOk)
Say ('  uuid  expected {0} , actual {1} -> {2}' -f $UUIDGATE, $uuid, $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say '  *** NOT server 234 - refusing to measure'; Fin $false }
Say ('  PowerShell {0}' -f $PSVersionTable.PSVersion)
Say ''
Say '  --- the instrument is proven BEFORE it is used. This is what v1 skipped. ---'
$resolved = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ('  Get-Sha256Of resolves to : {0}   expected Function (v1 used the name H, which resolves to the ALIAS Get-History)' -f $resolved.CommandType)
if ("$($resolved.CommandType)" -ne 'Function') { Say '  *** the hash helper is shadowed - refusing to measure'; Fin $false }
$selfSha = Get-Sha256Of $MyInvocation.MyCommand.Path
Say ('  this probe sha256 : {0}' -f $selfSha)
Say ('  expected          : the number named BEFORE the run, in the chat message that handed this box over')
if ($selfSha -eq 'ABSENT') { Say '  *** the helper cannot hash its own file - stop'; Fin $false }
$negHash = Get-Sha256Of 'C:\zzz-no-such-file.bin'
Say ('  NEGCTL hash of a missing path : {0}   expected ABSENT' -f $negHash)
if ($negHash -ne 'ABSENT') { Say '  *** the helper cannot report absence - stop'; Fin $false }
$posHash = Get-Sha256Of $MyInvocation.MyCommand.Path
Say ('  POSCTL hashing twice gives the same value : {0}   expected True' -f ($posHash -eq $selfSha))
if ($posHash -ne $selfSha) { Say '  *** the helper is not deterministic - stop'; Fin $false }
Say ('  collector type at entry : {0}   expected ArrayList' -f $Report.GetType().Name)
Say '  G0 PASS'
Say ''

$fails = 0
$notMeasured = 0

Say '===== 1  services - name, state, start mode, exe path ====='
foreach ($svcName in @('RTMService','RTMViewShell','RTMTwilio_1','RTM.Twilio','RTM','RTMApplyService','Garnet')) {
    $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $svcName) -ErrorAction SilentlyContinue
    if ($null -eq $svc) { Say ('  {0,-16} ABSENT' -f $svcName) }
    else { Say ('  {0,-16} {1,-9} {2,-10} {3}' -f $svc.Name, $svc.State, $svc.StartMode, $svc.PathName) }
}
Say '  expected: our three Running ; RTMApplyService ABSENT is NORMAL'
Say '  NOTE carried from v1 and NOT a defect of this probe: legacy RTM out of C:\IceDash was measured RUNNING,'
Say '  while the handoff records it Stopped. We do not touch it either way - it is the operator forbidden zone.'
$negSvc = Get-CimInstance Win32_Service -Filter "Name='ZzzNoSuchServiceHere'" -ErrorAction SilentlyContinue
Say ('  NEGCTL a service that cannot exist : {0}   expected ABSENT' -f $(if ($null -eq $negSvc) { 'ABSENT' } else { 'FOUND - predicate broken' }))
if ($null -ne $negSvc) { $fails++ }
$procList = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'C:\RTMView\*' })
Say ('  processes running out of C:\RTMView : {0}' -f $procList.Count)
foreach ($proc in $procList) { Say ('      {0,-18} pid {1,-7} started {2}   {3}' -f $proc.ProcessName, $proc.Id, $proc.StartTime, $proc.Path) }
Say ''

Say '===== 2  CONDITION FROM THE BACKLOG - the live adapter log4net.config against the 140 reference ====='
$adapterCfg = 'C:\RTMView\RTM.Twilio\log4net.config'
Say ('  expected : {0}' -f $REF_LOG4NET)
$adapterSha = Get-Sha256Of $adapterCfg
Say ('  actual   : {0}' -f $adapterSha)
if ($adapterSha -eq 'ABSENT') { Say '  -> FAIL  the file the adapter needs is not there at all'; $fails++ }
else {
    $adapterBytes = [IO.File]::ReadAllBytes($adapterCfg)
    $crCount = 0
    foreach ($byteValue in $adapterBytes) { if ($byteValue -eq 13) { $crCount++ } }
    Say ('  {0} bytes , CR {1} , modified {2}   expected 761 bytes and CR 21' -f $adapterBytes.Length, $crCount, (Get-Item $adapterCfg).LastWriteTime)
    if ($adapterSha -eq $REF_LOG4NET) { Say '  -> PASS  the live file is the 140 reference byte for byte' }
    else { Say '  -> FAIL  the coordinator condition: a real mismatch means edit 2 is reconsidered, and I say so first'; $fails++ }
}
Say ''

Say '===== 3  BEFORE baseline - every file the update must PRESERVE, read FROM DISK ====='
Say '  Update-RTMView preserve lists, read from the store at b4ad301:'
Say '    RTM   : data.sys , appsettings.json , log4net.config      <- log4net.config is edit 3, the subject of the batch'
Say '    Shell : appsettings.json , appsettings.Production.json , nlog.config'
foreach ($cfgPath in @('C:\RTMView\RTM\data.sys','C:\RTMView\RTM\appsettings.json','C:\RTMView\RTM\log4net.config','C:\RTMView\Shell\appsettings.json','C:\RTMView\Shell\appsettings.Production.json','C:\RTMView\Shell\nlog.config','C:\RTMView\RTM.Twilio\appsettings.json','C:\RTMView\RTM.Twilio\log4net.config')) {
    if (-not (Test-Path $cfgPath)) { Say ('  {0}   ABSENT' -f $cfgPath) }
    else {
        $item = Get-Item $cfgPath
        Say ('  {0}' -f $cfgPath)
        Say ('      {0,8} bytes   modified {1}   sha256 {2}' -f $item.Length, $item.LastWriteTime, (Get-Sha256Of $cfgPath))
    }
}
$dataSysSha = Get-Sha256Of 'C:\RTMView\RTM\data.sys'
if ($dataSysSha -eq 'ABSENT') { Say '  data.sys ABSENT -> FAIL'; $fails++ }
else {
    Say ('  data.sys sha256 {0}' -f $dataSysSha)
    Say ('  starts with the machine reference {0} : {1}   (the handoff records that reference truncated, so only the prefix can be compared - said, not implied)' -f $DATASYS_PREFIX, ("$dataSysSha".StartsWith($DATASYS_PREFIX)))
    if (-not ("$dataSysSha".StartsWith($DATASYS_PREFIX))) { Say '  -> FAIL  data.sys is not the machine file'; $fails++ }
    else { Say '  -> PASS' }
}
Say ''

Say '===== 4  BEFORE baseline for the POSITIVE PROOF that an update happened at all ====='
Say '  The package binaries are byte-identical to the installed ones, so a hash cannot tell "survived the'
Say '  update" from "the update never touched this directory". These numbers can, and only if taken NOW.'
foreach ($dirPath in @('C:\RTMView\Shell','C:\RTMView\RTM','C:\RTMView\RTM.Twilio')) {
    if (-not (Test-Path $dirPath)) { Say ('  {0} : ABSENT' -f $dirPath); continue }
    $dirFiles = @(Get-ChildItem $dirPath -Recurse -File -ErrorAction SilentlyContinue)
    $newestFile = @($dirFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    Say ('  {0}' -f $dirPath)
    Say ('      files {0} , total {1:N1} MB , newest {2}' -f $dirFiles.Count, (($dirFiles | Measure-Object Length -Sum).Sum/1MB), $(if ($newestFile.Count -eq 1) { "$($newestFile[0].Name) $($newestFile[0].LastWriteTime)" } else { 'none' }))
}
foreach ($exePath in @('C:\RTMView\RTM\RTM.exe','C:\RTMView\Shell\CcDashboard.Web.exe','C:\RTMView\RTM.Twilio\RTM.Twilio.exe')) {
    if (-not (Test-Path $exePath)) { Say ('  {0} : ABSENT' -f $exePath); continue }
    $exeItem = Get-Item $exePath
    Say ('  {0}' -f $exePath)
    Say ('      {0,10} bytes   created {1}   modified {2}' -f $exeItem.Length, $exeItem.CreationTime, $exeItem.LastWriteTime)
    Say ('      sha256 {0}' -f (Get-Sha256Of $exePath))
    Say ('      this hash is EXPECTED to be UNCHANGED after the update - there is no new product code; the mtime is what must change')
}
$backupDir = 'C:\RTMView\Backup'
if (-not (Test-Path $backupDir)) { Say ('  {0} : ABSENT - then the directory appearing at all is itself the proof' -f $backupDir) }
else {
    $backups = @(Get-ChildItem $backupDir -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    Say ('  backup directories under {0} right now : {1}' -f $backupDir, $backups.Count)
    foreach ($bk in $backups) { Say ('      {0}   created {1}' -f $bk.Name, $bk.CreationTime) }
    Say '  AFTER the update this count must be HIGHER, with a stamp from today.'
}
Say '  NEGATIVE HALF, stated now so the green later has a price: if the update does NOT happen, all three'
Say '  directories keep their file counts AND their newest timestamps, no new backup directory appears, and'
Say '  the services keep their old start times. By hashes alone that picture is indistinguishable from a'
Say '  successful update - which is exactly why these numbers are taken.'
Say ''

Say '===== 5  config VALUES from disk, and the KEY NAMES so a missing value is not confused with a wrong predicate ====='
$rtmCfg = 'C:\RTMView\RTM\appsettings.json'
$dbPassword = $null
$passwordSource = 'none'
if (-not (Test-Path $rtmCfg)) { Say ('  {0} ABSENT' -f $rtmCfg); $fails++ }
else {
    $rtmJson = Get-Content $rtmCfg -Raw | ConvertFrom-Json
    Say ('  top-level keys in RTM appsettings.json : {0}' -f (($rtmJson.PSObject.Properties.Name) -join ', '))
    if ($rtmJson.RTM) { Say ('  keys under RTM : {0}' -f (($rtmJson.RTM.PSObject.Properties.Name) -join ', ')) }
    Say ("  RTM:AdaptorServiceName = '{0}'   expected RTMTwilio_1 - anything else means our service drives the PRODUCTION adapter" -f $rtmJson.RTM.AdaptorServiceName)
    if ("$($rtmJson.RTM.AdaptorServiceName)" -ne 'RTMTwilio_1') { Say '      -> FAIL  stop, do not install: this is the 30.08 incident shape'; $fails++ }
    Say ("  RTM:PipeName           = '{0}'" -f $rtmJson.RTM.PipeName)
    Say ("  RTM:TenantId           = '{0}'" -f $rtmJson.RTM.TenantId)
    $rtmConn = "$($rtmJson.RTM.RTMConnectionString)"
    $rtmConnMasked = [regex]::Replace($rtmConn, '(?i)(password\s*=\s*)([^;]+)', '$1<masked>')
    Say ('  RTM connection string, password masked : {0}' -f $rtmConnMasked)
    if ($rtmConn -match '(?i)Port\s*=\s*(\d+)') {
        Say ('  RTM conn Port          = {0}   expected 5433' -f $Matches[1])
        if ($Matches[1] -ne '5433') { Say '      -> FAIL  the engine points at the OLD database'; $fails++ }
    } else { Say '  RTM conn Port          = NOT STATED in the string - then the engine uses the default 5432, and that is a finding, not a detail' }
    if ($rtmConn -match '(?i)password\s*=\s*([^;]+)') { $dbPassword = $Matches[1].Trim(); $passwordSource = 'RTM RTMConnectionString' }
}
$shellCfg = 'C:\RTMView\Shell\appsettings.json'
if (-not (Test-Path $shellCfg)) { Say ('  {0} ABSENT' -f $shellCfg); $fails++ }
else {
    $shellRaw = Get-Content $shellCfg -Raw
    $shellJson = $shellRaw | ConvertFrom-Json
    Say ('  top-level keys in Shell appsettings.json : {0}' -f (($shellJson.PSObject.Properties.Name) -join ', '))
    if ($shellJson.ConnectionStrings) { Say ('  keys under ConnectionStrings : {0}' -f (($shellJson.ConnectionStrings.PSObject.Properties.Name) -join ', ')) }
    else { Say '  ConnectionStrings : ABSENT as a section' }
    Say ("  Shell DefaultTenantSlug    = '{0}'   empty is the EXPECTED state while PR234-SHELL-CFG-01 is deferred" -f $shellJson.DefaultTenantSlug)
    Say ('  MetricsApply present       : {0}   expected False while deferred' -f ($shellRaw -match 'MetricsApply'))
    Say ('  RtmRelay override present  : {0}   v1 measured True, which is one of the four keys being present - a finding, not an error' -f ($shellRaw -match 'RtmRelay'))
    $serilogLines = @($shellRaw -split "`n" | Where-Object { $_ -match 'log-' })
    foreach ($serilogLine in $serilogLines) { Say ('  Serilog path line          : {0}' -f $serilogLine.Trim()) }
    Say '  a RELATIVE Serilog path means the running Shell writes its log into C:\Windows\System32\logs - half a day was lost to that'
    foreach ($connName in @('DefaultConnection','Default','RTMConnection','Postgres')) {
        if ($shellJson.ConnectionStrings -and $shellJson.ConnectionStrings.$connName) {
            $connStr = "$($shellJson.ConnectionStrings.$connName)"
            Say ('  ConnectionStrings.{0} , password masked : {1}' -f $connName, [regex]::Replace($connStr, '(?i)(password\s*=\s*)([^;]+)', '$1<masked>'))
            if (($null -eq $dbPassword) -and ($connStr -match '(?i)password\s*=\s*([^;]+)')) { $dbPassword = $Matches[1].Trim(); $passwordSource = ('Shell ConnectionStrings.' + $connName) }
        }
    }
}
if ($null -eq $dbPassword) { Say '  database password : NOT FOUND in any of the places checked - the database sections below are NOT MEASURED, which is a gap, not a pass' }
else { Say ('  database password : found in {0} , {1} characters, NOT printed' -f $passwordSource, $dbPassword.Length) }
Say ''

Say '===== 6  liveness - the PAIR, with the negative control on the address that ANSWERED ====='
$curlExe = Join-Path $env:SystemRoot 'System32\curl.exe'
$httpGreen = $false
$httpAddr = 'none'
$httpCode = '000'
if (-not (Test-Path $curlExe)) { Say '  curl.exe ABSENT - the HTTP half is NOT MEASURED, and that says nothing about the application'; $notMeasured++ }
else {
    foreach ($url in @('https://127.0.0.1:8444/health','https://localhost:8444/health','http://127.0.0.1:5000/health')) {
        $code = (& $curlExe -k -s -o NUL -w '%{http_code}' --max-time 15 $url) 2>$null
        Say ('  {0} -> {1}' -f $url, $code)
        if (("$code" -eq '200') -and ($httpAddr -eq 'none')) { $httpAddr = $url; $httpCode = "$code" }
    }
    if ($httpAddr -eq 'none') { Say '  no address answered 200 - UNREACHABLE or unhealthy; this is not a liveness verdict by itself'; $notMeasured++ }
    else {
        $body = (& $curlExe -k -s --max-time 15 $httpAddr) 2>$null
        $negUrl = $httpAddr -replace '/health','/zzz-no-such-endpoint'
        $negCode = (& $curlExe -k -s -o NUL -w '%{http_code}' --max-time 15 $negUrl) 2>$null
        Say ('  verdict taken on {0} : code {1} , body {2}' -f $httpAddr, $httpCode, $body)
        Say ('  NEGCTL on THAT SAME address -> {0}   must be neither 200 nor 000, or the pair proves nothing' -f $negCode)
        $httpGreen = (("$negCode" -ne '200') -and ("$negCode" -ne '000'))
    }
}
$pipeName = 'rtmpipe_v3'
if (Test-Path $rtmCfg) { $pipeName = "$((Get-Content $rtmCfg -Raw | ConvertFrom-Json).RTM.PipeName)" }
$pipeList = @([IO.Directory]::GetFiles('\\.\pipe\') | ForEach-Object { $_.Substring(9) })
Say ('  pipes visible in total : {0}   zero here means the measurement is broken, not that there are none' -f $pipeList.Count)
if ($pipeList.Count -eq 0) { Say '      -> FAIL  pipe enumeration returned nothing'; $fails++ }
$pipeServed = ($pipeList -contains $pipeName)
Say ("  pipe '{0}' served : {1}   expected True" -f $pipeName, $pipeServed)
Say ('  NEGCTL an impossible pipe served : {0}   expected False' -f ($pipeList -contains 'zzz-no-such-pipe-here'))
Say ('  LIVENESS BEFORE (both halves, or it is not liveness) : {0}' -f ($httpGreen -and $pipeServed))
if (-not ($httpGreen -and $pipeServed)) { Say '      a red here is a STOP for the install, not a detail - it goes to the coordinator'; $fails++ }
Say ''

Say '===== 7  the database, SELECT only - it names itself, and the instrument proves it can fail ====='
$psqlPath = $null
foreach ($pgDir in @(Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $candidate = Join-Path $pgDir.FullName 'bin\psql.exe'
    if ((Test-Path $candidate) -and ($null -eq $psqlPath)) { $psqlPath = $candidate }
}
if ($null -eq $psqlPath) { Say '  psql.exe NOT FOUND - the database sections are NOT MEASURED, which is a gap, not a pass'; $notMeasured++ }
elseif ($null -eq $dbPassword) { Say '  no password available from the machine config - the database sections are NOT MEASURED, which is a gap, not a pass'; $notMeasured++ }
else {
    Say ('  psql : {0}' -f $psqlPath)
    $env:PGCLIENTENCODING = 'UTF8'
    $env:PGPASSWORD = $dbPassword
    $badFile = Join-Path $env:TEMP ('probeA2_bad_' + $stamp + '.sql')
    [IO.File]::WriteAllText($badFile, "SELECT this_is_not_valid FROM;`n", (New-Object System.Text.UTF8Encoding($false)))
    $null = & $psqlPath -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=1 -At -f $badFile 2>&1
    $rcBad = $LASTEXITCODE
    Remove-Item $badFile -ErrorAction SilentlyContinue
    Say ('  INSTRUMENT CHECK a deliberately broken query : exit {0}   expected NON-zero, otherwise any zero below means only that psql started' -f $rcBad)
    if ($rcBad -eq 0) { Say '      *** psql does not fail on a broken query - refusing to trust its zeroes'; $env:PGPASSWORD = ''; Fin $false }
    $goodFile = Join-Path $env:TEMP ('probeA2_alive_' + $stamp + '.sql')
    [IO.File]::WriteAllText($goodFile, "SELECT 'ALIVE=1';`n", (New-Object System.Text.UTF8Encoding($false)))
    $aliveOut = & $psqlPath -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=1 -At -f $goodFile 2>&1
    $rcAlive = $LASTEXITCODE
    Remove-Item $goodFile -ErrorAction SilentlyContinue
    Say ('  INSTRUMENT CHECK a valid query : exit {0} , says {1}   expected 0 and ALIVE=1 - the broken-query code above means syntax, not a dead connection' -f $rcAlive, ($aliveOut -join ' '))
    if (($rcAlive -ne 0) -or ("$aliveOut" -notmatch 'ALIVE=1')) { Say '      *** no connection to the database - the sections below are NOT MEASURED'; $notMeasured++; $env:PGPASSWORD = '' }
    else {
        $sqlFile = Join-Path $env:TEMP ('probeA2_' + $stamp + '.sql')
        $resFile = Join-Path $OutDir ('234_' + $stamp + '_preinstall-sql.txt')
        $errFile = Join-Path $OutDir ('234_' + $stamp + '_preinstall-sql.err.txt')
        $sqlText = @'
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
SELECT 'rowcount NGC_BusinessUnit = ' || count(*)::text FROM "NGC_BusinessUnit";
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
        [IO.File]::WriteAllText($sqlFile, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
        $null = & $psqlPath -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=0 -At -o $resFile -f $sqlFile 2>$errFile
        $rcSql = $LASTEXITCODE
        $errSize = $(if (Test-Path $errFile) { (Get-Item $errFile).Length } else { 0 })
        Say ('  psql exit {0} ; results in {1} ; error file {2} bytes' -f $rcSql, $resFile, $errSize)
        Say '  psql writes the result file ITSELF via -o : no PowerShell variable stands between a native unicode stream and the file'
        if ($errSize -gt 0) {
            Say '  --- stderr, printed because a non-empty error file is a CONDITION, not a footnote ---'
            foreach ($errLine in (Get-Content $errFile)) { Say ('      ' + $errLine) }
            $fails++
        }
        if (Test-Path $resFile) { foreach ($resLine in (Get-Content $resFile)) { Say ('      ' + $resLine) } }
        Remove-Item $sqlFile -ErrorAction SilentlyContinue

        Say ''
        Say '  --- flow, three samples 60 s apart, on APPEND-ONLY tables (RTSData_UserStatus is an UPSERT and is NOT a gate) ---'
        $flowFile = Join-Path $env:TEMP ('probeA2_flow_' + $stamp + '.sql')
        $flowSql = @'
SELECT (SELECT count(*) FROM "RTSData_Interaction")::text || ' ' || (SELECT count(*) FROM "RTSData_UserStatusLog")::text || ' ' || now()::text;
'@
        [IO.File]::WriteAllText($flowFile, $flowSql, (New-Object System.Text.UTF8Encoding($false)))
        $samples = @()
        for ($sampleNo = 1; $sampleNo -le 3; $sampleNo++) {
            $sampleFile = Join-Path $env:TEMP ('probeA2_flow_out_' + $stamp + '_' + $sampleNo + '.txt')
            $null = & $psqlPath -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=1 -At -o $sampleFile -f $flowFile 2>&1
            $sampleLine = $(if (Test-Path $sampleFile) { (Get-Content $sampleFile | Select-Object -First 1) } else { 'NO RESULT' })
            Say ('      sample {0} : {1}' -f $sampleNo, $sampleLine)
            $samples += "$sampleLine"
            Remove-Item $sampleFile -ErrorAction SilentlyContinue
            if ($sampleNo -lt 3) { Start-Sleep -Seconds 60 }
        }
        Remove-Item $flowFile -ErrorAction SilentlyContinue
        try {
            $interFirst = [int64](($samples[0] -split ' ')[0]); $interLast = [int64](($samples[2] -split ' ')[0])
            $logFirst   = [int64](($samples[0] -split ' ')[1]); $logLast   = [int64](($samples[2] -split ' ')[1])
            Say ('      Interaction   {0} -> {1}   delta {2}' -f $interFirst, $interLast, ($interLast - $interFirst))
            Say ('      UserStatusLog {0} -> {1}   delta {2}' -f $logFirst, $logLast, ($logLast - $logFirst))
            if (($interLast -lt $interFirst) -or ($logLast -lt $logFirst)) { Say '      -> FAIL  a count WENT DOWN on an append-only table'; $fails++ }
            elseif (($interLast -gt $interFirst) -or ($logLast -gt $logFirst)) { Say '      -> PASS  the feed is growing' }
            else { Say '      -> QUIET: neither table grew in two minutes. Both may legally stand still in a quiet hour (Interaction upserts per segment, UserStatusLog writes only on a status change), so this is NOT a FAIL by itself: the feed is UNPROVEN in this window, and whether to wait for a busy one is the coordinator decision.'; $notMeasured++ }
        } catch { Say ('      -> the samples could not be parsed: {0}   NOT MEASURED, not a pass' -f $_.Exception.Message); $notMeasured++ }
        $env:PGPASSWORD = ''
    }
}
Say ''

Say '===== 8  the adapter log - the observability that was missing for two days ====='
$adapterLog = 'C:\Logs\RTM.Twilio\log.txt'
if (-not (Test-Path $adapterLog)) { Say ('  {0} : ABSENT - after the update, this file existing and being fresh is the gate for edit 2' -f $adapterLog) }
else {
    $logItem = Get-Item $adapterLog
    Say ('  {0}   {1} bytes   modified {2}   age {3:N0} minutes' -f $adapterLog, $logItem.Length, $logItem.LastWriteTime, ((Get-Date) - $logItem.LastWriteTime).TotalMinutes)
    Say '  --- last 6 lines, verbatim ---'
    foreach ($logLine in (Get-Content $adapterLog -Tail 6)) { Say ('      ' + $logLine) }
    $errorHits = @(Select-String -Path $adapterLog -Pattern 'ERROR' -SimpleMatch -ErrorAction SilentlyContinue)
    $nullKeyHits = @(Select-String -Path $adapterLog -Pattern "Value cannot be null. (Parameter 'key')" -SimpleMatch -ErrorAction SilentlyContinue)
    Say ('  lines containing ERROR : {0}' -f $errorHits.Count)
    Say ('  lines of the known null-key defect : {0}   this is product defect 1 from the handoff, recorded and NOT fixed here' -f $nullKeyHits.Count)
    Say ('  POSCTL lines containing a letter that must be there (e) : {0}   zero would mean the search is blind' -f @(Select-String -Path $adapterLog -Pattern 'e' -SimpleMatch -ErrorAction SilentlyContinue).Count)
    Say ('  NEGCTL lines containing an impossible phrase : {0}   expected 0' -f @(Select-String -Path $adapterLog -Pattern 'ZzzNoSuchPhraseHere' -SimpleMatch -ErrorAction SilentlyContinue).Count)
}
Say ''

Say '===== SUMMARY - this is the BEFORE half. Nothing here was changed. ====='
Say ('  collector type at exit : {0}   expected ArrayList - v1 lost its report here, because a foreach variable overwrote it' -f $Report.GetType().Name)
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Say '  *** the collector was overwritten - the report on disk is incomplete'; $fails++ }
Say ('  adapter log4net.config equals the 140 reference : {0}' -f ((Get-Sha256Of $adapterCfg) -eq $REF_LOG4NET))
$dataSysPath = 'C:\RTMView\RTM\data.sys'
$dataSysShaAtExit = Get-Sha256Of $dataSysPath
Say ('  data.sys starts with the machine reference      : {0}' -f ($dataSysShaAtExit.StartsWith($DATASYS_PREFIX)))
Say ('  failures     : {0}   anything above zero is a STOP: it goes to the coordinator before any write' -f $fails)
Say ('  NOT MEASURED : {0}   these are gaps, not passes, and they are named where they occur' -f $notMeasured)
Say '  Numbers to carry into the AFTER run: the eight config hashes, the three directory file counts and'
Say '  newest timestamps, the three executable mtimes and hashes, and the list of backup directories.'
Say '  NOTHING WAS STARTED, STOPPED, INSTALLED OR CHANGED. EVERY DATABASE STATEMENT WAS A SELECT.'
Say '===== END-OF-RUN MARKER: PREINSTALL-STATE-V2-COMPLETE ====='
Fin ($fails -eq 0)
