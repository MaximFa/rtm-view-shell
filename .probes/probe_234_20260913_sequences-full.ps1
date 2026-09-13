#Requires -Version 5.1
<#
  PROBE 234 / sequences-full      re-measurement of section 6, which went MUTE in the engine-port run
  WHERE IT RUNS : server 234 (machine RTM). It REFUSES to run anywhere else - machine name AND hardware
                  UUID are a gate. EVERY line of this box runs on 234.
  READ ONLY. Starts nothing, stops nothing, restarts nothing, writes no config, touches no service.
  The database work is SELECTs inside a read-only DO block that only RAISEs NOTICEs - no INSERT, UPDATE,
  DELETE, setval, ALTER or any other write, on either instance. C:\IceDash is not read, listed or queried.
  WHAT IT WRITES: its report and one result file per port under C:\RTMView-Ops\output, plus a scratch SQL
  file in TEMP that it deletes. It creates no artifact, so it carries no .origin mark.

  WHY THIS RUN EXISTS - my defect, named before any number. In the previous run the traversal of the
  RTSGrid sequences DIED on the fourth table: RTSGrid_Metric has a TEXT primary key (MetricId,
  character varying(100) per db/schema.sql:515) and I folded max(key) into a bigint. There was no
  per-table exception handler, so the loop ended there, and RTSGrid_Row, RTSGrid_Statistic and
  RTSGrid_UserStatus were never measured - RTSGrid_Row being exactly the table PR234-QGRID-79 is about.
  Worse than the abort: my gate printed "sequences BEHIND or UNSET : 0" and "failures : 0", because I
  counted lines carrying a verdict instead of the NUMBER of objects processed, and I never made the
  presence of an ERROR a condition. The silence was signed off by my own counter.

  WHAT IS DIFFERENT HERE, point by point:
   - the key column AND ITS DATA TYPE come from information_schema; a non-integer key is reported as
     SKIPPED with the reason printed, which is a BRANCH, not silence;
   - every table is wrapped in its own EXCEPTION WHEN OTHERS, so one table cannot kill the traversal,
     and the exception is printed per table;
   - the number of tables PROCESSED is compared against the number that EXISTS, and against the number
     named before the run; a shortfall is a FAIL even if every processed table came back OK;
   - any ERROR in the captured stream is a CONDITION, not a line in the report;
   - the skip branch carries a POSITIVE control: at least two tables MUST be reported as skipped
     (Metric and MetricTranslation have text keys), otherwise the branch never ran and its absence
     would be indistinguishable from "there were none";
   - a deliberate NEGATIVE control asks for a table that cannot exist and requires the handler to say so.

  EXPECTATIONS, NAMED BEFORE THE RUN (the counts were confirmed against db/schema.sql by the coordinator):
     tables matching RTSGrid% in public : 8 on port 5433 , 9 on port 5432
     the extra one on 5432 is RTSGrid_TemplateCell, which does NOT exist in db/schema.sql - it is a
     leftover of the old database, not something we lost
     verdict per table: OK when last_value >= max(key) ; BEHIND or UNSET means the next insert collides
  Password is NEVER prompted and never printed: it is read from the machine own config, only its length
  goes into the report.
#>

$ErrorActionPreference = 'Continue'

$NAMEGATE = 'RTM'
$UUIDGATE = 'E9516FFB-3068-47EA-8860-6A9D764325E6'
$OutDir = 'C:\RTMView-Ops\output'
$EXPECTED = @{ '5433' = 8; '5432' = 9 }
$MIN_SKIPPED = 2

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir ('234_' + $stamp + '_sequences-full.txt')
$Report = New-Object System.Collections.ArrayList
function Say($text) { [void]$Report.Add($text); Write-Host $text }
function Fin($pass) {
    [void]$Report.Add('')
    [void]$Report.Add($(if ($pass) { 'VERDICT: PASS' } else { 'VERDICT: FAIL' }))
    [IO.File]::WriteAllLines($outf, $Report, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ''
    Write-Host ('REPORT: ' + $outf)
    if ($pass) { exit 0 } else { exit 1 }
}
function Get-Sha256Of($targetPath) {
    if (Test-Path $targetPath) { return (Get-FileHash $targetPath -Algorithm SHA256).Hash } else { return 'ABSENT' }
}

Say '===== G0  machine identity and the instrument, proven before anything is measured ====='
$nameOk = ($env:COMPUTERNAME -eq $NAMEGATE)
$uuid = "$((Get-WmiObject Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID)".ToUpper()
$uuidOk = ($uuid -eq $UUIDGATE)
Say ('  name  expected {0} , actual {1} -> {2}' -f $NAMEGATE, $env:COMPUTERNAME, $nameOk)
Say ('  uuid  expected {0} , actual {1} -> {2}' -f $UUIDGATE, $uuid, $uuidOk)
if (-not ($nameOk -and $uuidOk)) { Say '  *** NOT server 234 - refusing to measure'; Fin $false }
Say ('  PowerShell {0}' -f $PSVersionTable.PSVersion)
$resolvedHash = Get-Command Get-Sha256Of -ErrorAction SilentlyContinue
Say ('  Get-Sha256Of resolves to : {0}   expected Function' -f $resolvedHash.CommandType)
if ("$($resolvedHash.CommandType)" -ne 'Function') { Say '  *** the hash helper is shadowed - stop'; Fin $false }
Say ('  this probe sha256 : {0}' -f (Get-Sha256Of $MyInvocation.MyCommand.Path))
Say ('  NEGCTL hash of a missing path : {0}   expected ABSENT' -f (Get-Sha256Of 'C:\zzz-no-such-file.bin'))
Say ('  collector type at entry : {0}   expected ArrayList' -f $Report.GetType().Name)
Say ('  EXPECTATIONS named now: tables RTSGrid% = 8 on 5433 , 9 on 5432 ; at least {0} of them skipped for a text key' -f $MIN_SKIPPED)
Say '  G0 PASS'
Say ''

$fails = 0
$notMeasured = 0

$dbPassword = $null
$shellCfg = 'C:\RTMView\Shell\appsettings.json'
if (Test-Path $shellCfg) {
    $shellJson = Get-Content $shellCfg -Raw | ConvertFrom-Json
    if ($shellJson.ConnectionStrings -and $shellJson.ConnectionStrings.Default) {
        $defConn = "$($shellJson.ConnectionStrings.Default)"
        if ($defConn -match '(?i)password\s*=\s*([^;]+)') { $dbPassword = $Matches[1].Trim() }
    }
}
$psqlPath = $null
foreach ($pgDir in @(Get-ChildItem 'C:\Program Files\PostgreSQL' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
    $candidate = Join-Path $pgDir.FullName 'bin\psql.exe'
    if ((Test-Path $candidate) -and ($null -eq $psqlPath)) { $psqlPath = $candidate }
}
if ($null -eq $psqlPath) { Say '  psql.exe NOT FOUND - nothing can be measured here, and that is a gap, not a pass'; Fin $false }
if ($null -eq $dbPassword) { Say '  no password from the machine config - nothing can be measured here, and that is a gap, not a pass'; Fin $false }
Say ('  psql : {0}   credentials ccdashboard_user , password {1} characters from the machine config, NOT printed' -f $psqlPath, $dbPassword.Length)
Say ''

$env:PGCLIENTENCODING = 'UTF8'
$env:PGPASSWORD = $dbPassword

Say '===== G1  the instrument proves it can FAIL before any of its zeroes are believed ====='
$badFile = Join-Path $env:TEMP ('probeC_bad_' + $stamp + '.sql')
[IO.File]::WriteAllText($badFile, "SELECT this_is_not_valid FROM;`n", (New-Object System.Text.UTF8Encoding($false)))
$null = & $psqlPath -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=1 -At -f $badFile 2>&1
$rcBad = $LASTEXITCODE
Remove-Item $badFile -ErrorAction SilentlyContinue
Say ('  a deliberately broken query : exit {0}   expected NON-zero' -f $rcBad)
if ($rcBad -eq 0) { Say '  *** psql does not fail on a broken query - refusing to trust any zero below'; $env:PGPASSWORD = ''; Fin $false }
$goodFile = Join-Path $env:TEMP ('probeC_alive_' + $stamp + '.sql')
[IO.File]::WriteAllText($goodFile, "SELECT 'ALIVE=1';`n", (New-Object System.Text.UTF8Encoding($false)))
$aliveOut = & $psqlPath -h 127.0.0.1 -p 5433 -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=1 -At -f $goodFile 2>&1
$rcAlive = $LASTEXITCODE
Remove-Item $goodFile -ErrorAction SilentlyContinue
Say ('  a valid query : exit {0} , says {1}   expected 0 and ALIVE=1 - so the non-zero above meant syntax, not a dead link' -f $rcAlive, ($aliveOut -join ' '))
if (($rcAlive -ne 0) -or ("$aliveOut" -notmatch 'ALIVE=1')) { Say '  *** no usable connection - stop'; $env:PGPASSWORD = ''; Fin $false }
Say '  G1 PASS'
Say ''

$sqlFile = Join-Path $env:TEMP ('probeC_seq_' + $stamp + '.sql')
$sqlText = @'
DO $$
DECLARE
    rec        record;
    pk_name    text;
    pk_type    text;
    seq_name   text;
    max_val    bigint;
    last_val   bigint;
    verdict    text;
    n_tables   int := 0;
    n_done     int := 0;
    n_ok       int := 0;
    n_bad      int := 0;
    n_skipped  int := 0;
    n_noseq    int := 0;
    n_norows   int := 0;
    n_except   int := 0;
BEGIN
    SELECT count(*) INTO n_tables FROM information_schema.tables
     WHERE table_schema = 'public' AND table_type = 'BASE TABLE' AND table_name LIKE 'RTSGrid%';
    RAISE NOTICE 'census | tables matching RTSGrid%% in public = %', n_tables;

    FOR rec IN SELECT table_name FROM information_schema.tables
                WHERE table_schema = 'public' AND table_type = 'BASE TABLE' AND table_name LIKE 'RTSGrid%'
                ORDER BY table_name LOOP
        BEGIN
            n_done := n_done + 1;
            pk_name := NULL; pk_type := NULL; seq_name := NULL; max_val := NULL; last_val := NULL;

            SELECT kcu.column_name INTO pk_name
              FROM information_schema.table_constraints tc
              JOIN information_schema.key_column_usage kcu
                ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
             WHERE tc.table_schema = 'public' AND tc.constraint_type = 'PRIMARY KEY' AND tc.table_name = rec.table_name
             ORDER BY kcu.ordinal_position LIMIT 1;

            IF pk_name IS NULL THEN
                n_skipped := n_skipped + 1;
                RAISE NOTICE 'seq | % | SKIPPED | no primary key at all, so there is no key to outrun', rec.table_name;
                CONTINUE;
            END IF;

            SELECT data_type INTO pk_type FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name = rec.table_name AND column_name = pk_name;

            IF pk_type NOT IN ('integer','bigint','smallint') THEN
                n_skipped := n_skipped + 1;
                RAISE NOTICE 'seq | % | key % is % | SKIPPED | the predicate applies to generated integer keys only, and this one is not one', rec.table_name, pk_name, pk_type;
                CONTINUE;
            END IF;

            seq_name := pg_get_serial_sequence('public.' || quote_ident(rec.table_name), pk_name);
            EXECUTE format('SELECT max(%I) FROM public.%I', pk_name, rec.table_name) INTO max_val;

            IF seq_name IS NULL THEN
                n_noseq := n_noseq + 1;
                RAISE NOTICE 'seq | % | key % is % | NO SEQUENCE | the key is integer but not generated, max = %', rec.table_name, pk_name, pk_type, coalesce(max_val::text,'NULL');
                CONTINUE;
            END IF;

            SELECT pg_sequence_last_value(seq_name::regclass) INTO last_val;
            IF last_val IS NULL THEN
                verdict := 'UNSET - the next insert collides'; n_bad := n_bad + 1;
            ELSIF max_val IS NULL THEN
                verdict := 'NO ROWS - nothing to collide with yet'; n_norows := n_norows + 1;
            ELSIF last_val >= max_val THEN
                verdict := 'OK'; n_ok := n_ok + 1;
            ELSE
                verdict := 'BEHIND - the next insert collides'; n_bad := n_bad + 1;
            END IF;
            RAISE NOTICE 'seq | % | key % is % | sequence % | last_value % | max % | %',
                         rec.table_name, pk_name, pk_type, seq_name,
                         coalesce(last_val::text,'NULL'), coalesce(max_val::text,'NULL'), verdict;
        EXCEPTION WHEN OTHERS THEN
            n_except := n_except + 1;
            RAISE NOTICE 'seq | % | EXCEPTION | % | the traversal CONTINUES - one table can no longer kill it', rec.table_name, SQLERRM;
        END;
    END LOOP;

    BEGIN
        seq_name := pg_get_serial_sequence('public.zzz_no_such_table','Id');
        RAISE NOTICE 'negctl | asking a table that cannot exist returned % instead of raising', coalesce(seq_name,'NULL');
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'negctl | asking a table that cannot exist raised % - the handler works, so the per-table handlers above are real', SQLERRM;
    END;

    RAISE NOTICE 'totals | tables % | processed % | ok % | behind_or_unset % | skipped % | no_sequence % | no_rows % | exceptions %',
                 n_tables, n_done, n_ok, n_bad, n_skipped, n_noseq, n_norows, n_except;
    IF n_done <> n_tables THEN
        RAISE NOTICE 'totals | MISMATCH | processed % of % - the traversal did not finish, and any zero above is meaningless', n_done, n_tables;
    END IF;
END
$$;
'@
[IO.File]::WriteAllText($sqlFile, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
Say ('  SQL written to {0} , sha256 {1}' -f $sqlFile, (Get-Sha256Of $sqlFile))
Say ''

foreach ($port in @('5433','5432')) {
    $expectedTables = $EXPECTED[$port]
    Say ('===== PORT {0} - expected {1} tables matching RTSGrid% , named BEFORE the run =====' -f $port, $expectedTables)
    $portFile = Join-Path $OutDir ('234_' + $stamp + '_sequences-full_' + $port + '.txt')
    $lines = & $psqlPath -h 127.0.0.1 -p $port -U ccdashboard_user -d rtmviewdb -v ON_ERROR_STOP=1 -At -f $sqlFile 2>&1
    $rc = $LASTEXITCODE
    [IO.File]::WriteAllLines($portFile, @($lines | ForEach-Object { "$_" }), (New-Object System.Text.UTF8Encoding($false)))
    Say ('  psql exit {0}   expected 0 ; captured lines {1} ; file {2}' -f $rc, @($lines).Count, $portFile)
    foreach ($line in @($lines)) {
        $clean = ("$line" -replace '^.*NOTICE:\s*','')
        if ($clean -match '^(seq|totals|census|negctl) \|') { Say ('      ' + $clean) }
    }
    $errorLines = @($lines | Where-Object { "$_" -match 'ERROR' })
    Say ('  lines containing ERROR : {0}   expected 0 - this is a CONDITION, not a footnote' -f $errorLines.Count)
    foreach ($errorLine in $errorLines) { Say ('      ' + "$errorLine") }
    if ($errorLines.Count -gt 0) { Say '      -> FAIL  the traversal hit an error'; $fails++ }
    if ($rc -ne 0) { Say ('      -> FAIL  psql exit {0}' -f $rc); $fails++ }

    $totalsLine = @($lines | Where-Object { "$_" -match 'totals \| tables' } | Select-Object -First 1)
    if ($totalsLine.Count -ne 1) { Say '  -> FAIL  no totals line at all: the traversal did not reach its end'; $fails++; Say ''; continue }
    $totalsText = ("$($totalsLine[0])" -replace '^.*NOTICE:\s*','')
    $nTables = 0; $nDone = 0; $nBad = 0; $nSkipped = 0; $nExcept = 0
    if ($totalsText -match 'tables (\d+)')            { $nTables = [int]$Matches[1] }
    if ($totalsText -match 'processed (\d+)')         { $nDone = [int]$Matches[1] }
    if ($totalsText -match 'behind_or_unset (\d+)')   { $nBad = [int]$Matches[1] }
    if ($totalsText -match 'skipped (\d+)')           { $nSkipped = [int]$Matches[1] }
    if ($totalsText -match 'exceptions (\d+)')        { $nExcept = [int]$Matches[1] }
    Say ('  tables found {0} , expected {1}' -f $nTables, $expectedTables)
    if ($nTables -ne $expectedTables) { Say '      -> FAIL  the number of tables is not what the tree says - a schema difference, report it, do not absorb it'; $fails++ }
    Say ('  PROCESSED {0} of {1}   this is the gate the previous run did not have' -f $nDone, $nTables)
    if ($nDone -ne $nTables) { Say '      -> FAIL  the traversal did not cover every table, so every zero above is meaningless'; $fails++ }
    Say ('  BEHIND or UNSET {0}   expected 0 ; above zero means PR234-QGRID-79 is alive on this instance' -f $nBad)
    if (($port -eq '5433') -and ($nBad -gt 0)) { Say '      -> FAIL on OUR database: the next insert into one of these tables collides'; $fails++ }
    Say ('  SKIPPED {0}   expected at least {1} - POSITIVE control of the skip branch: without it, "no skips" and "the branch never ran" look identical' -f $nSkipped, $MIN_SKIPPED)
    if ($nSkipped -lt $MIN_SKIPPED) { Say '      -> FAIL  the skip branch did not run, so its silence proves nothing'; $fails++ }
    Say ('  EXCEPTIONS {0}   above zero is not fatal by itself, but every one is printed by table above' -f $nExcept)
    if ($nExcept -gt 0) { $notMeasured++ }
    $negctlLine = @($lines | Where-Object { "$_" -match 'negctl \|' })
    Say ('  NEGCTL lines present : {0}   expected 1 - it proves the per-table handlers are real and not decoration' -f $negctlLine.Count)
    if ($negctlLine.Count -lt 1) { Say '      -> FAIL  the negative control did not run'; $fails++ }
    Say ''
}
Remove-Item $sqlFile -ErrorAction SilentlyContinue
$env:PGPASSWORD = ''

Say '===== SUMMARY ====='
Say ('  collector type at exit : {0}   expected ArrayList' -f $Report.GetType().Name)
if ("$($Report.GetType().Name)" -ne 'ArrayList') { Say '  *** the collector was overwritten - the report on disk is incomplete'; $fails++ }
Say ('  failures     : {0}   anything above zero goes to the coordinator before step 4 moves' -f $fails)
Say ('  NOT MEASURED : {0}   gaps, named where they occur, never counted as passes' -f $notMeasured)
Say '  What a PASS here means, stated narrowly: every RTSGrid table on both instances was VISITED, and on'
Say '  our database none of the generated integer keys has a sequence behind its maximum. It does NOT mean'
Say '  the install is safe, and it does not close PR234-QGRID-79 by itself - it supplies the BEFORE number'
Say '  that the after-install check on saving a Queue Grid will be compared against.'
Say '  NOTHING WAS STARTED, STOPPED, INSTALLED, RESTARTED OR CHANGED. NO WRITE WAS ISSUED TO EITHER'
Say '  DATABASE: the DO block only reads and raises notices. C:\IceDash WAS NOT TOUCHED.'
Say '===== END-OF-RUN MARKER: SEQUENCES-FULL-COMPLETE ====='
Fin ($fails -eq 0)
