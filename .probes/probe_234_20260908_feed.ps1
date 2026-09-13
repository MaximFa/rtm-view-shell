#Requires -Version 5.1
<#
  PROBE 234 / feed   -   READ ONLY. Starts nothing, stops nothing, changes nothing.
  WHERE IT RUNS : server 234. Database rtmviewdb on port 5433. SELECT only.
  QUESTION      : the Shell shows no contact-centre data after the clean install. Where does the
                  wire stop - at the adapter, at the pipe, at the engine, or at the database.

  Method: walk the path in ORDER and let each section answer for its own segment. Column names
  come from information_schema BEFORE any query uses them - guessing them has already cost us
  one measurement. Nothing here interprets: it prints.
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_feed.txt"
$ProbeLines = New-Object System.Collections.ArrayList
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$ProbeLines.Add("")
    [void]$ProbeLines.Add($(if ($pass) { "RUN COMPLETE" } else { "RUN ABORTED" }))
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($path) { if (Test-Path $path) { (Get-FileHash $path -Algorithm SHA256).Hash } else { "ABSENT" } }
function Show-Log($path, $tailCount) {
    if (-not (Test-Path $path)) { Say ("      {0} : ABSENT" -f $path); return }
    $fi = Get-Item $path
    Say ("      {0}" -f $path)
    Say ("      {0} bytes, modified {1}" -f $fi.Length, $fi.LastWriteTime)
    foreach ($t in (Get-Content $path -Tail $tailCount)) { Say ("        {0}" -f $t) }
}

Say "===== G0  machine identity ====="
$nameOk = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ("  name match {0} / uuid match {1}" -f $nameOk, ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))
if (-not ($nameOk -and ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))) { Say "  *** NOT 234"; Fin $false }
Say ("  time now : {0}" -f (Get-Date))
Say "  G0 PASS"
Say ""

Say "===== 1  SEGMENT A - the adapter: is it running, and what does its own log say ====="
$svc = Get-CimInstance Win32_Service -Filter "Name='RTMTwilio_1'" -ErrorAction SilentlyContinue
if ($null -eq $svc) { Say "  RTMTwilio_1 ABSENT" } else { Say ("  RTMTwilio_1 {0} / {1} / {2}" -f $svc.State, $svc.StartMode, $svc.PathName) }
$p = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "C:\RTMView\RTM.Twilio\*" })
foreach ($pp in $p) { Say ("  process {0} pid {1} started {2}" -f $pp.ProcessName, $pp.Id, $pp.StartTime) }
Say ("  processes under the adapter directory : {0}" -f $p.Count)
$twDir = "C:\RTMView\RTM.Twilio"
$logDirs = @(Get-ChildItem $twDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "(?i)log" })
Say ("  log directories under the adapter : {0}" -f $logDirs.Count)
$twLogs = @(Get-ChildItem $twDir -Recurse -File -Include "*.log","*.txt" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
Say ("  adapter log files found : {0}" -f $twLogs.Count)
foreach ($lg in $twLogs) { Show-Log $lg.FullName 25 }
if ($twLogs.Count -eq 0) { Say "      (no adapter log files - that is an answer about logging, not about the adapter)" }
Say ""

Say "===== 2  SEGMENT B - the pipe between adapter and engine ====="
$rtmCfg = "C:\RTMView\RTM\appsettings.json"
$jr = Get-Content $rtmCfg -Raw | ConvertFrom-Json
$pipeName = "$($jr.RTM.PipeName)"
$pipes = @([IO.Directory]::GetFiles("\\.\pipe\") | ForEach-Object { $_.Substring(9) })
Say ("  pipes visible in total : {0}   (0 would mean this measurement is broken)" -f $pipes.Count)
Say ("  pipe '{0}' served : {1}" -f $pipeName, ($pipes -contains $pipeName))
Say ("  legacy pipe 'rtmpipe' also present : {0}   (informational - we must not use it)" -f ($pipes -contains "rtmpipe"))
Say ("  NEGCTL impossible pipe : {0}   (must be False)" -f ($pipes -contains "zzz-no-pipe"))
$twCfg = Join-Path $twDir "appsettings.json"
if (Test-Path $twCfg) {
    $rawTw = Get-Content $twCfg -Raw
    $jt = $rawTw | ConvertFrom-Json
    Say ("  adapter config top-level keys : {0}" -f (($jt.PSObject.Properties.Name) -join ", "))
    $pipeHits = @([regex]::Matches($rawTw, "(?i)`"([A-Za-z]*Pipe[A-Za-z]*)`"\s*:\s*`"([^`"]*)`""))
    if ($pipeHits.Count -eq 0) { Say "  no key with 'Pipe' in its name inside the adapter config" }
    else { foreach ($ph in $pipeHits) { Say ("  adapter '{0}' = '{1}'" -f $ph.Groups[1].Value, $ph.Groups[2].Value) } }
    $portHits = @([regex]::Matches($rawTw, "(?i)`"([A-Za-z]*Port[A-Za-z]*)`"\s*:\s*(\d+)"))
    foreach ($ph in $portHits) { Say ("  adapter '{0}' = {1}" -f $ph.Groups[1].Value, $ph.Groups[2].Value) }
} else { Say "  adapter appsettings.json ABSENT" }
Say ""

Say "===== 3  SEGMENT C - the engine log, by category, with a positive control ====="
$rtmLog = "C:\RTMView\RTM\Logs\RTM.log"
if (-not (Test-Path $rtmLog)) { Say "  engine log ABSENT" }
else {
    $fi = Get-Item $rtmLog
    Say ("  {0}  {1} bytes, modified {2}" -f $rtmLog, $fi.Length, $fi.LastWriteTime)
    foreach ($pat in @("INFO","ERROR","WARN","Exception","License","Client","Connect","Union","LoadData","setUsersStatusList","CollectData")) {
        $c = @(Select-String -Path $rtmLog -Pattern $pat -SimpleMatch -ErrorAction SilentlyContinue).Count
        Say ("  lines containing '{0}' : {1}" -f $pat, $c)
    }
    Say ("  NEGCTL lines containing 'ZzzNoSuchWord' : {0}   (must be 0)" -f @(Select-String -Path $rtmLog -Pattern "ZzzNoSuchWord" -SimpleMatch -ErrorAction SilentlyContinue).Count)
    Say "  --- last 5 ERROR/Exception lines, verbatim ---"
    $errs = @(Select-String -Path $rtmLog -Pattern "ERROR","Exception" -ErrorAction SilentlyContinue | Select-Object -Last 5)
    if ($errs.Count -eq 0) { Say "      (none)" } else { foreach ($e in $errs) { Say ("      {0}" -f $e.Line) } }
    Say "  --- last 15 lines of the engine log ---"
    foreach ($t in (Get-Content $rtmLog -Tail 15)) { Say ("      {0}" -f $t) }
}
Say ""

Say "===== 4  SEGMENT D - the database: what tables exist, then what is in them ====="
$shellCfg = "C:\RTMView\Shell\appsettings.json"
$cs = "$((Get-Content $shellCfg -Raw | ConvertFrom-Json).ConnectionStrings.Default)"
$pw = ""; $usr = "ccdashboard_user"; $db = "rtmviewdb"; $port = "5433"
$m = [regex]::Match($cs, "(?i)Password\s*=\s*([^;]+)"); if ($m.Success) { $pw = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Username\s*=\s*([^;]+)"); if ($m.Success) { $usr = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Database\s*=\s*([^;]+)"); if ($m.Success) { $db  = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Port\s*=\s*(\d+)");       if ($m.Success) { $port = $m.Groups[1].Value }
$psql = $null
foreach ($pg in @(Get-ChildItem "C:\Program Files\PostgreSQL" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $c = Join-Path $pg.FullName "bin\psql.exe"; if ((Test-Path $c) -and ($null -eq $psql)) { $psql = $c }
}
if ($null -eq $psql -or -not $pw) { Say "  psql or password unavailable - this section is a GAP" }
else {
    $sqlf = Join-Path $env:TEMP ("feed_{0}.sql" -f $stamp)
    $sql = @'
SELECT 'whoami: db=' || current_database() || ' port=' || inet_server_port();
SELECT '--- columns of the tables this probe queries, from information_schema ---';
SELECT table_name || ' . ' || column_name || ' : ' || data_type
  FROM information_schema.columns
 WHERE table_schema='public'
   AND table_name IN ('NGC_Site','NGC_BusinessUnit','NGC_Queues','RTSData_Interaction','RTSData_UserStatus')
 ORDER BY table_name, ordinal_position;
SELECT '--- existence, via to_regclass ---';
SELECT 'NGC_Site = '            || coalesce(to_regclass('public."NGC_Site"')::text,'NULL');
SELECT 'NGC_BusinessUnit = '    || coalesce(to_regclass('public."NGC_BusinessUnit"')::text,'NULL');
SELECT 'NGC_Queues = '          || coalesce(to_regclass('public."NGC_Queues"')::text,'NULL');
SELECT 'RTSData_Interaction = ' || coalesce(to_regclass('public."RTSData_Interaction"')::text,'NULL');
SELECT 'RTSData_UserStatus = '  || coalesce(to_regclass('public."RTSData_UserStatus"')::text,'NULL');
SELECT 'NEGCTL zzz_no_such = '  || coalesce(to_regclass('public."zzz_no_such"')::text,'NULL');
SELECT '--- row counts ---';
SELECT 'NGC_Site rows = '            || count(*)::text FROM public."NGC_Site";
SELECT 'NGC_BusinessUnit rows = '    || count(*)::text FROM public."NGC_BusinessUnit";
SELECT 'NGC_Queues rows = '          || count(*)::text FROM public."NGC_Queues";
SELECT 'RTSData_Interaction rows = ' || count(*)::text FROM public."RTSData_Interaction";
SELECT 'RTSData_UserStatus rows = '  || count(*)::text FROM public."RTSData_UserStatus";
SELECT 'tenants rows = '             || count(*)::text FROM public.tenants;
SELECT 'dashboards rows = '          || count(*)::text FROM public.dashboards;
'@
    [IO.File]::WriteAllText($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $pw
    $rows = & $psql -h 127.0.0.1 -p $port -U $usr -d $db -At -f $sqlf 2>&1
    $rc = $LASTEXITCODE
    $env:PGPASSWORD = ""
    Remove-Item $sqlf -ErrorAction SilentlyContinue
    foreach ($r in $rows) { Say ("      {0}" -f $r) }
    Say ("  psql exit code : {0}   (non-zero means this section measured less than it claims)" -f $rc)
}
Say ""

Say "===== 5  SEGMENT E - the Shell's own log ====="
Show-Log "C:\Logs\RTMViewShell\log-20260908.txt" 20
Show-Log "C:\RTMView\Shell\Logs\log-20260908.txt" 20
Say ""

Say "===== SUMMARY ====="
Say "  This probe does not conclude. It shows each segment of the wire in order:"
Say "  A adapter -> B pipe -> C engine -> D database -> E shell."
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "  NOTHING WAS STARTED, STOPPED OR CHANGED."
Say "===== END-OF-RUN MARKER: FEED-COMPLETE ====="
Fin $true
