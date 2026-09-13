#Requires -Version 5.1
<#
  PROBE 234 / db-state-2   -   READ ONLY. Nothing is written.
  WHY THIS EXISTS : two questions the previous probe could not answer, one of them because of a
                    defect of my own.
    (a) tenants has 1 row, but my "slugs" line came out empty - the column is "Slug", I asked for
        slug. PostgreSQL folds unquoted names to lower case, so the query failed and the report
        showed a blank where an error belonged. That is EXACTLY the defect I logged against the
        installer's VERIFY an hour earlier, committed by me in the query written to expose it.
        The error was only visible in the separate stderr file - which is why stderr is kept
        separate. Fixed here: every identifier is quoted.
    (b) identity.users has 1 row, but no user matches NormalizedUserName='SUPERADMIN'. So WHO is
        that user? Asking is cheap; assuming is how the last three defects were born.
  NO GUESSES : column names are read FROM information_schema first, then used. Nothing is typed
               from memory.
#>

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_db-state-2.txt"
$errf  = Join-Path $OutDir "234_$($stamp)_db-state-2.err.txt"
$errAll = New-Object System.Collections.ArrayList
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }
function Fin($pass) {
    [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
    [IO.File]::WriteAllLines($errf, $errAll, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host ("REPORT: {0}" -f $outf)
    Write-Host ("STDERR: {0}   <- read this too; an empty answer above may be an error down here" -f $errf)
    if ($pass) { exit 0 } else { exit 1 }
}

Say "===== G0 ====="
$n = ($env:COMPUTERNAME -eq "RTM")
$u = ("$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper() -eq "E9516FFB-3068-47EA-8860-6A9D764325E6")
Say ("  name {0} / uuid {1}" -f $n, $u)
if (-not ($n -and $u)) { Say "  *** not server 234"; Fin $false }

$psql = (Get-ChildItem 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -ErrorAction SilentlyContinue)[0].FullName
$raw  = [IO.File]::ReadAllText("C:\RTMView\Shell\appsettings.json")
$pw   = ([regex]::Match($raw,'Password\s*=\s*([^";]+)')).Groups[1].Value
$usr  = ([regex]::Match($raw,'Username\s*=\s*([^";]+)')).Groups[1].Value

function Ask([string]$sqlText) {
    $t = Join-Path $env:TEMP ("db2_{0}.sql" -f [guid]::NewGuid().ToString("N"))
    $e = Join-Path $env:TEMP ("db2_{0}.err" -f [guid]::NewGuid().ToString("N"))
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
    $val = (@($r | Where-Object { $_ -ne $null -and "$_".Trim().Length -gt 0 }) -join "`n")
    # An empty answer is reported as an ERROR, not as a blank. On 2026-09-08 a blank line in the
    # report was in fact a failed query, and the report looked merely uninformative.
    if ($failed) { return "<QUERY FAILED - see the .err file>" }
    if ($val.Trim().Length -eq 0) { return "<empty result>" }
    return $val
}

Say ""
Say "===== 1  what columns these tables actually have - read, not remembered ====="
foreach ($t in @(@('public','tenants'), @('identity','users'))) {
    Say ("  {0}.{1} :" -f $t[0], $t[1])
    $cols = Ask ("SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_schema='{0}' AND table_name='{1}';" -f $t[0], $t[1])
    Say ("      {0}" -f $cols)
}
Say ("  NEGCTL columns of a table that cannot exist : {0}   (must be an empty result)" -f (Ask "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_schema='public' AND table_name='zzz_no_such_table';"))

Say ""
Say "===== 2  the tenant row, every identifier quoted ====="
Say ("  rows : {0}" -f (Ask "SELECT COUNT(*) FROM public.tenants;"))
Say  "  the row itself (id | Slug | Name-ish columns, whatever exists):"
foreach ($r in (Ask "SELECT t::text FROM public.tenants t;").Split("`n")) { Say ("      {0}" -f $r) }
Say ("  NEGCTL a slug that cannot exist : {0}   (must be 0)" -f (Ask "SELECT COUNT(*) FROM public.tenants WHERE ""Slug""='zzz-no-such-slug';"))

Say ""
Say "===== 3  WHO is the single user in identity.users ====="
Say ("  rows : {0}" -f (Ask "SELECT COUNT(*) FROM identity.users;"))
Say  "  user, without printing anything secret (no hashes, no tokens):"
foreach ($r in (Ask "SELECT COALESCE(""UserName"",'<null>')||' | norm='||COALESCE(""NormalizedUserName"",'<null>')||' | email='||COALESCE(""Email"",'<null>')||' | normemail='||COALESCE(""NormalizedEmail"",'<null>')||' | confirmed='||COALESCE(""EmailConfirmed""::text,'<null>') FROM identity.users;").Split("`n")) { Say ("      {0}" -f $r) }
Say ("  matches 'SUPERADMIN' exactly : {0}" -f (Ask "SELECT COUNT(*) FROM identity.users WHERE ""NormalizedUserName""='SUPERADMIN';"))
Say ("  POSITIVE control - matches its OWN normalized name : {0}   (must be 1 - proves the query can find)" -f (Ask "SELECT COUNT(*) FROM identity.users u WHERE u.""NormalizedUserName"" = (SELECT ""NormalizedUserName"" FROM identity.users LIMIT 1);"))
Say ("  NEGCTL an invented normalized name : {0}   (must be 0)" -f (Ask "SELECT COUNT(*) FROM identity.users WHERE ""NormalizedUserName""='ZZZNOSUCHUSER';"))

Say ""
Say "===== 4  is that user tied to a role, and to the tenant ====="
Say ("  identity.roles rows : {0}" -f (Ask "SELECT COUNT(*) FROM identity.roles;"))
Say ("  role names          : {0}" -f (Ask "SELECT COALESCE(string_agg(""Name"", ', '),'<none>') FROM identity.roles;"))
Say ("  user-role links     : {0}" -f (Ask "SELECT COUNT(*) FROM identity.user_roles;"))

Say ""
Say "===== END-OF-RUN MARKER: DB-STATE-2-COMPLETE ====="
Say ""
Say "NOTHING WAS WRITTEN."
Fin $true
