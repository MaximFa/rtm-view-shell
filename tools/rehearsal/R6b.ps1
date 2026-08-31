#Requires -Version 5.1
<#  R6b - diagnose the reload failure PROPERLY, before proposing any mechanism change:
      1) restore the dump into a separate staging DB (same physical file - no intermediate dump)
      2) compare the STRUCTURE of all 17 transfer tables: dump-side vs target-side, column by column
      3) settle the IDENTITY question: which pg_depend deptype carries identity sequences
    READ-ONLY against rtmviewdb_reh. Authored by devops-0829, 2026-08-29.
#>
$ErrorActionPreference = "Continue"
$pg  = "C:\Program Files\PostgreSQL\18\bin"
$dmp = "D:\RTMView-Ops\rehearsal\rtmviewdb_20260829_1129.dump"
$src = "rtmviewdb_src"
$db  = "rtmviewdb_reh"

$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

Write-Host "===== staging restore of the SAME dump file =====" -ForegroundColor Cyan
& "$pg\dropdb.exe"   -U postgres --if-exists $src
& "$pg\createdb.exe" -U postgres -E UTF8 $src
& "$pg\pg_restore.exe" -U postgres -d $src $dmp 2>&1 | Select-String -Pattern "^pg_restore: error" | Select-Object -First 5
Write-Host "staging ready"

$q = @"
SELECT table_name, column_name, ordinal_position
  FROM information_schema.columns
 WHERE table_schema='public' AND table_name IN
   ('NGC_Site','NGC_BusinessUnit','NGC_Supergroup','NGC_Queues','NGC_AgentGroups',
    'NGC_BusinessUnitQueueClassification','NGC_BusinessUnitSupergroup','NGC_SupergroupAgentgroup','NGC_UserAgentgroup',
    'RTSGrid_Grid','RTSGrid_Row','RTSGrid_Column','RTSGrid_Cell',
    'RTSUserGrid_Grid','RTSUserGrid_ColumnsSet','RTSUserGrid_Column','RTSData_UserStatusLog')
 ORDER BY table_name, ordinal_position;
"@
$f1 = Join-Path $env:TEMP "cols.sql"
[System.IO.File]::WriteAllText($f1, $q, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "===== columns: DUMP side =====" -ForegroundColor Yellow
& "$pg\psql.exe" -U postgres -d $src -t -A -F "|" -f $f1 | Out-File "$env:TEMP\cols_src.txt" -Encoding ascii
Write-Host "===== columns: TARGET side =====" -ForegroundColor Yellow
& "$pg\psql.exe" -U postgres -d $db  -t -A -F "|" -f $f1 | Out-File "$env:TEMP\cols_dst.txt" -Encoding ascii

$srcCols = @{}; $dstCols = @{}
Get-Content "$env:TEMP\cols_src.txt" | Where-Object { $_ } | ForEach-Object { $p=$_ -split '\|'; if(-not $srcCols[$p[0]]){$srcCols[$p[0]]=@()}; $srcCols[$p[0]] += $p[1] }
Get-Content "$env:TEMP\cols_dst.txt" | Where-Object { $_ } | ForEach-Object { $p=$_ -split '\|'; if(-not $dstCols[$p[0]]){$dstCols[$p[0]]=@()}; $dstCols[$p[0]] += $p[1] }

Write-Host ""
Write-Host "TABLE                                | only in DUMP            | only in TARGET" -ForegroundColor Cyan
Write-Host "-------------------------------------+-------------------------+------------------------"
foreach ($tname in ($srcCols.Keys | Sort-Object)) {
    $onlySrc = @($srcCols[$tname] | Where-Object { $dstCols[$tname] -notcontains $_ })
    $onlyDst = @($dstCols[$tname] | Where-Object { $srcCols[$tname] -notcontains $_ })
    $mark = if ($onlySrc.Count -or $onlyDst.Count) { "  <== MISMATCH" } else { "" }
    "{0,-36} | {1,-23} | {2}{3}" -f $tname, ($onlySrc -join ","), ($onlyDst -join ","), $mark
}

Write-Host ""
Write-Host "===== IDENTITY question: which deptype carries identity sequences =====" -ForegroundColor Yellow
$q2 = @"
SELECT d.deptype, count(*) AS sequences
  FROM pg_class s JOIN pg_depend d ON d.objid=s.oid
  JOIN pg_class t ON t.oid=d.refobjid JOIN pg_namespace n ON n.oid=t.relnamespace
 WHERE s.relkind='S' AND n.nspname='public' GROUP BY 1 ORDER BY 1;
SELECT t.relname, a.attname, a.attidentity, s.relname AS seq, pg_sequence_last_value(s.oid) AS last_value,
       (SELECT max(1) FROM pg_class WHERE false) AS _
  FROM pg_class s JOIN pg_depend d ON d.objid=s.oid
  JOIN pg_class t ON t.oid=d.refobjid
  JOIN pg_attribute a ON a.attrelid=t.oid AND a.attnum=d.refobjsubid
  JOIN pg_namespace n ON n.oid=t.relnamespace
 WHERE s.relkind='S' AND n.nspname='public'
   AND t.relname IN ('NGC_BusinessUnit','RTSGrid_Cell','RTSData_UserStatusLog','RTSGrid_Grid')
 ORDER BY 1;
"@
$f2 = Join-Path $env:TEMP "ident.sql"
[System.IO.File]::WriteAllText($f2, $q2, (New-Object System.Text.UTF8Encoding($false)))
& "$pg\psql.exe" -U postgres -d $db -f $f2
$env:PGPASSWORD = ""
Write-Host "===== R6b done ====="
