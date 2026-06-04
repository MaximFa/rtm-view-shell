# Task: Create db/ module and migrate SQL functions

## Goal

Create the `db/` directory structure as defined in CLAUDE.md §39.
Move SQL functions from `RTM/sql/pgsql/` to `db/functions/`.
Move export script to `db/tools/`.
Update cc_prompt_push.md to include db/ commit.

---

## Step 1 — Create directory structure

```bash
cd "D:\Claude\Projects\RTM View Shell"
mkdir -p db/functions db/migrations db/tools
```

---

## Step 2 — Move SQL function files

Use git mv to preserve history:

```bash
git mv RTM/sql/pgsql/01_ngc_functions.sql      db/functions/01_ngc_functions.sql
git mv RTM/sql/pgsql/02_rtsdata_functions.sql  db/functions/02_rtsdata_functions.sql
git mv RTM/sql/pgsql/03_rtsgrid_read_functions.sql db/functions/03_rtsgrid_read.sql
git mv RTM/sql/pgsql/04_missing_functions.sql  db/functions/04_misc_functions.sql
```

If git mv fails due to mount issues, copy + add + delete:
```bash
cp RTM/sql/pgsql/01_ngc_functions.sql      db/functions/01_ngc_functions.sql
cp RTM/sql/pgsql/02_rtsdata_functions.sql  db/functions/02_rtsdata_functions.sql
cp RTM/sql/pgsql/03_rtsgrid_read_functions.sql db/functions/03_rtsgrid_read.sql
cp RTM/sql/pgsql/04_missing_functions.sql  db/functions/04_misc_functions.sql
```

---

## Step 3 — Move Export-DbBaseline.ps1 to db/tools/

```bash
cp RTM/tools/Export-DbBaseline.ps1 db/tools/Export-Baseline.ps1
```

Then update internal paths in `db/tools/Export-Baseline.ps1`:
- Change `$OutFile = Join-Path $RepoRoot "sql\db_baseline.sql"` 
  to    `$OutFile = Join-Path $RepoRoot "db\baseline.sql"`

---

## Step 4 — Create db/tools/Create-FreshDb.ps1

Create `db/tools/Create-FreshDb.ps1` with this content:

```powershell
# Create-FreshDb.ps1
# Creates a clean RTM View Shell database from scratch.
# Steps: EF migrations -> SQL functions -> Shell startup seed -> baseline.sql
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File db\tools\Create-FreshDb.ps1 `
#     -DBPassword "yourpw" -DBAppPassword "apppw"

[CmdletBinding()]
param(
    [string]$Host          = "localhost",
    [string]$Port          = "5432",
    [string]$Database      = "rtmviewdb",
    [string]$DBSuperUser   = "postgres",
    [string]$DBPassword    = "",
    [string]$DBAppUser     = "ccdashboard_user",
    [string]$DBAppPassword = "",
    [string]$ShellExe      = "C:\RTMView\Shell\CcDashboard.Web.exe",
    [switch]$SkipMigrations
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$FunctionsDir = Join-Path $RepoRoot "db\functions"
$BaselineSql  = Join-Path $RepoRoot "db\baseline.sql"

function Find-PGTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($base in @("C:\Program Files\PostgreSQL","C:\Program Files (x86)\PostgreSQL")) {
        $found = Get-ChildItem "$base\*\bin\$Name.exe" -ErrorAction SilentlyContinue | Sort-Object -Descending | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

$psql = Find-PGTool "psql"
if (-not $psql) { throw "psql not found." }

if ($DBPassword) { $env:PGPASSWORD = $DBPassword }

Write-Host "[ 1/4 ] Running EF migrations..." -ForegroundColor Cyan
if (-not $SkipMigrations -and (Test-Path $ShellExe)) {
    & $ShellExe migrate
    Write-Host "  Migrations applied." -ForegroundColor Green
} else {
    Write-Host "  Skipped (SkipMigrations or ShellExe not found)." -ForegroundColor Yellow
}

Write-Host "[ 2/4 ] Deploying SQL functions..." -ForegroundColor Cyan
foreach ($f in @("01_ngc_functions.sql","02_rtsdata_functions.sql","03_rtsgrid_read.sql","04_misc_functions.sql")) {
    $file = Join-Path $FunctionsDir $f
    if (Test-Path $file) {
        if ($DBAppPassword) { $env:PGPASSWORD = $DBAppPassword }
        & $psql -h $Host -p $Port -U $DBAppUser -d $Database -f $file -q
        Write-Host "  Applied: $f" -ForegroundColor Green
    } else {
        Write-Host "  Not found: $f" -ForegroundColor Yellow
    }
}

Write-Host "[ 3/4 ] Applying baseline seed data..." -ForegroundColor Cyan
if (Test-Path $BaselineSql) {
    if ($DBAppPassword) { $env:PGPASSWORD = $DBAppPassword }
    & $psql -h $Host -p $Port -U $DBAppUser -d $Database -f $BaselineSql -q
    Write-Host "  Baseline applied." -ForegroundColor Green
} else {
    Write-Host "  baseline.sql not found — run Export-Baseline.ps1 first." -ForegroundColor Yellow
}

Write-Host "[ 4/4 ] Done." -ForegroundColor Green
Write-Host ""
Write-Host "Next: start Shell service -> DatabaseInitializer creates Platform tenant + superadmin." -ForegroundColor Yellow
$env:PGPASSWORD = ""
```

---

## Step 5 — Add placeholder db/migrations/.gitkeep

```bash
echo "" > db/migrations/.gitkeep
```

---

## Step 6 — Update cc_prompt_push.md

In `tools/cc_prompt_push.md`, find Step 3 (Shell commit) and add Step 3b for DB:

After the Shell commit block, add:

```markdown
## Step 3b — Commit DB changes (if any db/ files modified)

```bash
cp .git/index /tmp/cc-idx
GIT_INDEX_FILE=/tmp/cc-idx git add db/ CLAUDE.md
GIT_INDEX_FILE=/tmp/cc-idx git commit -m "db: <describe DB changes>"
cp /tmp/cc-idx .git/index
```
```

---

## Step 7 — Update README / docs if any reference RTM/sql/pgsql

Search for references to old paths:
```bash
grep -r "RTM/sql/pgsql" --include="*.md" --include="*.ps1" --include="*.sql" .
```
Update any found references to `db/functions/`.

Also update `RTM/staging/00_deploy_all_functions.sql` header comment if it
references the old path.

---

## Step 8 — Verify

```bash
ls db/functions/
ls db/tools/
cat db/tools/Export-Baseline.ps1 | grep "OutFile"
```

---

## Git push
Do NOT run `git push` automatically. Commit only.

## Mandatory pre-commit check

```bash
bash tools/pre-commit-check.sh
```

## Commit message

```
docs: create db/ module — move SQL functions from RTM/sql/pgsql/

New three-module structure: src/ (Shell), RTM/ (RTM Service), db/ (Database).
SQL functions moved to db/functions/. Export-Baseline.ps1 and
Create-FreshDb.ps1 added to db/tools/. See CLAUDE.md §39.
CLAUDE.md updated to TZ v2.0.
```
