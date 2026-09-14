#Requires -Version 5.1
<#
  PROBE 234 / who answers our init - the SignalR address our Shell dials, and WHO owns that port.
  WHERE IT RUNS : server 234 (machine RTM). Name and hardware UUID are a gate.
  WHAT IT DOES  : READS. Two SELECTs on 5433 and a listener lookup. It restarts nothing, writes no
                  config, changes no data, installs nothing, and issues no statement other than SELECT.
                  C:\IceDash, the production RTM.Twilio, legacy RTM, PostgreSQL 15 on 5432 and
                  C:\Program Files\CcDashboard are not touched - the last one is only NAMED if a
                  listener lookup happens to return it.
  THE QUESTION  : at 23:59:46 the Shell logged "reconnected ... union 21" and "init union 21,
                  serverTimeOffset = -0.9 ms", i.e. something ANSWERED its init - while OUR engine
                  logged no OnConnected, no init GridId=, no Groups.Add and no <<getUsers in that
                  second, and those three lines are unconditional in the code. Somebody replied, and it
                  may not be the engine we restarted. Two numbers separate every version of this:
                  the address in tenant settings, and the owner of the port behind it.
  NEGATIVE HALF : "no row in tenant_settings" and "the value is empty" are DIFFERENT answers, and this
                  run reports which one it is instead of substituting a default from the code.
  PASSWORD      : Read-Host -AsSecureString, never printed, cleared from the environment at the end.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir   = 'C:\RTMView-Ops\output'
$DBPORT   = '5433'
$DBNAME   = 'rtmviewdb'
$DBUSER   = 'ccdashboard_user'
$TENANT   = '019e03e9-60dd-72da-bd01-648ffdb2b433'
$SENTINEL = -999

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_signalr-owner.txt')
$sqlf  = Join-Path $OutDir ('234_' + $stamp + '_signalr-owner.sql')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    if ($env:PGPASSWORD) { $env:PGPASSWORD = '' }
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound - the two numbers are above)' }
                       else        { 'VERDICT: FAIL (instrument unsound - nothing below proves anything)' }))
    Flush
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Safe-Count($c) { if ($null -eq $c) { return $SENTINEL } return @($c).Count }

Say '===== 0  machine and instrument ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ('  name {0} -> {1} ; uuid match -> {2}' -f $env:COMPUTERNAME, $nameOk, ($uuid -eq $UUIDGATE))
if (-not ($nameOk -and ($uuid -eq $UUIDGATE))) { Say '  *** NOT server 234 - refusing to run'; Fin $false }
Say ('  assignment gate : unassigned {0} (want {1})' -f (Safe-Count $null), $SENTINEL)
Say ('  now : {0}   READ ONLY, SELECT only, port {1}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $DBPORT)

Say ''
Say '===== 1  psql - found, not assumed ====='
$psql = @(Get-ChildItem -Path 'C:\Program Files\PostgreSQL' -Filter 'psql.exe' -Recurse -ErrorAction SilentlyContinue |
          Sort-Object FullName -Descending)
if ((Safe-Count $psql) -lt 1) { Say '  *** psql not found'; Fin $false }
$PSQL = $psql[0].FullName
Say ('  using : {0}' -f $PSQL)

Say ''
Say '===== 2  the address, from tenant_settings - table and column DISCOVERED, not guessed ====='
Say '  table name comes from the code (AppDbContext: e.ToTable("tenant_settings")); the COLUMN is'
Say '  discovered in information_schema, because EF naming conventions are a guess I refuse to make.'
$sql = @()
$sql += "\pset format unaligned"
$sql += "\pset tuples_only on"
$sql += "SELECT '@@COL@@' || column_name || ' :: ' || data_type FROM information_schema.columns WHERE table_name = 'tenant_settings' ORDER BY ordinal_position;"
$sql += "SELECT '@@ROWS@@' || count(*)::text FROM tenant_settings;"
$sql += "SELECT format('SELECT ''@@MINE@@'' || count(*)::text FROM tenant_settings WHERE %I = ''" + $TENANT + "''::uuid', (SELECT column_name FROM information_schema.columns WHERE table_name = 'tenant_settings' AND column_name ILIKE '%tenant%id%' LIMIT 1));"
$sql += "\gexec"
$sql += "SELECT format('SELECT ''@@URL@@'' || coalesce(%I::text, ''(NULL)'') FROM tenant_settings WHERE %I = ''" + $TENANT + "''::uuid', (SELECT column_name FROM information_schema.columns WHERE table_name = 'tenant_settings' AND column_name ILIKE '%signalr%' LIMIT 1), (SELECT column_name FROM information_schema.columns WHERE table_name = 'tenant_settings' AND column_name ILIKE '%tenant%id%' LIMIT 1));"
$sql += "\gexec"
$sql += "SELECT '@@NEG@@' || count(*)::text FROM tenant_settings WHERE " + "1 = 0;"
[IO.File]::WriteAllLines($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))
Say ('  SQL written to : {0}' -f $sqlf)
Say '  statements: SELECT only. No INSERT, UPDATE, DELETE, CREATE, ALTER or DROP anywhere in this run.'

$sec = Read-Host ('Password for ' + $DBUSER + ' on port ' + $DBPORT) -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
$raw = & $PSQL -h localhost -p $DBPORT -U $DBUSER -d $DBNAME -f $sqlf 2>&1
$code = $LASTEXITCODE
$env:PGPASSWORD = ''
Say ('  psql exit code : {0}   expected 0' -f $code)

$cols = New-Object System.Collections.ArrayList
$url = $null; $rowsAll = $SENTINEL; $rowsMine = $SENTINEL; $neg = $SENTINEL
foreach ($l in @($raw | ForEach-Object { "$_" })) {
    $t = "$l".Trim()
    if     ($t.StartsWith('@@COL@@'))  { [void]$cols.Add($t.Substring(7)) }
    elseif ($t.StartsWith('@@ROWS@@')) { $rowsAll = [int]$t.Substring(8) }
    elseif ($t.StartsWith('@@MINE@@')) { $rowsMine = [int]$t.Substring(8) }
    elseif ($t.StartsWith('@@URL@@'))  { $url = $t.Substring(7) }
    elseif ($t.StartsWith('@@NEG@@'))  { $neg = [int]$t.Substring(7) }
}
if ($code -ne 0) {
    Say '  *** the query did not answer. Verbatim output, because a refusal must show what it tripped on:'
    foreach ($l in @($raw | Select-Object -First 25)) { Say ('      | ' + "$l") }
    Fin $false
}
Say ('  columns of tenant_settings : {0}' -f (Safe-Count $cols))
foreach ($c in $cols) { if ($c -match '(?i)signalr|tenant') { Say ('      {0}' -f $c) } }
Say ('  rows in tenant_settings, all tenants : {0}' -f $rowsAll)
Say ('  rows for tenant {0} : {1}' -f $TENANT, $rowsMine)
Say ('  NEGCTL (a WHERE that can match nothing) : {0}   expected 0' -f $neg)
if ($neg -ne 0) { Say '  *** the instrument counts rows that cannot exist'; Fin $false }
if ($rowsMine -eq 0) {
    Say '  *** THERE IS NO ROW for this tenant. That is NOT the same as an empty value, and I am not'
    Say '  *** substituting the default from the code. Reporting it as it is.'
    Fin $true
}
if ($null -eq $url) { Say '  *** no @@URL@@ line came back - reporting nothing rather than guessing'; Fin $false }
Say ''
Say ('  SignalRConnectionUrl = {0}' -f $url)

Say ''
Say '===== 3  WHO owns that port - runbook 8.3, applied to the address we just read ====='
if ($url -eq '(NULL)') {
    Say '  the value is NULL: the Shell falls back to whatever its own configuration says, and THAT'
    Say '  is a different question. Nothing to look up here; reporting the NULL as the answer.'
    Fin $true
}
$port = $null; $host2 = $null
try {
    $u = [Uri]$url
    $host2 = $u.Host
    $port = $u.Port
} catch {
    Say ('  *** cannot parse the value as a URI: {0}' -f $_.Exception.Message)
    Say '  printing it verbatim above is the answer; the owner lookup needs a port and there is none.'
    Fin $true
}
Say ('  host {0}   port {1}' -f $host2, $port)
$conns = @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
Say ('  listeners on {0} : {1}   (zero would mean nobody listens, which is itself an answer)' -f $port, (Safe-Count $conns))
foreach ($c in $conns) {
    $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
    $svc  = @(Get-WmiObject Win32_Service -ErrorAction SilentlyContinue | Where-Object { $_.ProcessId -eq $c.OwningProcess })
    Say ('      {0,-22} pid {1,-7} {2}' -f $c.LocalAddress, $c.OwningProcess, $(if ($proc) { $proc.Path } else { '(process gone)' }))
    foreach ($s in $svc) { Say ('          service : {0}' -f $s.Name) }
}
Say ''
Say '  OURS is C:\RTMView\Shell\... and C:\RTMView\RTM\... . Anything under C:\Program Files\CcDashboard'
Say '  or C:\IceDash is a DIFFERENT installation, out of perimeter, and would mean our Shell has been'
Say '  talking to a foreign process. I state the paths; I do not draw the conclusion - that is for'
Say '  shell-0912 and the coordinator together.'

Say ''
Say '===== 4  nothing was restarted by this run ====='
foreach ($s in @('RTMService','RTMTwilio_1','RTMViewShell')) {
    foreach ($pr in @(Get-WmiObject Win32_Service -Filter ("Name='" + $s + "'") -ErrorAction SilentlyContinue)) {
        if ($pr.ProcessId -gt 0) {
            $po = Get-Process -Id $pr.ProcessId -ErrorAction SilentlyContinue
            if ($po) { Say ('  {0,-14} pid {1,-7} started {2}' -f $s, $pr.ProcessId, $po.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
        }
    }
}
Remove-Item -LiteralPath $sqlf -Force -ErrorAction SilentlyContinue
Fin $true
