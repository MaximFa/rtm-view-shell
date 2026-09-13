#Requires -Version 5.1
<#
  PROBE 234 / sequences   -   READ ONLY. SELECT only. Nothing is reset, nothing is fixed.
  WHERE IT RUNS : server 234. Database rtmviewdb on port 5433.
  QUESTION      : PR234-QGRID-79 - saving a Queue Grid fails with 23505 on PK_RTSGrid_Column.
                  backend-0906 diagnoses a sequence left behind by the seed.

  THE PREDICATE WAS FIXED BEFORE THIS RUN, by the coordinator, and is copied here verbatim:
      if the diagnosis is right, last_value is NOTICEABLY LESS than max(ColumnId).
      greater or equal -> the diagnosis is wrong, backend re-opens it. Nothing gets adjusted
      after the fact.

  It also asks the machine WHY, rather than taking it from my reading of the code: the resync in
  Provision-FreshDb.ps1 step 7 selects sequences by pg_depend.deptype='a' (the old serial link),
  while these columns are GENERATED ALWAYS AS IDENTITY, whose link is 'i'. If the machine shows
  'i' here, the step iterated over nothing and still printed "Sequences resynced".
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_sequences.txt"
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

Say "===== G0  machine identity ====="
$nameOk = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ("  name match {0} / uuid match {1}" -f $nameOk, ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))
if (-not ($nameOk -and ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))) { Say "  *** NOT 234"; Fin $false }
Say ("  time now : {0}" -f (Get-Date))
Say "  G0 PASS"
Say ""

Say "===== 1  the database handle ====="
$js = Get-Content 'C:\RTMView\Shell\appsettings.json' -Raw | ConvertFrom-Json
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
Say ("  psql {0} , user {1} , db {2} , port {3} , password {4} chars" -f $(if ($psql) { "found" } else { "NOT FOUND" }), $usr, $db, $port, $pw.Length)
if ($null -eq $psql -or -not $pw) { Say "  *** cannot reach the database - this run measures nothing"; Fin $false }
Say ""

Say "===== 2  the measurement ====="
Say "  predicate, fixed before the run: last_value NOTICEABLY LESS than max -> diagnosis holds"
Say "                                   last_value >= max                   -> diagnosis wrong"
$sqlf = Join-Path $env:TEMP ("seq_{0}.sql" -f $stamp)
$sql = @'
SELECT 'whoami: db=' || current_database() || ' port=' || inet_server_port() || ' user=' || current_user;
SELECT '--- sequences: last_value / is_called ---';
SELECT 'RTSGrid_Column_ColumnId_seq  last_value=' || last_value::text || ' is_called=' || is_called::text FROM "RTSGrid_Column_ColumnId_seq";
SELECT 'RTSGrid_Row_RowId_seq        last_value=' || last_value::text || ' is_called=' || is_called::text FROM "RTSGrid_Row_RowId_seq";
SELECT 'RTSGrid_Cell_CellId_seq      last_value=' || last_value::text || ' is_called=' || is_called::text FROM "RTSGrid_Cell_CellId_seq";
SELECT 'RTSGrid_Grid_GridId_seq      last_value=' || last_value::text || ' is_called=' || is_called::text FROM "RTSGrid_Grid_GridId_seq";
SELECT '--- the tables: max(id) and row count ---';
SELECT 'RTSGrid_Column  max=' || COALESCE(MAX("ColumnId"),0)::text || ' rows=' || count(*)::text FROM "RTSGrid_Column";
SELECT 'RTSGrid_Row     max=' || COALESCE(MAX("RowId"),0)::text    || ' rows=' || count(*)::text FROM "RTSGrid_Row";
SELECT 'RTSGrid_Cell    max=' || COALESCE(MAX("CellId"),0)::text   || ' rows=' || count(*)::text FROM "RTSGrid_Cell";
SELECT 'RTSGrid_Grid    max=' || COALESCE(MAX("GridId"),0)::text   || ' rows=' || count(*)::text FROM "RTSGrid_Grid";
SELECT '--- the verdict, computed BY THE SERVER, not by me ---';
SELECT 'VERDICT RTSGrid_Column: last_value=' || s.last_value::text || ' vs max=' || COALESCE(MAX(c."ColumnId"),0)::text ||
       ' -> ' || CASE WHEN s.last_value < COALESCE(MAX(c."ColumnId"),0) THEN 'LESS (diagnosis holds)' ELSE 'NOT less (diagnosis fails)' END
  FROM "RTSGrid_Column_ColumnId_seq" s, "RTSGrid_Column" c GROUP BY s.last_value;
SELECT '--- WHY: how each sequence is linked to its table (deptype) ---';
SELECT 'link ' || s.relname || ' -> ' || t.relname || '.' || a.attname || '  deptype=' || d.deptype ||
       CASE WHEN d.deptype='i' THEN '  (IDENTITY - the resync filter deptype=a does NOT see this)'
            WHEN d.deptype='a' THEN '  (serial - the resync filter WOULD see this)'
            ELSE '' END
  FROM pg_class s
  JOIN pg_depend d ON d.objid=s.oid
  JOIN pg_class t ON t.oid=d.refobjid
  JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=d.refobjsubid
 WHERE s.relkind='S' AND s.relname LIKE 'RTSGrid%'
 ORDER BY s.relname;
SELECT '--- POSITIVE control: how many sequences in this DB the resync filter WOULD match ---';
SELECT 'sequences with deptype=a in public/identity/audit = ' || count(*)::text
  FROM pg_class s JOIN pg_depend d ON d.objid=s.oid AND d.deptype='a'
  JOIN pg_class t ON t.oid=d.refobjid JOIN pg_namespace n ON n.oid=t.relnamespace
 WHERE s.relkind='S' AND n.nspname IN ('public','identity','audit');
SELECT 'sequences with deptype=i in public/identity/audit = ' || count(*)::text
  FROM pg_class s JOIN pg_depend d ON d.objid=s.oid AND d.deptype='i'
  JOIN pg_class t ON t.oid=d.refobjid JOIN pg_namespace n ON n.oid=t.relnamespace
 WHERE s.relkind='S' AND n.nspname IN ('public','identity','audit');
SELECT '--- NEGATIVE control ---';
SELECT 'NEGCTL sequences named zzz_no_such = ' || count(*)::text FROM pg_class WHERE relkind='S' AND relname='zzz_no_such_seq';
'@
[IO.File]::WriteAllText($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))
$env:PGPASSWORD = $pw
$rows = & $psql -h 127.0.0.1 -p $port -U $usr -d $db -At -f $sqlf 2>&1
$rc = $LASTEXITCODE
$env:PGPASSWORD = ""
Remove-Item $sqlf -ErrorAction SilentlyContinue
foreach ($r in $rows) { Say ("      {0}" -f $r) }
Say ("  psql exit code : {0}   (non-zero means this run measured less than it claims)" -f $rc)
Say ""

Say "===== 3  what the install log said about this very step ====="
$logs = @(Get-ChildItem "C:\RTMView-Ops\output" -File -Filter "*install-console*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
if ($logs.Count -eq 0) { Say "  no install console log kept here - skipping (and saying so, rather than staying silent)" }
else {
    Say ("  {0}" -f $logs[0].FullName)
    $hits = @(Select-String -Path $logs[0].FullName -Pattern "sequence","Sequences","resync","grants" -ErrorAction SilentlyContinue)
    Say ("  lines about sequences/grants : {0}" -f $hits.Count)
    foreach ($h in $hits) { Say ("      {0}" -f $h.Line) }
    $pos = @(Select-String -Path $logs[0].FullName -Pattern "7/7" -SimpleMatch -ErrorAction SilentlyContinue)
    Say ("  POSITIVE control - lines mentioning step 7/7 : {0}" -f $pos.Count)
    foreach ($h in $pos) { Say ("      {0}" -f $h.Line) }
}
Say ""

Say "===== SUMMARY ====="
Say "  Read only. No sequence was reset, no row was written, nothing was repaired."
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "===== END-OF-RUN MARKER: SEQUENCES-COMPLETE ====="
Fin $true
