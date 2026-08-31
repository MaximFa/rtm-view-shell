#Requires -Version 5.1
<#  REHEARSAL PART B - struct-diff of all 17 tables -> reload by two mechanisms -> drop staging ->
    identity resync (deptype 'a' AND 'i') -> full VERIFY with numbers.
    Authored by devops-0829, 2026-08-29.
#>
$ErrorActionPreference = "Continue"
$pg   = "C:\Program Files\PostgreSQL\18\bin"
$dmp  = "D:\RTMView-Ops\rehearsal\rtmviewdb_20260829_1129.dump"
$db   = "rtmviewdb_reh"
$src  = "rtmviewdb_src"
$expectHash = "EEA7B798F801DB13E887822885235D8FAF500BB16556A837E4681A672679F468"

$h = (Get-FileHash -Algorithm SHA256 $dmp).Hash
if ($h -ne $expectHash) { Write-Host "STOP: dump hash drift" -ForegroundColor Red; exit 1 }
Write-Host ("source pin OK; free space on D: {0:N1} GB" -f ((Get-PSDrive D).Free/1GB)) -ForegroundColor Green

$sec = Read-Host "postgres password" -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
$env:PGPASSWORD = $plain

$tables = @("NGC_Site","NGC_BusinessUnit","NGC_Supergroup","NGC_Queues","NGC_AgentGroups",
 "NGC_BusinessUnitQueueClassification","NGC_BusinessUnitSupergroup","NGC_SupergroupAgentgroup","NGC_UserAgentgroup",
 "RTSGrid_Grid","RTSGrid_Row","RTSGrid_Column","RTSGrid_Cell",
 "RTSUserGrid_Grid","RTSUserGrid_ColumnsSet","RTSUserGrid_Column","RTSData_UserStatusLog")

Write-Host "=== staging restore (same physical file) ===" -ForegroundColor Cyan
& "$pg\dropdb.exe" -U postgres --if-exists $src | Out-Null
& "$pg\createdb.exe" -U postgres -E UTF8 $src
& "$pg\pg_restore.exe" -U postgres -d $src $dmp 2>&1 | Select-String -Pattern "^pg_restore: error" | Select-Object -First 5

$colq = @"
SELECT table_name||'|'||column_name||'|'||data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name IN ('$($tables -join "','")') ORDER BY table_name, ordinal_position;
"@
$cf = Join-Path $env:TEMP "b_cols.sql"
[System.IO.File]::WriteAllText($cf, $colq, (New-Object System.Text.UTF8Encoding($false)))
$sCols = @{}; $dCols = @{}
(& "$pg\psql.exe" -U postgres -d $src -t -A -f $cf) | Where-Object { $_ -match '\|' } | ForEach-Object { $p=$_ -split '\|'; if(-not $sCols[$p[0]]){$sCols[$p[0]]=@()}; $sCols[$p[0]] += "$($p[1]):$($p[2])" }
(& "$pg\psql.exe" -U postgres -d $db  -t -A -f $cf) | Where-Object { $_ -match '\|' } | ForEach-Object { $p=$_ -split '\|'; if(-not $dCols[$p[0]]){$dCols[$p[0]]=@()}; $dCols[$p[0]] += "$($p[1]):$($p[2])" }

Write-Host ""
Write-Host "===== STRUCT-DIFF: all 17 tables, both directions (matches included) =====" -ForegroundColor Yellow
"{0,-36} {1,-28} {2}" -f "TABLE","ONLY IN DUMP","ONLY IN TARGET"
"{0,-36} {1,-28} {2}" -f ("-"*36),("-"*28),("-"*28)
$drift = @()
foreach ($tn in $tables) {
    $os = @($sCols[$tn] | Where-Object { $dCols[$tn] -notcontains $_ })
    $od = @($dCols[$tn] | Where-Object { $sCols[$tn] -notcontains $_ })
    if ($os.Count -or $od.Count) { $drift += $tn }
    $mark = if ($os.Count -or $od.Count) { " <== DRIFT" } else { " (match)" }
    "{0,-36} {1,-28} {2}{3}" -f $tn, ($os -join ","), ($od -join ","), $mark
}
Write-Host ""
# Gate by NAMED APPROVED LIST, not by count (coordinator 2026-08-29)
$approved = @("NGC_Queues","NGC_AgentGroups","RTSData_UserStatusLog")
$newDrift = @($drift | Where-Object { $approved -notcontains $_ })
Write-Host ("drift found : {0}" -f $(if ($drift.Count) { $drift -join ", " } else { "none" }))
Write-Host ("approved    : {0}" -f ($approved -join ", "))
if ($newDrift.Count) {
    Write-Host ("NEW DRIFT (not on the approved list): {0}" -f ($newDrift -join ", ")) -ForegroundColor Red
    Write-Host "STOP - full pass complete; report ALL drift above to the coordinator in ONE message" -ForegroundColor Red
    & "$pg\dropdb.exe" -U postgres --if-exists $src | Out-Null
    $env:PGPASSWORD = ""
    exit 1
}
Write-Host "all drift is on the approved list - proceeding" -ForegroundColor Green
Write-Host ""
Write-Host "===== TYPE-WIDENING: measured MAX() from the dump =====" -ForegroundColor Yellow
$maxq = 'SELECT max("Duration") AS max_duration_in_dump, 2147483647 AS int4_ceiling FROM public."RTSData_UserStatusLog";'
$mf = Join-Path $env:TEMP "b_max.sql"
[System.IO.File]::WriteAllText($mf, $maxq, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d $src -f $mf

Write-Host ""
Write-Host "===== RELOAD =====" -ForegroundColor Yellow
$colList = '"Id","TenantId","ExternalId","Name","IsActive"'
foreach ($tn in $tables) {
    if ($tn -in @("NGC_Queues","NGC_AgentGroups")) {
        # drifted: explicit column list, staging -> target, byte pipe via cmd (no PowerShell re-encoding)
        $o = Join-Path $env:TEMP "b_out_$tn.sql"; $i = Join-Path $env:TEMP "b_in_$tn.sql"
        [System.IO.File]::WriteAllText($o, "\copy (SELECT $colList FROM public.""$tn"") TO STDOUT", (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::WriteAllText($i, "\copy public.""$tn"" ($colList) FROM STDIN", (New-Object System.Text.UTF8Encoding($false)))
        $cmd = "`"$pg\psql.exe`" -U postgres -d $src -f `"$o`" | `"$pg\psql.exe`" -U postgres -d $db -f `"$i`""
        $out = cmd /c $cmd 2>&1
        $bad = $out | Select-String -Pattern "ERROR|FATAL"
        if ($bad) { Write-Host ("  {0,-40} FAILED (column-list copy)" -f $tn) -ForegroundColor Red; $bad | Select-Object -First 3 }
        else { Write-Host ("  {0,-40} ok (column-list copy, CreatedDatetime dropped)" -f $tn) -ForegroundColor Green }
    } else {
        $out = & "$pg\pg_restore.exe" -U postgres -d $db --data-only --disable-triggers --table="$tn" $dmp 2>&1
        $bad = $out | Select-String -Pattern "error|ERROR|FATAL"
        if ($bad) { Write-Host ("  {0,-40} FAILED" -f $tn) -ForegroundColor Red; $bad | Select-Object -First 3 }
        else { Write-Host ("  {0,-40} ok" -f $tn) }
    }
}

Write-Host ""
Write-Host "===== drop staging + prove it is gone =====" -ForegroundColor Yellow
& "$pg\dropdb.exe" -U postgres --if-exists $src
$gone = & "$pg\psql.exe" -U postgres -d postgres -t -A -c "SELECT count(*) FROM pg_database WHERE datname='$src'"
Write-Host ("pg_database rows for {0}: {1}  (must be 0)" -f $src, $gone)

Write-Host ""
Write-Host "===== identity resync: deptype 'a' AND 'i' (the standard block misses 'i') =====" -ForegroundColor Yellow
$seq = @'
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS sch, s.relname AS seq, t.relname AS tbl, a.attname AS col
    FROM pg_class s
    JOIN pg_depend d ON d.objid=s.oid AND d.deptype IN ('a','i')
    JOIN pg_class t ON t.oid=d.refobjid
    JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=d.refobjsubid
    JOIN pg_namespace n ON n.oid=t.relnamespace
    WHERE s.relkind='S' AND n.nspname IN ('public','identity','audit')
  LOOP
    EXECUTE format('SELECT setval(%L, (SELECT COALESCE(MAX(%I),1) FROM %I.%I), true)',
                   r.sch||'.'||r.seq, r.col, r.sch, r.tbl);
  END LOOP;
END $$;
'@
$sf = Join-Path $env:TEMP "b_seq.sql"
[System.IO.File]::WriteAllText($sf, $seq, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d $db -v ON_ERROR_STOP=1 -f $sf
Write-Host ("resync exit: {0}" -f $LASTEXITCODE)

$verify = @"
\echo ===== (1) COUNTS vs expected =====
SELECT 'NGC_BusinessUnit' t, count(*) n, 59 exp FROM "NGC_BusinessUnit"
UNION ALL SELECT 'NGC_Queues', count(*), 61 FROM "NGC_Queues"
UNION ALL SELECT 'NGC_AgentGroups', count(*), 43 FROM "NGC_AgentGroups"
UNION ALL SELECT 'NGC_Supergroup', count(*), 41 FROM "NGC_Supergroup"
UNION ALL SELECT 'NGC_UserAgentgroup', count(*), 566 FROM "NGC_UserAgentgroup"
UNION ALL SELECT 'NGC_Site', count(*), 3 FROM "NGC_Site"
UNION ALL SELECT 'BUQueueClassification', count(*), 61 FROM "NGC_BusinessUnitQueueClassification"
UNION ALL SELECT 'BUSupergroup', count(*), 36 FROM "NGC_BusinessUnitSupergroup"
UNION ALL SELECT 'SupergroupAgentgroup', count(*), 39 FROM "NGC_SupergroupAgentgroup"
UNION ALL SELECT 'RTSGrid_Grid', count(*), 32 FROM "RTSGrid_Grid"
UNION ALL SELECT 'RTSGrid_Row', count(*), 62 FROM "RTSGrid_Row"
UNION ALL SELECT 'RTSGrid_Column', count(*), 77 FROM "RTSGrid_Column"
UNION ALL SELECT 'RTSGrid_Cell', count(*), 338 FROM "RTSGrid_Cell"
UNION ALL SELECT 'RTSUserGrid_Grid', count(*), 2 FROM "RTSUserGrid_Grid"
UNION ALL SELECT 'RTSUserGrid_ColumnsSet', count(*), 2 FROM "RTSUserGrid_ColumnsSet"
UNION ALL SELECT 'RTSUserGrid_Column', count(*), 14 FROM "RTSUserGrid_Column"
UNION ALL SELECT 'RTSData_UserStatusLog', count(*), 202917 FROM "RTSData_UserStatusLog"
ORDER BY 1;
\echo ===== BU names must be HUMAN (schema.sql:162 "BusinessUnitName") =====
SELECT "BusinessUnitId", "BusinessUnitName" FROM "NGC_BusinessUnit" ORDER BY 1 LIMIT 6;
\echo ===== (2a) declared FKs - orphans, expect 0 =====
SELECT 'BUQueueClass->BU' k, count(*) n FROM "NGC_BusinessUnitQueueClassification" c
  LEFT JOIN "NGC_BusinessUnit" p ON c."BusinessUnitId"=p."BusinessUnitId" WHERE p."BusinessUnitId" IS NULL
UNION ALL SELECT 'BUSupergroup->BU', count(*) FROM "NGC_BusinessUnitSupergroup" c
  LEFT JOIN "NGC_BusinessUnit" p ON c."BusinessUnitId"=p."BusinessUnitId" WHERE p."BusinessUnitId" IS NULL
UNION ALL SELECT 'BUSupergroup->SG', count(*) FROM "NGC_BusinessUnitSupergroup" c
  LEFT JOIN "NGC_Supergroup" p ON c."SupergroupId"=p."SupergroupId" WHERE p."SupergroupId" IS NULL
UNION ALL SELECT 'BU->Site', count(*) FROM "NGC_BusinessUnit" c
  LEFT JOIN "NGC_Site" p ON c."SiteId"=p."SiteId" WHERE c."SiteId" IS NOT NULL AND p."SiteId" IS NULL
UNION ALL SELECT 'SGAG->SG', count(*) FROM "NGC_SupergroupAgentgroup" c
  LEFT JOIN "NGC_Supergroup" p ON c."SupergroupId"=p."SupergroupId" WHERE p."SupergroupId" IS NULL
ORDER BY 1;
\echo ===== (2b) logical refs, NO declared FK - join on ExternalId (schema.sql:176/214/253/150/279) =====
SELECT 'BUQueueClass->Queues.ExternalId' k, count(*) n FROM "NGC_BusinessUnitQueueClassification" c
  LEFT JOIN "NGC_Queues" p ON c."QueueId"=p."ExternalId" WHERE c."QueueId" IS NOT NULL AND p."ExternalId" IS NULL
UNION ALL SELECT 'SGAG->AgentGroups.ExternalId', count(*) FROM "NGC_SupergroupAgentgroup" c
  LEFT JOIN "NGC_AgentGroups" p ON c."AgentgroupId"=p."ExternalId" WHERE c."AgentgroupId" IS NOT NULL AND p."ExternalId" IS NULL
UNION ALL SELECT 'UserAgentgroup->AgentGroups.ExternalId', count(*) FROM "NGC_UserAgentgroup" c
  LEFT JOIN "NGC_AgentGroups" p ON c."AgentgroupId"=p."ExternalId" WHERE c."AgentgroupId" IS NOT NULL AND p."ExternalId" IS NULL
UNION ALL SELECT 'Row->Grid', count(*) FROM "RTSGrid_Row" c
  LEFT JOIN "RTSGrid_Grid" p ON c."GridId"=p."GridId" WHERE p."GridId" IS NULL
UNION ALL SELECT 'Column->Grid', count(*) FROM "RTSGrid_Column" c
  LEFT JOIN "RTSGrid_Grid" p ON c."GridId"=p."GridId" WHERE p."GridId" IS NULL
UNION ALL SELECT 'Cell->Row', count(*) FROM "RTSGrid_Cell" c
  LEFT JOIN "RTSGrid_Row" p ON c."RowId"=p."RowId" WHERE p."RowId" IS NULL
UNION ALL SELECT 'Cell->Column', count(*) FROM "RTSGrid_Cell" c
  LEFT JOIN "RTSGrid_Column" p ON c."ColumnId"=p."ColumnId" WHERE p."ColumnId" IS NULL
UNION ALL SELECT 'UserGridColumn->ColumnsSet', count(*) FROM "RTSUserGrid_Column" c
  LEFT JOIN "RTSUserGrid_ColumnsSet" p ON c."ColumnsSetId"=p."ColumnsSetId" WHERE p."ColumnsSetId" IS NULL
ORDER BY 1;
\echo ===== (2c) METRIC GATE: RTSUserGrid_Column.MetricId (schema.sql:641) -> RTSGrid_Metric (:514), expect 0 =====
SELECT count(*) AS dangling FROM "RTSUserGrid_Column" c
  LEFT JOIN "RTSGrid_Metric" m ON c."MetricId"=m."MetricId"
 WHERE c."MetricId" IS NOT NULL AND m."MetricId" IS NULL;
SELECT DISTINCT c."MetricId" FROM "RTSUserGrid_Column" c
  LEFT JOIN "RTSGrid_Metric" m ON c."MetricId"=m."MetricId"
 WHERE c."MetricId" IS NOT NULL AND m."MetricId" IS NULL ORDER BY 1;
\echo ===== METRIC INFO (NOT a gate): Cell."Value" strings matching no metric Description =====
SELECT count(*) AS unmatched_value_strings FROM "RTSGrid_Cell" c
 WHERE c."Value" IS NOT NULL AND c."Value" <> ''
   AND NOT EXISTS (SELECT 1 FROM "RTSGrid_Metric" m WHERE m."Description" = c."Value");
\echo ===== (3) IDENTITY: sequence last_value vs column MAX - seq must be >= max =====
SELECT t.relname AS tbl, a.attname AS col, pg_sequence_last_value(s.oid) AS seq_last
  FROM pg_class s JOIN pg_depend d ON d.objid=s.oid AND d.deptype IN ('a','i')
  JOIN pg_class t ON t.oid=d.refobjid
  JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=d.refobjsubid
  JOIN pg_namespace n ON n.oid=t.relnamespace
 WHERE s.relkind='S' AND n.nspname='public'
   AND t.relname IN ('NGC_BusinessUnit','NGC_Supergroup','NGC_SupergroupAgentgroup','NGC_UserAgentgroup',
                     'RTSData_UserStatusLog','RTSGrid_Grid','RTSGrid_Row','RTSGrid_Column','RTSGrid_Cell',
                     'RTSUserGrid_Grid','RTSUserGrid_ColumnsSet','RTSUserGrid_Column')
 ORDER BY 1;
\echo ===== ownership + privileges =====
SELECT tableowner, count(*) FROM pg_tables WHERE schemaname IN ('public','identity','audit') GROUP BY 1;
SELECT count(*) AS tables_without_full_crud FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind='r'
   AND NOT has_table_privilege('ccdashboard_user', c.oid, 'SELECT,INSERT,UPDATE,DELETE');
"@
$vf = Join-Path $env:TEMP "b_verify.sql"
[System.IO.File]::WriteAllText($vf, $verify, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d $db -f $vf
$env:PGPASSWORD = ""
Write-Host "===== PART B done =====" -ForegroundColor Green
