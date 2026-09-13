#Requires -Version 5.1
<#
  PROBE 234 / dataflow   -   READ ONLY. Nothing is started, stopped or written.
  WHERE IT RUNS : server 234 (G0 exits, it does not warn).
  THE QUESTION  : the system is up but reads NOTHING from the contact centre - no agents, no
                  queues, no skills. The engine log shows "no unions loaded yet" and
                  "LongestAction = 0 (0,0)". Up is not the same as working.
  THE CHAIN, and this probe walks it end to end without guessing which link is broken:
      contact centre  ->  adapter (RTM.Twilio)  ->  named pipe  ->  engine (RTM)  ->  database
  Each link is asked separately, and its own evidence is printed. Secrets are never printed -
  only their length.
#>

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_dataflow.txt"
$errf  = Join-Path $OutDir "234_$($stamp)_dataflow.err.txt"
$errAll = New-Object System.Collections.ArrayList
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    [IO.File]::WriteAllLines($errf, $errAll, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    Write-Host ("STDERR: {0}" -f $errf)
    if ($pass) { exit 0 } else { exit 1 }
}

Say "===== G0 ====="
$n = ($env:COMPUTERNAME -eq "RTM")
$u = ("$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper() -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  name {0} / uuid {1}" -f $n, $u)
if (-not ($n -and $u)) { Say "  *** not server 234"; Fin $false }
Say "  G0 PASS"

# ---------------- link 1: the adapter's own configuration ----------------
Say ""
Say "===== 1  the adapter's configuration - what it was told to connect to ====="
$acfg = "C:\RTMView\RTM.Twilio\appsettings.json"
if (-not (Test-Path $acfg)) { Say ("  *** MISSING: {0}" -f $acfg) }
else {
    $at = [IO.File]::ReadAllText($acfg)
    Say ("  file : {0}   ({1} bytes)" -f $acfg, (Get-Item $acfg).Length)
    foreach ($m in [regex]::Matches($at, '"([A-Za-z0-9_]+)"\s*:\s*"([^"]*)"')) {
        $k = $m.Groups[1].Value; $v = $m.Groups[2].Value
        if ($k -match '(?i)token|secret|password|pwd|sid|key$') { Say ("      {0,-28} : <length {1}, never printed>" -f $k, $v.Length) }
        elseif ($v.Length -gt 90) { Say ("      {0,-28} : <{1} chars>" -f $k, $v.Length) }
        else { Say ("      {0,-28} : {1}" -f $k, $v) }
    }
}

# ---------------- link 2: does the adapter log anything ----------------
Say ""
Say "===== 2  the adapter - what it says about itself ====="
$aLogDirs = @("C:\RTMView\RTM.Twilio\Logs","C:\RTMView\RTM.Twilio\log","C:\RTMView\Logs")
$aLogs = @()
foreach ($d in $aLogDirs) {
    if (Test-Path $d) {
        $fs = @(Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue)
        Say ("  {0} : {1} files" -f $d, $fs.Count)
        $aLogs += $fs
    } else { Say ("  {0} : does not exist" -f $d) }
}
$aLogs = @($aLogs | Sort-Object LastWriteTime -Descending)
if ($aLogs.Count -eq 0) {
    Say "  the adapter has written NO log at all."
    Say "  That is itself a finding: a process that connects to a contact centre and says nothing"
    Say "  either has nothing to say, or is not logging - and we cannot tell which from here."
} else {
    foreach ($f in ($aLogs | Select-Object -First 2)) {
        Say ("  --- {0}   ({1} bytes, {2}) ---" -f $f.Name, $f.Length, $f.LastWriteTime)
        foreach ($t in @(Get-Content $f.FullName -Tail 25 -ErrorAction SilentlyContinue)) { Say ("      {0}" -f $t) }
    }
}
$p = @(Get-Process -Name 'RTM.Twilio' -ErrorAction SilentlyContinue)
foreach ($x in $p) { Say ("  process RTM.Twilio pid {0}, started {1}, threads {2}, memory {3:N1} MB" -f $x.Id, $x.StartTime, $x.Threads.Count, ($x.WorkingSet64/1MB)) }

# ---------------- link 3: outbound connections ----------------
Say ""
Say "===== 3  is the adapter talking to anything outside ====="
foreach ($nm in @('RTM.Twilio','RTM')) {
    $pr = @(Get-Process -Name $nm -ErrorAction SilentlyContinue)
    foreach ($x in $pr) {
        $conns = @(Get-NetTCPConnection -OwningProcess $x.Id -ErrorAction SilentlyContinue |
                   Where-Object { $_.State -eq 'Established' -and $_.RemoteAddress -notin @('127.0.0.1','::1') })
        Say ("  {0} (pid {1}) : {2} established connections to the outside" -f $nm, $x.Id, $conns.Count)
        foreach ($c in ($conns | Select-Object -First 10)) {
            Say ("      {0}:{1}  ->  {2}:{3}" -f $c.LocalAddress, $c.LocalPort, $c.RemoteAddress, $c.RemotePort)
        }
    }
}
Say  "  (no outbound connection at all would mean the adapter never reached the contact centre)"

# ---------------- link 4: the pipe ----------------
Say ""
Say "===== 4  the pipe between adapter and engine ====="
$pipeName = ([regex]::Match([IO.File]::ReadAllText("C:\RTMView\RTM\appsettings.json"), '"PipeName"\s*:\s*"([^"]*)"')).Groups[1].Value
$pipes = @([System.IO.Directory]::GetFiles("\\.\pipe\"))
Say ("  PipeName from disk : {0}" -f $pipeName)
Say ("  served             : {0}" -f (@($pipes | Where-Object { $_ -like "*$pipeName*" }).Count -gt 0))
Say ("  NEGCTL impossible pipe : {0}   (must be 0)" -f @($pipes | Where-Object { $_ -like "*zzz_no_such_pipe*" }).Count)

# ---------------- link 5: what the engine says ----------------
Say ""
Say "===== 5  the engine - what it received ====="
$rl = "C:\RTMView\RTM\Logs\RTM.log"
if (Test-Path $rl) {
    Say ("  log : {0} bytes, last write {1}" -f (Get-Item $rl).Length, (Get-Item $rl).LastWriteTime)
    foreach ($pat in @('CLIENT','connected','Connect','union','Union','Agent','Queue','Skill','Error','ERROR','Exception','Twilio')) {
        $c = @(Get-Content $rl -ErrorAction SilentlyContinue | Where-Object { $_ -match $pat }).Count
        Say ("      lines matching '{0,-10}' : {1}" -f $pat, $c)
    }
    Say ("  NEGCTL lines matching a word that cannot be there : {0}   (must be 0)" -f @(Get-Content $rl -ErrorAction SilentlyContinue | Where-Object { $_ -match 'ZZZNoSuchWord' }).Count)
    Say ""
    Say "  --- lines mentioning errors or exceptions, last 15 ---"
    $errs = @(Get-Content $rl -ErrorAction SilentlyContinue | Where-Object { $_ -match 'ERROR|Exception|Failed' })
    if ($errs.Count -eq 0) { Say "      none" }
    foreach ($e2 in ($errs | Select-Object -Last 15)) { Say ("      {0}" -f $e2) }
} else { Say ("  *** engine log missing: {0}" -f $rl) }

# ---------------- link 6: the database ----------------
Say ""
Say "===== 6  did anything reach the database ====="
$psqlExe = @(Get-ChildItem 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -ErrorAction SilentlyContinue)
if ($psqlExe.Count -ne 1) { Say "  psql not found - database section not run" }
else {
    $psql = $psqlExe[0].FullName
    $raw  = [IO.File]::ReadAllText("C:\RTMView\Shell\appsettings.json")
    $pw   = ([regex]::Match($raw,'Password\s*=\s*([^";]+)')).Groups[1].Value
    $usr  = ([regex]::Match($raw,'Username\s*=\s*([^";]+)')).Groups[1].Value
    function Ask([string]$sqlText) {
        $t = Join-Path $env:TEMP ("df_{0}.sql" -f [guid]::NewGuid().ToString("N"))
        $e = Join-Path $env:TEMP ("df_{0}.err" -f [guid]::NewGuid().ToString("N"))
        [IO.File]::WriteAllText($t, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
        $env:PGPASSWORD = $pw
        $r = & $psql -h 127.0.0.1 -p 5433 -U $usr -d rtmviewdb -v ON_ERROR_STOP=1 -A -F "|" -t -f $t 2> $e
        $env:PGPASSWORD = $null
        $failed = $false
        if (Test-Path $e) {
            $c = [IO.File]::ReadAllText($e)
            if ($c.Trim().Length -gt 0) { [void]$errAll.Add($c); $failed = $true }
            Remove-Item $e -ErrorAction SilentlyContinue
        }
        Remove-Item $t -ErrorAction SilentlyContinue
        if ($failed) { return "<QUERY FAILED - see .err>" }
        $v = (@($r | Where-Object { "$_".Trim().Length -gt 0 }) -join "`n")
        if ($v.Trim().Length -eq 0) { return "<empty>" }
        return $v
    }
    Say ("  identity : {0}" -f (Ask "SELECT current_database()||' | port '||inet_server_port();"))
    Say  "  tables that would hold data from the contact centre:"
    foreach ($t in @('NGC_Site','NGC_Agent','NGC_Queue','NGC_Skill','NGC_AgentGroup','RTSData_Interaction','RTSData_AgentState','RTSGrid_Statistic')) {
        $exists = Ask ("SELECT COALESCE(to_regclass('public.""{0}""')::text,'<absent>');" -f $t)
        if ($exists -eq '<absent>') { Say ("      {0,-24} : table absent" -f $t) }
        else { Say ("      {0,-24} : {1} rows" -f $t, (Ask ("SELECT COUNT(*) FROM public.""{0}"";" -f $t))) }
    }
    Say  "  every table this engine writes to, with a non-zero count:"
    foreach ($r2 in (Ask "SELECT relname||' = '||n_live_tup FROM pg_stat_user_tables WHERE n_live_tup > 0 ORDER BY n_live_tup DESC LIMIT 25;").Split("`n")) { Say ("      {0}" -f $r2) }
    Say ("  NEGCTL count from a table that cannot exist : {0}" -f (Ask "SELECT COALESCE(to_regclass('public.""ZZZNoSuch""')::text,'<absent>');"))
}

Say ""
Say "===== END-OF-RUN MARKER: DATAFLOW-COMPLETE ====="
Say ""
Say "NOTHING WAS STARTED, STOPPED OR WRITTEN."
Fin $true
