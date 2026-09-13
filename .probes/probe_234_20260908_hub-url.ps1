#Requires -Version 5.1
<#
  PROBE 234 / hub-url   -   READ ONLY. Nothing is written, cached, restarted or cleared.
  WHERE IT RUNS : server 234. Reads BOTH databases: the new one on 5433 and the old one on 5432
                  (the old one is the reference and is only ever read).
  QUESTION      : the tenant's SignalR address has been set, and the widget still does not connect.
                  Where does the value the running Shell actually uses come from.

  The order in the code is not the order people assume (RtmRelayService.GetHubUrlAsync:50-72):
      1. Redis cache, key "<tenantId>:rtm:hub_url"   <- read FIRST
      2. tenant_settings.SignalRConnectionUrl        <- only if the cache is empty
      3. a built-in fallback, with a warning in the log
  So a stale or empty value in the cache makes a correct value in the database invisible.
  This probe prints all three, plus the reference from the untouched 5432 database.
#>

$ErrorActionPreference = "Continue"
$TENANT = "019e03e9-60dd-72da-bd01-648ffdb2b433"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_hub-url.txt"
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
$script:psql = $null
function Sql($label, $port, $db, $usr, $pw, $text) {
    if ($null -eq $script:psql) { Say ("  [{0}] psql not found - GAP" -f $label); return }
    $f = Join-Path $env:TEMP ("hu_{0}_{1}.sql" -f $label, $stamp)
    [IO.File]::WriteAllText($f, $text, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $pw
    $rows = & $script:psql -h 127.0.0.1 -p $port -U $usr -d $db -v ON_ERROR_STOP=1 -At -f $f 2>&1
    $rc = $LASTEXITCODE
    $env:PGPASSWORD = ""
    Remove-Item $f -ErrorAction SilentlyContinue
    foreach ($r in $rows) { Say ("      {0}" -f $r) }
    Say ("  [{0}] psql exit code : {1}" -f $label, $rc)
}

Say "===== G0  machine identity ====="
$nameOk = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ("  name match {0} / uuid match {1}" -f $nameOk, ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))
if (-not ($nameOk -and ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))) { Say "  *** NOT 234"; Fin $false }
Say ("  time now : {0}" -f (Get-Date))
Say "  G0 PASS"
Say ""

$js = Get-Content 'C:\RTMView\Shell\appsettings.json' -Raw | ConvertFrom-Json
$cs = "$($js.ConnectionStrings.Default)"
$pw = ""; $usr = "ccdashboard_user"; $db = "rtmviewdb"
$m = [regex]::Match($cs, "(?i)Password\s*=\s*([^;]+)"); if ($m.Success) { $pw = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Username\s*=\s*([^;]+)"); if ($m.Success) { $usr = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Database\s*=\s*([^;]+)"); if ($m.Success) { $db  = $m.Groups[1].Value.Trim() }
foreach ($pg in @(Get-ChildItem "C:\Program Files\PostgreSQL" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $c = Join-Path $pg.FullName "bin\psql.exe"; if ((Test-Path $c) -and ($null -eq $script:psql)) { $script:psql = $c }
}
Say ("  psql {0} , user {1} , db {2} , password {3} chars" -f $(if ($script:psql) { "found" } else { "NOT FOUND" }), $usr, $db, $pw.Length)
Say ""

Say "===== 1  THE NEW DATABASE (5433) - what is stored now ====="
Sql "new" "5433" $db $usr $pw @'
SELECT 'whoami: db=' || current_database() || ' port=' || inet_server_port();
SELECT 'tenant_settings columns: ' || string_agg(column_name, ', ' ORDER BY ordinal_position)
  FROM information_schema.columns WHERE table_schema='public' AND table_name='tenant_settings';
SELECT 'tenant_settings rows total = ' || count(*)::text FROM public.tenant_settings;
SELECT 'row for our tenant: TenantId=' || "TenantId"::text
    || ' | SignalRConnectionUrl=[' || COALESCE("SignalRConnectionUrl",'<NULL>') || ']'
    || ' | len=' || COALESCE(length("SignalRConnectionUrl"),0)::text
  FROM public.tenant_settings WHERE "TenantId" = '019e03e9-60dd-72da-bd01-648ffdb2b433';
SELECT 'NEGCTL row for an impossible tenant = ' || count(*)::text
  FROM public.tenant_settings WHERE "TenantId" = '00000000-0000-0000-0000-000000000000';
'@
Say ""

Say "===== 2  THE OLD DATABASE (5432) - the reference, read only ====="
Say "  (this instance is the pre-migration production copy and is never written by us)"
Sql "old" "5432" $db $usr $pw @'
SELECT 'whoami: db=' || current_database() || ' port=' || inet_server_port();
SELECT 'rows in tenant_settings = ' || count(*)::text FROM public.tenant_settings;
SELECT 'reference: TenantId=' || "TenantId"::text
    || ' | SignalRConnectionUrl=[' || COALESCE("SignalRConnectionUrl",'<NULL>') || ']'
  FROM public.tenant_settings;
'@
Say ""

Say "===== 3  THE CACHE - which is read BEFORE the database ====="
$cli = $null
foreach ($cand in @("C:\Garnet\redis-cli.exe","C:\Garnet\src\redis-cli.exe")) { if ((Test-Path $cand) -and ($null -eq $cli)) { $cli = $cand } }
Say ("  redis-cli : {0}" -f $(if ($cli) { $cli } else { "NOT FOUND under C:\Garnet - the cache cannot be read here" }))
$redisPw = ""
if ($js.ConnectionStrings.Redis) {
    $rs = "$($js.ConnectionStrings.Redis)"
    $rm = [regex]::Match($rs, "(?i)password\s*=\s*([^,;\s]+)")
    if ($rm.Success) { $redisPw = $rm.Groups[1].Value }
    Say ("  Redis connection string present, password {0} chars" -f $redisPw.Length)
}
if ($null -ne $cli) {
    $key = "$TENANT`:rtm:hub_url"
    Say ("  key : {0}" -f $key)
    $argsBase = @("-h","127.0.0.1","-p","6379")
    if ($redisPw) { $argsBase += @("-a",$redisPw) }
    $v = & $cli @argsBase GET $key 2>&1
    Say ("  GET -> [{0}]" -f ($v -join " "))
    $t = & $cli @argsBase TTL $key 2>&1
    Say ("  TTL -> {0}   (-1 = no expiry, -2 = key absent)" -f ($t -join " "))
    $ping = & $cli @argsBase PING 2>&1
    Say ("  POSCTL PING -> {0}   (must be PONG, otherwise the two lines above mean nothing)" -f ($ping -join " "))
    $neg = & $cli @argsBase GET "zzz:no:such:key" 2>&1
    Say ("  NEGCTL GET of an impossible key -> [{0}]   (must be empty)" -f ($neg -join " "))
    $keys = & $cli @argsBase KEYS "*rtm*" 2>&1
    Say ("  keys matching *rtm* :")
    foreach ($k in $keys) { Say ("      {0}" -f $k) }
}
Say ""

Say "===== 4  WHAT THE SHELL ITSELF SAYS - its log, wherever it actually writes ====="
$cands = @("C:\RTMView\Shell\Logs","C:\Logs\RTMViewShell","C:\Windows\System32\logs")
foreach ($d in $cands) {
    if (-not (Test-Path $d)) { Say ("  {0,-32} : does not exist" -f $d); continue }
    $files = @(Get-ChildItem $d -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3)
    Say ("  {0,-32} : files {1}" -f $d, @(Get-ChildItem $d -File -ErrorAction SilentlyContinue).Count)
    foreach ($f in $files) {
        Say ("      {0}  {1} bytes  {2}" -f $f.Name, $f.Length, $f.LastWriteTime)
        $hits = @(Select-String -Path $f.FullName -Pattern "SignalRConnectionUrl","RtmRelay","hub_url","not set for tenant" -ErrorAction SilentlyContinue | Select-Object -Last 8)
        foreach ($h in $hits) { Say ("        {0}" -f $h.Line) }
        $tail = @(Get-Content $f.FullName -Tail 6 -ErrorAction SilentlyContinue)
        foreach ($t in $tail) { Say ("        | {0}" -f $t) }
    }
}
Say ""

Say "===== 5  can anything even reach the engine's hub port from here ====="
foreach ($p in @(8088,8089,6379)) {
    $l = @(Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue)
    Say ("  port {0} : listeners {1}" -f $p, $l.Count)
    try {
        $c = New-Object Net.Sockets.TcpClient
        $ok = $c.ConnectAsync("127.0.0.1", $p).Wait(3000)
        Say ("      TCP connect to 127.0.0.1:{0} : {1}" -f $p, $(if ($ok -and $c.Connected) { "OPEN" } else { "closed" }))
        $c.Close()
    } catch { Say ("      TCP connect to 127.0.0.1:{0} : error {1}" -f $p, $_.Exception.Message) }
}
$c2 = New-Object Net.Sockets.TcpClient
try { $ok2 = $c2.ConnectAsync("127.0.0.1", 5098).Wait(2000); Say ("  NEGCTL TCP to a free port 5098 : {0}   (must be closed)" -f $(if ($ok2 -and $c2.Connected) { "OPEN" } else { "closed" })) } catch { Say "  NEGCTL TCP to 5098 : closed" }
$c2.Close()
Say ""

Say "===== SUMMARY ====="
Say "  Read only. Nothing was written, no cache key was cleared, no service was restarted."
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "===== END-OF-RUN MARKER: HUB-URL-COMPLETE ====="
Fin $true
