#Requires -Version 5.1
<#
  PROBE 234 / state   -   READ ONLY. Starts nothing, stops nothing, installs nothing, changes nothing.
  WHERE IT RUNS : server 234 (RTM). Database rtmviewdb on port 5433. READ ONLY, SELECT only.
  WHY : the last measurement of this machine is hours old and was taken by a session that has since
        ended. Before a rebuild and a fresh install we measure what is actually there, in this
        awakening, instead of inheriting it from a note.
  Password is NOT prompted: it is read from the machine own Shell config and only its length printed.
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_state.txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}

Say "===== G0  machine identity - this probe refuses to run anywhere else ====="
$n = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$u = ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  name match {0} / uuid match {1}" -f $n, $u)
if (-not ($n -and $u)) { Say "  *** NOT server 234 - refusing"; Fin $false; exit 1 }
Say "  G0 PASS"
Say ""

Say "===== 1  services - name, state, start mode, and the exe PATH ====="
$want = @("RTMService","RTMViewShell","RTMTwilio_1","RTM.Twilio","RTM","RTMApplyService")
foreach ($s in $want) {
    $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $s) -ErrorAction SilentlyContinue
    if ($null -eq $svc) { Say ("  {0,-16} ABSENT (not installed on this machine)" -f $s) }
    else { Say ("  {0,-16} {1,-9} {2,-10} {3}" -f $svc.Name, $svc.State, $svc.StartMode, $svc.PathName) }
}
Say "  NEGCTL a service that cannot exist:"
$neg = Get-CimInstance Win32_Service -Filter "Name='ZzzNoSuchServiceHere'" -ErrorAction SilentlyContinue
Say ("      returned : {0}   (must be nothing)" -f $(if ($null -eq $neg) { "ABSENT" } else { "*** FOUND - predicate broken" }))
Say ""

Say "===== 2  running processes under C:\RTMView (a stopped service can leave an orphan) ====="
$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "C:\RTMView\*" })
Say ("  processes found : {0}" -f $procs.Count)
foreach ($p in $procs) { Say ("      {0,-18} pid {1,-8} started {2}   {3}" -f $p.ProcessName, $p.Id, $p.StartTime, $p.Path) }
Say ""

Say "===== 3  the product tree on disk ====="
if (-not (Test-Path "C:\RTMView")) { Say "  C:\RTMView : DOES NOT EXIST" }
else {
    foreach ($d in @(Get-ChildItem "C:\RTMView" -Directory -ErrorAction SilentlyContinue)) {
        $cnt = @(Get-ChildItem $d.FullName -Recurse -File -ErrorAction SilentlyContinue).Count
        Say ("  {0,-24} {1,6} files   modified {2}" -f $d.Name, $cnt, $d.LastWriteTime)
    }
}
Say ""

Say "===== 4  data.sys - the live file and every preserved copy, by hash ====="
function H($p) { if (Test-Path $p) { (Get-FileHash $p -Algorithm SHA256).Hash } else { "ABSENT" } }
$live = "C:\RTMView\RTM\data.sys"
Say ("  LIVE  {0}" -f $live)
Say ("        sha256 {0}" -f (H $live))
if (Test-Path $live) { Say ("        size {0} bytes, modified {1}" -f (Get-Item $live).Length, (Get-Item $live).LastWriteTime) }
$copies = @(Get-ChildItem "C:\RTMView" -Recurse -Filter "data.sys" -ErrorAction SilentlyContinue | Where-Object { $_.FullName -ne $live })
Say ("  other copies found : {0}" -f $copies.Count)
foreach ($c in $copies) { Say ("      {0}`n        sha256 {1}   modified {2}" -f $c.FullName, (H $c.FullName), $c.LastWriteTime) }
Say "  reference from the handoff : 24F0BFAC... = the machine file ; 7745C5CA... = the one the installer ships"
Say ("  NEGCTL hash of a path that cannot exist : {0}   (must be ABSENT)" -f (H "C:\RTMView\zzz-no-such-file.sys"))
Say ""

Say "===== 5  config, READ FROM DISK - not from what any command reported ====="
$rtmCfg = "C:\RTMView\RTM\appsettings.json"
if (-not (Test-Path $rtmCfg)) { Say ("  {0} : ABSENT" -f $rtmCfg) }
else {
    $j = Get-Content $rtmCfg -Raw | ConvertFrom-Json
    Say ("  RTM:AdaptorServiceName = '{0}'" -f $j.RTM.AdaptorServiceName)
    Say ("  RTM:PipeName           = '{0}'" -f $j.RTM.PipeName)
    Say ("  RTM:TenantId           = '{0}'" -f $j.RTM.TenantId)
    $cs = "$($j.RTM.RTMConnectionString)"
    if ($cs -match "Port\s*=\s*(\d+)") { Say ("  RTM conn Port          = {0}" -f $Matches[1]) } else { Say "  RTM conn Port          = not stated in the string" }
}
$shCfg = "C:\RTMView\Shell\appsettings.json"
if (-not (Test-Path $shCfg)) { Say ("  {0} : ABSENT" -f $shCfg) }
else {
    $s = Get-Content $shCfg -Raw | ConvertFrom-Json
    Say ("  Shell DefaultTenantSlug = '{0}'" -f $s.DefaultTenantSlug)
    $scs = "$($s.ConnectionStrings.DefaultConnection)"
    if ($scs -match "Port\s*=\s*(\d+)") { Say ("  Shell conn Port         = {0}" -f $Matches[1]) } else { Say "  Shell conn Port         = not stated" }
    if ($scs -match "Database\s*=\s*([^;]+)")  { Say ("  Shell conn Database     = {0}" -f $Matches[1].Trim()) }
    if ($scs -match "Username\s*=\s*([^;]+)")  { Say ("  Shell conn Username     = {0}" -f $Matches[1].Trim()) }
    if ($scs -match "Password\s*=\s*([^;]+)")  { $script:PW = $Matches[1].Trim(); Say ("  Shell conn Password     = present, {0} characters (NOT printed)" -f $script:PW.Length) }
    else { Say "  Shell conn Password     = NOT FOUND in the string" }
}
Say ""

Say "===== 6  liveness - the PAIR. 200 alone is not liveness. ====="
$curl = "$env:SystemRoot\System32\curl.exe"
if (-not (Test-Path $curl)) {
    Say "  curl.exe ABSENT - cannot measure HTTP by an external process; NOT calling it green"
    $http200 = $false
} else {
    $code = (& $curl -k -s -o NUL -w "%{http_code}" --max-time 15 "https://127.0.0.1:8444/health") 2>$null
    $body = (& $curl -k -s --max-time 15 "https://127.0.0.1:8444/health") 2>$null
    $negc = (& $curl -k -s -o NUL -w "%{http_code}" --max-time 15 "https://127.0.0.1:8444/zzz-no-such-endpoint") 2>$null
    Say ("  https 8444 /health -> {0}   body '{1}'" -f $code, $body)
    Say ("  NEGCTL /zzz        -> {0}   (200 here would void the line above)" -f $negc)
    $http200 = (("$code" -eq "200") -and ("$negc" -ne "200"))
}
$pipeName = "rtmpipe_v3"
if (Test-Path $rtmCfg) { $pipeName = "$((Get-Content $rtmCfg -Raw | ConvertFrom-Json).RTM.PipeName)" }
$pipes = @([IO.Directory]::GetFiles("\\.\pipe\") | ForEach-Object { $_.Substring(9) })
Say ("  pipes visible in total : {0}   (0 here means the measurement is broken, not that there are none)" -f $pipes.Count)
$served = ($pipes -contains $pipeName)
Say ("  pipe '{0}' served : {1}" -f $pipeName, $served)
Say ("  NEGCTL impossible pipe served : {0}   (must be False)" -f ($pipes -contains "zzz-no-such-pipe-here"))
Say ("  first pipe names, as a control : {0}" -f (($pipes | Select-Object -First 5) -join ", "))
$liveness = ($http200 -and $served)
Say ("  LIVENESS (both, or it is not liveness) : {0}" -f $liveness)
Say ""

Say "===== 7  the database names itself - no assuming which one we reached ====="
$psql = $null
$cands = @(Get-ChildItem "C:\Program Files\PostgreSQL" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
foreach ($c in $cands) { $p = Join-Path $c.FullName "bin\psql.exe"; if ((Test-Path $p) -and ($null -eq $psql)) { $psql = $p } }
if ($null -eq $psql) { Say "  psql.exe NOT FOUND - database section skipped, and that is a gap, not a pass" }
elseif (-not $script:PW) { Say "  no password available from the Shell config - database section skipped" }
else {
    Say ("  psql : {0}" -f $psql)
    $sqlf = Join-Path $env:TEMP ("probe_state_{0}.sql" -f $stamp)
    $sql = @'
SELECT 'db=' || current_database() || ' port=' || inet_server_port() || ' user=' || current_user AS whoami;
SELECT 'tenant ' || "Id" || ' | ' || "Slug" || ' | ' || "Status" FROM tenants ORDER BY "Slug";
SELECT 'regclass RTSGrid_Metric = ' || coalesce(to_regclass('public."RTSGrid_Metric"')::text,'NULL');
SELECT 'regclass NGC_BusinessUnit = ' || coalesce(to_regclass('public."NGC_BusinessUnit"')::text,'NULL');
SELECT 'regclass RTSData_Interaction = ' || coalesce(to_regclass('public."RTSData_Interaction"')::text,'NULL');
SELECT 'NEGCTL regclass zzz_no_such_table = ' || coalesce(to_regclass('public."zzz_no_such_table"')::text,'NULL');
SELECT 'users total = ' || count(*)::text FROM identity.users;
'@
    [IO.File]::WriteAllText($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $script:PW
    $rows = & $psql -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb -At -f $sqlf 2>&1
    $env:PGPASSWORD = ""
    Remove-Item $sqlf -ErrorAction SilentlyContinue
    foreach ($r in $rows) { Say ("      {0}" -f $r) }
    Say ("  psql exit code : {0}" -f $LASTEXITCODE)
}
Say ""

Say "===== 8  engine log - the RTMTwilio_1 line, VERBATIM, no interpretation ====="
$rtmLog = "C:\RTMView\RTM\Logs\RTM.log"
if (-not (Test-Path $rtmLog)) { Say ("  {0} : ABSENT" -f $rtmLog) }
else {
    Say ("  file {0}   {1} bytes   modified {2}" -f $rtmLog, (Get-Item $rtmLog).Length, (Get-Item $rtmLog).LastWriteTime)
    $hits = @(Select-String -Path $rtmLog -Pattern "RTMTwilio_1" -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -Last 8)
    Say ("  lines mentioning RTMTwilio_1 : {0}" -f $hits.Count)
    foreach ($h in $hits) { Say ("      {0}" -f $h.Line) }
    $pos = @(Select-String -Path $rtmLog -Pattern "INFO" -SimpleMatch -ErrorAction SilentlyContinue).Count
    Say ("  POSITIVE control - lines containing INFO : {0}   (0 here means this search is blind)" -f $pos)
    Say "  --- last 6 lines of the log ---"
    foreach ($l in (Get-Content $rtmLog -Tail 6)) { Say ("      {0}" -f $l) }
}
Say ""

Say "===== SUMMARY ====="
Say ("  liveness pair : {0}" -f $liveness)
Say "  Everything above is a reading. NOTHING WAS STARTED, STOPPED OR CHANGED."
Say "===== END-OF-RUN MARKER: STATE-COMPLETE ====="
Fin $true
exit 0
