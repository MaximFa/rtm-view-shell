#Requires -Version 5.1
<#
  BOX 234 / sequence resync
  WHERE IT RUNS : server 234. Database rtmviewdb on port 5433.
  WHAT IT WRITES: sequence counters ONLY - setval on the sequences of this database.
                  No row of data is inserted, updated or deleted. No service is touched.
                  No file outside C:\RTMView-Ops\output is written.

  WHY: the installer's step 7 selects sequences by pg_depend.deptype='a' (the old serial link).
  Measured on this machine: 0 sequences match that, and 16 are linked as 'i' (IDENTITY). So the
  loop made no iteration at all and still printed "Sequences resynced." The counters were left
  where the seed found them, and the next insert collides with a row the seed already wrote.

  THE GATE OF THIS BOX IS THE ITERATION COUNT. A resync that reports success while doing nothing
  is exactly the defect being repaired, so this run prints how many sequences it actually touched
  and refuses to call itself done unless that number is greater than zero.
  psql runs with -v ON_ERROR_STOP=1: without it psql returns 0 even when a statement failed, and
  the exit code is not a gate at all.
#>

$ErrorActionPreference = "Continue"
$OutDir = "C:\RTMView-Ops\output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "234_$($stamp)_seq-resync.txt"
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
$script:psql = $null; $script:pw = ""; $script:usr = ""; $script:db = ""; $script:port = ""
function RunSql($label, $sqlText) {
    $f = Join-Path $env:TEMP ("sq_{0}_{1}.sql" -f $label, $stamp)
    [IO.File]::WriteAllText($f, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $script:pw
    $rows = & $script:psql -h 127.0.0.1 -p $script:port -U $script:usr -d $script:db -v ON_ERROR_STOP=1 -At -f $f 2>&1
    $rc = $LASTEXITCODE
    $env:PGPASSWORD = ""
    Remove-Item $f -ErrorAction SilentlyContinue
    foreach ($r in $rows) { Say ("      {0}" -f $r) }
    Say ("  [{0}] psql exit code : {1}   (ON_ERROR_STOP is set, so this IS a gate)" -f $label, $rc)
    return $rc
}

Say "===== G0  machine identity ====="
$nameOk = ($env:COMPUTERNAME -eq "RTM")
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
Say ("  name match {0} / uuid match {1}" -f $nameOk, ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))
if (-not ($nameOk -and ($uuid -eq "E9516FFB-3068-47EA-8860-6A9D764325E6"))) { Say "  *** NOT 234"; Fin $false }
Say ("  time now : {0}" -f (Get-Date))
Say "  G0 PASS"
Say ""

Say "===== G1  the database handle, and the tool proves it can fail ====="
$js = Get-Content 'C:\RTMView\Shell\appsettings.json' -Raw | ConvertFrom-Json
$cs = "$($js.ConnectionStrings.Default)"
$script:usr = "ccdashboard_user"; $script:db = "rtmviewdb"; $script:port = "5433"
$m = [regex]::Match($cs, "(?i)Password\s*=\s*([^;]+)"); if ($m.Success) { $script:pw = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Username\s*=\s*([^;]+)"); if ($m.Success) { $script:usr = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Database\s*=\s*([^;]+)"); if ($m.Success) { $script:db  = $m.Groups[1].Value.Trim() }
$m = [regex]::Match($cs, "(?i)Port\s*=\s*(\d+)");       if ($m.Success) { $script:port = $m.Groups[1].Value }
foreach ($pg in @(Get-ChildItem "C:\Program Files\PostgreSQL" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $c = Join-Path $pg.FullName "bin\psql.exe"; if ((Test-Path $c) -and ($null -eq $script:psql)) { $script:psql = $c }
}
Say ("  psql {0} , user {1} , db {2} , port {3} , password {4} chars" -f $(if ($script:psql) { "found" } else { "NOT FOUND" }), $script:usr, $script:db, $script:port, $script:pw.Length)
if ($null -eq $script:psql -or -not $script:pw) { Say "  *** cannot reach the database"; Fin $false }
Say "  NEGATIVE control - a deliberately broken statement MUST make psql exit non-zero:"
$negRc = RunSql "negctl" "SELECT * FROM zzz_this_table_cannot_exist;"
if ($negRc -eq 0) { Say "  *** psql returned 0 on a broken statement - the gate does not work. Refusing to write anything."; Fin $false }
Say "  the tool can fail. Its zero now means something."
Say ""

$reportSql = @'
SELECT 'whoami: db=' || current_database() || ' port=' || inet_server_port() || ' user=' || current_user;
DO $$
DECLARE r record; v bigint; n int := 0;
BEGIN
  FOR r IN
    SELECT n2.nspname AS sch, s.relname AS seq, t.relname AS tbl, a.attname AS col,
           quote_ident(n2.nspname) || '.' || quote_ident(s.relname) AS seqfqn
    FROM pg_class s
    JOIN pg_depend d ON d.objid = s.oid AND d.deptype IN ('a','i')
    JOIN pg_class t ON t.oid = d.refobjid
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
    JOIN pg_namespace n2 ON n2.oid = t.relnamespace
    WHERE s.relkind = 'S' AND n2.nspname IN ('public','identity','audit')
    ORDER BY n2.nspname, t.relname
  LOOP
    EXECUTE format('SELECT COALESCE(MAX(%I),0) FROM %I.%I', r.col, r.sch, r.tbl) INTO v;
    n := n + 1;
    RAISE NOTICE 'SEQ % -> %.%(%)  last_value=%  max=%',
      r.seqfqn, r.sch, r.tbl, r.col,
      (SELECT last_value FROM pg_sequences WHERE schemaname = r.sch AND sequencename = r.seq),
      v;
  END LOOP;
  RAISE NOTICE 'SEQUENCES SEEN = %', n;
END $$;
'@

Say "===== 1  BEFORE - every sequence, its table, its counter and the data's max ====="
$rc1 = RunSql "before" $reportSql
if ($rc1 -ne 0) { Say "  *** the before-measurement failed - writing nothing"; Fin $false }
Say ""

Say "===== 2  THE RESYNC - and it must say HOW MANY it touched ====="
$resyncSql = @'
DO $$
DECLARE r record; v bigint; n int := 0;
BEGIN
  FOR r IN
    SELECT n2.nspname AS sch, s.relname AS seq, t.relname AS tbl, a.attname AS col,
           quote_ident(n2.nspname) || '.' || quote_ident(s.relname) AS seqfqn
    FROM pg_class s
    JOIN pg_depend d ON d.objid = s.oid AND d.deptype IN ('a','i')
    JOIN pg_class t ON t.oid = d.refobjid
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
    JOIN pg_namespace n2 ON n2.oid = t.relnamespace
    WHERE s.relkind = 'S' AND n2.nspname IN ('public','identity','audit')
    ORDER BY n2.nspname, t.relname
  LOOP
    EXECUTE format('SELECT COALESCE(MAX(%I),0) FROM %I.%I', r.col, r.sch, r.tbl) INTO v;
    PERFORM setval(r.seqfqn, GREATEST(v, 1), v > 0);
    n := n + 1;
    RAISE NOTICE 'RESYNCED % -> max=% (is_called=%)', r.seqfqn, v, (v > 0);
  END LOOP;
  RAISE NOTICE 'ITERATIONS = %', n;
  IF n = 0 THEN
    RAISE EXCEPTION 'ZERO ITERATIONS - this is the very defect being repaired, refusing to report success';
  END IF;
END $$;
'@
$rc2 = RunSql "resync" $resyncSql
if ($rc2 -ne 0) { Say "  *** the resync failed or touched nothing"; Fin $false }
Say ""

Say "===== 3  AFTER - the same report, and then the verdict per table ====="
$rc3 = RunSql "after" $reportSql
if ($rc3 -ne 0) { Say "  *** the after-measurement failed"; Fin $false }
Say ""

Say "===== 4  THE PREDICATE, stated by the coordinator before the run ====="
Say "  for every table that has rows: last_value >= max(id). Otherwise the repair did not take."
$verdictSql = @'
DO $$
DECLARE r record; v bigint; lv bigint; bad int := 0; tot int := 0;
BEGIN
  FOR r IN
    SELECT n2.nspname AS sch, s.relname AS seq, t.relname AS tbl, a.attname AS col
    FROM pg_class s
    JOIN pg_depend d ON d.objid = s.oid AND d.deptype IN ('a','i')
    JOIN pg_class t ON t.oid = d.refobjid
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
    JOIN pg_namespace n2 ON n2.oid = t.relnamespace
    WHERE s.relkind = 'S' AND n2.nspname IN ('public','identity','audit')
    ORDER BY n2.nspname, t.relname
  LOOP
    EXECUTE format('SELECT COALESCE(MAX(%I),0) FROM %I.%I', r.col, r.sch, r.tbl) INTO v;
    SELECT last_value INTO lv FROM pg_sequences WHERE schemaname = r.sch AND sequencename = r.seq;
    tot := tot + 1;
    IF v > 0 AND lv < v THEN
      bad := bad + 1;
      RAISE NOTICE 'FAIL %.% : last_value=% < max=%', r.sch, r.tbl, lv, v;
    ELSE
      RAISE NOTICE 'ok   %.% : last_value=% , max=%', r.sch, r.tbl, lv, v;
    END IF;
  END LOOP;
  RAISE NOTICE 'CHECKED = % , FAILING = %', tot, bad;
  IF bad > 0 THEN
    RAISE EXCEPTION 'the predicate does not hold for % of % sequences', bad, tot;
  END IF;
END $$;
'@
$rc4 = RunSql "verdict" $verdictSql
Say ""

Say "===== 5  the four tables of PR234-QGRID-79, spelled out ====="
$rc5 = RunSql "qgrid" @'
SELECT 'RTSGrid_Column  last_value=' || (SELECT last_value FROM pg_sequences WHERE sequencename='RTSGrid_Column_ColumnId_seq')::text
    || '  max=' || COALESCE(MAX("ColumnId"),0)::text FROM "RTSGrid_Column";
SELECT 'RTSGrid_Row     last_value=' || (SELECT last_value FROM pg_sequences WHERE sequencename='RTSGrid_Row_RowId_seq')::text
    || '  max=' || COALESCE(MAX("RowId"),0)::text FROM "RTSGrid_Row";
SELECT 'RTSGrid_Cell    last_value=' || (SELECT last_value FROM pg_sequences WHERE sequencename='RTSGrid_Cell_CellId_seq')::text
    || '  max=' || COALESCE(MAX("CellId"),0)::text FROM "RTSGrid_Cell";
SELECT 'RTSGrid_Grid    last_value=' || (SELECT last_value FROM pg_sequences WHERE sequencename='RTSGrid_Grid_GridId_seq')::text
    || '  max=' || COALESCE(MAX("GridId"),0)::text FROM "RTSGrid_Grid";
SELECT 'data untouched: Metric=' || (SELECT count(*)::text FROM "RTSGrid_Metric")
    || ' Translation=' || (SELECT count(*)::text FROM "RTSGrid_MetricTranslation")
    || ' Site=' || (SELECT count(*)::text FROM "NGC_Site")
    || ' BU=' || (SELECT count(*)::text FROM "NGC_BusinessUnit");
'@
Say ""

Say "===== SUMMARY ====="
Say ("  before rc {0} , resync rc {1} , after rc {2} , verdict rc {3} , qgrid rc {4}" -f $rc1, $rc2, $rc3, $rc4, $rc5)
Say "  Only sequence counters were written. No data row was inserted, updated or deleted."
Say "  Next step is the operator's: save a Queue Grid again. That is the check by deed."
Say ("  collector still intact : {0}" -f $ProbeLines.GetType().Name)
Say "===== END-OF-RUN MARKER: SEQ-RESYNC-COMPLETE ====="
Fin (($rc1 -eq 0) -and ($rc2 -eq 0) -and ($rc3 -eq 0) -and ($rc4 -eq 0) -and ($rc5 -eq 0))
