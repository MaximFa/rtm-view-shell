# PR234-V4-WFM-WINDOW-TZ-01 — run the read-only timezone probe.
# Reads the connection string from appsettings.json, prints host/database/user ONLY
# (never the password, which goes to PGPASSWORD and is not echoed), runs PROBE.sql,
# and saves the output next to the probe so the numbers survive this window.

$ErrorActionPreference = 'Stop'
$root   = "D:\Claude\Projects\RTM View Shell"
$probe  = Join-Path $root ".coord\measure\wfm-window-tz-1014\PROBE.sql"
$outFile= Join-Path $root ".coord\measure\wfm-window-tz-1014\RESULT.txt"

if (-not (Test-Path $probe)) { Write-Host "STOP: PROBE.sql not found at $probe"; exit 1 }

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
    $cand = Get-ChildItem "C:\Program Files\PostgreSQL\*\bin\psql.exe" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
    if ($cand) { $psql = $cand.FullName } else { Write-Host "STOP: psql not found - say so and I will give a C#-based probe instead"; exit 1 }
} else { $psql = $psql.Source }
Write-Host "psql: $psql"

$cfg = Get-Content (Join-Path $root "src\CcDashboard.Web\appsettings.json") -Raw | ConvertFrom-Json
$cs  = $cfg.ConnectionStrings.Default
$kv  = @{}
foreach ($part in $cs -split ';') {
    if ($part -match '^\s*([^=]+)=(.*)$') { $kv[$matches[1].Trim().ToLower()] = $matches[2].Trim() }
}

$env:PGHOST     = $kv['host']
$env:PGPORT     = if ($kv['port']) { $kv['port'] } else { '5432' }
$env:PGDATABASE = $kv['database']
$env:PGUSER     = if ($kv['username']) { $kv['username'] } else { $kv['user id'] }
$env:PGPASSWORD = if ($kv['password']) { $kv['password'] } else { '' }

# Password is NOT printed - only its length, so the right secret can be recognised without exposing it.
Write-Host ("target: host={0} port={1} db={2} user={3} password_len={4}" -f `
    $env:PGHOST, $env:PGPORT, $env:PGDATABASE, $env:PGUSER, $env:PGPASSWORD.Length)

& $psql -v ON_ERROR_STOP=1 -f $probe 2>&1 | Tee-Object -FilePath $outFile
Write-Host "---"
Write-Host ("saved: {0}" -f $outFile)
$env:PGPASSWORD = $null
