#Requires -Version 5.1
<#
  PROBE 234 / post-install   -   READ ONLY. Starts nothing, stops nothing, changes nothing.
  WHERE IT RUNS : server 234. Database rtmviewdb on port 5433. SELECT only.
  QUESTION      : after the clean install - is the tenant Id finally the canonical one, did the
                  adapter survive, what does data.sys look like now, and is the pair alive.

  Note on the adapter: it is currently Stopped. This box does NOT start it. Measuring first is
  deliberate - a restart destroys the state that is measurable right now, and the log of an engine
  that came up without its adapter is exactly what we want to read before it is overwritten.
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_post-install.txt"
$ProbeLines = New-Object System.Collections.ArrayList
function Say($text) { [void]$ProbeLines.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$ProbeLines.Add("")
    [void]$ProbeLines.Add($(if ($pass) { "VERDICT: PASS" } else { "VERDICT: FAIL" }))
    [IO.File]::WriteAllLines($outf, $ProbeLines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($path) { if (Test-Path $path) { (Get-FileHash $path -Algorithm SHA256).Hash } else { "ABSENT" } }

Say "===== G0  machine identity ====="
$nameOk = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  name match {0} / uuid match {1}" -f $nameOk, $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say "  *** NOT server 234 - refusing"; Fin $false }
Say "  G0 PASS"
Say ""

Say "===== G1  the instrument checks itself ====="
$cmd = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ("  Get-Sha256Of resolves to : {0}   (must be Function)" -f $cmd.CommandType)
if ("$($cmd.CommandType)" -ne "Function") { Say "  *** shadowed helper"; Fin $false }
Say ("  POSCTL hash of this file : {0}" -f (Get-Sha256Of $MyInvocation.MyCommand.Path))
Say ("  NEGCTL hash of a missing path : {0}   (must be ABSENT)" -f (Get-Sha256Of "C:\zzz-no-such.bin"))
Say ("  host {0} / PS {1}" -f $env:COMPUTERNAME, $PSVersionTable.PSVersion)
Say "  G1 PASS"
Say ""

$fails = 0

Say "===== 1  data.sys as it stands now ====="
$live = "C:\RTMView\RTM\data.sys"
if (-not (Test-Path $live)) { Say "  ABSENT -> FAIL"; $fails++ }
else {
    $h = Get-Sha256Of $live
    Say ("  sha256 {0}" -f $h)
    Say ("  size {0} bytes, modified {1}" -f (Get-Item $live).Length, (Get-Item $live).LastWriteTime)
    $isMachine = ($h -eq "24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43")
    Say ("  equals the machine file 24F0BFAC...DE43, expected True : {0}" -f $isMachine)
    Say ("  equals the package file 7745C5CA...476D, expected False : {0}" -f ($h -eq "7745C5CA4DF0DD4AE24584343A16A38180CB3E930D1630CD88766C66C44F476D"))
    if (-not $isMachine) { $fails++ }
    Say "  (the installer reported 'Preserved: data.sys (package version ignored)' - this is that claim, measured)"
}
Say ""

Say "===== 2  services and the adapter's own directory ====="
foreach ($s in @("RTMViewShell","RTMService","RTMTwilio_1","RTM.Twilio","RTM","Garnet")) {
    $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $s) -ErrorAction SilentlyContinue
    if ($null -eq $svc) { Say ("  {0,-14} ABSENT" -f $s) }
    else { Say ("  {0,-14} {1,-9} {2,-10} {3}" -f $svc.Name, $svc.State, $svc.StartMode, $svc.PathName) }
}
$twDir = "C:\RTMView\RTM.Twilio"
$twCount = @(Get-ChildItem $twDir -Recurse -File -ErrorAction SilentlyContinue).Count
Say ("  {0} : exists {1} , files {2}   (355 before the install)" -f $twDir, (Test-Path $twDir), $twCount)
$twCfg = Join-Path $twDir "appsettings.json"
Say ("  adapter appsettings.json present : {0}" -f (Test-Path $twCfg))
$rtmCfg = "C:\RTMView\RTM\appsettings.json"
$jr = Get-Content $rtmCfg -Raw | ConvertFrom-Json
Say ("  RTM:AdaptorServiceName read from disk : '{0}'   (must be RTMTwilio_1)" -f $jr.RTM.AdaptorServiceName)
Say ("  RTM:PipeName read from disk           : '{0}'" -f $jr.RTM.PipeName)
Say ("  RTM:TenantId read from disk           : '{0}'" -f $jr.RTM.TenantId)
if ("$($jr.RTM.AdaptorServiceName)" -ne "RTMTwilio_1") { $fails++ }
Say ""

Say "===== 3  the database names itself, and the tenant Id is the whole point ====="
$shellCfg = "C:\RTMView\Shell\appsettings.json"
$rawShell = Get-Content $shellCfg -Raw
$js = $rawShell | ConvertFrom-Json
$cs = "$($js.ConnectionStrings.Default)"
$pw = ""; $usr = "ccdashboard_user"; $db = "rtmviewdb"; $port = "5433"
$m = [regex]::Match($cs, "(?i)Password\s*=\s*([^;]+)"); if ($m.Success) { $pw = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Username\s*=\s*([^;]+)"); if ($m.Success) { $usr = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Database\s*=\s*([^;]+)"); if ($m.Success) { $db = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Port\s*=\s*(\d+)");       if ($m.Success) { $port = $m.Groups[1].Value }
Say ("  connecting as {0} to {1} on port {2}, password {3} characters" -f $usr, $db, $port, $pw.Length)
$psql = $null
foreach ($pg in @(Get-ChildItem "C:\Program Files\PostgreSQL" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $c = Join-Path $pg.FullName "bin\psql.exe"; if ((Test-Path $c) -and ($null -eq $psql)) { $psql = $c }
}
if ($null -eq $psql -or -not $pw) { Say "  psql or password unavailable - this section is a GAP, not a pass"; $fails++ }
else {
    $sqlf = Join-Path $env:TEMP ("post_{0}.sql" -f $stamp)
    $sql = @'
SELECT 'whoami: db=' || current_database() || ' port=' || inet_server_port() || ' user=' || current_user;
SELECT 'server_version: ' || current_setting('server_version');
SELECT 'tenant | ' || "Id" || ' | ' || "Slug" || ' | ' || "Status" FROM tenants ORDER BY "Slug";
SELECT 'tenants total = ' || count(*)::text FROM tenants;
SELECT 'users | ' || "UserName" || ' | active=' || "IsActive"::text FROM identity.users ORDER BY "UserName";
SELECT 'regclass NGC_BusinessUnit = ' || coalesce(to_regclass('public."NGC_BusinessUnit"')::text,'NULL');
SELECT 'regclass RTSData_Interaction = ' || coalesce(to_regclass('public."RTSData_Interaction"')::text,'NULL');
SELECT 'NEGCTL regclass zzz_no_such = ' || coalesce(to_regclass('public."zzz_no_such"')::text,'NULL');
SELECT 'NGC_BusinessUnit rows = ' || count(*)::text FROM public."NGC_BusinessUnit";
'@
    [IO.File]::WriteAllText($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $pw
    $rows = & $psql -h 127.0.0.1 -p $port -U $usr -d $db -At -f $sqlf 2>&1
    $rc = $LASTEXITCODE
    $env:PGPASSWORD = ""
    Remove-Item $sqlf -ErrorAction SilentlyContinue
    foreach ($r in $rows) { Say ("      {0}" -f $r) }
    Say ("  psql exit code : {0}" -f $rc)
    if ($rc -ne 0) { $fails++ }
    $canon = @($rows | Where-Object { "$_" -match "019e03e9-60dd-72da-bd01-648ffdb2b433" }).Count
    $random = @($rows | Where-Object { "$_" -match "01a07e07" }).Count
    Say ("  canonical Id 019e03e9 present in tenants, expected 1 : {0}" -f $canon)
    Say ("  the old random Id 01a07e07 present, expected 0        : {0}" -f $random)
    if ($canon -lt 1) { Say "  *** the seed did not land - this was the entire purpose of the pass"; $fails++ }
    if ($random -gt 0) { $fails++ }
}
Say ""

Say "===== 4  liveness - the PAIR, measured by an external process ====="
$curl = "$env:SystemRoot\System32\curl.exe"
$http200 = $false
if (-not (Test-Path $curl)) { Say "  curl.exe ABSENT - not calling it green" }
else {
    $code = (& $curl -k -s -o NUL -w "%{http_code}" --max-time 15 "https://127.0.0.1:8444/health") 2>$null
    $body = (& $curl -k -s --max-time 15 "https://127.0.0.1:8444/health") 2>$null
    $negc = (& $curl -k -s -o NUL -w "%{http_code}" --max-time 15 "https://127.0.0.1:8444/zzz-no-such") 2>$null
    Say ("  https 8444 /health -> {0}   body '{1}'" -f $code, $body)
    Say ("  NEGCTL /zzz        -> {0}   (200 here would void the line above)" -f $negc)
    $http200 = (("$code" -eq "200") -and ("$negc" -ne "200"))
}
$pipeName = "$($jr.RTM.PipeName)"
$pipes = @([IO.Directory]::GetFiles("\\.\pipe\") | ForEach-Object { $_.Substring(9) })
Say ("  pipes visible in total : {0}   (0 means the measurement is broken)" -f $pipes.Count)
$served = ($pipes -contains $pipeName)
Say ("  pipe '{0}' served : {1}" -f $pipeName, $served)
Say ("  NEGCTL impossible pipe : {0}   (must be False)" -f ($pipes -contains "zzz-no-such-pipe"))
Say ("  LIVENESS (both) : {0}" -f ($http200 -and $served))
if (-not ($http200 -and $served)) { $fails++ }
Say ""

Say "===== 5  the engine log, verbatim - did it find the adapter this time ====="
$rtmLog = "C:\RTMView\RTM\Logs\RTM.log"
if (-not (Test-Path $rtmLog)) { Say ("  {0} : ABSENT   <- the engine has written no log since the install" -f $rtmLog) }
else {
    Say ("  file {0} bytes, modified {1}" -f (Get-Item $rtmLog).Length, (Get-Item $rtmLog).LastWriteTime)
    $hits = @(Select-String -Path $rtmLog -Pattern "RTMTwilio_1" -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -Last 10)
    Say ("  lines mentioning RTMTwilio_1 : {0}" -f $hits.Count)
    foreach ($h in $hits) { Say ("      {0}" -f $h.Line) }
    $pos = @(Select-String -Path $rtmLog -Pattern "INFO" -SimpleMatch -ErrorAction SilentlyContinue).Count
    Say ("  POSITIVE control - lines with INFO : {0}   (0 means this search is blind)" -f $pos)
    $lic = @(Select-String -Path $rtmLog -Pattern "License" -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -Last 3)
    Say ("  lines mentioning License : {0}" -f $lic.Count)
    foreach ($h in $lic) { Say ("      {0}" -f $h.Line) }
    Say "  --- last 8 lines ---"
    foreach ($t in (Get-Content $rtmLog -Tail 8)) { Say ("      {0}" -f $t) }
}
Say ""

Say "===== SUMMARY ====="
Say ("  failures : {0}" -f $fails)
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "  NOTHING WAS STARTED, STOPPED OR CHANGED. The adapter is still Stopped on purpose."
Say "===== END-OF-RUN MARKER: POST-INSTALL-COMPLETE ====="
Fin ($fails -eq 0)
