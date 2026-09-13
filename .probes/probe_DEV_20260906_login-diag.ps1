#Requires -Version 5.1
# ============================================================================
#  PROBE DEV / login-diag  -  READ ONLY, DIAGNOSIS ONLY
#  WHERE IT RUNS : the LOCAL machine (DEV), not server 234. 234 is not touched.
#  WRITES        : nothing anywhere except its own output files.
#                  NO password reset, NO user creation, NO config edit,
#                  NO write to any authentication table. SELECT only.
#  PURPOSE       : the only local account (admin) cannot log in and the form says
#                  "invalid credentials". THREE different causes produce that same
#                  message - unresolved tenant / missing-or-inactive user / wrong
#                  password - so this probe separates them by measurement.
#  ASSUMES NOTHING: shell path, log path, database and tenant slug are all discovered,
#                  never assumed from another machine.
# ============================================================================

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING = "UTF8"

# ops root: DEV uses D:\ (operator decision), PROD layout is C:\ - pick by existence
$OpsRoot = if (Test-Path 'D:\RTMView-Ops') { 'D:\RTMView-Ops' } elseif (Test-Path 'C:\RTMView-Ops') { 'C:\RTMView-Ops' } else { "$env:TEMP\RTMView-Ops" }
$OutDir  = Join-Path $OpsRoot "output"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$stamp = Get-Date -Format yyyyMMdd_HHmmss
$outf  = Join-Path $OutDir "DEV_$($stamp)_login-diag.txt"
$L = New-Object System.Collections.ArrayList
function Say($s) { [void]$L.Add($s); Write-Host $s }

Say "WHERE IT RUNS : LOCAL machine (DEV). Server 234 NOT touched. READ ONLY - no writes anywhere."
Say ("ops root      : {0}" -f $OpsRoot)
Say ""

Say "===== L0 WHICH SHELL INSTALLATION IS HERE - found, not assumed ====="
$cands = @(
  'C:\RTMView\Shell\appsettings.json',
  'D:\RTMView\Shell\appsettings.json',
  'C:\Program Files\CcDashboard\appsettings.json'
)
$found = @()
foreach ($c in $cands) {
    if (Test-Path $c) { $found += $c; Say ("  FOUND   : {0}   ({1} bytes, modified {2})" -f $c, (Get-Item $c).Length, (Get-Item $c).LastWriteTime) }
    else { Say ("  absent  : {0}" -f $c) }
}
$svc = @(Get-Service -Name 'RTMViewShell','RTMService' -ErrorAction SilentlyContinue)
foreach ($s in $svc) {
    $wmi = Get-WmiObject Win32_Service -Filter "Name='$($s.Name)'"
    Say ("  service {0,-14} {1,-9} path = {2}" -f $s.Name, $s.Status, $wmi.PathName)
}
if ($found.Count -eq 0) { Say "  *** STOP: no shell config found on this machine. Nothing else can be measured."; [IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false))); Write-Host ""; Write-Host "GATE: FAIL"; Write-Host "   $outf"; exit 1 }

$cfg = $found[0]
$raw = [IO.File]::ReadAllText($cfg)

Say ""
Say "===== L1 THE CONFIG - tenant slug, connection target, log path (password NEVER printed) ====="
$slug = ([regex]::Match($raw,'"DefaultTenantSlug"\s*:\s*"([^"]*)"')).Groups[1].Value
$slugPresent = [regex]::IsMatch($raw,'"DefaultTenantSlug"')
Say ("  DefaultTenantSlug present : {0}" -f $slugPresent)
Say ("  DefaultTenantSlug value   : '{0}'" -f $slug)
$seedSlug = ([regex]::Match($raw,'"PlatformTenantSlug"\s*:\s*"([^"]*)"')).Groups[1].Value
Say ("  Seed:PlatformTenantSlug   : '{0}'" -f $seedSlug)

$conn = ([regex]::Match($raw,'"DefaultConnection"\s*:\s*"([^"]*)"')).Groups[1].Value
if ($conn -eq '') { $conn = ([regex]::Match($raw,'Host\s*=\s*[^"]*')).Value }
$dbHost = ([regex]::Match($conn,'Host\s*=\s*([^;"]+)')).Groups[1].Value
$dbPort = ([regex]::Match($conn,'Port\s*=\s*([^;"]+)')).Groups[1].Value
$dbName = ([regex]::Match($conn,'Database\s*=\s*([^;"]+)')).Groups[1].Value
$dbUser = ([regex]::Match($conn,'Username\s*=\s*([^;"]+)')).Groups[1].Value
$dbPass = ([regex]::Match($conn,'Password\s*=\s*([^;"]+)')).Groups[1].Value
if ($dbPort -eq '') { $dbPort = '5432' }
Say ("  THE APP ACTUALLY POINTS AT : host={0} port={1} database={2} user={3} (password length {4}, never printed)" -f $dbHost, $dbPort, $dbName, $dbUser, $dbPass.Length)

$logPath = ([regex]::Match($raw,'"path"\s*:\s*"([^"]*)"')).Groups[1].Value
if ($logPath -eq '') { $logPath = ([regex]::Match($raw,'"pathFormat"\s*:\s*"([^"]*)"')).Groups[1].Value }
Say ("  Serilog path in config     : '{0}'" -f $logPath)
Say  "  (on 234 a RELATIVE path sent service logs to C:\Windows\System32\logs - checked below by fact)"

Say ""
Say "===== L2 THE LOG - where it actually is, and what the login attempt says ====="
$logDirs = @()
if ($logPath -ne '') {
    $d = Split-Path $logPath -Parent
    if ($d -ne '' -and -not [IO.Path]::IsPathRooted($d)) { $logDirs += (Join-Path (Split-Path $cfg -Parent) $d) }
    elseif ($d -ne '') { $logDirs += $d }
}
$logDirs += 'C:\Logs\RTMViewShell'
$logDirs += (Join-Path (Split-Path $cfg -Parent) 'logs')
$logDirs += 'C:\Windows\System32\logs'
$logDirs = $logDirs | Select-Object -Unique
$logFile = $null
foreach ($d in $logDirs) {
    if (Test-Path $d) {
        $f = @(Get-ChildItem $d -Filter *.txt -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        if ($f.Count -gt 0) {
            Say ("  log dir  : {0}   newest = {1}  ({2}, modified {3})" -f $d, $f[0].Name, $f[0].Length, $f[0].LastWriteTime)
            if ($logFile -eq $null) { $logFile = $f[0].FullName }
        } else { Say ("  log dir  : {0}   (exists, no .txt)" -f $d) }
    } else { Say ("  absent   : {0}" -f $d) }
}
if ($logFile -ne $null) {
    Say ""
    Say ("  --- lines mentioning login / tenant / auth, newest 40, from {0} ---" -f $logFile)
    $pat = 'login|tenant|Invalid username|SignIn|authentic|Unauthor|slug'
    $hits = @(Select-String -Path $logFile -Pattern $pat -ErrorAction SilentlyContinue | Select-Object -Last 40)
    if ($hits.Count -eq 0) { Say "      (no matching lines - printed as a zero, not as an empty screen)" }
    foreach ($h in $hits) { Say ("      {0}" -f $h.Line.Trim()) }
} else { Say "  *** no log file found in any candidate directory" }

Say ""
Say "===== L3 THE DATA - tenants, the admin user, and whether they line up ====="
$psqlCands = @(Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe' -ErrorAction SilentlyContinue | Sort-Object FullName -Descending)
if ($psqlCands.Count -eq 0) { Say "  *** psql not found on this machine - DB section skipped" }
else {
    $psql = $psqlCands[0].FullName
    Say ("  psql : {0}" -f $psql)
    $sql = @"
\qecho -- tenants and their slugs
SELECT 'tenant | '||"Id"||' | slug='||coalesce("Slug",'<null>')||' | name='||coalesce("Name",'<null>')||' | active='||coalesce("IsActive"::text,'<null>') FROM tenants ORDER BY "Slug";
\qecho -- how many tenants, and does the config slug match any of them
SELECT 'tenant count | '||count(*)::text FROM tenants;
SELECT 'config slug matches a tenant | '||(EXISTS (SELECT 1 FROM tenants WHERE "Slug" = '$slug'))::text;
SELECT 'NEGCTL slug ZZZNOSUCH matches | '||(EXISTS (SELECT 1 FROM tenants WHERE "Slug" = 'ZZZNOSUCHSLUG'))::text;
\qecho -- users: who exists, active or not, in which tenant
SELECT 'user | '||"UserName"||' | tenant='||coalesce("TenantId"::text,'<null>')||' | active='||coalesce("IsActive"::text,'<null>')||' | lockoutEnd='||coalesce("LockoutEnd"::text,'-')||' | accessFailed='||coalesce("AccessFailedCount"::text,'-')||' | hasHash='||(("PasswordHash" IS NOT NULL))::text FROM identity.users ORDER BY "UserName";
SELECT 'user count | '||count(*)::text FROM identity.users;
SELECT 'NEGCTL user ZZZNOSUCH exists | '||(EXISTS (SELECT 1 FROM identity.users WHERE "UserName"='ZZZNOSUCHUSER'))::text;
\qecho -- the join that actually matters: is there an ACTIVE user inside the tenant the config resolves to
SELECT 'active users in config-slug tenant | '||count(*)::text
FROM identity.users u JOIN tenants t ON t."Id" = u."TenantId"
WHERE t."Slug" = '$slug' AND coalesce(u."IsActive", true);
\qecho ===== END-OF-RUN MARKER: LOGIN-DIAG-COMPLETE =====
"@
    $sqlf = Join-Path $OutDir "DEV_$($stamp)_login-diag.sql"
    $errf = Join-Path $OutDir "DEV_$($stamp)_login-diag.err.txt"
    [IO.File]::WriteAllText($sqlf, $sql, (New-Object System.Text.UTF8Encoding($false)))
    $env:PGPASSWORD = $dbPass
    $res = & $psql -h $dbHost -p $dbPort -U $dbUser -d $dbName -v ON_ERROR_STOP=0 -A -t -f $sqlf 2> $errf
    $rc = $LASTEXITCODE
    $env:PGPASSWORD = $null
    foreach ($r in @($res | Where-Object { "$_".Trim().Length -gt 0 })) { Say ("      {0}" -f $r) }
    Say ("  psql exit : {0}" -f $rc)
    $es = 0; if (Test-Path $errf) { $es = (Get-Item $errf).Length }
    Say ("  psql stderr bytes : {0}   (non-zero = read the .err file)" -f $es)
    if ($es -gt 0) { Say ("  stderr file : {0}" -f $errf) }
}

Say ""
Say "===== END-OF-PROBE ====="
[IO.File]::WriteAllLines($outf, $L, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ""
Write-Host "COPY THIS BACK:"
Write-Host "   $outf"
