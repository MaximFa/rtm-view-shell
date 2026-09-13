#Requires -Version 5.1
# ============================================================================
#  PROBE 234 / backup-both  -  CREATES DUMP FILES. Databases are READ ONLY.
#  WHERE IT RUNS : server 234.
#     DB #1 = rtmviewdb @ 127.0.0.1:5432  (PG15, UNTOUCHED "before us")  <- dumped FIRST
#     DB #2 = rtmviewdb @ 127.0.0.1:5433  (PG18, ours, live)
#  WRITES        : ONLY new files under C:\RTMView-Ops\backup\ .
#                  Nothing is changed, restored or deleted in either database.
#  TOUCHES       : nothing under C:\IceDash\. Widget 78 is not modified.
#  PASSWORD      : read from the machine's own Shell config; only its LENGTH is printed.
#  WHY 5432 FIRST: it is the ONLY place where the six removed metric rows still exist.
#                  It is evidence, not a spare copy.
# ============================================================================

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"

$BackupDir = "C:\RTMView-Ops\backup"
$OutDir    = "C:\RTMView-Ops\output"
$cfg       = "C:\RTMView\Shell\appsettings.json"
$server    = "234"
$stamp     = Get-Date -Format yyyyMMdd_HHmmss

Write-Host "WHERE IT RUNS : server $server. Dumps BOTH databases. Databases are read-only; only new files are created."

$psqlExe = @(Get-ChildItem 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -ErrorAction SilentlyContinue)
if ($psqlExe.Count -ne 1 -or -not (Test-Path $cfg)) {
    Write-Host "STOP: psql matches=$($psqlExe.Count), config exists=$(Test-Path $cfg). Nothing was run."
    exit 1
}
$psql = $psqlExe[0].FullName

# version-matched pg_dump per server where available (a dump taken by a newer tool
# carries preamble GUCs the older server does not know - lesson 2026-08-30)
$dump15 = @(Get-ChildItem 'C:\Program Files\PostgreSQL\15\bin\pg_dump.exe' -ErrorAction SilentlyContinue)
$dump18 = @(Get-ChildItem 'C:\Program Files\PostgreSQL\18\bin\pg_dump.exe' -ErrorAction SilentlyContinue)
$rest18 = @(Get-ChildItem 'C:\Program Files\PostgreSQL\18\bin\pg_restore.exe' -ErrorAction SilentlyContinue)
if ($dump18.Count -ne 1 -or $rest18.Count -ne 1) {
    Write-Host "STOP: pg_dump18=$($dump18.Count), pg_restore18=$($rest18.Count). Nothing was run."
    exit 1
}

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir    | Out-Null

$txt = [IO.File]::ReadAllText($cfg)
$pw  = ([regex]::Match($txt,'Password\s*=\s*([^";]+)')).Groups[1].Value
$usr = ([regex]::Match($txt,'Username\s*=\s*([^";]+)')).Groups[1].Value
if ($pw.Length -eq 0) { Write-Host "STOP: password not found in $cfg. Nothing was run."; exit 1 }

$rep  = Join-Path $OutDir "$($server)_$($stamp)_backup-both.txt"
$L    = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }

Say "===== B0 PRE-FLIGHT ====="
Say ("  user                : {0}  (password length {1}, value never printed)" -f $usr, $pw.Length)
$drive = Get-PSDrive C
$freeBefore = [math]::Round($drive.Free/1GB,2)
Say ("  free space on C: BEFORE : {0} GB" -f $freeBefore)
Say ("  pg_dump 15 present  : {0}" -f ($dump15.Count -eq 1))
Say ("  pg_dump 18 present  : {0}" -f ($dump18.Count -eq 1))

function AskDb([int]$port, [string]$q) {
    $tmp = Join-Path $env:TEMP ("bk_{0}.sql" -f [guid]::NewGuid().ToString("N"))
    [IO.File]::WriteAllText($tmp, $q, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $pw
    $r = & $psql -h 127.0.0.1 -p $port -U $usr -d rtmviewdb -A -t -f $tmp 2>&1
    $env:PGPASSWORD = $null
    Remove-Item $tmp -ErrorAction SilentlyContinue
    return @($r | Where-Object { $_ -ne $null -and "$_".Trim().Length -gt 0 })
}

Say ""
Say "===== B1 IDENTITY AND OWNERSHIP - each database states what it is ====="
$ownersOk = $true
foreach ($p in 5432,5433) {
    $id = (AskDb $p "SELECT current_database()||' | port '||inet_server_port()||' | '||version();") -join ""
    Say ("  {0}" -f $id)
    $own = AskDb $p "SELECT tableowner||' : '||count(*) FROM pg_tables WHERE schemaname IN ('public','identity','audit') GROUP BY tableowner ORDER BY tableowner;"
    foreach ($o in $own) { Say ("      owner {0}" -f $o) }
    $foreign = AskDb $p ("SELECT count(*) FROM pg_tables WHERE schemaname IN ('public','identity','audit') AND tableowner <> '{0}';" -f $usr)
    $n = 0; [void][int]::TryParse((($foreign -join "").Trim()), [ref]$n)
    Say ("      tables NOT owned by {0} : {1}" -f $usr, $n)
    if ($n -gt 0) { $ownersOk = $false }
}

if (-not $ownersOk) {
    Say ""
    Say "  *** STOP - NOT DUMPING. Some tables are owned by another role."
    Say "      A pg_dump run by a non-owner produces an INCOMPLETE backup that looks fine"
    Say "      (role-devops lesson 2026-06-19, server 234). This needs the owner role's"
    Say "      credentials, which I will not ask for inside a script. Report and stop."
    [IO.File]::WriteAllLines($rep, $L, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ""
    Write-Host "GATE: FAIL - backup deliberately NOT taken. Report: $rep"
    exit 1
}

function Dump-One([int]$port, [string]$label, [string]$tool) {
    $file = Join-Path $BackupDir "rtmviewdb_$($label)_$($stamp).dump"
    $log  = Join-Path $BackupDir "rtmviewdb_$($label)_$($stamp).err.txt"
    Say ""
    Say ("===== B2 DUMP port {0} ({1}) =====" -f $port, $label)
    Say ("  tool : {0}" -f $tool)
    Say ("  file : {0}" -f $file)
    $env:PGPASSWORD = $pw
    & $tool -h 127.0.0.1 -p $port -U $usr -d rtmviewdb -Fc -f $file 2> $log
    $rc = $LASTEXITCODE
    $env:PGPASSWORD = $null

    $errSize = 0; if (Test-Path $log) { $errSize = (Get-Item $log).Length }
    $size    = 0; if (Test-Path $file) { $size = (Get-Item $file).Length }
    Say ("  exit code       : {0}   (must be 0)" -f $rc)
    Say ("  stderr bytes    : {0}   (must be 0)" -f $errSize)
    Say ("  file size bytes : {0}   (must be > 0)" -f $size)

    $sha = "<not computed>"
    if ($size -gt 0) { $sha = (Get-FileHash -Path $file -Algorithm SHA256).Hash }
    Say ("  SHA-256         : {0}" -f $sha)

    $toc = @()
    $tocCount = 0
    $hasMetric = $false
    if ($size -gt 0) {
        $toc = & $rest18[0].FullName --list $file 2>&1
        $tocCount = @($toc | Where-Object { "$_" -match '^\s*\d+;' }).Count
        $hasMetric = [bool](@($toc | Where-Object { "$_" -match 'RTSGrid_Metric' }).Count -gt 0)
    }
    Say ("  TOC entries     : {0}   (must be > 0 - a file that cannot be listed is not a backup)" -f $tocCount)
    Say ("  RTSGrid_Metric in TOC : {0}" -f $hasMetric)

    $ok = ($rc -eq 0 -and $errSize -eq 0 -and $size -gt 0 -and $tocCount -gt 0 -and $hasMetric)
    Say ("  GATE {0} : {1}" -f $label, $(if ($ok) { "PASS" } else { "FAIL" }))
    return $ok
}

$tool15 = $(if ($dump15.Count -eq 1) { $dump15[0].FullName } else { $dump18[0].FullName })
$ok32 = Dump-One 5432 "5432-untouched-EVIDENCE" $tool15
$ok33 = Dump-One 5433 "5433-live" $dump18[0].FullName

$freeAfter = [math]::Round((Get-PSDrive C).Free/1GB,2)
Say ""
Say "===== B3 AFTER ====="
Say ("  free space on C: AFTER : {0} GB   (was {1} GB)" -f $freeAfter, $freeBefore)
Say ("  backup directory       : {0}" -f $BackupDir)
Say "===== END-OF-RUN MARKER: BACKUP-BOTH-COMPLETE ====="

[IO.File]::WriteAllLines($rep, $L, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
if ($ok32 -and $ok33) { Write-Host "OVERALL GATE: PASS - both dumps taken and verified by listing" }
else { Write-Host "OVERALL GATE: FAIL - read the report, do not treat the files as usable backups" }
Write-Host ""
Write-Host "COPY THIS BACK:"
Write-Host "   $rep"
