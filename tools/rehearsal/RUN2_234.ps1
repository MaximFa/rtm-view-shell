#Requires -Version 5.1
<#  RUN 2 on server 234 - transfer into rtmviewdb on PORT 5433.
    Touches ONLY the 18 instance. Port 5432, legacy, RTM.Twilio and Garnet are never contacted.
    Authored by devops-0829, 2026-08-30.
#>
$ErrorActionPreference = "Continue"
chcp 65001 > $null
$pg   = "C:\Program Files\PostgreSQL\18\bin"
$dmp  = "C:\RTMView-Ops\backup\rtmviewdb_20260829_1129.dump"
$port = 5433
$db   = "rtmviewdb"
$src  = "rtmviewdb_src"
$expectHash = "EEA7B798F801DB13E887822885235D8FAF500BB16556A837E4681A672679F468"

$h = (Get-FileHash $dmp -Algorithm SHA256).Hash
if ($h -ne $expectHash) { Write-Host "STOP: dump hash drift" -ForegroundColor Red; exit 1 }
Write-Host "source pin OK" -ForegroundColor Green

$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
$env:PGCLIENTENCODING = "UTF8"

$order = @("NGC_Site","NGC_BusinessUnit","NGC_Supergroup","NGC_Queues","NGC_AgentGroups",
 "NGC_BusinessUnitQueueClassification","NGC_BusinessUnitSupergroup","NGC_SupergroupAgentgroup","NGC_UserAgentgroup",
 "RTSGrid_Grid","RTSGrid_Row","RTSGrid_Column","RTSGrid_Cell",
 "RTSUserGrid_Grid","RTSUserGrid_ColumnsSet","RTSUserGrid_Column","RTSData_UserStatusLog")
$colList = '"Id","TenantId","ExternalId","Name","IsActive"'

Write-Host "===== RELOAD =====" -ForegroundColor Yellow
foreach ($t in $order) {
    if ($t -in @("NGC_Queues","NGC_AgentGroups")) {
        $tmp = Join-Path $env:TEMP "r2_$t.txt"
        if (Test-Path $tmp) { Remove-Item $tmp -Force }
        $esc = $tmp -replace '\\','/'
        $o = Join-Path $env:TEMP "r2_out_$t.sql"; $i = Join-Path $env:TEMP "r2_in_$t.sql"
        [System.IO.File]::WriteAllText($o, "\copy (SELECT $colList FROM public.""$t"") TO '$esc'", (New-Object System.Text.UTF8Encoding($false)))
        [System.IO.File]::WriteAllText($i, "\copy public.""$t"" ($colList) FROM '$esc'", (New-Object System.Text.UTF8Encoding($false)))
        $a = & "$pg\psql.exe" -U postgres -h localhost -p $port -d $src -f $o 2>&1
        $b = & "$pg\psql.exe" -U postgres -h localhost -p $port -d $db  -f $i 2>&1
        $bad = @($a; $b) | Select-String "ERROR|error:"
        $rows = if (Test-Path $tmp) { (Get-Content $tmp | Measure-Object -Line).Lines } else { 0 }
        if ($bad) { Write-Host ("  {0,-38} FAILED" -f $t) -ForegroundColor Red; $bad | Select-Object -First 2 }
        else { Write-Host ("  {0,-38} ok ({1} rows, column-list)" -f $t, $rows) -ForegroundColor Green }
    } else {
        $out = & "$pg\pg_restore.exe" -U postgres -h localhost -p $port -d $db --data-only --disable-triggers --table="$t" $dmp 2>&1
        $bad = $out | Select-String "error|ERROR"
        if ($bad) { Write-Host ("  {0,-38} FAILED" -f $t) -ForegroundColor Red; $bad | Select-Object -First 2 }
        else { Write-Host ("  {0,-38} ok" -f $t) }
    }
}

Write-Host "===== IDENTITY resync (deptype a AND i, quote_ident) =====" -ForegroundColor Yellow
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
                   quote_ident(r.sch)||'.'||quote_ident(r.seq), r.col, r.sch, r.tbl);
  END LOOP;
END $$;
'@
$sf = Join-Path $env:TEMP "r2_seq.sql"
[System.IO.File]::WriteAllText($sf, $seq, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -h localhost -p $port -d $db -v ON_ERROR_STOP=1 -f $sf
Write-Host ("resync exit: {0}" -f $LASTEXITCODE)

$verify = @"
\echo ===== COUNTS vs expected =====
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
\echo ===== BU names must be HUMAN =====
SELECT "BusinessUnitId", "BusinessUnitName" FROM "NGC_BusinessUnit" ORDER BY 1 LIMIT 6;
\echo ===== INTEGRITY vs SOURCE BASELINE (expect 21 / 21 / 81, others 0) =====
SELECT 'Cell->Row' k, count(*) n, 21 baseline FROM "RTSGrid_Cell" c
  LEFT JOIN "RTSGrid_Row" p ON c."RowId"=p."RowId" WHERE p."RowId" IS NULL
UNION ALL SELECT 'Cell->Column', count(*), 21 FROM "RTSGrid_Cell" c
  LEFT JOIN "RTSGrid_Column" p ON c."ColumnId"=p."ColumnId" WHERE p."ColumnId" IS NULL
UNION ALL SELECT 'UserAG->AgentGroups', count(*), 81 FROM "NGC_UserAgentgroup" c
  LEFT JOIN "NGC_AgentGroups" p ON c."AgentgroupId"=p."ExternalId" WHERE c."AgentgroupId" IS NOT NULL AND p."ExternalId" IS NULL
UNION ALL SELECT 'BUQueueClass->Queues', count(*), 0 FROM "NGC_BusinessUnitQueueClassification" c
  LEFT JOIN "NGC_Queues" p ON c."QueueId"=p."ExternalId" WHERE c."QueueId" IS NOT NULL AND p."ExternalId" IS NULL
UNION ALL SELECT 'SGAG->AgentGroups', count(*), 0 FROM "NGC_SupergroupAgentgroup" c
  LEFT JOIN "NGC_AgentGroups" p ON c."AgentgroupId"=p."ExternalId" WHERE c."AgentgroupId" IS NOT NULL AND p."ExternalId" IS NULL
UNION ALL SELECT 'BUQueueClass->BU', count(*), 0 FROM "NGC_BusinessUnitQueueClassification" c
  LEFT JOIN "NGC_BusinessUnit" p ON c."BusinessUnitId"=p."BusinessUnitId" WHERE p."BusinessUnitId" IS NULL
UNION ALL SELECT 'BUSupergroup->SG', count(*), 0 FROM "NGC_BusinessUnitSupergroup" c
  LEFT JOIN "NGC_Supergroup" p ON c."SupergroupId"=p."SupergroupId" WHERE p."SupergroupId" IS NULL
ORDER BY 1;
\echo ===== METRIC GATE (expect 0) =====
SELECT count(*) AS dangling FROM "RTSUserGrid_Column" c
  LEFT JOIN "RTSGrid_Metric" m ON c."MetricId"=m."MetricId"
 WHERE c."MetricId" IS NOT NULL AND m."MetricId" IS NULL;
\echo ===== IDENTITY sequences =====
SELECT t.relname tbl, a.attname col, pg_sequence_last_value(s.oid) seq_last
  FROM pg_class s JOIN pg_depend d ON d.objid=s.oid AND d.deptype IN ('a','i')
  JOIN pg_class t ON t.oid=d.refobjid
  JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=d.refobjsubid
  JOIN pg_namespace n ON n.oid=t.relnamespace
 WHERE s.relkind='S' AND n.nspname='public'
   AND t.relname IN ('NGC_BusinessUnit','NGC_Supergroup','NGC_SupergroupAgentgroup','NGC_UserAgentgroup',
                     'RTSData_UserStatusLog','RTSGrid_Grid','RTSGrid_Row','RTSGrid_Column','RTSGrid_Cell',
                     'RTSUserGrid_Grid','RTSUserGrid_ColumnsSet','RTSUserGrid_Column')
 ORDER BY 1;
\echo ===== SLUGS (P4d) =====
SELECT "Slug", "Name" FROM public.tenants ORDER BY 1;
"@
$vf = Join-Path $env:TEMP "r2_verify.sql"
[System.IO.File]::WriteAllText($vf, $verify, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -h localhost -p $port -d $db -f $vf

Write-Host "===== drop staging + prove =====" -ForegroundColor Yellow
& "$pg\dropdb.exe" -U postgres -h localhost -p $port --if-exists $src
& "$pg\psql.exe" -U postgres -h localhost -p $port -d postgres -t -A -c "SELECT count(*) FROM pg_database WHERE datname='rtmviewdb_src';"
$env:PGPASSWORD = ""
Write-Host "===== RUN 2 done =====" -ForegroundColor Green
