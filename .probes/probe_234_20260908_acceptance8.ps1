#Requires -Version 5.1
<#
  PROBE 234 / acceptance-8   -   READ ONLY. Starts nothing, stops nothing, changes nothing.
  WHERE IT RUNS : server 234. Database rtmviewdb on port 5433. SELECT only.
  WHAT IT IS    : the acceptance list of the procedure, section 8, measured point by point.
                  Every expected number is printed BEFORE the measured one, so a mismatch is a
                  fact and not a judgement call. "Clean" is not "empty": a fresh install must
                  contain the seeded catalogue, and zero grids would be a DEFECT, not a clean slate.
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_acceptance8.txt"
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
function Svc($n) { return (Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $n) -ErrorAction SilentlyContinue) }
function Check($num, $what, $expected, $actual) {
    $ok = ("$expected" -eq "$actual")
    Say ("  [{0}] {1}" -f $num, $what)
    Say ("       expected {0} , measured {1}  -> {2}" -f $expected, $actual, $(if ($ok) { "PASS" } else { "FAIL" }))
    return $ok
}

Say "===== G0  machine identity ====="
$nameOk = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ("  name match {0} / uuid match {1}" -f $nameOk, ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))
if (-not ($nameOk -and ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))) { Say "  *** NOT 234"; Fin $false }
Say ("  time now : {0}" -f (Get-Date))
Say "  G0 PASS"
Say ""

$fails = 0

Say "===== 8.1 / 8.2  services ====="
foreach ($n in @("RTMViewShell","RTMService","RTMTwilio_1")) {
    $s = Svc $n
    $st = $(if ($null -eq $s) { "ABSENT" } else { $s.State })
    if (-not (Check "8.1" ("service {0}" -f $n) "Running" $st)) { $fails++ }
}
$ap = Svc "RTMApplyService"
Say ("  [8.1] RTMApplyService : {0}   - three services is the norm here; the installer does not register it" -f $(if ($null -eq $ap) { "ABSENT, as expected" } else { $ap.State }))
foreach ($n in @("RTM.Twilio","RTM")) {
    $s = Svc $n
    $st = $(if ($null -eq $s) { "ABSENT" } else { $s.State })
    if (-not (Check "8.2" ("production/legacy {0} untouched" -f $n) "Stopped" $st)) { $fails++ }
}
Say ""

Say "===== 8.3  liveness - the PAIR, by an external process ====="
$curl = "$env:SystemRoot\System32\curl.exe"
$code = "n/a"; $negc = "n/a"
if (Test-Path $curl) {
    $code = (& $curl -k -s -o NUL -w "%{http_code}" --max-time 15 "https://127.0.0.1:8444/health") 2>$null
    $negc = (& $curl -k -s -o NUL -w "%{http_code}" --max-time 15 "https://127.0.0.1:8444/zzz") 2>$null
}
if (-not (Check "8.3a" "/health by an external process" "200" $code)) { $fails++ }
if (-not (Check "8.3b" "NEGCTL /zzz (200 here would void 8.3a)" "404" $negc)) { $fails++ }
$rtmCfg = "C:\RTMView\RTM\appsettings.json"
$jr = Get-Content $rtmCfg -Raw | ConvertFrom-Json
$pipeName = "$($jr.RTM.PipeName)"
$pipes = @([IO.Directory]::GetFiles("\\.\pipe\") | ForEach-Object { $_.Substring(9) })
Say ("  [8.3c] pipes visible in total : {0}   (0 would mean this measurement is broken)" -f $pipes.Count)
if (-not (Check "8.3c" ("pipe '{0}' served" -f $pipeName) "True" ($pipes -contains $pipeName))) { $fails++ }
if (-not (Check "8.3d" "NEGCTL impossible pipe served" "False" ($pipes -contains "zzz-no-pipe"))) { $fails++ }
Say ""

Say "===== 8.4  data.sys ====="
$h = Get-Sha256Of "C:\RTMView\RTM\data.sys"
if (-not (Check "8.4" "sha256 of RTM\data.sys" "24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43" $h)) { $fails++ }
Say ""

Say "===== 8.8  orphan processes under C:\RTMView, matched BY PATH ====="
$procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "C:\RTMView\*" })
Say ("  [8.8] processes under C:\RTMView : {0}   (three of ours are expected to be running)" -f $procs.Count)
foreach ($p in $procs) { Say ("       {0,-18} pid {1,-7} {2}" -f $p.ProcessName, $p.Id, $p.Path) }
$stopped = @($procs | Where-Object { $_.HasExited })
if (-not (Check "8.8" "exited-but-held processes" "0" $stopped.Count)) { $fails++ }
Say ""

Say "===== 8.6  the four Shell keys in the DEPLOYED config ====="
$shellCfg = "C:\RTMView\Shell\appsettings.json"
$rawShell = Get-Content $shellCfg -Raw
$js = $rawShell | ConvertFrom-Json
Say ("  file {0} bytes, modified {1}" -f (Get-Item $shellCfg).Length, (Get-Item $shellCfg).LastWriteTime)
Say ("  top-level keys : {0}" -f (($js.PSObject.Properties.Name) -join ", "))
$k1 = @([regex]::Matches($rawShell, '(?i)"DefaultTenantSlug"\s*:\s*"([^"]*)"'))
Say ("  [8.6a] DefaultTenantSlug : {0}" -f $(if ($k1.Count -eq 0) { "KEY ABSENT" } else { "'" + $k1[0].Groups[1].Value + "'" }))
if ($k1.Count -eq 0) { $fails++ }
$k2 = @([regex]::Matches($rawShell, '(?i)"BaseUrl"\s*:\s*"([^"]*)"'))
Say ("  [8.6b] MetricsApply BaseUrl : {0}" -f $(if ($k2.Count -eq 0) { "KEY ABSENT" } else { "'" + $k2[0].Groups[1].Value + "'" }))
if ($k2.Count -eq 0) { $fails++ }
$k3 = @([regex]::Matches($rawShell, '(?i)"path[A-Za-z]*"\s*:\s*"([^"]*log[^"]*)"'))
Say ("  [8.6c] Serilog file path : {0}" -f $(if ($k3.Count -eq 0) { "KEY ABSENT" } else { "'" + $k3[0].Groups[1].Value + "'" }))
if ($k3.Count -eq 0) { $fails++ }
$k4 = @([regex]::Matches($rawShell, '(?i)"([A-Za-z.]*RtmRelay)"\s*:\s*"([^"]*)"'))
Say ("  [8.6d] RtmRelay level override : {0}" -f $(if ($k4.Count -eq 0) { "KEY ABSENT" } else { "'" + $k4[0].Groups[1].Value + "' = '" + $k4[0].Groups[2].Value + "'" }))
if ($k4.Count -eq 0) { $fails++ }
Say ("  NEGCTL a key that cannot be there : {0}   (must be 0)" -f @([regex]::Matches($rawShell, '"ZzzNoSuchKey"')).Count)
Say "  (an absent key here is the installer defect No.3 repeating - it is reported, not repaired)"
Say ""

Say "===== 8.5 / 8.10 / 8.11  the database, counted ====="
$cs = "$($js.ConnectionStrings.Default)"
$pw = ""; $usr = "ccdashboard_user"; $db = "rtmviewdb"; $port = "5433"
$m = [regex]::Match($cs, "(?i)Password\s*=\s*([^;]+)"); if ($m.Success) { $pw = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Username\s*=\s*([^;]+)"); if ($m.Success) { $usr = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Database\s*=\s*([^;]+)"); if ($m.Success) { $db  = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Port\s*=\s*(\d+)");       if ($m.Success) { $port = $m.Groups[1].Value }
$psql = $null
foreach ($pg in @(Get-ChildItem "C:\Program Files\PostgreSQL" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $c = Join-Path $pg.FullName "bin\psql.exe"; if ((Test-Path $c) -and ($null -eq $psql)) { $psql = $c }
}
if ($null -eq $psql -or -not $pw) { Say "  psql or password unavailable - this whole section is a GAP, not a pass"; $fails++ }
else {
    Say "  expected, from the seed measured in the object store on 2026-09-06:"
    Say "      RTSGrid_Metric 203 | MetricTranslation 402 | Grid 1 | Row 1 | Column 5 | Cell 5"
    Say "      RTSUserGrid_ColumnsSet 1 | _Grid 1 | _Column 5 | NGC_Site 3"
    Say "      Zero grids would be a DEFECT, not an empty database."
    $sqlf = Join-Path $env:TEMP ("acc_{0}.sql" -f $stamp)
    $sql = @'
SELECT 'whoami: db=' || current_database() || ' port=' || inet_server_port() || ' user=' || current_user;
SELECT 'server_version: ' || current_setting('server_version');
SELECT 'tenant | ' || "Id" || ' | ' || "Slug" FROM tenants ORDER BY "Slug";
SELECT 'count RTSGrid_Metric = ' || count(*)::text FROM public."RTSGrid_Metric";
SELECT 'count RTSGrid_MetricTranslation = ' || count(*)::text FROM public."RTSGrid_MetricTranslation";
SELECT 'count RTSGrid_Grid = ' || count(*)::text FROM public."RTSGrid_Grid";
SELECT 'count RTSGrid_Row = ' || count(*)::text FROM public."RTSGrid_Row";
SELECT 'count RTSGrid_Column = ' || count(*)::text FROM public."RTSGrid_Column";
SELECT 'count RTSGrid_Cell = ' || count(*)::text FROM public."RTSGrid_Cell";
SELECT 'count RTSUserGrid_ColumnsSet = ' || count(*)::text FROM public."RTSUserGrid_ColumnsSet";
SELECT 'count RTSUserGrid_Grid = ' || count(*)::text FROM public."RTSUserGrid_Grid";
SELECT 'count RTSUserGrid_Column = ' || count(*)::text FROM public."RTSUserGrid_Column";
SELECT 'count NGC_Site = ' || count(*)::text FROM public."NGC_Site";
SELECT 'NGC_Site tenant | ' || "SiteId" || ' | ' || "TenantId"::text FROM public."NGC_Site" ORDER BY "SiteId";
SELECT 'live NGC_BusinessUnit = ' || count(*)::text FROM public."NGC_BusinessUnit";
SELECT 'live NGC_Queues = ' || count(*)::text FROM public."NGC_Queues";
SELECT 'live RTSData_Interaction = ' || count(*)::text FROM public."RTSData_Interaction";
SELECT 'live RTSData_UserStatus = ' || count(*)::text FROM public."RTSData_UserStatus";
SELECT 'metric rows mentioning QueueNumberOfLoggedAgents = ' || count(*)::text
  FROM public."RTSGrid_Metric" WHERE to_jsonb("RTSGrid_Metric")::text ILIKE '%QueueNumberOfLoggedAgents%';
SELECT 'NEGCTL rows mentioning ZzzNoSuchMetric = ' || count(*)::text
  FROM public."RTSGrid_Metric" WHERE to_jsonb("RTSGrid_Metric")::text ILIKE '%ZzzNoSuchMetric%';
SELECT 'row text: ' || to_jsonb("RTSGrid_Metric")::text
  FROM public."RTSGrid_Metric" WHERE to_jsonb("RTSGrid_Metric")::text ILIKE '%QueueNumberOfLoggedAgents%';
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
    foreach ($pair in @(@("RTSGrid_Metric",203), @("RTSGrid_MetricTranslation",402), @("RTSGrid_Grid",1),
                        @("RTSGrid_Row",1), @("RTSGrid_Column",5), @("RTSGrid_Cell",5),
                        @("RTSUserGrid_ColumnsSet",1), @("RTSUserGrid_Grid",1), @("RTSUserGrid_Column",5),
                        @("NGC_Site",3))) {
        $line = @($rows | Where-Object { "$_" -like ("count " + $pair[0] + " = *") })
        if ($line.Count -ne 1) { Say ("  [8.10] {0} : no single count line found -> FAIL" -f $pair[0]); $fails++; continue }
        $val = ("$($line[0])" -split "= ")[1]
        if (-not (Check "8.10" ("seeded rows in {0}" -f $pair[0]) $pair[1] $val)) { $fails++ }
    }
}
Say ""

Say "===== 8.11  the engine log must carry no KeyNotFoundException for the removed metric ====="
$rtmLog = "C:\RTMView\RTM\Logs\RTM.log"
if (-not (Test-Path $rtmLog)) { Say "  engine log ABSENT -> FAIL"; $fails++ }
else {
    $kn = @(Select-String -Path $rtmLog -Pattern "KeyNotFoundException" -SimpleMatch -ErrorAction SilentlyContinue).Count
    $qn = @(Select-String -Path $rtmLog -Pattern "QueueNumberOfLoggedAgents" -SimpleMatch -ErrorAction SilentlyContinue).Count
    $pos = @(Select-String -Path $rtmLog -Pattern "INFO" -SimpleMatch -ErrorAction SilentlyContinue).Count
    Say ("  POSITIVE control - lines with INFO : {0}   (0 would mean this search is blind)" -f $pos)
    if (-not (Check "8.11a" "KeyNotFoundException in the engine log" "0" $kn)) { $fails++ }
    if (-not (Check "8.11b" "mentions of QueueNumberOfLoggedAgents" "0" $qn)) { $fails++ }
    $er = @(Select-String -Path $rtmLog -Pattern "ERROR" -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -Last 5)
    Say ("  last ERROR lines in the engine log : {0}" -f $er.Count)
    foreach ($e in $er) { Say ("       {0}" -f $e.Line) }
}
Say ""

Say "===== the live wire, for the record ====="
$adLog = "C:\Logs\RTM.Twilio\log.txt"
if (Test-Path $adLog) {
    $fi = Get-Item $adLog
    Say ("  adapter log {0} bytes, modified {1}" -f $fi.Length, $fi.LastWriteTime)
    $ae = @(Select-String -Path $adLog -Pattern "ERROR" -SimpleMatch -ErrorAction SilentlyContinue).Count
    Say ("  ERROR lines in the adapter log : {0}" -f $ae)
} else { Say "  adapter log ABSENT" }
Say ""

Say "===== SUMMARY ====="
Say ("  failures : {0}" -f $fails)
Say "  Points 8.7 (login) and 8.9 (the six installer checks with their negative halves) are NOT"
Say "  measured here: the first is the operator's action, already done; the second runs on the"
Say "  build machine against the OLD installer. This probe does not claim them."
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "  NOTHING WAS STARTED, STOPPED OR CHANGED."
Say "===== END-OF-RUN MARKER: ACCEPTANCE8-COMPLETE ====="
Fin ($fails -eq 0)
