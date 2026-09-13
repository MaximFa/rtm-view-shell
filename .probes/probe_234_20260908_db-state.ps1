#Requires -Version 5.1
<#
  PROBE 234 / db-state   -   READ ONLY. No table is written, no row is inserted or deleted.
  WHERE IT RUNS : server 234 (G0 exits, it does not warn).
  PURPOSE       : the installer's own VERIFY reported failures on a database that may be healthy.
                  Measured 2026-09-08: its queries are written correctly in the source
                  (public."RTSGrid_Metric"), but reach psql WITHOUT the quotes, so PostgreSQL
                  folds the names to lower case and reports "relation does not exist".
                  A broken instrument cannot settle the question. This probe asks its own.
  IDENTITY      : the database is asked WHO IT IS (current_database, inet_server_port, version)
                  before anything is counted - so the numbers belong to the database we installed,
                  not to whichever one the connection happened to reach.
  BOTH CONTROLS : every existence check is run once on a name that MUST be found and once on a
                  name that CANNOT exist. A check that only ever answers one way measures nothing.
#>

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"
$OpsRoot  = "C:\RTMView-Ops"
$OutDir   = Join-Path $OpsRoot "output"
$Preserve = Join-Path $OpsRoot "preserve_20260906_1230"
$CurDir   = Join-Path $Preserve "configs\current"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_db-state.txt"
$errf  = Join-Path $OutDir "234_$($stamp)_db-state.err.txt"
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

Say "===== G0 which machine is this ====="
$n = ($env:COMPUTERNAME -eq "RTM")
$u = ("$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper() -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
$m = (@(Get-WmiObject Win32_NetworkAdapter -Filter "MACAddress IS NOT NULL" -ErrorAction SilentlyContinue |
        ForEach-Object { "$($_.MACAddress)".Replace(":","").ToUpper() }) -contains "000D3AD3061B")
Say ("  name {0} / uuid {1} / mac {2}" -f $n, $u, $m)
if (-not ($n -and $u -and $m)) { Say "  *** G0 FAILED - not server 234."; Fin $false }
Say "  G0 PASS"

$psqlExe = @(Get-ChildItem 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -ErrorAction SilentlyContinue)
$cfg = "C:\RTMView\Shell\appsettings.json"
if ($psqlExe.Count -ne 1 -or -not (Test-Path $cfg)) { Say "  *** psql or deployed config missing."; Fin $false }
$psql = $psqlExe[0].FullName
$raw  = [IO.File]::ReadAllText($cfg)
$pw   = ([regex]::Match($raw,'Password\s*=\s*([^";]+)')).Groups[1].Value
$usr  = ([regex]::Match($raw,'Username\s*=\s*([^";]+)')).Groups[1].Value
if ($pw.Length -eq 0) { Say "  *** password not found in the DEPLOYED config."; Fin $false }
Say ("  connecting as {0} (password length {1}, never printed) - from the DEPLOYED config, so we test what the app will use" -f $usr, $pw.Length)

function Ask([string]$sqlText) {
    $t = Join-Path $env:TEMP ("db_{0}.sql" -f [guid]::NewGuid().ToString("N"))
    $e = Join-Path $env:TEMP ("db_{0}.err" -f [guid]::NewGuid().ToString("N"))
    # the query goes through a FILE, not through -c: that is exactly how the installer's VERIFY
    # lost its quotes on 2026-09-08 and then reported a healthy database as broken.
    [IO.File]::WriteAllText($t, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $pw
    $r = & $psql -h 127.0.0.1 -p 5433 -U $usr -d rtmviewdb -v ON_ERROR_STOP=1 -A -F "|" -t -f $t 2> $e
    $env:PGPASSWORD = $null
    if (Test-Path $e) {
        $c = [IO.File]::ReadAllText($e)
        if ($c.Trim().Length -gt 0) { [void]$errAll.Add($c) }
        Remove-Item $e -ErrorAction SilentlyContinue
    }
    Remove-Item $t -ErrorAction SilentlyContinue
    return (@($r | Where-Object { $_ -ne $null -and "$_".Trim().Length -gt 0 }) -join "")
}

Say ""
Say "===== 1  which database is this - asked OF the server ====="
Say ("  {0}" -f (Ask "SELECT current_database()||' | port '||inet_server_port()||' | '||split_part(version(),',',1);"))
Say ("  current_user : {0}" -f (Ask "SELECT current_user;"))
$port = Ask "SELECT inet_server_port();"
Say ("  port is 5433 : {0}   (must be True - 5432 is a foreign estate)" -f ($port -eq "5433"))
if ($port -ne "5433") { Say "  *** STOP - wrong instance."; Fin $false }

Say ""
Say "===== 2  do the tables exist - quoted properly, and each check proved both ways ====="
foreach ($t in @('RTSGrid_Metric','RTSGrid_MetricTranslation','RTSGrid_Grid','RTSGrid_Row','RTSGrid_Column','RTSGrid_Cell','RTSUserGrid_Grid','RTSUserGrid_Column','RTSUserGrid_ColumnsSet','NGC_Site','RTSData_Interaction')) {
    $v = Ask ("SELECT COALESCE(to_regclass('public.""{0}""')::text,'<absent>');" -f $t)
    Say ("  {0,-28} : {1}" -f $t, $v)
}
Say ("  NEGCTL a table that cannot exist : {0}   (must be <absent>)" -f (Ask "SELECT COALESCE(to_regclass('public.""ZZZNoSuchTable_xyz""')::text,'<absent>');"))
Say ""
Say "  the same names WITHOUT quotes - this is what the installer's VERIFY actually sent:"
Say ("      unquoted RTSGrid_Metric : {0}   (this is the artefact, not the truth)" -f (Ask "SELECT COALESCE(to_regclass('public.RTSGrid_Metric')::text,'<absent>');"))

Say ""
Say "===== 3  the numbers a fresh install must produce (measured 2026-09-06 in db/data) ====="
$expect = @(
  @{ t='RTSGrid_Metric';            n=203 },
  @{ t='RTSGrid_MetricTranslation'; n=402 },
  @{ t='RTSGrid_Grid';              n=1   },
  @{ t='RTSGrid_Row';               n=1   },
  @{ t='RTSGrid_Column';            n=5   },
  @{ t='RTSGrid_Cell';              n=5   },
  @{ t='RTSUserGrid_ColumnsSet';    n=1   },
  @{ t='RTSUserGrid_Grid';          n=1   },
  @{ t='RTSUserGrid_Column';        n=5   },
  @{ t='NGC_Site';                  n=3   }
)
$bad = 0
foreach ($x in $expect) {
    $c = Ask ("SELECT COUNT(*) FROM public.""{0}"";" -f $x.t)
    $ok = ($c -eq "$($x.n)")
    Say ("  {0,-28} {1,6}   expected {2,6}   {3}" -f $x.t, $c, $x.n, $(if ($ok) { "ok" } else { "*** MISMATCH" }))
    if (-not $ok) { $bad++ }
}
Say ("  tables whose count differs from the seed : {0}   (must be 0; zero everywhere would mean the seed did not run)" -f $bad)

Say ""
Say "===== 4  the metric that was removed from the product ====="
Say ("  QueueNumberOfLoggedAgents defined : {0}   (must be 0 - the standing prediction)" -f (Ask "SELECT COUNT(*) FROM public.""RTSGrid_Metric"" WHERE ""MetricId""='QueueNumberOfLoggedAgents';"))
Say ("  QueueLoginDataNumLoggedUsers      : {0}   (must be 1 - POSITIVE control: the query can find)" -f (Ask "SELECT COUNT(*) FROM public.""RTSGrid_Metric"" WHERE ""MetricId""='QueueLoginDataNumLoggedUsers';"))
Say ("  NEGCTL an invented metric id      : {0}   (must be 0)" -f (Ask "SELECT COUNT(*) FROM public.""RTSGrid_Metric"" WHERE ""MetricId""='ZZZNoSuchMetric_xyz';"))

Say ""
Say "===== 5  tenants and the superadmin - the one VERIFY line that was NOT an artefact ====="
Say ("  public.tenants exists : {0}" -f (Ask "SELECT COALESCE(to_regclass('public.tenants')::text,'<absent>');"))
Say ("  rows in tenants       : {0}" -f (Ask "SELECT COUNT(*) FROM public.tenants;"))
Say ("  slugs                 : {0}" -f (Ask "SELECT COALESCE(string_agg(slug,', '),'<none>') FROM public.tenants;"))
Say ("  identity.users exists : {0}" -f (Ask "SELECT COALESCE(to_regclass('identity.users')::text,'<absent>');"))
Say ("  rows in identity.users: {0}" -f (Ask "SELECT COUNT(*) FROM identity.users;"))
Say ("  superadmin present    : {0}   (quoted properly, unlike the installer's VERIFY)" -f (Ask "SELECT COUNT(*) FROM identity.users WHERE ""NormalizedUserName""='SUPERADMIN';"))
Say ("  NEGCTL an invented user : {0}   (must be 0)" -f (Ask "SELECT COUNT(*) FROM identity.users WHERE ""NormalizedUserName""='ZZZNOSUCHUSER';"))

Say ""
Say "===== 6  orphans - the mechanism backend-0906 fixes; on a fresh base there must be none ====="
Say ("  cells whose row is missing    : {0}   (must be 0 on a fresh database)" -f (Ask "SELECT COUNT(*) FROM public.""RTSGrid_Cell"" c LEFT JOIN public.""RTSGrid_Row"" r ON r.""RowId""=c.""RowId"" WHERE r.""RowId"" IS NULL;"))
Say ("  cells whose column is missing : {0}   (must be 0)" -f (Ask "SELECT COUNT(*) FROM public.""RTSGrid_Cell"" c LEFT JOIN public.""RTSGrid_Column"" k ON k.""ColumnId""=c.""ColumnId"" WHERE k.""ColumnId"" IS NULL;"))
Say ("  NEGCTL orphan on a self-join  : {0}   (must be 0 - proves the join shape is sane)" -f (Ask "SELECT COUNT(*) FROM public.""RTSGrid_Cell"" c LEFT JOIN public.""RTSGrid_Cell"" c2 ON c2.""CellId""=c.""CellId"" WHERE c2.""CellId"" IS NULL;"))

Say ""
Say "===== END-OF-RUN MARKER: DB-STATE-COMPLETE ====="
Say ""
Say "NOTHING WAS WRITTEN. No row inserted, updated or deleted."
Fin $true
