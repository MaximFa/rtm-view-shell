#Requires -Version 5.1
# ============================================================================
#  PROBE 234 / roles-control   -   READ ONLY.  NOTHING IS STOPPED OR CHANGED.
#  WHERE IT RUNS : server 234, databases 5432 (untouched, PG15) and 5433 (ours, PG18).
#  WRITES        : output files only, into C:\RTMView-Ops\output\
#  DOES NOT      : create/alter/drop any role; write to any database; touch any service;
#                  touch C:\IceDash\.
#  PURPOSE       : the previous run compared two zeroes - the role we look for and an
#                  invented one both returned 0. That proves the query can say NO. It does
#                  NOT prove it can say YES. Until a role that certainly EXISTS comes back
#                  found, "ccdashboard_catowner is absent" is unmeasured, not established.
#  BOTH CONTROLS : POSITIVE - ccdashboard_user (we are connecting AS it, so it must exist).
#                  NEGATIVE - ccdashboard_nosuchrole_xyz (must not exist).
#                  The run is only valid if positive=1 AND negative=0 on each server.
#  SECRETS       : DB password read from the machine config; only its length is printed.
# ============================================================================

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"

$OutDir   = "C:\RTMView-Ops\output"
$ShellCfg = "C:\RTMView\Shell\appsettings.json"
$server   = "234"
$topic    = "roles-control"

Write-Host "WHERE IT RUNS : server $server, ports 5432 and 5433. READ ONLY - no role is created or changed."

$psqlExe = @(Get-ChildItem 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -ErrorAction SilentlyContinue)
if ($psqlExe.Count -ne 1 -or -not (Test-Path $ShellCfg)) {
    Write-Host "STOP: psql matches=$($psqlExe.Count), config exists=$(Test-Path $ShellCfg). Nothing was run."
    exit 1
}
$psql = $psqlExe[0].FullName
$txt  = [IO.File]::ReadAllText($ShellCfg)
$pw   = ([regex]::Match($txt,'Password\s*=\s*([^";]+)')).Groups[1].Value
$usr  = ([regex]::Match($txt,'Username\s*=\s*([^";]+)')).Groups[1].Value
if ($pw.Length -eq 0) { Write-Host "STOP: password not found in $ShellCfg. Nothing was run."; exit 1 }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).txt"
$errf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).err.txt"
$errAll = New-Object System.Collections.ArrayList
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }

function Ask([int]$port, [string]$sqlText) {
    $t = Join-Path $env:TEMP ("rc_{0}.sql" -f [guid]::NewGuid().ToString("N"))
    $e = Join-Path $env:TEMP ("rc_{0}.err" -f [guid]::NewGuid().ToString("N"))
    [IO.File]::WriteAllText($t, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $pw
    $r = & $psql -h 127.0.0.1 -p $port -U $usr -d rtmviewdb -v ON_ERROR_STOP=1 -A -F "|" -t -f $t 2> $e
    $env:PGPASSWORD = $null
    if (Test-Path $e) {
        $c = [IO.File]::ReadAllText($e)
        if ($c.Trim().Length -gt 0) { [void]$errAll.Add("port $port :: $c") }
        Remove-Item $e -ErrorAction SilentlyContinue
    }
    Remove-Item $t -ErrorAction SilentlyContinue
    return @($r | Where-Object { $_ -ne $null -and "$_".Trim().Length -gt 0 })
}

Say ("  connecting as {0} (password length {1}, never printed)" -f $usr, $pw.Length)

$valid = @{}
foreach ($p in 5432,5433) {
    Say ""
    Say ("===== port {0} =====" -f $p)
    foreach ($r in (Ask $p "SELECT '  identity: '||current_database()||' | port '||inet_server_port()||' | '||split_part(version(),',',1);")) { Say $r }

    $pos = (Ask $p "SELECT count(*) FROM pg_roles WHERE rolname='ccdashboard_user';") -join ""
    $neg = (Ask $p "SELECT count(*) FROM pg_roles WHERE rolname='ccdashboard_nosuchrole_xyz';") -join ""
    $tgt = (Ask $p "SELECT count(*) FROM pg_roles WHERE rolname='ccdashboard_catowner';") -join ""

    Say ("  POSITIVE CONTROL  ccdashboard_user          : {0}   (must be 1 - the query must be able to FIND)" -f $pos)
    Say ("  NEGATIVE CONTROL  ccdashboard_nosuchrole_xyz: {0}   (must be 0 - the query must be able to DENY)" -f $neg)
    $ok = ($pos -eq "1" -and $neg -eq "0")
    $valid[$p] = $ok
    Say ("  both controls hold on this server           : {0}" -f $ok)
    if ($ok) {
        Say ("  --> TARGET  ccdashboard_catowner           : {0}   (0 = genuinely absent, 1 = present)" -f $tgt)
    } else {
        Say ("      TARGET  ccdashboard_catowner           : {0}   *** UNMEASURED - controls failed, do not read this" -f $tgt)
    }

    Say "  --- every role on this server (name | can login | superuser) ---"
    foreach ($r in (Ask $p "SELECT '      '||rolname||' | login='||rolcanlogin||' | super='||rolsuper FROM pg_roles ORDER BY rolname;")) { Say $r }
}

Say ""
Say "===== END-OF-RUN MARKER: ROLES-CONTROL-COMPLETE ====="

[IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllLines($errf, $errAll, (New-Object System.Text.UTF8Encoding($false)))

$errSize = (Get-Item $errf).Length
$content = [IO.File]::ReadAllText($outf, [Text.Encoding]::UTF8)
$marker  = $content.Contains('ROLES-CONTROL-COMPLETE')
$allOk   = ($valid[5432] -and $valid[5433])

Write-Host ""
Write-Host "stderr size   : $errSize bytes   (0 expected)"
Write-Host "END marker    : $marker  (must be True)"
Write-Host "both controls hold on BOTH servers : $allOk  (must be True)"
Write-Host ""
if ($errSize -eq 0 -and $marker -and $allOk) { Write-Host "GATE: PASS - the catowner answer is a measurement" }
else { Write-Host "GATE: FAIL - the catowner answer is NOT a measurement. Report, do not read the number." }
Write-Host ""
Write-Host "NOTHING WAS CHANGED. No role was created, altered or dropped."
Write-Host ""
Write-Host "COPY THESE BACK:"
Write-Host "   $outf"
Write-Host "   $errf"
