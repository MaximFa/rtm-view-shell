#Requires -Version 5.1
<#
  PROBE 234 / state-2   -   READ ONLY. Starts nothing, stops nothing, installs nothing, changes nothing.
  WHERE IT RUNS : server 234 (RTM). Database rtmviewdb on port 5433. READ ONLY, SELECT only.

  WHY A SECOND RUN : the first probe had three defects of its own, all in the instrument:
    (1) a helper named H was shadowed by the built-in ALIAS h = Get-History (aliases outrank
        functions), so every data.sys hash was never taken - it called Get-History instead;
    (2) the collector variable $L was clobbered by a loop variable $l - PowerShell is
        case-insensitive, they are ONE variable - so the report file lost its tail;
    (3) the Shell config was read by GUESSED key paths; they returned empty, which is
        indistinguishable from a genuinely empty setting. This run PRINTS THE ACTUAL KEYS.
  Everything measured cleanly the first time is measured again here, so this file stands alone.
  Password is NOT prompted and NOT printed: only whether one was found, and its length.
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_state-2.txt"
$ProbeLines = New-Object System.Collections.ArrayList
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($path) { if (Test-Path $path) { (Get-FileHash $path -Algorithm SHA256).Hash } else { "ABSENT" } }

Say "===== G0  machine identity - this probe refuses to run anywhere else ====="
$nameOk = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  name match {0} / uuid match {1}" -f $nameOk, $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say "  *** NOT server 234 - refusing"; Fin $false }
Say "  G0 PASS"
Say ""

Say "===== G1  the instrument checks ITSELF before it measures anything ====="
$cmd = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ("  Get-Sha256Of resolves to : {0}   (must be Function, not Alias)" -f $cmd.CommandType)
if ("$($cmd.CommandType)" -ne "Function") { Say "  *** the helper is shadowed - this is defect (1) again"; Fin $false }
$probeSelf = $MyInvocation.MyCommand.Path
$selfHash = Get-Sha256Of $probeSelf
Say ("  POSCTL hash of this very file : {0}" -f $selfHash)
if ("$selfHash" -eq "ABSENT") { Say "  *** the hasher cannot hash a file that exists - blind"; Fin $false }
Say ("  NEGCTL hash of a path that cannot exist : {0}   (must be ABSENT)" -f (Get-Sha256Of "C:\zzz-no-such-file-here.bin"))
Say ("  collector type : {0}   (must be ArrayList)" -f $ProbeLines.GetType().Name)
Say "  G1 PASS"
Say ""

Say "===== 1  services - name, state, start mode, and the exe PATH ====="
foreach ($svcName in @("RTMService","RTMViewShell","RTMTwilio_1","RTM.Twilio","RTM","RTMApplyService")) {
    $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $svcName) -ErrorAction SilentlyContinue
    if ($null -eq $svc) { Say ("  {0,-16} ABSENT (not installed on this machine)" -f $svcName) }
    else { Say ("  {0,-16} {1,-9} {2,-10} {3}" -f $svc.Name, $svc.State, $svc.StartMode, $svc.PathName) }
}
$negSvc = Get-CimInstance Win32_Service -Filter "Name='ZzzNoSuchServiceHere'" -ErrorAction SilentlyContinue
Say ("  NEGCTL impossible service : {0}   (must be ABSENT)" -f $(if ($null -eq $negSvc) { "ABSENT" } else { "*** FOUND - predicate broken" }))
Say ""

Say "===== 2  running processes under C:\RTMView, matched BY PATH not by service state ====="
$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "C:\RTMView\*" })
Say ("  processes found : {0}" -f $procs.Count)
foreach ($proc in $procs) { Say ("      {0,-18} pid {1,-8} started {2}   {3}" -f $proc.ProcessName, $proc.Id, $proc.StartTime, $proc.Path) }
Say ""

Say "===== 3  the product tree on disk ====="
if (-not (Test-Path "C:\RTMView")) { Say "  C:\RTMView : DOES NOT EXIST" }
else {
    foreach ($dir in @(Get-ChildItem "C:\RTMView" -Directory -ErrorAction SilentlyContinue)) {
        $cnt = @(Get-ChildItem $dir.FullName -Recurse -File -ErrorAction SilentlyContinue).Count
        Say ("  {0,-24} {1,6} files   modified {2}" -f $dir.Name, $cnt, $dir.LastWriteTime)
    }
}
Say ""

Say "===== 4  WHERE ARE THE PRESERVED COPIES - searched wide, not only under the product ====="
Say "  (the first run found ZERO copies under C:\RTMView and its Backup folder holds 0 files)"
$roots = @("C:\RTMView","C:\RTMView-Ops","C:\Temp","D:\RTMView-Ops","D:\Temp")
foreach ($root in $roots) {
    if (-not (Test-Path $root)) { Say ("  {0,-20} : path does not exist" -f $root); continue }
    $preserveDirs = @(Get-ChildItem $root -Recurse -Directory -Filter "preserve*" -ErrorAction SilentlyContinue)
    $found = @(Get-ChildItem $root -Recurse -File -Filter "data.sys" -ErrorAction SilentlyContinue)
    Say ("  {0,-20} : preserve* dirs {1,3} , data.sys files {2,3}" -f $root, $preserveDirs.Count, $found.Count)
    foreach ($pd in $preserveDirs) { Say ("        DIR  {0}   ({1} files)" -f $pd.FullName, @(Get-ChildItem $pd.FullName -Recurse -File -ErrorAction SilentlyContinue).Count) }
    foreach ($fd in $found) { Say ("        FILE {0}`n             sha256 {1}   {2} bytes   modified {3}" -f $fd.FullName, (Get-Sha256Of $fd.FullName), $fd.Length, $fd.LastWriteTime) }
}
Say ""
Say "  reference hashes from the record, for comparison by eye:"
Say "      24F0BFAC...DE43 = the machine file (the licensed one)"
Say "      7745C5CA...476D = the one the installer ships (overwrites the machine file)"
Say ""

Say "===== 5  config, READ FROM DISK - and the KEYS ARE PRINTED, not assumed ====="
$rtmCfg   = "C:\RTMView\RTM\appsettings.json"
$shellCfg = "C:\RTMView\Shell\appsettings.json"

if (-not (Test-Path $rtmCfg)) { Say ("  {0} : ABSENT" -f $rtmCfg) }
else {
    $rawRtm = Get-Content $rtmCfg -Raw
    $jsonRtm = $rawRtm | ConvertFrom-Json
    Say ("  --- {0} ({1} bytes) ---" -f $rtmCfg, $rawRtm.Length)
    Say ("  top-level keys : {0}" -f (($jsonRtm.PSObject.Properties.Name) -join ", "))
    if ($jsonRtm.RTM) { Say ("  RTM section keys : {0}" -f (($jsonRtm.RTM.PSObject.Properties.Name) -join ", ")) }
    Say ("  RTM:AdaptorServiceName = '{0}'" -f $jsonRtm.RTM.AdaptorServiceName)
    Say ("  RTM:PipeName           = '{0}'" -f $jsonRtm.RTM.PipeName)
    Say ("  RTM:TenantId           = '{0}'" -f $jsonRtm.RTM.TenantId)
    $portHits = @([regex]::Matches($rawRtm, "(?i)Port\s*=\s*(\d+)"))
    Say ("  ports named anywhere in this file : {0}" -f $(if ($portHits.Count -eq 0) { "none" } else { (($portHits | ForEach-Object { $_.Groups[1].Value }) -join ", ") }))
}
Say ""
if (-not (Test-Path $shellCfg)) { Say ("  {0} : ABSENT" -f $shellCfg) }
else {
    $rawShell = Get-Content $shellCfg -Raw
    $jsonShell = $rawShell | ConvertFrom-Json
    Say ("  --- {0} ({1} bytes) ---" -f $shellCfg, $rawShell.Length)
    Say ("  top-level keys : {0}" -f (($jsonShell.PSObject.Properties.Name) -join ", "))
    if ($jsonShell.ConnectionStrings) { Say ("  ConnectionStrings keys : {0}" -f (($jsonShell.ConnectionStrings.PSObject.Properties.Name) -join ", ")) }
    else { Say "  ConnectionStrings : the section is ABSENT from this file" }
    $slugHits = @([regex]::Matches($rawShell, '(?i)"([A-Za-z]*TenantSlug[A-Za-z]*)"\s*:\s*"([^"]*)"'))
    if ($slugHits.Count -eq 0) { Say "  any key whose name contains TenantSlug : NOT PRESENT in the file at all" }
    else { foreach ($m in $slugHits) { Say ("  key '{0}' = '{1}'" -f $m.Groups[1].Value, $m.Groups[2].Value) } }
    $portHits2 = @([regex]::Matches($rawShell, "(?i)Port\s*=\s*(\d+)"))
    Say ("  ports named anywhere in this file : {0}" -f $(if ($portHits2.Count -eq 0) { "none" } else { (($portHits2 | ForEach-Object { $_.Groups[1].Value }) -join ", ") }))
    $dbHits = @([regex]::Matches($rawShell, "(?i)Database\s*=\s*([^;`"]+)"))
    Say ("  databases named anywhere : {0}" -f $(if ($dbHits.Count -eq 0) { "none" } else { (($dbHits | ForEach-Object { $_.Groups[1].Value.Trim() }) -join ", ") }))
    $userHits = @([regex]::Matches($rawShell, "(?i)(?:Username|User ID)\s*=\s*([^;`"]+)"))
    Say ("  db users named anywhere : {0}" -f $(if ($userHits.Count -eq 0) { "none" } else { (($userHits | ForEach-Object { $_.Groups[1].Value.Trim() }) -join ", ") }))
    $pwHits = @([regex]::Matches($rawShell, "(?i)Password\s*=\s*([^;`"]+)"))
    if ($pwHits.Count -eq 0) { Say "  password : NOT FOUND anywhere in this file" }
    else {
        $script:DbPw   = $pwHits[0].Groups[1].Value.Trim()
        $script:DbUser = $(if ($userHits.Count -gt 0) { $userHits[0].Groups[1].Value.Trim() } else { "ccdashboard_user" })
        $script:DbName = $(if ($dbHits.Count -gt 0)   { $dbHits[0].Groups[1].Value.Trim() }   else { "rtmviewdb" })
        $script:DbPort = $(if ($portHits2.Count -gt 0){ $portHits2[0].Groups[1].Value }       else { "5433" })
        Say ("  password : FOUND, {0} characters (value NOT printed)" -f $script:DbPw.Length)
    }
}
Say ""

Say "===== 6  liveness - the PAIR. 200 alone is not liveness. ====="
$curl = "$env:SystemRoot\System32\curl.exe"
$http200 = $false
if (-not (Test-Path $curl)) { Say "  curl.exe ABSENT - cannot measure HTTP by an external process; NOT calling it green" }
else {
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
$liveness = ($http200 -and $served)
Say ("  LIVENESS (both, or it is not liveness) : {0}" -f $liveness)
Say ""

Say "===== 7  the database names itself ====="
$psql = $null
foreach ($pgDir in @(Get-ChildItem "C:\Program Files\PostgreSQL" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $cand = Join-Path $pgDir.FullName "bin\psql.exe"
    if ((Test-Path $cand) -and ($null -eq $psql)) { $psql = $cand }
}
if ($null -eq $psql) { Say "  psql.exe NOT FOUND under C:\Program Files\PostgreSQL - this section is a GAP, not a pass" }
elseif (-not $script:DbPw) { Say "  no password recovered from the Shell config - this section is a GAP, not a pass" }
else {
    Say ("  psql   : {0}" -f $psql)
    Say ("  target : host 127.0.0.1 port {0} db {1} user {2}" -f $script:DbPort, $script:DbName, $script:DbUser)
    $sqlf = Join-Path $env:TEMP ("probe_state2_{0}.sql" -f $stamp)
    $sql = @'
SELECT 'whoami: db=' || current_database() || ' port=' || inet_server_port() || ' user=' || current_user;
SELECT 'server_version: ' || current_setting('server_version');
SELECT 'tenant | ' || "Id" || ' | ' || "Slug" || ' | ' || "Status" FROM tenants ORDER BY "Slug";
SELECT 'regclass RTSGrid_Metric      = ' || coalesce(to_regclass('public."RTSGrid_Metric"')::text,'NULL');
SELECT 'regclass NGC_BusinessUnit    = ' || coalesce(to_regclass('public."NGC_BusinessUnit"')::text,'NULL');
SELECT 'regclass RTSData_Interaction = ' || coalesce(to_regclass('public."RTSData_Interaction"')::text,'NULL');
SELECT 'NEGCTL regclass zzz_no_such_table = ' || coalesce(to_regclass('public."zzz_no_such_table"')::text,'NULL');
SELECT 'users total = ' || count(*)::text FROM identity.users;
SELECT 'user | ' || "UserName" || ' | active=' || "IsActive"::text FROM identity.users ORDER BY "UserName" LIMIT 10;
'@
    [IO.File]::WriteAllText($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $script:DbPw
    $rows = & $psql -h 127.0.0.1 -p $script:DbPort -U $script:DbUser -d $script:DbName -At -f $sqlf 2>&1
    $rc = $LASTEXITCODE
    $env:PGPASSWORD = ""
    Remove-Item $sqlf -ErrorAction SilentlyContinue
    foreach ($row in $rows) { Say ("      {0}" -f $row) }
    Say ("  psql exit code : {0}   (non-zero means the section did not measure what it claims)" -f $rc)
}
Say ""

Say "===== 8  engine log - the RTMTwilio_1 lines, VERBATIM, no interpretation ====="
$rtmLog = "C:\RTMView\RTM\Logs\RTM.log"
if (-not (Test-Path $rtmLog)) { Say ("  {0} : ABSENT" -f $rtmLog) }
else {
    Say ("  file {0}   {1} bytes   modified {2}" -f $rtmLog, (Get-Item $rtmLog).Length, (Get-Item $rtmLog).LastWriteTime)
    $hits = @(Select-String -Path $rtmLog -Pattern "RTMTwilio_1" -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -Last 10)
    Say ("  lines mentioning RTMTwilio_1 : {0}" -f $hits.Count)
    foreach ($hit in $hits) { Say ("      {0}" -f $hit.Line) }
    $posCount = @(Select-String -Path $rtmLog -Pattern "INFO" -SimpleMatch -ErrorAction SilentlyContinue).Count
    Say ("  POSITIVE control - lines containing INFO : {0}   (0 here means this search is blind)" -f $posCount)
    $errCount = @(Select-String -Path $rtmLog -Pattern "ERROR" -SimpleMatch -ErrorAction SilentlyContinue).Count
    $keyCount = @(Select-String -Path $rtmLog -Pattern "KeyNotFoundException" -SimpleMatch -ErrorAction SilentlyContinue).Count
    Say ("  lines containing ERROR : {0}    KeyNotFoundException : {1}" -f $errCount, $keyCount)
    Say "  --- last 6 lines of the log ---"
    foreach ($tailLine in (Get-Content $rtmLog -Tail 6)) { Say ("      {0}" -f $tailLine) }
}
Say ""

Say "===== SUMMARY ====="
Say ("  liveness pair          : {0}" -f $liveness)
Say ("  collector still intact : {0}   (must be ArrayList - defect (2) guard)" -f $ProbeLines.GetType().Name)
Say "  Everything above is a reading. NOTHING WAS STARTED, STOPPED OR CHANGED."
Say "===== END-OF-RUN MARKER: STATE-2-COMPLETE ====="
Fin $true
