#Requires -Version 5.1
<#  R1+R2 - restore the 234 dump into rtmviewdb_reh, count the transfer set, probe the BE gate.
    Read-only against everything except rtmviewdb_reh, which is dropped and recreated.
    Authored by devops-0829, 2026-08-29. Run as: powershell -ExecutionPolicy Bypass -File <this file>
#>
$ErrorActionPreference = "Stop"

$pg  = "C:\Program Files\PostgreSQL\18\bin"
$dmp = "D:\RTMView-Ops\rehearsal\rtmviewdb_20260829_1129.dump"
$expectHash  = "EEA7B798F801DB13E887822885235D8FAF500BB16556A837E4681A672679F468"
$expectBytes = 19949183

if (-not (Test-Path $dmp)) { Write-Host "STOP: dump missing at $dmp" -ForegroundColor Red; exit 1 }
$h = (Get-FileHash -Algorithm SHA256 $dmp).Hash
$b = (Get-Item $dmp).Length
Write-Host ("dump bytes {0} (expect {1}); sha {2}" -f $b, $expectBytes, $h)
if ($h -ne $expectHash -or $b -ne $expectBytes) { Write-Host "STOP: source drift - hash or size differs" -ForegroundColor Red; exit 1 }
Write-Host "source pin OK" -ForegroundColor Green

$sec = Read-Host "postgres password" -AsSecureString
$env:PGPASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))

& "$pg\dropdb.exe"   -U postgres --if-exists rtmviewdb_reh
& "$pg\createdb.exe" -U postgres -E UTF8 rtmviewdb_reh
Write-Host "===== restore: errors only (first 20) ====="
& "$pg\pg_restore.exe" -U postgres -d rtmviewdb_reh --no-owner --no-privileges $dmp 2>&1 |
    Select-String -Pattern "error" | Select-Object -First 20
Write-Host "===== restore finished ====="

$sql = @"
SELECT 'NGC_BusinessUnit' t, count(*) n FROM "NGC_BusinessUnit"
UNION ALL SELECT 'NGC_Queues', count(*) FROM "NGC_Queues"
UNION ALL SELECT 'NGC_Supergroup', count(*) FROM "NGC_Supergroup"
UNION ALL SELECT 'NGC_AgentGroups', count(*) FROM "NGC_AgentGroups"
UNION ALL SELECT 'NGC_UserAgentgroup', count(*) FROM "NGC_UserAgentgroup"
UNION ALL SELECT 'NGC_Site', count(*) FROM "NGC_Site"
UNION ALL SELECT 'BUQueueClassification', count(*) FROM "NGC_BusinessUnitQueueClassification"
UNION ALL SELECT 'BUSupergroup', count(*) FROM "NGC_BusinessUnitSupergroup"
UNION ALL SELECT 'SupergroupAgentgroup', count(*) FROM "NGC_SupergroupAgentgroup"
UNION ALL SELECT 'RTSGrid_Grid', count(*) FROM "RTSGrid_Grid"
UNION ALL SELECT 'RTSGrid_Row', count(*) FROM "RTSGrid_Row"
UNION ALL SELECT 'RTSGrid_Column', count(*) FROM "RTSGrid_Column"
UNION ALL SELECT 'RTSGrid_Cell', count(*) FROM "RTSGrid_Cell"
UNION ALL SELECT 'RTSUserGrid_Grid', count(*) FROM "RTSUserGrid_Grid"
UNION ALL SELECT 'RTSUserGrid_ColumnsSet', count(*) FROM "RTSUserGrid_ColumnsSet"
UNION ALL SELECT 'RTSUserGrid_Column', count(*) FROM "RTSUserGrid_Column"
UNION ALL SELECT 'RTSData_UserStatusLog', count(*) FROM "RTSData_UserStatusLog"
UNION ALL SELECT 'RTSData_Interaction', count(*) FROM "RTSData_Interaction"
ORDER BY 1;

SELECT to_regclass('public."__BackendEmulationMigrationsHistory"') AS be_history,
       to_regclass('public."RTSGrid_Grid"') AS be_signature_object;

SELECT table_schema, table_name FROM information_schema.tables
 WHERE table_name ILIKE '%migrationshistory%' OR table_name ILIKE '%__ef%'
 ORDER BY 1,2;
"@

$f = Join-Path $env:TEMP "r1r2_query.sql"
[System.IO.File]::WriteAllText($f, $sql, (New-Object System.Text.UTF8Encoding($false)))
$first = (Get-Content $f -Encoding Byte -TotalCount 3) -join " "
Write-Host ("query file first bytes: {0} (must be 83 69 76 = SEL, not 239 187 191)" -f $first)

& "$pg\psql.exe" -U postgres -d rtmviewdb_reh -f $f
$env:PGPASSWORD = ""
Write-Host "===== R1+R2 done ====="
