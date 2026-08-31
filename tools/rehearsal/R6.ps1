#Requires -Version 5.1
<#  R6 - RELOAD the transfer set from the SAME physical dump (SEAM-1), in FK order,
    then: sequence resync (Provision-FreshDb step 7 block), INTEGRITY (counts != meaning),
    and the metric-reference check.
    Authored by devops-0829, 2026-08-29.
#>
$ErrorActionPreference = "Continue"   # psql/pg_restore write NOTICEs to stderr
$pg  = "C:\Program Files\PostgreSQL\18\bin"
$dmp = "D:\RTMView-Ops\rehearsal\rtmviewdb_20260829_1129.dump"
$db  = "rtmviewdb_reh"

$expectHash = "EEA7B798F801DB13E887822885235D8FAF500BB16556A837E4681A672679F468"
$h = (Get-FileHash -Algorithm SHA256 $dmp).Hash
if ($h -ne $expectHash) { Write-Host "STOP: reload source drifted" -ForegroundColor Red; exit 1 }
Write-Host "reload source hash OK (same physical file as R1)" -ForegroundColor Green

$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

$order = @(
 "NGC_Site","NGC_BusinessUnit","NGC_Supergroup","NGC_Queues","NGC_AgentGroups",
 "NGC_BusinessUnitQueueClassification","NGC_BusinessUnitSupergroup","NGC_SupergroupAgentgroup","NGC_UserAgentgroup",
 "RTSGrid_Grid","RTSGrid_Row","RTSGrid_Column","RTSGrid_Cell",
 "RTSUserGrid_Grid","RTSUserGrid_ColumnsSet","RTSUserGrid_Column",
 "RTSData_UserStatusLog"
)
Write-Host "===== RELOAD in FK order =====" -ForegroundColor Yellow
$failed = @()
foreach ($t in $order) {
    $out = & "$pg\pg_restore.exe" -U postgres -d $db --data-only --disable-triggers --table="$t" $dmp 2>&1
    $bad = $out | Select-String -Pattern "error|ERROR|FATAL"
    if ($LASTEXITCODE -ne 0 -or $bad) { Write-Host ("  {0,-40} FAILED" -f $t) -ForegroundColor Red; $bad | Select-Object -First 3; $failed += $t }
    else { Write-Host ("  {0,-40} ok" -f $t) }
}
if ($failed.Count -gt 0) { Write-Host ("STOP: reload failures: {0}" -f ($failed -join ", ")) -ForegroundColor Red }

Write-Host "===== sequence resync (Provision-FreshDb step 7 block, verbatim) =====" -ForegroundColor Yellow
$seq = @'
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS sch, s.relname AS seq, t.relname AS tbl, a.attname AS col
    FROM pg_class s
    JOIN pg_depend d ON d.objid=s.oid AND d.deptype='a'
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
$t1 = Join-Path $env:TEMP "r6_seq.sql"
[System.IO.File]::WriteAllText($t1, $seq, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d $db -v ON_ERROR_STOP=1 -f $t1
Write-Host ("sequence resync exit: {0}" -f $LASTEXITCODE)

$verify = @"
\echo ===== (1) COUNTS - did the rows arrive =====
SELECT 'NGC_BusinessUnit' t, count(*) n, 59 expected FROM "NGC_BusinessUnit"
UNION ALL SELECT 'NGC_Queues', count(*), 61 FROM "NGC_Queues"
UNION ALL SELECT 'NGC_Supergroup', count(*), 41 FROM "NGC_Supergroup"
UNION ALL SELECT 'NGC_AgentGroups', count(*), 43 FROM "NGC_AgentGroups"
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
\echo ===== BU names must be HUMAN, not id=id =====
SELECT "BusinessUnitId", "Name" FROM "NGC_BusinessUnit" ORDER BY 1 LIMIT 8;
\echo ===== (2a) declared FKs - orphans, expect 0 everywhere =====
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
\echo ===== (2b) LOGICAL references with NO declared FK - VALIDATE can never catch these =====
SELECT 'BUQueueClass->Queues' k, count(*) n FROM "NGC_BusinessUnitQueueClassification" c
  LEFT JOIN "NGC_Queues" p ON c."QueueId"=p."QueueId" WHERE c."QueueId" IS NOT NULL AND p."QueueId" IS NULL
UNION ALL SELECT 'SGAG->AgentGroups', count(*) FROM "NGC_SupergroupAgentgroup" c
  LEFT JOIN "NGC_AgentGroups" p ON c."AgentgroupId"=p."AgentgroupId" WHERE c."AgentgroupId" IS NOT NULL AND p."AgentgroupId" IS NULL
UNION ALL SELECT 'UserAgentgroup->AgentGroups', count(*) FROM "NGC_UserAgentgroup" c
  LEFT JOIN "NGC_AgentGroups" p ON c."AgentgroupId"=p."AgentgroupId" WHERE c."AgentgroupId" IS NOT NULL AND p."AgentgroupId" IS NULL
UNION ALL SELECT 'Row->Grid', count(*) FROM "RTSGrid_Row" c
  LEFT JOIN "RTSGrid_Grid" p ON c."GridId"=p."GridId" WHERE p."GridId" IS NULL
UNION ALL SELECT 'Column->Grid', count(*) FROM "RTSGrid_Column" c
  LEFT JOIN "RTSGrid_Grid" p ON c."GridId"=p."GridId" WHERE p."GridId" IS NULL
ORDER BY 1;
\echo ===== (2c) metric references - dangling RTSGrid_Cell.MetricId after the baseline seed =====
SELECT count(*) AS dangling_metric_refs FROM "RTSGrid_Cell" c
  LEFT JOIN "RTSGrid_Metric" m ON c."MetricId"=m."MetricId"
 WHERE c."MetricId" IS NOT NULL AND m."MetricId" IS NULL;
SELECT DISTINCT c."MetricId" AS missing_metric FROM "RTSGrid_Cell" c
  LEFT JOIN "RTSGrid_Metric" m ON c."MetricId"=m."MetricId"
 WHERE c."MetricId" IS NOT NULL AND m."MetricId" IS NULL ORDER BY 1 LIMIT 20;
\echo ===== (3) IDENTITY - every sequence must be ahead of its column max =====
SELECT n.nspname||'.'||t.relname AS tbl, a.attname AS col,
       pg_sequence_last_value(s.oid) AS seq_last
  FROM pg_class s
  JOIN pg_depend d ON d.objid=s.oid AND d.deptype='a'
  JOIN pg_class t ON t.oid=d.refobjid
  JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=d.refobjsubid
  JOIN pg_namespace n ON n.oid=t.relnamespace
 WHERE s.relkind='S' AND n.nspname='public'
   AND t.relname IN ('NGC_BusinessUnit','NGC_Supergroup','NGC_SupergroupAgentgroup','NGC_UserAgentgroup',
                     'RTSData_UserStatusLog','RTSGrid_Grid','RTSGrid_Row','RTSGrid_Column','RTSGrid_Cell',
                     'RTSUserGrid_Grid','RTSUserGrid_ColumnsSet','RTSUserGrid_Column')
 ORDER BY 1;
"@
$f = Join-Path $env:TEMP "r6_verify.sql"
[System.IO.File]::WriteAllText($f, $verify, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d $db -f $f
$env:PGPASSWORD = ""
Write-Host "===== R6 done ====="
