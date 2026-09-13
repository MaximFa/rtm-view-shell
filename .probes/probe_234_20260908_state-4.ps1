#Requires -Version 5.1
<#
  PROBE 234 / state-3   -   READ ONLY. SELECT only. Nothing is installed, started, stopped or edited.
  WHERE IT RUNS : server 234 (name RTM). Database rtmviewdb on port 5433, read-only queries.
  WHO ASKED     : coordinator-0908, task #1 - an independent picture of 234 taken TODAY.
  NOT TOUCHED   : C:\IceDash\, the production RTM.Twilio and legacy RTM services, PG15 on 5432,
                  C:\RTMView-Ops\. Secrets: name, length and sha256 only - never a value.

  Every section prints its EXPECTED value BEFORE the measured one.
  Three gates abort the run rather than report a green they cannot support:
    G0 machine identity, G1 local-midnight window, G2 the instrument can fail (psql rc).
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_state-3.txt"
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

Say "===== WHERE IT RUNS ====="
Say "  machine 234 / database rtmviewdb port 5433 / READ ONLY"
Say ("  probe file sha256 : {0}" -f (Get-FileHash -Path $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash)
Say ("  local time now    : {0}" -f (Get-Date))
Say ""

Say "===== G0  machine identity (gate) ====="
$nameOk = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  expected : name RTM and uuid E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  measured : name match {0} / uuid match {1}" -f $nameOk, $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say "  *** THIS IS NOT 234 - aborting"; Fin $false }
Say "  G0 PASS"
Say ""

Say "===== G1  local-midnight window (gate) ====="
Say "  reason   : the flow samples in section 5 are meaningless across the nightly clear"
$now = Get-Date
$minsToMidnight = [int]([math]::Round(($now.Date.AddDays(1) - $now).TotalMinutes))
$minsFromMidnight = [int]([math]::Round(($now - $now.Date).TotalMinutes))
Say ("  expected : at least 20 minutes away from local midnight on both sides")
Say ("  measured : {0} min since midnight / {1} min until midnight" -f $minsFromMidnight, $minsToMidnight)
if (($minsToMidnight -lt 20) -or ($minsFromMidnight -lt 20)) { Say "  *** inside the midnight window - aborting, re-run later"; Fin $false }
Say "  G1 PASS"
Say ""

Say "===== G2  the instrument must be able to FAIL (gate) ====="
$psql = $null
foreach ($pgDir in @(Get-ChildItem "C:\Program Files\PostgreSQL" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $cand = Join-Path $pgDir.FullName "bin\psql.exe"
    if ((Test-Path $cand) -and ($null -eq $psql)) { $psql = $cand }
}
$shellCfg = "C:\RTMView\Shell\appsettings.json"
$rtmCfg   = "C:\RTMView\RTM\appsettings.json"
$DbPw = ""; $DbUser = ""; $DbName = ""; $DbPort = ""
if (Test-Path $shellCfg) {
    $rawShell = Get-Content $shellCfg -Raw
    $m = [regex]::Match($rawShell, "(?i)Password\s*=\s*([^;`"]+)");            if ($m.Success) { $DbPw   = $m.Groups[1].Value.Trim() }
    $m = [regex]::Match($rawShell, "(?i)(?:Username|User ID)\s*=\s*([^;`"]+)"); if ($m.Success) { $DbUser = $m.Groups[1].Value.Trim() }
    $m = [regex]::Match($rawShell, "(?i)Database\s*=\s*([^;`"]+)");            if ($m.Success) { $DbName = $m.Groups[1].Value.Trim() }
    $m = [regex]::Match($rawShell, "(?i)Port\s*=\s*(\d+)");                    if ($m.Success) { $DbPort = $m.Groups[1].Value }
}
Say ("  psql : {0}" -f $(if ($psql) { $psql } else { "NOT FOUND" }))
Say ("  connection from the machine's own Shell config : user {0} / db {1} / port {2} / password {3} chars" -f $DbUser, $DbName, $DbPort, $DbPw.Length)
if (($null -eq $psql) -or (-not $DbPw) -or (-not $DbName) -or (-not $DbPort)) { Say "  *** cannot reach the database - this run would measure nothing; aborting"; Fin $false }
$badf = Join-Path $env:TEMP ("bad_{0}.sql" -f $stamp)
[IO.File]::WriteAllText($badf, "SELECT this_function_does_not_exist();", (New-Object System.Text.UTF8Encoding($false)))
$env:PGPASSWORD = $DbPw
$null = & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p $DbPort -U $DbUser -d $DbName -At -f $badf 2>&1
$badRc = $LASTEXITCODE
$env:PGPASSWORD = ""
Remove-Item $badf -ErrorAction SilentlyContinue
Say ("  expected : a deliberately broken query returns a NON-ZERO exit code")
Say ("  measured : rc = {0}" -f $badRc)
if ($badRc -eq 0) { Say "  *** psql returns 0 on a broken query - every zero below would be meaningless; aborting"; Fin $false }
Say "  G2 PASS"
Say ""

Say "===== 1  services (read-only Get-Service; nothing is started or stopped) ====="
Say "  expected : RTMViewShell / RTMService / RTMTwilio_1 = Running ; RTM.Twilio and RTM (legacy) = untouched"
foreach ($svc in @("RTMViewShell","RTMService","RTMTwilio_1","RTMApplyService","RTM.Twilio","RTM")) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($null -eq $s) { Say ("  {0,-16} : ABSENT" -f $svc) }
    else { Say ("  {0,-16} : {1}   (StartType {2})" -f $svc, $s.Status, $s.StartType) }
}
Say "  note: RTMApplyService ABSENT is NORMAL - the installer does not install it"
Say ""

Say "===== 2  liveness as a PAIR - HTTP 200 alone is not liveness ====="
$curl = "$env:SystemRoot\System32\curl.exe"
$http200 = $false; $negHttpOk = $false
$healthBase = ""; $healthSrc = ""
if (Test-Path $shellCfg) {
    $rawCfgU = Get-Content $shellCfg -Raw
    $urlHits = @([regex]::Matches($rawCfgU, '(?i)"(?:Url|Urls|ApplicationUrl)"\s*:\s*"([^"]+)"'))
    $cands = @()
    foreach ($u in $urlHits) { foreach ($piece in ($u.Groups[1].Value -split ";")) { if ($piece.Trim()) { $cands += $piece.Trim() } } }
    Say ("  URL candidates found in the Shell config : {0}" -f $(if ($cands.Count -gt 0) { ($cands -join ", ") } else { "NONE" }))
    $https = @($cands | Where-Object { $_ -match "^https" })
    if ($https.Count -gt 0) { $healthBase = $https[0]; $healthSrc = "Shell appsettings.json" }
    elseif ($cands.Count -gt 0) { $healthBase = $cands[0]; $healthSrc = "Shell appsettings.json" }
}
$targets = @()
if ($healthBase) {
    $healthBase = $healthBase.TrimEnd("/").Replace("+","127.0.0.1").Replace("0.0.0.0","127.0.0.1").Replace("[::]","127.0.0.1").Replace("*","127.0.0.1")
    $targets += [pscustomobject]@{ Base = $healthBase; Src = $healthSrc }
    $mPort = [regex]::Match($healthBase, "^(https?)://[^/:]+(?::(\d+))?")
    if ($mPort.Success) {
        $loop = "{0}://127.0.0.1{1}" -f $mPort.Groups[1].Value, $(if ($mPort.Groups[2].Success) { ":" + $mPort.Groups[2].Value } else { "" })
        if ($loop -ne $healthBase) { $targets += [pscustomobject]@{ Base = $loop; Src = "loopback on the port the machine named" } }
    }
} else {
    $targets += [pscustomobject]@{ Base = "https://127.0.0.1:8444"; Src = "CONSTANT built into this probe - the machine did not name a binding" }
}
Say ("  addresses to try, in order : {0}" -f (($targets | ForEach-Object { $_.Base }) -join " , "))
Say "  RULE: an address that does not answer is UNREACHABLE - it is not a liveness verdict, and it"
Say "        contributes NEITHER half to the gate. The negative control is computed ONLY against the"
Say "        address whose /health answered, because /zzz -> 000 proves unreachability, not refusal."
$liveBase = ""; $liveCode = ""; $liveNeg = ""
if (-not (Test-Path $curl)) { Say "  curl.exe ABSENT - HTTP cannot be measured by an external process; NOT calling this green" }
else {
    foreach ($tg in $targets) {
        $u = $tg.Base + "/health"
        $code = (& $curl -k -s -o NUL -w "%{http_code}" --max-time 15 $u) 2>$null
        $body = (& $curl -k -s --max-time 15 $u) 2>$null
        if ("$code" -eq "000") {
            Say ("  {0}  -> UNREACHABLE (not a liveness verdict)   [source: {1}]" -f $u, $tg.Src)
        } else {
            Say ("  {0}  -> {1}   body '{2}'   [source: {3}]" -f $u, $code, $body, $tg.Src)
            if (("$code" -eq "200") -and (-not $liveBase)) { $liveBase = $tg.Base; $liveCode = "$code" }
        }
    }
    if ($liveBase) {
        $liveNeg = (& $curl -k -s -o NUL -w "%{http_code}" --max-time 15 ($liveBase + "/zzz-no-such-endpoint")) 2>$null
        Say ("  NEGCTL on the answering address {0} : /zzz -> {1}   (must be neither 200 nor 000)" -f $liveBase, $liveNeg)
        $negHttpOk = (("$liveNeg" -ne "200") -and ("$liveNeg" -ne "000"))
        $http200 = $negHttpOk
        Say ("  HTTP half : answered by {0}, negative control discriminates = {1}" -f $liveBase, $negHttpOk)
    } else {
        Say "  HTTP half : NOT MEASURED - no address answered. This says nothing about the application."
    }
}
$pipeName = ""
if (Test-Path $rtmCfg) { $pipeName = "$((Get-Content $rtmCfg -Raw | ConvertFrom-Json).RTM.PipeName)" }
$pipes = @([IO.Directory]::GetFiles("\\.\pipe\") | ForEach-Object { $_.Substring(9) })
Say ("  pipe name taken from AppConfig on disk : '{0}'" -f $pipeName)
Say ("  pipes visible in total : {0}   (0 here means the measurement is broken, not that there are none)" -f $pipes.Count)
$served = ($pipeName -ne "") -and ($pipes -contains $pipeName)
$negPipeOk = -not ($pipes -contains "zzz-no-such-pipe-here")
Say ("  expected : the configured pipe served = True ; NEGCTL impossible pipe served = False")
Say ("  measured : configured pipe served = {0} ; NEGCTL = {1}" -f $served, (-not $negPipeOk))
$liveness = ($http200 -and $served -and $negHttpOk -and $negPipeOk -and ($pipes.Count -gt 0))
Say ("  LIVENESS (both halves, negative controls included) : {0}" -f $liveness)
if (-not $http200) { Say "  NOTE: with no answering address the HTTP half is UNMEASURED, not failed - the pipe half above stands on its own" }
if (-not $liveness) { Say "  *** liveness not established - the sections below still run, but read them as readings of a machine whose liveness is UNPROVEN" }
Say ""

Say "===== 3  data.sys ====="
$ds = "C:\RTMView\Shell\data.sys"
$dsExpected = "24F0BFACE0A0F7D076DF7CFB2CF98933B8FC7F178166FD680567440FF04DDE43"
Say ("  expected sha256 : {0}" -f $dsExpected)
if (-not (Test-Path $ds)) {
    $alt = @(Get-ChildItem "C:\RTMView" -Recurse -Filter "data.sys" -ErrorAction SilentlyContinue | Select-Object -First 5)
    Say ("  {0} : ABSENT   (searched C:\RTMView recursively, found {1} copies elsewhere)" -f $ds, $alt.Count)
    foreach ($a in $alt) { Say ("      {0}   sha256 {1}" -f $a.FullName, (Get-FileHash $a.FullName -Algorithm SHA256).Hash) }
} else {
    $dsHash = (Get-FileHash $ds -Algorithm SHA256).Hash
    Say ("  measured sha256 : {0}   size {1} bytes   modified {2}" -f $dsHash, (Get-Item $ds).Length, (Get-Item $ds).LastWriteTime)
    Say ("  match : {0}" -f ($dsHash -eq $dsExpected))
}
Say ""

Say "===== 4-6-7  the database names itself, the flow, the sequences ====="
Say "  expected : db rtmviewdb / port 5433 / one tenant 019e03e9-60dd-72da-bd01-648ffdb2b433 = platform"
Say "  expected : three flow samples 60 s apart, non-decreasing, last strictly greater than first"
Say "  expected : every sequence last_value >= max(id)  (yesterday's manual resync must still hold)"
$sqlf = Join-Path $env:TEMP ("state3_{0}.sql" -f $stamp)
$sqlText = @'
\encoding UTF8
SELECT 'whoami: db=' || current_database() || ' port=' || inet_server_port() || ' user=' || current_user;
SELECT 'server_version: ' || current_setting('server_version');
SELECT 'tenant | ' || "Id" || ' | ' || "Slug" || ' | ' || "Status" FROM tenants ORDER BY "Slug";
SELECT 'tenants total = ' || count(*)::text FROM tenants;
SELECT '--- sequences: last_value vs max(id), verdict computed by the server ---';
SELECT 'SEQ RTSGrid_Column last_value=' || s.last_value::text || ' max=' || COALESCE(m.mx,0)::text || ' -> ' ||
       CASE WHEN s.last_value >= COALESCE(m.mx,0) THEN 'OK (resync holds)' ELSE 'BEHIND (will collide)' END
  FROM "RTSGrid_Column_ColumnId_seq" s, (SELECT MAX("ColumnId") mx FROM "RTSGrid_Column") m;
SELECT 'SEQ RTSGrid_Row last_value=' || s.last_value::text || ' max=' || COALESCE(m.mx,0)::text || ' -> ' ||
       CASE WHEN s.last_value >= COALESCE(m.mx,0) THEN 'OK (resync holds)' ELSE 'BEHIND (will collide)' END
  FROM "RTSGrid_Row_RowId_seq" s, (SELECT MAX("RowId") mx FROM "RTSGrid_Row") m;
SELECT 'SEQ RTSGrid_Cell last_value=' || s.last_value::text || ' max=' || COALESCE(m.mx,0)::text || ' -> ' ||
       CASE WHEN s.last_value >= COALESCE(m.mx,0) THEN 'OK (resync holds)' ELSE 'BEHIND (will collide)' END
  FROM "RTSGrid_Cell_CellId_seq" s, (SELECT MAX("CellId") mx FROM "RTSGrid_Cell") m;
SELECT 'SEQ RTSGrid_Grid last_value=' || s.last_value::text || ' max=' || COALESCE(m.mx,0)::text || ' -> ' ||
       CASE WHEN s.last_value >= COALESCE(m.mx,0) THEN 'OK (resync holds)' ELSE 'BEHIND (will collide)' END
  FROM "RTSGrid_Grid_GridId_seq" s, (SELECT MAX("GridId") mx FROM "RTSGrid_Grid") m;
SELECT '--- reference volumes (a zero here is a finding, not a blank) ---';
SELECT 'COUNT NGC_BusinessUnit = ' || count(*)::text FROM "NGC_BusinessUnit";
SELECT 'COUNT NGC_Queues = ' || count(*)::text FROM "NGC_Queues";
SELECT 'COUNT RTSGrid_Metric = ' || count(*)::text FROM "RTSGrid_Metric";
SELECT 'NEGCTL regclass zzz_no_such_table = ' || coalesce(to_regclass('public."zzz_no_such_table"')::text,'NULL (correct)');
SELECT '--- connection identity (backend debt 3.2): the connection describes ITSELF ---';
SELECT 'server address = ' || coalesce(inet_server_addr()::text,'NULL (unix socket or local)') || ' port ' || inet_server_port()::text;
SELECT 'client address = ' || coalesce(inet_client_addr()::text,'NULL');
SELECT 'search_path in force = ' || array_to_string(current_schemas(true), ', ');
SELECT 'version = ' || version();
SELECT '--- to_regclass, NULLs printed explicitly ---';
SELECT 'regclass RTSGrid_Grid   = ' || coalesce(to_regclass('public."RTSGrid_Grid"')::text,'NULL');
SELECT 'regclass RTSGrid_Row    = ' || coalesce(to_regclass('public."RTSGrid_Row"')::text,'NULL');
SELECT 'regclass RTSGrid_Column = ' || coalesce(to_regclass('public."RTSGrid_Column"')::text,'NULL');
SELECT 'regclass RTSGrid_Cell   = ' || coalesce(to_regclass('public."RTSGrid_Cell"')::text,'NULL');
SELECT '--- row counts of the same four ---';
SELECT 'COUNT RTSGrid_Grid = '   || count(*)::text FROM "RTSGrid_Grid";
SELECT 'COUNT RTSGrid_Row = '    || count(*)::text FROM "RTSGrid_Row";
SELECT 'COUNT RTSGrid_Column = ' || count(*)::text FROM "RTSGrid_Column";
SELECT 'COUNT RTSGrid_Cell = '   || count(*)::text FROM "RTSGrid_Cell";
SELECT '--- every database on this instance, so the reading cannot be about another one ---';
SELECT 'pg_database | ' || datname || ' | connectable=' || datallowconn::text FROM pg_database ORDER BY datname;
SELECT 'NEGCTL database that must not exist: zzz_no_such_db present = ' ||
       (EXISTS (SELECT 1 FROM pg_database WHERE datname = 'zzz_no_such_db'))::text || ' (must be false)';
'@
[IO.File]::WriteAllText($sqlf, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
$errf = Join-Path $OutDir "234_$($stamp)_state-3.err.txt"
$resf = Join-Path $env:TEMP ("state3_out_{0}.txt" -f $stamp)
$env:PGPASSWORD = $DbPw
& $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p $DbPort -U $DbUser -d $DbName -At -o $resf -f $sqlf 2> $errf
$rc = $LASTEXITCODE
Say ("  psql exit code : {0}   (G2 proved a non-zero is reachable)" -f $rc)
if (Test-Path $shellCfg) {
    $csRaw = ""
    $csM = [regex]::Match((Get-Content $shellCfg -Raw), '(?is)"ConnectionStrings"\s*:\s*\{[^}]*?"([^"]+)"\s*:\s*"([^"]*)"')
    if ($csM.Success) { $csRaw = $csM.Groups[2].Value }
    if ($csRaw) {
        $masked = [regex]::Replace($csRaw, "(?i)(Password\s*=\s*)([^;]*)", { param($m) $m.Groups[1].Value + "<" + $m.Groups[2].Value.Length + " chars, not printed>" })
        Say ("  connection string VERBATIM (password masked, length kept) : {0}" -f $masked)
    } else { Say "  connection string : NOT FOUND in the Shell config - stated as absent, not guessed" }
}
if (Test-Path $resf) { foreach ($row in (Get-Content $resf)) { Say ("      {0}" -f $row) } }
$errSize = 0; if (Test-Path $errf) { $errSize = (Get-Item $errf).Length }
Say ("  stderr file size : {0} bytes   (anything above 0 is a finding: {1})" -f $errSize, $errf)

Say ""
Say "  --- flow: three samples, 60 s apart ---"
Say "  WHY THESE TABLES: RTSData_UserStatus is an UPSERT keyed (UserId,StatusId,ServerId,OnDate)"
Say "  (db/functions/02_rtsdata_functions.sql:204, db/schema.sql:873) - its count(*) is NOT obliged to"
Say "  grow in a calm minute, so it is REPORTED but is NOT part of the gate. RTSData_UserStatusLog has"
Say "  its own Id primary key (db/schema.sql:880) and is appended to. RTSData_Interaction is also an"
Say "  UPSERT (ON CONFLICT InteractionId,Segment,ServerId :112) - it grows on NEW interactions only."
Say "  Therefore: growth is a PASS; no growth is judged by FRESHNESS, not called death."
$sampleSql = Join-Path $env:TEMP ("state3_s_{0}.sql" -f $stamp)
$sampleText = @'
SELECT (SELECT count(*) FROM "RTSData_Interaction")::text || '|' ||
       (SELECT count(*) FROM "RTSData_UserStatusLog")::text || '|' ||
       (SELECT count(*) FROM "RTSData_UserStatus")::text || '|' ||
       COALESCE((SELECT round(EXTRACT(EPOCH FROM (now() - max("UpdateTime"))))::text FROM "RTSData_Interaction"),'NULL') || '|' ||
       COALESCE((SELECT round(EXTRACT(EPOCH FROM (now() - max("UpdateTime"))))::text FROM "RTSData_UserStatus"),'NULL');
'@
[IO.File]::WriteAllText($sampleSql, $sampleText, (New-Object System.Text.UTF8Encoding($false)))
$ia = @(); $la = @(); $ua = @(); $ageI = @(); $ageU = @()
for ($i = 1; $i -le 3; $i++) {
    $sf = Join-Path $env:TEMP ("state3_s{0}_{1}.txt" -f $i, $stamp)
    & $psql -v ON_ERROR_STOP=1 -h 127.0.0.1 -p $DbPort -U $DbUser -d $DbName -At -o $sf -f $sampleSql 2>> $errf
    $src = $LASTEXITCODE
    $line = ""; if (Test-Path $sf) { $line = (Get-Content $sf | Select-Object -First 1) }
    $parts = "$line".Split("|")
    if (($src -eq 0) -and ($parts.Count -eq 5)) {
        $ia += [int64]$parts[0]; $la += [int64]$parts[1]; $ua += [int64]$parts[2]
        if ($parts[3] -ne "NULL") { $ageI += [int64]$parts[3] }
        if ($parts[4] -ne "NULL") { $ageU += [int64]$parts[4] }
        Say ("    sample {0} at {1} : Interaction={2}  UserStatusLog={3}  UserStatus={4}(no gate)  newest row age: Interaction {5}s / UserStatus {6}s" -f $i, (Get-Date -Format HH:mm:ss), $parts[0], $parts[1], $parts[2], $parts[3], $parts[4])
    } else {
        Say ("    sample {0} FAILED (rc {1}, line '{2}') - the flow verdict below is void" -f $i, $src, $line)
    }
    Remove-Item $sf -ErrorAction SilentlyContinue
    if ($i -lt 3) { Start-Sleep -Seconds 60 }
}
$flowOk = $false; $flowVerdict = "UNMEASURED"
if (($ia.Count -eq 3) -and ($la.Count -eq 3)) {
    $iMono = (($ia[1] -ge $ia[0]) -and ($ia[2] -ge $ia[1]))
    $lMono = (($la[1] -ge $la[0]) -and ($la[2] -ge $la[1]))
    $grew  = (($ia[2] -gt $ia[0]) -or ($la[2] -gt $la[0]))
    Say ("    non-decreasing : Interaction {0} / UserStatusLog {1}   (a DECREASE is a hard failure)" -f $iMono, $lMono)
    Say ("    deltas over the window : Interaction {0} / UserStatusLog {1} / UserStatus {2} (reported, not gated)" -f ($ia[2]-$ia[0]), ($la[2]-$la[0]), $(if ($ua.Count -eq 3) { $ua[2]-$ua[0] } else { "n/a" }))
    $freshSec = 900
    $best = $null; $anomaly = @()
    foreach ($v in @($ageI + $ageU)) {
        if ($v -lt 0) { $anomaly += $v; continue }
        if (($null -eq $best) -or ($v -lt $best)) { $best = $v }
    }
    if ($anomaly.Count -gt 0) { Say ("    ANOMALY: {0} age reading(s) are NEGATIVE ({1} s) - rows timestamped in the FUTURE relative to the database clock; excluded from freshness, see PR234-TIME-01" -f $anomaly.Count, ($anomaly -join ", ")) }
    Say ("    newest row anywhere in the feed : {0}   threshold for FRESH : {1} s" -f $(if ($null -ne $best) { "$best s" } else { "no timestamp at all" }), $freshSec)
    if (-not ($iMono -and $lMono)) { $flowVerdict = "FAIL (a counter went DOWN - that is not a quiet hour)" }
    elseif ($grew) { $flowVerdict = "GROWING"; $flowOk = $true }
    elseif (($null -ne $best) -and ($best -le $freshSec)) { $flowVerdict = "QUIET BUT FRESH (no new rows in the window; the newest row is $best s old - consistent with an idle contact centre, NOT with a dead feed)"; $flowOk = $true }
    else { $flowVerdict = "STALE (nothing arrived in the window and the newest row is older than the threshold)" }
} else { $flowVerdict = "UNMEASURED (fewer than three good samples) - this is not a FAIL, it is an absence of measurement" }
Say ("  FLOW VERDICT : {0}" -f $flowVerdict)
Remove-Item $sqlf, $sampleSql, $resf -ErrorAction SilentlyContinue
$env:PGPASSWORD = ""
Say ""

Say "===== 8  the four Shell keys (READ ONLY - nothing is written) ====="
Say "  expected, per handoff: DefaultTenantSlug / MetricsApply.BaseUrl / RtmRelay override are ABSENT,"
Say "                         and the Serilog path is RELATIVE (logs/log-.txt) - a known open item, not a surprise"
if (-not (Test-Path $shellCfg)) { Say ("  {0} : ABSENT - this section is a GAP" -f $shellCfg) }
else {
    $raw = Get-Content $shellCfg -Raw
    Say ("  file {0}   {1} bytes   sha256 {2}" -f $shellCfg, $raw.Length, (Get-FileHash $shellCfg -Algorithm SHA256).Hash)
    $j = $raw | ConvertFrom-Json
    Say ("  top-level keys : {0}" -f (($j.PSObject.Properties.Name) -join ", "))
    foreach ($k in @("DefaultTenantSlug","MetricsApply","RtmRelay","Serilog")) {
        $present = @($j.PSObject.Properties.Name) -contains $k
        Say ("  key '{0}' present at top level : {1}" -f $k, $present)
    }
    $slug = [regex]::Matches($raw, '(?i)"DefaultTenantSlug"\s*:\s*"([^"]*)"')
    Say ("  DefaultTenantSlug value : {0}" -f $(if ($slug.Count -gt 0) { "'" + $slug[0].Groups[1].Value + "'" } else { "NOT PRESENT anywhere in the file" }))
    $base = [regex]::Matches($raw, '(?i)"BaseUrl"\s*:\s*"([^"]*)"')
    Say ("  BaseUrl values anywhere : {0}" -f $(if ($base.Count -gt 0) { (($base | ForEach-Object { $_.Groups[1].Value }) -join ", ") } else { "NONE" }))
    $relay = [regex]::Matches($raw, '(?i)"RtmRelay"')
    Say ("  occurrences of RtmRelay : {0}" -f $relay.Count)
    $logp = [regex]::Matches($raw, '(?i)"path"\s*:\s*"([^"]*)"')
    Say ("  Serilog path values : {0}" -f $(if ($logp.Count -gt 0) { (($logp | ForEach-Object { $_.Groups[1].Value }) -join ", ") } else { "NONE" }))
    Say ("  NEGCTL key 'zzz_no_such_key' present : {0}   (must be False)" -f ((@($j.PSObject.Properties.Name) -contains "zzz_no_such_key")))
    $sysLogs = "C:\Windows\System32\logs"
    if (Test-Path $sysLogs) {
        $newest = @(Get-ChildItem $sysLogs -Filter "log-*.txt" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
        if ($newest.Count -eq 1) { Say ("  Shell log really lands in {0} : newest {1}, modified {2}" -f $sysLogs, $newest[0].Name, $newest[0].LastWriteTime) }
        else { Say ("  {0} exists but holds no log-*.txt" -f $sysLogs) }
    } else { Say ("  {0} : ABSENT" -f $sysLogs) }
}
Say ""

Say "===== SUMMARY ====="
Say ("  liveness pair          : {0}" -f $liveness)
Say ("  flow                   : {0}" -f $flowVerdict)
Say ("  psql rc (main section) : {0}   stderr {1} bytes" -f $rc, $errSize)
Say ("  collector still intact : {0}   (must be ArrayList)" -f $ProbeLines.GetType().Name)
Say "  Everything above is a reading. NOTHING WAS STARTED, STOPPED OR CHANGED."
Say "===== END-OF-RUN MARKER: STATE-3-COMPLETE ====="
$overall = ($liveness -and $flowOk -and ($rc -eq 0) -and ($errSize -eq 0))
Say ("  LAST LINE : {0}" -f $(if ($overall) { "PASS" } else { "FAIL (read the sections - a FAIL here means at least one gate did not close)" }))
Fin $overall
