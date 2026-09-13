#Requires -Version 5.1
# ============================================================================
#  PROBE 234 / applysvc-recon   -   READ ONLY.  NOTHING IS STOPPED OR CHANGED.
#  WHERE IT RUNS : server 234.
#  WRITES        : output files only, into C:\RTMView-Ops\output\
#  DOES NOT      : stop/start/delete any service; change any ENV; touch C:\IceDash\;
#                  write to any database; run with -Proceed (no such switch exists here).
#  PURPOSE       : G6 of the wipe probe found a 4th service of ours, RTMApplyService,
#                  which is in NO backup and in NO procedure. Gather facts so the scope
#                  decision is made on measurements, not on guesses.
#  SECRETS       : ENV values are NEVER printed. Only NAME, present yes/no, and LENGTH.
#                  DB password is read from the machine config; only its length is shown.
# ============================================================================

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"

$OpsRoot  = "C:\RTMView-Ops"
$OutDir   = Join-Path $OpsRoot "output"
$Preserve = Join-Path $OpsRoot "preserve_20260906_1230"
$BackupD  = Join-Path $OpsRoot "backup"
$ApplyDir = "C:\RTMView\ApplyService"
$ShellCfg = "C:\RTMView\Shell\appsettings.json"
$SvcName  = "RTMApplyService"
$server   = "234"
$topic    = "applysvc-recon"

Write-Host "WHERE IT RUNS : server $server. READ ONLY - nothing is stopped, deleted or changed."
Write-Host "SECRETS       : ENV values are never printed - name / present / length only."

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).txt"
$errf  = Join-Path $OutDir "$($server)_$($stamp)_$($topic).err.txt"
$errAll = New-Object System.Collections.ArrayList
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }

# ---------- psql plumbing (same shape as previous probes) ----------
$psqlExe = @(Get-ChildItem 'C:\Program Files\PostgreSQL\18\bin\psql.exe' -ErrorAction SilentlyContinue)
$dbOk = ($psqlExe.Count -eq 1 -and (Test-Path $ShellCfg))
$psql = $null; $pw = ""; $usr = ""
if ($dbOk) {
    $psql = $psqlExe[0].FullName
    $txt  = [IO.File]::ReadAllText($ShellCfg)
    $pw   = ([regex]::Match($txt,'Password\s*=\s*([^";]+)')).Groups[1].Value
    $usr  = ([regex]::Match($txt,'Username\s*=\s*([^";]+)')).Groups[1].Value
    if ($pw.Length -eq 0) { $dbOk = $false }
}

function Ask([int]$port, [string]$sqlText) {
    if (-not $dbOk) { return @() }
    $t = Join-Path $env:TEMP ("ar_{0}.sql" -f [guid]::NewGuid().ToString("N"))
    $e = Join-Path $env:TEMP ("ar_{0}.err" -f [guid]::NewGuid().ToString("N"))
    [IO.File]::WriteAllText($t, $sqlText, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $pw
    $r = & $psql -h 127.0.0.1 -p $port -U $usr -d rtmviewdb -v ON_ERROR_STOP=1 -A -F "|" -t -f $t 2> $e
    $env:PGPASSWORD = $null
    if (Test-Path $e) {
        $c = [IO.File]::ReadAllText($e)
        if ($c.Trim().Length -gt 0) { [void]$errAll.Add("port $port :: $c") }
        Remove-Item $e -ErrorAction SilentlyContinue
    }
    Remove-Item $t -ErrorAction SilentlyContinue
    return @($r | Where-Object { $_ -ne $null -and "$_".Trim().Length -gt 0 })
}

# ============================== A. THE DIRECTORY ==============================
Say ""
Say "===== A  the directory C:\RTMView\ApplyService - what would be destroyed ====="
$dirExists = Test-Path $ApplyDir
Say ("  exists : {0}" -f $dirExists)
$aFiles = @()
if ($dirExists) {
    $aFiles = @(Get-ChildItem $ApplyDir -Recurse -File -ErrorAction SilentlyContinue)
    $bytes  = ($aFiles | Measure-Object -Property Length -Sum).Sum
    if ($bytes -eq $null) { $bytes = 0 }
    Say ("  files  : {0}" -f $aFiles.Count)
    Say ("  bytes  : {0}  ({1:N1} MB)" -f $bytes, ($bytes/1MB))
    Say "  --- config-like and state-like files (name | bytes | sha256 first 8 | modified) ---"
    $interesting = @($aFiles | Where-Object {
        $_.Extension -in @('.json','.config','.xml','.ini','.sys','.dat','.db','.pfx','.key') -or
        $_.Name -match '^(data|state|license|token)' })
    if ($interesting.Count -eq 0) { Say "      none" }
    foreach ($f in $interesting) {
        $h = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.Substring(0,8)
        Say ("      {0} | {1} | {2} | {3}" -f $f.FullName.Substring($ApplyDir.Length+1), $f.Length, $h, $f.LastWriteTime)
    }
    Say "  --- subdirectories ---"
    $subs = @(Get-ChildItem $ApplyDir -Directory -ErrorAction SilentlyContinue)
    if ($subs.Count -eq 0) { Say "      none" } else { foreach ($s in $subs) { Say ("      {0}" -f $s.Name) } }
} else {
    Say "  *** the service points at a path that does not exist - report this, it changes everything"
}
Say ("  NEGCTL a path that must NOT exist (C:\RTMView\NoSuchDir_xyz) : {0}   (must be False)" -f (Test-Path "C:\RTMView\NoSuchDir_xyz"))
Say ("  is any of it already in preserve_ ? files under {0}\ApplyService : {1}" -f $Preserve, @(Get-ChildItem (Join-Path $Preserve 'ApplyService') -Recurse -File -ErrorAction SilentlyContinue).Count)

# ============================== B. THE SERVICE + ITS ENV ==============================
Say ""
Say "===== B  the service and its ENV - NAMES AND LENGTHS ONLY, never values ====="
$svc = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
if ($svc -eq $null) { Say "  service not found by name - report" }
else {
    $wmi = Get-WmiObject Win32_Service -Filter "Name='$SvcName'" -ErrorAction SilentlyContinue
    Say ("  name       : {0}" -f $svc.Name)
    Say ("  status     : {0}" -f $svc.Status)
    Say ("  startmode  : {0}" -f $wmi.StartMode)
    Say ("  logon as   : {0}" -f $wmi.StartName)
    Say ("  image path : {0}" -f $wmi.PathName)
}
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$SvcName"
Say ("  registry key exists : {0}" -f (Test-Path $regPath))
$envNames = @()
if (Test-Path $regPath) {
    $props = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    $envRaw = $props.Environment
    if ($envRaw -eq $null) {
        Say "  Environment value : ABSENT under the service key"
    } else {
        Say ("  Environment entries : {0}" -f @($envRaw).Count)
        foreach ($line in @($envRaw)) {
            $i = "$line".IndexOf('=')
            if ($i -lt 1) { Say ("      <unparsable entry, length {0}>" -f "$line".Length); continue }
            $n = "$line".Substring(0,$i)
            $v = "$line".Substring($i+1)
            $envNames += $n
            Say ("      {0} | present={1} | length={2}" -f $n, ($v.Length -gt 0), $v.Length)
        }
    }
}
Say ("  NEGCTL a service key that must NOT exist (RTMNoSuchService_xyz) : {0}   (must be False)" -f (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\RTMNoSuchService_xyz"))
$tokenInEnv = ($envNames | Where-Object { $_ -match 'Token' }).Count -gt 0
Say ("  a Token-named variable is present in ENV : {0}" -f $tokenInEnv)

Say "  --- is a token stored anywhere ELSE we already hold? (searching text, never printing matches) ---"
foreach ($cand in @($ApplyDir, (Join-Path $Preserve 'configs'), 'C:\RTMView\Shell', 'C:\RTMView\RTM')) {
    $n = 0
    if (Test-Path $cand) {
        $n = @(Get-ChildItem $cand -Recurse -File -Include *.json,*.config,*.xml -ErrorAction SilentlyContinue |
               Select-String -Pattern 'ApplyService__Token|"Token"\s*:' -List -ErrorAction SilentlyContinue).Count
    }
    Say ("      files mentioning a Token key under {0} : {1}" -f $cand, $n)
}

# ============================== C. WHO REFERS TO IT ==============================
Say ""
Say "===== C  who points at ApplyService - BaseUrl and the port ====="
foreach ($c in @(@{n='live Shell';p=$ShellCfg}, @{n='preserved Shell';p=(Join-Path $Preserve 'configs\current\Shell__appsettings.json')})) {
    if (Test-Path $c.p) {
        $t = [IO.File]::ReadAllText($c.p)
        $m = [regex]::Match($t,'"BaseUrl"\s*:\s*"([^"]*)"')
        Say ("  {0,-16} MetricsApply:BaseUrl = {1}" -f $c.n, $(if ($m.Success) { $m.Groups[1].Value } else { "key absent" }))
    } else { Say ("  {0,-16} config not found: {1}" -f $c.n, $c.p) }
}
foreach ($p in @(5099, 5098)) {
    $conn = @(Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue)
    if ($conn.Count -eq 0) {
        Say ("  port {0} : nobody is listening{1}" -f $p, $(if ($p -eq 5098) { "   (NEGCTL - expected)" } else { "" }))
    } else {
        foreach ($cn in $conn) {
            $pr = Get-Process -Id $cn.OwningProcess -ErrorAction SilentlyContinue
            Say ("  port {0} : LISTEN on {1} by pid {2} = {3}" -f $p, $cn.LocalAddress, $cn.OwningProcess, $(if ($pr) { $pr.Path } else { "<pid gone>" }))
        }
    }
}

# ============================== D. THE DATABASE SIDE ==============================
Say ""
Say "===== D  the role ccdashboard_catowner - which server holds it, 5432 or 5433 ====="
if (-not $dbOk) { Say "  psql or config unavailable - database section not run" }
else {
    Say ("  connecting as {0} (password length {1}, never printed)" -f $usr, $pw.Length)
    foreach ($p in 5432,5433) {
        Say ("  --- port {0} ---" -f $p)
        foreach ($r in (Ask $p "SELECT '  identity: '||current_database()||' | port '||inet_server_port()||' | '||split_part(version(),',',1);")) { Say ("    {0}" -f $r) }
        foreach ($r in (Ask $p "SELECT '  role ccdashboard_catowner exists: '||count(*) FROM pg_roles WHERE rolname='ccdashboard_catowner';")) { Say ("    {0}" -f $r) }
        foreach ($r in (Ask $p "SELECT '  NEGCTL role ccdashboard_nosuchrole_xyz exists (must be 0): '||count(*) FROM pg_roles WHERE rolname='ccdashboard_nosuchrole_xyz';")) { Say ("    {0}" -f $r) }
        foreach ($r in (Ask $p "SELECT '  tables owned by catowner: '||count(*) FROM pg_class c JOIN pg_roles r ON r.oid=c.relowner WHERE r.rolname='ccdashboard_catowner' AND c.relkind='r';")) { Say ("    {0}" -f $r) }
        foreach ($r in (Ask $p "SELECT '  owned table: '||n.nspname||'.'||c.relname FROM pg_class c JOIN pg_roles r ON r.oid=c.relowner JOIN pg_namespace n ON n.oid=c.relnamespace WHERE r.rolname='ccdashboard_catowner' AND c.relkind='r' ORDER BY 1;")) { Say ("    {0}" -f $r) }
    }
}

# ============================== E. IS IT IN THE DUMPS ==============================
Say ""
Say "===== E  do the dumps we hold carry its side of the data? ====="
$pgr = @(Get-ChildItem 'C:\Program Files\PostgreSQL\18\bin\pg_restore.exe' -ErrorAction SilentlyContinue)
if ($pgr.Count -ne 1) { Say "  pg_restore not found - dump section not run" }
else {
    $restore = $pgr[0].FullName
    foreach ($dn in @('rtmviewdb_5433-live_20260905_171440.dump','rtmviewdb_5432-untouched-EVIDENCE_20260905_171440.dump')) {
        $dp = Join-Path $BackupD $dn
        Say ("  --- {0} ---" -f $dn)
        if (-not (Test-Path $dp)) { Say "      file not found"; continue }
        $e = Join-Path $env:TEMP ("ar_{0}.err" -f [guid]::NewGuid().ToString("N"))
        $toc = @(& $restore -l $dp 2> $e)
        if (Test-Path $e) {
            $c = [IO.File]::ReadAllText($e)
            if ($c.Trim().Length -gt 0) { [void]$errAll.Add("pg_restore $dn :: $c") }
            Remove-Item $e -ErrorAction SilentlyContinue
        }
        Say ("      TOC entries                          : {0}" -f $toc.Count)
        Say ("      entries owned by ccdashboard_catowner: {0}" -f @($toc | Where-Object { $_ -match 'ccdashboard_catowner' }).Count)
        Say ("      NEGCTL entries owned by a fake owner : {0}   (must be 0)" -f @($toc | Where-Object { $_ -match 'ccdashboard_nosuchrole_xyz' }).Count)
        $names = @($toc | Where-Object { $_ -match 'ccdashboard_catowner' } | Select-Object -First 15)
        foreach ($n in $names) { Say ("        {0}" -f $n.Trim()) }
    }
}

Say ""
Say "===== END-OF-RUN MARKER: APPLYSVC-RECON-COMPLETE ====="

[IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
[IO.File]::WriteAllLines($errf, $errAll, (New-Object System.Text.UTF8Encoding($false)))

$errSize = (Get-Item $errf).Length
$content = [IO.File]::ReadAllText($outf, [Text.Encoding]::UTF8)
$marker  = $content.Contains('APPLYSVC-RECON-COMPLETE')
$negOk   = $content.Contains('(must be False)') -and (-not $content.Contains('NoSuchDir_xyz) : True'))

Write-Host ""
Write-Host "stderr size   : $errSize bytes   (0 expected; if not 0, read the .err file before the numbers)"
Write-Host "END marker    : $marker  (must be True)"
Write-Host "negative controls present : $negOk  (must be True)"
Write-Host ""
if ($marker -and $negOk) { Write-Host "GATE: measurement is structurally valid" }
else { Write-Host "GATE: FAIL - do NOT read the numbers as a result" }
Write-Host ""
Write-Host "NOTHING WAS STOPPED, DELETED OR CHANGED. The machine is exactly as it was."
Write-Host ""
Write-Host "COPY THESE BACK:"
Write-Host "   $outf"
Write-Host "   $errf"
