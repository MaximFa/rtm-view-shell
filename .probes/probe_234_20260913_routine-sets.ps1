#Requires -Version 5.1
<#
  PROBE 234 / routine-sets - does the routine drift survive when names are compared WITHOUT signatures?
  WHERE IT RUNS : server 234 (machine RTM). Name and hardware UUID are a gate.
  WHAT IT DOES  : READS. Two SELECTs against rtmviewdb on port 5433, and a regex read of the db/ module
                  that shipped INSIDE the package. It installs nothing, restarts nothing, writes no
                  config, changes no data, and issues no statement other than SELECT. It does not touch
                  C:\IceDash, the production RTM.Twilio service, legacy RTM, PostgreSQL 15 on 5432, or
                  C:\Program Files\CcDashboard. Only writes: its own report and one temporary .sql file.
  THE QUESTION  : the delta report says 46 routines missing and 116 extra, but all ten missing names it
                  showed also appear in its own extra list, differing only in NOTATION - baseline keeps
                  name(types), the server reports name(mode name type). Signatures cannot settle this.
                  NAMES can: B \ S is the real disappearance, S \ B is what truly stands beyond baseline.
  PORT          : 5433 explicitly. The default 5432 is the OLD PostgreSQL 15 on this machine and must
                  never be queried here.
  NEGATIVE HALF : a name that cannot exist is queried too. If it "is found", the instrument lies and the
                  run stops - "all of them found" would otherwise be indistinguishable from
                  "the query always returns a row".
  PASSWORD      : Read-Host -AsSecureString. The value is never printed, never written to the report,
                  and is cleared from the environment at the end.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir   = 'C:\RTMView-Ops\output'
$PKGDB    = 'C:\RTMView-Ops\incoming\step5b_243424e\rtm\db'
$DBPORT   = '5433'
$DBNAME   = 'rtmviewdb'
$DBUSER   = 'ccdashboard_user'
$NEGNAME  = 'NGC_ThisDoesNotExist'
$SENTINEL = -999

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_routine-sets.txt')
$sqlf  = Join-Path $OutDir ('234_' + $stamp + '_routine-sets.sql')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Flush() { [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false))) }
function Fin($pass) {
    if ($env:PGPASSWORD) { $env:PGPASSWORD = '' }
    [void]$Report.Add('')
    [void]$Report.Add('--- end of run ---')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS (instrument sound - read the two set differences above)' }
                       else        { 'VERDICT: FAIL (instrument unsound - the numbers below prove nothing)' }))
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
if ((Safe-Count $null) -ne $SENTINEL) { Say '  *** gate broken'; Fin $false }
Say ('  now : {0}   READ ONLY, SELECT only, port {1}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $DBPORT)

Say ''
Say '===== 1  psql - found, not assumed ====='
$psql = @(Get-ChildItem -Path 'C:\Program Files\PostgreSQL' -Filter 'psql.exe' -Recurse -ErrorAction SilentlyContinue |
          Sort-Object FullName -Descending)
Say ('  psql.exe candidates : {0}' -f (Safe-Count $psql))
foreach ($c in $psql) { Say ('      {0}' -f $c.FullName) }
if ((Safe-Count $psql) -lt 1) { Say '  *** psql not found - stopping'; Fin $false }
$PSQL = $psql[0].FullName
Say ('  using : {0}' -f $PSQL)

Say ''
Say '===== 2  B - the baseline set, read from the db module that SHIPPED IN THE PACKAGE ====='
if (-not (Test-Path -LiteralPath $PKGDB)) { Say ('  *** not found : {0}' -f $PKGDB); Fin $false }
$sqlFiles = @(Get-ChildItem -LiteralPath $PKGDB -Recurse -File -Filter '*.sql' -ErrorAction SilentlyContinue)
Say ('  .sql files under {0} : {1}' -f $PKGDB, (Safe-Count $sqlFiles))
$B = New-Object System.Collections.ArrayList
$rx = [regex]'(?im)^\s*CREATE\s+(?:OR\s+REPLACE\s+)?(?:FUNCTION|PROCEDURE)\s+(?:"?public"?\.)?"?([A-Za-z0-9_]+)"?\s*\('
foreach ($f in $sqlFiles) {
    $text = [IO.File]::ReadAllText($f.FullName)
    foreach ($m in $rx.Matches($text)) {
        $n = $m.Groups[1].Value
        if (-not $B.Contains($n)) { [void]$B.Add($n) }
    }
}
Say ('  |B| unique routine names declared in the package db module : {0}' -f (Safe-Count $B))
if ((Safe-Count $B) -lt 1) { Say '  *** the matcher found nothing - it is the matcher under suspicion, not the tree'; Fin $false }
foreach ($n in @($B | Sort-Object | Select-Object -First 8)) { Say ('      sample : {0}' -f $n) }

Say ''
Say '===== 3  S - the server set, by SELECT on 5433 ====='
$sql = @()
$sql += "\pset format unaligned"
$sql += "\pset tuples_only on"
$sql += "SELECT '@@S@@' || p.proname"
$sql += "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace"
$sql += "WHERE n.nspname NOT IN ('pg_catalog','information_schema')"
$sql += "  AND n.nspname NOT LIKE 'pg_toast%'"
$sql += "ORDER BY 1;"
$sql += "SELECT '@@NEG@@' || count(*)::text"
$sql += "FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace"
$sql += "WHERE n.nspname NOT IN ('pg_catalog','information_schema')"
$sql += "  AND p.proname = '" + $NEGNAME + "';"
[IO.File]::WriteAllLines($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))
Say ('  SQL written to : {0}' -f $sqlf)
Say '  statements: two SELECTs. No INSERT, UPDATE, DELETE, CREATE, ALTER or DROP anywhere in this run.'

$sec = Read-Host ('Password for ' + $DBUSER + ' on port ' + $DBPORT) -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

$raw = & $PSQL -h localhost -p $DBPORT -U $DBUSER -d $DBNAME -f $sqlf 2>&1
$code = $LASTEXITCODE
$env:PGPASSWORD = ''
Say ('  psql exit code : {0}   expected 0' -f $code)
$lines = @("$raw" -split "`r?`n")
$lines = @($raw | ForEach-Object { "$_" })
$S = New-Object System.Collections.ArrayList
$negCount = $SENTINEL
foreach ($l in $lines) {
    $t = "$l".Trim()
    if ($t.StartsWith('@@S@@')) { $v = $t.Substring(5); if (-not $S.Contains($v)) { [void]$S.Add($v) } }
    elseif ($t.StartsWith('@@NEG@@')) { $negCount = [int]$t.Substring(7) }
}
Say ('  |S| unique routine names on the server : {0}' -f (Safe-Count $S))
Say ('  NEGCTL rows for a name that cannot exist ({0}) : {1}   expected 0' -f $NEGNAME, $negCount)
if ($code -ne 0 -or (Safe-Count $S) -lt 1) {
    Say '  *** the query did not answer. Verbatim output follows, because a refusal must show what it tripped on:'
    foreach ($l in @($lines | Select-Object -First 25)) { Say ('      | {0}' -f $l) }
    Fin $false
}
if ($negCount -ne 0) { Say '  *** the instrument finds things that do not exist - every green below would be meaningless'; Fin $false }
Flush

Say ''
Say '===== 4  THE TWO SET DIFFERENCES - this is the whole point ====='
$BminusS = @($B | Where-Object { -not ($S -contains $_) } | Sort-Object)
$SminusB = @($S | Where-Object { -not ($B -contains $_) } | Sort-Object)
Say ('  |B| {0}   |S| {1}' -f (Safe-Count $B), (Safe-Count $S))
Say ''
Say ('  B \ S  - declared in the package, ABSENT on the server : {0}' -f (Safe-Count $BminusS))
Say '  (this, and only this, is a real disappearance)'
foreach ($n in $BminusS) { Say ('      MISSING : {0}' -f $n) }
if ((Safe-Count $BminusS) -eq 0) { Say '      (none)' }
Say ''
Say ('  S \ B  - present on the server, NOT declared in the package : {0}' -f (Safe-Count $SminusB))
foreach ($n in $SminusB) { Say ('      EXTRA   : {0}' -f $n) }
if ((Safe-Count $SminusB) -eq 0) { Say '      (none)' }

Say ''
Say '===== 5  what this settles and what it does not ====='
Say '  Settles: whether any routine NAME the package declares is absent from the live database.'
Say '  Does NOT settle: whether the bodies match, whether argument types match, or whether the baseline'
Say '  itself is current. Names are a floor, not a ceiling - said before the numbers, not after.'
Remove-Item -LiteralPath $sqlf -Force -ErrorAction SilentlyContinue
Fin $true
